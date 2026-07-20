///|
pub fn research_watch() -> @research.ResearchWatch {
  {
    watch_id: "humanoid-models-arxiv",
    title: "Humanoid Robotics Model Research",
    query: "(all:humanoid AND all:robot) OR (all:whole-body AND cat:cs.RO) OR (all:vision-language-action AND cat:cs.RO)",
    categories: ["cs.RO", "cs.AI", "cs.CV", "cs.LG"],
    keywords: [
      "humanoid", "whole-body", "vision-language-action", "foundation model", "locomotion",
      "manipulation", "world model", "teleoperation", "sim-to-real", "embodied",
    ],
    negative_keywords: ["social media", "human pose estimation only"],
    max_papers: 12,
    cadence: "0 8 * * * Asia/Shanghai",
    domain_profile: "moonfind.humanoid-models.v1",
  }
}

///|
pub(all) struct HumanoidModelSpecification {
  model_name : String
  target_capability : String
  backbone : String
  observation_tokens : Array[String]
  memory_state : String
  action_representation : String
  training_objectives : Array[String]
  training_stages : Array[String]
  dataset_plan : Array[String]
  simulation_plan : String
  hardware_assumptions : Array[String]
  evaluation_benchmarks : Array[String]
  required_ablations : Array[String]
  safety_constraints : Array[String]
  falsification_metric : String
} derive(Debug, Eq, ToJson, FromJson)

///|
fn contains_any(text : String, terms : ArrayView[String]) -> Array[String] {
  let matched : Array[String] = []
  let lowered = text.to_lower()
  for term in terms {
    if lowered.contains(term.to_lower()) {
      matched.push(term)
    }
  }
  matched
}

///|
pub fn score_paper(paper : @research.PaperRecord) -> @research.PaperRecord {
  let watch = research_watch()
  let text = paper.title + " " + paper.abstract_text
  let matched = contains_any(text, watch.keywords)
  let excluded = contains_any(text, watch.negative_keywords)
  let mut score = matched.length() * 9 - excluded.length() * 30
  let reasons : Array[String] = []
  if paper.categories.contains("cs.RO") {
    score += 25
    reasons.push("primary robotics category")
  }
  if paper.title.to_lower().contains("humanoid") {
    score += 20
    reasons.push("humanoid appears in title")
  }
  for term in matched {
    reasons.push("matched: " + term)
  }
  { ..paper, relevance_score: score, relevance_reasons: reasons }
}

///|
pub fn rank_papers(
  papers : ArrayView[@research.PaperRecord],
) -> Array[@research.PaperRecord] {
  let ranked = papers
    .map(score_paper)
    .filter(fn(paper) { paper.relevance_score >= 20 })
  ranked.sort_by(fn(left, right) {
    let by_score = right.relevance_score.compare(left.relevance_score)
    if by_score != 0 {
      by_score
    } else {
      right.updated_at.compare(left.updated_at)
    }
  })
  if ranked.length() > research_watch().max_papers {
    ranked[:research_watch().max_papers].to_owned()
  } else {
    ranked
  }
}

///|
pub fn validate_model_specification(
  specification : HumanoidModelSpecification,
) -> Array[String] {
  let issues : Array[String] = []
  if specification.model_name.is_blank() ||
    specification.target_capability.is_blank() ||
    specification.backbone.is_blank() ||
    specification.memory_state.is_blank() ||
    specification.action_representation.is_blank() {
    issues.push(
      "model identity, target, backbone, memory and action representation are required",
    )
  }
  if specification.observation_tokens.length() < 2 ||
    specification.training_objectives.length() < 2 ||
    specification.training_stages.length() < 2 ||
    specification.dataset_plan.length() < 2 {
    issues.push(
      "model idea needs multi-modal inputs and a multi-stage training plan",
    )
  }
  if specification.evaluation_benchmarks.length() < 2 ||
    specification.required_ablations.is_empty() ||
    specification.safety_constraints.is_empty() ||
    specification.falsification_metric.is_blank() {
    issues.push(
      "model idea needs benchmarks, ablations, safety constraints and a falsifier",
    )
  }
  issues
}

///|
pub fn validate_humanoid_analysis(
  run : @research.ResearchRun,
  result : @research.ResearchAnalysisResult,
) -> Array[String] {
  let issues = @research.validate_analysis_result(run, result)
  for idea in result.ideas {
    let specification : HumanoidModelSpecification = @json.from_json(
      idea.domain_payload,
    ) catch {
      _ => {
        issues.push("humanoid model payload is invalid: \{idea.idea_id}")
        continue
      }
    }
    for issue in validate_model_specification(specification) {
      issues.push("\{idea.idea_id}: \{issue}")
    }
  }
  issues
}

///|
pub fn complete_humanoid_run(
  run : @research.ResearchRun,
  result : @research.ResearchAnalysisResult,
  completed_at : Int64,
) -> @research.ResearchRun raise {
  let completed = @research.complete_research_run(run, result, completed_at)
  let issues = validate_humanoid_analysis(run, result)
  {
    ..completed,
    status: if issues.is_empty() {
      "human-review"
    } else {
      "blocked"
    },
    validation_issues: issues,
  }
}
