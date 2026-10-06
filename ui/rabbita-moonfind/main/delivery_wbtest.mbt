///|
fn delivery_fixture_id() -> String {
  "delivery-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
}

///|
fn delivery_fixture(state? : String = "complete") -> DeliveryStatus {
  {
    contract_id: "moonfind.delivery-status.v1",
    run_id: "run-1",
    state,
    detail: "Retained research · 月面 🛰️ <script> & exact bytes",
    manifest: if state == "not-prepared" {
      None
    } else {
      Some({
        contract_id: "moonfind.delivery-manifest.v1",
        run_id: "run-1",
        delivery_id: delivery_fixture_id(),
        run_digest: "sha256:run",
        source_digest: "sha256:first",
        files: [
          {
            name: "report.md",
            media_type: "text/markdown; charset=utf-8",
            byte_count: 4097,
            digest: "sha256:report",
          },
          {
            name: "evidence.json",
            media_type: "application/json",
            byte_count: 13809,
            digest: "sha256:evidence",
          },
          {
            name: "synthesis.json",
            media_type: "application/json",
            byte_count: 2842,
            digest: "sha256:synthesis",
          },
        ],
        boundary: "Projection only · no new synthesis · no acceptance · retained 月面 evidence",
      })
    },
    issues: if state == "incomplete" {
      ["synthesis.json digest mismatch"]
    } else {
      []
    },
    versions: if state == "not-prepared" {
      []
    } else {
      [delivery_fixture_id()]
    },
  }
}

///|
fn delivered_model(state? : String = "complete") -> Model {
  let model = synthesis_model()
  let request = model.delivery.pending.unwrap()
  let (_, delivered) = update(
    _ => @rabbita.none,
    DeliveryLoaded(request, Ok(delivery_fixture(state~))),
    model,
  )
  delivered
}

///|
test "delivery renders real preview download and ZIP routes with exact file metadata and escaped Unicode" {
  let model = delivered_model()
  let html = qa_test_render(model)
  let base = "/api/v1/delivery/" + delivery_fixture_id() + "/"
  for name in ["report.md", "evidence.json", "synthesis.json", "manifest.json"] {
    assert_true(html.contains("href=\"" + base + name + "\""), msg=name)
    assert_true(html.contains("download=\"" + name + "\""), msg=name)
    assert_true(html.contains("Preview " + name), msg=name)
    assert_true(html.contains("Download " + name), msg=name)
  }
  assert_true(html.contains("href=\"" + base + "package.zip\""))
  assert_true(html.contains("Download complete package · ZIP"))
  assert_true(html.contains("Markdown · 4097 bytes"))
  assert_true(html.contains("JSON · 13809 bytes"))
  assert_true(html.contains("JSON · 2842 bytes"))
  assert_true(html.contains("target=\"_blank\""))
  assert_true(html.contains("rel=\"noopener noreferrer\""))
  assert_true(html.contains("月面 🛰️ &lt;script&gt; &amp; exact bytes"))
  assert_false(html.contains("<script>"))
  assert_true(html.contains("Current package · complete"))
  assert_eq(model.review_outcome, "")
  assert_eq(model.review_scope, "")
}

///|
extern "js" fn delivery_test_location(path : String) -> Unit =
  #| path => {
  #|   globalThis.__deliveryOldLocation = globalThis.location;
  #|   globalThis.location = { pathname: path };
  #| }

///|
extern "js" fn delivery_restore_location() -> Unit =
  #| () => { globalThis.location = globalThis.__deliveryOldLocation; delete globalThis.__deliveryOldLocation; }

///|
test "delivery uses the pack prefix for exact immutable file and HTTP status routes" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  delivery_test_location("/pack-apps/moonfind/review")
  defer delivery_restore_location()
  assert_eq(
    delivery_file_url(delivery_fixture_id(), "report.md"),
    Some(
      "/pack-apps/moonfind/api/v1/delivery/" +
      delivery_fixture_id() +
      "/report.md",
    ),
  )
  assert_true(
    qa_test_render(delivered_model()).contains(
      "href=\"/pack-apps/moonfind/api/v1/delivery/",
    ),
  )
  let (_, dispatch) = retained_harness(delivered_model())
  ignore(dispatch(RefreshDelivery))
  assert_true(
    retained_requests()[0]
    is {
      "method": "GET",
      "url": "/pack-apps/moonfind/api/v1/delivery",
      "body": Null,
      ..
    },
  )
  for name in ["../secret", "report.html", "report.md?raw=1", "/report.md", ""] {
    assert_true(delivery_file_url(delivery_fixture_id(), name) is None)
  }
  for
    id in [
      "../run", "other/route", "https://evil.test", "delivery-abc", "delivery-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
    ] {
    assert_true(delivery_file_url(id, "report.md") is None)
  }
}

