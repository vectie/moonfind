///|
fn evidence_workspace(topic : String) -> DurableResearchWorkspace {
  @json.from_json({
    "product_id": "moonfind",
    "title": "Research",
    "run_id": "run-" + topic,
    "status": "human-review",
    "watch_title": topic + " research",
    "query": topic + " open questions",
    "paper_count": 1,
    "summary_count": 1,
    "idea_count": 1,
    "question_count": 1,
    "accepted_idea_count": 0,
    "active_stage": "Named human review",
    "validation_issues": [],
    "bookkeeper_route": "moonbook.bookkeeper",
    "three_gap_state": "pending",
    "papers": [
      {
        "paper_id": topic + ":paper",
        "versioned_id": topic + ":paper-v2",
        "title": topic + " source <evidence>",
        "abstract_text": "Measured evidence for " + topic,
        "abs_url": "https://example.org/" + topic,
        "pdf_url": "https://example.org/" + topic + ".pdf",
        "source_digest": "sha256:" + topic,
      },
    ],
    "summaries": [
      {
        "paper_id": topic + ":paper",
        "one_sentence": topic + " finding",
        "problem": "Problem " + topic,
        "method": "Controlled experiment",
        "evidence": "Measured result",
        "limitations": ["Small sample"],
        "claims": [
          {
            "claim_id": topic + ":claim",
            "statement": "Evidence claim",
            "paper_ids": [topic + ":paper"],
            "evidence_location": "Table 2",
            "confidence": "limited",
            "counterevidence": "Replication missing",
          },
        ],
        "open_questions": ["Can it replicate?"],
      },
    ],
    "ideas": [
      {
        "idea_id": topic + ":exact-idea-7",
        "title": topic + " candidate",
        "thesis": "Candidate hypothesis",
        "mechanism": "Testable mechanism",
        "source_paper_ids": [topic + ":paper"],
        "cross_paper_bridge": "Candidate bridge",
        "novelty_claim": "Unverified novelty",
        "counter_hypothesis": "Alternative cause",
        "risks": ["Transfer risk"],
        "falsifier": "Failed replication",
        "next_experiment": "Replicate",
      },
    ],
    "questions": [
      {
        "question_id": topic + ":question",
        "question": topic + " next question?",
        "source_paper_ids": [topic + ":paper"],
        "missing_evidence": ["Independent test"],
        "next_check": "Compare outcomes",
      },
    ],
  }) catch {
    error => abort("invalid fixture: \{error}")
  }
}

///|
fn qa_ready_model() -> Model {
  {
    ..apply_native_route(route_model(), 7, route_fixture()),
    qa_ready: true,
    qa_session: Some(route_session(Some("moongate/chosen"))),
    qa_question: "What supports the current hypothesis?",
  }
}

///|
fn qa_test_render(model : Model) -> String {
  @rabbita.render_to_string(@rabbita.cell(model~, update~, view~))
}

///|
test "two topics produce exact topic titles and inline grounding in the actual Q&A HTTP sequence" {
  for topic in ["humanoid", "lunar-habitat"] {
    install_route_http_fixture(false)
    let scheduler = RouteTestScheduler::{
      hooks: { url_request: None, url_changed: None, },
    }
    let workspace = evidence_workspace(topic)
    let cell = Ref({
      ..apply_native_route(route_model(), 7, route_fixture()),
      workspace: Some(workspace),
      native_route: Some({ ..route_fixture(), run_id: workspace.run_id, }),
      qa_question: "Compare " + topic,
    })
    fn dispatch(message : Msg) -> @rabbita.Cmd {
      let (command, next) = update(dispatch, message, cell.val)
      cell.val = next
      @cmd.Scheduler::add(scheduler, command)
      @rabbita.none
    }
    ignore(dispatch(PrepareQa))
    ignore(dispatch(AskQa))
    guard @json.parse(route_http_requests()) is Array(requests) else {
      fail("requests missing")
    }
    assert_eq(requests.length(), 4)
    for index in [0, 1] {
      guard requests[index]
        is { "body": { "title": String(title), "cwd": String(cwd), .. }, .. } else {
        fail("session identity missing")
      }
      assert_eq(title, "MoonFind Q&A: " + topic + " research")
      assert_eq(cwd, "/trusted/book")
    }
    for index in [2, 3] {
      guard requests[index]
        is {
          "body": { "content": String(content), "cwd": String(cwd), .. },
          ..
        } else {
        fail("grounding missing")
      }
      assert_true(content.contains("run-" + topic))
      assert_true(content.contains("https://example.org/" + topic))
      assert_true(content.contains(topic + ":exact-idea-7"))
      assert_false(content.contains("DeepSeek"))
      assert_false(content.contains("wiki/"))
      assert_eq(cwd, "/trusted/book")
    }
    assert_true(cell.val.pending_question is None)
    restore_route_http_fixture()
  }
}

