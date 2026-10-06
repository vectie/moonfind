///|
fn retained_harness(model : Model) -> (Ref[Model], (Msg) -> @rabbita.Cmd) {
  let scheduler = RouteTestScheduler::{
    hooks: { url_request: None, url_changed: None, },
  }
  let cell = Ref(model)
  fn dispatch(message : Msg) -> @rabbita.Cmd {
    let (command, next) = update(dispatch, message, cell.val)
    cell.val = next
    @cmd.Scheduler::add(scheduler, command)
    @rabbita.none
  }
  (cell, dispatch)
}

///|
fn retained_snapshot_json(state : String, key : String?) -> String {
  let value : Json = {
    "contract_id": "moonfind.ui-workspace.v1",
    "product_id": "moonfind",
    "generated_at": "2026-10-04T10:00:00Z",
    "book_workspace": "/trusted/book",
    "workspace": {
      "product_id": "moonfind",
      "title": "Test",
      "run_id": "run-1",
      "status": "human-review",
      "watch_title": "Test",
      "query": "current evidence",
      "paper_count": 0,
      "summary_count": 0,
      "idea_count": 0,
      "question_count": 0,
      "accepted_idea_count": 0,
      "active_stage": "review",
      "validation_issues": [],
      "bookkeeper_route": "moonbook.bookkeeper",
      "three_gap_state": "pending",
    },
    "qa_agent_status": state,
    "moonclaw_gateway_base": "/api/v1/cowork-gateway",
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
      "detail": "not ready",
    },
  }
  if key is Some(key) && value is Object(fields) {
    fields["qa_cowork_session_key"] = Json::string(key)
  }
  value.stringify()
}

///|
fn retained_session_json(
  selector : String?,
  key? : String = "cowork:fixture",
  cwd? : String = "/trusted/book",
) -> String {
  let summary : Json = {
    "session_key": key,
    "session_id": "fixture",
    "title": "Fixture",
    "updated_at": 1,
    "state": "ready",
    "cwd": cwd,
    "has_plan_mode": false,
  }
  if selector is Some(selector) && summary is Object(fields) {
    fields["model_override"] = Json::string(selector)
  }
  let value : Json = {
    "session": {
      "session": summary,
      "messages": [
        {
          "id": "historic",
          "role": "assistant",
          "kind": "assistant",
          "content": "HISTORIC ANSWER MUST STAY HIDDEN",
          "timestamp": 1,
          "metadata": Json::empty_object(),
        },
      ],
    },
  }
  value.stringify()
}

///|
fn retained_route_json() -> String {
  let value : Json = {
    "contract_id": "moonfind.native-model-route.v1",
    "run_id": "run-1",
    "cwd": "/trusted/book",
    "catalog_ready": true,
    "default_ready": true,
    "default_model": "moongate/chosen",
    "models": ["moongate/chosen", "moongate/other"],
    "blocker": "",
  }
  value.stringify()
}

///|
fn retained_requests() -> Array[Json] raise {
  match @json.parse(question_http_requests()) {
    Array(items) => items
    _ => fail("requests missing")
  }
}

