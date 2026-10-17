///|
fn nbib_test_original() -> String {
  "\uFEFFPMID- 99900001\r\nSTAT- MEDLINE\r\nTI  - Synthetic lunar evidence:\r\n      a local comparison 🌒.\r\nFAU - García, Ana\r\nAU  - Garcia A\r\nAU  - Lee J\r\nDP  - 2025 Jan 12\r\nPT  - Journal Article\r\nJT  - Example Research Journal\r\nAID - 10.1234/lunar.1 [doi]\r\nAB  - Supplied first line.\r\n      第二行.\r\nOT  - lunar habitat\r\nZZ  - Unknown database tag\r\n\r\nPMID- 99900002\r\nTI  - Unselected mapping study\r\nAU  - Smith J\r\nDP  - 2024\r\n\r\nPMID- 99900001\r\nTI  - Separate supplied duplicate\r\nFAU - García, Ana\r\nAU  - Garcia A\r\nDP  - 2023\r\nPT  - Journal Article\r\nLID - 10.1234/LUNAR.1 [doi]\r\n"
}

///|
extern "js" fn nbib_write_evidence(name : String, content : String) -> Unit =
  #|(name,content) => {const dir=process.env.MOONFIND_NBIB_EVIDENCE;if(dir)process.getBuiltinModule('fs').writeFileSync(dir+'/'+name,content);}

