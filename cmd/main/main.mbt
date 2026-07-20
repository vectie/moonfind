///|
fn usage() -> Unit {
  println(
    "Moonfind usage:\n" +
    "  moonfind run-fixture <workspace> <fixtures-directory>\n" +
    "  moonfind prepare-live <workspace> <run-id>\n" +
    "  moonfind record-fulltext <workspace> <run-id> <full-text-evidence.json>\n" +
    "  moonfind validate-provider <provider-policy.json> <use-request.json>\n" +
    "  moonfind resume <workspace> <run-id>\n" +
    "  moonfind publish-robotics-graph <moonbook-root>\n" +
    "  moonfind complete <workspace> <run-id> <analysis-result.json>\n" +
    "  moonfind record-moontown <workspace> <run-id> <execution-receipt.json>\n" +
    "  moonfind ingest-moontown <workspace> <run-id> <execution-receipt.json> <reducer-output.json>\n" +
    "  moonfind review <workspace> <run-id> <human-review.json>\n" +
    "  moonfind export-ui <workspace> <run-id> <moonfind-workspace.json>\n" +
    "  moonfind status <workspace> <run-id>\n" +
    "  moonfind manifest",
  )
}

///|
async fn persist_pending(
  workspace : String,
  run : @research.ResearchRun,
) -> Unit {
  let evidence_path = @store.run_directory(workspace, run.run_id) +
    "/fulltext-evidence.json"
  let evidence : Array[@hardening.FullTextEvidence] = if @fs.exists(
      evidence_path,
    ) {
    @json.from_json(@store.read_json(evidence_path))
  } else {
    []
  }
  let command = @agent.prepare_humanoid_analysis_command_with_evidence(
    run, ".moonbook/books/moonfind-humanoid-research", "moonfind-research-agent",
    evidence,
  )
  @store.write_run_artifact(workspace, run.run_id, "run.json", run.to_json())
  @store.write_run_artifact(
    workspace,
    run.run_id,
    "moonclaw-command.json",
    command.to_json(),
  )
  @store.write_run_artifact(
    workspace,
    run.run_id,
    "workspace.json",
    @app.project_research_workspace(run).to_json(),
  )
}

///|
async fn record_fulltext(
  workspace : String,
  run_id : String,
  evidence_path : String,
) -> Unit {
  let directory = @store.run_directory(workspace, run_id)
  let run : @research.ResearchRun = @json.from_json(
    @store.read_json(directory + "/run.json"),
  )
  let evidence : @hardening.FullTextEvidence = @json.from_json(
    @store.read_json(evidence_path),
  )
  let issues = @hardening.validate_full_text_evidence(evidence)
  guard issues.is_empty() else {
    fail("Full-text evidence rejected: \{issues.join("; ")}")
  }
  guard run.papers.any(paper => paper.paper_id == evidence.paper_id) else {
    fail("Full-text evidence references a paper outside this run")
  }
  let index_path = directory + "/fulltext-evidence.json"
  let existing : Array[@hardening.FullTextEvidence] = if @fs.exists(index_path) {
    @json.from_json(@store.read_json(index_path))
  } else {
    []
  }
  let next = existing.filter(item => item.paper_id != evidence.paper_id)
  next.push(evidence)
  @store.write_run_artifact(
    workspace,
    run_id,
    "fulltext-evidence.json",
    next.to_json(),
  )
  persist_pending(workspace, run)
  println(next.to_json().stringify(indent=2))
}

///|
async fn validate_provider(policy_path : String, request_path : String) -> Unit {
  let policy : @hardening.ProviderPolicy = @json.from_json(
    @store.read_json(policy_path),
  )
  let request : @hardening.ProviderUseRequest = @json.from_json(
    @store.read_json(request_path),
  )
  let decision = @hardening.decide_provider_use(policy, request)
  println(decision.to_json().stringify(indent=2))
  guard decision.decision == "allow" else {
    fail("Provider use denied: \{decision.reasons.join("; ")}")
  }
}

