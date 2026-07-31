///|
fn review_relative_run_ref(config : Config, name : String) -> String {
  ".moonsuite/products/moonfind/runs/\{config.run_id}/\{name}"
}

///|
fn review_safe_identifier(value : String) -> Bool {
  !value.is_blank() &&
  value != "." &&
  value != ".." &&
  value.all(fn(ch) {
    (ch >= 'a' && ch <= 'z') ||
    (ch >= 'A' && ch <= 'Z') ||
    (ch >= '0' && ch <= '9') ||
    ch == '-' ||
    ch == '_' ||
    ch == '.'
  })
}

///|
fn reviewer_id(run_id : String) -> String {
  "reviewer-" + run_id
}

///|
fn review_id(run_id : String) -> String {
  "moonfind-review-" + run_id
}

///|
fn review_outcome(value : String) -> String raise {
  match value {
    "approve_subset" | "approve" => "approve"
    "request_changes" | "defer" => "defer"
    "reject" => "reject"
    _ =>
      fail("review outcome must be approve_subset, request_changes, or reject")
  }
}

///|
fn validate_prepare_request(request : ReviewPrepareRequestV1) -> Unit raise {
  if request.contract_id != "moonfind.review-prepare-request.v1" ||
    request.reviewer_name.is_blank() ||
    request.rationale.is_blank() {
    fail("named reviewer and rationale are required")
  }
  ignore(review_outcome(request.outcome))
  let seen : Array[String] = []
  for idea_id in request.accepted_idea_ids + request.rejected_idea_ids {
    if !review_safe_identifier(idea_id) || seen.contains(idea_id) {
      fail("review idea ids must be safe, unique, and non-overlapping")
    }
    seen.push(idea_id)
  }
}

///|
fn review_decision(
  config : Config,
  request : ReviewPrepareRequestV1,
) -> @closed_loop.CrossProductReviewDecision raise {
  {
    review_id: review_id(config.run_id),
    reviewer_id: reviewer_id(config.run_id),
    reviewer_name: request.reviewer_name,
    outcome: review_outcome(request.outcome),
    accepted_idea_ids: request.accepted_idea_ids,
    rejected_idea_ids: request.rejected_idea_ids,
    rationale: request.rationale,
    reviewed_at_utc: host_timestamp(),
    reviewed_at_epoch: @async.now(),
    information_gap_present: request.information_gap.present,
    information_gap_severity: request.information_gap.severity,
    information_gap_summary: request.information_gap.summary,
    recognition_gap_present: request.recognition_gap.present,
    recognition_gap_severity: request.recognition_gap.severity,
    recognition_gap_summary: request.recognition_gap.summary,
    decisiveness_gap_present: request.decisiveness_gap.present,
    decisiveness_gap_severity: request.decisiveness_gap.severity,
    decisiveness_gap_summary: request.decisiveness_gap.summary,
  }
}

///|
fn persisted_decision_matches_request(
  config : Config,
  request : ReviewPrepareRequestV1,
  decision : @closed_loop.CrossProductReviewDecision,
) -> Bool raise {
  decision.review_id == review_id(config.run_id) &&
  decision.reviewer_id == reviewer_id(config.run_id) &&
  decision.reviewer_name == request.reviewer_name &&
  decision.outcome == review_outcome(request.outcome) &&
  decision.accepted_idea_ids == request.accepted_idea_ids &&
  decision.rejected_idea_ids == request.rejected_idea_ids &&
  decision.rationale == request.rationale &&
  decision.information_gap_present == request.information_gap.present &&
  decision.information_gap_severity == request.information_gap.severity &&
  decision.information_gap_summary == request.information_gap.summary &&
  decision.recognition_gap_present == request.recognition_gap.present &&
  decision.recognition_gap_severity == request.recognition_gap.severity &&
  decision.recognition_gap_summary == request.recognition_gap.summary &&
  decision.decisiveness_gap_present == request.decisiveness_gap.present &&
  decision.decisiveness_gap_severity == request.decisiveness_gap.severity &&
  decision.decisiveness_gap_summary == request.decisiveness_gap.summary
}

