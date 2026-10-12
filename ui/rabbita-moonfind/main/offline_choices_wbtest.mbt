///|
fn offline_fixture_basis(
  id? : String = "brief-offline-fixture",
  version? : Char = 'a',
) -> BriefSnapshot {
  let draft = { ..brief_fixture_draft(), brief_id: id, }
  {
    contract_id: "moonfind.brief-snapshot.v1",
    revision_id: "revision-" + String::make(64, version),
    state: "prepared",
    brief: draft,
    boundary: "Prepared local captures only; no research or approval.",
    sources: [
      {
        slot: 1,
        name: draft.sources[0].name,
        origin: draft.sources[0].origin,
        captured_at: draft.sources[0].captured_at,
        kind: draft.sources[0].kind,
        availability: "retained-local-capture",
        archive_path: "sources/source-1.txt",
        byte_count: draft.sources[0].content_hex.length() / 2,
        digest: "sha256:" + String::make(64, version),
      },
    ],
  }
}

///|
fn offline_fixture_model(basis : BriefSnapshot) -> Model {
  let initial = initial_model()
  {
    ..initial,
    brief: {
      ..initial.brief,
      draft: basis.brief,
      pending: false,
      error: None,
      opened: Some({
        contract_id: "moonfind.brief-status.v1",
        brief_id: basis.brief.brief_id,
        revision_id: basis.revision_id,
        state: "prepared",
        snapshot: Some(basis),
        issues: [],
      }),
    },
  }
}

///|
fn offline_started(basis : BriefSnapshot) -> Model {
  update_offline_choices(
    offline_fixture_model(basis),
    OpenOffline(basis.to_json().stringify()),
  )
}

///|
fn offline_apply(model : Model, action : ChoiceMsg) -> Model {
  let (_, next) = update(
    _ => @rabbita.none,
    OfflineChoices(
      EditOffline(
        model.offline_choices.key,
        model.offline_choices.sheet.unwrap().current.revision,
        model.offline_generation,
        action,
      ),
    ),
    model,
  )
  next
}

///|
extern "js" fn offline_route_fixture() -> Unit =
  #| () => { globalThis.__offlineOldLocation=Object.getOwnPropertyDescriptor(globalThis,'location'); Object.defineProperty(globalThis,'location',{configurable:true,value:{pathname:'/apps/moonfind/briefs'}}); }

///|
extern "js" fn offline_restore_route() -> Unit =
  #| () => { if(globalThis.__offlineOldLocation)Object.defineProperty(globalThis,'location',globalThis.__offlineOldLocation);else delete globalThis.location;delete globalThis.__offlineOldLocation; }

///|
test "offline choices ordinary brief route starts without research workspace or requests" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  offline_route_fixture()
  defer offline_restore_route()
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let basis = offline_fixture_basis()
  let model = offline_started(basis)
  assert_true(model.workspace is None)
  assert_true(model.choices.sheet is None)
  assert_eq(
    model.offline_choices.sheet.unwrap().current.basis.to_json(),
    basis.to_json(),
  )
  let html = qa_test_render(model)
  assert_true(html.contains("moonfind-brief-workspace"))
  assert_true(html.contains("offline-choice-worksheet"))
  assert_true(html.contains("Strongest local capture"))
  assert_true(html.contains("No research run"))
  assert_false(html.contains("Load a research workspace"))
  assert_eq(retained_requests().length(), 0)
}