///|
async fn recovery_status(
  workspace : String,
  run_id : String,
  repair? : Bool = false,
) -> Unit {
  let directory = @store.run_directory(workspace, run_id)
  let run_path = directory + "/run.json"
  guard @fs.exists(run_path) else { fail("Moonfind run does not exist") }
  let run : @research.ResearchRun = @json.from_json(@store.read_json(run_path))
  if repair &&
    run.status == "awaiting-agent-analysis" &&
    !@fs.exists(directory + "/moonclaw-command.json") {
    persist_pending(workspace, run)
  }
  let snapshot = @hardening.recovery_snapshot(
    run_id,
    run.status,
    @fs.exists(directory + "/fulltext-evidence.json"),
    @fs.exists(directory + "/moonclaw-command.json"),
    !run.summaries.is_empty() || @fs.exists(directory + "/analysis-result.json"),
    @fs.exists(directory + "/moontown-handoff.json"),
    @fs.exists(directory + "/moontown-receipt.json"),
    @fs.exists(directory + "/human-review.json"),
    @fs.exists(directory + "/bookkeeper-deliverable.json"),
    @async.now(),
  )
  @store.write_run_artifact(
    workspace,
    run_id,
    "recovery.json",
    snapshot.to_json(),
  )
  println(snapshot.to_json().stringify(indent=2))
}

///|
async fn publish_robotics_graph(book_root : String) -> Unit {
  guard !book_root.is_blank() else { fail("MoonBook root is required") }
  let source = "workflows/humanoid-robotics-suite.v1.json"
  guard @fs.exists(source) else {
    fail("Run this command from the Moonfind repository root")
  }
  let flow_root = if book_root.has_suffix("/") {
    book_root + "flow"
  } else {
    book_root + "/flow"
  }
  if !@fs.exists(flow_root) {
    @fs.mkdir(flow_root, permission=0o755, recursive=true)
  }
  let book_parts = book_root
    .replace(old="\\", new="/")
    .split("/")
    .filter(part => !part.is_blank())
    .collect()
  guard !book_parts.is_empty() else { fail("MoonBook root is invalid") }
  let book_id = book_parts[book_parts.length() - 1].to_owned()
  let graph_id = "moonfind-" + book_id + "-humanoid-robotics-suite-v1"
  let digest_seed : Json = {
    "template_graph_id": "moonfind-humanoid-robotics-suite-v1",
    "book_id": book_id,
    "declaration_revision": "suite-v1",
  }
  let rendered = @fs.read_file(source)
    .text()
    .replace(
      old="\"graph_id\": \"moonfind-humanoid-robotics-suite-v1\"",
      new="\"graph_id\": \"" + graph_id + "\"",
    )
    .replace(
      old="\"book_id\": \"moonfind-humanoid-robotics\"",
      new="\"book_id\": \"" + book_id + "\"",
    )
    .replace(
      old="sha256:55ad83b204660e728a2eb35544b60bf4ac542a61b55e01926f4bc41b5bf628cc",
      new=@store.digest_json(digest_seed),
    )
  let output = flow_root + "/work-graph.json"
  @fs.write_file(output, rendered, create=0o644, truncate=true)
  println(output)
}

///|
async fn prepare_live(workspace : String, run_id : String) -> Unit {
  let now = @async.now()
  let watch = @humanoid.research_watch()
  let acquired = @arxiv.fetch_papers(watch.query, watch.max_papers, now)
  let papers = @humanoid.rank_papers(acquired)
  let run = @research.start_research_run(run_id, watch, papers, now)
  persist_pending(workspace, run)
  println(@app.project_research_workspace(run).to_json().stringify(indent=2))
}

