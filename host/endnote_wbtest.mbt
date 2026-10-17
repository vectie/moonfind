///|
async test "EndNote intake selection save reopen and dossier preserve original and all selected tags" {
  let original = "\uFEFF%0 Journal Article\r\n%T 月面 robotics 🌒\r\n%A García, Ana\r\n%A 王, 明\r\n%D 2025\r\n%R 10.1234/lunar.1\r\n%X First line.\r\n  第二行.\r\n%~ Research database\r\n\r\n%0 Conference Paper\r\n%T Tactile mapping\r\n%A Smith, Jo\r\n%D 2024\r\n\r\n%0 Book\r\n%T Références locales\r\n%A García, Ana\r\n%D 2023\r\n"
  let source = brief_test_source(original, name="bibliothèque.enw")
  let intake = intake_endnote({ source, author_filter: "GARCÍA", })
  assert_eq(intake.total_count, 3)
  assert_eq(intake.references.map(r => r.record_number), [1, 3])
  let sources = select_endnote({ source, record_numbers: [3, 1, 3], })
  assert_eq(sources.length(), 2)
  assert_eq(sources[0], source)
  assert_eq(sources[1].name, "endnote-selection.json")
  let selection : @research.EndnoteSelectionV1 = @json.from_json(
    @json.parse(@utf8.decode(brief_source_bytes(sources[1]))),
  )
  assert_eq(selection.contract_id, "moonfind.endnote-selection.v1")
  assert_eq(selection.references.map(r => r.record_number), [1, 3])
  assert_eq(selection.source_digest, @store.digest_text(original))
  assert_eq(selection.references[0].fields[7].tag, "~")
  let config = {
    ..model_route_config(workspace=@fs.tmpdir(prefix="find-endnote")),
    run_id: "",
  }
  let request = {
    ..brief_test_request(),
    brief_id: "endnote-library",
    sources,
  }
  let saved = save_brief(config, request)
  assert_eq(saved.state, "prepared")
  let reopened = brief_status(config, request.brief_id, saved.revision_id)
  assert_eq(reopened.snapshot.unwrap().brief, request)
  let archive = @moonzip.unzip_sync(
    export_brief(config, request.brief_id, saved.revision_id, "dossier.zip").to_fixedarray(),
  )
  assert_eq(archive.length(), 5)
  assert_eq(archive[2].0, "sources/source-1.enw")
  assert_eq(Bytes::from_fixedarray(archive[2].1), @utf8.encode(original))
  assert_eq(
    Bytes::from_fixedarray(archive[3].1),
    brief_source_bytes(sources[1]),
  )
  let readable = @utf8.decode(Bytes::from_fixedarray(archive[0].1))
  assert_true(readable.contains("Selected EndNote references"))
  assert_true(readable.contains("月面 robotics 🌒"))
  assert_true(readable.contains("Références locales"))
  assert_false(readable.contains("Tactile mapping"))
  assert_false(
    @fs.exists(config.workspace + "/.moonsuite/products/moonfind/runs"),
  )
}

///|
test "EndNote malformed late record cannot produce a partial selection" {
  let source = brief_test_source(
    "%0 Book\n%T Good\n\n%0 Book\n%Title Broken\n",
    name="broken.enw",
  )
  try intake_endnote({ source, author_filter: "", }) catch {
    _ => ()
  } noraise {
    _ => fail("Expected no intake result")
  }
  try select_endnote({ source, record_numbers: [1], }) catch {
    _ => ()
  } noraise {
    _ => fail("Expected no partial source pair")
  }
  let good = brief_test_source("%0 Book\n%T Good\n", name="good.enw")
  for record_numbers in [[], [0], [2], [1, 2]] {
    try select_endnote({ source: good, record_numbers, }) catch {
      _ => ()
    } noraise {
      _ => fail("Expected invalid selection failure")
    }
  }
}
