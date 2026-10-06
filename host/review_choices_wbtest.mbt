///|
fn choice_request(outcome : String, digest : String) -> ReviewPrepareRequestV1 {
  {
    contract_id: "moonfind.review-prepare-request.v1",
    source_digest: Some(digest),
    reviewer_name: "Avery Chen",
    outcome,
    accepted_idea_ids: if outcome == "approve_subset" {
      ["idea-1"]
    } else {
      []
    },
    rejected_idea_ids: if outcome == "reject" {
      ["idea-1"]
    } else {
      []
    },
    rationale: "Retain <dissent> & uncertainty: B reports lower error. Approval only covers the next matched test.",
    information_gap: {
      present: true,
      severity: 2,
      summary: "No customer evidence",
    },
    recognition_gap: {
      present: false,
      severity: 0,
      summary: "Limits recognized",
    },
    decisiveness_gap: {
      present: true,
      severity: 1,
      summary: "Matched trial required",
    },
  }
}

///|
// Execute the exact pinned MoonChat pure event/projection functions. This
// fixture owns only file materialization; it does not emulate review policy.
async fn choice_record(config : Config) -> MoonChatResultIngestRequestV1 {
  let bundle = retained_review_bundle(config)
  let directory = run_artifact(config, "moonchat-events")
  @fs.mkdir(directory)
  let evidence : Array[@review.ReviewEvidence] = []
  for event in @review.review_events(bundle, bundle.source_digest) {
    let name = "moonchat-events/\{event.sequence}.json"
    let text = event.to_json().stringify(indent=2) + "\n"
    ensure_immutable_review_artifact(
      run_artifact(config, name),
      text,
      "fixture MoonChat event",
    )
    evidence.push({
      artifact_ref: review_relative_run_ref(config, name),
      digest: @store.digest_text(text),
    })
  }
  let record = @review.project_review_record(
    bundle,
    bundle.source_digest,
    evidence,
  )
  let text = record.to_json().stringify(indent=2) + "\n"
  {
    contract_id: "moonfind.moonchat-result-ingest.v1",
    product_id: "moonchat",
    status: "succeeded",
    output_digest: @store.digest_text(text),
    output_artifact_ref: "moonchat/records/\{bundle.review_id}.json",
    record_text: text,
  }
}

