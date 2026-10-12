///|
fn reading_source(name : String, content : String) -> BriefInputSource {
  {
    name,
    origin: "Synthetic local reading-list fixture: " + name,
    captured_at: "2026-10-09T17:00:00Z",
    kind: "local-file",
    content_hex: brief_text_hex(content),
  }
}

///|
fn reading_pair(
  format : String,
  original : BriefInputSource,
  references : Json,
) -> Json {
  let selection = reading_source(
    format + "-selection.json",
    (
      {
        "contract_id": "moonfind." + format + "-selection.v1",
        "source_name": original.name,
        "source_digest": dossier_test_digest(original.content_hex),
        "references": references,
      } : Json).stringify(indent=2),
  )
  [ToJson::to_json(original), ToJson::to_json(selection)]
}

///|
fn reading_fixture() -> BriefView {
  let bib : BibtexReference = {
    record_number: 1,
    citation_key: "alpha",
    reference_type: "article",
    title: "Contact sensing <script>\"quoted\"\n🌒",
    authors: ["García, Ana"],
    year: "2025",
    venue: "Synthetic Review",
    keywords: "contact",
    doi: "10.1234/Shared",
    url: "javascript:alert(1)",
    abstract_text: "First line\nSecond line <img src=x>",
    availability: "metadata-and-abstract",
  }
  let bibs = [
    bib,
    {
      ..bib,
      record_number: 2,
      citation_key: "alternative",
      title: "Conflicting method",
      doi: " doi: 10.1234/SHARED ",
    },
    {
      ..bib,
      record_number: 3,
      citation_key: "blank",
      title: "",
      doi: "",
      abstract_text: "",
    },
    {
      ..bib,
      record_number: 4,
      citation_key: "broken",
      title: "Malformed DOI lead",
      doi: "not a DOI",
      abstract_text: "",
    },
  ]
  let csl : CslReference = {
    record_number: 1,
    item_id: "9007199254740993",
    item_id_kind: "number",
    citation_key: "alpha",
    reference_type: "article-journal",
    title: "Contact synthesis",
    authors: ["王, 明"],
    editors: ["García, Ana"],
    year: "2026",
    issued: "2026-4-2",
    venue: "Synthetic Journal",
    keywords: "contact",
    doi: "https://doi.org/10.1234/shared",
    url: "https://example.invalid/synthesis",
    abstract_text: "",
    availability: "metadata-only",
  }
  let csls = [
    csl,
    {
      ..csl,
      record_number: 2,
      item_id: "separate",
      item_id_kind: "string",
      title: "Longer DOI is a separate group",
      doi: "10.1234/shared.extra",
    },
    {
      ..csl,
      record_number: 3,
      item_id: "separate-copy",
      item_id_kind: "string",
      title: "Longer DOI second candidate",
      doi: "DOI:10.1234/SHARED.EXTRA",
    },
  ]
  let ris : RisReference = {
    record_number: 1,
    reference_type: "JOUR",
    title: "RIS conflict",
    authors: ["Rivera, Sam"],
    year: "2024",
    doi: "HTTP://DX.DOI.ORG/10.1234/SHARED",
    url: "",
    abstract_text: "Review this conflicting abstract.",
  }
  let riss = [
    ris,
    {
      ..ris,
      record_number: 2,
      title: "No DOI available",
      doi: " ",
      abstract_text: "",
    },
  ]
  // Exact synthetic input captures and host-selection-shaped replies. This
  // exercises production Selected reducers, not native bibliography parsers.
  let bib_original = reading_source(
    "synthetic.bib", "@article{alpha,title={Contact sensing},doi={10.1234/Shared}}\n@article{alternative,title={Conflicting method},doi={doi: 10.1234/SHARED}}\n@misc{blank,title={}}\n@misc{broken,title={Malformed DOI lead},doi={not a DOI}}\n",
  )
  let csl_original = reading_source(
    "synthetic.csl.json",
    csls
    .map(r => {
      (
        {
          "id": r.item_id,
          "type": r.reference_type,
          "title": r.title,
          "DOI": r.doi,
        } : Json)
    })
    .to_json()
    .stringify(indent=2),
  )
  let ris_original = reading_source(
    "synthetic.ris", "TY  - JOUR\nTI  - RIS conflict\nDO  - HTTP://DX.DOI.ORG/10.1234/SHARED\nER  -\nTY  - JOUR\nTI  - No DOI available\nER  -\n",
  )
  let view = {
    ..initial_brief_view(),
    draft: {
      ..brief_fixture_draft(),
      brief_id: "reading-list-synthetic",
      sources: [],
    },
    generation: 1,
    pending: true,
  }
  let view = update_brief_view(
      _ => @rabbita.none,
      Bibtex(
        Selected(1, Ok(reading_pair("bibtex", bib_original, bibs.to_json()))),
      ),
      view,
    ).1
  let view = { ..view, pending: true, }
  let view = update_brief_view(
      _ => @rabbita.none,
      Csl(
        Selected(
          view.generation,
          Ok(reading_pair("csl", csl_original, csls.to_json())),
        ),
      ),
      view,
    ).1
  let view = { ..view, pending: true, }
  update_brief_view(
    _ => @rabbita.none,
    Ris(
      Selected(
        view.generation,
        Ok(reading_pair("ris", ris_original, riss.to_json())),
      ),
    ),
    view,
  ).1
}

