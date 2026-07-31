///|
fn canonical_sha256(value : String) -> Bool {
  value.length() == 71 &&
  value.has_prefix("sha256:") &&
  value[7:]
  .iter()
  .all(char => char.is_ascii_digit() || ('a' <= char && char <= 'f'))
}

///|
fn safe_identity(value : String) -> Bool {
  !value.is_blank() &&
  !value.contains("/") &&
  !value.contains("\\") &&
  !value.contains("..")
}

///|
fn expected_evidence_path(request : PackToolExecutionRequest) -> String {
  "records/moonclaw-commands/" + attempt_digest(request) + ".json"
}

///|
fn expected_config() -> Json {
  {
    "adapter_mode": "installed-pack",
    "result_mode": "moonclaw-command",
    "provider_calls_forbidden": true,
  }
}

///|
fn research_run_issues(run : @research.ResearchRun) -> Array[String] {
  let issues = @research.validate_watch(run.watch)
  if run.contract_version != @research.research_contract_version() ||
    run.status != "awaiting-agent-analysis" ||
    run.papers.length() < 2 ||
    !run.summaries.is_empty() ||
    !run.questions.is_empty() ||
    !run.ideas.is_empty() ||
    run.completed_at is Some(_) ||
    run.human_review_status != "pending" ||
    !run.accepted_idea_ids.is_empty() {
    issues.push("research run is not a pristine awaiting-analysis input")
  }
  let paper_ids : Array[String] = []
  for paper in run.papers {
    if paper.paper_id.is_blank() ||
      paper.title.is_blank() ||
      paper.abstract_text.is_blank() ||
      paper.source_digest.is_blank() ||
      paper_ids.contains(paper.paper_id) {
      issues.push("research run contains incomplete or duplicate papers")
    } else {
      paper_ids.push(paper.paper_id)
    }
  }
  issues
}

///|
async fn validate_request(
  config : AdapterConfig,
  request : PackToolExecutionRequest,
) -> @research.ResearchRun {
  let binding = request.binding
  guard binding.pack_id == "moonfind" &&
    binding.product_id == "moonfind" &&
    binding.tool_id == "research.prepare-analysis" &&
    binding.input_schema_id == "research-run" &&
    binding.output_schema_id == "moonclaw-research-command" &&
    binding.authority == SandboxExecution &&
    binding.idempotent &&
    binding.evidence_outputs == ["records/moonclaw-commands"] &&
    !binding.review_required else {
    fail("MoonFind pack-tool binding does not match research.prepare-analysis")
  }
  guard request.operation_ref == "moonfind/research.prepare-analysis@0.1.0" &&
    safe_identity(request.run_id) &&
    request.step_id == "prepare-analysis" &&
    request.attempt == 1 &&
    request.estimated_cost_micros == 0 &&
    request.outputs.is_empty() &&
    request.config == expected_config() else {
    fail("MoonFind pack-tool request widened the installed operation")
  }
  let request_id = "moonfind-analysis-\{request.run_id}"
  let attempt_id = request_id + "-a1"
  let key_prefix = "moonfind/\{request.run_id}/research.prepare-analysis/1/"
  let input_digest = if request.idempotency_key.has_prefix(key_prefix) {
    request.idempotency_key[key_prefix.length():].to_owned()
  } else {
    ""
  }
  guard request.request_id == request_id &&
    request.attempt_id == attempt_id &&
    canonical_sha256(input_digest) &&
    request.evidence_path == expected_evidence_path(request) else {
    fail("MoonFind pack-tool attempt identity is not canonical")
  }
  guard request.initial_input is Some(input) else {
    fail("MoonFind pack-tool request is missing its research input")
  }
  let input_ref = ".moonsuite/products/moonfind/runs/" +
    request.run_id +
    "/run.json"
  let durable_path = @store.run_directory(config.workspace, request.run_id) +
    "/run.json"
  guard @fs.exists(durable_path) else {
    fail("MoonFind durable research input does not exist")
  }
  let (_, canonical) = canonical_workspace(config)
  guard @fs.realpath(durable_path) == exact_child(canonical, input_ref) else {
    fail("MoonFind durable research input escaped through a symbolic link")
  }
  let durable_data = @fs.read_file(durable_path)
  let durable_input = @json.parse(durable_data.text())
  let durable_digest = @store.digest_declared_artifact_bytes([
    (input_ref, durable_data.binary()),
  ])
  guard input == durable_input else {
    fail("MoonFind request input differs from its durable research artifact")
  }
  guard input_digest == durable_digest else {
    fail(
      "MoonFind request digest differs from its durable research bytes: expected \{durable_digest}, received \{input_digest}",
    )
  }
  let run : @research.ResearchRun = @json.from_json(durable_input)
  let issues = research_run_issues(run)
  guard run.run_id == request.run_id && issues.is_empty() else {
    fail("MoonFind research input is invalid: " + issues.join("; "))
  }
  run
}