///|
async fn complete_run(
  workspace : String,
  run_id : String,
  analysis_path : String,
) -> Unit {
  let run : @research.ResearchRun = @json.from_json(
    @store.read_json(@store.run_directory(workspace, run_id) + "/run.json"),
  )
  let result : @research.ResearchAnalysisResult = @json.from_json(
    @store.read_json(analysis_path),
  )
  let completed = @humanoid.complete_humanoid_run(run, result, @async.now())
  let handoff = @moontown.cross_paper_handoff(completed)
  let scenario = handoff.scenario
  @store.write_run_artifact(workspace, run_id, "run.json", completed.to_json())
  @store.write_run_artifact(
    workspace,
    run_id,
    "moontown-scenario.json",
    scenario.to_json(),
  )
  @store.write_run_artifact(
    workspace,
    run_id,
    "moontown-handoff.json",
    handoff.to_json(),
  )
  @store.write_run_artifact(
    workspace,
    run_id,
    "workspace.json",
    @app.project_research_workspace(completed).to_json(),
  )
  println(
    @app.project_research_workspace(completed).to_json().stringify(indent=2),
  )
}

///|
async fn record_moontown_receipt(
  workspace : String,
  run_id : String,
  receipt_path : String,
) -> Unit {
  let receipt : @moontown.TownExecutionReceipt = @json.from_json(
    @store.read_json(receipt_path),
  )
  let errors = @moontown.validate_town_execution_receipt(receipt, run_id)
  guard errors.length() == 0 else {
    fail("Invalid Moontown receipt: \{errors.join("; ")}")
  }
  @store.write_run_artifact(
    workspace,
    run_id,
    "moontown-receipt.json",
    receipt.to_json(),
  )
  println(receipt.to_json().stringify(indent=2))
}

///|
async fn ingest_moontown_output(
  workspace : String,
  run_id : String,
  receipt_path : String,
  output_path : String,
) -> Unit {
  let receipt : @moontown.TownExecutionReceipt = @json.from_json(
    @store.read_json(receipt_path),
  )
  let output : @moontown.TownSynthesisOutput = @json.from_json(
    @store.read_json(output_path),
  )
  let errors = @moontown.validate_town_execution_receipt(receipt, run_id) +
    @moontown.validate_town_synthesis_output(output, receipt)
  guard errors.is_empty() else {
    fail("Invalid Moontown synthesis: \{errors.join("; ")}")
  }
  @store.write_run_artifact(
    workspace,
    run_id,
    "moontown-receipt.json",
    receipt.to_json(),
  )
  @store.write_run_artifact(
    workspace,
    run_id,
    "moontown-reducer-output.json",
    output.to_json(),
  )
  println(output.to_json().stringify(indent=2))
}

///|
async fn review_run(
  workspace : String,
  run_id : String,
  review_path : String,
  require_moontown_receipt? : Bool = true,
) -> Unit {
  let run : @research.ResearchRun = @json.from_json(
    @store.read_json(@store.run_directory(workspace, run_id) + "/run.json"),
  )
  if require_moontown_receipt {
    let receipt_path = @store.run_directory(workspace, run_id) +
      "/moontown-receipt.json"
    guard @fs.exists(receipt_path) else {
      fail(
        "Moontown execution receipt is required before named-human review; run record-moontown first",
      )
    }
    let receipt : @moontown.TownExecutionReceipt = @json.from_json(
      @store.read_json(receipt_path),
    )
    let receipt_errors = @moontown.validate_town_execution_receipt(
      receipt, run_id,
    )
    guard receipt_errors.length() == 0 else {
      fail("Invalid Moontown receipt: \{receipt_errors.join("; ")}")
    }
    guard receipt.status == "completed" else {
      fail("Moontown synthesis is not review-ready: status=\{receipt.status}")
    }
    let output_path = @store.run_directory(workspace, run_id) +
      "/moontown-reducer-output.json"
    guard @fs.exists(output_path) else {
      fail(
        "Moontown reducer output is required before named-human review; run ingest-moontown first",
      )
    }
    let output : @moontown.TownSynthesisOutput = @json.from_json(
      @store.read_json(output_path),
    )
    let output_errors = @moontown.validate_town_synthesis_output(
      output, receipt,
    )
    guard output_errors.is_empty() else {
      fail("Invalid Moontown reducer output: \{output_errors.join("; ")}")
    }
  }
  let review : @research.HumanResearchReview = @json.from_json(
    @store.read_json(review_path),
  )
  let reviewed = run.apply_human_review(review)
  let reviewed_json = reviewed.to_json()
  let digest = @store.digest_json(reviewed_json)
  let review_digest = @store.digest_json(review.to_json())
  let binding = @closed_loop.bookkeeper_deliverable_candidate(
    reviewed, review, digest, review_digest,
  )
  let observation = @closed_loop.capability_observation(
    reviewed,
    review,
    "moonfind-research-agent",
    "baseline",
    {
      record_id: "moonfind-humanoid-synthesis",
      record_version: "1",
      record_digest: "sha256:moonfind-humanoid-synthesis:v1",
    },
    digest,
    review_digest,
  )
  @store.write_run_artifact(workspace, run_id, "run.json", reviewed_json)
  @store.write_run_artifact(
    workspace,
    run_id,
    "human-review.json",
    review.to_json(),
  )
  @store.write_run_artifact(
    workspace,
    run_id,
    "bookkeeper-deliverable.json",
    binding.to_json(),
  )
  @store.write_run_artifact(
    workspace,
    run_id,
    "moonflow-observation.json",
    observation.to_json(),
  )
  @store.write_run_artifact(
    workspace,
    run_id,
    "workspace.json",
    @app.project_research_workspace(reviewed).to_json(),
  )
  println(
    @app.project_research_workspace(reviewed).to_json().stringify(indent=2),
  )
}

