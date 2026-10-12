///|
extern "js" fn timeline_evidence(name : String, content : String) -> Unit =
  #|(name,content)=>{const dir=process.env.MOONFIND_TIMELINE_EVIDENCE;if(dir)process.getBuiltinModule('fs').writeFileSync(dir+'/'+name,content);}

///|
// The existing fixture exercises all three real selection reducers. Change
// only synthetic supplied dates, retaining original source identities.
fn timeline_fixture() -> BriefView raise {
  let view = reading_fixture()
  let sources = view.draft.sources.map(source => {
    let content = match source.name {
      "bibtex-selection.json" => {
        let selection : BibtexSelection = @json.from_json(
          @json.parse(reference_capture_text(source.content_hex)),
        )
        (
          {
            "contract_id": selection.contract_id,
            "source_name": selection.source_name,
            "source_digest": selection.source_digest,
            "references": selection.references
            .mapi((i, r) => {
              ..r,
              year: ["2025", "forthcoming", "2024", "2020 / 2022"][i],
            })
            .to_json(),
          } : Json).stringify()
      }
      "csl-selection.json" => {
        let selection : CslSelection = @json.from_json(
          @json.parse(reference_capture_text(source.content_hex)),
        )
        (
          {
            "contract_id": selection.contract_id,
            "source_name": selection.source_name,
            "source_digest": selection.source_digest,
            "references": selection.references
            .mapi((i, r) => {
              ..r,
              issued: ["2026-4-2", "2025-2-29", " 2025-12 "][i],
            })
            .to_json(),
          } : Json).stringify()
      }
      "ris-selection.json" => {
        let selection : RisSelection = @json.from_json(
          @json.parse(reference_capture_text(source.content_hex)),
        )
        (
          {
            "contract_id": selection.contract_id,
            "source_name": selection.source_name,
            "source_digest": selection.source_digest,
            "references": selection.references
            .mapi((i, r) => { ..r, year: ["2024", ""][i], })
            .to_json(),
          } : Json).stringify()
      }
      _ => return source
    }
    { ..source, content_hex: brief_text_hex(content), }
  })
  { ..view, draft: { ..view.draft, sources, }, }
}

///|
fn timeline_ids(view : BriefView) -> Array[String] {
  reference_matches(view, reference_catalog(view)).map(r => {
    "\{r.source_slot}:\{r.record_number}"
  })
}

///|
test "timeline recognizes only unambiguous calendar dates and four digit bounds" {
  for
    (text, year) in [
      ("2025", 2025),
      (" 2026-4-2 ", 2026),
      ("2024-02-29", 2024),
      ("2000-2-29", 2000),
      ("0001", 1),
      ("9999-12-31", 9999),
    ] {
    assert_eq(reference_publication_year(text), Some(year))
  }
  for
    text in [
      "", " ", "forthcoming", "2025?", "2024/02/29", "2025-2-29", "1900-2-29", "2025-13",
      "2025-4-31", "0000", "20250", "2020 / 2022", "2025 / 2025", "spring 2025",
      "２０２５",
    ] {
    assert_eq(reference_publication_year(text), None)
  }
  assert_eq(reference_year_bound(" 2025 "), Some(2025))
  for
    text in [
      "", "0000", "20", "2e03", "2025.0", "-100", "2025-01", "２０２５",
    ] {
    assert_eq(reference_year_bound(text), None)
  }
}

