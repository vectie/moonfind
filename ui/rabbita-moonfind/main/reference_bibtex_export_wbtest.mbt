///|
extern "js" fn bibtex_export_evidence(name : String, content : String) -> Unit =
  #|(name,content)=>{const dir=process.env.MOONFIND_BIBTEX_EVIDENCE;if(dir)process.getBuiltinModule('fs').writeFileSync(dir+'/'+name,content,{flag:'wx'});}

///|
extern "js" fn bibtex_export_provenance(content : String) -> String =
  #|content=>JSON.stringify(Array.from(content.matchAll(/^  moonfind_provenance_hex = \{([0-9a-f]+)\},$/gm),m=>JSON.parse(Buffer.from(m[1],'hex').toString('utf8'))))

///|
fn bibtex_export_case(
  name : String,
  view : BriefView,
  references : Array[ReadingReference],
  scope : String,
  output : String,
) -> Unit raise {
  let provenance : Array[Json] = @json.from_json(
    @json.parse(bibtex_export_provenance(output)),
  )
  assert_eq(provenance.length(), references.length())
  for i, item in provenance {
    let r = references[i]
    let source = view.draft.sources[r.source_slot - 1]
    guard item
      is {
        "contract_id": String("moonfind.reference-bibtex-export.v1"),
        "citation_key": String(key),
        "brief_id": String(brief),
        "export_scope": String(export_scope),
        "reference": reference,
        "capture": capture,
        ..
      } else {
      fail("Missing exact source lineage")
    }
    assert_eq(key, "moonfind-slot-\{r.source_slot}-record-\{r.record_number}")
    assert_eq(brief, view.draft.brief_id)
    assert_eq(export_scope, scope)
    assert_eq(reference, ToJson::to_json(r))
    assert_eq(
      capture,
      (
        {
          "name": source.name,
          "origin": source.origin,
          "captured_at": source.captured_at,
          "kind": source.kind,
        } : Json),
    )
    assert_false(item.stringify().contains("content_hex"))
  }
  bibtex_export_evidence(name + ".bib", output)
  bibtex_export_evidence(
    name + ".expected.json",
    references.to_json().stringify(indent=2),
  )
}

///|
test "BibTeX mixed sourced bibliography exports distinct original records and preserves lineage" {
  let view = reading_fixture()
  let output = reference_bibtex_export(view)
  let records = reference_catalog(view).references
  assert_true(output.contains("@article{moonfind-slot-2-record-1,"))
  assert_true(output.contains("  author = {{García, Ana}},"))
  assert_true(output.contains("  editor = {{García, Ana}},"))
  assert_true(output.contains("  year = {2026},"))
  assert_true(output.contains("  doi = {10.1234/Shared},"))
  assert_false(output.contains("javascript:"))
  assert_false(output.contains("publisher ="))
  assert_false(output.contains("school ="))
  assert_eq(records.length(), 9)
  bibtex_export_case("mixed", view, records, "current-matches", output)
  bibtex_export_evidence(
    "captures.json",
    view.draft.sources.to_json().stringify(indent=2),
  )
}

