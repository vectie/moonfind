///|
test "catalog picker uses serialized host default and permits explicit nondefault without execution" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let (cell, dispatch) = retained_harness({
    ..route_model(),
    qa_question: "Keep question",
    review_message: "Keep brief",
  })
  ignore(dispatch(RefreshModelRoutes))
  ignore(dispatch(RefreshModelRoutes))
  assert_eq(retained_requests().length(), 1)
  assert_true(
    retained_requests()[0]
    is {
      "method": String("GET"),
      "url": String("/api/v1/model-route"),
      "body": Null,
      ..
    },
  )
  assert_true(cell.val.route_loading)
  assert_true(current_model_catalog(cell.val) is None)
  let generation = cell.val.route_generation
  complete_question_http(0, chooser_host_reply(0), false)
  assert_eq(cell.val.model_name, "moongate/chosen")
  assert_false(cell.val.route_loading)
  let html = qa_test_render(cell.val)
  assert_true(html.contains("Research model"))
  assert_true(html.contains("chosen · configured default"))
  assert_true(html.contains("other</option>"))
  assert_true(html.contains("Use configured default"))
  assert_true(html.contains("Advanced: enter an exact model route"))
  assert_true(html.contains("Provider execution has not been tested"))
  ignore(dispatch(SelectCatalogModel(generation, "moongate/other")))
  ignore(dispatch(SelectCatalogModel(generation, "moongate/other")))
  assert_eq(cell.val.model_name, "moongate/other")
  assert_eq(cell.val.model_source, "user")
  assert_eq(cell.val.qa_question, "Keep question")
  assert_eq(cell.val.review_message, "Keep brief")
  assert_eq(retained_requests().length(), 1)
  assert_true(
    cell.val.research_session is None && cell.val.pending_research is None,
  )
  ignore(dispatch(UseConfiguredDefault(generation)))
  ignore(dispatch(UseConfiguredDefault(generation)))
  assert_eq(cell.val.model_name, "moongate/chosen")
  assert_eq(retained_requests().length(), 1)
}

///|
test "no-default catalog offers alternatives while unavailable gateway and offline stay blocked" {
  let fixtures = chooser_host_fixtures()
  let (_, choices) = update(
    _ => @rabbita.none,
    NativeRouteLoaded(7, Ok(fixtures[1])),
    route_model(),
  )
  assert_eq(choices.model_name, "")
  assert_eq(current_model_catalog(choices).map(catalog_choices).unwrap_or([]), [
    "moongate/other", "moongate/chosen",
  ])
  assert_true(model_picker_status(choices).contains("no verified default"))
  let (_, unchanged) = update(
    _ => @rabbita.none,
    UseConfiguredDefault(7),
    choices,
  )
  assert_eq(unchanged.model_name, "")
  let (_, selected) = update(
    _ => @rabbita.none,
    SelectCatalogModel(7, "moongate/other"),
    choices,
  )
  assert_eq(model_route_issue(selected, selected.book_dir), None)
  for index in [2, 3] {
    let (_, unavailable) = update(
      _ => @rabbita.none,
      NativeRouteLoaded(7, Ok(fixtures[index])),
      selected,
    )
    assert_eq(unavailable.model_name, "moongate/other")
    assert_true(current_model_catalog(unavailable) is None)
    assert_true(model_route_issue(unavailable, unavailable.book_dir) is Some(_))
    let (_, attempted) = update(
      _ => @rabbita.none,
      SelectCatalogModel(7, "moongate/chosen"),
      unavailable,
    )
    assert_eq(attempted.model_name, "moongate/other")
    assert_true(
      model_picker_status(unavailable).contains(
        if index == 2 {
          "unavailable"
        } else {
          "not configured"
        },
      ),
    )
  }
  let missing = { ..selected, gateway_published: false, }
  assert_true(current_model_catalog(missing) is None)
  assert_true(
    model_picker_status(missing).contains("No reachable MoonClaw gateway"),
  )
}

