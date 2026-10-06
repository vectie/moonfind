///|
async test "reviewer missing saved human receipt returns invalid evidence without crashing snapshot" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="reviewer-missing-receipt"),
  )
  let source = delivery_fixture(config)
  ignore(
    prepare_cross_product_review(
      config,
      choice_request("reject", source.source_digest),
    ),
  )
  let bundle = retained_review_bundle(config)
  @store.write_run_artifact(
    config.workspace,
    config.run_id,
    "moonchat-review-bundle.json",
    { ..bundle, decision_receipts: [], }.to_json(),
  )
  assert_eq(review_workflow_status(config).state, "review-evidence-invalid")
}
