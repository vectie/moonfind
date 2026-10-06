///|
async test "missing completed artifacts preserve readable workspace without a fabricated result" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="find-result-missing"),
  )
  qa_fixture_workspace(config)
  let snapshot = workspace_snapshot_with(config, gateway_reachable=_ => false)
  assert_true(
    snapshot.moontown_result is Some({ state: "unavailable", output: None, .. }),
  )
  assert_eq(snapshot.workspace.run_id, config.run_id)
  assert_false(@fs.exists(run_artifact(config, "moontown-reducer-output.json")))
}

///|
test "review digest is optional for old callers and exact for result-aware clients" {
  let legacy : ReviewPrepareRequestV1 = @json.from_json({
    "contract_id": "moonfind.review-prepare-request.v1",
    "reviewer_name": "Fixture reviewer",
    "outcome": "approve_subset",
    "accepted_idea_ids": ["idea-1"],
    "rejected_idea_ids": [],
    "rationale": "Test evidence",
    "information_gap": { "present": false, "severity": 0, "summary": "" },
    "recognition_gap": { "present": false, "severity": 0, "summary": "" },
    "decisiveness_gap": { "present": false, "severity": 0, "summary": "" },
  })
  assert_true(legacy.source_digest is None)
  validate_displayed_result_digest(legacy, "sha256:current")
  validate_displayed_result_digest(
    { ..legacy, source_digest: Some("sha256:current"), },
    "sha256:current",
  )
  let rejected = try {
    validate_displayed_result_digest(
      { ..legacy, source_digest: Some("sha256:old"), },
      "sha256:current",
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
