///|
// Independent line-level RIS reader for assertions, deliberately not using the
// writer. It rejects orphan fields, injected boundaries and multiline notes.
fn ris_export_records(text : String) -> Array[Map[String, Array[String]]] raise {
  let result : Array[Map[String, Array[String]]] = []
  let mut active : Map[String, Array[String]]? = None
  for raw in text.split("\r\n") {
    let line = raw.to_owned()
    if line.is_empty() {
      continue
    }
    guard line.length() >= 5 && line[2:5] == "  -" else {
      fail("Malformed RIS line")
    }
    let tag = line[:2].to_owned()
    let value = line[5:].trim_start().to_owned()
    if tag == "TY" {
      guard active is None else { fail("Nested TY") }
      active = Some({ "TY": [value] })
    } else {
      guard active is Some(record) else { fail("Orphan RIS field") }
      if tag == "ER" {
        assert_eq(value, "")
        result.push(record)
        active = None
      } else {
        let values = record.get(tag).unwrap_or([])
        record[tag] = values + [value]
      }
    }
  }
  guard active is None else { fail("Missing ER") }
  result
}

///|
test "RIS export combines selected formats with portable fields and exact provenance notes" {
  let view = reading_fixture()
  let output = reference_ris_export(view)
  let records = ris_export_records(output)
  assert_eq(records.length(), 9)
  assert_eq(records[0]["TY"], ["JOUR"])
  assert_eq(records[0]["AU"], ["García, Ana"])
  assert_eq(records[0]["TI"], ["Contact sensing <script>\"quoted\" 🌒"])
  assert_eq(records[0]["AB"], ["First line Second line <img src=x>"])
  assert_eq(records[0]["DO"], ["10.1234/Shared"])
  assert_false(records[0].contains("UR"))
  assert_false(records[2].contains("TI"))
  assert_false(records[2].contains("AB"))
  assert_false(records[3].contains("DO"))
  assert_eq(records[4]["ED"], ["García, Ana"])
  assert_eq(records[4]["PY"], ["2026"])
  assert_eq(records[4]["UR"], ["https://example.invalid/synthesis"])
  assert_eq(records[7]["ID"], ["moonfind-slot-6-record-1"])
  for i, record in records {
    let note = @json.parse(record["N1"][0])
    guard note is { "reference": reference, .. } else {
      fail("No reference note")
    }
    assert_eq(reference, ToJson::to_json(reference_catalog(view).references[i]))
    assert_true(
      note
      is {
        "contract_id": String("moonfind.reference-ris-note.v1"),
        "brief_id": String("reading-list-synthetic"),
        ..
      },
    )
  }
  reading_evidence("bibliography.ris", output)
  reading_evidence(
    "ris-selection-inputs.json",
    view.draft.sources.to_json().stringify(indent=2),
  )
}

///|
test "RIS export respects search exact DOI scope and repeated source identities" {
  let base = reading_fixture()
  let group = reading_apply(base, ShowDoi("10.1234/shared"))
  assert_eq(ris_export_records(reference_ris_export(group)).length(), 4)
  let filtered = reading_apply(group, Query("Rivera"))
  let output = reference_ris_export(filtered)
  let records = ris_export_records(output)
  assert_eq(records.length(), 1)
  assert_eq(records[0]["TI"], ["RIS conflict"])
  assert_false(output.contains("García"))
  assert_false(output.contains("content_hex"))
  let repeated = {
    ..base,
    draft: {
      ..base.draft,
      sources: base.draft.sources + [base.draft.sources[1]],
    },
  }
  let copies = ris_export_records(
    reference_ris_export(reading_apply(repeated, Query("Conflicting method"))),
  )
  assert_eq(copies.length(), 2)
  assert_eq(copies[0]["ID"], ["moonfind-slot-2-record-2"])
  assert_eq(copies[1]["ID"], ["moonfind-slot-7-record-2"])
  reading_evidence("filtered-bibliography.ris", output)
  reading_evidence("same-doi-bibliography.ris", reference_ris_export(group))
}

///|
test "RIS export refuses empty pending malformed and oversized results without mutation" {
  let base = reading_fixture()
  let invalid = {
    ..base,
    draft: {
      ..base.draft,
      sources: base.draft.sources + [reading_source("ris-selection.json", "{}")],
    },
  }
  for
    view in [
      reading_apply(base, Query("not present anywhere")),
      { ..base, pending: true, },
      invalid,
    ] {
    try reference_ris_export(view) catch {
      _ => ()
    } noraise {
      _ => fail("Expected export refusal")
    }
    let after = reading_apply(view, ExportRis)
    assert_eq(after.draft, view.draft)
    if !view.pending {
      assert_true(after.error is Some(_))
    }
  }
  // A maliciously large in-memory catalog is refused even outside intake bounds.
  let repeated = {
    ..base,
    draft: { ..base.draft, sources: Array::make(500, base.draft.sources[1]), },
  }
  try reference_ris_export(repeated) catch {
    _ => ()
  } noraise {
    _ => fail("Expected size refusal")
  }
}