///|
test "workspace hydration automatically reads delivery without preparing or fetching file bytes" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let (cell, dispatch) = retained_harness(initial_model())
  ignore(
    dispatch(
      WorkspaceLoaded(1, Ok(synthesis_snapshot("run-1", "sha256:first"))),
    ),
  )
  let requests = retained_requests()
  assert_eq(requests.length(), 2)
  assert_true(
    requests[1]
    is { "method": "GET", "url": "/api/v1/delivery", "body": Null, .. },
  )
  assert_true(cell.val.delivery.pending is Some(_))
  assert_false(qa_test_render(cell.val).contains("Preview report.md"))
  complete_question_http(
    1,
    ToJson::to_json(delivery_fixture()).stringify(),
    false,
  )
  assert_true(cell.val.delivery.pending is None)
  assert_true(qa_test_render(cell.val).contains("Preview report.md"))
  assert_eq(retained_requests().length(), 2)
}

///|
test "preparation sends displayed run and synthesis digest once and repeated completed actions stay inert" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let (cell, dispatch) = retained_harness(delivered_model(state="not-prepared"))
  ignore(dispatch(PrepareDelivery))
  ignore(dispatch(PrepareDelivery))
  ignore(dispatch(RefreshDelivery))
  assert_eq(retained_requests().length(), 1)
  assert_true(
    retained_requests()[0]
    is {
      "method": "POST",
      "url": "/api/v1/delivery/prepare",
      "body": {
        "contract_id": "moonfind.delivery-prepare.v1",
        "run_id": "run-1",
        "source_digest": "sha256:first",
        ..
      },
      ..
    },
  )
  assert_true(qa_test_render(cell.val).contains("Preparing report files…"))
  assert_false(qa_test_render(cell.val).contains("Preview report.md"))
  complete_question_http(
    0,
    ToJson::to_json(delivery_fixture()).stringify(),
    false,
  )
  ignore(dispatch(PrepareDelivery))
  assert_eq(retained_requests().length(), 1)
  assert_true(qa_test_render(cell.val).contains("Current package · complete"))
  assert_eq(cell.val.review_phase, ReviewIdle)
  assert_eq(cell.val.review_outcome, "")
}

///|
test "delivery states remain readable and withhold file links until all bytes are validated" {
  for state in ["not-prepared", "incomplete", "unavailable"] {
    let model = delivered_model(state~)
    let html = qa_test_render(model)
    assert_false(html.contains("Preview report.md"), msg=state)
    assert_false(html.contains("Download complete package"), msg=state)
    assert_true(model.delivery.error is None)
    assert_eq(model.delivery.status.map(value => value.state), Some(state))
  }
  assert_true(
    qa_test_render(delivered_model(state="incomplete")).contains(
      "synthesis.json digest mismatch",
    ),
  )
  assert_true(
    qa_test_render(delivered_model(state="not-prepared")).contains(
      "Report files not prepared",
    ),
  )
}

///|
test "intact stale current pointer downloads historical bytes and allows preparing displayed current content" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let loading = synthesis_model()
  let old = delivery_fixture(state="stale")
  let status = {
    ..old,
    manifest: Some({ ..old.manifest.unwrap(), source_digest: "sha256:older", }),
  }
  let (_, current) = update(
    _ => @rabbita.none,
    DeliveryLoaded(loading.delivery.pending.unwrap(), Ok(status)),
    loading,
  )
  let html = qa_test_render(current)
  assert_true(
    html.contains("Historical saved package · current research differs"),
  )
  assert_true(
    html.contains("This intact package contains earlier retained content"),
  )
  assert_true(html.contains("sha256:older"))
  assert_false(html.contains("Current package · complete"))
  for name in ["report.md", "evidence.json", "synthesis.json", "manifest.json"] {
    assert_true(html.contains("Preview " + name))
    assert_true(html.contains("Download " + name))
  }
  assert_true(html.contains("Download complete package · ZIP"))
  let (cell, dispatch) = retained_harness(current)
  ignore(dispatch(PrepareDelivery))
  ignore(dispatch(PrepareDelivery))
  assert_eq(retained_requests().length(), 1)
  assert_true(
    retained_requests()[0]
    is {
      "method": "POST",
      "url": "/api/v1/delivery/prepare",
      "body": { "run_id": "run-1", "source_digest": "sha256:first", .. },
      ..
    },
  )
  assert_false(qa_test_render(cell.val).contains("Preview report.md"))
  complete_question_http(
    0,
    ToJson::to_json(delivery_fixture()).stringify(),
    false,
  )
  assert_true(qa_test_render(cell.val).contains("Current package · complete"))
}

