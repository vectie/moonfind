///|
test "town candidate becomes a MoonFind watch and projection" {
  let candidate : TownPackCandidate = {
    contract_id: "moontown.pack-candidate-intake.v1",
    candidate_ref: "dexterous-manipulation",
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
  let watch = intake_research_candidate(
    candidate,
    "dexterous manipulation tactile sensing",
    ["cs.RO"],
    ["dexterous manipulation", "tactile sensing"],
    "weekly",
    "humanoid-robotics",
  )
  assert_eq(watch.max_papers, 50)
  let projection = project_research_watch(
    watch,
    candidate.rationale,
    candidate.evidence_refs,
    candidate.submitted_at,
  )
  assert_eq(projection.subjects[0].schema_id, "research-watch")
  assert_true(
    projection.subjects[0].operation_ids.contains("papers.acquire-arxiv"),
  )
}
