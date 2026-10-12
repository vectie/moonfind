///|
extern "js" fn ris_native_fixture() -> String =
  #|() => process.getBuiltinModule('fs').readFileSync(process.env.MOONFIND_RIS_FIXTURE, 'utf8')

///|
test "RIS compiled UI actual native host import filter select save reopen export" {
  if !brief_install_native_transport() {
    return
  }
  defer brief_restore_native_transport()
  install_choice_storage("ok")
  defer restore_choice_storage()
  let scheduler = RouteTestScheduler::{
    hooks: { url_request: None, url_changed: None, },
  }
  let draft = {
    ..brief_fixture_draft(),
    brief_id: "ris-ui-fixture",
    sources: [],
  }
  let cell = Ref({
    ..initial_model(),
    brief: { ..initial_brief_view(), draft, },
  })
  fn dispatch(message : Msg) -> @rabbita.Cmd {
    let (command, next) = update(dispatch, message, cell.val)
    cell.val = next
    @cmd.Scheduler::add(scheduler, command)
    @rabbita.none
  }
  let original = ris_native_fixture()
  let source : BriefInputSource = {
    name: "local-bibliography.ris",
    origin: "User-selected local file: local-bibliography.ris",
    captured_at: "2026-10-08T14:00:00Z",
    kind: "local-file",
    content_hex: brief_text_hex(original),
  }
  // File chooser completion enters the production reducer, then every request
  // uses the compiled Rabbita HTTP command against the real native host.
  ignore(
    dispatch(
      BriefAction(
        Ris(
          FileLoaded(
            cell.val.brief.generation,
            ({ "sources": [source.to_json()] } : Json).stringify(),
          ),
        ),
      ),
    ),
  )
  assert_eq(cell.val.brief.error, None)
  assert_eq(cell.val.brief.ris.intake.unwrap().total_count, 3)
  let cards = cell.val.brief.ris.intake.unwrap().references
  assert_eq(cards[0].authors, ["García, Ana", "王, 明"])
  assert_eq(
    cards[0].abstract_text,
    "First abstract line.\n第二行 with Unicode.",
  )
  assert_true(qa_test_render(cell.val).contains("Tactile mapping"))
  ignore(dispatch(BriefAction(Ris(Filter("GARCÍA")))))
  assert_eq(ris_filtered(cell.val.brief.ris).map(r => r.record_number), [1, 3])
  assert_false(qa_test_render(cell.val).contains("Tactile mapping"))
  ignore(dispatch(BriefAction(Ris(Toggle(1)))))
  ignore(dispatch(BriefAction(Ris(Toggle(3)))))
  ignore(dispatch(BriefAction(Ris(Filter("Smith")))))
  assert_eq(cell.val.brief.ris.selected, [1, 3])
  ignore(dispatch(BriefAction(Ris(AddSelected))))
  assert_eq(cell.val.brief.error, None)
  assert_eq(cell.val.brief.draft.sources.length(), 2)
  assert_eq(cell.val.brief.draft.sources[0], source)
  let selected : RisSelection = @json.from_json(
    @json.parse(
      brief_source_preview(cell.val.brief.draft.sources[1].content_hex),
    ),
  )
  assert_eq(selected.references.map(r => r.record_number), [1, 3])
  assert_true(
    qa_test_render(cell.val).contains(
      "Selected reference cards from local-bibliography.ris",
    ),
  )
  ignore(dispatch(BriefAction(Save)))
  assert_eq(cell.val.brief.error, None)
  let saved = cell.val.brief.opened.unwrap()
  let saved_draft = cell.val.brief.draft
  assert_eq(saved.state, "prepared")
  cell.val = initial_model()
  ignore(dispatch(BriefAction(Open(saved.brief_id, saved.revision_id))))
  assert_eq(cell.val.brief.error, None)
  assert_eq(cell.val.brief.draft, saved_draft)
  let html = qa_test_render(cell.val)
  assert_true(
    html.contains("Selected reference cards from local-bibliography.ris"),
  )
  assert_true(html.contains("Références locales"))
  assert_true(html.contains("第二行 with Unicode."))
  let zip = brief_native_export(
    "/api/v1/briefs/" +
    saved.brief_id +
    "/" +
    saved.revision_id +
    "/dossier.zip",
  )
  assert_true(zip.has_prefix("504b0304"))
  println(
    "MOONFIND_RIS_NATIVE=" +
    (
      {
        "imported": 3,
        "author_filter": "GARCÍA",
        "selected_record_numbers": [1, 3],
        "revision_id": saved.revision_id,
        "original_source_preserved": true,
        "reopened_cards": 2,
        "dossier_bytes": zip.length() / 2,
        "requests": @json.parse(brief_native_requests()),
        "provider_calls": 0,
      } : Json).stringify(),
  )
}

///|
test "RIS UI pending import can be cleared and stale response does not replace new brief" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = {
    ..initial_model(),
    brief: { ..initial_brief_view(), pending: true, generation: 7, },
  }
  let (_, fresh) = update(_ => @rabbita.none, BriefAction(New), model)
  let (_, stale) = update(
    _ => @rabbita.none,
    BriefAction(Ris(Imported(7, Ok(Json::null())))),
    fresh,
  )
  assert_eq(stale.brief.draft, fresh.brief.draft)
  assert_true(stale.brief.ris.intake is None)
  assert_false(stale.brief.pending)
}