///|
test "stale packages still require complete validated manifest and exact selected ID" {
  let model = synthesis_model()
  let request = model.delivery.pending.unwrap()
  let intact = delivery_fixture(state="stale")
  let manifest = intact.manifest.unwrap()
  for
    invalid in [
      { ..intact, manifest: None, },
      { ..intact, issues: ["report.md digest mismatch"], },
      { ..intact, manifest: Some({ ..manifest, files: [], }), },
      { ..intact, manifest: Some({ ..manifest, run_id: "different-run", }), },
    ] {
    let (_, rejected) = update(
      _ => @rabbita.none,
      DeliveryLoaded(request, Ok(invalid)),
      model,
    )
    assert_true(rejected.delivery.error is Some(_))
    assert_false(qa_test_render(rejected).contains("Preview report.md"))
    assert_false(qa_test_render(rejected).contains("Download complete package"))
  }
  assert_true(
    delivery_status_issue(
      {
        ..request,
        selected_id: Some(
          "delivery-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        ),
      },
      intact,
    )
    is Some(_),
  )
  assert_true(
    delivery_status_issue(
      { ..request, selected_id: Some(delivery_fixture_id()), },
      intact,
    )
    is None,
  )
}

///|
test "delivery refresh immediately hides links and failures cannot resurrect them" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let (cell, dispatch) = retained_harness(delivered_model())
  ignore(dispatch(RefreshDelivery))
  assert_true(cell.val.delivery.status is None)
  assert_false(qa_test_render(cell.val).contains("Preview report.md"))
  complete_question_http(0, "offline", true)
  assert_true(cell.val.delivery.error is Some(_))
  assert_false(qa_test_render(cell.val).contains("Preview report.md"))
  complete_question_http(
    0,
    ToJson::to_json(delivery_fixture()).stringify(),
    false,
  )
  assert_true(cell.val.delivery.status is None)
  assert_true(cell.val.delivery.error is Some(_))
}

///|
test "workspace reload blocks delivery checks until current workspace returns and rejects pending preparation" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let (cell, dispatch) = retained_harness(delivered_model(state="not-prepared"))
  ignore(dispatch(PrepareDelivery))
  ignore(dispatch(RefreshMoonTownStatus))
  assert_false(cell.val.delivery.workspace_ready)
  ignore(dispatch(RefreshDelivery))
  ignore(dispatch(PrepareDelivery))
  assert_eq(retained_requests().length(), 2)
  complete_question_http(
    0,
    ToJson::to_json(delivery_fixture()).stringify(),
    false,
  )
  assert_true(cell.val.delivery.status is None)
  assert_false(qa_test_render(cell.val).contains("Preview report.md"))
  ignore(
    dispatch(
      WorkspaceLoaded(
        cell.val.workspace_generation,
        Ok(synthesis_snapshot("run-2", "sha256:second")),
      ),
    ),
  )
  assert_true(cell.val.delivery.workspace_ready)
  assert_true(cell.val.delivery.pending is Some(_))
  assert_true(cell.val.delivery.versions.is_empty())
  assert_eq(cell.val.delivery.pending.unwrap().run_id, "run-2")
}

///|
test "historical versions use validated ID buttons and readonly requests without changing review or synthesis" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let model = delivered_model(state="stale")
  let (cell, dispatch) = retained_harness(model)
  ignore(dispatch(SelectDelivery("unlisted-id")))
  assert_eq(retained_requests().length(), 0)
  ignore(dispatch(SelectDelivery(delivery_fixture_id())))
  ignore(dispatch(SelectDelivery(delivery_fixture_id())))
  assert_eq(retained_requests().length(), 1)
  assert_true(
    retained_requests()[0] is { "method": "GET", "url": String(url), .. } &&
    url == "/api/v1/delivery/" + delivery_fixture_id(),
  )
  let status = delivery_fixture()
  let historical = {
    ..status,
    state: "stale",
    manifest: Some({
      ..status.manifest.unwrap(),
      source_digest: "sha256:older",
    }),
  }
  complete_question_http(0, ToJson::to_json(historical).stringify(), false)
  let html = qa_test_render(cell.val)
  assert_true(
    html.contains("Historical saved package · current research differs"),
  )
  assert_true(html.contains("sha256:older"))
  assert_true(html.contains("Preview report.md"))
  assert_true(html.contains("Back to current package"))
  assert_eq(
    cell.val.moontown_result.bind(result => result.source_digest),
    Some("sha256:first"),
  )
  ignore(dispatch(PrepareDelivery))
  assert_eq(retained_requests().length(), 1)
  ignore(dispatch(RefreshDelivery))
  assert_true(cell.val.delivery.selected_id is None)
  assert_false(qa_test_render(cell.val).contains("Preview report.md"))
  assert_true(
    retained_requests()[1] is { "method": "GET", "url": "/api/v1/delivery", .. },
  )
}