///|
async fn run_fixture(workspace : String, fixtures : String) -> Unit {
  let now = 1000L
  let feed = @store.read_json(fixtures + "/feed.json")
  guard feed is Object(fields) && fields.get("atom") is Some(String(atom)) else {
    fail("fixture feed.json must contain an atom string")
  }
  let papers = @humanoid.rank_papers(@arxiv.decode_atom_feed(atom, now))
  let run = @research.start_research_run(
    "humanoid-cross-paper-demo",
    @humanoid.research_watch(),
    papers,
    now,
  )
  persist_pending(workspace, run)
  complete_run(workspace, run.run_id, fixtures + "/analysis-result.json")
  review_run(
    workspace,
    run.run_id,
    fixtures + "/human-review.json",
    require_moontown_receipt=false,
  )
}

///|
async fn status(workspace : String, run_id : String) -> Unit {
  let path = @store.run_directory(workspace, run_id) + "/workspace.json"
  println(@store.read_json(path).stringify(indent=2))
}

///|
async fn export_ui(
  workspace : String,
  run_id : String,
  output : String,
) -> Unit {
  let projection = @store.read_json(
    @store.run_directory(workspace, run_id) + "/workspace.json",
  )
  @store.write_json(output, projection)
  println(output)
}

///|
async fn main {
  match @env.args()[1:] {
    ["run-fixture", workspace, fixtures] => run_fixture(workspace, fixtures)
    ["prepare-live", workspace, run_id] => prepare_live(workspace, run_id)
    ["record-fulltext", workspace, run_id, evidence] =>
      record_fulltext(workspace, run_id, evidence)
    ["validate-provider", policy, request] => validate_provider(policy, request)
    ["resume", workspace, run_id] =>
      recovery_status(workspace, run_id, repair=true)
    ["publish-robotics-graph", book_root] => publish_robotics_graph(book_root)
    ["complete", workspace, run_id, analysis] =>
      complete_run(workspace, run_id, analysis)
    ["record-moontown", workspace, run_id, receipt] =>
      record_moontown_receipt(workspace, run_id, receipt)
    ["ingest-moontown", workspace, run_id, receipt, output] =>
      ingest_moontown_output(workspace, run_id, receipt, output)
    ["review", workspace, run_id, review] =>
      review_run(workspace, run_id, review)
    ["export-ui", workspace, run_id, output] =>
      export_ui(workspace, run_id, output)
    ["status", workspace, run_id] => status(workspace, run_id)
    ["manifest"] => {
      let report = @suitepack.validation_report()
      guard report.ok else { fail(report.to_json().stringify(indent=2)) }
      println(@suitepack.manifest().to_json().stringify(indent=2))
    }
    _ => usage()
  }
}
