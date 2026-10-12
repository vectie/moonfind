///|
extern "js" fn bibtex_native_fixture() -> String =
  #|() => process.getBuiltinModule('fs').readFileSync(process.env.MOONFIND_BIBTEX_FIXTURE, 'utf8')

///|
test "BIBTEX compiled UI actual native host import filter select save reopen export" {
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
    brief_id: "bibtex-ui-fixture",
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
  let original = bibtex_native_fixture()
  let source : BriefInputSource = {
    name: "local-bibliography.bib",
    origin: "User-selected local file: local-bibliography.bib",
    captured_at: "2026-10-08T14:00:00Z",
    kind: "local-file",
    content_hex: brief_text_hex(original),
  }
  // File chooser completion enters the production reducer, then every request
  // uses the compiled Rabbita HTTP command against the real native host.
  ignore(
    dispatch(
      BriefAction(
        Bibtex(
          FileLoaded(
            cell.val.brief.generation,
            ({ "sources": [source.to_json()] } : Json).stringify(),
          ),
        ),
      ),
    ),
  )
  assert_eq(cell.val.brief.error, None)
  assert_eq(cell.val.brief.bibtex.intake.unwrap().total_count, 3)
  let cards = cell.val.brief.bibtex.intake.unwrap().references
  assert_eq(cards[0].authors, ["García, Ana", "王, 明"])
  assert_eq(cards[0].citation_key, "garcia2025Lunar")
  assert_eq(cards[0].venue, "Lunar Systems Workshop")
  assert_eq(cards[2].availability, "metadata-only")
  assert_eq(
    cards[0].abstract_text,
    "First abstract line.\n第二行 with Unicode.",
  )
  assert_true(qa_test_render(cell.val).contains("Tactile mapping"))
  for query in ["garcia2025Lunar", "2025", "contact"] {
    ignore(dispatch(BriefAction(Bibtex(Filter(query)))))
    assert_eq(
      bibtex_filtered(cell.val.brief.bibtex).map(r => r.record_number),
      [1],
    )
  }
  ignore(dispatch(BriefAction(Bibtex(Filter("GARCÍA")))))
  assert_eq(bibtex_filtered(cell.val.brief.bibtex).map(r => r.record_number), [
    1, 3,
  ])
  assert_false(qa_test_render(cell.val).contains("Tactile mapping"))
  ignore(dispatch(BriefAction(Bibtex(Toggle(1)))))
  ignore(dispatch(BriefAction(Bibtex(Toggle(3)))))
  ignore(dispatch(BriefAction(Bibtex(Filter("Smith")))))
  assert_eq(cell.val.brief.bibtex.selected, [1, 3])
  ignore(dispatch(BriefAction(Bibtex(AddSelected))))
  assert_eq(cell.val.brief.error, None)
  assert_eq(cell.val.brief.draft.sources.length(), 2)
  assert_eq(cell.val.brief.draft.sources[0], source)
  let selected : BibtexSelection = @json.from_json(
    @json.parse(
      brief_source_preview(cell.val.brief.draft.sources[1].content_hex),
    ),
  )
  assert_eq(selected.references.map(r => r.record_number), [1, 3])
  assert_true(
    qa_test_render(cell.val).contains(
      "Selected reference cards from local-bibliography.bib",
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
    html.contains("Selected reference cards from local-bibliography.bib"),
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
    "MOONFIND_BIBTEX_NATIVE=" +
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
test "BIBTEX UI pending import can be cleared and stale response does not replace new brief" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = {
    ..initial_model(),
    brief: { ..initial_brief_view(), pending: true, generation: 7, },
  }
  let (_, fresh) = update(_ => @rabbita.none, BriefAction(New), model)
  let (_, stale) = update(
    _ => @rabbita.none,
    BriefAction(Bibtex(Imported(7, Ok(Json::null())))),
    fresh,
  )
  assert_eq(stale.brief.draft, fresh.brief.draft)
  assert_true(stale.brief.bibtex.intake is None)
  assert_false(stale.brief.pending)
}
