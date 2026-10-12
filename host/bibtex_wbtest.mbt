///|
async test "BibTeX selected evidence saves reopens and exports readable citation keys with original bytes" {
  let original = "\uFEFF@string{venue=\"Lunar Review\"}\r\n@article{garcia2025,title={月面 robotics 🌒},author={García, Ana and 王, 明},year=2025,journal=venue,abstract={Contact sensing finding.}}\r\n@book{smith2024,title={Other approach},author={Smith, Jo},year=2024}\r\n"
  let source = brief_test_source(original, name="bibliothèque.bib")
  let intake = intake_bibtex({ source, query: "GARCÍA", })
  assert_eq(intake.total_count, 2)
  assert_eq(intake.references.map(r => r.citation_key), ["garcia2025"])
  let sources = select_bibtex({ source, record_numbers: [1], })
  assert_eq(sources.length(), 2)
  assert_eq(sources[0], source)
  let selection : @research.BibtexSelectionV1 = @json.from_json(
    @json.parse(@utf8.decode(brief_source_bytes(sources[1]))),
  )
  assert_eq(selection.source_digest, @store.digest_text(original))
  assert_eq(selection.references[0].citation_key, "garcia2025")
  assert_true((try? select_bibtex({ source, record_numbers: [3], })) is Err(_))
  let config = {
    ..model_route_config(workspace=@fs.tmpdir(prefix="find-bibtex")),
    run_id: "",
  }
  let request = { ..brief_test_request(), brief_id: "bibtex-library", sources, }
  let saved = save_brief(config, request)
  assert_eq(saved.state, "prepared")
  let reopened = brief_status(config, request.brief_id, saved.revision_id)
  assert_eq(reopened.snapshot.unwrap().brief, request)
  let archive = @moonzip.unzip_sync(
    export_brief(config, request.brief_id, saved.revision_id, "dossier.zip").to_fixedarray(),
  )
  assert_eq(Bytes::from_fixedarray(archive[2].1), @utf8.encode(original))
  assert_eq(archive[2].0, "sources/source-1.bib")
  assert_eq(
    Bytes::from_fixedarray(archive[3].1),
    brief_source_bytes(sources[1]),
  )
  let readable = @utf8.decode(Bytes::from_fixedarray(archive[0].1))
  assert_true(readable.contains("Selected BibTeX references"))
  assert_true(readable.contains("[garcia2025] 月面 robotics 🌒"))
  assert_true(readable.contains("Lunar Review"))
  assert_true(readable.contains("metadata-and-abstract"))
  assert_false(readable.contains("Other approach"))
  assert_false(
    @fs.exists(config.workspace + "/.moonsuite/products/moonfind/runs"),
  )
}
