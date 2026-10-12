///|
extern "js" fn csl_export_evidence(name : String, content : String) -> Unit =
  #|(name,content)=>{const dir=process.env.MOONFIND_CSL_EXPORT_EVIDENCE;if(dir)process.getBuiltinModule('fs').writeFileSync(dir+'/'+name,content);}

///|
fn csl_export_items(text : String) -> Array[Map[String, Json]] raise {
  @json.from_json(@json.parse(text))
}

///|
test "CSL export mixed bibliography preserves citation fields and exact custom provenance" {
  let view = reading_fixture()
  let output = reference_csl_export(view)
  let items = csl_export_items(output)
  assert_eq(items.length(), 9)
  assert_eq(items[0]["id"], Json::string("moonfind-slot-2-record-1"))
  assert_eq(items[0]["citation-key"], items[0]["id"])
  assert_eq(items[0]["type"], Json::string("article-journal"))
  assert_eq(
    items[0]["title"],
    Json::string("Contact sensing <script>\"quoted\"\n🌒"),
  )
  assert_eq(items[0]["author"], ([{ "literal": "García, Ana" }] : Json))
  assert_eq(items[0]["issued"], ({ "date-parts": [[2025]] } : Json))
  assert_eq(items[0]["DOI"], Json::string("10.1234/Shared"))
  assert_false(items[0].contains("URL"))
  assert_eq(
    items[0]["abstract"],
    Json::string("First line\nSecond line <img src=x>"),
  )
  assert_false(items[2].contains("title"))
  assert_false(items[2].contains("abstract"))
  assert_false(items[3].contains("DOI"))
  assert_eq(items[4]["editor"], ([{ "literal": "García, Ana" }] : Json))
  assert_eq(items[4]["issued"], ({ "date-parts": [[2026, 4, 2]] } : Json))
  assert_eq(items[4]["URL"], Json::string("https://example.invalid/synthesis"))
  let references = reference_catalog(view).references
  for i, item in items {
    guard item["custom"]
      is {
        "moonfind": {
          "contract_id": String("moonfind.reference-csl-export.v1"),
          "export_scope": String("current-matches"),
          "reference": reference,
          "capture_origin": String(origin),
          "captured_at": String(captured_at),
          ..
        },
        ..
      } else {
      fail("Missing original metadata")
    }
    assert_eq(reference, ToJson::to_json(references[i]))
    assert_eq(origin, view.draft.sources[references[i].source_slot - 1].origin)
    assert_eq(
      captured_at,
      view.draft.sources[references[i].source_slot - 1].captured_at,
    )
  }
  assert_true(output.contains("9007199254740993"))
  assert_false(output.contains("content_hex"))
  csl_export_evidence("all-references.csl.json", output)
  csl_export_evidence(
    "source-captures.json",
    view.draft.sources.to_json().stringify(indent=2),
  )
  csl_export_evidence(
    "reference-catalog.json",
    references.to_json().stringify(indent=2),
  )
}

///|
test "CSL export current filters shortlist order and duplicate source IDs stay distinct" {
  let base = reading_fixture()
  let group = reading_apply(base, ShowDoi("10.1234/shared"))
  let group_output = reference_csl_export(group)
  assert_eq(csl_export_items(group_output).length(), 4)
  let narrowed = reading_apply(group, Query("Rivera"))
  let current = reference_csl_export(narrowed)
  assert_eq(csl_export_items(current).length(), 1)
  assert_false(current.contains("García"))
  let selected = shortlist_fixture()
  let shortlist = reference_shortlist_csl(selected)
  let choices = csl_export_items(shortlist)
  assert_eq(
    choices.map(item => item["id"]),
    (
      [
        "moonfind-slot-2-record-2", "moonfind-slot-6-record-2", "moonfind-slot-4-record-1",
      ] : Array[Json]),
  )
  assert_eq(
    reference_shortlist_csl(reading_apply(selected, Query("nothing"))),
    shortlist,
  )
  assert_false(shortlist.contains("RIS conflict"))
  let repeated = {
    ..base,
    draft: {
      ..base.draft,
      sources: base.draft.sources + [base.draft.sources[1]],
    },
  }
  let copies = csl_export_items(
    reference_csl_export(reading_apply(repeated, Query("Conflicting method"))),
  )
  assert_eq(
    copies.map(item => item["id"]),
    (["moonfind-slot-2-record-2", "moonfind-slot-7-record-2"] : Array[Json]),
  )
  csl_export_evidence("same-doi.csl.json", group_output)
  csl_export_evidence("current-match.csl.json", current)
  csl_export_evidence("shortlist.csl.json", shortlist)
}

