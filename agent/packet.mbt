///|
pub(all) struct MoonClawResearchCommand {
  protocol : String
  session_id : String
  book_root : String
  command : String
  // Empty means this preparation-only packet has no model assignment.
  // The trusted execution transport must bind an exact selected model.
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
fn packet_bool(packet : Json, key : String) -> Bool? {
  match packet {
    Object(fields) =>
      match fields.get(key) {
        Some(True) => Some(true)
        Some(False) => Some(false)
        _ => None
      }
    _ => None
  }
}

///|
/// Verifies that a Moonfind packet delegates only the model loop to MoonClaw.
/// Research ownership, review, capability activation, and external effects
/// remain outside the runtime command.
fn command_responsibility_issues(
  command : MoonClawResearchCommand,
  expected_scope_id : String,
  expected_owner_route : String,
) -> Array[String] {
  let issues : Array[String] = []
  if command.protocol != "moonclaw.mooncode.v1" || command.command != "prompt" {
    issues.push("Moonfind must use the existing MoonClaw prompt protocol")
  }
  if command.model != command.model.trim().to_owned() {
    issues.push(
      "Moonfind command model must be an exact selector or unassigned",
    )
  }
  if command.capability_scope_id != expected_scope_id ||
    command.capability_participant_id.is_blank() {
    issues.push("analysis must bind the reviewed Moonfind capability scope")
  }
  if packet_string(command.packet, "product_id") != Some("moonfind") ||
    packet_string(command.packet, "required_review") != Some("named-human") ||
    packet_string(command.packet, "owner_route") != Some(expected_owner_route) {
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
pub fn research_command_responsibility_issues(
  command : MoonClawResearchCommand,
) -> Array[String] {
  command_responsibility_issues(
    command, "moonfind.humanoid.synthesis", "moonfind.humanoid-models",
  )
}

///|
pub fn local_corpus_command_responsibility_issues(
  command : MoonClawResearchCommand,
) -> Array[String] {
  command_responsibility_issues(
    command, "moonfind.local-corpus.research", "moonfind.general-research",
  )
}

///|
pub fn book_qa_command_responsibility_issues(
  command : MoonClawResearchCommand,
) -> Array[String] {
  let issues = command_responsibility_issues(
    command, "moonfind.book.qa", "moonfind.reviewed-book-qa",
  )
  if packet_bool(command.packet, "read_only") != Some(true) ||
    packet_string(command.packet, "persistence_policy") !=
    Some("moonbook-review-only") ||
    packet_string(command.packet, "web_update_policy") !=
    Some("label-separately") {
    issues.push(
      "book Q&A must be read-only and route new knowledge through MoonBook review",
    )
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
    model: "",
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

///|
fn local_corpus_output_contract() -> String {
  let contract =
    #|Return exactly one JSON object containing: iteration_id, source_claims, corroborated_claims, contradictions, research_questions, synthesis_notes, evidence_gaps, capability_gaps, and next_checks. Every source claim must cite an input_id plus one or more page or region evidence anchors from the supplied coverage ledger. Every externally corroborated or contradicted claim must cite a fetched source artifact, publication date, retrieval date, and credibility limit. Separate source attribution, verified fact, inference, hypothesis, and recommendation. Do not infer contents for known_missing_inputs. Do not claim that the report is reviewed or accepted.
  contract
}

///|
pub fn prepare_local_corpus_analysis_command(
  ledger : @research.LocalInputCoverageLedger,
  book_root : String,
  participant_id : String,
  research_question : String,
  iteration_id : String,
) -> MoonClawResearchCommand raise {
  let coverage = @research.summarize_local_input_coverage(ledger)
  guard coverage.research_ready &&
    !book_root.is_blank() &&
    !participant_id.is_blank() &&
    !research_question.is_blank() &&
    !iteration_id.is_blank() else {
    fail(
      "local corpus analysis requires ready coverage, a book root, a participant, a question and an iteration",
    )
  }
  let command : MoonClawResearchCommand = {
    protocol: "moonclaw.mooncode.v1",
    session_id: "moonfind-local-\{ledger.ledger_id}",
    book_root,
    command: "prompt",
    model: "",
    capability_scope_id: "moonfind.local-corpus.research",
    capability_participant_id: participant_id,
    text: "Analyze the fully accounted local corpus, cross-validate its claims, and persist a reviewable iteration in MoonBook.",
    packet: {
      "command_id": "moonfind-local-\{ledger.ledger_id}-\{iteration_id}",
      "product_id": "moonfind",
      "ledger": ledger,
      "coverage_summary": coverage,
      "research_question": research_question,
      "iteration_id": iteration_id,
      "output_contract": local_corpus_output_contract(),
      "required_review": "named-human",
      "owner_route": "moonfind.general-research",
    },
  }
  let issues = local_corpus_command_responsibility_issues(command)
  guard issues.is_empty() else {
    fail("irresponsible local corpus command: " + issues.join("; "))
  }
  command
}

///|
fn book_qa_output_contract() -> String {
  let contract =
    #|Use a verified moonfind.read-only-qa-grounding.v1 manifest for the supplied MoonBook bundle. Answer the operator's question from that bundle. Cite durable book-relative artifact paths and exact evidence anchors for every material claim. State the report review_state at the top of the answer. Distinguish reviewed bundle evidence from any clearly labelled web-fresh update. If the bundle does not support an answer, say so and identify the missing evidence. Do not write to the book or promote new knowledge; return proposed follow-up insights for MoonBook review instead.
  contract
}

///|
pub fn prepare_book_qa_command(
  book_id : String,
  book_root : String,
  participant_id : String,
  review_state : String,
  bundle_artifacts : Array[String],
  question : String,
) -> MoonClawResearchCommand raise {
  guard !book_id.is_blank() &&
    !book_root.is_blank() &&
    !participant_id.is_blank() &&
    !question.is_blank() &&
    (review_state == "accepted" || review_state == "pending-review") &&
    !bundle_artifacts.is_empty() &&
    bundle_artifacts.all(fn(path) {
      !path.is_blank() && !path.has_prefix("/") && !path.contains("..")
    }) else {
    fail(
      "book Q&A requires a bound book, explicit review state, safe bundle artifacts and a question",
    )
  }
  let command : MoonClawResearchCommand = {
    protocol: "moonclaw.mooncode.v1",
    session_id: "moonfind-\{book_id}-qa",
    book_root,
    command: "prompt",
    model: "",
    capability_scope_id: "moonfind.book.qa",
    capability_participant_id: participant_id,
    text: question,
    packet: {
      "command_id": "moonfind-\{book_id}-qa",
      "product_id": "moonfind",
      "book_id": book_id,
      "review_state": review_state,
      "bundle_artifacts": bundle_artifacts,
      "read_only": true,
      "web_update_policy": "label-separately",
      "persistence_policy": "moonbook-review-only",
      "output_contract": book_qa_output_contract(),
      "required_review": "named-human",
      "owner_route": "moonfind.reviewed-book-qa",
    },
  }
  let issues = book_qa_command_responsibility_issues(command)
  guard issues.is_empty() else {
    fail("irresponsible book Q&A command: " + issues.join("; "))
  }
  command
}