///|
fn reading_apply(view : BriefView, message : ReferenceListMsg) -> BriefView {
  update_brief_view(_ => @rabbita.none, ReferenceList(message), view).1
}

///|
fn reading_render(model : BriefView) -> String {
  @rabbita.render_to_string(
    @rabbita.cell(
      model~,
      update=(emit, message, view) => {
        match message {
          BriefAction(action) => update_brief_view(emit, action, view)
          _ => (@rabbita.none, view)
        }
      },
      view=reference_list_panel,
    ),
  )
}

///|
extern "js" fn reading_evidence(name : String, content : String) -> Unit =
  #|(name,content) => {const dir=process.env.MOONFIND_READING_EVIDENCE; if(dir) process.getBuiltinModule('fs').writeFileSync(dir+'/'+name,content);}

///|
test "reading list production selection reducers combine three formats preserving identities" {
  let view = reading_fixture()
  assert_eq(view.draft.sources.length(), 6)
  assert_eq(view.error, None)
  assert_false(view.pending)
  let catalog = reference_catalog(view)
  assert_eq(catalog.issues, [])
  assert_eq(catalog.references.length(), 9)
  assert_eq(catalog.references.map(r => r.source_slot), [
    2, 2, 2, 2, 4, 4, 4, 6, 6,
  ])
  assert_eq(catalog.references.map(r => r.record_number), [
    1, 2, 3, 4, 1, 2, 3, 1, 2,
  ])
  assert_eq(catalog.references[4].item_id, "9007199254740993")
  assert_eq(catalog.references[4].item_id_kind, "number")
  assert_eq(catalog.references[4].editors, ["García, Ana"])
  assert_eq(catalog.references[7].format, "ris")
  assert_eq(catalog.references[2].availability, "metadata-only")
  assert_eq(
    catalog.references[0].citation_key,
    catalog.references[4].citation_key,
  )
  for i in [0, 2, 4] {
    let source = view.draft.sources[i]
    reading_evidence(source.name, brief_source_preview(source.content_hex))
  }
  reading_evidence(
    "selection-inputs.json",
    view.draft.sources.to_json().stringify(indent=2),
  )
  reading_evidence("all-references.json", reference_list_export(view))
}

///|
test "reading DOI candidates conservative normalization missing malformed and exact groups" {
  for
    value in [
      "10.1234/A", " doi: 10.1234/A ", "https://doi.org/10.1234/A", "HTTP://DX.DOI.ORG/10.1234/A",
    ] {
    assert_eq(reference_doi_key(value), "10.1234/a")
  }
  for
    value in [
      "", " ", "10.123/a", "10.1234567890/a", "10.1234/", "10.1234/two words", "https://evil.invalid/10.1234/a",
      "doi:doi:10.1234/a", "10.1234/<a>", "not a DOI",
    ] {
    assert_eq(reference_doi_key(value), "")
  }
  assert_eq(reference_doi_key("10.1234/a%2Fb"), "10.1234/a%2fb")
  assert_eq(reference_doi_key("10.1234/a."), "10.1234/a.")
  let view = reading_apply(reading_fixture(), Duplicates)
  let catalog = reference_catalog(view)
  let counts = reference_doi_counts(catalog)
  assert_eq(counts.get("10.1234/shared"), Some(4))
  assert_eq(counts.get("10.1234/shared.extra"), Some(2))
  assert_eq(reference_matches(view, catalog).length(), 6)
  let group = reading_apply(view, ShowDoi("10.1234/shared"))
  assert_eq(reference_matches(group, catalog).length(), 4)
  assert_true(
    reference_matches(group, catalog).all(r => {
      r.doi_match_key == "10.1234/shared"
    }),
  )
  assert_eq(
    reading_apply(group, ShowDoi("missing")).reference_doi_filter,
    "10.1234/shared",
  )
  reading_evidence("same-doi-candidates.json", reference_list_export(view))
  reading_evidence("exact-doi-group.json", reference_list_export(group))
}