///|
async fn exercise_choice(outcome : String, state : String) -> Unit {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="find-choice-" + outcome),
  )
  let source = delivery_fixture(config)
  let before_run = @fs.read_file(run_artifact(config, "run.json")).text()
  let request = choice_request(outcome, source.source_digest)
  let prepared = prepare_cross_product_review(config, request)
  let bundle_before = @fs.read_file(
    run_artifact(config, "moonchat-review-bundle.json"),
  ).text()
  assert_eq(prepared.source_digest, source.source_digest)
  let pending = review_workflow_status(config).decision_receipt.unwrap()
  assert_eq(pending.delivery_status, "pending-return")
  assert_eq(pending.rationale, request.rationale)
  assert_eq(pending.reviewer_name, "Avery Chen")
  assert_eq(pending.objections, [request.rationale])
  let returned = choice_record(config)
  // Interrupt after MoonChat's record exists and before the producer records
  // successful delivery. A fresh status read must still expose pending.
  ensure_immutable_review_artifact(
    run_artifact(config, review_record_name()),
    returned.record_text,
    "interrupted review return",
  )
  assert_eq(
    review_workflow_status(config).decision_receipt.unwrap().delivery_status,
    "pending-return",
  )
  let first = ingest_moonchat_result(config, returned)
  assert_eq(first.state, state)
  let receipt_text = @fs.read_file(run_artifact(config, review_return_name())).text()
  for _ in 0..<2 {
    assert_eq(
      ingest_moonchat_result(config, returned).to_json(),
      first.to_json(),
    )
    assert_eq(
      @fs.read_file(run_artifact(config, review_return_name())).text(),
      receipt_text,
    )
  }
  let restored = review_workflow_status({ ..config, })
  let receipt = restored.decision_receipt.unwrap()
  assert_eq(restored.state, state)
  assert_eq(receipt.delivery_status, "linked")
  assert_eq(receipt.evidence_status, "typed-validated")
  assert_eq(receipt.record_digest, Some(returned.output_digest))
  assert_eq(receipt.objections, [request.rationale])
  assert_eq(receipt.bookkeeper_state, "not-acknowledged")
  let run : @research.ResearchRun = @json.from_json(
    @store.read_json(run_artifact(config, "run.json")),
  )
  if outcome == "approve_subset" {
    assert_eq(run.status, "accepted")
    assert_eq(run.ideas.map(idea => idea.idea_id), ["candidate-a"])
    assert_eq(run.accepted_idea_ids, [])
    assert_eq(run.reviewed_synthesis.unwrap().accepted_idea_ids, ["idea-1"])
    assert_eq(
      run.reviewed_synthesis.unwrap().source_digest,
      source.source_digest,
    )
    assert_true(first.submission_ref is Some(_))
  } else {
    assert_eq(
      @fs.read_file(run_artifact(config, "run.json")).text(),
      before_run,
    )
    assert_false(
      @fs.exists(run_artifact(config, "bookkeeper-outcome-submission.json")),
    )
    assert_true(first.submission_ref is None)
    assert_true(first.next_operation_ref is None)
    assert_eq(
      receipt.review_status,
      if outcome == "reject" {
        "rejected"
      } else {
        "pending_review"
      },
    )
  }
  assert_eq(
    @fs.read_file(run_artifact(config, "moonchat-review-bundle.json")).text(),
    bundle_before,
  )
  let source_path = run_artifact(config, "moontown-reducer-output.json")
  let exact_source = @fs.read_file(source_path).text()
  @fs.write_file(source_path, exact_source + " ", create_mode=TruncateExisting)
  assert_eq(review_workflow_status(config).state, "review-stale")
  assert_false(
    review_workflow_status(config).decision_receipt.unwrap().source_current,
  )
  assert_eq(
    review_workflow_status(config).decision_receipt.unwrap().rationale,
    request.rationale,
  )
  try ingest_moonchat_result(config, returned) catch {
    _ => ()
  } noraise {
    _ => fail("changed bytes must not qualify")
  }
  assert_eq(
    @fs.read_file(run_artifact(config, review_return_name())).text(),
    receipt_text,
  )
  @fs.write_file(source_path, exact_source, create_mode=TruncateExisting)
  assert_eq(review_workflow_status(config).state, state)
  println("CHOICE_FIXTURE " + outcome + " " + config.workspace)
}

///|
async test "approve exact synthesis retains dissent and a single receipt across reload and two retries" {
  exercise_choice("approve_subset", "ready-for-bookkeeper")
}

///|
async test "reject exact synthesis retains dissent without preparing Bookkeeper across reload and retries" {
  exercise_choice("reject", "review-rejected")
}

///|
async test "defer request changes remains an unresolved named decision across reload and retries" {
  exercise_choice("request_changes", "review-deferred")
}

///|
async test "typed return rejects forged approval reviewer rationale and missing journal before writes" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="find-choice-forged"),
  )
  let source = delivery_fixture(config)
  ignore(
    prepare_cross_product_review(
      config,
      choice_request("reject", source.source_digest),
    ),
  )
  let returned = choice_record(config)
  let record = @review.decode_review_record(@json.parse(returned.record_text))
  for
    forged in [
      {
        ..record,
        accepted: true,
        review_status: "accepted",
        claim_class: "accepted-knowledge",
      },
      { ..record, journal_evidence: [], },
      {
        ..record,
        decision_receipts: [
          {
            ..record.decision_receipts[0],
            reviewer_name: "Different reviewer",
          },
        ],
      },
      {
        ..record,
        entries: [{ ..record.entries[0], body: "Unreviewed replacement", }],
      },
    ] {
    let text = forged.to_json().stringify(indent=2) + "\n"
    try
      ingest_moonchat_result(config, {
        ..returned,
        record_text: text,
        output_digest: @store.digest_text(text),
      })
    catch {
      _ => ()
    } noraise {
      _ => fail("forged return must fail")
    }
    assert_false(@fs.exists(run_artifact(config, review_record_name())))
    assert_false(@fs.exists(run_artifact(config, review_return_name())))
    assert_false(
      @fs.exists(run_artifact(config, "bookkeeper-outcome-submission.json")),
    )
  }
  let linked = ingest_moonchat_result(config, { ..returned, status: "failed", })
  assert_eq(linked.state, "review-rejected")
  let before = @fs.read_file(run_artifact(config, review_return_name())).text()
  try
    ingest_moonchat_result(config, {
      ..returned,
      output_artifact_ref: "changed/result.json",
    })
  catch {
    _ => ()
  } noraise {
    _ => fail("changed return identity must fail")
  }
  assert_eq(
    @fs.read_file(run_artifact(config, review_return_name())).text(),
    before,
  )
  @fs.write_file(
    config.workspace + "/" + record.journal_evidence[0].artifact_ref,
    "{}",
    create_mode=TruncateExisting,
  )
  assert_eq(review_workflow_status(config).state, "review-evidence-invalid")
}

