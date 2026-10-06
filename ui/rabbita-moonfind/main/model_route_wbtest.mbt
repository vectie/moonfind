///|
fn route_workspace(run_id? : String = "run-1") -> DurableResearchWorkspace {
  {
    product_id: "moonfind",
    title: "Test",
    run_id,
    status: "awaiting-agent-analysis",
    watch_title: "Test",
    query: "test",
    paper_count: 1,
    summary_count: 0,
    idea_count: 0,
    question_count: 0,
    accepted_idea_count: 0,
    papers: None,
    summaries: None,
    ideas: None,
    questions: None,
    active_stage: "analysis",
    validation_issues: [],
    bookkeeper_route: "moonbook.bookkeeper",
    three_gap_state: "pending",
  }
}

///|
fn route_fixture(
  default_model? : String = "moongate/chosen",
  ready? : Bool = true,
) -> NativeModelRoute {
  {
    contract_id: "moonfind.native-model-route.v1",
    run_id: "run-1",
    cwd: "/trusted/book",
    catalog_ready: true,
    default_ready: ready,
    default_model,
    models: ["moongate/other", "moongate/chosen"],
    blocker: if ready {
      ""
    } else {
      "MoonGate default model is not configured for this Cowork workspace."
    },
  }
}

///|
fn route_model() -> Model {
  {
    ..initial_model(),
    workspace: Some(route_workspace()),
    book_dir: "/trusted/book",
    trusted_book_dir: "/trusted/book",
    gateway_base: "/api/v1/cowork-gateway",
    gateway_published: true,
    route_generation: 7,
  }
}

///|
fn route_session(selector : String?) -> CoworkSessionDetail {
  {
    session: {
      session_key: "cowork:fixture",
      session_id: "fixture",
      title: "Fixture",
      updated_at: 1,
      state: "ready",
      last_message_preview: None,
      channel: None,
      cwd: Some("/trusted/book"),
      model_override: selector,
      provider_override: None,
      has_plan_mode: false,
      linked_proposal_id: None,
      linked_run_id: None,
    },
    messages: [],
    plan_preview: None,
    linked_proposal: None,
    linked_run: None,
  }
}

///|
fn route_execution() -> ResearchExecutionProjection {
  {
    contract_id: "moonfind.research-execution-record.v1",
    revision: 1,
    run_id: "run-1",
    operation_ref: "moonfind/research.prepare-analysis@0.1.0",
    request_id: "request-1",
    attempt_id: "attempt-1",
    idempotency_key: "run-1/attempt-1",
    state: "command-ready",
    invocation: Json::empty_object(),
    receipt_ref: None,
    receipt: Some({
      output: Some({
        "protocol": "moonclaw.mooncode.v1",
        "model": "",
        "command": "prompt",
      }),
    }),
    result_ref: None,
    moonclaw_session_key: None,
    moonclaw_run_id: None,
    error_kind: "",
    requires_review: true,
    next_action: "submit",
    updated_at: "2026-10-03T00:00:00Z",
  }
}

///|
fn route_snapshot(run_id : String) -> WorkspaceSnapshot {
  {
    contract_id: "moonfind.ui-workspace.v1",
    product_id: "moonfind",
    generated_at: "2026-10-03T00:00:01Z",
    book_workspace: "/trusted/book",
    workspace: route_workspace(run_id~),
    research_cowork_session_key: None,
    qa_cowork_session_key: None,
    qa_agent_status: "not-published",
    research_execution: None,
    capability_submit_url: None,
    capability_reconcile_url: None,
    capability_checkpoint_url: None,
    moonclaw_gateway_base: Some("/api/v1/cowork-gateway"),
    host_status: "ready",
    host_blockers: [],
    moontown_result: None,
    moontown_handoff: {
      contract_id: "moonfind.moontown-handoff-status.v1",
      run_id,
      state: "not-ready",
      handoff_contract: "moontown.civic.communication.handoff.v1",
      handoff_id: None,
      handoff_url: None,
      open_url: None,
      receipt_contract: None,
      receipt_status: None,
      detail: "Not ready",
    },
    review_workflow: {
      contract_id: "moonfind.review-workflow-status.v1",
      run_id,
      state: "not-ready",
      prepare_url: None,
      moonchat_ingest_url: None,
      moonchat_operation_ref: None,
      bundle_ref: None,
      record_ref: None,
      bookkeeper_operation_ref: None,
      bookkeeper_submission_ref: None,
      decision_receipt: None,
      detail: "Not ready",
    },
  }
}