///|
test "current projection decodes and renders cited evidence and exact candidate IDs for two topics" {
  for topic in ["humanoid", "lunar-habitat"] {
    let workspace = evidence_workspace(topic)
    let model = { ..qa_ready_model(), workspace: Some(workspace), }
    let rendered = qa_test_render(model)
    for
      expected in [
        topic + ":paper-v2",
        topic + ":claim",
        topic + ":exact-idea-7",
        topic + ":question",
        "Table 2",
        "Small sample",
        "Replication missing",
        "https://example.org/" + topic,
      ] {
      assert_true(rendered.contains(expected), msg=expected)
    }
    assert_true(rendered.contains("&lt;evidence&gt;"))
    assert_true(
      rendered.contains("not the separately verified MoonTown synthesis"),
    )
    assert_true(rendered.contains("Ask about " + topic + " research"))
    assert_false(rendered.contains("DeepSeek"))
    let prompt = qa_grounding_prompt(
      qa_projection_context(model),
      "Compare evidence",
    )
    assert_true(prompt.contains("run-" + topic))
    assert_true(prompt.contains(topic + " open questions"))
    assert_true(prompt.contains(topic + ":exact-idea-7"))
    assert_false(prompt.contains("wiki/"))
    assert_false(prompt.contains("state/review-status.json"))
    assert_true(
      prompt.contains("MoonBook Bookkeeper remains the acceptance authority"),
    )
  }
}

///|
test "absent evidence remains explicit and unsafe citation URLs are never links" {
  let model = route_model()
  let rendered = qa_test_render(model)
  assert_true(rendered.contains("No source records were supplied"))
  assert_true(rendered.contains("No evidence summaries were supplied"))
  assert_true(rendered.contains("No candidate ideas were supplied"))
  assert_true(rendered.contains("No research questions were supplied"))
  let prompt = qa_grounding_prompt(qa_projection_context(model), "Answer")
  assert_true(prompt.contains("counts alone are not evidence"))
  assert_true(prompt.contains("Do not fetch new sources"))
  assert_false(safe_evidence_url("javascript:alert(1)"))
  assert_false(safe_evidence_url("file:///secret"))
  assert_false(safe_evidence_url("https://user:secret@example.org/"))
  assert_false(safe_evidence_url("/guessed/source"))
  assert_true(safe_evidence_url("https://example.org/paper"))
  assert_eq(initial_model().qa_question, "")
  assert_eq(initial_model().review_message, "")
  assert_eq(initial_model().book_dir, "")
}

///|
extern "js" fn install_question_http_fixture() -> Unit =
  #| () => {
  #|   globalThis.__qaOldFetch = globalThis.fetch;
  #|   globalThis.__qaRequests = [];
  #|   globalThis.fetch = (url, options) => {
  #|     const request = {url, method:options.method, body:options.body ? JSON.parse(options.body) : null};
  #|     globalThis.__qaRequests.push(request);
  #|     return {then(fn) { request.ok = fn; return {catch(fn) {request.error = fn;}}; }};
  #|   };
  #| }

