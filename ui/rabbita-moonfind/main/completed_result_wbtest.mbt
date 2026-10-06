///|
fn synthesis_fixture(
  run_id : String,
  digest : String,
  count? : Int = 1,
) -> CompletedResult {
  {
    contract_id: "moonfind.moontown-result-view.v1",
    run_id,
    state: "available",
    detail: "Correlated result",
    source_ref: Some("runs/" + run_id + "/moontown-reducer-output.json"),
    source_digest: Some(digest),
    output: Some({
      contract_id: "civic.communication.output.v1",
      scenario_id: "moonfind-" + run_id,
      participant_book_ids: ["paper-a", "paper-b"],
      ideas: Array::makei(count, index => {
        id: "synthesis-" + index.to_string(),
        title: "Exact completed <idea> " + index.to_string(),
        summary: "Completed summary & evidence",
        participating_books: ["paper-a", "paper-b"],
        research_questions: ["Can it replicate?"],
        why_it_matters: "Cross-paper relevance",
        next_experiment: "Independent falsification experiment",
      }),
    }),
  }
}

///|
fn synthesis_snapshot(run_id : String, digest : String) -> WorkspaceSnapshot {
  let snapshot = route_snapshot(run_id)
  {
    ..snapshot,
    moonclaw_gateway_base: None,
    moontown_result: Some(synthesis_fixture(run_id, digest)),
    moontown_handoff: {
      ..snapshot.moontown_handoff,
      state: "ingested-pending-review",
    },
    review_workflow: {
      ..snapshot.review_workflow,
      state: "ready-for-human-review",
      prepare_url: Some("/api/v1/review/prepare"),
    },
  }
}

///|
fn synthesis_model() -> Model {
  let snapshot = synthesis_snapshot("run-1", "sha256:first")
  let (_, model) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(1, Ok(snapshot)),
    initial_model(),
  )
  model
}

///|
test "completed result renders exact synthesis content separately and selection never chooses outcome" {
  let model = {
    ..synthesis_model(),
    workspace: Some({ ..evidence_workspace("candidate"), run_id: "run-1", }),
  }
  let html = qa_test_render(model)
  assert_true(html.contains("Completed MoonTown synthesis"))
  assert_true(html.contains("Exact completed &lt;idea&gt; 0"))
  assert_false(html.contains("Exact completed <idea>"))
  for
    field in [
      "Completed summary &amp; evidence", "Can it replicate?", "Cross-paper relevance",
      "Independent falsification experiment", "paper-a, paper-b", "sha256:first",
      "Analysis candidate ideas",
    ] {
    assert_true(html.contains(field), msg=field)
  }
  let (_, selected) = update(
    _ => @rabbita.none,
    ToggleResultIdea(review_result_context(model), "synthesis-0"),
    model,
  )
  assert_eq(selected.review_scope, "synthesis-0")
  assert_eq(selected.review_outcome, "")
  assert_eq(selected.review_message, "")
  assert_eq(selected.review_phase, ReviewIdle)
  let (_, removed) = update(
    _ => @rabbita.none,
    ToggleResultIdea(review_result_context(selected), "synthesis-0"),
    selected,
  )
  assert_eq(removed.review_scope, "")
  assert_eq(
    toggle_result_idea(model, "stale context", "synthesis-0").review_scope,
    "",
  )
  assert_eq(
    toggle_result_idea(
      model,
      review_result_context(model),
      "candidate:exact-idea-7",
    ).review_scope,
    "",
  )
}

///|
test "all large-result ideas remain reachable in bounded pages with selection retained" {
  let model = {
    ..synthesis_model(),
    moontown_result: Some(synthesis_fixture("run-1", "sha256:large", count=23)),
  }
  let output = current_synthesis(model).unwrap()
  assert_eq(result_page_ideas(model, output).length(), 10)
  let selected = toggle_result_idea(
    model,
    review_result_context(model),
    "synthesis-0",
  )
  let (_, last) = update(_ => @rabbita.none, SetResultPage(2), selected)
  assert_eq(result_page_ideas(last, output).map(idea => idea.id), [
    "synthesis-20", "synthesis-21", "synthesis-22",
  ])
  assert_true(qa_test_render(last).contains("Page 3 of 3"))
  assert_false(qa_test_render(last).contains("Exact completed &lt;idea&gt; 0"))
  assert_eq(last.review_scope, "synthesis-0")
  assert_eq(
    result_page_ideas({ ..last, result_page: 999, }, output).length(),
    3,
  )
  assert_eq(
    result_page_ideas({ ..last, result_page: -1, }, output).length(),
    10,
  )
}

