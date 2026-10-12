///|
async test "CSL selection saves reopens and exports citation IDs with byte exact source" {
  let original = "\uFEFF[\r\n{\"id\":42,\"type\":\"article-journal\",\"citation-key\":\"garcia2025\",\"title\":\"月面 robotics 🌒\",\"author\":[{\"family\":\"García\",\"given\":\"Ana\"}],\"issued\":{\"date-parts\":[[2025]]},\"abstract\":\"Contact finding.\",\"custom\":{\"keep\":true}},\r\n{\"id\":\"other\",\"type\":\"book\",\"title\":\"Other approach\"}\r\n]\r\n"
  let source = brief_test_source(original, name="bibliothèque.csl.json")
  let intake = intake_csl({ source, query: "GARCÍA", })
  assert_eq(intake.total_count, 2)
  assert_eq(intake.references.map(r => r.citation_key), ["garcia2025"])
  let sources = select_csl({ source, record_numbers: [1, 1], })
  assert_eq(sources.length(), 2)
  assert_eq(sources[0], source)
  let selection : @research.CslSelectionV1 = @json.from_json(
    @json.parse(@utf8.decode(brief_source_bytes(sources[1]))),
  )
  assert_eq(selection.source_digest, @store.digest_text(original))
  assert_eq(selection.references.length(), 1)
  assert_eq(selection.references[0].item_id, "42")
  assert_eq(selection.references[0].item_id_kind, "number")
  for numbers in [[], [0], [3], [1, -1]] {
    assert_true(
      (try? select_csl({ source, record_numbers: numbers, })) is Err(_),
    )
  }
  let config = {
    ..model_route_config(workspace=@fs.tmpdir(prefix="find-csl")),
    run_id: "",
  }
  let request = { ..brief_test_request(), brief_id: "csl-library", sources, }
  let saved = save_brief(config, request)
  assert_eq(saved.state, "prepared")
  let reopened = brief_status(config, request.brief_id, saved.revision_id)
  assert_eq(reopened.snapshot.unwrap().brief, request)
  let archive = @moonzip.unzip_sync(
    export_brief(config, request.brief_id, saved.revision_id, "dossier.zip").to_fixedarray(),
  )
  assert_eq(Bytes::from_fixedarray(archive[2].1), @utf8.encode(original))
  assert_eq(archive[2].0, "sources/source-1.json")
  assert_eq(
    Bytes::from_fixedarray(archive[3].1),
    brief_source_bytes(sources[1]),
  )
  let readable = @utf8.decode(Bytes::from_fixedarray(archive[0].1))
  assert_true(readable.contains("Selected CSL JSON references"))
  assert_true(readable.contains("[garcia2025] 月面 robotics 🌒"))
  assert_true(readable.contains("CSL item ID (number): 42"))
  assert_true(readable.contains("metadata-and-abstract"))
  assert_false(readable.contains("Other approach"))
  assert_false(
    @fs.exists(config.workspace + "/.moonsuite/products/moonfind/runs"),
  )
}

///|
test "CSL host enforces source and selection sizes" {
  let original = "[{\"id\":1,\"type\":\"book\"}]"
  let source = brief_test_source(original, name="library.json")
  for
    invalid in [
      { ..source, name: "wrong.bib", },
      { ..source, content_hex: "ff", },
      { ..source, content_hex: "0", },
      { ..source, origin: "", },
      { ..source, kind: "url", },
    ] {
    assert_true((try? intake_csl({ source: invalid, query: "", })) is Err(_))
  }
  let huge = brief_test_source(String::make(32769, ' '), name="huge.json")
  assert_true((try? intake_csl({ source: huge, query: "", })) is Err(_))
  // An ID is retained separately from its display key and fallback title. The
  // normalized companion limit is checked independently of the smaller input.
  let text = (
    [{ "id": String::make(16000, 'x').to_json(), "type": "book" }] : Json).stringify()
  let source = brief_test_source(text, name="large.json")
  assert_eq(intake_csl({ source, query: "", }).total_count, 1)
  assert_true((try? select_csl({ source, record_numbers: [1], })) is Err(_))
}
