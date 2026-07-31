///|
pub fn moonfind_analysis_operation_ref() -> String {
  "moonfind/research.prepare-analysis@0.1.0"
}

///|
pub fn moonfind_analysis_input_schema_ref() -> String {
  "moonfind/research-run@1.0.0"
}

///|
pub fn moonfind_analysis_output_schema_ref() -> String {
  "moonfind/moonclaw-research-command@1.0.0"
}

///|
fn canonical_timestamp(value : String) -> Bool {
  value.length() == 20 &&
  value[4] == '-' &&
  value[7] == '-' &&
  value[10] == 'T' &&
  value[13] == ':' &&
  value[16] == ':' &&
  value[19] == 'Z' &&
  value
  .iter()
  .all(char => {
    char.is_ascii_digit() ||
    char == '-' ||
    char == 'T' ||
    char == ':' ||
    char == 'Z'
  })
}

///|
fn canonical_sha256(value : String) -> Bool {
  value.length() == 71 &&
  value.has_prefix("sha256:") &&
  value[7:]
  .iter()
  .all(char => char.is_ascii_digit() || ('a' <= char && char <= 'f'))
}

///|
fn safe_artifact_ref(value : String) -> Bool {
  !value.is_blank() &&
  !value.has_prefix("/") &&
  !value.contains("\\") &&
  !value.split("/").any(part => part == "..")
}

///|
fn exact_analysis_operation(
  catalog : CapabilityCatalogV1,
  evaluated_at : String,
) -> CapabilityCatalogOperationV1 raise {
  guard catalog.contract_id == "moonflow.capability-catalog.v1" &&
    canonical_timestamp(catalog.compiled_at) &&
    canonical_timestamp(evaluated_at) &&
    catalog.compiled_at <= evaluated_at else {
    fail("analysis requires a current MoonFlow capability catalog")
  }
  let matches = catalog.operations.filter(operation => {
    operation.operation_ref == moonfind_analysis_operation_ref()
  })
  guard matches is [operation] else {
    fail(
      "MoonFind analysis capability is absent or ambiguous: " +
      moonfind_analysis_operation_ref(),
    )
  }
  guard operation.product_id == "moonfind" &&
    operation.pack_id == "moonfind" &&
    operation.pack_version == "0.1.0" &&
    operation.tool_id == "research.prepare-analysis" &&
    operation.protocol == "moonflow.adapter.v2" &&
    operation.authority == "sandbox-execution" &&
    operation.input_schema_ref == moonfind_analysis_input_schema_ref() &&
    operation.output_schema_ref == moonfind_analysis_output_schema_ref() &&
    operation.idempotent &&
    operation.supports_reconcile &&
    operation.health_checked_at <= evaluated_at &&
    operation.health_valid_until >= evaluated_at else {
    fail("MoonFind analysis capability drifted from its manifest contract")
  }
  operation
}

///|
fn execution_record(
  previous : ResearchExecutionRecordV1,
  state : String,
  receipt_ref : String?,
  receipt : MoonClawCapabilityReceiptV1?,
  result_ref : String?,
  error_kind : String,
  next_action : String,
  updated_at : String,
) -> ResearchExecutionRecordV1 {
  {
    contract_id: previous.contract_id,
    revision: previous.revision + 1,
    run_id: previous.run_id,
    operation_ref: previous.operation_ref,
    request_id: previous.request_id,
    attempt_id: previous.attempt_id,
    idempotency_key: previous.idempotency_key,
    state,
    invocation: previous.invocation,
    receipt_ref,
    receipt,
    result_ref,
    moonclaw_session_key: previous.moonclaw_session_key,
    moonclaw_run_id: previous.moonclaw_run_id,
    moonclaw_run: previous.moonclaw_run,
    error_kind,
    requires_review: previous.requires_review,
    next_action,
    updated_at,
  }
}

