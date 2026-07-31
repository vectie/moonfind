///|
fn local_corpus_participant(
  book_id : String,
  role_id : String,
  title : String,
  focus_area : String,
  perspective : String,
  current_question : String,
  contribution : String,
  next_artifact : String,
) -> TownParticipant {
  {
    book_id: "\{book_id}-\{role_id}",
    title,
    focus_area,
    perspective,
    cadence: "per-moonfind-run",
    current_question,
    contribution,
    next_artifact,
  }
}

///|
pub fn local_corpus_challenge_scenario(
  ledger : @research.LocalInputCoverageLedger,
  book_id : String,
  topic : String,
) -> TownResearchScenario raise {
  let coverage = @research.summarize_local_input_coverage(ledger)
  guard coverage.research_ready && !book_id.is_blank() && !topic.is_blank() else {
    fail("local corpus salon requires ready coverage, a MoonBook and a topic")
  }
  let scenario_id = "moonfind-\{ledger.ledger_id}"
  {
    id: scenario_id,
    title: "Moonfind Local Corpus Adversarial Research Salon",
    communication_pattern_id: Some("research-salon"),
    communication_pattern_label: Some("Research Salon"),
    building_id: "moonfind-local-corpus-salon",
    building_book_id: book_id,
    domain_label: "evidence-backed general research",
    topic,
    cadence: "per-moonfind-run",
    interval_ms: None,
    skill_name: "moonfind-local-corpus-challenge",
    skill_description: "Challenge attributed local-source claims against provenance, external evidence, contradictions, and falsifiable alternatives.",
    protocol_channel: "moonfind.research.local-corpus.v1",
    reduction_kind: "adversarial-evidence-synthesis",
    output_channel: "moonfind.research.challenges.v1",
    review_gate: "named-human",
    review_owner: "moonbook.bookkeeper",
    review_reason: "Attributed local-source claims, contradictions, and novel hypotheses require evidence-bound human review.",
    backlog_path: "research/backlog.md",
    synthesis_path: "research/local-corpus-challenge.md",
    metrics_path: "research/coverage-and-quality.md",
    review_path: "reviews/moonfind-local-corpus.md",
    returned_ideas_path: "research/returned-local-corpus-ideas.md",
    participant_contract_path: "research/local-corpus-participant-contract.md",
    quality_rules: [
      "Treat the imported files as one source sequence unless provenance proves otherwise.",
      "Every challenged source claim must retain an input id and page or region anchor.",
      "Separate source attribution, verified fact, inference, hypothesis, and recommendation.",
      "Surface contradictions and missing context instead of averaging them away.",
      "Known missing inputs must remain explicit gaps and must never be reconstructed.",
      "No reducer output is accepted without named-human review.",
    ],
    skill_rules: [
      "Search for disconfirming evidence before strengthening a source claim.", "Prefer primary sources for technical claims and record publication and retrieval dates.",
      "Propose the smallest next check that could falsify each novel connection.",
      "Keep raw local inputs private and cite durable MoonBook evidence artifacts.",
    ],
    participants: [
      local_corpus_participant(
        book_id, "source-critic", "Source and Provenance Critic", "authenticity, completeness, attribution, and missing context",
        "Assume the local source may be incomplete, altered, or misattributed until corroborated.",
        "Which major claims depend on unverified provenance or the missing source context?",
        "A provenance challenge and a list of claims that must remain attributed.",
        "research/challenges/source-and-provenance.md",
      ),
      local_corpus_participant(
        book_id, "technical-verifier", "Technical Evidence Verifier", "models, training, compute, chips, software, data, and product claims",
        "Require primary technical evidence and distinguish released capability from roadmap language.",
        "Which technical claims are independently reproducible, contradicted, or still unverifiable?",
        "A technical corroboration and contradiction matrix.", "research/challenges/technical-evidence.md",
      ),
      local_corpus_participant(
        book_id, "economic-skeptic", "Competitive and Economic Skeptic", "pricing, costs, revenue, strategy, market structure, and incentives",
        "Stress-test commercial narratives, selection effects, and unsupported quantitative claims.",
        "What economic assumptions fail under alternative cost, demand, or competition scenarios?",
        "A scenario table with falsifiers and confidence limits.", "research/challenges/economics-and-competition.md",
      ),
      local_corpus_participant(
        book_id, "synthesis-explorer", "Synthesis and New-Idea Explorer", "cross-topic connections, mechanisms, implications, and research questions",
        "Generate novel connections only after the evidence critics have bounded the claim set.",
        "Which evidence-backed connections are useful, surprising, and falsifiable?",
        "A ranked hypothesis set with counter-hypotheses and next checks.", "research/challenges/novel-hypotheses.md",
      ),
    ],
    ideas: [],
  }
}

///|
pub fn local_corpus_handoff(
  ledger : @research.LocalInputCoverageLedger,
  book_id : String,
  topic : String,
) -> TownResearchHandoff raise {
  {
    contract_version: town_handoff_contract_version(),
    handoff_id: town_handoff_id(ledger.ledger_id),
    producer: "moonfind",
    producer_run_id: ledger.ledger_id,
    scenario: local_corpus_challenge_scenario(ledger, book_id, topic),
  }
}