///|
test "fresh UI has no invented selector or readiness and exact non-first native default is selected" {
  let fresh = initial_model()
  assert_eq(fresh.model_name, "")
  assert_eq(phase_text(fresh.phase), "Not started")
  assert_false(fresh.gateway_published)
  let selected = apply_native_route(route_model(), 7, route_fixture())
  assert_eq(selected.model_name, "moongate/chosen")
  assert_eq(model_route_issue(selected, "/trusted/book"), None)
  let missing = apply_native_route(
    route_model(),
    7,
    route_fixture(default_model="", ready=false),
  )
  assert_eq(missing.model_name, "")
  assert_true(model_route_issue(missing, "/trusted/book") is Some(_))
  let unavailable = apply_native_route(
    route_model(),
    7,
    route_fixture(default_model="moongate/missing"),
  )
  assert_eq(unavailable.model_name, "")
  let health_only = { ..route_model(), host_status: "ready", }
  assert_true(model_route_issue(health_only, "/trusted/book") is Some(_))
}

///|
test "late route discovery preserves user edits saved selection unavailable exact choice and explicit legacy" {
  let (_, typed) = update(
    _ => @rabbita.none,
    SetModelName("moongate/other"),
    route_model(),
  )
  let typed = apply_native_route(
    typed,
    7,
    route_fixture(default_model="", ready=false),
  )
  assert_eq(typed.model_name, "moongate/other")
  assert_eq(model_route_issue(typed, "/trusted/book"), None)
  let saved = restore_model_selection(
    route_model(),
    route_session(Some("moongate/missing")),
  )
  let saved = apply_native_route(saved, 7, route_fixture())
  assert_eq(saved.model_name, "moongate/missing")
  assert_true(model_route_issue(saved, "/trusted/book") is Some(_))
  assert_eq(
    restore_model_selection(typed, route_session(Some("codex/manual"))).model_name,
    "moongate/other",
  )
  let (_, legacy) = update(
    _ => @rabbita.none,
    SetModelName("codex/manual"),
    route_model(),
  )
  assert_eq(
    apply_native_route(legacy, 7, route_fixture()).model_name,
    "codex/manual",
  )
  assert_eq(model_route_issue(legacy, "/trusted/book"), None)
  let (_, cleared) = update(_ => @rabbita.none, SetModelName(""), typed)
  assert_eq(apply_native_route(cleared, 7, route_fixture()).model_name, "")
  assert_true(model_route_issue(cleared, "/trusted/book") is Some(_))
}

///|
test "route refresh generation run identity folder mismatch and recovery are enforced" {
  assert_eq(
    apply_native_route(route_model(), 6, route_fixture()).model_name,
    "",
  )
  assert_eq(
    apply_native_route(
      { ..route_model(), workspace: Some(route_workspace(run_id="new-run")), },
      7,
      route_fixture(),
    ).model_name,
    "",
  )
  let ready = apply_native_route(route_model(), 7, route_fixture())
  let (_, moved) = update(
    _ => @rabbita.none,
    SetBookDir("/another/book"),
    ready,
  )
  assert_true(model_route_issue(moved, "/another/book") is Some(_))
  assert_eq(
    apply_native_route(moved, 7, route_fixture()).native_route.map(route => {
      route.cwd
    }),
    None,
  )
  let (_, recovered) = update(
    _ => @rabbita.none,
    SetBookDir("/trusted/book"),
    moved,
  )
  assert_true(model_route_issue(recovered, "/trusted/book") is Some(_))
  let recovered = apply_native_route(
    recovered,
    recovered.route_generation,
    route_fixture(),
  )
  assert_eq(model_route_issue(recovered, "/trusted/book"), None)
  let (_, stale_workspace) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(0, Err("stale")),
    ready,
  )
  assert_eq(stale_workspace.error, ready.error)
}

