///|
test "general brief accepts a single local source without specialized paper-pair requirements" {
  let brief : @research.ResearchBriefV1 = {
    contract_id: "moonfind.research-brief.v1",
    brief_id: "one-source",
    parent_revision: None,
    question: "What should we measure next?",
    objective: "Prepare a bounded investigation",
    audience: "Operator",
    decision: "Pick a next check",
    source_restrictions: "Local bytes only",
    requested_filenames: ["result.md"],
    acceptance_criteria: "Separate claims and unknowns",
    sources: [
      {
        name: "notes.txt",
        origin: "User notes",
        captured_at: "2026-10-07T00:00:00Z",
        kind: "pasted-text",
        content_hex: "6162",
      },
    ],
  }
  assert_eq(@research.brief_issues(brief), [])
  assert_true(@research.brief_boundary().contains("Prepared brief only"))
  assert_true(@research.brief_issues({ ..brief, objective: "", }).length() > 0)
}