///|
async fn ensure_immutable_review_artifact(
  path : String,
  text : String,
  label : String,
) -> Unit {
  if @fs.exists(path) {
    if @fs.read_file(path).text() != text {
      fail("\{label} already exists with different content")
    }
    return
  }
  @fs.write_file(
    path,
    @utf8.encode(text),
    create_mode=CreateNew,
    permission=0o600,
    sync=Full,
  ) catch {
    _ => {
      guard @fs.exists(path) else {
        fail("MoonFind could not create immutable \{label}")
      }
      guard @fs.read_file(path).text() == text else {
        fail("\{label} already exists with different content")
      }
    }
  }
}

///|
async fn review_inputs(
  config : Config,
) -> (
  @research.ResearchRun,
  @moontown.TownExecutionReceipt,
  @moontown.TownSynthesisOutput,
  String,
  String,
) {
  let run : @research.ResearchRun = @json.from_json(
    @store.read_json(run_artifact(config, "run.json")),
  )
  let receipt : @moontown.TownExecutionReceipt = @json.from_json(
    @store.read_json(run_artifact(config, "moontown-receipt.json")),
  )
  let output_path = run_artifact(config, "moontown-reducer-output.json")
  let output_text = @fs.read_file(output_path).text()
  let output : @moontown.TownSynthesisOutput = @json.from_json(
    @json.parse(output_text),
  )
  let issues = @moontown.validate_town_execution_receipt(receipt, config.run_id) +
    @moontown.validate_town_synthesis_output(output, receipt)
  if !issues.is_empty() ||
    receipt.status != "completed" ||
    receipt.review_status != "pending" {
    fail("MoonTown output is not ready for named-human review")
  }
  (
    run,
    receipt,
    output,
    review_relative_run_ref(config, "moontown-reducer-output.json"),
    @store.digest_text(output_text),
  )
}

///|
pub async fn prepare_cross_product_review(
  config : Config,
  request : ReviewPrepareRequestV1,
) -> ReviewPrepareReplyV1 {
  validate_prepare_request(request)
  let (run, _, output, source_ref, source_digest) = review_inputs(config)
  let decision_path = run_artifact(config, "cross-product-review-decision.json")
  let decision = if @fs.exists(decision_path) {
    let persisted : @closed_loop.CrossProductReviewDecision = @json.from_json(
      @store.read_json(decision_path),
    )
    if !persisted_decision_matches_request(config, request, persisted) {
      fail("review decision already exists with different content")
    }
    persisted
  } else {
    review_decision(config, request)
  }
  let bundle = @closed_loop.moonchat_review_bundle(
    run, output, decision, source_ref, source_digest,
  )
  let bundle_path = run_artifact(config, "moonchat-review-bundle.json")
  let decision_text = decision.to_json().stringify(indent=2) + "\n"
  let bundle_text = bundle.stringify(indent=2) + "\n"
  ensure_immutable_review_artifact(
    decision_path, decision_text, "review decision",
  )
  ensure_immutable_review_artifact(
    bundle_path, bundle_text, "MoonChat review bundle",
  )
  {
    contract_id: "moonfind.review-prepare-reply.v1",
    state: "awaiting-moonchat",
    run_id: config.run_id,
    review_id: decision.review_id,
    source_ref,
    source_digest,
    bundle_ref: review_relative_run_ref(config, "moonchat-review-bundle.json"),
    operation_ref: "moonchat/conversation.review.record@0.1.0",
    message: "Portable review bundle is durable. MoonFlow may now hand the exact bundle and source evidence to MoonChat.",
  }
}

///|
fn moonchat_result_identity(
  request : MoonChatResultIngestRequestV1,
) -> Json raise {
  if request.contract_id != "moonfind.moonchat-result-ingest.v1" ||
    request.product_id != "moonchat" ||
    request.status.to_lower() != "succeeded" ||
    request.output_artifact_ref.is_blank() ||
    request.record_text.is_blank() ||
    @store.digest_text(request.record_text) != request.output_digest {
    fail("MoonChat result is missing exact successful output identity")
  }
  @json.parse(request.record_text)
}