///|
test "actual reload hydration uses only GET and retained exact model with fresh evidence on explicit Ask" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let (cell, dispatch) = retained_harness({
    ..initial_model(),
    qa_question: "Keep this draft",
    review_message: "Keep reviewer draft",
  })
  ignore(dispatch(RefreshQa))
  complete_question_http(
    0,
    retained_snapshot_json("retained", Some("cowork:fixture")),
    false,
  )
  assert_true(cell.val.pending_qa_restore is Some(_))
  ignore(dispatch(PrepareQa))
  ignore(dispatch(AskQa))
  complete_question_http(1, retained_route_json(), false)
  assert_eq(cell.val.model_name, "")
  complete_question_http(
    2,
    retained_session_json(Some("moongate/other")),
    false,
  )
  assert_true(cell.val.qa_ready)
  assert_eq(cell.val.model_name, "moongate/other")
  assert_eq(cell.val.qa_canonical_key, Some("cowork:fixture"))
  assert_eq(cell.val.qa_question, "Keep this draft")
  assert_eq(cell.val.review_message, "Keep reviewer draft")
  assert_true(
    cell.val.qa_answer_text is None && cell.val.qa_response_context is None,
  )
  assert_false(
    qa_test_render(cell.val).contains("HISTORIC ANSWER MUST STAY HIDDEN"),
  )
  let requests = retained_requests()
  assert_eq(requests.length(), 3)
  for request in requests {
    assert_true(request is { "method": String("GET"), "body": Null, .. })
  }
  ignore(dispatch(AskQa))
  ignore(dispatch(AskQa))
  let requests = retained_requests()
  assert_eq(requests.length(), 4)
  assert_true(
    requests[3]
    is {
      "method": String("POST"),
      "url": String(
        "/api/v1/cowork-gateway/v1/cowork/sessions/cowork:fixture/messages"
      ),
      "body": {
        "model": String("moongate/other"),
        "content": String(content),
        ..
      },
      ..
    } &&
    content.contains("current evidence") &&
    content.contains("Keep this draft"),
  )
}

///|
test "unconfigured retained hydration never mutates until explicit finish and never creates replacement" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let (cell, dispatch) = retained_harness(initial_model())
  ignore(dispatch(RefreshQa))
  complete_question_http(
    0,
    retained_snapshot_json("retained", Some("cowork:fixture")),
    false,
  )
  // Exercise the opposite arrival order: session before native route.
  complete_question_http(2, retained_session_json(None), false)
  complete_question_http(1, retained_route_json(), false)
  assert_false(cell.val.qa_ready)
  assert_eq(cell.val.model_name, "moongate/chosen")
  assert_true(qa_test_render(cell.val).contains("Finish Q&amp;A preparation"))
  ignore(dispatch(PrepareQa))
  assert_eq(retained_requests().length(), 3)
  ignore(dispatch(FinishQaPreparation))
  ignore(dispatch(FinishQaPreparation))
  assert_eq(retained_requests().length(), 4)
  assert_true(
    retained_requests()[3]
    is {
      "url": String(
        "/api/v1/cowork-gateway/v1/cowork/sessions/cowork:fixture/config"
      ),
      "body": { "model": String("moongate/chosen"), .. },
      ..
    },
  )
  complete_question_http(
    3,
    retained_session_json(Some("moongate/chosen")),
    false,
  )
  assert_eq(retained_requests().length(), 5)
  assert_true(
    retained_requests()[4]
    is {
      "url": String(
        "/api/v1/cowork-gateway/v1/cowork/sessions/cowork:fixture/messages"
      ),
      ..
    },
  )
  complete_question_http(
    4,
    retained_session_json(Some("moongate/chosen")),
    false,
  )
  assert_true(cell.val.qa_ready)
  assert_eq(cell.val.qa_canonical_key, Some("cowork:fixture"))
  assert_false(
    qa_test_render(cell.val).contains("HISTORIC ANSWER MUST STAY HIDDEN"),
  )
}