///|
test "timeline filters mixed dates inclusively and sorts stably without editing captures" {
  let base = timeline_fixture()
  let source_ids = timeline_ids(base)
  let newest = reading_apply(base, Timeline(Order("newest")))
  assert_eq(timeline_ids(newest), [
    "4:1", "2:1", "4:3", "2:3", "6:1", "2:2", "2:4", "4:2", "6:2",
  ])
  let oldest = reading_apply(base, Timeline(Order("oldest")))
  assert_eq(timeline_ids(oldest), [
    "2:3", "6:1", "2:1", "4:3", "4:1", "2:2", "2:4", "4:2", "6:2",
  ])
  assert_eq(timeline_ids(base), source_ids)
  assert_eq(newest.draft, base.draft)
  let range = reading_apply(
    reading_apply(newest, Timeline(From("2024"))),
    Timeline(Through("2025")),
  )
  assert_eq(timeline_ids(range), ["2:1", "4:3", "2:3", "6:1"])
  let exact = reading_apply(range, Timeline(From("2025")))
  assert_eq(timeline_ids(exact), ["2:1", "4:3"])
  assert_eq(timeline_ids(reading_apply(exact, Timeline(Through("")))), [
    "4:1", "2:1", "4:3",
  ])
  assert_eq(timeline_ids(reading_apply(range, Timeline(From("")))), [
    "2:1", "4:3", "2:3", "6:1",
  ])
  assert_eq(
    timeline_ids(reading_apply(range, Timeline(Scope("unclassified")))),
    ["2:2", "2:4", "4:2", "6:2"],
  )
  assert_eq(
    timeline_ids(reading_apply(range, Timeline(Scope("all")))),
    timeline_ids(newest),
  )
  timeline_evidence(
    "catalog.json",
    reference_catalog(base).references.to_json().stringify(indent=2),
  )
  timeline_evidence(
    "captures.json",
    base.draft.sources.to_json().stringify(indent=2),
  )
  timeline_evidence("range.json", reference_list_export(range))
  timeline_evidence(
    "unclassified.json",
    reference_list_export(reading_apply(range, Timeline(Scope("unclassified")))),
  )
}

///|
test "timeline current exports share date scope and order while shortlist preserves choices" {
  let base = timeline_fixture()
  let references = reference_catalog(base).references
  let chosen = reading_apply(
    reading_apply(
      base,
      Shortlist(Toggle(reference_choice(base, references[1]))),
    ),
    Shortlist(Toggle(reference_choice(base, references[4]))),
  )
  let range = reading_apply(
    reading_apply(
      reading_apply(chosen, Timeline(From("2024"))),
      Timeline(Through("2025")),
    ),
    Timeline(Order("newest")),
  )
  let json = reference_list_export(range)
  assert_true(
    @json.parse(json)
    is {
      "publication_year_scope": String("years"),
      "from_year": String("2024"),
      "through_year": String("2025"),
      "reference_order": String("newest"),
      "exported_count": Number(4, ..),
      ..
    },
  )
  let csl = reference_csl_export(range)
  assert_eq(
    csl_export_items(csl).map(item => item["id"]),
    (
      [
        "moonfind-slot-2-record-1", "moonfind-slot-4-record-3", "moonfind-slot-2-record-3",
        "moonfind-slot-6-record-1",
      ] : Array[Json]),
  )
  let ris = reference_ris_export(range)
  assert_eq(
    ris,
    reference_ris_records(
      range,
      reference_matches(range, reference_catalog(range)),
    ),
  )
  assert_eq(reference_shortlist_csl(range), reference_shortlist_csl(chosen))
  assert_eq(reference_shortlist_records(range).map(r => r.issued), [
    "forthcoming", "2026-4-2",
  ])
  assert_eq(range.reference_shortlist, chosen.reference_shortlist)
  timeline_evidence("range.csl.json", csl)
  timeline_evidence("range.ris", ris)
  timeline_evidence("hidden-shortlist.csl.json", reference_shortlist_csl(range))
  let searched = reading_apply(range, Query("Rivera"))
  assert_eq(timeline_ids(searched), ["6:1"])
  let doi = reading_apply(range, ShowDoi("10.1234/shared"))
  assert_eq(doi.reference_timeline, initial_reference_timeline())
  assert_eq(timeline_ids(doi), ["2:1", "2:2", "4:1", "6:1"])
  let dated_doi = reading_apply(doi, Timeline(Through("2025")))
  assert_eq(timeline_ids(dated_doi), ["2:1", "6:1"])
  assert_eq(
    reference_doi_counts(reference_catalog(dated_doi))["10.1234/shared"],
    4,
  )
}

