///|
pub(all) struct Config {
  workspace : String
  run_id : String
  book_workspace : String
  public_base_url : String
  capability_catalog_path : String?
  moonclaw_gateway_base : String?
  moonclaw_gateway_token : String?
  moonclaw_submit_url : String?
  moonclaw_reconcile_url : String?
  moontown_base_url : String?
}

///|
fn run_artifact(config : Config, name : String) -> String raise {
  @store.run_directory(config.workspace, config.run_id) + "/" + name
}

///|
async fn current_execution(
  config : Config,
) -> @integration.ResearchExecutionRecordV1? {
  @store.read_latest_execution_record(config.workspace, config.run_id)
}

///|
pub async fn ensure_prepared_execution(
  config : Config,
) -> @integration.ResearchExecutionRecordV1? {
  match current_execution(config) {
    Some(record) => return Some(record)
    None => ()
  }
  guard config.capability_catalog_path is Some(catalog_path) &&
    @fs.exists(catalog_path) else {
    return None
  }
  let run_path = run_artifact(config, "run.json")
  guard @fs.exists(run_path) else { return None }
  let run_data = @fs.read_file(run_path)
  let input = @json.parse(run_data.text())
  let run : @research.ResearchRun = @json.from_json(input)
  guard run.run_id == config.run_id && run.status == "awaiting-agent-analysis" else {
    return None
  }
  let catalog : @integration.CapabilityCatalogV1 = @json.from_json(
    @store.read_json(catalog_path),
  )
  let input_ref = ".moonsuite/products/moonfind/runs/" +
    config.run_id +
    "/run.json"
  let input_digest = @store.digest_declared_artifact_bytes([
    (input_ref, run_data.binary()),
  ])
  let prepared = @integration.prepare_analysis_execution(
    catalog,
    config.run_id,
    book_id_from_path(config.book_workspace),
    input_digest,
    [input_ref],
    input,
    host_timestamp(),
    300000,
  )
  ignore(@store.append_execution_record(config.workspace, prepared))
  Some(prepared)
}

///|
fn blocked_reply(
  operation : String,
  message : String,
  execution : @integration.ResearchExecutionRecordV1,
) -> CapabilityOperationReplyV1 {
  {
    contract_id: "moonfind.capability-operation-reply.v1",
    operation,
    blocked: true,
    message,
    execution,
  }
}

///|
fn completed_reply(
  operation : String,
  message : String,
  execution : @integration.ResearchExecutionRecordV1,
) -> CapabilityOperationReplyV1 {
  {
    contract_id: "moonfind.capability-operation-reply.v1",
    operation,
    blocked: false,
    message,
    execution,
  }
}

///|
async fn fetch_capability_receipt(
  url : String,
  invocation : @integration.MoonClawCapabilityInvocationV1,
) -> Result[@integration.MoonClawCapabilityReceiptV1, String] noraise {
  try {
    let (response, data) = @http.post(url, invocation.to_json(), headers={
      "Content-Type": "application/json; charset=utf-8",
    })
    guard response.code >= 200 && response.code < 300 else {
      fail("MoonClaw capability host returned HTTP \{response.code}")
    }
    @json.from_json(@json.parse(data.text()))
  } catch {
    error => Err("\{error}")
  } noraise {
    receipt => Ok(receipt)
  }
}

///|
async fn persist_capability_receipt(
  config : Config,
  previous : @integration.ResearchExecutionRecordV1,
  receipt : @integration.MoonClawCapabilityReceiptV1,
) -> @integration.ResearchExecutionRecordV1 {
  let receipt_name = "capability-receipt-r\{previous.revision + 1}.json"
  @store.write_run_artifact(
    config.workspace,
    config.run_id,
    receipt_name,
    receipt.to_json(),
  )
  let next = @integration.apply_execution_receipt(
    previous,
    receipt_name,
    receipt,
    host_timestamp(),
  )
  ignore(@store.append_execution_record(config.workspace, next))
  next
}

