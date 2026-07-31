///|
test "research journey keeps one deterministic next action" {
  assert_eq(
    research_journey_state(
      false, false, "not-ready", "not-ready", "not-ready", false,
    ).target,
    "reload",
  )
  assert_eq(
    research_journey_state(
      true, false, "not-ready", "prepared", "not-ready", false,
    ).target,
    "research",
  )
  assert_eq(
    research_journey_state(
      true, true, "ready", "needs-review", "not-ready", false,
    ).target,
    "moontown",
  )
  assert_eq(
    research_journey_state(
      true, true, "completed", "needs-review", "ready-for-human-review", false,
    ).target,
    "review",
  )
}

///|
test "failed journey exposes recovery instead of a duplicate run" {
  let journey = research_journey_state(
    true, true, "completed", "runtime-unknown", "not-ready", true,
  )
  assert_eq(journey.action, "Reload state")
  assert_true(journey.detail.contains("same attempt"))
}

///|
test "series selector resolves only the chosen validated catalog entry" {
  let scenario : SeriesUseCaseProjection = {
    contract_id: "moonsuite.series-use-case.v1",
    use_case_id: "research-decision-series",
    title: "Research Decision Series",
    summary: "A governed decision package.",
    primary_user: "program owner",
    primary_action: "Review the commission",
    completion_statement: "Named digital decision recorded.",
    phases: [
      {
        phase_id: "research",
        title: "Research",
        outcome: "Cited evidence",
        product_ids: ["moonfind", "moontown"],
        stage_ids: ["research-habitat-evidence"],
      },
    ],
    graph: {
      graph_id: "research-decision-series-v1",
      stages: [
        {
          stage_id: "research-habitat-evidence",
          product_id: "moonfind",
          desired_operation_ref: Some("moonfind/research.evidence@0.1.0"),
        },
      ],
      intentional_exclusions: Some([]),
    },
  }
  let model = {
    ..initial_model(),
    series_catalog: [scenario],
    selected_series_id: "research-decision-series",
  }
  assert_true(
    selected_series(model) is Some(value) &&
    value.primary_user == "program owner",
  )
  assert_true(series_template_issues(scenario).is_empty())
}