///|
test "lost creation reply reads durable canonical session and duplicate prepare cannot create again" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let (cell, dispatch) = retained_harness(
    apply_native_route(route_model(), 7, route_fixture()),
  )
  ignore(dispatch(PrepareQa))
  ignore(dispatch(PrepareQa))
  assert_eq(retained_requests().length(), 1)
  assert_true(
    retained_requests()[0]
    is {
      "body": {
        "moonfind_purpose": String("qa"),
        "moonfind_run_id": String("run-1"),
        ..
      },
      ..
    },
  )
  complete_question_http(0, "reply lost", true)
  assert_eq(cell.val.qa_agent_status, "creation-uncertain")
  ignore(dispatch(PrepareQa))
  assert_eq(retained_requests().length(), 2)
  assert_true(
    retained_requests()[1]
    is { "method": String("GET"), "url": String("/api/v1/workspace"), .. },
  )
  complete_question_http(
    1,
    retained_snapshot_json("retained", Some("cowork:fixture")),
    false,
  )
  complete_question_http(2, retained_route_json(), false)
  complete_question_http(3, retained_session_json(None), false)
  assert_eq(cell.val.qa_agent_status, "retained")
  assert_true(cell.val.qa_session is Some(_))
  assert_false(cell.val.qa_ready)
  assert_eq(retained_requests().length(), 4)
  ignore(dispatch(PrepareQa))
  assert_eq(retained_requests().length(), 4)
  ignore(dispatch(FinishQaPreparation))
  assert_eq(retained_requests().length(), 5)
  assert_true(
    retained_requests()[4]
    is {
      "url": String(
        "/api/v1/cowork-gateway/v1/cowork/sessions/cowork:fixture/config"
      ),
      ..
    },
  )
}

///|
test "uncertain creation remains explicit across repeated readback and missing readback cannot enable replacement" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let (cell, dispatch) = retained_harness(
    apply_native_route(route_model(), 7, route_fixture()),
  )
  ignore(dispatch(PrepareQa))
  complete_question_http(0, "reply lost", true)
  complete_question_http(1, "host unavailable", true)
  assert_eq(cell.val.qa_agent_status, "creation-uncertain")
  assert_false(cell.val.qa_readback_loading)
  ignore(dispatch(PrepareQa))
  assert_eq(retained_requests().length(), 2)
  ignore(dispatch(RefreshQa))
  ignore(dispatch(RefreshQa))
  assert_eq(retained_requests().length(), 3)
  complete_question_http(
    2,
    retained_snapshot_json("creation-uncertain", None),
    false,
  )
  assert_eq(retained_requests().length(), 4)
  assert_eq(cell.val.qa_agent_status, "creation-uncertain")
  assert_true(qa_test_render(cell.val).contains("Check retained session"))
  assert_false(qa_test_render(cell.val).contains("Prepare Q&A agent"))
  ignore(dispatch(PrepareQa))
  assert_eq(retained_requests().length(), 4)
}

///|
test "confirmed no-role readback permits explicit create retry but never auto creates" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let (cell, dispatch) = retained_harness(
    apply_native_route(route_model(), 7, route_fixture()),
  )
  ignore(dispatch(PrepareQa))
  complete_question_http(0, "failed before host", true)
  complete_question_http(1, retained_snapshot_json("not-created", None), false)
  complete_question_http(2, retained_route_json(), false)
  assert_eq(cell.val.qa_agent_status, "not-created")
  assert_eq(retained_requests().length(), 3)
  ignore(dispatch(PrepareQa))
  assert_eq(retained_requests().length(), 4)
  assert_true(
    retained_requests()[3]
    is {
      "url": String("/api/v1/cowork-gateway/v1/cowork/sessions"),
      "body": { "moonfind_run_id": String("run-1"), .. },
      ..
    },
  )
}

///|
test "retained provenance mismatch has no session GET or POST and requires trusted reconnect" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let (cell, dispatch) = retained_harness(initial_model())
  ignore(dispatch(RefreshQa))
  complete_question_http(
    0,
    retained_snapshot_json("reconnect-required", Some("cowork:fixture")),
    false,
  )
  complete_question_http(1, retained_route_json(), false)
  ignore(dispatch(PrepareQa))
  ignore(dispatch(FinishQaPreparation))
  ignore(dispatch(AskQa))
  assert_eq(retained_requests().length(), 2)
  assert_true(cell.val.qa_session is None)
  assert_false(cell.val.qa_ready)
  assert_true(
    qa_test_render(cell.val).contains("original trusted host configuration"),
  )
  assert_true(qa_test_render(cell.val).contains("Check retained session"))
}

