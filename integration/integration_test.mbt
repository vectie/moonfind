///|
fn analysis_operation(
  valid_until? : String = "2026-08-01T00:00:00Z",
) -> @integration.CapabilityCatalogOperationV1 {
  {
    operation_ref: @integration.moonfind_analysis_operation_ref(),
    product_id: "moonfind",
    pack_id: "moonfind",
    pack_version: "0.1.0",
    tool_id: "research.prepare-analysis",
    adapter_id: "moonfind-pack-local-v1",
    protocol: "moonflow.adapter.v2",
    authority: "sandbox-execution",
    input_schema_ref: @integration.moonfind_analysis_input_schema_ref(),
    output_schema_ref: @integration.moonfind_analysis_output_schema_ref(),
    claim_ceiling: "execution-result",
    idempotent: true,
    review_required: false,
    supports_cancel: true,
    supports_reconcile: true,
    health_checked_at: "2026-07-30T00:00:00Z",
    health_valid_until: valid_until,
    health_evidence_ref: "health/moonfind.json",
    health_evidence_digest: "sha256:" + "a".repeat(64),
  }
}

///|
fn capability_catalog(
  operations : Array[@integration.CapabilityCatalogOperationV1],
) -> @integration.CapabilityCatalogV1 {
  {
    contract_id: "moonflow.capability-catalog.v1",
    catalog_id: "moonfind-test-catalog",
    compiled_at: "2026-07-31T00:00:00Z",
    conformant: true,
    products: [
      { product_id: "moonfind", pack_id: "moonfind", pack_version: "0.1.0" },
    ],
    operations,
    issues: [],
  }
}

///|
fn success_receipt(
  record : @integration.ResearchExecutionRecordV1,
) -> @integration.MoonClawCapabilityReceiptV1 {
  {
    contract_id: "moonclaw.capability-invocation-receipt.v1",
    result_id: "result-1",
    request_id: record.request_id,
    attempt_id: record.attempt_id,
    idempotency_key: record.idempotency_key,
    product_id: "moonfind",
    external_job_id: "",
    status: "succeeded",
    output_digest: "sha256:" + "b".repeat(64),
    output_artifacts: ["records/moonclaw-commands/run-1.json"],
    error_kind: "",
    compensable: false,
    recorded_at: "2026-07-31T00:00:02Z",
    catalog_id: "moonfind-test-catalog",
    pack_id: "moonfind",
    pack_version: "0.1.0",
    adapter_id: record.invocation.adapter_id,
    operation_ref: record.operation_ref,
    input_schema_ref: @integration.moonfind_analysis_input_schema_ref(),
    output_schema_ref: @integration.moonfind_analysis_output_schema_ref(),
    requested_authority: "sandbox-execution",
    input_digest: record.invocation.request.input_digest,
    health_evidence_ref: "health/moonfind.json",
    health_evidence_digest: "sha256:" + "a".repeat(64),
    output: Some({
      "protocol": "moonclaw.mooncode.v1",
      "command": "prompt",
      "model": "gpt-5.6-sol",
    }),
    summary: Some("command prepared"),
    metrics: Json::empty_object(),
    logs: [],
  }
}

///|
test "capability success still requires the persisted MoonClaw run" {
  let prepared = @integration.prepare_analysis_execution(
    capability_catalog([analysis_operation()]),
    "run-1",
    "book-1",
    "sha256:" + "0".repeat(64),
    ["records/research-run.json"],
    { "run_id": "run-1" },
    "2026-07-31T00:00:00Z",
    30000,
  )
  assert_eq(prepared.state, "prepared")
  let submitting = @integration.mark_execution_submitting(
    prepared, "2026-07-31T00:00:01Z",
  )
  let command_ready = @integration.apply_execution_receipt(
    submitting,
    ".moonsuite/products/moonclaw/capability-invocations/a/result.json",
    success_receipt(submitting),
    "2026-07-31T00:00:03Z",
  )
  assert_eq(command_ready.state, "command-ready")
  assert_eq(
    @integration.restart_action(command_ready),
    "submit-moonclaw-command",
  )
  let session_bound = @integration.bind_moonclaw_session(
    command_ready, "cowork:session-1", "2026-07-31T00:00:04Z",
  )
  assert_eq(session_bound.state, "runtime-submitting")
  assert_eq(@integration.restart_action(session_bound), "poll-moonclaw-session")
  let runtime = @integration.bind_moonclaw_run(
    session_bound, "cowork:session-1", "run-moonclaw-1", "2026-07-31T00:00:05Z",
  )
  assert_eq(runtime.state, "runtime-pending")
  let review = @integration.apply_moonclaw_run_observation(runtime, {
    contract_id: "moonfind.moonclaw-run-observation.v1",
    session_key: "cowork:session-1",
    run_id: "run-moonclaw-1",
    status: "completed",
    result_ref: Some("records/analysis/run-1.json"),
    error: "",
    observed_at: "2026-07-31T00:00:06Z",
  })
  assert_eq(review.state, "needs-review")
  assert_eq(@integration.restart_action(review), "named-human-review")
}

///|
fn desired_stage(
  stage_id : String,
  operation_ref : String?,
) -> @integration.DesiredCapabilityStageV2 {
  {
    stage_id,
    declaration_id: stage_id + "-v1",
    product_id: "moonfind",
    desired_operation_ref: operation_ref,
    desired_tool_hint: "research.prepare-analysis",
    execution_role: None,
    execution_config: None,
    requested_authority: "sandbox-execution",
    input_schema_ref: Some(@integration.moonfind_analysis_input_schema_ref()),
    output_schema_ref: Some(@integration.moonfind_analysis_output_schema_ref()),
    required_claim: "execution-result",
    acceptance_criteria: ["command exists"],
    input_artifacts: ["records/research-run.json"],
    timeout_ms: 30000,
    depends_on: [],
  }
}

///|
test "desired graph exposes gaps and never emits a partial import" {
  let catalog = capability_catalog([analysis_operation()])
  let blocked = @integration.project_desired_graph(
    {
      contract_id: "moonfind.desired-capability-graph.v2",
      graph_id: "blocked-graph",
      book_id: "book-1",
      declaration_revision: "r1",
      source_digest: "sha256:blocked",
      support_topology: None,
      intentional_exclusions: None,
      stages: [
        desired_stage(
          "known",
          Some(@integration.moonfind_analysis_operation_ref()),
        ),
        desired_stage("missing", None),
      ],
    },
    catalog,
    "2026-07-31T00:00:00Z",
  )
  assert_false(blocked.fully_conformant)
  assert_true(blocked.importable_graph is None)
  assert_true(blocked.gaps.any(gap => gap.code == "operation-unpublished"))
  let accepted = @integration.project_desired_graph(
    {
      contract_id: "moonfind.desired-capability-graph.v2",
      graph_id: "accepted-graph",
      book_id: "book-1",
      declaration_revision: "r1",
      source_digest: "sha256:accepted",
      support_topology: None,
      intentional_exclusions: None,
      stages: [
        desired_stage(
          "known",
          Some(@integration.moonfind_analysis_operation_ref()),
        ),
      ],
    },
    catalog,
    "2026-07-31T00:00:00Z",
  )
  assert_true(accepted.fully_conformant)
  assert_true(accepted.importable_graph is Some(_))
  ignore(@integration.require_importable_graph(accepted))
}