///|
test "reading search and export never widen filters or lose missing metadata" {
  let view = reading_apply(
    reading_apply(reading_fixture(), Duplicates),
    Query("  RIVERA  "),
  )
  let catalog = reference_catalog(view)
  let matches = reference_matches(view, catalog)
  assert_eq(matches.length(), 1)
  assert_eq(matches[0].source_slot, 6)
  let exported = @json.parse(reference_list_export(view))
  assert_true(
    exported
    is {
      "exported_count": Number(1, ..),
      "catalog_count": Number(9, ..),
      "selection_captures": Array([{ "source_slot": Number(6, ..), .. }]),
      "references": Array(
        [
          {
            "source_slot": Number(6, ..),
            "record_number": Number(1, ..),
            "venue": String(""),
            ..
          },
        ]
      ),
      "doi_candidate_counts": Array([{ "catalog_matches": Number(4, ..), .. }]),
      ..
    },
  )
  let text = reference_list_export(view)
  assert_false(text.contains("content_hex"))
  assert_false(text.contains("García"))
  reading_evidence("filtered-reading-list.json", text)
  for
    query in [
      "9007199254740993", "王", "2026-4-2", "synthetic.ris", "SECOND LINE", "javascript:alert(1)",
    ] {
    assert_false(
      reference_matches(reading_apply(reading_fixture(), Query(query)), catalog).is_empty(),
    )
  }
  let empty = reading_apply(view, Query("definitely absent"))
  assert_true(
    @json.parse(reference_list_export(empty))
    is {
      "exported_count": Number(0, ..),
      "references": Array([]),
      "selection_captures": Array([]),
      ..
    },
  )
  assert_eq(reference_matches(reading_apply(view, Clear), catalog).length(), 9)
  reading_evidence("zero-matches.json", reference_list_export(empty))
}

///|
test "reading malformed selections are visible and block incomplete export" {
  let base = reading_fixture()
  for content in ["{}", "{broken", "{\"contract_id\":\"unknown\"}"] {
    let bad = reading_source("bibtex-selection.json", content)
    let view = {
      ..base,
      draft: { ..base.draft, sources: base.draft.sources + [bad], },
    }
    assert_eq(reference_catalog(view).references.length(), 9)
    assert_eq(reference_catalog(view).issues.length(), 1)
    try reference_list_export(view) catch {
      _ => ()
    } noraise {
      _ => fail("Expected invalid selection export to fail")
    }
  }
  let original = base.draft.sources[1]
  for hex in ["f", "zz", "ff", "00".repeat(32769)] {
    let view = {
      ..base,
      draft: { ..base.draft, sources: [{ ..original, content_hex: hex, }], },
    }
    assert_eq(reference_catalog(view).references.length(), 0)
    assert_eq(reference_catalog(view).issues.length(), 1)
  }
  let json = @json.parse(brief_source_preview(original.content_hex))
  guard json is { "references": Array(refs), .. } else { fail("fixture") }
  let duplicate = reading_source(
    "bibtex-selection.json",
    (
      {
        "contract_id": "moonfind.bibtex-selection.v1",
        "source_name": "same.bib",
        "source_digest": "sha256:synthetic",
        "references": [refs[0], refs[0]],
      } : Json).stringify(),
  )
  try reference_selection(duplicate, 1) catch {
    _ => ()
  } noraise {
    _ => fail("Expected repeated record identity to fail")
  }
}