///|
test "NBIB compiled UI native import inspect select edit filter shortlist export save reopen" {
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
        brief_id: "nbib-ui-fixture",
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
  let original = nbib_test_original()
  let source = reading_source("local-citations.nbib", original)
  ignore(
    dispatch(
      BriefAction(
        Nbib(
          FileLoaded(
            cell.val.brief.generation,
            ({ "sources": [source.to_json()] } : Json).stringify(),
          ),
        ),
      ),
    ),
  )
  assert_eq(cell.val.brief.error, None)
  assert_eq(cell.val.brief.nbib.intake.unwrap().total_count, 3)
  let cards = cell.val.brief.nbib.intake.unwrap().references
  assert_eq(cards[0].authors, ["García, Ana", "Lee J"])
  assert_eq(cards[0].abstract_text, "Supplied first line. 第二行.")
  assert_true(qa_test_render(cell.val).contains("Unknown database tag"))
  assert_true(qa_test_render(cell.val).contains("Supplied PMID: 99900001"))
  ignore(dispatch(BriefAction(Nbib(Filter("GARCÍA")))))
  assert_eq(nbib_filtered(cell.val.brief.nbib).map(r => r.record_number), [1, 3])
  assert_false(qa_test_render(cell.val).contains("Unselected mapping study"))
  ignore(dispatch(BriefAction(Nbib(Toggle(3)))))
  ignore(dispatch(BriefAction(Nbib(Toggle(1)))))
  ignore(dispatch(BriefAction(Nbib(Filter("Smith")))))
  assert_eq(cell.val.brief.nbib.selected, [3, 1])
  ignore(dispatch(BriefAction(Nbib(AddSelected))))
  assert_eq(cell.val.brief.error, None)
  assert_eq(cell.val.brief.draft.sources.length(), 2)
  assert_eq(cell.val.brief.draft.sources[0], source)
  let selected : NbibSelection = @json.from_json(
    @json.parse(
      brief_source_preview(cell.val.brief.draft.sources[1].content_hex),
    ),
  )
  assert_eq(selected.references.map(r => r.record_number), [1, 3])
  assert_eq(selected.references[0].fields.last().unwrap().tag, "ZZ")
  ignore(
    dispatch(
      BriefAction(
        Edit(
          "question", "Which supplied lunar citation deserves full-text follow-up?",
        ),
      ),
    ),
  )
  assert_eq(
    cell.val.brief.draft.question,
    "Which supplied lunar citation deserves full-text follow-up?",
  )
  let catalog = reference_catalog(cell.val.brief)
  assert_eq(catalog.issues, [])
  assert_eq(catalog.references.map(r => r.format), ["nbib", "nbib"])
  assert_eq(catalog.references.map(r => r.item_id_kind), ["pmid", "pmid"])
  assert_eq(catalog.references.map(r => r.item_id), ["99900001", "99900001"])
  assert_eq(catalog.references[0].availability, "metadata-and-abstract")
  assert_eq(catalog.references[1].availability, "metadata-only")
  assert_eq(reference_doi_counts(catalog).get("10.1234/lunar.1"), Some(2))
  assert_eq(reference_ris_type(catalog.references[0]), "JOUR")
  assert_eq(reference_csl_type(catalog.references[0]), "article-journal")
  assert_eq(reference_bibtex_type(catalog.references[0]), "article")
  ignore(dispatch(BriefAction(ReferenceList(Query("99900001")))))
  assert_eq(reference_matches(cell.val.brief, catalog).length(), 2)
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
  nbib_write_evidence(
    "selected-references.json",
    reference_shortlist_json(cell.val.brief),
  )
  ignore(dispatch(BriefAction(ReferenceList(Clear))))
  let ris = reference_ris_export(cell.val.brief)
  let csl = reference_csl_export(cell.val.brief)
  let bibtex = reference_bibtex_export(cell.val.brief)
  assert_true(ris.contains("TY  - JOUR"))
  assert_true(csl.contains("article-journal"))
  assert_true(bibtex.contains("@article"))
  for output in [ris, csl, bibtex, reference_list_export(cell.val.brief)] {
    assert_true(output.contains("99900001"))
  }
  nbib_write_evidence(
    "reading-list.json",
    reference_list_export(cell.val.brief),
  )
  nbib_write_evidence("reading-list.ris", ris)
  nbib_write_evidence("reading-list.csl.json", csl)
  nbib_write_evidence("reading-list.bib", bibtex)
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
  let zip = brief_native_export(
    "/api/v1/briefs/" +
    saved.brief_id +
    "/" +
    saved.revision_id +
    "/dossier.zip",
  )
  assert_true(zip.has_prefix("504b0304"))
  nbib_write_evidence("nbib-workspace.html", qa_test_render(cell.val))
  nbib_write_evidence(
    "retained-brief.json",
    saved_draft.to_json().stringify(indent=2),
  )
  nbib_write_evidence("original-citations.nbib", original)
  nbib_write_evidence(
    "nbib-selection.json",
    brief_source_preview(saved_draft.sources[1].content_hex),
  )
  let broken = reading_source(
    "broken.nbib", "PMID- 1\nTI  - Good first\n\nPMID- 2\nTI - Malformed final record\n",
  )
  ignore(
    dispatch(
      BriefAction(
        Nbib(
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
  assert_true(cell.val.brief.nbib.intake is None)
  assert_false(cell.val.brief.pending)
  nbib_write_evidence("native-requests.json", brief_native_requests())
  println(
    "MOONFIND_NBIB_NATIVE=" +
    (
      {
        "imported": 3,
        "selected_original_ordinals": [1, 3],
        "reading_list_count": 2,
        "pmid_preserved": true,
        "doi_group_count": 2,
        "year_filtered_ordinals": [1],
        "shortlisted_ordinals": [3],
        "question_edited": true,
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
test "NBIB new brief ignores stale pending replies and failed selection is recoverable" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = {
    ..initial_model(),
    brief: { ..initial_brief_view(), pending: true, generation: 7, },
  }
  let (_, fresh) = update(_ => @rabbita.none, BriefAction(New), model)
  let (_, stale) = update(
    _ => @rabbita.none,
    BriefAction(Nbib(Imported(7, Ok(Json::null())))),
    fresh,
  )
  assert_eq(stale.brief.draft, fresh.brief.draft)
  assert_true(stale.brief.nbib.intake is None)
  assert_false(stale.brief.pending)
  let view = {
    ..initial_brief_view(),
    draft: { ..brief_fixture_draft(), sources: [], },
    pending: true,
    generation: 3,
    nbib: { ..empty_nbib_view(), selected: [1, 3], },
  }
  let (_, failed) = update_nbib_view(
    _ => @rabbita.none,
    Selected(3, Ok({ "error": "Malformed last record" })),
    view,
  )
  assert_eq(failed.draft, view.draft)
  assert_eq(failed.nbib.selected, [1, 3])
  assert_false(failed.pending)
  assert_true(failed.error is Some(_))
}

///|
// Exercise the actual shared file reader. Only the selected File/DOM boundary is
// controlled; callbacks validate the resulting capture and report async failures.
extern "js" fn nbib_check_picker(pick : ((String) -> Unit) -> Unit) -> Unit =
  #|pick => {
  #| const previous=globalThis.document;
  #| const text='\ufeffPMID- 42\r\nTI  - Synthetic local citation 🌒\r\n';
  #| const modes=['valid','invalid-utf8','oversize','empty'];
  #| let completed=0;
  #| for(const mode of modes){
  #|  const bytes=mode==='invalid-utf8'?Uint8Array.of(255):new TextEncoder().encode(text);
  #|  const file={name:'citations.NBIB',size:mode==='oversize'?32769:bytes.length,arrayBuffer:async()=>bytes.buffer};
  #|  let changed;
  #|  globalThis.document={createElement(tag){if(tag!=='input')throw Error('Expected file input');return {files:mode==='empty'?[]:[file],addEventListener(event,fn){if(event==='change')changed=fn;},click(){if(this.accept!=='.nbib'||this.multiple!==false)throw Error('Incorrect NBIB chooser wiring');changed();}};}};
  #|  pick(raw=>{try{const result=JSON.parse(raw);if(mode==='valid'){if(result.sources.length!==1||result.sources[0].name!=='citations.NBIB'||result.sources[0].content_hex!==Buffer.from(text).toString('hex'))throw Error('NBIB file bytes or filename changed');}else if(mode==='empty'){if(result.sources.length!==0)throw Error('Empty chooser added source');}else if(!result.error)throw Error('Invalid NBIB capture accepted');completed++;}catch(error){console.error(error);process.exitCode=1;}});
  #| }
  #| globalThis.document=previous;
  #| process.once('beforeExit',()=>{if(completed!==modes.length){console.error('NBIB picker callbacks incomplete',completed);process.exitCode=1;}});
  #|}

///|
test "NBIB file picker accepts extension preserves bytes and reports rejected captures" {
  nbib_check_picker(done => brief_choose_files(done, ".nbib", false))
}