///|
test "RIS export line injection controls and raw values cannot synthesize records" {
  let base = reading_fixture()
  let source = base.draft.sources[0]
  let original : BibtexSelection = @json.from_json(
    @json.parse(reference_capture_text(base.draft.sources[1].content_hex)),
  )
  let hostile = "one\r\nER  -\nTY  - JOUR\u0000\u0085\u2028\u2029end"
  let r = {
    ..original.references[0],
    title: hostile,
    authors: [hostile, "second"],
    abstract_text: hostile,
    year: "forthcoming",
    reference_type: "unrecognized",
  }
  let sources : Array[BriefInputSource] = @json.from_json(
    reading_pair("bibtex", source, [ToJson::to_json(r)]),
  )
  let view = { ..base, draft: { ..base.draft, sources, }, }
  let output = reference_ris_export(view)
  let records = ris_export_records(output)
  assert_eq(records.length(), 1)
  assert_eq(records[0]["TY"], ["GEN"])
  assert_eq(records[0]["AU"].length(), 2)
  assert_false(records[0].contains("PY"))
  guard @json.parse(records[0]["N1"][0])
    is { "reference": { "title": String(title), .. }, .. } else {
    fail("Missing note")
  }
  assert_eq(title, hostile)
  assert_false(output.contains("\u0085"))
  assert_false(output.contains("\u2028"))
  reading_evidence("hostile-metadata.ris", output)
}

///|
test "RIS export type mapping dates and safe links have explicit fallbacks" {
  let r = reference_catalog(reading_fixture()).references[0]
  for
    (format, kind, expected) in [
      ("bibtex", "book", "BOOK"),
      ("csl", "chapter", "CHAP"),
      ("bibtex", "inproceedings", "CPAPER"),
      ("bibtex", "proceedings", "CONF"),
      ("csl", "thesis", "THES"),
      ("bibtex", "techreport", "RPRT"),
      ("csl", "webpage", "ELEC"),
      ("ris", "DATA", "DATA"),
      ("ris", "UNKNOWN", "GEN"),
      ("csl", "software", "GEN"),
    ] {
    assert_eq(
      reference_ris_type({ ..r, format, reference_type: kind, }),
      expected,
    )
  }
  for
    (raw, expected) in [
      ("2024", "2024"),
      ("2024-7-9", "2024"),
      ("2024/07", "2024"),
      ("20240", ""),
      ("no date", ""),
    ] {
    assert_eq(reference_ris_year(raw), expected)
  }
  for
    url in [
      "javascript:alert(1)", "file:///local", "https://example.invalid/a\nER  -",
      "https://example.invalid/a b",
    ] {
    assert_eq(reference_ris_url(url), "")
  }
  assert_eq(
    reference_ris_url(" HTTPS://example.invalid/a "),
    "HTTPS://example.invalid/a",
  )
}

///|
test "RIS export actual UI download exact Blob bytes failure retry and pending control" {
  let view = reading_apply(reading_fixture(), Query("9007199254740993"))
  for failed in [true, false] {
    experiment_download_fixture(failed)
    defer experiment_download_restore()
    let after = reading_apply(view, ExportRis)
    assert_eq(after.draft, view.draft)
    assert_eq(after.reference_query, view.reference_query)
    if failed {
      assert_true(after.error.unwrap().contains("RIS download failed"))
    } else {
      assert_eq(after.error, None)
      guard @json.parse(experiment_download_readback())
        is {
          "name": String("moonfind-reading-list.ris"),
          "clicked": True,
          "content": String(content),
          ..
        } else {
        fail("No download")
      }
      assert_eq(content, reference_ris_export(view))
      assert_eq(ris_export_records(content).length(), 1)
      reading_evidence("downloaded-bibliography.ris", content)
    }
  }
  install_choice_storage("ok")
  defer restore_choice_storage()
  let html = reading_render(view)
  assert_true(html.contains("Download current bibliography RIS"))
  assert_false(
    reading_render({ ..view, pending: true, }).contains(
      "Download current bibliography RIS",
    ),
  )
  assert_eq(
    reading_apply({ ..view, pending: true, }, ExportRis).error,
    view.error,
  )
  reading_evidence("ris-export-panel.html", html)
}