///|
extern "js" fn question_http_requests() -> String =
  #| () => JSON.stringify(globalThis.__qaRequests.map(({url,method,body}) => ({url,method,body})))

///|
extern "js" fn complete_question_http(
  index : Int,
  response : String,
  error : Bool,
) -> Unit =
  #| (index, response, error) => {
  #|   const request = globalThis.__qaRequests[index];
  #|   if (error) request.error(new Error(response));
  #|   else request.ok({text:() => ({then(fn) {fn(response);}})});
  #| }

///|
extern "js" fn restore_question_http_fixture() -> Unit =
  #| () => {globalThis.fetch = globalThis.__qaOldFetch; delete globalThis.__qaRequests;}

///|
fn qa_http_reply(text : String) -> String {
  let reply : Json = {
    "session": {
      "session": {
        "session_key": "cowork:fixture",
        "session_id": "fixture",
        "title": "Fixture",
        "updated_at": 1,
        "state": "ready",
        "cwd": "/trusted/book",
        "model_override": "moongate/chosen",
        "has_plan_mode": false,
      },
      "messages": [
        {
          "id": "answer",
          "role": "assistant",
          "kind": "assistant",
          "content": text,
          "timestamp": 1,
          "metadata": Json::empty_object(),
        },
      ],
    },
  }
  reply.stringify()
}

///|
test "duplicate Ask sends one HTTP effect and old completion or error cannot replace explicit retry" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let scheduler = RouteTestScheduler::{
    hooks: { url_request: None, url_changed: None, },
  }
  let cell = Ref(qa_ready_model())
  fn dispatch(message : Msg) -> @rabbita.Cmd {
    let (command, next) = update(dispatch, message, cell.val)
    cell.val = next
    @cmd.Scheduler::add(scheduler, command)
    @rabbita.none
  }
  ignore(dispatch(AskQa))
  let generation = cell.val.question_generation
  ignore(dispatch(AskQa))
  assert_eq(cell.val.question_generation, generation)
  guard @json.parse(question_http_requests()) is Array(first_requests) else {
    fail("requests missing")
  }
  assert_eq(first_requests.length(), 1)
  assert_true(qa_test_render(cell.val).contains("Answering…"))
  complete_question_http(0, "offline", true)
  assert_true(cell.val.pending_question is None)
  assert_true(cell.val.qa_error is Some(_))
  assert_eq(cell.val.qa_question, "What supports the current hypothesis?")
  assert_true(qa_test_render(cell.val).contains("Retry question"))
  ignore(dispatch(AskQa))
  assert_eq(cell.val.question_generation, generation + 1)
  let pending = cell.val.pending_question
  complete_question_http(0, qa_http_reply("STALE ANSWER"), false)
  complete_question_http(0, "STALE ERROR", true)
  assert_eq(cell.val.pending_question, pending)
  assert_true(cell.val.qa_error is None)
  assert_false(qa_test_render(cell.val).contains("STALE ANSWER"))
  complete_question_http(1, qa_http_reply("CURRENT ANSWER"), false)
  assert_true(cell.val.pending_question is None)
  assert_true(qa_test_render(cell.val).contains("CURRENT ANSWER"))
  complete_question_http(0, qa_http_reply("STALE ANSWER"), false)
  assert_true(qa_test_render(cell.val).contains("CURRENT ANSWER"))
  assert_eq(cell.val.review_scope, "")
  assert_eq(cell.val.review_outcome, "")
  assert_eq(cell.val.review_phase, ReviewIdle)
  assert_true(cell.val.review_prepare_reply is None)
}

