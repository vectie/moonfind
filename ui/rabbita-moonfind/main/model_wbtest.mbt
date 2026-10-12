///|
test "run status normalization maps gateway states to review phases" {
  assert_eq(phase_from_run_status("\"Succeeded\"") == Completed, true)
  assert_eq(phase_from_run_status(" WaitingForInput ") == NeedsReview, true)
  assert_eq(phase_from_run_status("cancelled") == Failed, true)
  assert_eq(phase_from_run_status("Executing") == Running, true)
}

///|
test "initial model remains pending and targets the governed workspace" {
  let model = initial_model()
  assert_eq(model.phase == Ready, true)
  assert_eq(phase_text(model.phase), "Not started")
  assert_eq(model.model_name, "")
  assert_eq(model.gateway_published, false)
  assert_eq(model.book_dir, "")
  assert_eq(model.reviewer_name, "")
  assert_eq(model.review_outcome, "")
  assert_eq(model.review_scope, "")
  assert_eq(model.review_phase == ReviewIdle, true)
  assert_eq(model.review_prepare_reply is None, true)
  assert_eq(model.qa_session is None, true)
  assert_eq(model.qa_ready, false)
}

///|
test "command-ready research waits for an explicit model route" {
  let execution : ResearchExecutionProjection = @json.from_json({
    "contract_id": "moonfind.research-execution-record.v1",
    "revision": 1,
    "run_id": "run-1",
    "operation_ref": "moonfind/research.prepare-analysis@0.1.0",
    "request_id": "request-1",
    "attempt_id": "attempt-1",
    "idempotency_key": "moonfind/run-1/attempt-1",
    "state": "command-ready",
    "invocation": Json::empty_object(),
    "error_kind": "",
    "requires_review": true,
    "next_action": "run-exact-command",
    "updated_at": "2026-09-30T00:00:00Z",
  })
  let model = {
    ..initial_model(),
    gateway_published: true,
    gateway_base: "http://127.0.0.1:4313",
    workspace: Some(route_workspace()),
    book_dir: "/trusted/book",
    trusted_book_dir: "/trusted/book",
    research_execution: Some(execution),
  }
  let (_, held) = update(_ => @rabbita.none, StartResearch, model)
  assert_eq(held.phase, Failed)
  assert_true(held.error.unwrap_or("").contains("Choose a model explicitly"))
  let reply : CapabilityOperationReply = {
    contract_id: "moonfind.capability-operation-reply.v1",
    operation: "reconcile",
    blocked: false,
    message: "ready",
    execution: { ..execution, revision: 2, },
  }
  let (_, reconciled) = update(
    _ => @rabbita.none,
    CapabilitySubmitted(execution, Ok(reply)),
    model,
  )
  assert_eq(reconciled.phase, Failed)
  assert_true(
    reconciled.error.unwrap_or("").contains("Choose a model explicitly"),
  )
  let (_, selected) = update(
    _ => @rabbita.none,
    SetModelName("configured/research-route"),
    model,
  )
  let (_, started) = update(_ => @rabbita.none, StartResearch, selected)
  assert_eq(started.phase, CreatingSession)
  assert_eq(started.error, None)
}

///|
test "workspace snapshot carries both persisted UI session keys" {
  let snapshot : WorkspaceSnapshot = @json.from_json({
    "contract_id": "moonfind.ui-workspace.v1",
    "product_id": "moonfind",
    "generated_at": "2026-07-31T00:00:00Z",
    "book_workspace": "/workspace/book",
    "workspace": {
      "product_id": "moonfind",
      "title": "Research",
      "run_id": "run-1",
      "status": "awaiting-agent-analysis",
      "watch_title": "Humanoid research",
      "query": "humanoid",
      "paper_count": 2,
      "summary_count": 0,
      "idea_count": 0,
      "question_count": 0,
      "accepted_idea_count": 0,
      "active_stage": "MoonClaw analysis",
      "validation_issues": [],
      "bookkeeper_route": "moonbook.bookkeeper",
      "three_gap_state": "waiting-for-accepted-outcome",
    },
    "research_cowork_session_key": "cowork:research",
    "qa_cowork_session_key": "cowork:qa",
    "qa_agent_status": "grounded_verified",
    "moonclaw_gateway_base": "http://127.0.0.1:19000",
    "host_status": "ready",
    "host_blockers": [],
    "moontown_handoff": {
      "contract_id": "moonfind.moontown-handoff-status.v1",
      "run_id": "run-1",
      "state": "not-ready",
      "handoff_contract": "moontown.civic.communication.handoff.v1",
      "detail": "not ready",
    },
    "review_workflow": {
      "contract_id": "moonfind.review-workflow-status.v1",
      "run_id": "run-1",
      "state": "not-ready",
      "detail": "MoonTown synthesis must complete before review.",
    },
  })
  assert_eq(snapshot.product_id, "moonfind")
  assert_eq(snapshot.book_workspace, "/workspace/book")
  assert_true(snapshot.research_cowork_session_key is Some("cowork:research"))
  assert_true(snapshot.qa_cowork_session_key is Some("cowork:qa"))
  assert_eq(snapshot.qa_agent_status, "grounded_verified")
  assert_eq(snapshot.contract_id, "moonfind.ui-workspace.v1")
  assert_eq(snapshot.workspace.run_id, "run-1")
  assert_eq(
    gateway_base_from_snapshot(snapshot, "http://127.0.0.1:4313"),
    "http://127.0.0.1:19000",
  )
  assert_eq(has_published_gateway(snapshot), true)
}

