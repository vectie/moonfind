///|
async fn moontown_reachable(base_url : String) -> Bool {
  try {
    let (response, _) = @http.get(trimmed_base(base_url) + "/viewport.html")
    response.code >= 200 && response.code < 400
  } catch {
    _ => false
  }
}

///|
async fn moonclaw_gateway_reachable(base_url : String) -> Bool {
  try {
    let (response, _) = @http.get(trimmed_base(base_url) + "/health")
    response.code >= 200 && response.code < 300
  } catch {
    _ => false
  }
}

///|
fn execution_requires_moonclaw_gateway(
  execution : @integration.ResearchExecutionRecordV1?,
) -> Bool {
  execution
  .map(record => {
    record.state
    is ("command-ready"
    | "runtime-submitting"
    | "runtime-pending"
    | "runtime-unknown"
    | "runtime-failed")
  })
  .unwrap_or(false)
}

///|
async fn handoff_status(
  config : Config,
  execution : @integration.ResearchExecutionRecordV1?,
) -> MoonTownHandoffStatusV1 {
  let handoff_path = run_artifact(config, "moontown-handoff.json")
  let receipt_path = run_artifact(config, "moontown-receipt.json")
  let output_path = run_artifact(config, "moontown-reducer-output.json")
  let envelope_path = run_artifact(config, "moontown-result-ingest-v1.json")
  if !@fs.exists(handoff_path) {
    return {
      contract_id: "moonfind.moontown-handoff-status.v1",
      run_id: config.run_id,
      state: if execution
        .map(record => record.state == "needs-review")
        .unwrap_or(false) {
        "awaiting-materialization"
      } else {
        "not-ready"
      },
      handoff_contract: @moontown.town_handoff_contract_version(),
      handoff_id: None,
      handoff_url: None,
      open_url: None,
      receipt_contract: None,
      receipt_status: None,
      detail: if execution
        .map(record => record.state == "needs-review")
        .unwrap_or(false) {
        "MoonClaw analysis is complete, but no typed MoonTown handoff artifact has been materialized from the reviewed analysis result."
      } else {
        "MoonTown becomes available after MoonClaw analysis produces a durable typed handoff."
      },
    }
  }
  let handoff : @moontown.TownResearchHandoff = @json.from_json(
    @store.read_json(handoff_path),
  )
  let issues = @moontown.validate_town_research_handoff(handoff, config.run_id)
  if !issues.is_empty() {
    return {
      contract_id: "moonfind.moontown-handoff-status.v1",
      run_id: config.run_id,
      state: "blocked",
      handoff_contract: handoff.contract_version,
      handoff_id: Some(handoff.handoff_id),
      handoff_url: None,
      open_url: None,
      receipt_contract: None,
      receipt_status: None,
      detail: "Typed handoff validation failed: " + issues.join("; "),
    }
  }
  let handoff_url = trimmed_base(config.public_base_url) +
    "/api/v1/moontown/handoff"
  let mut receipt_contract : String? = None
  let mut receipt_status : String? = None
  let mut state = "ready"
  let mut detail = "Typed handoff is valid and remains pending MoonTown synthesis."
  if @fs.exists(receipt_path) {
    let receipt : @moontown.TownExecutionReceipt = @json.from_json(
      @store.read_json(receipt_path),
    )
    let receipt_issues = @moontown.validate_town_execution_receipt(
      receipt,
      config.run_id,
    )
    receipt_contract = Some(receipt.contract_version)
    receipt_status = Some(receipt.status)
    if !receipt_issues.is_empty() {
      state = "blocked"
      detail = "MoonTown receipt validation failed: " +
        receipt_issues.join("; ")
    } else if receipt.status == "completed" &&
      (!@fs.exists(output_path) || !@fs.exists(envelope_path)) {
      state = "result-incomplete"
      detail = "MoonTown receipt exists, but the correlated reducer output or immutable ingest envelope is missing."
    } else if receipt.status == "completed" {
      let output : @moontown.TownSynthesisOutput = @json.from_json(
        @store.read_json(output_path),
      )
      let output_issues = @moontown.validate_town_synthesis_output(
        output, receipt,
      )
      if !output_issues.is_empty() {
        state = "blocked"
        detail = "MoonTown reducer-output validation failed: " +
          output_issues.join("; ")
      } else {
        state = "ingested-pending-review"
        detail = "MoonTown returned \{output.ideas.length()} correlated synthesis idea(s). The immutable result is pending named-human MoonBook review."
      }
    } else {
      state = receipt.status
      detail = receipt.summary
    }
  }
  let mut open_url : String? = None
  if state == "ready" {
    match config.moontown_base_url {
      Some(base) if !base.is_blank() && moontown_reachable(base) =>
        open_url = Some(
          trimmed_base(base) +
          "/viewport.html?assets=generated&mode=view&v=wenyu" +
          "&handoff_contract=" +
          handoff.contract_version +
          "&handoff_id=" +
          handoff.handoff_id +
          "&handoff_url=" +
          handoff_url,
        )
      Some(_) =>
        detail = "Typed handoff is valid, but the configured MoonTown host is unavailable."
      None =>
        detail = "Typed handoff is valid, but no MoonTown host endpoint is configured."
    }
  }
  {
    contract_id: "moonfind.moontown-handoff-status.v1",
    run_id: config.run_id,
    state,
    handoff_contract: handoff.contract_version,
    handoff_id: Some(handoff.handoff_id),
    handoff_url: Some(handoff_url),
    open_url,
    receipt_contract,
    receipt_status,
    detail,
  }
}