///|
test "new run resets saved session and automatic defaults while stale run replies cannot restore them" {
  let old = restore_model_selection(
    apply_native_route(route_model(), 7, route_fixture()),
    route_session(Some("moongate/other")),
  )
  let request = submission_context(old, 3)
  let old = {
    ..old,
    research_session: Some(route_session(Some("moongate/other"))),
    qa_session: Some(route_session(Some("moongate/other"))),
    pending_research: Some(request),
    pending_qa: Some(request),
    qa_ready: true,
  }
  let (_, reset) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(1, Ok(route_snapshot("new-run"))),
    old,
  )
  assert_eq(reset.model_name, "")
  assert_eq(reset.model_source, "automatic")
  assert_true(
    reset.research_session is None &&
    reset.qa_session is None &&
    reset.native_route is None,
  )
  assert_true(reset.pending_research is None && reset.pending_qa is None)
  assert_false(reset.qa_ready)
  for
    message in [
      ResearchRefreshed("run-1", Ok(route_session(Some("codex/old")))),
      QaReconnected(
        {
          workspace_generation: 1,
          run_id: "run-1",
          gateway: old.gateway_base,
          cwd: old.book_dir,
          session_key: "cowork:fixture",
        },
        Ok(route_session(Some("codex/old"))),
      ),
      ResearchConfigured(request, Ok(route_session(Some("moongate/other")))),
      QaBootstrapped(request, Ok(route_session(Some("moongate/other")))),
    ] {
    let (_, late) = update(_ => @rabbita.none, message, reset)
    assert_eq(late.model_name, "")
    assert_true(late.research_session is None && late.qa_session is None)
  }
  let (_, edited) = update(
    _ => @rabbita.none,
    SetBookDir("/edited/book"),
    route_model(),
  )
  let (_, refreshed) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(1, Ok(route_snapshot("run-1"))),
    edited,
  )
  assert_eq(refreshed.book_dir, "/edited/book")
  assert_true(model_route_issue(refreshed, refreshed.book_dir) is Some(_))
}

///|
test "config response requires exact captured model and late edited response cannot submit" {
  let ready = apply_native_route(route_model(), 7, route_fixture())
  let request = submission_context(ready, 1)
  assert_eq(
    configured_selection_issue(request, route_session(Some("moongate/chosen"))),
    None,
  )
  assert_true(
    configured_selection_issue(request, route_session(None)) is Some(_),
  )
  assert_true(
    configured_selection_issue(request, route_session(Some("codex/other")))
    is Some(_),
  )
  let pending = { ..ready, pending_research: Some(request), }
  assert_true(submission_current(pending, request, pending.pending_research))
  let (_, edited) = update(
    _ => @rabbita.none,
    SetModelName("moongate/other"),
    pending,
  )
  let (_, late) = update(
    _ => @rabbita.none,
    ResearchConfigured(request, Ok(route_session(Some("moongate/chosen")))),
    edited,
  )
  assert_eq(late.model_name, "moongate/other")
  assert_true(late.research_session is None)
  let (_, failed) = update(
    _ => @rabbita.none,
    ResearchConfigured(request, Err("config failed")),
    pending,
  )
  assert_true(failed.pending_research is None)
  assert_eq(failed.error, Some("config failed"))
}

///|
test "research and Q&A prevent blank config instead of clearing to Cowork default" {
  let (_, qa) = update(_ => @rabbita.none, PrepareQa, route_model())
  assert_true(qa.pending_qa is None)
  assert_true(qa.error is Some(_))
  let ready = apply_native_route(route_model(), 7, route_fixture())
  let (_, qa) = update(_ => @rabbita.none, PrepareQa, ready)
  assert_eq(qa.pending_qa.map(value => value.selector), Some("moongate/chosen"))
  let (_, duplicate) = update(_ => @rabbita.none, PrepareQa, qa)
  assert_eq(duplicate.submission_generation, qa.submission_generation)
}

///|
struct RouteTestScheduler {
  hooks : @cmd.Hooks
}

///|
impl @cmd.Scheduler for RouteTestScheduler with fn run_effect(
  self,
  _kind,
  effect,
) {
  effect(self)
}

///|
impl @cmd.Scheduler for RouteTestScheduler with fn queue_message(
  _self,
  _id,
  send,
) {
  send()
}

///|
impl @cmd.Scheduler for RouteTestScheduler with fn drain_message(_self) {
  ()
}

///|
impl @cmd.Scheduler for RouteTestScheduler with fn hooks(self) {
  self.hooks
}