///|
test "BibTeX current filter and year order differ from hidden shortlist without merging duplicates" {
  let base = timeline_fixture()
  let selected = shortlist_pick(shortlist_pick(base, 1), 4)
  let view = reading_apply(
    reading_apply(
      reading_apply(selected, Timeline(From("2024"))),
      Timeline(Through("2025")),
    ),
    Timeline(Order("newest")),
  )
  let refs = reference_matches(view, reference_catalog(view))
  assert_eq(refs.map(r => (r.source_slot, r.record_number)), [
    (2, 1),
    (4, 3),
    (2, 3),
    (6, 1),
  ])
  bibtex_export_case(
    "filtered",
    view,
    refs,
    "current-matches",
    reference_bibtex_export(view),
  )
  let shortlist = reference_shortlist_bibtex(view)
  assert_eq(shortlist, reference_shortlist_bibtex(selected))
  bibtex_export_case(
    "hidden-shortlist",
    view,
    reference_shortlist_records(view),
    "explicit-shortlist",
    shortlist,
  )
  let doi = reading_apply(reading_fixture(), ShowDoi("10.1234/shared"))
  assert_eq(reference_matches(doi, reference_catalog(doi)).length(), 4)
  bibtex_export_case(
    "same-doi",
    doi,
    reference_matches(doi, reference_catalog(doi)),
    "current-matches",
    reference_bibtex_export(doi),
  )
  let repeated = {
    ..base,
    draft: {
      ..base.draft,
      sources: base.draft.sources + [base.draft.sources[1]],
    },
  }
  let repeated = reading_apply(repeated, Query("Conflicting method"))
  assert_eq(
    reference_matches(repeated, reference_catalog(repeated)).map(r => {
      r.source_slot
    }),
    [2, 7],
  )
  bibtex_export_case(
    "repeated-capture",
    repeated,
    reference_matches(repeated, reference_catalog(repeated)),
    "current-matches",
    reference_bibtex_export(repeated),
  )
}

///|
test "BibTeX known types map conservatively and date projection never invents precision" {
  let view = reading_fixture()
  let r = reference_catalog(view).references[0]
  for
    (format, kind, expected) in [
      ("bibtex", "conference", "inproceedings"),
      ("bibtex", "phdthesis", "phdthesis"),
      ("bibtex", "mastersthesis", "mastersthesis"),
      ("bibtex", "manual", "manual"),
      ("bibtex", "inbook", "inbook"),
      ("bibtex", "booklet", "booklet"),
      ("ris", "CHAP", "incollection"),
      ("ris", "CONF", "proceedings"),
      ("ris", "BOOK", "book"),
      ("csl", "report", "techreport"),
      ("csl", "manuscript", "unpublished"),
      ("csl", "article-journal", "article"),
      ("csl", "thesis", "misc"),
      ("ris", "THES", "misc"),
      ("csl", "dataset", "misc"),
      ("bibtex", "unknown", "misc"),
      ("csl", "article", "misc"),
    ] {
    assert_eq(
      reference_bibtex_type({ ..r, format, reference_type: kind, }),
      expected,
    )
  }
  for issued in ["forthcoming", "2024 / 2025", "2025-2-29", "2025?", ""] {
    assert_false(
      reference_bibtex_records(view, [{ ..r, issued, }], "current-matches").contains(
        "  year =",
      ),
    )
  }
  for issued in ["2024", "2024-2-29", "2024-12"] {
    assert_true(
      reference_bibtex_records(view, [{ ..r, issued, }], "current-matches").contains(
        "  year = {2024},",
      ),
    )
  }
  let records = [
    {
      ..r,
      record_number: 1,
      format: "csl",
      reference_type: "book",
      title: "Evidence handbook",
    },
    {
      ..r,
      record_number: 2,
      format: "csl",
      reference_type: "paper-conference",
      title: "Contact sensing study",
    },
    {
      ..r,
      record_number: 3,
      format: "csl",
      reference_type: "thesis",
      title: "Undeclared degree",
      issued: "forthcoming",
    },
    {
      ..r,
      record_number: 4,
      format: "bibtex",
      reference_type: "unknown",
      title: "",
      authors: [],
      issued: "",
      venue: "",
      doi: "",
      doi_match_key: "",
      keywords: "",
      abstract_text: "",
    },
  ]
  let output = reference_bibtex_records(view, records, "current-matches")
  assert_true(output.contains("  booktitle = {{Synthetic Review}},"))
  bibtex_export_case(
    "types-and-missing", view, records, "current-matches", output,
  )
}