///|
test "offline choice full user fields JSON reload preserve exact sources without fabricated research" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let basis = offline_fixture_basis()
  let mut model = offline_started(basis)
  for
    action in [
      SetOption("option-1", "name", "Pilot <script> 月面 🌒"),
      SetOption("option-1", "source", "source-1"),
      SetCriterion(0, "Learn within a week"),
      SetAssessment("option-1", 0, "Uncertain; no buyer evidence"),
      SetOption("option-1", "contradiction", "Reports disagree"),
      SetOption("option-1", "unknowns", "Demand"),
      SetOption("option-1", "cost", "One day"),
      SetOption("option-1", "experiment", "Ask three buyers to commit"),
      SetField("chosen", "option-1"),
      SetField("reasoning", "Smallest reversible test"),
      SetField("next", "Draft interview"),
      SetField("commitment", "user-reference-1"),
    ] {
    model = offline_apply(model, action)
  }
  let sheet = model.offline_choices.sheet.unwrap()
  let restored = offline_started(basis)
  assert_eq(restored.offline_choices.sheet.unwrap().to_json(), sheet.to_json())
  let encoded = offline_export_json(sheet, true).stringify()
  guard offline_decode(encoded, basis.brief.brief_id) is Ok(decoded) else {
    fail("Own offline JSON failed restore")
  }
  assert_eq(decoded.to_json(), sheet.to_json())
  for
    forbidden in [
      "\"run_id\"", "\"papers\"", "\"summaries\"", "\"claim_id\"", "moonfind.choice-worksheet.v1",
    ] {
    assert_false(encoded.contains(forbidden), msg=forbidden)
  }
  let markdown = offline_markdown(sheet, true)
  for
    field in [
      "Reports disagree",
      "Demand",
      "One day",
      "Ask three buyers",
      "Smallest reversible test",
      "Draft interview",
      "user-reference-1",
      basis.revision_id,
      basis.sources[0].digest,
      "source 月面 🌒\r\n",
      "Unknown / not recorded",
    ] {
    assert_true(markdown.contains(field), msg=field)
  }
  let html = qa_test_render(restored)
  assert_true(html.contains("&lt;script&gt;"))
  assert_false(html.contains("Pilot <script>"))
  let downloaded = offline_apply(restored, Export("md"))
  assert_eq(downloaded.offline_choices.recovery, markdown)
  assert_eq(
    downloaded.offline_choices.sheet.unwrap().to_json(),
    sheet.to_json(),
  )
}

///|
test "offline choice exact duplicate source names retain slot identity and full byte provenance" {
  let first = offline_fixture_basis()
  let duplicate = {
    ..first,
    brief: {
      ..first.brief,
      sources: first.brief.sources + first.brief.sources,
    },
    sources: first.sources +
    [{ ..first.sources[0], slot: 2, archive_path: "sources/source-2.txt", }],
  }
  assert_eq(offline_basis_issue(duplicate), "")
  let sheet = offline_edit(
    new_offline_sheet(duplicate),
    SetOption("option-1", "source", "source-2"),
  )
  assert_eq(sheet.current.options[0].source_slot, "source-2")
  assert_eq(
    offline_citation(sheet.current.basis, "source-2").unwrap().source.slot,
    2,
  )
  assert_true(offline_markdown(sheet, false).contains("Slot: 2"))
  assert_eq(
    offline_edit(sheet, SetOption("option-1", "source", "missing")).to_json(),
    sheet.to_json(),
  )
}

///|
test "offline choices unsaved incomplete corrupt or stale native basis cannot start or continue" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let basis = offline_fixture_basis()
  let initial = offline_fixture_model(basis)
  let (_, edited) = update(
    _ => @rabbita.none,
    BriefAction(Edit("question", "Unsaved new question")),
    initial,
  )
  assert_true(offline_open_basis(edited) is None)
  assert_true(
    update_offline_choices(edited, OpenOffline(basis.to_json().stringify())).offline_choices.sheet
    is None,
  )
  for
    bad in [
      { ..basis, state: "incomplete", },
      { ..basis, sources: [], },
      { ..basis, sources: [{ ..basis.sources[0], digest: "missing", }], },
      { ..basis, sources: [{ ..basis.sources[0], byte_count: 999, }], },
    ] {
    assert_true(offline_open_basis(offline_fixture_model(bad)) is None)
  }
  let started = offline_started(basis)
  let next = offline_fixture_basis(version='b')
  let stale = update_offline_choices(
    { ..started, brief: offline_fixture_model(next).brief, },
    ContinueOffline(
      started.offline_choices.key,
      1,
      started.offline_generation,
      basis.to_json().stringify(),
    ),
  )
  assert_eq(
    stale.offline_choices.sheet.unwrap().to_json(),
    started.offline_choices.sheet.unwrap().to_json(),
  )
}

///|
test "offline continuation retains exact history and clears changed citations without revalidating direction" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let basis = offline_fixture_basis()
  let chosen = offline_edit(
    offline_edit(
      offline_edit(
        new_offline_sheet(basis),
        SetOption("option-1", "source", "source-1"),
      ),
      SetField("chosen", "option-1"),
    ),
    SetField("reasoning", "Prior rationale"),
  )
  let changed = offline_fixture_basis(version='b')
  guard offline_continue(chosen, changed) is Ok(next) else {
    fail("Continuation failed")
  }
  assert_eq(next.history.length(), 1)
  assert_eq(next.history[0].to_json(), chosen.current.to_json())
  assert_eq(next.current.options[0].source_slot, "")
  assert_eq(
    next.current.options[0].historical_source.unwrap().source.digest,
    basis.sources[0].digest,
  )
  assert_eq(next.current.chosen_option_id, "option-1")
  assert_eq(next.current.reasoning, "Prior rationale")
  guard offline_decode(
      offline_export_json(next, true).stringify(),
      basis.brief.brief_id,
    )
    is Ok(restored) else {
    fail("History restore failed")
  }
  assert_eq(restored.to_json(), next.to_json())
  let markdown = offline_markdown(next, true)
  assert_true(markdown.contains(basis.sources[0].digest))
  assert_true(markdown.contains(changed.sources[0].digest))
  assert_true(markdown.contains("Complete retained earlier versions"))
  assert_true(
    offline_continue(next, offline_fixture_basis(id="another-brief")) is Err(_),
  )
}