///|
async fn planned_output(
  config : AdapterConfig,
  run : @research.ResearchRun,
) -> Json {
  let evidence_path = @store.run_directory(config.workspace, run.run_id) +
    "/fulltext-evidence.json"
  let evidence : Array[@hardening.FullTextEvidence] = if @fs.exists(
      evidence_path,
    ) {
    @json.from_json(@store.read_json(evidence_path))
  } else {
    []
  }
  @agent.prepare_humanoid_analysis_command_with_evidence(
    run, ".moonbook/books/moonfind-humanoid-research", "moonfind-research-agent",
    evidence,
  ).to_json()
}

///|
fn successful_result(
  request : PackToolExecutionRequest,
  output : Json,
) -> PackToolExecutionResult {
  {
    status: "succeeded",
    output,
    summary: Some(
      "Prepared the deterministic MoonClaw research command; no model or provider was called.",
    ),
    metrics: {
      "provider_calls": 0,
      "output_artifacts": 1,
      "estimated_cost_micros": 0,
    },
    logs: [
      "validated exact moonfind/research.prepare-analysis@0.1.0 binding", "matched input against the durable MoonFind research run",
      "materialized a review-required MoonClaw command only",
    ],
    output_artifacts: [request.evidence_path],
    external_job_id: "moonfind-pack-tool-" + attempt_digest(request),
    compensable: false,
  }
}

///|
async fn settle_attempt(
  config : AdapterConfig,
  path : String,
  record : PackToolAttemptRecord,
) -> PackToolExecutionResult {
  require_same_attempt(record, record.request)
  guard record.state == "submitted" else {
    fail("MoonFind pack-tool attempt cannot settle from " + record.state)
  }
  write_or_verify_output_artifact(config, record.request, record.planned_output)
  let result = successful_result(record.request, record.planned_output)
  persist_attempt(path, {
    ..record,
    state: "succeeded",
    result: Some(result),
    error_kind: "",
  })
  result
}

///|
/// Submit one exact deterministic MoonFind pack operation. The request is
/// checkpointed before the output artifact is written.
pub async fn submit(
  config : AdapterConfig,
  request : PackToolExecutionRequest,
) -> PackToolExecutionResult {
  let run = validate_request(config, request)
  guard attempt_directory(config, request, true) is Some(directory) else {
    fail("MoonFind pack-tool attempt directory could not be created")
  }
  let lock = @fs.open(
    directory + "/attempt.lock",
    mode=WriteOnly,
    create_mode=OpenOrCreate,
    permission=0o600,
  )
  defer lock.close()
  lock.lock(Exclusive)
  defer lock.unlock()
  let path = directory + "/result.json"
  match read_attempt_record(path) {
    Some(record) => {
      require_same_attempt(record, request)
      match record.result {
        Some(result) if record.state == "succeeded" => result
        _ => settle_attempt(config, path, record)
      }
    }
    None => {
      let output = planned_output(config, run)
      let submitted : PackToolAttemptRecord = {
        contract_id: "moonfind.pack-tool-attempt.v1",
        request_digest: @store.digest_json(request.to_json()),
        request,
        planned_output_digest: @store.digest_json(output),
        planned_output: output,
        state: "submitted",
        result: None,
        error_kind: "",
      }
      persist_attempt(path, submitted)
      settle_attempt(config, path, submitted)
    }
  }
}

///|
/// Reconcile only the same durable attempt. A missing attempt is observed as
/// unknown and is never created by reconciliation.
pub async fn reconcile(
  config : AdapterConfig,
  request : PackToolExecutionRequest,
) -> PackToolReconciliation {
  ignore(validate_request(config, request))
  guard attempt_directory(config, request, false) is Some(directory) else {
    return { status: "unknown", result: None, error_kind: "attempt-not-found" }
  }
  let lock_path = directory + "/attempt.lock"
  let lock = @fs.open(
    lock_path,
    mode=WriteOnly,
    create_mode=OpenOrCreate,
    permission=0o600,
  )
  defer lock.close()
  lock.lock(Exclusive)
  defer lock.unlock()
  let path = directory + "/result.json"
  guard read_attempt_record(path) is Some(record) else {
    return {
      status: "unknown",
      result: None,
      error_kind: "attempt-checkpoint-missing",
    }
  }
  require_same_attempt(record, request)
  let result = match record.result {
    Some(result) if record.state == "succeeded" => result
    _ => settle_attempt(config, path, record)
  }
  { status: result.status, result: Some(result), error_kind: record.error_kind }
}