///|
test "CSL export mapping and dates retain unsupported text without inferred precision" {
  let r = reference_catalog(reading_fixture()).references[0]
  for
    (format, kind, expected) in [
      ("bibtex", "book", "book"),
      ("bibtex", "incollection", "chapter"),
      ("bibtex", "inproceedings", "paper-conference"),
      ("bibtex", "phdthesis", "thesis"),
      ("bibtex", "techreport", "report"),
      ("bibtex", "unpublished", "manuscript"),
      ("bibtex", "proceedings", "article"),
      ("bibtex", "unknown", "article"),
      ("ris", "ELEC", "webpage"),
      ("ris", "NEWS", "article-newspaper"),
      ("ris", "MGZN", "article-magazine"),
      ("ris", "DATA", "dataset"),
      ("ris", "UNPB", "manuscript"),
      ("ris", "UNKNOWN", "article"),
      ("csl", "software", "software"),
      ("csl", "legal_case", "legal_case"),
      ("csl", "post-weblog", "post-weblog"),
      ("csl", "unknown", "article"),
    ] {
    assert_eq(
      reference_csl_type({ ..r, format, reference_type: kind, }),
      expected,
    )
  }
  for
    (raw, expected) in [
      ("2025", ({ "date-parts": [[2025]] } : Json)),
      ("2025-6", ({ "date-parts": [[2025, 6]] } : Json)),
      ("2024-02-29", ({ "date-parts": [[2024, 2, 29]] } : Json)),
      ("2000-2-29", ({ "date-parts": [[2000, 2, 29]] } : Json)),
      (
        "2025-6-1 / 2025-7-2",
        ({ "date-parts": [[2025, 6, 1], [2025, 7, 2]] } : Json),
      ),
    ] {
    assert_eq(@json.parse(reference_csl_date_json(raw)), expected)
  }
  for
    raw in [
      "forthcoming", "2025/07", "2025~", "2025-13", "2025-2-29", "1900-2-29", "2025-4-31",
      "0000", "20250", "2025 / forthcoming",
    ] {
    assert_eq(
      @json.parse(reference_csl_date_json(raw)),
      ({ "literal": raw } : Json),
    )
  }
}

///|
test "CSL export literal names hostile strings and unmodeled fields remain reviewable" {
  let view = reading_fixture()
  let r = reference_catalog(view).references[0]
  let hostile = "Title\r\n\u0000</script>\"}],[{\"id\":\"injected\u2028🌘"
  let changed = {
    ..r,
    title: hostile,
    authors: [
      "", "  ", "Research and Development Group", "van Beethoven, Ludwig, Jr.",
    ],
    editors: [" ", "王, 明"],
    issued: "forthcoming",
    reference_type: "custom-kind",
    url: "file:///private",
    doi: "not-a-doi",
    doi_match_key: "",
  }
  let output = reference_csl_records(view, [changed], "current-matches")
  let items = csl_export_items(output)
  assert_eq(items.length(), 1)
  assert_eq(items[0]["title"], Json::string(hostile))
  assert_eq(
    items[0]["author"],
    (
      [
        { "literal": "Research and Development Group" },
        { "literal": "van Beethoven, Ludwig, Jr." },
      ] : Json),
  )
  assert_eq(items[0]["editor"], ([{ "literal": "王, 明" }] : Json))
  assert_eq(items[0]["issued"], ({ "literal": "forthcoming" } : Json))
  assert_eq(items[0]["type"], Json::string("article"))
  assert_false(items[0].contains("URL"))
  assert_false(items[0].contains("DOI"))
  guard items[0]["custom"] is { "moonfind": { "reference": original, .. }, .. } else {
    fail("No source reference")
  }
  assert_eq(original, ToJson::to_json(changed))
  csl_export_evidence("literal-metadata.csl.json", output)
}