///|
pub async fn workspace_snapshot(config : Config) -> UiWorkspaceSnapshotV1 {
  let projection_path = run_artifact(config, "workspace.json")
  guard @fs.exists(projection_path) else {
    fail("MoonFind durable workspace projection does not exist")
  }
  let workspace : @app.ResearchWorkspaceProjection = @json.from_json(
    @store.read_json(projection_path),
  )
  guard workspace.product_id == "moonfind" && workspace.run_id == config.run_id else {
    fail("MoonFind workspace projection does not match the configured run")
  }
  let execution = current_execution(config)
  let moonclaw_gateway_base = match config.moonclaw_gateway_base {
    Some(base) if !base.is_blank() && moonclaw_gateway_reachable(base) =>
      Some(trimmed_base(base))
    _ => None
  }
  let blockers : Array[String] = []
  if execution is None {
    blockers.push(
      "No prepared execution exists. Supply a current compiled capability catalog for an awaiting-agent-analysis run.",
    )
  }
  if execution_requires_moonclaw_gateway(execution) &&
    moonclaw_gateway_base is None {
    blockers.push(
      if config.moonclaw_gateway_base is Some(_) {
        "The configured MoonClaw Cowork gateway is unavailable."
      } else {
        "MoonClaw Cowork gateway is not configured."
      },
    )
  }
  match execution {
    Some(record) =>
      if record.state == "prepared" && config.moonclaw_submit_url is None {
        blockers.push("MoonClaw capability submit endpoint is not configured.")
      } else if record.state
        is ("submitting" | "pending" | "unknown" | "failed") &&
        config.moonclaw_reconcile_url is None {
        blockers.push(
          "MoonClaw capability reconcile endpoint is not configured.",
        )
      }
    None => ()
  }
  let town = handoff_status(config, execution)
  {
    contract_id: "moonfind.ui-workspace.v1",
    product_id: "moonfind",
    generated_at: host_timestamp(),
    book_workspace: config.book_workspace,
    workspace,
    research_cowork_session_key: execution.bind(record => {
      record.moonclaw_session_key
    }),
    qa_cowork_session_key: None,
    qa_agent_status: "not-published",
    research_execution: execution,
    capability_submit_url: execution.map(_ => "/api/v1/capability/submit"),
    capability_reconcile_url: execution.map(_ => "/api/v1/capability/reconcile"),
    capability_checkpoint_url: execution.map(_ => {
      "/api/v1/capability/checkpoint"
    }),
    moonclaw_gateway_base,
    host_status: if blockers.is_empty() {
      "ready"
    } else {
      "blocked"
    },
    host_blockers: blockers,
    moontown_handoff: town,
    review_workflow: review_workflow_status(config),
  }
}

///|
pub async fn typed_moontown_handoff(config : Config) -> Json {
  let path = run_artifact(config, "moontown-handoff.json")
  guard @fs.exists(path) else { fail("typed MoonTown handoff is not ready") }
  let value = @store.read_json(path)
  let handoff : @moontown.TownResearchHandoff = @json.from_json(value)
  let issues = @moontown.validate_town_research_handoff(handoff, config.run_id)
  guard issues.is_empty() else {
    fail("typed MoonTown handoff is invalid: " + issues.join("; "))
  }
  value
}
