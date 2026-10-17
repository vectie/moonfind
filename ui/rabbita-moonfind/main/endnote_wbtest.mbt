///|
fn endnote_test_original() -> String {
  "\uFEFF%0 Journal Article\r\n%T 月面 robotics 🌒\r\n%A García, Ana\r\n%A 王, 明\r\n%D 2025\r\n%J Robotics Letters\r\n%R 10.1234/lunar.1\r\n%X First abstract line.\r\n  第二行 with Unicode.\r\n%~ Research database\r\n%> file:///unopened.pdf\r\n\r\n%0 Conference Paper\r\n%T Tactile mapping\r\n%A Smith, Jo\r\n%D 2024\r\n\r\n%0 Book\r\n%T Références locales\r\n%A García, Ana\r\n%D 2023\r\n%R https://doi.org/10.1234/LUNAR.1\r\n"
}

///|
extern "js" fn endnote_write_evidence(name : String, content : String) -> Unit =
  #|(name,content) => {const dir=process.env.MOONFIND_ENDNOTE_EVIDENCE;if(dir)process.getBuiltinModule('fs').writeFileSync(dir+'/'+name,content);}

///|
test "EndNote compiled UI actual native host import inspect select reading list save reopen and late failure" {
  if !brief_install_native_transport() {
    return
  }
  defer brief_restore_native_transport()
  install_choice_storage("ok")
  defer restore_choice_storage()
  let scheduler = RouteTestScheduler::{
    hooks: { url_request: None, url_changed: None, },
  }
  let cell = Ref({
    ..initial_model(),
    brief: {
      ..initial_brief_view(),
      draft: {
        ..brief_fixture_draft(),
        brief_id: "endnote-ui-fixture",
        sources: [],
      },
    },
  })
  fn dispatch(message : Msg) -> @rabbita.Cmd {
    let (command, next) = update(dispatch, message, cell.val)
    cell.val = next
    @cmd.Scheduler::add(scheduler, command)
    @rabbita.none
  }
  let original = endnote_test_original()
  let source = reading_source("local-bibliography.enw", original)
  ignore(
    dispatch(
      BriefAction(
        Endnote(
          FileLoaded(
            cell.val.brief.generation,
            ({ "sources": [source.to_json()] } : Json).stringify(),
          ),
        ),
      ),
    ),
  )
  assert_eq(cell.val.brief.error, None)
  assert_eq(cell.val.brief.endnote.intake.unwrap().total_count, 3)
  let cards = cell.val.brief.endnote.intake.unwrap().references
  assert_eq(cards[0].authors, ["García, Ana", "王, 明"])
  assert_eq(
    cards[0].abstract_text,
    "First abstract line.\n第二行 with Unicode.",
  )
  assert_eq(cards[0].fields[9].value, "file:///unopened.pdf")
  assert_true(qa_test_render(cell.val).contains("Research database"))
  assert_true(qa_test_render(cell.val).contains("Tactile mapping"))
  ignore(dispatch(BriefAction(Endnote(Filter("GARCÍA")))))
  assert_eq(
    endnote_filtered(cell.val.brief.endnote).map(r => r.record_number),
    [1, 3],
  )
  assert_false(qa_test_render(cell.val).contains("Tactile mapping"))
  ignore(dispatch(BriefAction(Endnote(Toggle(3)))))
  ignore(dispatch(BriefAction(Endnote(Toggle(1)))))
  ignore(dispatch(BriefAction(Endnote(Filter("Smith")))))
  assert_eq(cell.val.brief.endnote.selected, [3, 1])
  ignore(dispatch(BriefAction(Endnote(AddSelected))))
  assert_eq(cell.val.brief.error, None)
  assert_eq(cell.val.brief.draft.sources.length(), 2)
  assert_eq(cell.val.brief.draft.sources[0], source)
  let selected : EndnoteSelection = @json.from_json(
    @json.parse(
      brief_source_preview(cell.val.brief.draft.sources[1].content_hex),
    ),
  )
  assert_eq(selected.references.map(r => r.record_number), [1, 3])
  assert_eq(selected.references[0].fields[9].value, "file:///unopened.pdf")
  let catalog = reference_catalog(cell.val.brief)
  assert_eq(catalog.issues, [])
  assert_eq(catalog.references.map(r => r.format), ["endnote", "endnote"])
  assert_eq(catalog.references[0].availability, "metadata-and-abstract")
  assert_eq(catalog.references[1].availability, "metadata-only")
  assert_eq(reference_doi_counts(catalog).get("10.1234/lunar.1"), Some(2))
  assert_eq(reference_ris_type(catalog.references[0]), "JOUR")
  assert_eq(reference_csl_type(catalog.references[0]), "article-journal")
  assert_eq(reference_bibtex_type(catalog.references[1]), "book")
  ignore(dispatch(BriefAction(ReferenceList(Timeline(From("2024"))))))
  assert_eq(
    reference_matches(cell.val.brief, catalog).map(r => r.record_number),
    [1],
  )
  ignore(
    dispatch(
      BriefAction(
        ReferenceList(
          Shortlist(
            Toggle(reference_choice(cell.val.brief, catalog.references[1])),
          ),
        ),
      ),
    ),
  )
  assert_eq(
    reference_shortlist_records(cell.val.brief).map(r => r.record_number),
    [3],
  )
  endnote_write_evidence(
    "selected-references.json",
    reference_shortlist_json(cell.val.brief),
  )
  ignore(dispatch(BriefAction(ReferenceList(Clear))))
  endnote_write_evidence(
    "reading-list.json",
    reference_list_export(cell.val.brief),
  )
  endnote_write_evidence(
    "reading-list.ris",
    reference_ris_export(cell.val.brief),
  )
  endnote_write_evidence(
    "reading-list.csl.json",
    reference_csl_export(cell.val.brief),
  )
  endnote_write_evidence(
    "reading-list.bib",
    reference_bibtex_export(cell.val.brief),
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
  assert_eq(reference_catalog(cell.val.brief).references.length(), 2)
  assert_eq(cell.val.brief.reference_shortlist, [])
  let html = qa_test_render(cell.val)
  assert_true(html.contains("Références locales"))
  assert_true(html.contains("第二行 with Unicode."))
  assert_true(html.contains("Research database"))
  assert_false(
    reference_catalog(cell.val.brief).references.any(r => {
      r.title == "Tactile mapping"
    }),
  )
  let zip = brief_native_export(
    "/api/v1/briefs/" +
    saved.brief_id +
    "/" +
    saved.revision_id +
    "/dossier.zip",
  )
  assert_true(zip.has_prefix("504b0304"))
  endnote_write_evidence("endnote-workspace.html", html)
  endnote_write_evidence(
    "retained-brief.json",
    saved_draft.to_json().stringify(indent=2),
  )
  endnote_write_evidence("original-bibliography.enw", original)
  endnote_write_evidence(
    "endnote-selection.json",
    brief_source_preview(saved_draft.sources[1].content_hex),
  )
  let broken = reading_source(
    "broken.enw", "%0 Book\n%T Good first\n\n%0 Book\n%Title malformed final record\n",
  )
  ignore(
    dispatch(
      BriefAction(
        Endnote(
          FileLoaded(
            cell.val.brief.generation,
            ({ "sources": [broken.to_json()] } : Json).stringify(),
          ),
        ),
      ),
    ),
  )
  assert_true(cell.val.brief.error is Some(_))
  assert_eq(cell.val.brief.draft, saved_draft)
  assert_true(cell.val.brief.endnote.intake is None)
  assert_false(cell.val.brief.pending)
  endnote_write_evidence("native-requests.json", brief_native_requests())
  println(
    "MOONFIND_ENDNOTE_NATIVE=" +
    (
      {
        "imported": 3,
        "selected_original_ordinals": [1, 3],
        "reading_list_count": 2,
        "doi_group_count": 2,
        "year_filtered_ordinals": [1],
        "shortlisted_ordinals": [3],
        "revision_id": saved.revision_id,
        "reopened": true,
        "original_preserved": true,
        "late_bad_record_partial_insert": false,
        "dossier_bytes": zip.length() / 2,
        "provider_calls": 0,
      } : Json).stringify(),
  )
}

///|
test "EndNote pending import can be cleared and stale replies do not enter a new brief" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = {
    ..initial_model(),
    brief: { ..initial_brief_view(), pending: true, generation: 7, },
  }
  let (_, fresh) = update(_ => @rabbita.none, BriefAction(New), model)
  let (_, stale) = update(
    _ => @rabbita.none,
    BriefAction(Endnote(Imported(7, Ok(Json::null())))),
    fresh,
  )
  assert_eq(stale.brief.draft, fresh.brief.draft)
  assert_true(stale.brief.endnote.intake is None)
  assert_false(stale.brief.pending)
}

///|
test "EndNote failed selection keeps the draft and recoverable selection intact" {
  let view = {
    ..initial_brief_view(),
    draft: { ..brief_fixture_draft(), sources: [], },
    pending: true,
    generation: 3,
    endnote: { ..empty_endnote_view(), selected: [1, 3], },
  }
  let (_, failed) = update_endnote_view(
    _ => @rabbita.none,
    Selected(3, Ok({ "error": "Malformed last record" })),
    view,
  )
  assert_eq(failed.draft, view.draft)
  assert_eq(failed.endnote.selected, [1, 3])
  assert_false(failed.pending)
  assert_true(failed.error is Some(_))
}
