///|
async test "reviewer scoped defer survives failed operation and duplicates with no approval writes" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="reviewer-scoped-defer"),
  )
  let source = delivery_fixture(config)
  let request = {
    ..choice_request("request_changes", source.source_digest),
    rejected_idea_ids: ["idea-1"],
  }
  ignore(prepare_cross_product_review(config, request))
  let returned = { ..choice_record(config), status: "failed", }
  let before = @fs.read_file(run_artifact(config, "run.json")).text()
  let first = ingest_moonchat_result(config, returned)
  assert_eq(first.state, "review-deferred")
  assert_eq(ingest_moonchat_result(config, returned).to_json(), first.to_json())
  let receipt = review_workflow_status(config).decision_receipt.unwrap()
  assert_eq(receipt.accepted_idea_ids, [])
  assert_eq(receipt.rejected_idea_ids, ["idea-1"])
  assert_eq(receipt.review_status, "pending_review")
  assert_eq(receipt.bookkeeper_state, "not-acknowledged")
  assert_eq(@fs.read_file(run_artifact(config, "run.json")).text(), before)
  assert_false(
    @fs.exists(run_artifact(config, "bookkeeper-outcome-submission.json")),
  )
  try
    prepare_cross_product_review(config, { ..request, outcome: "reject", })
  catch {
    _ => ()
  } noraise {
    _ => fail("Saved decision must remain immutable")
  }
  assert_eq(
    review_workflow_status(config).decision_receipt.unwrap().outcome,
    "defer",
  )
}

///|
async test "reviewer journal symlink escaping workspace is refused even with matching bytes and digest" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="reviewer-journal-symlink"),
  )
  let source = delivery_fixture(config)
  ignore(
    prepare_cross_product_review(
      config,
      choice_request("approve_subset", source.source_digest),
    ),
  )
  let returned = choice_record(config)
  let event_path = run_artifact(config, "moonchat-events/0.json")
  let event_text = @fs.read_file(event_path).text()
  let outside = @fs.tmpdir(prefix="reviewer-outside-evidence") + "/event.json"
  @fs.write_file(outside, event_text, create_mode=CreateNew)
  @fs.remove(event_path)
  @fs.symlink(target=outside, event_path)
  try ingest_moonchat_result(config, returned) catch {
    _ => ()
  } noraise {
    _ => fail("Journal symlink may not escape workspace")
  }
  assert_false(@fs.exists(run_artifact(config, review_record_name())))
  assert_false(@fs.exists(run_artifact(config, review_return_name())))
  assert_false(
    @fs.exists(run_artifact(config, "bookkeeper-outcome-submission.json")),
  )
}