///|
test "response stays attached to submitted question while edits are preserved and old evidence response is hidden" {
  let (_, pending) = update(_ => @rabbita.none, AskQa, qa_ready_model())
  guard pending.pending_question is Some(request) else {
    fail("missing question")
  }
  let (_, edited) = update(
    _ => @rabbita.none,
    SetQaQuestion("Next draft"),
    pending,
  )
  let response = route_session(Some("moongate/chosen"))
  let response = {
    ..response,
    messages: [
      {
        id: "a",
        role: "assistant",
        kind: "assistant",
        content: "OLD EVIDENCE ANSWER",
        timestamp: 1,
        metadata: Json::empty_object(),
      },
    ],
  }
  let (_, answered) = update(
    _ => @rabbita.none,
    QaAnswered(request, Ok(response)),
    edited,
  )
  assert_eq(answered.qa_question, "Next draft")
  assert_eq(answered.qa_answered_question, Some(request.question))
  assert_true(qa_test_render(answered).contains("OLD EVIDENCE ANSWER"))
  let snapshot = route_snapshot("run-1")
  let (_, changed) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(
      1,
      Ok({
        ..snapshot,
        workspace: { ..snapshot.workspace, query: "Updated evidence", },
      }),
    ),
    answered,
  )
  assert_false(qa_test_render(changed).contains("OLD EVIDENCE ANSWER"))
  assert_eq(changed.qa_question, "Next draft")
  assert_true(changed.qa_response_context is None)
}

///|
test "mismatched response identity is rejected without replacing session or losing draft" {
  let (_, pending) = update(_ => @rabbita.none, AskQa, qa_ready_model())
  guard pending.pending_question is Some(request) else {
    fail("missing question")
  }
  let response = route_session(Some("moongate/chosen"))
  let response = {
    ..response,
    session: { ..response.session, session_key: "cowork:wrong", },
  }
  let (_, rejected) = update(
    _ => @rabbita.none,
    QaAnswered(request, Ok(response)),
    pending,
  )
  assert_true(rejected.pending_question is None)
  assert_true(rejected.qa_error is Some(_))
  assert_eq(rejected.qa_question, pending.qa_question)
  assert_eq(
    rejected.qa_session.map(value => value.session.session_key),
    Some("cowork:fixture"),
  )
  assert_true(rejected.qa_response_context is None)
}

///|
test "unchanged empty or blank assistant tails cannot relabel a previous answer as the new question" {
  let session = route_session(Some("moongate/chosen"))
  let old_message : CoworkMessage = {
    id: "prior-answer",
    role: "assistant",
    kind: "assistant",
    content: "PREVIOUS ANSWER",
    timestamp: 1,
    metadata: Json::empty_object(),
  }
  let session = { ..session, messages: [old_message], }
  let model = {
    ..qa_ready_model(),
    qa_session: Some(session),
    qa_question: "A different question",
  }
  let (_, pending) = update(_ => @rabbita.none, AskQa, model)
  guard pending.pending_question is Some(request) else {
    fail("missing request")
  }
  assert_eq(request.previous_message_ids, ["prior-answer"])
  for
    messages in [
      [old_message],
      [],
      [old_message, { ..old_message, id: "blank-new", content: "  ", }],
      [{ ..old_message, content: "Changed content on previous ID", }],
      [
        old_message,
        { ..old_message, id: "user-new", role: "user", kind: "user", },
      ],
    ] {
    let (_, returned) = update(
      _ => @rabbita.none,
      QaAnswered(request, Ok({ ..session, messages, })),
      pending,
    )
    assert_true(returned.pending_question is None)
    assert_true(
      returned.qa_error is Some(error) && error.contains("No new answer"),
    )
    assert_eq(returned.qa_question, "A different question")
    assert_true(
      returned.qa_answered_question is None && returned.qa_answer_text is None,
    )
    assert_false(qa_test_render(returned).contains("PREVIOUS ANSWER"))
    assert_true(qa_test_render(returned).contains("Retry question"))
  }
  let (_, answered) = update(
    _ => @rabbita.none,
    QaAnswered(
      request,
      Ok({
        ..session,
        messages: [
          old_message,
          { ..old_message, id: "new-answer", content: "NEW ANSWER", },
        ],
      }),
    ),
    pending,
  )
  assert_eq(answered.qa_answer_text, Some("NEW ANSWER"))
  assert_eq(answered.qa_answered_question, Some("A different question"))
  assert_true(answered.qa_error is None)
}