///|
test "restore request fences generation run gateway Book and canonical key for both late success and failure" {
  let snapshot = {
    ..route_snapshot("run-1"),
    qa_cowork_session_key: Some("cowork:fixture"),
    qa_agent_status: "retained",
  }
  let (_, pending) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(1, Ok(snapshot)),
    initial_model(),
  )
  guard pending.pending_qa_restore is Some(request) else {
    fail("restore absent")
  }
  let (_, edited) = update(
    _ => @rabbita.none,
    SetBookDir("/other/book"),
    pending,
  )
  let (_, changed_run) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(
      1,
      Ok({
        ..route_snapshot("run-new"),
        qa_agent_status: "retained",
        qa_cowork_session_key: Some("cowork:fixture"),
      }),
    ),
    pending,
  )
  for
    stale in [
      { ..pending, workspace_generation: 2, },
      { ..pending, gateway_base: "/different-gateway", },
      { ..pending, trusted_book_dir: "/different/book", },
      { ..pending, qa_canonical_key: Some("cowork:new"), },
      edited,
      changed_run,
    ] {
    for
      message in [
        QaReconnected(request, Ok(route_session(Some("codex/old")))),
        QaReconnected(request, Err("STALE RESTORE ERROR")),
      ] {
      let (_, next) = update(_ => @rabbita.none, message, stale)
      assert_eq(next.model_name, stale.model_name)
      assert_eq(next.qa_error, stale.qa_error)
      assert_eq(next.pending_qa_restore, stale.pending_qa_restore)
      assert_eq(
        next.qa_session.map(session => session.session.session_key),
        stale.qa_session.map(session => session.session.session_key),
      )
      assert_false(next.qa_ready)
    }
  }
}

///|
test "wrong-key and wrong-Book restore replies cannot configure use or replace the canonical session" {
  let snapshot = {
    ..route_snapshot("run-1"),
    qa_cowork_session_key: Some("cowork:fixture"),
    qa_agent_status: "retained",
  }
  let (_, pending) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(1, Ok(snapshot)),
    initial_model(),
  )
  guard pending.pending_qa_restore is Some(request) else {
    fail("restore absent")
  }
  let session = route_session(Some("codex/wrong"))
  for
    bad in [
      {
        ..session,
        session: { ..session.session, session_key: "cowork:wrong", },
      },
      { ..session, session: { ..session.session, cwd: Some("/wrong/book"), }, },
    ] {
    let (_, rejected) = update(
      _ => @rabbita.none,
      QaReconnected(request, Ok(bad)),
      pending,
    )
    assert_eq(rejected.qa_agent_status, "reconnect-required")
    assert_eq(rejected.qa_canonical_key, Some("cowork:fixture"))
    assert_eq(rejected.model_name, "")
    assert_true(rejected.qa_session is None)
    assert_false(rejected.qa_ready)
    let (_, blocked) = update(_ => @rabbita.none, PrepareQa, rejected)
    assert_true(blocked.pending_qa is None)
  }
}

///|
test "retained unavailable native selector stays exact and never falls back to catalog default or Codex" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let (cell, dispatch) = retained_harness({
    ..initial_model(),
    qa_question: "Explain evidence",
  })
  ignore(dispatch(RefreshQa))
  complete_question_http(
    0,
    retained_snapshot_json("retained", Some("cowork:fixture")),
    false,
  )
  complete_question_http(
    2,
    retained_session_json(Some("moongate/unavailable")),
    false,
  )
  complete_question_http(1, retained_route_json(), false)
  assert_eq(cell.val.model_name, "moongate/unavailable")
  ignore(dispatch(AskQa))
  assert_eq(retained_requests().length(), 3)
  assert_true(cell.val.pending_question is None)
  assert_eq(
    cell.val.qa_session.bind(session => session.session.model_override),
    Some("moongate/unavailable"),
  )
  ignore(dispatch(SetModelName("codex/manual")))
  ignore(dispatch(AskQa))
  assert_eq(retained_requests().length(), 3)
  assert_eq(cell.val.qa_question, "Explain evidence")
}

