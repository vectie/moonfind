///|
extern "js" fn csl_native_fixture() -> String =
  #|() => process.getBuiltinModule('fs').readFileSync(process.env.MOONFIND_CSL_FIXTURE, 'utf8')

///|
test "CSL compiled UI actual native host import filter select save reopen export" {
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
    brief_id: "csl-ui-fixture",
    question: "Which contact-sensing approach should we investigate before terrain trials?",
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
  let original = csl_native_fixture()
  let source : BriefInputSource = {
    name: "local-bibliography.csl.json",
    origin: "User-selected local file: local-bibliography.csl.json",
    captured_at: "2026-10-08T14:00:00Z",
    kind: "local-file",
    content_hex: brief_text_hex(original),
  }
  let wrong_export = {
    ..source,
    content_hex: brief_text_hex("{\"items\":[]}"),
  }
  ignore(
    dispatch(
      BriefAction(
        Csl(
          FileLoaded(
            cell.val.brief.generation,
            ({ "sources": [wrong_export.to_json()] } : Json).stringify(),
          ),
        ),
      ),
    ),
  )
  assert_true(cell.val.brief.error is Some(_))
  assert_false(cell.val.brief.pending)
  assert_eq(cell.val.brief.draft.sources.length(), 0)
  // File chooser completion enters the production reducer, then every request
  // uses the compiled Rabbita HTTP command against the real native host.
  ignore(
    dispatch(
      BriefAction(
        Csl(
          FileLoaded(
            cell.val.brief.generation,
            ({ "sources": [source.to_json()] } : Json).stringify(),
          ),
        ),
      ),
    ),
  )
  assert_eq(cell.val.brief.error, None)
  assert_eq(cell.val.brief.csl.intake.unwrap().total_count, 3)
  let cards = cell.val.brief.csl.intake.unwrap().references
  assert_eq(cards[0].authors, ["García, Ana", "王, 明"])
  assert_eq(cards[0].citation_key, "garcia2025Lunar")
  assert_eq(cards[0].venue, "Lunar Systems Workshop")
  assert_eq(cards[0].issued, "2025-6-12")
  assert_eq(cards[1].item_id, "9007199254740993")
  assert_eq(cards[1].item_id_kind, "number")
  assert_eq(cards[1].authors[1], "Research and Development Group")
  assert_eq(cards[2].editors, ["García, Ana"])
  assert_eq(cards[2].issued, "forthcoming")
  assert_eq(cards[2].availability, "metadata-only")
  assert_eq(
    cards[0].abstract_text,
    "First abstract line.\n第二行 with Unicode.",
  )
  assert_true(qa_test_render(cell.val).contains("Tactile mapping"))
  assert_false(qa_test_render(cell.val).contains("<script>alert(1)</script>"))
  assert_true(qa_test_render(cell.val).contains("&lt;script&gt;"))
  for query in ["garcia2025Lunar", "2025", "contact", "LUNAR001", "10.1234"] {
    ignore(dispatch(BriefAction(Csl(Filter(query)))))
    assert_eq(csl_filtered(cell.val.brief.csl).map(r => r.record_number), [1])
  }
  ignore(dispatch(BriefAction(Csl(Filter("9007199254740993")))))
  assert_eq(csl_filtered(cell.val.brief.csl).map(r => r.record_number), [2])
  ignore(dispatch(BriefAction(Csl(Filter("forthcoming")))))
  assert_eq(csl_filtered(cell.val.brief.csl).map(r => r.record_number), [3])
  ignore(dispatch(BriefAction(Csl(Filter("GARCÍA")))))
  assert_eq(csl_filtered(cell.val.brief.csl).map(r => r.record_number), [1, 3])
  assert_false(qa_test_render(cell.val).contains("Tactile mapping"))
  ignore(dispatch(BriefAction(Csl(Toggle(1)))))
  ignore(dispatch(BriefAction(Csl(Toggle(3)))))
  ignore(dispatch(BriefAction(Csl(Filter("Smith")))))
  assert_eq(cell.val.brief.csl.selected, [1, 3])
  ignore(dispatch(BriefAction(Csl(AddSelected))))
  assert_eq(cell.val.brief.error, None)
  assert_eq(cell.val.brief.draft.sources.length(), 2)
  assert_eq(cell.val.brief.draft.sources[0], source)
  let selected : CslSelection = @json.from_json(
    @json.parse(
      brief_source_preview(cell.val.brief.draft.sources[1].content_hex),
    ),
  )
  assert_eq(selected.references.map(r => r.record_number), [1, 3])
  assert_eq(
    selected.references[0].item_id,
    "https://example.org/zotero/items/LUNAR001",
  )
  assert_true(
    qa_test_render(cell.val).contains(
      "Selected reference cards from local-bibliography.csl.json",
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
    html.contains("Selected reference cards from local-bibliography.csl.json"),
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
  // Use the saved selection as the evidence source of an editable decision
  // comparison. Its export retains both the citation keys and exact capture.
  let basis = offline_open_basis(cell.val).unwrap()
  ignore(dispatch(OfflineChoices(OpenOffline(basis.to_json().stringify()))))
  for
    action in [
      SetOption("option-1", "name", "Contact sensing pilot"),
      SetOption("option-1", "source", "source-2"),
      SetOption(
        "option-1", "unknowns", "[garcia2025Lunar] has only an abstract; hardware transfer remains unverified.",
      ),
      SetOption(
        "option-1", "experiment", "Compare contact error on a small simulated terrain set.",
      ),
      SetField(
        "reasoning", "Use the selected bibliography to narrow the next literature review.",
      ),
    ] {
    cell.val = offline_apply(cell.val, action)
  }
  let sheet = cell.val.offline_choices.sheet.unwrap()
  let comparison = offline_markdown(sheet, true)
  assert_true(comparison.contains("garcia2025Lunar"))
  assert_true(comparison.contains("Contact sensing pilot"))
  assert_true(comparison.contains("hardware transfer remains unverified"))
  assert_eq(sheet.current.options[0].source_slot, "source-2")
  let backup = offline_export_json(sheet, true).stringify()
  assert_eq(
    offline_decode(backup, saved.brief_id).unwrap().to_json(),
    sheet.to_json(),
  )
  println(
    "MOONFIND_CSL_NATIVE=" +
    (
      {
        "imported": 3,
        "query": "GARCÍA",
        "selected_record_numbers": [1, 3],
        "revision_id": saved.revision_id,
        "original_source_preserved": true,
        "reopened_cards": 2,
        "dossier_bytes": zip.length() / 2,
        "requests": @json.parse(brief_native_requests()),
        "provider_calls": 0,
        "comparison_markdown": comparison,
        "comparison_json": backup,
      } : Json).stringify(),
  )
}

///|
test "CSL UI pending import can be cleared and stale response does not replace new brief" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = {
    ..initial_model(),
    brief: { ..initial_brief_view(), pending: true, generation: 7, },
  }
  let (_, fresh) = update(_ => @rabbita.none, BriefAction(New), model)
  let (_, stale) = update(
    _ => @rabbita.none,
    BriefAction(Csl(Imported(7, Ok(Json::null())))),
    fresh,
  )
  assert_eq(stale.brief.draft, fresh.brief.draft)
  assert_true(stale.brief.csl.intake is None)
  assert_false(stale.brief.pending)
  let (_, late_selection) = update(
    _ => @rabbita.none,
    BriefAction(Csl(Selected(7, Ok(Json::array([]))))),
    fresh,
  )
  assert_eq(late_selection.brief.draft, fresh.brief.draft)
  assert_false(late_selection.brief.pending)
}

///|
test "CSL compiled UI cancellation malformed import repeat click and source capacity" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let emit = _ => @rabbita.none
  let initial = { ..initial_brief_view(), draft: brief_fixture_draft(), }
  let (_, cancelled) = update_csl_view(
    emit,
    FileLoaded(initial.generation, "{\"sources\":[]}"),
    initial,
  )
  assert_eq(cancelled.draft, initial.draft)
  assert_false(cancelled.pending)
  let (_, bad_file) = update_csl_view(
    emit,
    FileLoaded(initial.generation, "{\"error\":\"Invalid UTF-8\"}"),
    initial,
  )
  assert_true(bad_file.error.unwrap().contains("Invalid UTF-8"))
  assert_eq(bad_file.draft, initial.draft)
  let pending = { ..initial, pending: true, generation: 8, }
  let (_, repeated) = update_csl_view(emit, AddSelected, pending)
  assert_eq(repeated.generation, 8)
  assert_true(repeated.pending)
  assert_eq(repeated.draft, initial.draft)
  let (_, malformed) = update_csl_view(
    emit,
    Imported(8, Ok(Json::null())),
    pending,
  )
  assert_false(malformed.pending)
  assert_true(malformed.error is Some(_))
  assert_eq(malformed.draft, initial.draft)
  let (_, empty_selection) = update_csl_view(emit, AddSelected, initial)
  assert_true(empty_selection.error.unwrap().contains("Select at least one"))
  let full = {
    ..initial,
    draft: {
      ..initial.draft,
      sources: Array::make(7, initial.draft.sources[0]),
    },
    csl: {
      intake: Some({
        source: initial.draft.sources[0],
        references: [],
        total_count: 1,
      }),
      query: "",
      selected: [1],
    },
  }
  let (_, capacity) = update_csl_view(emit, AddSelected, full)
  assert_false(capacity.pending)
  assert_true(capacity.error.unwrap().contains("two source slots"))
  assert_eq(capacity.draft.sources.length(), 7)
}