///|
test "actual HTTP discovery rejects stale completion and permits retry without touching drafts or run" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let (cell, dispatch) = retained_harness({
    ..apply_native_route(route_model(), 7, route_fixture()),
    model_name: "moongate/other",
    model_source: "saved",
    qa_question: "draft question",
    review_message: "draft review",
    research_execution: Some(route_execution()),
  })
  ignore(dispatch(RefreshModelRoutes))
  let old_generation = cell.val.route_generation
  complete_question_http(0, "offline", true)
  assert_false(cell.val.route_loading)
  assert_true(
    model_picker_status(cell.val).contains("Refresh") ||
    model_picker_status(cell.val).contains("refresh"),
  )
  assert_eq(cell.val.model_name, "moongate/other")
  ignore(dispatch(RefreshModelRoutes))
  ignore(dispatch(RefreshModelRoutes))
  assert_eq(retained_requests().length(), 2)
  ignore(dispatch(NativeRouteLoaded(old_generation, Ok(route_fixture()))))
  ignore(dispatch(SelectCatalogModel(old_generation, "moongate/chosen")))
  ignore(dispatch(UseConfiguredDefault(old_generation)))
  assert_true(cell.val.route_loading)
  assert_eq(cell.val.model_name, "moongate/other")
  complete_question_http(1, chooser_host_reply(0), false)
  assert_false(cell.val.route_loading)
  assert_true(cell.val.route_error is None)
  assert_eq(cell.val.model_name, "moongate/other")
  assert_eq(cell.val.model_source, "saved")
  assert_eq(cell.val.qa_question, "draft question")
  assert_eq(cell.val.review_message, "draft review")
  assert_eq(
    cell.val.research_execution.map(execution => execution.request_id),
    Some("request-1"),
  )
  assert_eq(retained_requests().length(), 2)
}

///|
test "folder A B A and wrong-run catalog cannot authorize stale selector events" {
  let fixtures = chooser_host_fixtures()
  let ready = apply_native_route(route_model(), 7, fixtures[0])
  let (_, away) = update(_ => @rabbita.none, SetBookDir("/other"), ready)
  let (_, back) = update(_ => @rabbita.none, SetBookDir("/trusted/book"), away)
  assert_true(back.route_loading)
  assert_true(current_model_catalog(back) is None)
  let (_, stale) = update(
    _ => @rabbita.none,
    NativeRouteLoaded(7, Ok(fixtures[0])),
    back,
  )
  assert_true(stale.route_loading)
  let (_, wrong) = update(
    _ => @rabbita.none,
    NativeRouteLoaded(back.route_generation, Ok(fixtures[4])),
    stale,
  )
  assert_false(wrong.route_loading)
  assert_true(wrong.route_error is Some(_))
  assert_true(current_model_catalog(wrong) is None)
  let (_, retry) = update(_ => @rabbita.none, RefreshModelRoutes, wrong)
  let (_, recovered) = update(
    _ => @rabbita.none,
    NativeRouteLoaded(retry.route_generation, Ok(fixtures[0])),
    retry,
  )
  let (_, old_click) = update(
    _ => @rabbita.none,
    SelectCatalogModel(7, "moongate/other"),
    recovered,
  )
  assert_eq(old_click.model_name, "moongate/chosen")
  let (_, chosen) = update(
    _ => @rabbita.none,
    SelectCatalogModel(recovered.route_generation, "moongate/other"),
    old_click,
  )
  assert_eq(chosen.model_name, "moongate/other")
  let (_, forged) = update(
    _ => @rabbita.none,
    SelectCatalogModel(chosen.route_generation, "moongate/unlisted"),
    chosen,
  )
  assert_eq(forged.model_name, "moongate/other")
}