///|
test "missing empty and cross-run results do not allow selection or preparation" {
  let model = synthesis_model()
  for
    result in [
      None,
      Some(synthesis_fixture("other-run", "sha256:x")),
      Some(synthesis_fixture("run-1", "sha256:x", count=0)),
      Some({ ..synthesis_fixture("run-1", "sha256:x"), state: "unavailable", }),
    ] {
    let invalid = { ..model, moontown_result: result, }
    assert_true(current_synthesis(invalid) is None)
    assert_false(result_review_issues(invalid).is_empty())
    assert_eq(
      toggle_result_idea(invalid, review_result_context(invalid), "synthesis-0").review_scope,
      "",
    )
    assert_true(
      qa_test_render(invalid).contains("Completed result unavailable"),
    )
    assert_false(
      qa_test_render(invalid).contains("Prepare MoonChat review bundle"),
    )
  }
  assert_false(
    result_review_issues({ ..model, review_scope: "C01", }).is_empty(),
  )
  assert_true(
    result_review_issues({ ..model, review_scope: "synthesis-0", }).is_empty(),
  )
}

///|
test "workspace refresh keeps same result draft and switches restore exact run book and digest drafts" {
  let first = {
    ..synthesis_model(),
    review_scope: "synthesis-0",
    review_outcome: "approve_subset",
    review_message: "First result rationale",
    recognition_gap_summary: "Specific first gap",
    result_page: 2,
  }
  let (_, same) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(1, Ok(synthesis_snapshot("run-1", "sha256:first"))),
    first,
  )
  assert_eq(same.review_message, first.review_message)
  assert_eq(same.review_scope, "synthesis-0")
  let (_, changed) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(1, Ok(synthesis_snapshot("run-1", "sha256:second"))),
    same,
  )
  assert_eq(changed.review_scope, "")
  assert_eq(changed.review_message, "")
  assert_eq(changed.review_outcome, "")
  assert_eq(changed.result_page, 0)
  assert_true(changed.review_prepare_reply is None)
  let (_, restored) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(1, Ok(synthesis_snapshot("run-1", "sha256:first"))),
    changed,
  )
  assert_eq(restored.review_scope, "synthesis-0")
  assert_eq(restored.review_message, "First result rationale")
  assert_eq(restored.recognition_gap_summary, "Specific first gap")
  let (_, other) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(1, Ok(synthesis_snapshot("run-2", "sha256:first"))),
    restored,
  )
  assert_eq(other.review_scope, "")
  let (_, other_book) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(
      1,
      Ok({
        ..synthesis_snapshot("run-1", "sha256:first"),
        book_workspace: "/other/book",
      }),
    ),
    other,
  )
  assert_eq(other_book.review_message, "")
}

///|
test "fresh return shows current completed result but never manufactures a saved decision" {
  let model = synthesis_model()
  assert_true(current_synthesis(model) is Some(_))
  assert_eq(model.review_scope, "")
  assert_eq(model.review_outcome, "")
  assert_true(model.review_prepare_reply is None)
  assert_true(model.review_pending_context is None)
}

