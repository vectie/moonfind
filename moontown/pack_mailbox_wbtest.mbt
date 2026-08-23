///|
async test "delivered research candidates publish one idempotent draft watch" {
  let workspace = @fs.tmpdir(prefix="moonfind-town-bridge")
  let candidate : TownPackCandidate = {
    contract_id: "moontown.pack-candidate-intake.v1",
    candidate_ref: "town/candidates/dexterous-manipulation",
    origin_ref: "town/ideas/dexterous-manipulation",
    target_pack_id: "moonfind",
    intake_operation_id: "research.candidate.intake",
    submitted_by: "robotics-salon",
    submitted_at: "2026-08-23T10:00:00Z",
    title: "Dexterous manipulation watch",
    rationale: "The salon found an unresolved evidence gap.",
    claim_ceiling: "research-evidence",
    evidence_refs: ["evidence/robotics-salon.json"],
    domain_payload: {},
  }
  let key = bridge_mailbox_key(candidate.candidate_ref)
  bridge_write_json(
    bridge_root(workspace) + "/inbox/candidates/\{key}.json",
    candidate.to_json(),
  )
  let projection = prepare_research_candidate(
    workspace,
    candidate,
    "dexterous manipulation tactile sensing",
    ["cs.RO"],
    ["dexterous manipulation", "tactile sensing"],
    "weekly",
    "humanoid-robotics",
    "2026-08-24T10:00:00Z",
  )
  assert_eq(projection.subjects.length(), 1)
  assert_eq(projection.subjects[0].lifecycle_state, "watch-draft")
  let replayed = prepare_research_candidate(
    workspace,
    candidate,
    "dexterous manipulation tactile sensing",
    ["cs.RO"],
    ["dexterous manipulation", "tactile sensing"],
    "weekly",
    "humanoid-robotics",
    "2026-08-24T10:00:00Z",
  )
  assert_eq(replayed.subjects.length(), 1)
  let acknowledgement = @fs.read_file(
    bridge_root(workspace) + "/outbox/candidate-receipts/\{key}.json",
  ).text()
  assert_true(acknowledgement.contains("received"))
  @fs.rmdir(workspace, recursive=true)
}