///|
pub async fn ingest_moonchat_result(
  config : Config,
  request : MoonChatResultIngestRequestV1,
) -> MoonChatResultIngestReplyV1 {
  let record = moonchat_result_identity(request)
  let (run, _, output, town_ref, town_digest) = review_inputs(config)
  let decision_path = run_artifact(config, "cross-product-review-decision.json")
  let bundle_path = run_artifact(config, "moonchat-review-bundle.json")
  if !@fs.exists(decision_path) || !@fs.exists(bundle_path) {
    fail("MoonFind has no durable review decision and MoonChat bundle")
  }
  let decision : @closed_loop.CrossProductReviewDecision = @json.from_json(
    @store.read_json(decision_path),
  )
  let reviewed = @closed_loop.apply_moonchat_review(
    run, output, decision, record, town_digest,
  )
  let raw_record_name = "moonchat-review-record.raw.json"
  let raw_record_path = run_artifact(config, raw_record_name)
  ensure_immutable_review_artifact(
    raw_record_path,
    request.record_text,
    "MoonChat review record",
  )
  let review_ref = review_relative_run_ref(config, raw_record_name)
  let review_digest = @store.digest_text(request.record_text)
  let submission = @closed_loop.moonbook_product_outcome_submission(
    run, output, decision, record, town_ref, town_digest, review_ref, review_digest,
  )
  @store.write_run_artifact(
    config.workspace,
    config.run_id,
    "run.json",
    reviewed.to_json(),
  )
  @store.write_run_artifact(
    config.workspace,
    config.run_id,
    "workspace.json",
    @app.project_research_workspace(reviewed).to_json(),
  )
  @store.write_run_artifact(
    config.workspace,
    config.run_id,
    "bookkeeper-outcome-submission.json",
    submission,
  )
  {
    contract_id: "moonfind.moonchat-result-ingest-reply.v1",
    state: "ready-for-bookkeeper",
    run_id: config.run_id,
    review_id: decision.review_id,
    record_ref: review_ref,
    record_digest: review_digest,
    submission_ref: Some(
      review_relative_run_ref(config, "bookkeeper-outcome-submission.json"),
    ),
    next_operation_ref: Some("moonbook/bookkeeper.outcome.submit@0.1.0"),
    message: "MoonChat accepted the exact synthesis. MoonFind updated its run and prepared a generic MoonBook outcome submission; MoonBook retains every human gate.",
  }
}

///|
pub async fn review_workflow_status(config : Config) -> ReviewWorkflowStatusV1 {
  let output = run_artifact(config, "moontown-reducer-output.json")
  let bundle = run_artifact(config, "moonchat-review-bundle.json")
  let record = run_artifact(config, "moonchat-review-record.raw.json")
  let submission = run_artifact(config, "bookkeeper-outcome-submission.json")
  let state = if @fs.exists(submission) && @fs.exists(record) {
    "ready-for-bookkeeper"
  } else if @fs.exists(bundle) {
    "awaiting-moonchat"
  } else if @fs.exists(output) {
    "ready-for-human-review"
  } else {
    "not-ready"
  }
  {
    contract_id: "moonfind.review-workflow-status.v1",
    run_id: config.run_id,
    state,
    prepare_url: if state == "ready-for-human-review" {
      Some("/api/v1/review/prepare")
    } else {
      None
    },
    moonchat_ingest_url: if state == "awaiting-moonchat" {
      Some("/api/v1/review/moonchat-result")
    } else {
      None
    },
    moonchat_operation_ref: if @fs.exists(bundle) {
      Some("moonchat/conversation.review.record@0.1.0")
    } else {
      None
    },
    bundle_ref: if @fs.exists(bundle) {
      Some(review_relative_run_ref(config, "moonchat-review-bundle.json"))
    } else {
      None
    },
    record_ref: if @fs.exists(record) {
      Some(review_relative_run_ref(config, "moonchat-review-record.raw.json"))
    } else {
      None
    },
    bookkeeper_operation_ref: if @fs.exists(submission) {
      Some("moonbook/bookkeeper.outcome.submit@0.1.0")
    } else {
      None
    },
    bookkeeper_submission_ref: if @fs.exists(submission) {
      Some(
        review_relative_run_ref(config, "bookkeeper-outcome-submission.json"),
      )
    } else {
      None
    },
    detail: match state {
      "ready-for-human-review" =>
        "MoonTown returned a correlated synthesis. Record the named-human decision and explicit Three-Gap statements."
      "awaiting-moonchat" =>
        "The portable bundle is durable and waiting for MoonFlow to execute MoonChat's versioned review operation."
      "ready-for-bookkeeper" =>
        "MoonChat accepted the exact source. The generic MoonBook submission is ready for Bookkeeper's own review queue."
      _ => "MoonTown synthesis must complete before review."
    },
  }
}