///|
test "manual and saved selection survive discovery and explicit default can replace failed restore" {
  let fixtures = chooser_host_fixtures()
  let (_, manual) = update(
    _ => @rabbita.none,
    SetModelName("moongate/manual"),
    route_model(),
  )
  let (_, discovered) = update(
    _ => @rabbita.none,
    NativeRouteLoaded(7, Ok(fixtures[0])),
    manual,
  )
  assert_eq(discovered.model_name, "moongate/manual")
  assert_true(model_route_issue(discovered, discovered.book_dir) is Some(_))
  let restored = restore_model_selection(
    route_model(),
    route_session(Some("moongate/other")),
  )
  let (_, discovered) = update(
    _ => @rabbita.none,
    NativeRouteLoaded(7, Ok(fixtures[0])),
    restored,
  )
  assert_eq(discovered.model_name, "moongate/other")
  let blocked = {
    ..discovered,
    model_source: "automatic",
    saved_selection_error: Some("restore failed"),
  }
  let (_, explicit) = update(
    _ => @rabbita.none,
    UseConfiguredDefault(7),
    blocked,
  )
  assert_eq(explicit.model_name, "moongate/chosen")
  assert_eq(explicit.saved_selection_error, None)
  assert_eq(model_route_issue(explicit, explicit.book_dir), None)
  let pending = {
    ..explicit,
    pending_research: Some(submission_context(explicit, 1)),
  }
  let (_, duplicate) = update(
    _ => @rabbita.none,
    UseConfiguredDefault(7),
    pending,
  )
  assert_eq(duplicate.pending_research, pending.pending_research)
}

///|
test "selecting another catalog model invalidates unsubmitted request and never sends old config completion" {
  let ready = apply_native_route(route_model(), 7, route_fixture())
  let request = submission_context(ready, 1)
  let pending = { ..ready, pending_research: Some(request), }
  let (_, selected) = update(
    _ => @rabbita.none,
    SelectCatalogModel(7, "moongate/other"),
    pending,
  )
  assert_true(selected.pending_research is None)
  let (_, late) = update(
    _ => @rabbita.none,
    ResearchConfigured(request, Ok(route_session(Some("moongate/chosen")))),
    selected,
  )
  assert_eq(late.model_name, "moongate/other")
  assert_true(late.research_session is None)
}

///|
fn chooser_host_reply(index : Int) -> String raise {
  guard @json.parse(chooser_host_serialized()) is Array(rows) else {
    fail("missing generated host fixtures")
  }
  rows[index].stringify()
}

///|
test "explicit research start sends the chooser's exact nondefault through unchanged Cowork flow" {
  install_route_http_fixture(false)
  defer restore_route_http_fixture()
  let (cell, dispatch) = retained_harness({
    ..apply_native_route(route_model(), 7, chooser_host_fixtures()[0]),
    research_execution: Some(route_execution()),
  })
  ignore(dispatch(SelectCatalogModel(7, "moongate/other")))
  assert_eq(route_http_requests(), "[]")
  ignore(dispatch(StartResearch))
  guard @json.parse(route_http_requests()) is Array(requests) else {
    fail("missing requests")
  }
  assert_eq(requests.length(), 3)
  assert_true(
    requests[1]
    is {
      "url": String(url),
      "body": {
        "model": String("moongate/other"),
        "cwd": String("/trusted/book"),
        ..
      },
      ..
    } &&
    url.has_suffix("/config"),
  )
  assert_true(
    requests[2]
    is {
      "body": {
        "model": String("moongate/other"),
        "source_request_id": String("request-1"),
        ..
      },
      ..
    },
  )
  assert_eq(cell.val.model_name, "moongate/other")
}

///|
test "configured route disappearing on refresh stays selected but blocked without automatic fallback" {
  let ready = select_catalog_model(
    apply_native_route(route_model(), 7, route_fixture()),
    7,
    "moongate/other",
  )
  let (_, refreshing) = update(_ => @rabbita.none, RefreshModelRoutes, ready)
  let changed = { ..route_fixture(), models: ["moongate/chosen"], }
  let (_, unavailable) = update(
    _ => @rabbita.none,
    NativeRouteLoaded(refreshing.route_generation, Ok(changed)),
    refreshing,
  )
  assert_eq(unavailable.model_name, "moongate/other")
  assert_true(model_route_issue(unavailable, unavailable.book_dir) is Some(_))
  assert_true(
    qa_test_render(unavailable).contains(
      "Current selection: moongate/other (not in this catalog)",
    ),
  )
  let (_, deliberate) = update(
    _ => @rabbita.none,
    UseConfiguredDefault(unavailable.route_generation),
    unavailable,
  )
  assert_eq(deliberate.model_name, "moongate/chosen")
  assert_eq(model_route_issue(deliberate, deliberate.book_dir), None)
}
