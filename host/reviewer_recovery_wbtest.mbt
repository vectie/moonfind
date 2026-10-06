///|
async test "reviewer interrupted new approval cannot be relabeled historical when its journal is damaged" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="reviewer-new-interrupted"),
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
  // The production write order saves the submission/run/workspace before
  // the producer return marker. Removing only that marker reconstructs
  // that real crash window without changing the v2 decision or bundle.
  @fs.remove(run_artifact(config, review_return_name()))
  @fs.write_file(
    run_artifact(config, "moonchat-events/0.json"),
    "{}",
    create_mode=TruncateExisting,
  )
  let status = review_workflow_status(config)
  println(
    "NEW_DAMAGED_APPROVAL state=" +
    status.state +
    " evidence=" +
    status.decision_receipt.map(r => r.evidence_status).unwrap_or("none"),
  )
  let replay_state = ingest_moonchat_result(config, returned).state catch {
      _ => "refused"
    }
  println("NEW_DAMAGED_APPROVAL replay=" + replay_state)
  assert_eq(status.state, "review-evidence-invalid")
  assert_eq(replay_state, "refused")
}

///|
async test "reviewer pending decision scope must agree with immutable MoonChat bundle before readback" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="reviewer-pending-scope"),
  )
  let source = delivery_fixture(config)
  ignore(
    prepare_cross_product_review(
      config,
      choice_request("approve_subset", source.source_digest),
    ),
  )
  let decision : @closed_loop.CrossProductReviewDecision = @json.from_json(
    @store.read_json(run_artifact(config, "cross-product-review-decision.json")),
  )
  @store.write_run_artifact(
    config.workspace,
    config.run_id,
    "cross-product-review-decision.json",
    { ..decision, accepted_idea_ids: ["unreviewed-idea"], }.to_json(),
  )
  let status = review_workflow_status(config)
  println(
    "CHANGED_PENDING_SCOPE state=" +
    status.state +
    " accepted=" +
    status.decision_receipt
    .map(r => r.accepted_idea_ids.join(","))
    .unwrap_or("none"),
  )
  assert_eq(status.state, "review-evidence-invalid")
}

///|
async test "reviewer intact interrupted approval retries deterministically without duplicating its submission" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="reviewer-intact-retry"),
  )
  let source = delivery_fixture(config)
  let request = choice_request("approve_subset", source.source_digest)
  let first_prepare = prepare_cross_product_review(config, request)
  assert_eq(
    prepare_cross_product_review(config, request).to_json(),
    first_prepare.to_json(),
  )
  let returned = choice_record(config)
  let first = ingest_moonchat_result(config, returned)
  let submission = @fs.read_file(
    run_artifact(config, "bookkeeper-outcome-submission.json"),
  ).text()
  let run = @fs.read_file(run_artifact(config, "run.json")).text()
  @fs.remove(run_artifact(config, review_return_name()))
  let retry = ingest_moonchat_result(config, returned)
  assert_eq(first.to_json(), retry.to_json())
  assert_eq(
    @fs.read_file(run_artifact(config, "bookkeeper-outcome-submission.json")).text(),
    submission,
  )
  assert_eq(@fs.read_file(run_artifact(config, "run.json")).text(), run)
  assert_eq(
    review_workflow_status(config).decision_receipt.unwrap().delivery_status,
    "linked",
  )
}

///|
async test "reviewer failed approving operation has no saved approval or Bookkeeper effects" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="reviewer-failed-approval"),
  )
  let source = delivery_fixture(config)
  ignore(
    prepare_cross_product_review(
      config,
      choice_request("approve_subset", source.source_digest),
    ),
  )
  let returned = choice_record(config)
  let before = @fs.read_file(run_artifact(config, "run.json")).text()
  try ingest_moonchat_result(config, { ..returned, status: "failed", }) catch {
    _ => ()
  } noraise {
    _ => fail("Failed approving operation must be rejected")
  }
  assert_false(@fs.exists(run_artifact(config, review_record_name())))
  assert_false(@fs.exists(run_artifact(config, review_return_name())))
  assert_false(
    @fs.exists(run_artifact(config, "bookkeeper-outcome-submission.json")),
  )
  assert_eq(@fs.read_file(run_artifact(config, "run.json")).text(), before)
}

///|
async test "reviewer reversed journal sequence fails closed before recording or accepting anything" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="reviewer-journal-order"),
  )
  let source = delivery_fixture(config)
  ignore(
    prepare_cross_product_review(
      config,
      choice_request("approve_subset", source.source_digest),
    ),
  )
  let returned = choice_record(config)
  let record = @review.decode_review_record(@json.parse(returned.record_text))
  let evidence = record.journal_evidence.copy()
  let first = evidence[0]
  evidence[0] = evidence[1]
  evidence[1] = first
  let text = { ..record, journal_evidence: evidence, }
    .to_json()
    .stringify(indent=2) +
    "\n"
  try
    ingest_moonchat_result(config, {
      ..returned,
      record_text: text,
      output_digest: @store.digest_text(text),
    })
  catch {
    _ => ()
  } noraise {
    _ => fail("Reordered journal must be refused")
  }
  assert_false(@fs.exists(run_artifact(config, review_return_name())))
  assert_false(
    @fs.exists(run_artifact(config, "bookkeeper-outcome-submission.json")),
  )
}
