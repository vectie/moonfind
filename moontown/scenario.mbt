///|
pub(all) struct TownParticipant {
  book_id : String
  title : String
  focus_area : String
  perspective : String
  cadence : String
  current_question : String
  contribution : String
  next_artifact : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct TownIdea {
  id : String
  title : String
  summary : String
  participating_books : Array[String]
  research_questions : Array[String]
  why_it_matters : String
  next_experiment : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct TownResearchScenario {
  id : String
  title : String
  communication_pattern_id : String?
  communication_pattern_label : String?
  building_id : String
  building_book_id : String
  domain_label : String
  topic : String
  cadence : String
  interval_ms : UInt64?
  skill_name : String
  skill_description : String
  protocol_channel : String
  reduction_kind : String
  output_channel : String
  review_gate : String
  review_owner : String
  review_reason : String
  backlog_path : String
  synthesis_path : String
  metrics_path : String
  review_path : String
  returned_ideas_path : String
  participant_contract_path : String
  quality_rules : Array[String]
  skill_rules : Array[String]
  participants : Array[TownParticipant]
  ideas : Array[TownIdea]
} derive(Debug, Eq, ToJson, FromJson)

///|
fn paper_book_id(paper_id : String) -> String {
  "moonfind-paper-" +
  paper_id.replace_all(old=".", new="-").replace_all(old="/", new="-")
}

///|
fn paper_summary_for(
  summaries : ArrayView[@research.PaperSummary],
  paper_id : String,
) -> @research.PaperSummary? {
  for summary in summaries {
    if summary.paper_id == paper_id {
      return Some(summary)
    }
  }
  None
}

///|
fn participant_for(
  paper : @research.PaperRecord,
  summaries : ArrayView[@research.PaperSummary],
) -> TownParticipant {
  let summary = paper_summary_for(summaries, paper.paper_id)
  {
    book_id: paper_book_id(paper.paper_id),
    title: paper.title,
    focus_area: paper.categories.join(", "),
    perspective: match summary {
      Some(value) => value.method
      None => paper.abstract_text
    },
    cadence: "per-moonfind-run",
    current_question: match summary {
      Some(value) =>
        value.open_questions.get(0).unwrap_or("What evidence is still missing?")
      None => "What does this paper contribute to a reusable humanoid model?"
    },
    contribution: match summary {
      Some(value) => value.one_sentence
      None => paper.abstract_text
    },
    next_artifact: "records/papers/\{paper.paper_id}/critique.md",
  }
}

///|
fn town_idea(idea : @research.ResearchIdea) -> TownIdea {
  {
    id: idea.idea_id,
    title: idea.title,
    summary: idea.thesis + " Mechanism: " + idea.mechanism,
    participating_books: idea.source_paper_ids.map(paper_book_id),
    research_questions: [idea.counter_hypothesis, idea.falsifier],
    why_it_matters: idea.novelty_claim,
    next_experiment: idea.next_experiment,
  }
}

///|
pub fn cross_paper_scenario(
  run : @research.ResearchRun,
) -> TownResearchScenario raise {
  guard run.papers.length() >= 2 else {
    fail("Moontown cross-paper synthesis requires at least two papers")
  }
  {
    id: "moonfind-\{run.run_id}",
    title: "Moonfind Humanoid Cross-Paper Research Salon",
    communication_pattern_id: Some("research-salon"),
    communication_pattern_label: Some("Research Salon"),
    building_id: "moonfind-research-salon",
    building_book_id: "moonfind-synthesis-book",
    domain_label: "humanoid robotics model research",
    topic: run.watch.title,
    cadence: run.watch.cadence,
    interval_ms: Some(86400000UL),
    skill_name: "moonfind-humanoid-synthesis",
    skill_description: "Challenge claims across arXiv papers and synthesize falsifiable humanoid model ideas.",
    protocol_channel: "moonfind.research.cross-paper.v1",
    reduction_kind: "evidence-backed-idea-synthesis",
    output_channel: "moonfind.research.ideas.v1",
    review_gate: "named-human",
    review_owner: "moonbook.bookkeeper",
    review_reason: "Cross-paper novelty claims and model experiments require evidence and human technical review.",
    backlog_path: "research/backlog.md",
    synthesis_path: "research/cross-paper-synthesis.md",
    metrics_path: "research/metrics.md",
    review_path: "reviews/moonfind-synthesis.md",
    returned_ideas_path: "research/returned-ideas.md",
    participant_contract_path: "research/participant-contract.md",
    quality_rules: [
      "Every idea must connect at least two participant paper books.", "Every novelty claim must retain exact arXiv paper identifiers.",
      "Every model idea must name a counter-hypothesis, falsifier and next experiment.",
      "No reducer output is accepted without named-human review.",
    ],
    skill_rules: [
      "Separate reported facts, inference and proposed experiments.", "Surface contradictions instead of averaging them away.",
      "Prefer the smallest experiment that can falsify the proposed bridge.",
    ],
    participants: run.papers.map(fn(paper) {
      participant_for(paper, run.summaries)
    }),
    ideas: run.ideas.map(town_idea),
  }
}