///|
test "current preparation receipt binds the displayed digest and stays pending downstream review" {
  let model = synthesis_model()
  let context = review_result_context(model)
  let pending = {
    ..model,
    review_phase: ReviewPreparing,
    review_pending_context: Some(context),
  }
  let reply : ReviewPrepareReply = {
    contract_id: "moonfind.review-prepare-reply.v1",
    state: "awaiting-moonchat",
    run_id: "run-1",
    review_id: "review-1",
    source_ref: "runs/run-1/moontown-reducer-output.json",
    source_digest: "sha256:first",
    bundle_ref: "exact-bundle",
    operation_ref: "moonchat/conversation.review.record@0.1.0",
    message: "Prepared",
  }
  let (_, wrong) = update(
    _ => @rabbita.none,
    ReviewPrepared(
      pending.review_request_generation,
      context,
      Ok({ ..reply, source_digest: "sha256:changed", }),
    ),
    pending,
  )
  assert_true(wrong.review_prepare_reply is None)
  assert_true(wrong.review_pending_context is None)
  assert_eq(wrong.review_phase, ReviewFailed)
  let (_, success) = update(
    _ => @rabbita.none,
    ReviewPrepared(pending.review_request_generation, context, Ok(reply)),
    pending,
  )
  assert_eq(success.review_phase, ReviewBundleReady)
  assert_true(success.review_pending_context is None)
  assert_eq(
    success.review_prepare_reply.map(value => value.bundle_ref),
    Some("exact-bundle"),
  )
  let snapshot = synthesis_snapshot("run-1", "sha256:first")
  let (_, returned) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(
      success.workspace_generation,
      Ok({
        ..snapshot,
        review_workflow: {
          ..snapshot.review_workflow,
          state: "awaiting-moonchat",
          prepare_url: None,
          bundle_ref: Some("exact-bundle"),
        },
      }),
    ),
    success,
  )
  assert_true(current_synthesis(returned) is Some(_))
  assert_eq(returned.review_phase, ReviewBundleReady)
  assert_eq(
    toggle_result_idea(returned, review_result_context(returned), "synthesis-0").review_scope,
    "",
  )
}

///|
test "actual review HTTP sends exact selected ID and digest once and ignores stale result replies" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let model = {
    ..synthesis_model(),
    reviewer_name: "Fixture reviewer",
    review_outcome: "approve_subset",
    review_scope: "synthesis-0",
    review_message: "Evidence checked",
  }
  let (cell, dispatch) = retained_harness(model)
  ignore(dispatch(PrepareReview))
  ignore(dispatch(PrepareReview))
  assert_eq(cell.val.review_phase, ReviewPreparing)
  let requests = retained_requests()
  assert_eq(requests.length(), 1)
  assert_true(
    requests[0]
    is {
      "method": "POST",
      "url": "/api/v1/review/prepare",
      "body": {
        "source_digest": "sha256:first",
        "accepted_idea_ids": ["synthesis-0"],
        "rejected_idea_ids": [],
        ..
      },
      ..
    },
  )
  let context = review_result_context(model)
  let (_, changed) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(1, Ok(synthesis_snapshot("run-2", "sha256:second"))),
    cell.val,
  )
  let (_, after_error) = update(
    _ => @rabbita.none,
    ReviewPrepared(
      model.review_request_generation + 1,
      context,
      Err("stale failure"),
    ),
    changed,
  )
  assert_true(after_error.review_prepare_reply is None)
  assert_false(after_error.error == Some("stale failure"))
  cell.val = changed
  let reply : Json = {
    "contract_id": "moonfind.review-prepare-reply.v1",
    "state": "awaiting-moonchat",
    "run_id": "run-1",
    "review_id": "review-1",
    "source_ref": "old",
    "source_digest": "sha256:first",
    "bundle_ref": "old-bundle",
    "operation_ref": "moonchat/conversation.review.record@0.1.0",
    "message": "prepared",
  }
  complete_question_http(0, reply.stringify(), false)
  assert_true(cell.val.review_prepare_reply is None)
  assert_eq(cell.val.workspace.map(value => value.run_id), Some("run-2"))
  assert_eq(retained_requests().length(), 1)
}

///|
test "result refresh is read-only and keeps typed reviewer work until result context changes" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let (cell, dispatch) = retained_harness({
    ..synthesis_model(),
    review_message: "Typed draft",
  })
  ignore(dispatch(RefreshMoonTownStatus))
  assert_eq(retained_requests().length(), 1)
  assert_true(
    retained_requests()[0]
    is { "method": "GET", "url": "/api/v1/workspace", .. },
  )
  assert_eq(cell.val.review_message, "Typed draft")
  assert_eq(cell.val.review_outcome, "")
  assert_eq(cell.val.review_scope, "")
}

