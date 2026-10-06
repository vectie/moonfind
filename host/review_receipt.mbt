///|
fn review_return_name() -> String {
  "moonchat-review-return.json"
}

///|
fn review_record_name() -> String {
  "moonchat-review-record.raw.json"
}

///|
async fn retained_review_bundle(
  config : Config,
) -> @review.ConversationReviewBundle {
  let bundle_text = @fs.read_file(
    run_artifact(config, "moonchat-review-bundle.json"),
  ).text()
  let bundle = @review.decode_review_bundle(@json.parse(bundle_text))
  guard bundle.review_id == review_id(config.run_id) &&
    bundle.source_revision_id == "moontown-\{config.run_id}" &&
    bundle.source_artifact_ref ==
    review_relative_run_ref(config, "moontown-reducer-output.json") else {
    fail("Retained MoonChat bundle does not belong to this exact result")
  }
  let issues = @review.bundle_issues(bundle, bundle.source_digest).filter(issue => {
    !(bundle.conversation.contract_id == "moonsuite-conversation.v1" &&
    issue ==
    "conversation binding must consume " + @review.conversation_contract_id())
  })
  if !issues.is_empty() {
    fail("Retained MoonChat bundle is invalid: " + issues.join("; "))
  }
  validate_prepared_review_binding(config, bundle, bundle_text)
  bundle
}

///|
async fn validate_review_journal(
  config : Config,
  bundle : @review.ConversationReviewBundle,
  record : @review.ConversationReviewRecord,
) -> Unit {
  let expected = @review.review_events(bundle, bundle.source_digest)
  guard expected.length() == record.journal_evidence.length() else {
    fail("MoonChat return must retain every exact review event")
  }
  let seen : Array[String] = []
  let root = @fs.realpath(config.workspace)
  for index in 0..<expected.length() {
    let evidence = record.journal_evidence[index]
    guard review_receiver_safe_ref(evidence.artifact_ref) &&
      !seen.contains(evidence.artifact_ref) else {
      fail("MoonChat review journal reference is unsafe or duplicated")
    }
    seen.push(evidence.artifact_ref)
    let path = @fs.realpath(root + "/" + evidence.artifact_ref)
    guard path.has_prefix(root + "/") else {
      fail("MoonChat review journal escapes this workspace")
    }
    let text = @fs.read_file(path).text()
    guard @store.digest_text(text) == evidence.digest else {
      fail("MoonChat review journal bytes changed")
    }
    let event : @review.ConversationReviewEvent = @json.from_json(
      @json.parse(text),
    )
    guard event == expected[index] else {
      fail("MoonChat review journal is not the exact retained event sequence")
    }
  }
}

///|
async fn validate_typed_review_return(
  config : Config,
  bundle : @review.ConversationReviewBundle,
  value : Json,
) -> @review.ConversationReviewRecord {
  let record = @review.decode_review_record(value)
  let expected = @review.project_review_record(
    bundle,
    bundle.source_digest,
    record.journal_evidence,
  )
  guard record == expected else {
    fail(
      "MoonChat return is not the deterministic projection of this exact retained decision",
    )
  }
  validate_review_journal(config, bundle, record)
  record
}

///|
async fn review_return_json(
  config : Config,
  request : MoonChatResultIngestRequestV1,
  record : @review.ConversationReviewRecord,
) -> Json {
  {
    "contract_id": "moonfind.moonchat-review-return.v1",
    "run_id": config.run_id,
    "review_id": record.review_id,
    "source_ref": record.source_artifact_ref,
    "source_digest": record.source_digest,
    "output_artifact_ref": request.output_artifact_ref,
    "record_ref": review_relative_run_ref(config, review_record_name()),
    "record_digest": request.output_digest,
    "decision_digest": @store.digest_text(
      @fs.read_file(run_artifact(config, "cross-product-review-decision.json")).text(),
    ),
    "bundle_digest": @store.digest_text(
      @fs.read_file(run_artifact(config, "moonchat-review-bundle.json")).text(),
    ),
    "review_status": record.review_status,
    "recorded_at": record.recorded_at,
  }
}