///|
/// Prepare an immutable capability attempt. The host must persist this record
/// before it submits `invocation` to MoonClaw.
pub fn prepare_analysis_execution(
  catalog : CapabilityCatalogV1,
  run_id : String,
  book_id : String,
  input_digest : String,
  input_artifacts : Array[String],
  input : Json,
  created_at : String,
  timeout_ms : Int,
) -> ResearchExecutionRecordV1 raise {
  let operation = exact_analysis_operation(catalog, created_at)
  guard !run_id.is_blank() &&
    !book_id.is_blank() &&
    canonical_sha256(input_digest) &&
    !input_artifacts.is_empty() &&
    input_artifacts.all(safe_artifact_ref) &&
    timeout_ms > 0 else {
    fail("analysis execution requires a run, book, verified inputs and timeout")
  }
  let request_id = "moonfind-analysis-\{run_id}"
  let attempt_id = request_id + "-a1"
  let idempotency_key = "moonfind/\{run_id}/research.prepare-analysis/1/\{input_digest}"
  let request : MoonFlowAdapterRequestV2 = {
    request_id,
    run_id,
    book_id,
    work_item_id: "prepare-analysis",
    declaration_id: "moonfind-prepare-analysis-v1",
    attempt_id,
    idempotency_key,
    product_id: "moonfind",
    operation: operation.operation_ref,
    requested_authority: operation.authority,
    acceptance_criteria: [
      "a MoonClaw command is bound to the exact research run and isolated evidence",
      "the command delegates model execution only and grants no review authority",
    ],
    input_contracts: [operation.input_schema_ref],
    output_contracts: [operation.output_schema_ref],
    required_claim: "execution-result",
    input_digest,
    input_artifacts,
    timeout_ms,
    created_at,
  }
  let invocation : MoonClawCapabilityInvocationV1 = {
    contract_id: "moonclaw.capability-invocation.v1",
    adapter_id: operation.adapter_id,
    evaluated_at: created_at,
    recorded_at: created_at,
    attempt: 1,
    request,
    config: {
      "adapter_mode": "installed-pack",
      "result_mode": "moonclaw-command",
      "provider_calls_forbidden": true,
    },
    input,
  }
  {
    contract_id: "moonfind.research-execution-record.v1",
    revision: 1,
    run_id,
    operation_ref: operation.operation_ref,
    request_id,
    attempt_id,
    idempotency_key,
    state: "prepared",
    invocation,
    receipt_ref: None,
    receipt: None,
    result_ref: None,
    moonclaw_session_key: None,
    moonclaw_run_id: None,
    moonclaw_run: None,
    error_kind: "",
    requires_review: operation.review_required,
    next_action: "submit",
    updated_at: created_at,
  }
}

///|
/// Record the crash boundary before calling MoonClaw. Repeating the immutable
/// invocation after this point is reconciliation, never a blind retry.
pub fn mark_execution_submitting(
  record : ResearchExecutionRecordV1,
  recorded_at : String,
) -> ResearchExecutionRecordV1 raise {
  guard record.state == "prepared" && canonical_timestamp(recorded_at) else {
    fail("only a prepared execution can enter submission")
  }
  execution_record(
    record,
    "submitting",
    record.receipt_ref,
    record.receipt,
    record.result_ref,
    "",
    "reconcile",
    recorded_at,
  )
}

///|
fn verify_receipt_identity(
  record : ResearchExecutionRecordV1,
  receipt : MoonClawCapabilityReceiptV1,
) -> Unit raise {
  guard receipt.contract_id == "moonclaw.capability-invocation-receipt.v1" &&
    receipt.request_id == record.request_id &&
    receipt.attempt_id == record.attempt_id &&
    receipt.idempotency_key == record.idempotency_key &&
    receipt.product_id == "moonfind" &&
    receipt.operation_ref == record.operation_ref &&
    receipt.adapter_id == record.invocation.adapter_id &&
    receipt.input_schema_ref == moonfind_analysis_input_schema_ref() &&
    receipt.output_schema_ref == moonfind_analysis_output_schema_ref() &&
    receipt.requested_authority == "sandbox-execution" &&
    receipt.input_digest == record.invocation.request.input_digest else {
    fail("MoonClaw receipt does not belong to this MoonFind attempt")
  }
}

///|
/// Reconcile a persisted attempt from MoonClaw's durable receipt. `unknown`
/// remains nonterminal and can only be reconciled with the same idempotency key.
pub fn apply_execution_receipt(
  record : ResearchExecutionRecordV1,
  receipt_ref : String,
  receipt : MoonClawCapabilityReceiptV1,
  observed_at : String,
) -> ResearchExecutionRecordV1 raise {
  guard record.state is ("submitting" | "pending" | "unknown" | "failed") &&
    safe_artifact_ref(receipt_ref) &&
    canonical_timestamp(observed_at) else {
    fail("receipt can only reconcile a persisted non-successful attempt")
  }
  verify_receipt_identity(record, receipt)
  match receipt.status {
    "submitted" | "running" | "pending" =>
      execution_record(
        record,
        "pending",
        Some(receipt_ref),
        Some(receipt),
        None,
        "",
        "reconcile",
        observed_at,
      )
    "unknown" =>
      execution_record(
        record,
        "unknown",
        Some(receipt_ref),
        Some(receipt),
        None,
        receipt.error_kind,
        "investigate-and-reconcile",
        observed_at,
      )
    "failed" | "cancelled" =>
      execution_record(
        record,
        "failed",
        Some(receipt_ref),
        Some(receipt),
        None,
        receipt.error_kind,
        "named-operator-decision",
        observed_at,
      )
    "succeeded" => {
      guard canonical_sha256(receipt.output_digest) &&
        !receipt.output_artifacts.is_empty() &&
        receipt.output_artifacts.all(safe_artifact_ref) else {
        fail("successful MoonClaw receipt lacks verified output evidence")
      }
      execution_record(
        record,
        "command-ready",
        Some(receipt_ref),
        Some(receipt),
        Some(receipt.output_artifacts[0]),
        "",
        "submit-moonclaw-command",
        observed_at,
      )
    }
    _ => fail("unsupported MoonClaw capability receipt status")
  }
}