///|
test "terminal durable execution skips refresh and opens named review cleanly" {
  let snapshot : WorkspaceSnapshot = @json.from_json({
    "contract_id": "moonfind.ui-workspace.v1",
    "product_id": "moonfind",
    "generated_at": "2026-07-31T00:00:06Z",
    "book_workspace": "/workspace/book",
    "workspace": {
      "product_id": "moonfind",
      "title": "Research",
      "run_id": "run-1",
      "status": "human-review",
      "watch_title": "Humanoid research",
      "query": "humanoid",
      "paper_count": 3,
      "summary_count": 3,
      "idea_count": 1,
      "question_count": 2,
      "accepted_idea_count": 0,
      "active_stage": "Named human review",
      "validation_issues": [],
      "bookkeeper_route": "moonbook.bookkeeper",
      "three_gap_state": "waiting-for-accepted-outcome",
    },
    "research_cowork_session_key": "cowork:completed",
    "qa_agent_status": "not-published",
    "research_execution": {
      "contract_id": "moonfind.research-execution-record.v1",
      "revision": 6,
      "run_id": "run-1",
      "operation_ref": "moonfind/research.prepare-analysis@0.1.0",
      "request_id": "request-1",
      "attempt_id": "attempt-1",
      "idempotency_key": "moonfind/run-1/attempt-1",
      "state": "needs-review",
      "invocation": Json::empty_object(),
      "error_kind": "",
      "requires_review": true,
      "next_action": "named-human-review",
      "updated_at": "2026-07-31T00:00:06Z",
    },
    "host_status": "ready",
    "host_blockers": [],
    "moontown_handoff": {
      "contract_id": "moonfind.moontown-handoff-status.v1",
      "run_id": "run-1",
      "state": "ready",
      "handoff_contract": "moontown.civic.communication.handoff.v1",
      "handoff_id": "handoff-1",
      "detail": "ready",
    },
    "review_workflow": {
      "contract_id": "moonfind.review-workflow-status.v1",
      "run_id": "run-1",
      "state": "ready-for-human-review",
      "prepare_url": "/api/v1/review/prepare",
      "detail": "Record the named-human decision.",
    },
  })
  assert_eq(execution_needs_session_refresh(snapshot.research_execution), false)
  let (_, loaded) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(1, Ok(snapshot)),
    initial_model(),
  )
  assert_eq(loaded.phase == Completed, true)
  assert_eq(loaded.gateway_published, false)
  assert_eq(loaded.error is None, true)
  assert_eq(loaded.research_session is None, true)
  assert_true(
    loaded.notice
    is Some(
      "MoonClaw execution is durably complete and ready for named-human review."
    ),
  )
}

///|
test "post-run review requires identity outcome rationale and explicit approval scope" {
  assert_eq(review_request_issues("", "", "", "").length(), 3)
  assert_eq(
    review_request_issues(
      "kq", "approve_subset", "", "Approve supported claims.",
    ).contains("List the exact synthesis idea IDs approved."),
    true,
  )
  assert_eq(
    review_request_issues(
      "kq", "approve_subset", "C01, C02", "Approve these public-fact claims only.",
    ).is_empty(),
    true,
  )
  assert_eq(
    review_request_issues(
      "kq", "request_changes", "", "Add independent unit-economics evidence.",
    ).is_empty(),
    true,
  )
}

///|
test "Three-Gap inputs and review scope remain bounded" {
  let model = {
    ..initial_model(),
    review_scope: "idea-1, idea_2\nidea-1",
    information_gap_severity: 3,
    information_gap_summary: "",
  }
  assert_eq(review_scope_ids(model.review_scope), ["idea-1", "idea_2"])
  assert_eq(
    review_gap_issues(model).contains(
      "Information gap needs a concrete summary when present.",
    ),
    true,
  )
  assert_eq(safe_review_scope_id("../escape"), false)
  assert_eq(review_gap_severity("9", 0), 5)
  assert_eq(review_gap_severity("-2", 1), 0)
  assert_eq(review_gap_severity("not-a-number", 2), 2)
}

///|
test "MoonFlow launch and receiver identities fail closed" {
  let token = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  assert_eq(valid_moonflow_launch("run-1", token), true)
  assert_eq(valid_moonflow_launch("../run", token), false)
  assert_eq(valid_moonflow_launch("run-1", "short"), false)
  assert_eq(
    moonflow_receiver_base("run-1", token),
    "/api/moonflow/runs/run-1/handoffs/" + token,
  )
}

///|
test "every Q&A turn carries its own grounding and privacy contract" {
  let prompt = qa_grounding_prompt(
    qa_projection_context(route_model()),
    "Compare the strongest claims.",
  )
  assert_eq(prompt.contains("run-1"), true)
  assert_eq(prompt.contains("do not invent files, paths, citations"), true)
  assert_eq(prompt.contains("Q&A cannot approve MoonBook changes"), true)
  assert_eq(prompt.contains("Compare the strongest claims."), true)
}