///|
test "BibTeX hostile prose is literal with balanced braces literal names and exact originals" {
  let view = reading_fixture()
  let r = reference_catalog(view).references[0]
  let records = [
    {
      ..r,
      record_number: 1,
      title: "Open { only \\input{/private} \\write18{bad}\r\n\u0000 100% & $ # _ ^ ~ < > | 🌒",
      authors: ["Research and Development Group", "García, Ana", "A { only"],
      editors: ["王, 明"],
      url: "https://example.invalid/a_b",
      doi: "10.1234/a_b",
      doi_match_key: "10.1234/a_b",
    },
    {
      ..r,
      record_number: 2,
      title: "Close } only\n@preamble{\\input{bad}}\n@article{injected",
      authors: ["", " ", "B } only"],
      abstract_text: "Unbalanced } { \\command % comment\u2028line",
      url: "https://example.invalid/query?x=a&y=b",
      doi: "not doi",
      doi_match_key: "",
    },
  ]
  let output = reference_bibtex_records(view, records, "current-matches")
  assert_false(output.contains("\\input"))
  assert_false(output.contains("\\write18"))
  assert_false(output.contains("\n@preamble"))
  assert_false(output.contains("\n@article{injected"))
  assert_false(output.contains("  url ="))
  assert_false(output.contains("  doi ="))
  assert_true(output.contains("\\textbraceleft{}"))
  assert_true(output.contains("\\textbraceright{}"))
  assert_true(
    output.contains("{Research and Development Group} and {García, Ana}"),
  )
  bibtex_export_case(
    "hostile-literals", view, records, "current-matches", output,
  )
}

///|
test "BibTeX invalid empty pending stale and oversized downloads refuse without source mutation" {
  let base = shortlist_fixture()
  let invalid = {
    ..base,
    draft: {
      ..base.draft,
      sources: base.draft.sources +
      [reading_source("bibtex-selection.json", "{}")],
    },
  }
  let bad_bounds = reading_apply(base, Timeline(From("bad")))
  for
    view in [
      reading_apply(base, Query("absent")),
      { ..base, pending: true, },
      invalid,
      bad_bounds,
    ] {
    try reference_bibtex_export(view) catch {
      _ => ()
    } noraise {
      _ => fail("Expected current refusal")
    }
    let after = reading_apply(view, ExportBibtex)
    assert_eq(after.draft, view.draft)
    assert_eq(after.reference_shortlist, view.reference_shortlist)
    if !view.pending {
      assert_true(after.error is Some(_))
    }
  }
  assert_eq(
    reference_shortlist_bibtex(bad_bounds),
    reference_shortlist_bibtex(base),
  )
  let stale = {
    ..base,
    reference_source_generation: base.reference_source_generation + 1,
  }
  for view in [reading_fixture(), { ..base, pending: true, }, invalid, stale] {
    try reference_shortlist_bibtex(view) catch {
      _ => ()
    } noraise {
      _ => fail("Expected shortlist refusal")
    }
    let after = reading_apply(view, Shortlist(ExportBibtex))
    assert_eq(after.draft, view.draft)
    assert_eq(after.reference_shortlist, view.reference_shortlist)
  }
  let many = {
    ..base,
    draft: { ..base.draft, sources: Array::make(500, base.draft.sources[1]), },
    reference_query: "",
    reference_doi_filter: "",
  }
  let many = {
    ..many,
    reference_shortlist: reference_catalog(many).references.map(r => {
      reference_choice(many, r)
    }),
  }
  for action in [ReferenceListMsg::ExportBibtex, Shortlist(ExportBibtex)] {
    let after = reading_apply(many, action)
    assert_true(after.error.unwrap().contains("1 MiB"))
    assert_eq(after.reference_shortlist, many.reference_shortlist)
    assert_eq(after.draft, many.draft)
  }
}

///|
extern "js" fn bibtex_export_blob(
  expected : String,
  selected : Bool,
  attempt : Int,
) -> String =
  #|(expected,selected,attempt)=>{
  #| const got=globalThis.__numericDownload,name=selected?'moonfind-selected-references.bib':'moonfind-reading-list.bib';
  #| if(!got.clicked||got.name!==name||!(got.blob instanceof Blob)||got.blob.type!=='application/x-bibtex;charset=utf-8')return 'BibTeX Blob metadata mismatch';
  #| got.blob.arrayBuffer().then(buffer=>{const actual=Buffer.from(buffer);if(!actual.equals(Buffer.from(expected,'utf8')))throw Error('BibTeX Blob bytes mismatch');const dir=process.env.MOONFIND_BIBTEX_EVIDENCE;if(dir){const fs=process.getBuiltinModule('fs'),file=attempt+'-'+name;fs.writeFileSync(dir+'/'+file,actual,{flag:'wx'});fs.writeFileSync(dir+'/'+file+'.receipt.json',JSON.stringify({filename:name,mime:got.blob.type,bytes:got.blob.size,sha256:process.getBuiltinModule('crypto').createHash('sha256').update(actual).digest('hex'),real_blob:true},null,2),{flag:'wx'});}}).catch(error=>{console.error(error);process.exitCode=1;});return '';
  #|}