///|
test "legacy workspace statuses decode without new fields and grounded verified uses read-only binding" {
  for state in ["not-published", "not-created", "grounded_verified", "retained"] {
    let key = if state == "not-published" || state == "not-created" {
      None
    } else {
      Some("cowork:fixture")
    }
    let snapshot : WorkspaceSnapshot = @json.from_json(
      @json.parse(retained_snapshot_json(state, key)),
    )
    let (_, model) = update(
      _ => @rabbita.none,
      WorkspaceLoaded(1, Ok(snapshot)),
      initial_model(),
    )
    assert_eq(model.qa_canonical_key, key)
    assert_eq(model.pending_qa_restore is Some(_), key is Some(_))
    assert_true(model.pending_qa is None)
  }
}

///|
test "checking retained Q&A cannot abandon a concurrent research creation" {
  let ready = apply_native_route(route_model(), 7, route_fixture())
  let request = submission_context(ready, 1)
  let creating = {
    ..ready,
    pending_research: Some(request),
    research_session: Some(route_session(None)),
    research_execution: Some(route_execution()),
    research_message_sent: false,
    phase: CreatingSession,
  }
  let (_, readback) = update(_ => @rabbita.none, RefreshQa, creating)
  assert_eq(readback.pending_research, Some(request))
  assert_eq(
    readback.research_session.map(session => session.session.session_key),
    Some("cowork:fixture"),
  )
  assert_false(readback.research_message_sent)
  let (_, continued) = update(
    _ => @rabbita.none,
    ResearchConfigured(request, Ok(route_session(Some("moongate/chosen")))),
    readback,
  )
  assert_true(continued.research_message_sent)
}

///|
test "late HTTP restore completion and failure cannot replace a newer same-run readback" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let (cell, dispatch) = retained_harness(initial_model())
  ignore(dispatch(RefreshQa))
  complete_question_http(
    0,
    retained_snapshot_json("retained", Some("cowork:fixture")),
    false,
  )
  let old_request = cell.val.pending_qa_restore
  ignore(dispatch(RefreshQa))
  complete_question_http(
    3,
    retained_snapshot_json("retained", Some("cowork:fixture")),
    false,
  )
  let current_request = cell.val.pending_qa_restore
  assert_false(old_request == current_request)
  complete_question_http(2, retained_session_json(Some("codex/old")), false)
  complete_question_http(2, "STALE ERROR", true)
  assert_eq(cell.val.pending_qa_restore, current_request)
  assert_eq(cell.val.model_name, "")
  complete_question_http(4, retained_route_json(), false)
  complete_question_http(
    5,
    retained_session_json(Some("moongate/other")),
    false,
  )
  assert_eq(cell.val.model_name, "moongate/other")
  assert_true(cell.val.qa_ready)
  complete_question_http(2, retained_session_json(Some("codex/old")), false)
  assert_eq(cell.val.model_name, "moongate/other")
  assert_eq(retained_requests().length(), 6)
  for request in retained_requests() {
    assert_true(request is { "method": String("GET"), .. })
  }
}

///|
test "retained readback failure retries the same key with GET and keeps question draft" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let (cell, dispatch) = retained_harness({
    ..initial_model(),
    qa_question: "Draft survives disconnect",
  })
  ignore(dispatch(RefreshQa))
  complete_question_http(
    0,
    retained_snapshot_json("retained", Some("cowork:fixture")),
    false,
  )
  complete_question_http(1, retained_route_json(), false)
  complete_question_http(2, "offline", true)
  assert_true(cell.val.pending_qa_restore is None)
  assert_eq(cell.val.qa_canonical_key, Some("cowork:fixture"))
  assert_eq(cell.val.qa_question, "Draft survives disconnect")
  ignore(dispatch(PrepareQa))
  assert_eq(retained_requests().length(), 3)
  ignore(dispatch(RefreshQa))
  complete_question_http(
    3,
    retained_snapshot_json("retained", Some("cowork:fixture")),
    false,
  )
  assert_true(
    retained_requests()[5]
    is {
      "method": String("GET"),
      "url": String("/api/v1/cowork-gateway/v1/cowork/sessions/cowork:fixture"),
      ..
    },
  )
  complete_question_http(
    5,
    retained_session_json(Some("moongate/chosen")),
    false,
  )
  assert_true(cell.val.qa_ready)
  assert_eq(cell.val.qa_question, "Draft survives disconnect")
}