///|
extern "js" fn install_route_http_fixture(fail_config : Bool) -> Unit =
  #| (failConfig) => {
  #|   globalThis.__moonfindOldFetch = globalThis.fetch;
  #|   globalThis.__moonfindRequests = [];
  #|   const chain = (value, error) => ({then(fn) { if (error) return chain(null, error); try { return fn(value) || chain(null, null); } catch(e) { return chain(null, e); } }, catch(fn) { if(error) fn(error); return chain(null, null); }});
  #|   globalThis.fetch = (url, options) => {
  #|     const body = options.body ? JSON.parse(options.body) : null;
  #|     globalThis.__moonfindRequests.push({url, body});
  #|     if (url.endsWith('/config') && failConfig) return chain(null, new Error('fixture config rejected'));
  #|     const summary = {session_key:'cowork:fixture', session_id:'fixture', title:'Fixture', updated_at:1, state:'ready', cwd:'/trusted/book', has_plan_mode:false};
  #|     if (body?.model) summary.model_override = body.model;
  #|     const reply = {session:{session:summary, messages:[]}};
  #|     return chain({text:() => chain(JSON.stringify(reply), null)}, null);
  #|   };
  #| }

///|
extern "js" fn route_http_requests() -> String = "() => JSON.stringify(globalThis.__moonfindRequests)"

///|
extern "js" fn restore_route_http_fixture() -> Unit = "() => { globalThis.fetch = globalThis.__moonfindOldFetch; }"

///|
test "actual UI HTTP command uses exact selected model in Cowork config and messages" {
  install_route_http_fixture(false)
  defer restore_route_http_fixture()
  let scheduler = RouteTestScheduler::{
    hooks: { url_request: None, url_changed: None, },
  }
  let cell = Ref::new(apply_native_route(route_model(), 7, route_fixture()))
  fn dispatch(message : Msg) -> @rabbita.Cmd {
    let (command, next) = update(dispatch, message, cell.val)
    cell.val = next
    @cmd.Scheduler::add(scheduler, command)
    @rabbita.none
  }
  ignore(dispatch(PrepareQa))
  let requests = @json.parse(route_http_requests())
  assert_eq(cell.val.error, None)
  guard requests is Array(items) else { fail("missing recorded requests") }
  assert_eq(items.length(), 3)
  assert_true(
    items[1]
    is {
      "url": String(
        "/api/v1/cowork-gateway/v1/cowork/sessions/cowork:fixture/config"
      ),
      "body": {
        "model": String("moongate/chosen"),
        "cwd": String("/trusted/book"),
        ..
      },
      ..
    },
  )
  assert_true(
    items[2] is { "body": { "model": String("moongate/chosen"), .. }, .. },
  )
  assert_true(cell.val.qa_ready)
}

///|
test "actual UI HTTP config failure never sends a Cowork message" {
  install_route_http_fixture(true)
  defer restore_route_http_fixture()
  let scheduler = RouteTestScheduler::{
    hooks: { url_request: None, url_changed: None, },
  }
  let cell = Ref::new(apply_native_route(route_model(), 7, route_fixture()))
  fn dispatch(message : Msg) -> @rabbita.Cmd {
    let (command, next) = update(dispatch, message, cell.val)
    cell.val = next
    @cmd.Scheduler::add(scheduler, command)
    @rabbita.none
  }
  ignore(dispatch(PrepareQa))
  assert_true(cell.val.error is Some(_))
  guard @json.parse(route_http_requests()) is Array(items) else {
    fail("missing requests")
  }
  assert_eq(items.length(), 2)
  assert_false(cell.val.qa_ready)
  assert_true(cell.val.error is Some(_))
}

///|
test "actual research HTTP journey configures exact native selector without changing immutable command receipt" {
  install_route_http_fixture(false)
  defer restore_route_http_fixture()
  let scheduler = RouteTestScheduler::{
    hooks: { url_request: None, url_changed: None, },
  }
  let original = route_execution()
  let cell = Ref({
    ..apply_native_route(route_model(), 7, route_fixture()),
    research_execution: Some(original),
  })
  fn dispatch(message : Msg) -> @rabbita.Cmd {
    let (command, next) = update(dispatch, message, cell.val)
    cell.val = next
    @cmd.Scheduler::add(scheduler, command)
    @rabbita.none
  }
  ignore(dispatch(StartResearch))
  assert_eq(cell.val.error, None)
  guard @json.parse(route_http_requests()) is Array(items) else {
    fail("missing requests")
  }
  assert_eq(items.length(), 3)
  assert_true(
    items[1] is { "body": { "model": String("moongate/chosen"), .. }, .. },
  )
  assert_true(
    items[2]
    is {
      "body": {
        "model": String("moongate/chosen"),
        "source_request_id": String("request-1"),
        ..
      },
      ..
    },
  )
  assert_eq(
    cell.val.research_execution
    .bind(record => record.receipt)
    .bind(receipt => receipt.output),
    original.receipt.bind(receipt => receipt.output),
  )
}

