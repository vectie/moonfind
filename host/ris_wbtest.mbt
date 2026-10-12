///|
async test "RIS intake select save reopen dossier retains original file and selected structured cards" {
  let original = "\uFEFFTY  - JOUR\r\nTI  - 月面 robotics 🌒\r\nAU  - García, Ana\r\nAU  - 王, 明\r\nPY  - 2025\r\nDO  - 10.1234/lunar.1\r\nUR  - https://example.org/lunar\r\nAB  - First line.\r\n      第二行.\r\nER  -\r\nTY  - CONF\r\nTI  - Tactile mapping\r\nAU  - Smith, Jo\r\nPY  - 2024\r\nER  -\r\nTY  - BOOK\r\nTI  - Références locales\r\nAU  - García, Ana\r\nAU  - Müller, Éva\r\nPY  - 2023\r\nER  -\r\n"
  let source = brief_test_source(original, name="bibliothèque.ris")
  let intake = intake_ris({ source, author_filter: "garcía", })
  assert_eq(intake.total_count, 3)
  assert_eq(intake.references.map(r => r.record_number), [1, 3])
  let sources = select_ris({ source, record_numbers: [1, 3], })
  assert_eq(sources.length(), 2)
  assert_eq(sources[0], source)
  let selection : @research.RisSelectionV1 = @json.from_json(
    @json.parse(@utf8.decode(brief_source_bytes(sources[1]))),
  )
  assert_eq(selection.references.length(), 2)
  assert_eq(selection.source_digest, @store.digest_text(original))
  assert_eq(selection.references[0].authors, ["García, Ana", "王, 明"])
  let config = {
    ..model_route_config(workspace=@fs.tmpdir(prefix="find-ris")),
    run_id: "",
  }
  let request = { ..brief_test_request(), brief_id: "ris-library", sources, }
  let saved = save_brief(config, request)
  assert_eq(saved.state, "prepared")
  let reopened = brief_status(config, request.brief_id, saved.revision_id)
  assert_eq(reopened.snapshot.unwrap().brief, request)
  let archive = @moonzip.unzip_sync(
    export_brief(config, request.brief_id, saved.revision_id, "dossier.zip").to_fixedarray(),
  )
  assert_eq(archive.length(), 5)
  assert_eq(archive[2].0, "sources/source-1.ris")
  assert_eq(Bytes::from_fixedarray(archive[2].1), @utf8.encode(original))
  assert_eq(
    Bytes::from_fixedarray(archive[3].1),
    brief_source_bytes(sources[1]),
  )
  let readable = @utf8.decode(Bytes::from_fixedarray(archive[0].1))
  assert_true(readable.contains("Selected RIS references"))
  assert_true(readable.contains("月面 robotics 🌒"))
  assert_true(readable.contains("Références locales"))
  assert_false(readable.contains("Tactile mapping"))
  assert_false(
    @fs.exists(config.workspace + "/.moonsuite/products/moonfind/runs"),
  )
}