///|
async test "legacy accepted receipt and submission remain unchanged and inspectable without reauthorization" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="find-choice-legacy"),
  )
  let source = delivery_fixture(config)
  ignore(
    prepare_cross_product_review(
      config,
      choice_request("approve_subset", source.source_digest),
    ),
  )
  let legacy_bundle = retained_review_bundle(config)
  // This fixture reconstructs pre-upgrade v1 files, which never had the
  // new typed preparation binding. Production does not delete or migrate it.
  @fs.remove(run_artifact(config, review_prepared_name()))
  @fs.write_file(
    run_artifact(config, "moonchat-review-bundle.json"),
    {
      ..legacy_bundle,
      conversation: {
        ..legacy_bundle.conversation,
        contract_id: "moonsuite-conversation.v1",
      },
    }
    .to_json()
    .stringify(indent=2) +
    "\n",
    create_mode=TruncateExisting,
  )
  let legacy_bundle_bytes = @fs.read_file(
    run_artifact(config, "moonchat-review-bundle.json"),
  ).text()
  let legacy : Json = {
    "contract_id": "moonchat.conversation-review-record.v1",
    "review_id": review_id(config.run_id),
    "source_digest": source.source_digest,
    "source_revision_id": "moontown-\{config.run_id}",
    "review_status": "accepted",
    "accepted": true,
    "claim_class": "accepted-knowledge",
  }
  let text = legacy.stringify(indent=2) + "\n"
  ensure_immutable_review_artifact(
    run_artifact(config, review_record_name()),
    text,
    "historical raw record",
  )
  ensure_immutable_review_artifact(
    run_artifact(config, "bookkeeper-outcome-submission.json"),
    "{\"retained\":true}\n",
    "historical Bookkeeper submission",
  )
  let before = @fs.read_file(run_artifact(config, "run.json")).text()
  let view = review_workflow_status(config).decision_receipt.unwrap()
  assert_eq(view.evidence_status, "legacy-retained")
  assert_eq(view.review_status, "unverified-history")
  try
    prepare_cross_product_review(
      config,
      choice_request("approve_subset", source.source_digest),
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("Legacy bundle must never be rebound as a new typed preparation")
  }
  assert_false(@fs.exists(run_artifact(config, review_prepared_name())))
  assert_eq(
    review_workflow_status(config).decision_receipt.unwrap().evidence_status,
    "legacy-retained",
  )
  let reply = ingest_moonchat_result(config, {
    contract_id: "moonfind.moonchat-result-ingest.v1",
    product_id: "moonchat",
    status: "succeeded",
    output_artifact_ref: "historical/record.json",
    output_digest: @store.digest_text(text),
    record_text: text,
  })
  assert_true(reply.message.contains("Historical"))
  assert_false(@fs.exists(run_artifact(config, review_return_name())))
  assert_eq(@fs.read_file(run_artifact(config, "run.json")).text(), before)
  assert_eq(
    @fs.read_file(run_artifact(config, review_record_name())).text(),
    text,
  )
  assert_eq(
    @fs.read_file(run_artifact(config, "moonchat-review-bundle.json")).text(),
    legacy_bundle_bytes,
  )
}