///|
async fn retained_decision_view(
  config : Config,
) -> ReviewDecisionReceiptViewV1? {
  if !@fs.exists(run_artifact(config, "moonchat-review-bundle.json")) {
    return None
  }
  let bundle = retained_review_bundle(config)
  guard bundle.decision_receipts is [human] else {
    fail("The Find review must retain exactly one named human decision receipt")
  }
  let current = try
    @store.digest_text(
      @fs.read_file(run_artifact(config, "moontown-reducer-output.json")).text(),
    ) ==
    bundle.source_digest
  catch {
    _ => false
  }
  let decision : @closed_loop.CrossProductReviewDecision = @json.from_json(
    @store.read_json(run_artifact(config, "cross-product-review-decision.json")),
  )
  guard decision.review_id == bundle.review_id &&
    decision.reviewer_id == human.reviewer_participant_id &&
    decision.reviewer_name == human.reviewer_name &&
    decision.outcome == human.decision &&
    decision.rationale == human.rationale else {
    fail("Retained human decision and MoonChat bundle disagree")
  }
  let record_path = run_artifact(config, review_record_name())
  let record_exists = @fs.exists(record_path)
  let record_digest = if record_exists {
    Some(@store.digest_text(@fs.read_file(record_path).text()))
  } else {
    None
  }
  let linked_path = run_artifact(config, review_return_name())
  let legacy_binding = bundle.conversation.contract_id !=
    @review.conversation_contract_id()
  let mut evidence_status = if legacy_binding {
    "legacy-retained"
  } else {
    "bundle-validated"
  }
  let mut delivery_status = if legacy_binding {
    "legacy-retained"
  } else {
    "pending-return"
  }
  let mut status = if legacy_binding {
    "unverified-history"
  } else {
    @review.review_status(bundle)
  }
  if record_exists {
    try {
      let record = validate_typed_review_return(
        config,
        bundle,
        @store.read_json(record_path),
      )
      evidence_status = "typed-validated"
      status = record.review_status
      if @fs.exists(linked_path) {
        let link = @store.read_json(linked_path)
        guard link
          is {
            "contract_id": "moonfind.moonchat-review-return.v1",
            "run_id": String(run_id),
            "review_id": String(id),
            "source_ref": String(source),
            "source_digest": String(digest),
            "record_ref": String(reference),
            "record_digest": String(returned_digest),
            "review_status": String(state),
            "decision_digest": String(decision_digest),
            "bundle_digest": String(bundle_digest),
            ..
          } &&
          run_id == config.run_id &&
          id == bundle.review_id &&
          source == bundle.source_artifact_ref &&
          digest == bundle.source_digest &&
          reference == review_relative_run_ref(config, review_record_name()) &&
          Some(returned_digest) == record_digest &&
          state == record.review_status &&
          decision_digest ==
          @store.digest_text(
            @fs.read_file(
              run_artifact(config, "cross-product-review-decision.json"),
            ).text(),
          ) &&
          bundle_digest ==
          @store.digest_text(
            @fs.read_file(run_artifact(config, "moonchat-review-bundle.json")).text(),
          ) else {
          fail("MoonChat producer receipt no longer matches retained evidence")
        }
        delivery_status = "linked"
      }
    } catch {
      error => {
        // Only explicitly historical v1 evidence may retain its unverified
        // legacy label. New v2 failures stay failures even in the real crash
        // window after a Book submission but before the return marker.
        if !legacy_binding || @fs.exists(linked_path) {
          raise error
        }
        evidence_status = "legacy-retained"
        delivery_status = "legacy-retained"
        status = "unverified-history"
      }
    }
  }
  Some({
    review_id: bundle.review_id,
    reviewer_id: human.reviewer_participant_id,
    reviewer_name: human.reviewer_name,
    outcome: human.decision,
    rationale: human.rationale,
    accepted_idea_ids: decision.accepted_idea_ids,
    rejected_idea_ids: decision.rejected_idea_ids,
    objections: bundle.entries
    .filter(entry => entry.entry_kind == "objection")
    .map(entry => entry.body),
    source_ref: bundle.source_artifact_ref,
    source_digest: bundle.source_digest,
    source_revision_id: bundle.source_revision_id,
    source_current: current,
    review_status: status,
    delivery_status,
    evidence_status,
    record_ref: if record_exists {
      Some(review_relative_run_ref(config, review_record_name()))
    } else {
      None
    },
    record_digest,
    bookkeeper_state: "not-acknowledged",
    detail: if !current {
      "This retained decision belongs to different source bytes. Restore the original or create a new research revision; it cannot approve the current result."
    } else if evidence_status == "legacy-retained" {
      "Historical receipt retained unchanged. Its complete typed projection or journal is unavailable, so it is not newly qualified. MoonBook acceptance is unknown."
    } else if delivery_status != "linked" {
      "Decision saved; return from MoonChat is pending. Refresh after MoonFlow returns the exact record, or retry the same return without changing the decision."
    } else if human.decision == "defer" {
      "Deferred: a named decision is still required. Rationale and dissent are retained; create a revised research run to reconsider. Nothing was sent to Bookkeeper."
    } else if human.decision == "reject" {
      "Rejected: this version is retained for history. Create a revised research run; nothing was sent to Bookkeeper."
    } else {
      "Review approved and receipt linked. Bookkeeper submission is separate; MoonBook has not acknowledged or accepted it here."
    },
  })
}
