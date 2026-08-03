///|
test "lunar habitat series is complete, ordered, and fail-closed" {
  let scenario = @series.lunar_habitat_decision_series()
  assert_eq(scenario.graph.stages.length(), 38)
  assert_eq(scenario.phases.length(), 6)
  assert_eq(
    scenario.graph.source_digest,
    "sha256:3c95e516d9d47301a7312cccd69d2fa257a45d7a58fc949c41474508b1b2fab5",
  )
  assert_true(@series.validate(scenario).is_empty())
  assert_true(
    scenario.graph.stages.any(stage => stage.product_id == "moonmold"),
  )
  assert_true(
    scenario.graph.stages.any(stage => stage.product_id == "moonmoon"),
  )
  assert_true(
    scenario.graph.stages.any(stage => stage.product_id == "moonrobo"),
  )
  assert_true(
    scenario.graph.stages.any(stage => stage.product_id == "mooncast"),
  )
  assert_true(
    scenario.graph.stages.any(stage => {
      stage.desired_operation_ref ==
      Some("mooncast/asset-factory.generate@0.2.0")
    }),
  )
  assert_true(
    scenario.graph.stages.any(stage => {
      stage.desired_operation_ref ==
      Some("mooncast/needs-intake.approve-and-seed@0.3.0")
    }),
  )
  assert_eq(
    scenario.graph.stages
    .filter(stage => {
      stage.desired_operation_ref ==
      Some("mooncast/asset-factory.generate@0.2.0")
    })
    .length(),
    3,
  )
  assert_eq(
    scenario.graph.stages
    .filter(stage => {
      stage.desired_operation_ref == Some("mooncast/asset-factory.review@0.2.0")
    })
    .length(),
    3,
  )
  assert_true(
    scenario.graph.stages.all(stage => {
      stage.desired_operation_ref != Some("mooncast/project.advance@0.2.0")
    }),
  )
  assert_true(
    scenario.graph.stages.all(stage => {
      stage.desired_operation_ref != Some("mooncast/client-portal.create@0.2.0")
    }),
  )
  assert_true(
    scenario.graph.stages.all(stage => stage.product_id != "moonfish"),
  )
  let exclusions = scenario.graph.intentional_exclusions.unwrap_or([])
  assert_true(
    exclusions.any(fn(item) {
      item is Object(fields) &&
      fields.get("capability") is Some(String(value)) &&
      value == "physical robot command"
    }),
  )
  assert_true(
    exclusions.any(fn(item) {
      item is Object(fields) &&
      fields.get("capability") is Some(String(value)) &&
      value == "publication"
    }),
  )
}

///|
test "series catalog resolves the exact scenario" {
  assert_true(
    @series.find("lunar-habitat-decision-series") is Some(scenario) &&
    scenario.primary_action ==
    "Review the commission and start evidence gathering",
  )
  assert_true(@series.find("invented-series") is None)
}
