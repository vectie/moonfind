///|
fn adapter_watch() -> @research.ResearchWatch {
  {
    watch_id: "adapter-watch",
    title: "Humanoid evidence",
    query: "humanoid control",
    categories: ["cs.RO"],
    keywords: ["humanoid", "control"],
    negative_keywords: [],
    max_papers: 10,
    cadence: "daily",
    domain_profile: "humanoid-robotics",
  }
}

///|
fn adapter_paper(id : String) -> @research.PaperRecord {
  {
    paper_id: id,
    versioned_id: id + "v1",
    title: "Paper " + id,
    abstract_text: "Inspectable evidence for deterministic adapter testing.",
    authors: ["Researcher"],
    categories: ["cs.RO"],
    published_at: "2026-07-01",
    updated_at: "2026-07-01",
    abs_url: "https://example.invalid/abs/" + id,
    pdf_url: "https://example.invalid/pdf/" + id,
    source_digest: "sha256:" + "a".repeat(64),
    retrieved_at: 1L,
    relevance_score: 90,
    relevance_reasons: ["matches governed watch"],
  }
}

///|
fn adapter_request(
  run : @research.ResearchRun,
  input_digest : String,
) -> PackToolExecutionRequest {
  let idempotency_key = "moonfind/\{run.run_id}/research.prepare-analysis/1/" +
    input_digest
  let seed : PackToolExecutionRequest = {
    binding: {
      pack_id: "moonfind",
      product_id: "moonfind",
      tool_id: "research.prepare-analysis",
      input_schema_id: "research-run",
      output_schema_id: "moonclaw-research-command",
      authority: SandboxExecution,
      idempotent: true,
      evidence_outputs: ["records/moonclaw-commands"],
      review_required: false,
    },
    config: expected_config(),
    initial_input: Some(run.to_json()),
    outputs: Map([]),
    request_id: "moonfind-analysis-\{run.run_id}",
    attempt_id: "moonfind-analysis-\{run.run_id}-a1",
    idempotency_key,
    operation_ref: "moonfind/research.prepare-analysis@0.1.0",
    run_id: run.run_id,
    step_id: "prepare-analysis",
    evidence_path: "",
    attempt: 1,
    estimated_cost_micros: 0,
  }
  { ..seed, evidence_path: expected_evidence_path(seed), }
}

///|
async test "pack adapter submits once and reconciles durably without a provider" {
  assert_eq(
    @store.digest_declared_artifact_bytes([("records/run.json", b"{}\n")]),
    "sha256:525b04b66b55db335c655eb65188ce9b68c6d91dbcabfe2964bd509acd3dc124",
  )
  let workspace = @fs.tmpdir(prefix="moonfind-pack-adapter-")
  let run = @research.start_research_run(
    "adapter-run",
    adapter_watch(),
    [adapter_paper("paper-a"), adapter_paper("paper-b")],
    1L,
  )
  @store.write_run_artifact(workspace, run.run_id, "run.json", run.to_json())
  let config = AdapterConfig::new(workspace)
  let run_ref = ".moonsuite/products/moonfind/runs/" + run.run_id + "/run.json"
  let run_path = workspace + "/" + run_ref
  let input_digest = @store.digest_declared_artifact_bytes([
    (run_ref, @fs.read_file(run_path).binary()),
  ])
  let request = adapter_request(run, input_digest)
  let provider_widened = {
    ..request,
    config: {
      "adapter_mode": "installed-pack",
      "result_mode": "moonclaw-command",
      "provider_calls_forbidden": false,
    },
  }
  let provider_denied = try {
    ignore(submit(AdapterConfig::new(workspace), provider_widened))
    false
  } catch {
    _ => true
  }
  assert_true(provider_denied)
  let absent = reconcile(AdapterConfig::new(workspace), request)
  assert_eq(absent.status, "unknown")
  assert_eq(absent.error_kind, "attempt-not-found")
  assert_false(
    @fs.exists(
      workspace +
      "/.moonsuite/products/moonfind/pack-tool-attempts/" +
      attempt_digest(request),
    ),
  )
  let first = submit(config, request)
  assert_eq(first.status, "succeeded")
  assert_eq(first.output_artifacts, [request.evidence_path])
  guard first.output
    is { "protocol": String("moonclaw.mooncode.v1"), "model": String(""), .. } else {
    fail("adapter output is not the governed MoonClaw command")
  }
  let replay = submit(AdapterConfig::new(workspace), request)
  assert_eq(replay.to_json(), first.to_json())
  let recovered = reconcile(AdapterConfig::new(workspace), request)
  assert_eq(recovered.status, "succeeded")
  assert_eq(
    recovered.result.map(value => value.to_json()),
    Some(first.to_json()),
  )
  let artifact = workspace + "/" + request.evidence_path
  assert_true(@fs.exists(artifact))
  assert_eq(@json.parse(@fs.read_file(artifact).text()), first.output)
  @fs.rmdir(workspace, recursive=true)
}