///|
async test "receipt readback detects changed retained selection and incomplete new return journals" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="find-choice-selection"),
  )
  let source = delivery_fixture(config)
  ignore(
    prepare_cross_product_review(
      config,
      choice_request("approve_subset", source.source_digest),
    ),
  )
  let returned = choice_record(config)
  ignore(ingest_moonchat_result(config, returned))
  let decision : @closed_loop.CrossProductReviewDecision = @json.from_json(
    @store.read_json(run_artifact(config, "cross-product-review-decision.json")),
  )
  @store.write_run_artifact(
    config.workspace,
    config.run_id,
    "cross-product-review-decision.json",
    { ..decision, accepted_idea_ids: ["unreviewed-idea"], }.to_json(),
  )
  assert_eq(review_workflow_status(config).state, "review-evidence-invalid")
  assert_true(review_workflow_status(config).decision_receipt is None)
  let second = model_route_config(
    workspace=@fs.tmpdir(prefix="find-choice-unlinked-corrupt"),
  )
  let source2 = delivery_fixture(second)
  ignore(
    prepare_cross_product_review(
      second,
      choice_request("reject", source2.source_digest),
    ),
  )
  let returned2 = choice_record(second)
  ensure_immutable_review_artifact(
    run_artifact(second, review_record_name()),
    returned2.record_text,
    "interrupted new return",
  )
  @fs.write_file(
    run_artifact(second, "moonchat-events/0.json"),
    "{}",
    create_mode=TruncateExisting,
  )
  assert_eq(review_workflow_status(second).state, "review-evidence-invalid")
}

///|
async test "typed preparation binding repairs exact interrupted preparation and rejects missing scope proof" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="find-prepare-binding-retry"),
  )
  let source = delivery_fixture(config)
  let request = choice_request("request_changes", source.source_digest)
  let first = prepare_cross_product_review(config, request)
  let binding = @fs.read_file(run_artifact(config, review_prepared_name())).text()
  let bundle = @fs.read_file(
    run_artifact(config, "moonchat-review-bundle.json"),
  ).text()
  // Real preparation order is decision -> binding -> bundle. A crash after
  // binding leaves the original decision timestamp available for exact retry.
  @fs.remove(run_artifact(config, "moonchat-review-bundle.json"))
  assert_eq(
    prepare_cross_product_review(config, request).to_json(),
    first.to_json(),
  )
  assert_eq(
    @fs.read_file(run_artifact(config, review_prepared_name())).text(),
    binding,
  )
  assert_eq(
    @fs.read_file(run_artifact(config, "moonchat-review-bundle.json")).text(),
    bundle,
  )
  @fs.remove(run_artifact(config, review_prepared_name()))
  assert_eq(review_workflow_status(config).state, "review-evidence-invalid")
  assert_true(review_workflow_status(config).decision_receipt is None)
  assert_eq(
    prepare_cross_product_review(config, request).to_json(),
    first.to_json(),
  )
  assert_eq(
    review_workflow_status(config).decision_receipt.unwrap().delivery_status,
    "pending-return",
  )
}

///|
async test "legacy bundle without a human receipt is a recoverable error rather than a bounds abort" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="find-legacy-empty-decision"),
  )
  let source = delivery_fixture(config)
  ignore(
    prepare_cross_product_review(
      config,
      choice_request("reject", source.source_digest),
    ),
  )
  let bundle = retained_review_bundle(config)
  @fs.remove(run_artifact(config, review_prepared_name()))
  @store.write_run_artifact(
    config.workspace,
    config.run_id,
    "moonchat-review-bundle.json",
    {
      ..bundle,
      conversation: {
        ..bundle.conversation,
        contract_id: "moonsuite-conversation.v1",
      },
      decision_receipts: [],
    }.to_json(),
  )
  assert_eq(review_workflow_status(config).state, "review-evidence-invalid")
  assert_true(review_workflow_status(config).decision_receipt is None)
}
