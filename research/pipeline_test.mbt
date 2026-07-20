///|
fn sample_watch() -> ResearchWatch {
  {
    watch_id: "watch-vla",
    title: "Embodied agent evidence",
    query: "vision language action",
    categories: ["cs.RO"],
    keywords: ["robotics", "agent"],
    negative_keywords: [],
    max_papers: 10,
    cadence: "daily",
    domain_profile: "robotics-research",
  }
}

///|
fn sample_paper(id : String, title : String) -> PaperRecord {
  {
    paper_id: id,
    versioned_id: id + "v1",
    title,
    abstract_text: "A bounded abstract with inspectable evidence.",
    authors: ["Researcher"],
    categories: ["cs.RO"],
    published_at: "2026-07-01",
    updated_at: "2026-07-01",
    abs_url: "https://example.invalid/abs/" + id,
    pdf_url: "https://example.invalid/pdf/" + id,
    source_digest: "sha256:" + id,
    retrieved_at: 1L,
    relevance_score: 80,
    relevance_reasons: ["matches the governed watch"],
  }
}

///|
test "research starts only from a valid multi-paper evidence set" {
  let first = sample_paper("paper-a", "Paper A")
  let second = sample_paper("paper-b", "Paper B")
  let run = start_research_run("run-1", sample_watch(), [first, second], 10L)
  assert_eq(run.status, "awaiting-agent-analysis")
  assert_eq(run.papers.length(), 2)
  let duplicate_rejected = try {
    ignore(
      start_research_run("run-duplicate", sample_watch(), [first, first], 10L),
    )
    false
  } catch {
    _ => true
  }
  assert_true(duplicate_rejected)
}