///|
fn check_result_prepare_aba(
  old_error : Bool,
  newest_error : Bool,
) -> Unit raise {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let first = {
    ..synthesis_model(),
    reviewer_name: "Fixture reviewer",
    review_outcome: "approve_subset",
    review_scope: "synthesis-0",
    review_message: "First rationale",
  }
  let (cell, dispatch) = retained_harness(first)
  ignore(dispatch(PrepareReview))
  let old_generation = cell.val.review_request_generation
  assert_eq(old_generation, 1)
  ignore(
    dispatch(
      WorkspaceLoaded(1, Ok(synthesis_snapshot("run-2", "sha256:second"))),
    ),
  )
  ignore(
    dispatch(
      WorkspaceLoaded(1, Ok(synthesis_snapshot("run-1", "sha256:first"))),
    ),
  )
  ignore(dispatch(SetReviewMessage("Revised rationale for the newer request")))
  ignore(dispatch(SetInformationGapSummary("Newer evidence detail")))
  ignore(dispatch(PrepareReview))
  ignore(dispatch(PrepareReview))
  let newest_index = retained_requests().length() - 1
  assert_eq(
    retained_requests()
    .filter(request => {
      request is { "method": "POST", "url": "/api/v1/review/prepare", .. }
    })
    .length(),
    2,
  )
  assert_eq(cell.val.review_request_generation, old_generation + 1)
  assert_eq(cell.val.review_phase, ReviewPreparing)
  let context = cell.val.review_pending_context
  let requests_before_old = retained_requests().length()
  let success_reply : Json = {
    "contract_id": "moonfind.review-prepare-reply.v1",
    "state": "awaiting-moonchat",
    "run_id": "run-1",
    "review_id": "review-1",
    "source_ref": "runs/run-1/moontown-reducer-output.json",
    "source_digest": "sha256:first",
    "bundle_ref": "exact-bundle",
    "operation_ref": "moonchat/conversation.review.record@0.1.0",
    "message": "Prepared",
  }
  complete_question_http(
    0,
    if old_error {
      "Old request failed"
    } else {
      success_reply.stringify()
    },
    old_error,
  )
  assert_eq(cell.val.review_phase, ReviewPreparing)
  assert_eq(cell.val.review_pending_context, context)
  assert_true(cell.val.review_prepare_reply is None)
  assert_eq(cell.val.review_message, "Revised rationale for the newer request")
  assert_eq(cell.val.information_gap_summary, "Newer evidence detail")
  assert_eq(retained_requests().length(), requests_before_old)
  complete_question_http(
    newest_index,
    if newest_error {
      "Newest request failed"
    } else {
      success_reply.stringify()
    },
    newest_error,
  )
  assert_eq(
    cell.val.review_phase,
    if newest_error {
      ReviewFailed
    } else {
      ReviewBundleReady
    },
  )
  assert_true(cell.val.review_pending_context is None)
  assert_eq(cell.val.review_prepare_reply is Some(_), !newest_error)
  assert_eq(cell.val.review_message, "Revised rationale for the newer request")
  // A duplicate old delivery after the newest request settled cannot change
  // that outcome or revive a pending request either.
  let settled_phase = cell.val.review_phase
  let settled_error = cell.val.error
  let settled_requests = retained_requests().length()
  complete_question_http(
    0,
    if old_error {
      "Old duplicate failure"
    } else {
      success_reply.stringify()
    },
    old_error,
  )
  assert_eq(cell.val.review_phase, settled_phase)
  assert_eq(cell.val.error, settled_error)
  assert_eq(retained_requests().length(), settled_requests)
}

///|
test "preparation ABA ignores old error before newer success without losing revised draft" {
  check_result_prepare_aba(true, false)
}

///|
test "preparation ABA ignores old success before newer error without losing revised draft" {
  check_result_prepare_aba(false, true)
}