///|
test "old capability and checkpoint success and failure cannot cross run or attempt boundaries" {
  let old = route_execution()
  let current = {
    ..old,
    run_id: "new-run",
    request_id: "new-request",
    attempt_id: "new-attempt",
  }
  let model = {
    ..route_model(),
    workspace: Some(route_workspace(run_id="new-run")),
    research_execution: Some(current),
  }
  let reply : CapabilityOperationReply = {
    contract_id: "moonfind.capability-operation-reply.v1",
    operation: "submit",
    blocked: false,
    message: "ready",
    execution: old,
  }
  for
    message in [
      CapabilitySubmitted(old, Ok(reply)),
      CapabilitySubmitted(old, Err("old failure")),
      ExecutionCheckpointed(old, Ok(reply)),
      ExecutionCheckpointed(old, Err("old failure")),
    ] {
    let (_, next) = update(_ => @rabbita.none, message, model)
    assert_eq(
      next.research_execution.map(record => record.run_id),
      Some("new-run"),
    )
    assert_true(next.pending_research is None)
    assert_eq(next.error, None)
  }
  let newer = {
    ..route_model(),
    research_execution: Some({ ..old, attempt_id: "new-attempt", }),
  }
  let (_, next) = update(
    _ => @rabbita.none,
    CapabilitySubmitted(old, Err("old attempt failure")),
    newer,
  )
  assert_eq(next.error, None)
}

///|
test "selection editing abandons only unsubmitted sessions and old QA completion cannot replace a retry" {
  let ready = {
    ..apply_native_route(route_model(), 7, route_fixture()),
    research_execution: Some(route_execution()),
  }
  let request = submission_context(ready, 1)
  let creating = {
    ..ready,
    phase: CreatingSession,
    pending_research: Some(request),
    research_session: Some(route_session(None)),
  }
  let (_, changed) = update(
    _ => @rabbita.none,
    SetModelName("moongate/other"),
    creating,
  )
  assert_true(
    changed.pending_research is None && changed.research_session is None,
  )
  let (_, retry) = update(_ => @rabbita.none, StartResearch, changed)
  assert_eq(
    retry.pending_research.map(value => value.selector),
    Some("moongate/other"),
  )
  let newer_request = { ..request, generation: 2, }
  let newer = {
    ..ready,
    pending_qa: Some(newer_request),
    qa_session: Some(route_session(Some("moongate/chosen"))),
  }
  let (_, after_old) = update(
    _ => @rabbita.none,
    QaBootstrapped(request, Ok(route_session(Some("codex/old")))),
    newer,
  )
  assert_eq(after_old.pending_qa, Some(newer_request))
  assert_false(after_old.qa_ready)
}

///|
test "saved choice restoration blocks automatic launch including completed runs but allows explicit user intent" {
  let snapshot = {
    ..route_snapshot("run-1"),
    research_cowork_session_key: Some("cowork:fixture"),
    research_execution: Some({ ..route_execution(), state: "needs-review", }),
  }
  let (_, waiting) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(1, Ok(snapshot)),
    initial_model(),
  )
  let routed = apply_native_route(
    waiting,
    waiting.route_generation,
    route_fixture(),
  )
  assert_eq(routed.model_name, "")
  assert_true(model_route_issue(routed, routed.book_dir) is Some(_))
  let (_, blocked) = update(_ => @rabbita.none, PrepareQa, routed)
  assert_true(blocked.pending_qa is None)
  let (_, restored) = update(
    _ => @rabbita.none,
    SavedSelectionRestored(
      "run-1",
      "cowork:fixture",
      Ok(route_session(Some("moongate/other"))),
    ),
    routed,
  )
  assert_eq(restored.model_name, "moongate/other")
  assert_eq(restored.phase, Completed)
  assert_true(restored.research_session is None)
  let (_, typed) = update(
    _ => @rabbita.none,
    SetModelName("codex/manual"),
    routed,
  )
  assert_eq(model_route_issue(typed, typed.book_dir), None)
  let (_, kept) = update(
    _ => @rabbita.none,
    SavedSelectionRestored(
      "run-1",
      "cowork:fixture",
      Ok(route_session(Some("moongate/other"))),
    ),
    typed,
  )
  assert_eq(kept.model_name, "codex/manual")
}