///|
/// Persist the Cowork session immediately after command submission, before a
/// run ID necessarily exists. Restart recovery must poll this session and must
/// not submit the command again.
pub fn bind_moonclaw_session(
  record : ResearchExecutionRecordV1,
  session_key : String,
  observed_at : String,
) -> ResearchExecutionRecordV1 raise {
  guard record.state == "command-ready" &&
    !session_key.is_blank() &&
    canonical_timestamp(observed_at) else {
    fail("MoonClaw session binding requires a prepared command and session ID")
  }
  {
    ..execution_record(
      record,
      "runtime-submitting",
      record.receipt_ref,
      record.receipt,
      record.result_ref,
      "",
      "poll-moonclaw-session",
      observed_at,
    ),
    moonclaw_session_key: Some(session_key),
  }
}

///|
/// Persist the Cowork run identity once it is allocated.
pub fn bind_moonclaw_run(
  record : ResearchExecutionRecordV1,
  session_key : String,
  run_id : String,
  observed_at : String,
) -> ResearchExecutionRecordV1 raise {
  guard record.state is ("command-ready" | "runtime-submitting") &&
    !session_key.is_blank() &&
    !run_id.is_blank() &&
    (
      record.moonclaw_session_key is None ||
      record.moonclaw_session_key == Some(session_key)
    ) &&
    canonical_timestamp(observed_at) else {
    fail("MoonClaw run binding requires a prepared command and durable IDs")
  }
  let observation : MoonClawRunObservationV1 = {
    contract_id: "moonfind.moonclaw-run-observation.v1",
    session_key,
    run_id,
    status: "submitted",
    result_ref: None,
    error: "",
    observed_at,
  }
  {
    ..execution_record(
      record,
      "runtime-pending",
      record.receipt_ref,
      record.receipt,
      record.result_ref,
      "",
      "poll-moonclaw-run",
      observed_at,
    ),
    moonclaw_session_key: Some(session_key),
    moonclaw_run_id: Some(run_id),
    moonclaw_run: Some(observation),
  }
}

///|
/// Reconcile the existing Cowork run after polling or process restart. A
/// missing/unknown outcome never starts a second run.
pub fn apply_moonclaw_run_observation(
  record : ResearchExecutionRecordV1,
  observation : MoonClawRunObservationV1,
) -> ResearchExecutionRecordV1 raise {
  guard record.state
    is ("runtime-pending" | "runtime-unknown" | "runtime-failed") &&
    record.moonclaw_session_key == Some(observation.session_key) &&
    record.moonclaw_run_id == Some(observation.run_id) &&
    observation.contract_id == "moonfind.moonclaw-run-observation.v1" &&
    canonical_timestamp(observation.observed_at) else {
    fail("MoonClaw run observation does not match the persisted run")
  }
  let (state, next_action, error_kind, result_ref) = match
    observation.status.to_lower() {
    "submitted" | "queued" | "running" | "paused" =>
      ("runtime-pending", "poll-moonclaw-run", "", None)
    "unknown" | "missing" =>
      (
        "runtime-unknown",
        "investigate-and-reconcile-moonclaw-run",
        observation.error,
        None,
      )
    "failed" | "cancelled" | "canceled" =>
      ("runtime-failed", "named-operator-decision", observation.error, None)
    "succeeded" | "completed" => {
      guard observation.result_ref is Some(result_ref) &&
        safe_artifact_ref(result_ref) else {
        fail("completed MoonClaw run requires a durable result reference")
      }
      ("needs-review", "named-human-review", "", Some(result_ref))
    }
    _ => fail("unsupported MoonClaw run status")
  }
  let settled_result_ref : String? = match result_ref {
    Some(value) => Some(value)
    None => record.result_ref
  }
  {
    ..execution_record(
      record,
      state,
      record.receipt_ref,
      record.receipt,
      settled_result_ref,
      error_kind,
      next_action,
      observation.observed_at,
    ),
    moonclaw_run: Some(observation),
  }
}

///|
/// Derive the only safe action after process restart.
pub fn restart_action(record : ResearchExecutionRecordV1) -> String {
  match record.state {
    "prepared" => "submit"
    "submitting" | "pending" => "reconcile"
    "unknown" => "investigate-and-reconcile"
    "command-ready" => "submit-moonclaw-command"
    "runtime-submitting" => "poll-moonclaw-session"
    "runtime-pending" => "poll-moonclaw-run"
    "runtime-unknown" => "investigate-and-reconcile-moonclaw-run"
    "runtime-failed" => "named-operator-decision"
    "needs-review" => "named-human-review"
    "failed" => "named-operator-decision"
    _ => "stop-invalid-state"
  }
}