///|
test "CSL export empty unreadable pending stale and oversized views refuse without mutation" {
  let base = reading_fixture()
  let invalid = {
    ..base,
    draft: {
      ..base.draft,
      sources: base.draft.sources + [reading_source("csl-selection.json", "{}")],
    },
  }
  for
    view in [
      reading_apply(base, Query("not found")),
      { ..base, pending: true, },
      invalid,
    ] {
    try reference_csl_export(view) catch {
      _ => ()
    } noraise {
      _ => fail("Expected current export refusal")
    }
    let after = reading_apply(view, ExportCsl)
    assert_eq(after.draft, view.draft)
    assert_eq(after.reference_query, view.reference_query)
    assert_eq(after.reference_shortlist, view.reference_shortlist)
    if !view.pending {
      assert_true(after.error is Some(_))
    }
  }
  let selected = shortlist_fixture()
  let stale = {
    ..selected,
    reference_source_generation: selected.reference_source_generation + 1,
  }
  for
    view in [
      base,
      { ..selected, pending: true, },
      stale,
      { ..invalid, reference_shortlist: selected.reference_shortlist, },
    ] {
    try reference_shortlist_csl(view) catch {
      _ => ()
    } noraise {
      _ => fail("Expected shortlist refusal")
    }
    let after = reading_apply(view, Shortlist(ExportCsl))
    assert_eq(after.draft, view.draft)
    assert_eq(after.reference_shortlist, view.reference_shortlist)
  }
  let repeated = {
    ..base,
    draft: { ..base.draft, sources: Array::make(500, base.draft.sources[1]), },
  }
  try reference_csl_export(repeated) catch {
    _ => ()
  } noraise {
    _ => fail("Expected size refusal")
  }
  let huge = {
    ..base,
    reference_shortlist: reference_catalog(repeated).references.map(r => {
      reference_choice(repeated, r)
    }),
    draft: repeated.draft,
  }
  try reference_shortlist_csl(huge) catch {
    _ => ()
  } noraise {
    _ => fail("Expected shortlist size refusal")
  }
}

///|
extern "js" fn csl_export_blob(expected : String, selected : Bool) -> String =
  #|(expected,selected)=>{
  #| const got=globalThis.__numericDownload,name=selected?'moonfind-selected-references.csl.json':'moonfind-reading-list.csl.json';
  #| if(!got.clicked||got.name!==name||!(got.blob instanceof Blob)||got.blob.type!=='application/vnd.citationstyles.csl+json;charset=utf-8')return 'CSL Blob metadata mismatch';
  #| got.blob.text().then(text=>{if(text!==expected)throw Error('CSL Blob bytes mismatch');const dir=process.env.MOONFIND_CSL_EXPORT_EVIDENCE;if(dir){const fs=process.getBuiltinModule('fs');fs.writeFileSync(dir+'/'+name,text);fs.writeFileSync(dir+'/'+name+'.receipt.json',JSON.stringify({filename:name,mime:got.blob.type,bytes:got.blob.size,sha256:process.getBuiltinModule('crypto').createHash('sha256').update(text).digest('hex'),real_blob:true},null,2));}}).catch(error=>{console.error(error);process.exitCode=1;});return '';
  #|}

///|
test "CSL export UI current and hidden shortlist downloads real Blob bytes after retry" {
  let view = shortlist_fixture()
  let model = { ..initial_model(), brief: view, }
  for selected in [false, true] {
    for mode in ["create", "click", "ok", "ok"] {
      csv_numeric_blob_fixture(mode)
      let after = update(
          _ => @rabbita.none,
          BriefAction(
            ReferenceList(
              if selected {
                Shortlist(ExportCsl)
              } else {
                ExportCsl
              },
            ),
          ),
          model,
        ).1.brief
      assert_eq(after.draft, view.draft)
      assert_eq(after.reference_query, view.reference_query)
      assert_eq(after.reference_doi_filter, view.reference_doi_filter)
      assert_eq(after.reference_shortlist, view.reference_shortlist)
      if mode == "ok" {
        assert_eq(after.error, None)
        assert_eq(
          csl_export_blob(
            if selected {
              reference_shortlist_csl(view)
            } else {
              reference_csl_export(view)
            },
            selected,
          ),
          "",
        )
      } else {
        assert_true(after.error.unwrap().contains("CSL JSON download failed"))
      }
      csv_numeric_blob_restore()
    }
  }
  install_choice_storage("ok")
  defer restore_choice_storage()
  let html = reading_render(view)
  for
    label in [
      "Download current bibliography CSL JSON", "Download selected references CSL JSON",
      "custom.moonfind",
    ] {
    assert_true(html.contains(label))
  }
  assert_false(
    reading_render({ ..view, pending: true, }).contains(
      "Download current bibliography CSL JSON",
    ),
  )
  assert_false(
    reading_render({ ..view, pending: true, }).contains(
      "Download selected references CSL JSON",
    ),
  )
  let stale = {
    ..view,
    reference_source_generation: view.reference_source_generation + 1,
  }
  assert_false(
    reading_render(stale).contains("Download selected references CSL JSON"),
  )
  assert_eq(
    reading_apply({ ..view, pending: true, }, ExportCsl).error,
    view.error,
  )
  assert_eq(
    reading_apply({ ..view, pending: true, }, Shortlist(ExportCsl)).error,
    view.error,
  )
  let all_html = reading_render(reading_fixture())
  assert_true(all_html.contains("&lt;script&gt;"))
  assert_false(all_html.contains("<script>"))
  csl_export_evidence("rendered-csl-library.html", all_html)
  csl_export_evidence("rendered-csl-export.html", html)
}
