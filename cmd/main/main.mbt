///|
fn usage() -> Unit {
  println(
    "Moonfind usage:\n" +
    "  moonfind run-fixture <workspace> <fixtures-directory>\n" +
    "  moonfind prepare-live <workspace> <run-id>\n" +
    "  moonfind complete <workspace> <run-id> <analysis-result.json>\n" +
    "  moonfind record-moontown <workspace> <run-id> <execution-receipt.json>\n" +
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
  let command = @agent.prepare_humanoid_analysis_command(
    run, ".moonbook/books/moonfind-humanoid-research", "moonfind-research-agent",
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
    ["complete", workspace, run_id, analysis] =>
      complete_run(workspace, run_id, analysis)
    ["record-moontown", workspace, run_id, receipt] =>
      record_moontown_receipt(workspace, run_id, receipt)
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