///|
test "run session gateway Book and evidence changes fence old question responses" {
  let (_, pending) = update(_ => @rabbita.none, AskQa, qa_ready_model())
  guard pending.pending_question is Some(request) else {
    fail("missing request")
  }
  let (_, new_run) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(1, Ok(route_snapshot("new-run"))),
    pending,
  )
  assert_true(new_run.pending_question is None)
  assert_false(new_run.qa_ready)
  let other_session = route_session(Some("moongate/chosen"))
  let other_session = {
    ..other_session,
    session: { ..other_session.session, session_key: "cowork:new", },
  }
  let changed_session = { ..pending, qa_session: Some(other_session), }
  let (_, new_gateway) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(
      1,
      Ok({
        ..route_snapshot("run-1"),
        moonclaw_gateway_base: Some("/api/v1/cowork-gateway-new"),
      }),
    ),
    pending,
  )
  assert_false(new_gateway.qa_ready)
  assert_true(
    new_gateway.qa_session is None && new_gateway.pending_question is None,
  )
  let (_, new_book) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(
      1,
      Ok({ ..route_snapshot("run-1"), book_workspace: "/new/book", }),
    ),
    pending,
  )
  assert_false(new_book.qa_ready)
  assert_true(new_book.qa_session is None)
  let snapshot = route_snapshot("run-1")
  let (_, new_evidence) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(
      1,
      Ok({
        ..snapshot,
        workspace: { ..snapshot.workspace, query: "new evidence query", },
      }),
    ),
    pending,
  )
  assert_true(new_evidence.pending_question is None)
  assert_true(new_evidence.qa_error is Some(_))
  let (_, edited_book) = update(
    _ => @rabbita.none,
    SetBookDir("/edited/book"),
    pending,
  )
  assert_false(edited_book.qa_ready)
  assert_true(
    edited_book.qa_session is None && edited_book.pending_question is None,
  )
  for
    model in [
      new_run, changed_session, new_gateway, new_book, new_evidence, edited_book,
    ] {
    for
      message in [
        QaAnswered(request, Ok(route_session(Some("moongate/chosen")))),
        QaAnswered(request, Err("old failure")),
      ] {
      let (_, next) = update(_ => @rabbita.none, message, model)
      assert_eq(next.qa_error, model.qa_error)
      assert_eq(
        next.qa_session.map(value => value.session.session_key),
        model.qa_session.map(value => value.session.session_key),
      )
      assert_eq(next.qa_question, model.qa_question)
    }
  }
}

///|
test "Q&A uses trusted Book cwd and selected projection even when research allocates another root" {
  let model = qa_ready_model()
  let research = route_session(Some("moongate/chosen"))
  let model = {
    ..model,
    research_session: Some({
      ..research,
      linked_run: Some({
        id: "research-runtime",
        job_id: "job",
        status: "succeeded",
        summary: None,
        error: None,
        current_step_id: None,
        workspace_dir: Some("/research/runs/run-1"),
      }),
    }),
  }
  let (_, pending) = update(_ => @rabbita.none, AskQa, model)
  guard pending.pending_question is Some(request) else {
    fail("Q&A unexpectedly blocked")
  }
  assert_eq(request.cwd, "/trusted/book")
  assert_false(request.grounding_context.contains("/research/runs/"))
  let prepared = submission_context(model, 1)
  assert_eq(prepared.title, "Test")
  assert_eq(prepared.cwd, "/trusted/book")
  assert_true(prepared.grounding_context.contains("run-1"))
}