///|
test "timeline invalid bounds stay editable and cannot masquerade as an empty export" {
  let base = timeline_fixture()
  for
    (from, through) in [
      ("2026", "2024"),
      ("bad", ""),
      ("", "2025-12"),
      ("0000", "9999"),
    ] {
    let invalid = reading_apply(
      reading_apply(base, Timeline(From(from))),
      Timeline(Through(through)),
    )
    assert_true(
      reference_timeline_problem(invalid.reference_timeline) is Some(_),
    )
    assert_eq(timeline_ids(invalid), [])
    for action in ([Export, ExportRis, ExportCsl] : Array[ReferenceListMsg]) {
      let failed = reading_apply(invalid, action)
      assert_true(failed.error is Some(_))
      assert_eq(failed.draft, base.draft)
      assert_eq(failed.reference_timeline, invalid.reference_timeline)
    }
    assert_eq(
      timeline_ids(reading_apply(invalid, Timeline(Scope("all")))),
      timeline_ids(base),
    )
    assert_eq(timeline_ids(reading_apply(invalid, Clear)), timeline_ids(base))
  }
  let empty = reading_apply(base, Timeline(From("9999")))
  assert_eq(timeline_ids(empty), [])
  assert_true(
    @json.parse(reference_list_export(empty))
    is { "exported_count": Number(0, ..), .. },
  )
}

///|
test "timeline pending reset source removal and reopen follow current brief state" {
  let base = reading_apply(timeline_fixture(), Timeline(From("2025")))
  let pending = { ..base, pending: true, }
  for
    action in [
      Timeline(From("2020")),
      Timeline(Through("2024")),
      Timeline(Scope("unclassified")),
      Timeline(Order("newest")),
      Clear,
    ] {
    assert_eq(
      reading_apply(pending, action).reference_timeline,
      base.reference_timeline,
    )
  }
  assert_eq(
    reading_apply(base, Timeline(Order("unexpected"))).reference_timeline,
    base.reference_timeline,
  )
  let removed = update_brief_view(_ => @rabbita.none, RemoveSource(1), base).1
  assert_eq(timeline_ids(removed), ["3:1", "3:3"])
  assert_eq(removed.reference_timeline, base.reference_timeline)
  let fresh = update_brief_view(_ => @rabbita.none, New, pending).1
  assert_eq(fresh.reference_timeline, initial_reference_timeline())
  let reopened = update_brief_view(
      _ => @rabbita.none,
      Loaded(
        base.generation,
        base.draft.brief_id,
        "timeline-revision",
        Ok(brief_fixture_reply(base.draft, "timeline-revision")),
      ),
      pending,
    ).1
  assert_eq(reopened.reference_timeline, base.reference_timeline)
  assert_eq(timeline_ids(reopened), timeline_ids(base))
}

///|
test "timeline rendered controls disclose scope and real Blob downloads retain visible order" {
  let base = timeline_fixture()
  let view = reading_apply(
    reading_apply(base, Timeline(From("2024"))),
    Timeline(Order("newest")),
  )
  install_choice_storage("ok")
  let html = reading_render(view)
  restore_choice_storage()
  assert_true(
    html.contains(
      "5 references with recognized years and 4 with unclassified dates",
    ),
  )
  assert_true(html.contains("From year (inclusive)"))
  assert_true(html.contains("Through year (inclusive)"))
  assert_true(html.contains("Newest publication year first"))
  assert_true(html.contains("&lt;script&gt;"))
  assert_false(html.contains("<script>"))
  timeline_evidence("timeline.html", html)
  let invalid = reading_apply(view, Timeline(Through("2020")))
  install_choice_storage("ok")
  let invalid_html = reading_render(invalid)
  restore_choice_storage()
  assert_true(invalid_html.contains("must not be later"))
  assert_false(invalid_html.contains("Download current reading list JSON"))
  timeline_evidence("invalid-range.html", invalid_html)
  for mode in ["create", "click", "ok", "ok"] {
    csv_numeric_blob_fixture(mode)
    let after = reading_apply(view, ExportCsl)
    if mode == "ok" {
      assert_eq(after.error, None)
      assert_eq(csl_export_blob(reference_csl_export(view), false), "")
    } else {
      assert_true(after.error.unwrap().contains("download failed"))
    }
    assert_eq(after.reference_timeline, view.reference_timeline)
    assert_eq(after.draft, view.draft)
    csv_numeric_blob_restore()
  }
}