///|
test "completed status must bind current run source exact filenames and selected saved version" {
  let request = synthesis_model().delivery.pending.unwrap()
  let valid = delivery_fixture()
  let manifest = valid.manifest.unwrap()
  assert_true(delivery_status_issue(request, valid) is None)
  for
    status in [
      { ..valid, contract_id: "unknown", },
      { ..valid, run_id: "other-run", },
      { ..valid, manifest: None, },
      { ..valid, issues: ["changed bytes"], },
      { ..valid, versions: ["../outside"], },
      {
        ..valid,
        manifest: Some({ ..manifest, source_digest: "sha256:other", }),
      },
      { ..valid, manifest: Some({ ..manifest, files: [], }), },
      {
        ..valid,
        manifest: Some({
          ..manifest,
          files: [manifest.files[0], manifest.files[0], manifest.files[2]],
        }),
      },
      {
        ..valid,
        manifest: Some({
          ..manifest,
          files: [
            { ..manifest.files[0], name: "../report.md", },
            manifest.files[1],
            manifest.files[2],
          ],
        }),
      },
    ] {
    assert_true(delivery_status_issue(request, status) is Some(_))
  }
  assert_true(
    delivery_status_issue(
      {
        ..request,
        selected_id: Some(
          "delivery-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        ),
      },
      valid,
    )
    is Some(_),
  )
}

///|
test "delivery ABA discards stale success and failure after a newer matching-context request starts" {
  let start = synthesis_model()
  let old = start.delivery.pending.unwrap()
  let (_, changed) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(1, Ok(synthesis_snapshot("run-1", "sha256:second"))),
    start,
  )
  let (_, returned) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(1, Ok(synthesis_snapshot("run-1", "sha256:first"))),
    changed,
  )
  let newest = returned.delivery.pending.unwrap()
  assert_true(newest.generation > old.generation)
  for result in [Ok(delivery_fixture()), Err("obsolete failure")] {
    let (_, ignored) = update(
      _ => @rabbita.none,
      DeliveryLoaded(old, result),
      returned,
    )
    assert_eq(ignored.delivery.pending, Some(newest))
    assert_true(ignored.delivery.status is None)
    assert_true(ignored.delivery.error is None)
  }
  let (_, completed) = update(
    _ => @rabbita.none,
    DeliveryLoaded(newest, Ok(delivery_fixture())),
    returned,
  )
  assert_true(completed.delivery.status is Some(_))
}

///|
test "missing synthesis can inspect older packages but never prepare new ones" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let (_, model) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(1, Ok(route_snapshot("run-1"))),
    initial_model(),
  )
  let (cell, dispatch) = retained_harness(model)
  ignore(dispatch(PrepareDelivery))
  assert_eq(retained_requests().length(), 0)
  ignore(dispatch(RefreshDelivery))
  complete_question_http(
    0,
    ToJson::to_json(delivery_fixture(state="stale")).stringify(),
    false,
  )
  assert_eq(cell.val.delivery.versions, [delivery_fixture_id()])
  assert_true(
    qa_test_render(cell.val).contains(
      "Historical saved package · current research differs",
    ),
  )
  assert_true(qa_test_render(cell.val).contains("Preview report.md"))
  ignore(dispatch(PrepareDelivery))
  assert_eq(retained_requests().length(), 1)
  ignore(dispatch(SelectDelivery(delivery_fixture_id())))
  complete_question_http(
    1,
    ToJson::to_json(delivery_fixture(state="stale")).stringify(),
    false,
  )
  assert_true(
    qa_test_render(cell.val).contains(
      "Historical saved package · current research differs",
    ),
  )
  assert_true(qa_test_render(cell.val).contains("Preview report.md"))
  assert_true(current_synthesis(cell.val) is None)
}

///|
test "typed host delivery errors and malformed status never become success" {
  assert_true(
    decode_delivery(
      Ok({
        "error": {
          "contract_id": "moonfind.ui-host-error.v1",
          "message": "retained bytes changed",
        },
      }),
    )
    is Err("retained bytes changed"),
  )
  assert_true(
    decode_delivery(Ok({ "contract_id": "moonfind.delivery-status.v1" }))
    is Err(_),
  )
}