///|
pub async fn submit_execution(
  config : Config,
  invocation : Json,
) -> CapabilityOperationReplyV1 {
  guard current_execution(config) is Some(prepared) else {
    fail("MoonFind has no durable prepared execution")
  }
  guard prepared.state == "prepared" else {
    fail(
      "submit rejected: durable execution state is `\{prepared.state}`; use its recorded next action",
    )
  }
  guard invocation == prepared.invocation.to_json() else {
    fail("submitted invocation differs from the durable prepared invocation")
  }
  let submitting = @integration.mark_execution_submitting(
    prepared,
    host_timestamp(),
  )
  ignore(@store.append_execution_record(config.workspace, submitting))
  guard config.moonclaw_submit_url is Some(url) && !url.is_blank() else {
    return blocked_reply(
      "submit", "MoonClaw capability submit endpoint is not configured. The immutable attempt is persisted for reconciliation; no runtime success is claimed.",
      submitting,
    )
  }
  match fetch_capability_receipt(url, submitting.invocation) {
    Err(error) =>
      blocked_reply(
        "submit",
        "MoonClaw submit is unavailable: \{error}. Reconcile this same idempotency key; do not create a new attempt.",
        submitting,
      )
    Ok(receipt) => {
      let next = persist_capability_receipt(config, submitting, receipt)
      completed_reply(
        "submit",
        "MoonClaw receipt validated and appended as revision \{next.revision}.",
        next,
      )
    }
  }
}

///|
pub async fn reconcile_execution(
  config : Config,
  invocation : Json,
) -> CapabilityOperationReplyV1 {
  guard current_execution(config) is Some(previous) else {
    fail("MoonFind has no durable execution to reconcile")
  }
  guard previous.state is ("submitting" | "pending" | "unknown" | "failed") else {
    fail("reconcile rejected: durable execution state is `\{previous.state}`")
  }
  guard invocation == previous.invocation.to_json() else {
    fail("reconcile invocation differs from the durable immutable invocation")
  }
  guard config.moonclaw_reconcile_url is Some(url) && !url.is_blank() else {
    return blocked_reply(
      "reconcile", "MoonClaw capability reconcile endpoint is not configured. The original attempt remains unchanged and no retry was issued.",
      previous,
    )
  }
  match fetch_capability_receipt(url, previous.invocation) {
    Err(error) =>
      blocked_reply(
        "reconcile",
        "MoonClaw reconcile is unavailable: \{error}. The original attempt remains authoritative.",
        previous,
      )
    Ok(receipt) => {
      let next = persist_capability_receipt(config, previous, receipt)
      completed_reply(
        "reconcile",
        "MoonClaw receipt validated and appended as revision \{next.revision}.",
        next,
      )
    }
  }
}

///|
async fn fetch_cowork_checkpoint(
  config : Config,
  session_key : String,
) -> Result[CoworkCheckpointRun?, String] noraise {
  try {
    let value = fetch_cowork_json(
      config,
      "/v1/cowork/sessions/" + session_key,
      None,
    )
    guard valid_checkpoint_session_binding(config, session_key, value) else {
      fail(
        "Cowork checkpoint session identity or workspace differs from the trusted run binding.",
      )
    }
    let payload : CoworkCheckpointPayload = @json.from_json(value)
    payload.session.linked_run
  } catch {
    error => Err("\{error}")
  } noraise {
    run => Ok(run)
  }
}

///|
async fn append_session_if_needed(
  config : Config,
  record : @integration.ResearchExecutionRecordV1,
  session_key : String,
) -> @integration.ResearchExecutionRecordV1 {
  if record.state == "command-ready" {
    let next = @integration.bind_moonclaw_session(
      record,
      session_key,
      host_timestamp(),
    )
    ignore(@store.append_execution_record(config.workspace, next))
    next
  } else {
    guard record.moonclaw_session_key == Some(session_key) else {
      fail("checkpoint session differs from the durable MoonClaw session")
    }
    record
  }
}