///|
test "failed bootstrap keeps canonical session and explicit finish cannot display unchanged historic tail" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let (cell, dispatch) = retained_harness(
    apply_native_route(route_model(), 7, route_fixture()),
  )
  ignore(dispatch(PrepareQa))
  complete_question_http(0, retained_session_json(None), false)
  complete_question_http(
    1,
    retained_session_json(Some("moongate/chosen")),
    false,
  )
  complete_question_http(2, "bootstrap reply lost", true)
  assert_false(cell.val.qa_ready)
  assert_eq(cell.val.qa_canonical_key, Some("cowork:fixture"))
  assert_true(cell.val.qa_session is Some(_))
  ignore(dispatch(PrepareQa))
  assert_eq(retained_requests().length(), 3)
  ignore(dispatch(FinishQaPreparation))
  complete_question_http(
    3,
    retained_session_json(Some("moongate/chosen")),
    false,
  )
  complete_question_http(
    4,
    retained_session_json(Some("moongate/chosen")),
    false,
  )
  assert_true(cell.val.qa_ready)
  assert_true(
    cell.val.qa_answer_text is None && cell.val.qa_response_context is None,
  )
  assert_false(
    qa_test_render(cell.val).contains("HISTORIC ANSWER MUST STAY HIDDEN"),
  )
  assert_eq(retained_requests().length(), 5)
  assert_true(
    retained_requests()[3]
    is {
      "url": String(
        "/api/v1/cowork-gateway/v1/cowork/sessions/cowork:fixture/config"
      ),
      ..
    },
  )
}

///|
test "unknown host role states fail closed and edited Book requires explicit trusted reconnect" {
  let snapshot = {
    ..route_snapshot("run-1"),
    qa_agent_status: "unknown-new-state",
  }
  let (_, unknown) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(1, Ok(snapshot)),
    initial_model(),
  )
  assert_eq(unknown.qa_agent_status, "creation-uncertain")
  let (_, blocked) = update(_ => @rabbita.none, PrepareQa, unknown)
  assert_true(blocked.pending_qa is None)
  let snapshot = {
    ..snapshot,
    qa_agent_status: "retained",
    qa_cowork_session_key: Some("cowork:fixture"),
  }
  let (_, edited) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(1, Ok(snapshot)),
    { ..route_model(), book_dir: "/edited/book", },
  )
  assert_eq(edited.book_dir, "/edited/book")
  assert_true(edited.pending_qa_restore is None)
  assert_true(
    qa_test_render(edited).contains("Restore trusted Book and reconnect"),
  )
  let (_, reconnecting) = update(_ => @rabbita.none, RefreshQa, edited)
  assert_eq(reconnecting.book_dir, "/trusted/book")
  assert_true(reconnecting.qa_readback_loading)
}

///|
test "older same-scope snapshot cannot erase an acknowledged canonical key and reopen create" {
  let ready = {
    ..qa_ready_model(),
    qa_canonical_key: Some("cowork:fixture"),
    qa_agent_status: "retained",
  }
  let (_, refreshed) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(
      1,
      Ok({ ..route_snapshot("run-1"), qa_agent_status: "not-created", }),
    ),
    ready,
  )
  assert_eq(refreshed.qa_canonical_key, Some("cowork:fixture"))
  assert_eq(refreshed.qa_agent_status, "retained")
  let (_, blocked) = update(_ => @rabbita.none, PrepareQa, refreshed)
  assert_true(blocked.pending_qa is None)
}