///|
test "research retries creation while QA finishes the retained session after config failure" {
  for qa in [false, true] {
    install_route_http_fixture(true)
    let scheduler = RouteTestScheduler::{
      hooks: { url_request: None, url_changed: None, },
    }
    let cell = Ref({
      ..apply_native_route(route_model(), 7, route_fixture()),
      research_execution: Some(route_execution()),
    })
    fn dispatch(message : Msg) -> @rabbita.Cmd {
      let (command, next) = update(dispatch, message, cell.val)
      cell.val = next
      @cmd.Scheduler::add(scheduler, command)
      @rabbita.none
    }
    ignore(dispatch(if qa { PrepareQa } else { StartResearch }))
    assert_true(cell.val.error is Some(_))
    assert_true(
      if qa {
        cell.val.qa_session is Some(_) &&
        cell.val.qa_canonical_key == Some("cowork:fixture")
      } else {
        cell.val.research_session is None
      },
    )
    restore_route_http_fixture()
    install_route_http_fixture(false)
    ignore(dispatch(if qa { FinishQaPreparation } else { StartResearch }))
    assert_eq(cell.val.error, None)
    guard @json.parse(route_http_requests()) is Array(items) else {
      fail("missing requests")
    }
    assert_eq(items.length(), if qa { 2 } else { 3 })
    restore_route_http_fixture()
  }
}

///|
test "duplicate capability reply after dispatch cannot create another submission" {
  let prepared = { ..route_execution(), state: "prepared", revision: 0, }
  let ready = route_execution()
  let reply : CapabilityOperationReply = {
    contract_id: "moonfind.capability-operation-reply.v1",
    operation: "submit",
    blocked: false,
    message: "ready",
    execution: ready,
  }
  let model = {
    ..apply_native_route(route_model(), 7, route_fixture()),
    research_execution: Some(prepared),
  }
  let (_, first) = update(
    _ => @rabbita.none,
    CapabilitySubmitted(prepared, Ok(reply)),
    model,
  )
  guard first.pending_research is Some(request) else {
    fail("first submission missing")
  }
  let (_, sent) = update(
    _ => @rabbita.none,
    ResearchConfigured(request, Ok(route_session(Some("moongate/chosen")))),
    first,
  )
  assert_true(sent.research_message_sent)
  let (_, duplicate) = update(
    _ => @rabbita.none,
    CapabilitySubmitted(prepared, Ok(reply)),
    sent,
  )
  assert_eq(duplicate.submission_generation, sent.submission_generation)
  assert_eq(duplicate.pending_research, sent.pending_research)
  assert_true(duplicate.research_message_sent)
}

///|
test "refresh during configuration does not strand edit and retry or cancel already sent work" {
  let ready = {
    ..apply_native_route(route_model(), 7, route_fixture()),
    research_execution: Some(route_execution()),
  }
  let request = submission_context(ready, 1)
  let configuring = {
    ..ready,
    phase: CreatingSession,
    pending_research: Some(request),
    research_session: Some(route_session(None)),
  }
  let snapshot = {
    ..route_snapshot("run-1"),
    research_execution: Some(route_execution()),
  }
  let (_, refreshed) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(1, Ok(snapshot)),
    configuring,
  )
  let (_, edited) = update(
    _ => @rabbita.none,
    SetModelName("codex/manual"),
    refreshed,
  )
  assert_true(
    edited.pending_research is None && edited.research_session is None,
  )
  let (_, retried) = update(_ => @rabbita.none, StartResearch, edited)
  assert_eq(
    retried.pending_research.map(value => value.selector),
    Some("codex/manual"),
  )
  let (_, edited_sent) = update(
    _ => @rabbita.none,
    SetModelName("codex/manual"),
    { ..configuring, phase: Ready, research_message_sent: true, },
  )
  assert_eq(edited_sent.pending_research, Some(request))
}