///|
test "BibTeX production controls and reducer download actual Blob bytes after failure and repeated clicks" {
  let view = shortlist_fixture()
  let model = { ..initial_model(), brief: view, }
  for selected in [false, true] {
    for attempt, mode in ["create", "click", "ok", "ok"] {
      csv_numeric_blob_fixture(mode)
      let after = update(
          _ => @rabbita.none,
          BriefAction(
            ReferenceList(
              if selected {
                Shortlist(ExportBibtex)
              } else {
                ExportBibtex
              },
            ),
          ),
          model,
        ).1.brief
      assert_eq(after.draft, view.draft)
      assert_eq(after.reference_shortlist, view.reference_shortlist)
      assert_eq(after.reference_timeline, view.reference_timeline)
      assert_eq(after.reference_query, view.reference_query)
      if mode == "ok" {
        assert_eq(after.error, None)
        assert_eq(
          bibtex_export_blob(
            if selected {
              reference_shortlist_bibtex(view)
            } else {
              reference_bibtex_export(view)
            },
            selected,
            attempt,
          ),
          "",
        )
      } else {
        assert_true(after.error.unwrap().contains("BibTeX download failed"))
      }
      csv_numeric_blob_restore()
    }
  }
  install_choice_storage("ok")
  defer restore_choice_storage()
  let html = reading_render(view)
  assert_true(html.contains("Download current bibliography BibTeX"))
  assert_true(html.contains("Download selected references BibTeX"))
  assert_true(html.contains("moonfind_provenance_hex"))
  let pending = reading_render({ ..view, pending: true, })
  assert_false(pending.contains("Download current bibliography BibTeX"))
  assert_false(pending.contains("Download selected references BibTeX"))
  let stale = reading_render({
    ..view,
    reference_source_generation: view.reference_source_generation + 1,
  })
  assert_false(stale.contains("Download selected references BibTeX"))
  let invalid = reading_render(reading_apply(view, Timeline(From("bad"))))
  assert_false(invalid.contains("Download current bibliography BibTeX"))
  assert_true(invalid.contains("Download selected references BibTeX"))
  bibtex_export_evidence("controls.html", html)
}

///|
test "BibTeX reopen and source append preserve source bytes while stale picks remain blocked" {
  let view = shortlist_fixture()
  let reopened = update_brief_view(
      _ => @rabbita.none,
      Loaded(
        view.generation,
        view.draft.brief_id,
        "bibtex-revision",
        Ok(brief_fixture_reply(view.draft, "bibtex-revision")),
      ),
      { ..view, pending: true, },
    ).1
  assert_eq(reopened.draft, view.draft)
  assert_eq(reopened.reference_shortlist, [])
  assert_eq(reference_bibtex_export(reopened), reference_bibtex_export(view))
  let appended = {
    ..view,
    draft: {
      ..view.draft,
      sources: view.draft.sources + [view.draft.sources[1]],
    },
  }
  assert_eq(
    reference_shortlist_bibtex(appended),
    reference_shortlist_bibtex(view),
  )
  let removed = update_brief_view(_ => @rabbita.none, RemoveSource(1), view).1
  try reference_shortlist_bibtex(removed) catch {
    _ => ()
  } noraise {
    _ => fail("Changed sources must block")
  }
  assert_eq(view.draft.sources, reopened.draft.sources)
  bibtex_export_evidence("reopened.bib", reference_bibtex_export(reopened))
}