///|
test "reading recomputes after source removal refresh and New with pending guards" {
  let base = reading_apply(reading_fixture(), ShowDoi("10.1234/shared"))
  let pending = { ..base, pending: true, }
  for
    action in [
      Query("changed"),
      Duplicates,
      Clear,
      ShowDoi("10.1234/shared.extra"),
      Export,
    ] {
    let after = reading_apply(pending, action)
    assert_eq(after.reference_query, pending.reference_query)
    assert_eq(after.reference_doi_filter, pending.reference_doi_filter)
    assert_eq(after.reference_duplicates, pending.reference_duplicates)
    assert_eq(after.error, pending.error)
  }
  try reference_list_export(pending) catch {
    _ => ()
  } noraise {
    _ => fail("Expected pending export to fail")
  }
  let removed = update_brief_view(_ => @rabbita.none, RemoveSource(1), base).1
  assert_eq(reference_catalog(removed).references.length(), 5)
  assert_eq(reference_matches(removed, reference_catalog(removed)).length(), 2)
  assert_eq(
    reference_matches(removed, reference_catalog(removed)).map(r => {
      r.source_slot
    }),
    [3, 5],
  )
  let fresh_sources = base.draft.sources.filter(s => {
    s.name == "csl-selection.json"
  })
  let refreshed = { ..base, draft: { ..base.draft, sources: fresh_sources, }, }
  assert_eq(reference_catalog(refreshed).references.length(), 3)
  assert_eq(
    reference_matches(refreshed, reference_catalog(refreshed)).length(),
    0,
  )
  let cleared = update_brief_view(_ => @rabbita.none, New, pending).1
  assert_eq(reference_catalog(cleared).references.length(), 0)
  assert_eq(cleared.reference_query, "")
  assert_eq(cleared.reference_doi_filter, "")
  assert_false(cleared.reference_duplicates)
  let stale = update_brief_view(
      _ => @rabbita.none,
      Bibtex(Selected(base.generation, Ok(fresh_sources.to_json()))),
      cleared,
    ).1
  assert_eq(reference_catalog(stale).references.length(), 0)
}

///|
test "reading prepared reopen projection export revision and changed draft identity" {
  let base = reading_fixture()
  let revision = "synthetic-reading-revision"
  let snapshot : BriefSnapshot = {
    contract_id: "moonfind.brief-snapshot.v1",
    revision_id: revision,
    state: "prepared",
    brief: base.draft,
    sources: base.draft.sources.mapi((i, source) => {
      slot: i + 1,
      name: source.name,
      origin: source.origin,
      captured_at: source.captured_at,
      kind: source.kind,
      availability: "retained-local-capture",
      archive_path: "sources/source-\{i + 1}",
      byte_count: source.content_hex.length() / 2,
      digest: dossier_test_digest(source.content_hex),
    }),
    boundary: "Synthetic saved-state fixture; native persistence is not exercised.",
  }
  let reply : Json = {
    "contract_id": "moonfind.brief-status.v1",
    "brief_id": base.draft.brief_id,
    "revision_id": revision,
    "state": "prepared",
    "issues": [],
    "snapshot": ToJson::to_json(snapshot),
  }
  let reopened = update_brief_view(
      _ => @rabbita.none,
      Loaded(10, base.draft.brief_id, "synthetic-reading-revision", Ok(reply)),
      { ..initial_brief_view(), generation: 10, pending: true, },
    ).1
  assert_eq(reopened.error, None)
  assert_eq(reference_catalog(reopened).references.length(), 9)
  reading_evidence(
    "reopened-reading-list.json",
    reference_list_export(reopened),
  )
  assert_true(
    @json.parse(reference_list_export(reopened))
    is { "revision_id": String("synthetic-reading-revision"), .. },
  )
  let edited = update_brief_view(
      _ => @rabbita.none,
      Edit("question", "Changed"),
      reopened,
    ).1
  assert_true(
    @json.parse(reference_list_export(edited)) is { "revision_id": Null, .. },
  )
  assert_eq(reference_catalog(edited).references.length(), 9)
}

///|
test "reading actual compiled UI escapes fields and projects filter and provenance" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let base = reading_fixture()
  let html = reading_render(base)
  assert_true(html.contains("Unified bibliography reading list"))
  assert_true(html.contains("&lt;script&gt;"))
  assert_true(html.contains("&lt;img src=x&gt;"))
  assert_false(html.contains("<script>"))
  assert_false(html.contains("href=\"javascript:"))
  assert_true(html.contains("(Untitled reference)"))
  assert_true(html.contains("Source slot 6"))
  assert_true(html.contains("Inspect 4 same-DOI candidates"))
  let filtered = reading_apply(
    reading_apply(base, ShowDoi("10.1234/shared")),
    Query("Rivera"),
  )
  let filtered_html = reading_render(filtered)
  assert_true(filtered_html.contains("1 matching references of 9"))
  assert_false(filtered_html.contains("Contact synthesis"))
  assert_true(filtered_html.contains("Exact DOI group: 10.1234/shared"))
  assert_true(
    qa_test_render({ ..initial_model(), brief: base, }).contains(
      "Unified bibliography reading list",
    ),
  )
  reading_evidence("reading-list.html", html)
  reading_evidence("filtered-reading-list.html", filtered_html)
}