///|
test "offline storage corruption quota and cross brief switching preserve old drafts" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let basis = offline_fixture_basis()
  let model = offline_started(basis)
  let key = model.offline_choices.key
  assert_eq(choice_storage_write(key, "{broken"), "")
  let blocked = offline_started(basis)
  assert_true(blocked.offline_choices.blocked)
  let edits = offline_apply(blocked, SetField("reasoning", "Keep locally"))
  assert_eq(
    @json.parse(choice_storage_read(key)),
    ({ "value": "{broken" } : Json),
  )
  let backup = offline_export_json(edits.offline_choices.sheet.unwrap(), true).stringify()
  let recovered = offline_apply(
    offline_apply(edits, SetRecovery(backup)),
    Restore,
  )
  assert_false(recovered.offline_choices.blocked)
  set_choice_storage_mode("quota")
  let unsaved = offline_apply(
    recovered,
    SetField("reasoning", "Unsaved quota rationale"),
  )
  assert_true(unsaved.offline_choices.notice.contains("save failed"))
  let other = offline_fixture_basis(id="different-brief")
  let switched = update_offline_choices(
    { ..unsaved, brief: offline_fixture_model(other).brief, },
    OpenOffline(other.to_json().stringify()),
  )
  assert_eq(switched.offline_choices.sheet.unwrap().current.reasoning, "")
  let back = update_offline_choices(
    { ..switched, brief: offline_fixture_model(basis).brief, },
    OpenOffline(basis.to_json().stringify()),
  )
  assert_eq(
    back.offline_choices.sheet.unwrap().current.reasoning,
    "Unsaved quota rationale",
  )
  assert_true(offline_decode(backup, other.brief.brief_id) is Err(_))
  set_choice_storage_mode("ok")
  assert_eq(
    offline_started(basis).offline_choices.sheet.unwrap().current.reasoning,
    "Keep locally",
  )
  let durable = choice_storage_read(key)
  set_choice_storage_mode("read-error")
  let unreadable = offline_started(basis)
  assert_true(unreadable.offline_choices.blocked)
  let unsaved_read = offline_apply(
    unreadable,
    SetField("reasoning", "Read error local edit"),
  )
  assert_true(unsaved_read.offline_choices.blocked)
  set_choice_storage_mode("ok")
  assert_eq(choice_storage_read(key), durable)
}

///|
test "offline restore bounds and stale edit context never touch research worksheet" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = offline_started(offline_fixture_basis())
  let before = model.offline_choices.sheet.unwrap().to_json()
  let stale = update_offline_choices(
    model,
    EditOffline(
      "different key",
      1,
      model.offline_generation,
      SetField("reasoning", "wrong"),
    ),
  )
  assert_eq(stale.offline_choices.sheet.unwrap().to_json(), before)
  assert_true(stale.choices.sheet is None)
  let sheet = model.offline_choices.sheet.unwrap()
  assert_true(
    offline_decode(
      choice_export_json(new_choice_sheet(evidence_workspace("old")), true).stringify(),
      sheet.current.basis.brief.brief_id,
    )
    is Err(_),
  )
  assert_true(
    choice_decode(offline_export_json(sheet, true).stringify(), "old") is Err(_),
  )
  assert_true(
    offline_decode(
      String::make(2000001, 'x'),
      sheet.current.basis.brief.brief_id,
    )
    is Err(_),
  )
  let mut edited = sheet
  for _ in 0..<8 {
    edited = offline_edit(edited, AddOption)
    edited = offline_edit(edited, AddCriterion)
  }
  assert_eq(edited.current.options.length(), 4)
  assert_eq(edited.current.criteria.length(), 6)
  assert_true(
    edited.current.options.all(item => item.assessments.length() == 6),
  )
}