///|
async fn append_run_if_needed(
  config : Config,
  record : @integration.ResearchExecutionRecordV1,
  session_key : String,
  run : CoworkCheckpointRun,
) -> @integration.ResearchExecutionRecordV1 {
  if record.state == "runtime-submitting" {
    let next = @integration.bind_moonclaw_run(
      record,
      session_key,
      run.id,
      host_timestamp(),
    )
    ignore(@store.append_execution_record(config.workspace, next))
    next
  } else {
    guard record.moonclaw_run_id == Some(run.id) else {
      fail("checkpoint run differs from the durable MoonClaw run")
    }
    record
  }
}

///|
async fn append_run_observation(
  config : Config,
  record : @integration.ResearchExecutionRecordV1,
  session_key : String,
  run : CoworkCheckpointRun,
) -> @integration.ResearchExecutionRecordV1 {
  let normalized = run.status
    .trim(chars=['"', ' ', '\n', '\r', '\t'])
    .to_owned()
  let completed = normalized.to_lower() is ("succeeded" | "completed")
  let result_ref = if completed {
    let artifact = "moonclaw-run-observation-r\{record.revision + 1}.json"
    @store.write_run_artifact(
      config.workspace,
      config.run_id,
      artifact,
      run.to_json(),
    )
    Some(artifact)
  } else {
    None
  }
  let observation : @integration.MoonClawRunObservationV1 = {
    contract_id: "moonfind.moonclaw-run-observation.v1",
    session_key,
    run_id: run.id,
    status: normalized,
    result_ref,
    error: run.error.unwrap_or(""),
    observed_at: host_timestamp(),
  }
  let next = @integration.apply_moonclaw_run_observation(record, observation)
  ignore(@store.append_execution_record(config.workspace, next))
  next
}

///|
pub async fn checkpoint_execution(
  config : Config,
  request : MoonClawSessionCheckpointRequestV1,
) -> CapabilityOperationReplyV1 {
  guard request.contract_id == "moonfind.moonclaw-session-checkpoint-request.v1" &&
    !request.session_key.is_blank() else {
    fail("unsupported or incomplete MoonClaw checkpoint request")
  }
  guard current_execution(config) is Some(previous) else {
    fail("MoonFind has no durable execution to checkpoint")
  }
  if previous.state == "needs-review" {
    return completed_reply(
      "checkpoint", "MoonClaw run is already durably checkpointed for named-human review.",
      previous,
    )
  }
  guard previous.state
    is ("command-ready"
    | "runtime-submitting"
    | "runtime-pending"
    | "runtime-unknown"
    | "runtime-failed") else {
    fail(
      "execution state `\{previous.state}` cannot accept a Cowork checkpoint",
    )
  }
  guard config.moonclaw_gateway_base is Some(gateway) && !gateway.is_blank() else {
    return blocked_reply(
      "checkpoint", "MoonClaw Cowork gateway is not configured; browser-supplied run status was not trusted.",
      previous,
    )
  }
  guard checkpoint_session_authorized(
    request.session_key,
    previous.moonclaw_session_key,
    registered_cowork_keys(config),
  ) else {
    return blocked_reply(
      "checkpoint", "Cowork session is not independently bound to this MoonFind run; it was not fetched or adopted.",
      previous,
    )
  }
  match fetch_cowork_checkpoint(config, request.session_key) {
    Err(error) =>
      blocked_reply(
        "checkpoint",
        "MoonClaw Cowork checkpoint is unavailable: \{error}. No run status was fabricated.",
        previous,
      )
    Ok(None) => {
      let session_bound = append_session_if_needed(
        config,
        previous,
        request.session_key,
      )
      completed_reply(
        "checkpoint", "MoonClaw session identity is durable; no run has been allocated yet.",
        session_bound,
      )
    }
    Ok(Some(run)) => {
      let session_bound = append_session_if_needed(
        config,
        previous,
        request.session_key,
      )
      let run_bound = append_run_if_needed(
        config,
        session_bound,
        request.session_key,
        run,
      )
      let observed = append_run_observation(
        config,
        run_bound,
        request.session_key,
        run,
      )
      completed_reply(
        "checkpoint", "MoonClaw session and run observation were validated and appended.",
        observed,
      )
    }
  }
}