///|
test "reading real Blob download exact filtered bytes failure and retry" {
  for failed in [true, false] {
    experiment_download_fixture(failed)
    defer experiment_download_restore()
    let view = reading_apply(reading_fixture(), Query("9007199254740993"))
    let after = reading_apply(view, Export)
    assert_eq(after.draft, view.draft)
    assert_eq(after.reference_query, view.reference_query)
    if failed {
      assert_true(after.error.unwrap().contains("download failed"))
    } else {
      assert_eq(after.error, None)
      guard @json.parse(experiment_download_readback())
        is {
          "name": String("moonfind-reference-reading-list.json"),
          "clicked": True,
          "content": String(content),
          ..
        } else {
        fail("download missing")
      }
      assert_eq(content, reference_list_export(view))
      assert_true(
        @json.parse(content) is { "exported_count": Number(1, ..), .. },
      )
      reading_evidence("downloaded-reading-list.json", content)
    }
  }
}

///|
test "reading identical filenames and repeated captures keep distinct source slots" {
  let base = reading_fixture()
  let view = {
    ..base,
    draft: {
      ..base.draft,
      sources: base.draft.sources + [base.draft.sources[1]],
    },
  }
  let catalog = reference_catalog(view)
  assert_eq(catalog.references.length(), 13)
  assert_eq(catalog.references[9].source_slot, 7)
  assert_eq(
    catalog.references[9].source_name,
    catalog.references[0].source_name,
  )
  assert_eq(
    catalog.references[9].source_digest,
    catalog.references[0].source_digest,
  )
  assert_eq(reference_doi_counts(catalog).get("10.1234/shared"), Some(6))
  let filtered = reading_apply(view, Query("Conflicting method"))
  assert_eq(reference_matches(filtered, catalog).map(r => r.source_slot), [2, 7])
  assert_true(
    @json.parse(reference_list_export(filtered))
    is {
      "exported_count": Number(2, ..),
      "selection_captures": Array(
        [
          { "source_slot": Number(2, ..), .. },
          { "source_slot": Number(7, ..), .. },
        ]
      ),
      ..
    },
  )
}

///|
test "reading DOI controls exclude all C1 values and preserve adjacent noncontrols" {
  for
    control in "\u007f\u0080\u0081\u0082\u0083\u0084\u0085\u0086\u0087\u0088\u0089\u008a\u008b\u008c\u008d\u008e\u008f\u0090\u0091\u0092\u0093\u0094\u0095\u0096\u0097\u0098\u0099\u009a\u009b\u009c\u009d\u009e\u009f" {
    assert_eq(reference_doi_key("10.98765/a" + control.to_string() + "b"), "")
  }
  for
    malformed in ["10.98765/a\u0000b", "10.98765/a\u001fb", "10.98765/a\u00a0b"] {
    assert_eq(reference_doi_key(malformed), "")
  }
  for allowed in ["10.98765/a~b", "10.98765/a¡b"] {
    assert_eq(reference_doi_key(allowed), allowed)
  }
  assert_eq(
    reference_doi_key("  HTTPS://DOI.ORG/10.98765/AB?X=1  "),
    "10.98765/ab?x=1",
  )
  assert_eq(reference_doi_key("10.98765/a%2Fb"), "10.98765/a%2fb")
  let base = reading_fixture()
  let original = base.draft.sources[0]
  let selection : BibtexSelection = @json.from_json(
    @json.parse(reference_capture_text(base.draft.sources[1].content_hex)),
  )
  let malformed = "10.98765/a\u0080b"
  let refs = [
    { ..selection.references[0], doi: malformed, },
    { ..selection.references[1], doi: malformed, },
  ]
  let sources : Array[BriefInputSource] = @json.from_json(
    reading_pair("bibtex", original, refs.to_json()),
  )
  let view = { ..base, draft: { ..base.draft, sources, }, }
  let catalog = reference_catalog(view)
  assert_eq(catalog.references.length(), 2)
  assert_true(
    catalog.references.all(r => r.doi == malformed && r.doi_match_key == ""),
  )
  assert_eq(reference_doi_counts(catalog).length(), 0)
  assert_eq(reference_matches(reading_apply(view, Duplicates), catalog), [])
  assert_true(
    @json.parse(reference_list_export(view))
    is {
      "exported_count": Number(2, ..),
      "doi_candidate_counts": Array([]),
      ..
    },
  )
  reading_evidence("c1-control-reading-list.json", reference_list_export(view))
}
