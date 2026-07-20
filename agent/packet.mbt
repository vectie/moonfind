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
fn full_text_context(evidence : @hardening.FullTextEvidence) -> Json {
  {
    "evidence_id": evidence.evidence_id,
    "paper_id": evidence.paper_id,
    "provider_id": evidence.provider_id,
    "pdf_digest": evidence.pdf_digest,
    "extracted_text_digest": evidence.extracted_text_digest,
    "extracted_text_artifact": evidence.extracted_text_artifact,
    "evidence_locations": evidence.evidence_locations,
    "isolation_receipt_id": evidence.isolation_receipt.receipt_id,
    "license_terms_ref": evidence.provider_decision.terms_ref,
  }
}

///|
fn humanoid_output_contract() -> String {
  let contract =
    #|Return exactly one JSON object matching moonfind.research.v1. Summarize every supplied paper separately. Every claim must cite known paper_ids and an evidence location. Every generated idea must bridge at least two distinct papers, state a counter-hypothesis, risks, a falsifier, and a next experiment. Each idea.domain_payload must contain: model_name, target_capability, backbone, observation_tokens, memory_state, action_representation, training_objectives, training_stages, dataset_plan, simulation_plan, hardware_assumptions, evaluation_benchmarks, required_ablations, safety_constraints, and falsification_metric. Do not claim experimental results that are absent from the supplied evidence.
  contract
}

///|
fn packet_string(packet : Json, key : String) -> String? {
  match packet {
    Object(fields) =>
      match fields.get(key) {
        Some(String(value)) => Some(value)
        _ => None
      }
    _ => None
  }
}

///|
/// Verifies that a Moonfind packet delegates only the model loop to MoonClaw.
/// Research ownership, review, capability activation, and external effects
/// remain outside the runtime command.
pub fn research_command_responsibility_issues(
  command : MoonClawResearchCommand,
) -> Array[String] {
  let issues : Array[String] = []
  if command.protocol != "moonclaw.mooncode.v1" || command.command != "prompt" {
    issues.push("Moonfind must use the existing MoonClaw prompt protocol")
  }
  if command.model != "gpt-5.6-sol" {
    issues.push("Moonfind analysis must use gpt-5.6-sol")
  }
  if command.capability_scope_id != "moonfind.humanoid.synthesis" ||
    command.capability_participant_id.is_blank() {
    issues.push("analysis must bind the reviewed Moonfind capability scope")
  }
  if packet_string(command.packet, "product_id") != Some("moonfind") ||
    packet_string(command.packet, "required_review") != Some("named-human") ||
    packet_string(command.packet, "owner_route") !=
    Some("moonfind.humanoid-models") {
    issues.push(
      "packet must preserve Moonfind ownership and named-human review",
    )
  }
  let serialized = command.packet.stringify().to_lower()
  if serialized.contains("api_key") ||
    serialized.contains("credential") ||
    serialized.contains("publication_authority") ||
    serialized.contains("capability_activation") {
    issues.push("runtime packet carries authority or secret-shaped fields")
  }
  issues
}

///|
pub fn prepare_humanoid_analysis_command(
  run : @research.ResearchRun,
  book_root : String,
  participant_id : String,
) -> MoonClawResearchCommand raise {
  prepare_humanoid_analysis_command_with_evidence(
    run,
    book_root,
    participant_id,
    [],
  )
}

///|
pub fn prepare_humanoid_analysis_command_with_evidence(
  run : @research.ResearchRun,
  book_root : String,
  participant_id : String,
  full_text_evidence : Array[@hardening.FullTextEvidence],
) -> MoonClawResearchCommand raise {
  guard run.status == "awaiting-agent-analysis" &&
    !book_root.is_blank() &&
    !participant_id.is_blank() else {
    fail("analysis command requires a collected run, book root and participant")
  }
  for evidence in full_text_evidence {
    let issues = @hardening.validate_full_text_evidence(evidence)
    guard issues.is_empty() &&
      run.papers.any(paper => paper.paper_id == evidence.paper_id) else {
      fail("invalid or unrelated full-text evidence: \{issues.join("; ")}")
    }
  }
  let papers = run.papers.map(paper_context)
  let command : MoonClawResearchCommand = {
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
      "full_text_evidence": Json::array(
        full_text_evidence.map(full_text_context),
      ),
      "output_contract": humanoid_output_contract(),
      "required_review": "named-human",
      "owner_route": "moonfind.humanoid-models",
    },
  }
  let responsibility_issues = research_command_responsibility_issues(command)
  guard responsibility_issues.is_empty() else {
    fail(
      "irresponsible MoonClaw research command: " +
      responsibility_issues.join("; "),
    )
  }
  command
}
