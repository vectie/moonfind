///|
fn unique_nonblank(values : ArrayView[String]) -> Bool {
  let seen : Array[String] = []
  for value in values {
    if value.is_blank() || seen.contains(value) {
      return false
    }
    seen.push(value)
  }
  true
}

///|
pub fn validate_watch(watch : ResearchWatch) -> Array[String] {
  let issues : Array[String] = []
  if watch.watch_id.is_blank() {
    issues.push("watch_id is required")
  }
  if watch.title.is_blank() || watch.query.is_blank() {
    issues.push("watch title and query are required")
  }
  if watch.max_papers < 2 || watch.max_papers > 100 {
    issues.push("max_papers must be between 2 and 100")
  }
  if !unique_nonblank(watch.categories) || !unique_nonblank(watch.keywords) {
    issues.push("watch categories and keywords must be unique and non-empty")
  }
  if watch.cadence.is_blank() || watch.domain_profile.is_blank() {
    issues.push("watch cadence and domain profile are required")
  }
  issues
}

///|
pub fn start_research_run(
  run_id : String,
  watch : ResearchWatch,
  papers : Array[PaperRecord],
  started_at : Int64,
) -> ResearchRun raise {
  guard run_id != "" && started_at >= 0 else {
    fail("run identity and non-negative start time are required")
  }
  let watch_issues = validate_watch(watch)
  guard watch_issues.is_empty() else {
    fail("invalid research watch: \{watch_issues.join("; ")}")
  }
  guard papers.length() >= 2 else {
    fail("cross-paper research requires at least two papers")
  }
  let paper_ids : Array[String] = []
  for paper in papers {
    guard !paper.paper_id.is_blank() &&
      !paper.title.is_blank() &&
      !paper.abstract_text.is_blank() &&
      !paper.source_digest.is_blank() &&
      !paper_ids.contains(paper.paper_id) else {
      fail("paper records must be complete and uniquely identified")
    }
    paper_ids.push(paper.paper_id)
  }
  {
    contract_version: research_contract_version(),
    run_id,
    watch,
    status: "awaiting-agent-analysis",
    papers,
    summaries: [],
    questions: [],
    ideas: [],
    synthesis_notes: [],
    validation_issues: [],
    started_at,
    completed_at: None,
    human_review_status: "pending",
    accepted_idea_ids: [],
  }
}

///|
fn paper_exists(papers : ArrayView[PaperRecord], paper_id : String) -> Bool {
  papers.any(fn(paper) { paper.paper_id == paper_id })
}

///|
fn cited_sources_valid(
  papers : ArrayView[PaperRecord],
  paper_ids : ArrayView[String],
  minimum : Int,
) -> Bool {
  paper_ids.length() >= minimum &&
  unique_nonblank(paper_ids) &&
  paper_ids.all(fn(paper_id) { paper_exists(papers, paper_id) })
}

///|
pub fn validate_analysis_result(
  run : ResearchRun,
  result : ResearchAnalysisResult,
) -> Array[String] {
  let issues : Array[String] = []
  if result.contract_version != research_contract_version() {
    issues.push("analysis result contract version mismatch")
  }
  if result.result_id.is_blank() || result.model != "gpt-5.6-sol" {
    issues.push("analysis must identify a result and use gpt-5.6-sol")
  }
  let summary_ids : Array[String] = []
  for summary in result.summaries {
    if !paper_exists(run.papers, summary.paper_id) ||
      summary_ids.contains(summary.paper_id) {
      issues.push(
        "summary has an unknown or duplicate paper: \{summary.paper_id}",
      )
    } else {
      summary_ids.push(summary.paper_id)
    }
    if summary.one_sentence.is_blank() ||
      summary.problem.is_blank() ||
      summary.method.is_blank() ||
      summary.evidence.is_blank() ||
      summary.limitations.is_empty() ||
      summary.open_questions.is_empty() {
      issues.push("summary is incomplete: \{summary.paper_id}")
    }
    for claim in summary.claims {
      if claim.claim_id.is_blank() ||
        claim.statement.is_blank() ||
        claim.evidence_location.is_blank() ||
        !cited_sources_valid(run.papers, claim.paper_ids, 1) {
        issues.push("claim is incomplete or uncited: \{claim.claim_id}")
      }
    }
  }
  if summary_ids.length() != run.papers.length() {
    issues.push("every selected paper requires exactly one summary")
  }
  for question in result.questions {
    if question.question_id.is_blank() ||
      question.question.is_blank() ||
      question.missing_evidence.is_empty() ||
      question.next_check.is_blank() ||
      !cited_sources_valid(run.papers, question.source_paper_ids, 1) {
      issues.push("research question is incomplete: \{question.question_id}")
    }
  }
  let idea_ids : Array[String] = []
  for idea in result.ideas {
    if idea.idea_id.is_blank() || idea_ids.contains(idea.idea_id) {
      issues.push("idea identity is missing or duplicated: \{idea.idea_id}")
    } else {
      idea_ids.push(idea.idea_id)
    }
    if idea.title.is_blank() ||
      idea.thesis.is_blank() ||
      idea.mechanism.is_blank() ||
      idea.cross_paper_bridge.is_blank() ||
      idea.novelty_claim.is_blank() ||
      idea.counter_hypothesis.is_blank() ||
      idea.risks.is_empty() ||
      idea.falsifier.is_blank() ||
      idea.next_experiment.is_blank() ||
      !cited_sources_valid(run.papers, idea.source_paper_ids, 2) {
      issues.push(
        "cross-paper idea is incomplete or weakly sourced: \{idea.idea_id}",
      )
    }
  }
  if result.ideas.is_empty() {
    issues.push("analysis produced no cross-paper ideas")
  }
  issues
}

///|
pub fn complete_research_run(
  run : ResearchRun,
  result : ResearchAnalysisResult,
  completed_at : Int64,
) -> ResearchRun raise {
  guard completed_at >= run.started_at else {
    fail("research completion cannot precede run start")
  }
  let issues = validate_analysis_result(run, result)
  {
    ..run,
    status: if issues.is_empty() {
      "human-review"
    } else {
      "blocked"
    },
    summaries: result.summaries.copy(),
    questions: result.questions.copy(),
    ideas: result.ideas.copy(),
    synthesis_notes: result.synthesis_notes.copy(),
    validation_issues: issues,
    completed_at: Some(completed_at),
  }
}

///|
pub fn ResearchRun::apply_human_review(
  self : ResearchRun,
  review : HumanResearchReview,
) -> ResearchRun raise {
  guard self.status == "human-review" &&
    review.run_id == self.run_id &&
    !review.review_id.is_blank() &&
    !review.reviewer_id.is_blank() &&
    !review.authority_ref.is_blank() &&
    review.reviewed_at >= self.started_at &&
    (
      review.disposition == "accept" ||
      review.disposition == "revise" ||
      review.disposition == "reject"
    ) else {
    fail("invalid or unauthorized human research review")
  }
  let known = self.ideas.map(fn(idea) { idea.idea_id })
  guard review.accepted_idea_ids.all(fn(id) { known.contains(id) }) &&
    review.rejected_idea_ids.all(fn(id) { known.contains(id) }) else {
    fail("human review references unknown ideas")
  }
  {
    ..self,
    status: if review.disposition == "accept" {
      "accepted"
    } else {
      "closed"
    },
    human_review_status: review.disposition,
    accepted_idea_ids: review.accepted_idea_ids.copy(),
  }
}
