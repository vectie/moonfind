///|
pub(all) struct MoonClawResearchCommand {
  protocol : String
  session_id : String
  book_root : String
  command : String
  model : String
  capability_scope_id : String
  capability_participant_id : String
  text : String
  packet : Json
} derive(Debug, Eq, ToJson, FromJson)

///|
fn paper_context(paper : @research.PaperRecord) -> Json {
  {
    "paper_id": paper.paper_id,
    "versioned_id": paper.versioned_id,
    "title": paper.title,
    "abstract": paper.abstract_text,
    "authors": paper.authors,
    "categories": paper.categories,
    "published_at": paper.published_at,
    "source_digest": paper.source_digest,
    "relevance_score": paper.relevance_score,
    "relevance_reasons": paper.relevance_reasons,
  }
}

///|
fn humanoid_output_contract() -> String {
  let contract =
    #|Return exactly one JSON object matching moonfind.research.v1. Summarize every supplied paper separately. Every claim must cite known paper_ids and an evidence location. Every generated idea must bridge at least two distinct papers, state a counter-hypothesis, risks, a falsifier, and a next experiment. Each idea.domain_payload must contain: model_name, target_capability, backbone, observation_tokens, memory_state, action_representation, training_objectives, training_stages, dataset_plan, simulation_plan, hardware_assumptions, evaluation_benchmarks, required_ablations, safety_constraints, and falsification_metric. Do not claim experimental results that are absent from the supplied evidence.
  contract
}

///|
pub fn prepare_humanoid_analysis_command(
  run : @research.ResearchRun,
  book_root : String,
  participant_id : String,
) -> MoonClawResearchCommand raise {
  guard run.status == "awaiting-agent-analysis" &&
    !book_root.is_blank() &&
    !participant_id.is_blank() else {
    fail("analysis command requires a collected run, book root and participant")
  }
  let papers = run.papers.map(paper_context)
  {
    protocol: "moonclaw.mooncode.v1",
    session_id: "moonfind-\{run.run_id}",
    book_root,
    command: "prompt",
    model: "gpt-5.6-sol",
    capability_scope_id: "moonfind.humanoid.synthesis",
    capability_participant_id: participant_id,
    text: "Analyze the selected arXiv papers and generate evidence-backed humanoid robotics model ideas through cross-paper synthesis.",
    packet: {
      "command_id": "moonfind-analysis-\{run.run_id}",
      "product_id": "moonfind",
      "run_id": run.run_id,
      "watch": run.watch,
      "papers": Json::array(papers),
      "output_contract": humanoid_output_contract(),
      "required_review": "named-human",
      "owner_route": "moonfind.humanoid-models",
    },
  }
}
