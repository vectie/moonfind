///|
pub(all) struct ResearchWorkspaceProjection {
  product_id : String
  title : String
  run_id : String
  status : String
  watch_title : String
  query : String
  paper_count : Int
  summary_count : Int
  idea_count : Int
  question_count : Int
  accepted_idea_count : Int
  pipeline : Array[String]
  active_stage : String
  papers : Array[@research.PaperRecord]
  summaries : Array[@research.PaperSummary]
  ideas : Array[@research.ResearchIdea]
  questions : Array[@research.ResearchQuestion]
  validation_issues : Array[String]
  bookkeeper_route : String
  three_gap_state : String
} derive(Debug, Eq, ToJson, FromJson)

///|
fn active_stage(status : String) -> String {
  match status {
    "awaiting-agent-analysis" => "MoonClaw analysis"
    "human-review" => "Named human review"
    "accepted" => "Bookkeeper outcome learning"
    "blocked" => "Evidence repair"
    _ => "Closed"
  }
}

///|
pub fn project_research_workspace(
  run : @research.ResearchRun,
) -> ResearchWorkspaceProjection {
  {
    product_id: "moonfind",
    title: "Moonfind Research Studio",
    run_id: run.run_id,
    status: run.status,
    watch_title: run.watch.title,
    query: run.watch.query,
    paper_count: run.papers.length(),
    summary_count: run.summaries.length(),
    idea_count: run.ideas.length(),
    question_count: run.questions.length(),
    accepted_idea_count: run.accepted_idea_ids.length(),
    pipeline: [
      "arXiv intake", "paper normalization", "MoonClaw analysis", "Moontown cross-paper salon",
      "named human review", "Bookkeeper Three-Gap learning",
    ],
    active_stage: active_stage(run.status),
    papers: run.papers.copy(),
    summaries: run.summaries.copy(),
    ideas: run.ideas.copy(),
    questions: run.questions.copy(),
    validation_issues: run.validation_issues.copy(),
    bookkeeper_route: "moonbook.bookkeeper",
    three_gap_state: if run.status == "accepted" {
      "ready-for-outcome-binding"
    } else {
      "waiting-for-accepted-outcome"
    },
  }
}
