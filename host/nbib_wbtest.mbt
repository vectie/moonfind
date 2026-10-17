///|
async test "NBIB selection save reopen and dossier retain originals PMID and all tags" {
  let original = "\uFEFFPMID- 99900001\r\nTI  - Synthetic lunar evidence 🌒\r\nFAU - García, Ana\r\nAU  - Garcia A\r\nDP  - 2025 Jan\r\nAB  - Supplied abstract.\r\n      第二行.\r\nZZ  - Unknown metadata\r\n\r\nPMID- 99900002\r\nTI  - Unselected citation\r\nAU  - Lee J\r\n\r\nPMID- 99900001\r\nTI  - Separate duplicate\r\nFAU - García, Ana\r\n"
  let source = brief_test_source(original, name="bibliothèque.nbib")
  let intake = intake_nbib({ source, author_filter: "GARCÍA", })
  assert_eq(intake.total_count, 3)
  assert_eq(intake.references.map(r => r.record_number), [1, 3])
  let sources = select_nbib({ source, record_numbers: [3, 1, 3], })
  assert_eq(sources.length(), 2)
  assert_eq(sources[0], source)
  let selection : @research.NbibSelectionV1 = @json.from_json(
    @json.parse(@utf8.decode(brief_source_bytes(sources[1]))),
  )
  assert_eq(selection.contract_id, "moonfind.nbib-selection.v1")
  assert_eq(selection.references.map(r => r.record_number), [1, 3])
  assert_eq(selection.references.map(r => r.pmid), ["99900001", "99900001"])
  assert_eq(selection.source_digest, @store.digest_text(original))
  assert_eq(selection.references[0].fields.last().unwrap().tag, "ZZ")
  let config = {
    ..model_route_config(workspace=@fs.tmpdir(prefix="find-nbib")),
    run_id: "",
  }
  let request = { ..brief_test_request(), brief_id: "nbib-library", sources, }
  let saved = save_brief(config, request)
  assert_eq(saved.state, "prepared")
  let reopened = brief_status(config, request.brief_id, saved.revision_id)
  assert_eq(reopened.snapshot.unwrap().brief, request)
  let archive = @moonzip.unzip_sync(
    export_brief(config, request.brief_id, saved.revision_id, "dossier.zip").to_fixedarray(),
  )
  assert_eq(archive.length(), 5)
  assert_eq(archive[2].0, "sources/source-1.nbib")
  assert_eq(Bytes::from_fixedarray(archive[2].1), @utf8.encode(original))
  assert_eq(
    Bytes::from_fixedarray(archive[3].1),
    brief_source_bytes(sources[1]),
  )
  let readable = @utf8.decode(Bytes::from_fixedarray(archive[0].1))
  assert_true(readable.contains("Selected PubMed NBIB references"))
  assert_true(readable.contains("Supplied PMID: 99900001"))
  assert_true(readable.contains("Synthetic lunar evidence 🌒"))
  assert_false(readable.contains("Unselected citation"))
  assert_false(
    @fs.exists(config.workspace + "/.moonsuite/products/moonfind/runs"),
  )
}

///|
test "NBIB failed final record and invalid selection cannot produce partial source pair" {
  let bad = brief_test_source(
    "PMID- 1\nTI  - Good\n\nPMID- 2\nTI - Malformed final record\n",
    name="bad.nbib",
  )
  try intake_nbib({ source: bad, author_filter: "", }) catch {
    _ => ()
  } noraise {
    _ => fail("Expected complete intake rejection")
  }
  try select_nbib({ source: bad, record_numbers: [1], }) catch {
    _ => ()
  } noraise {
    _ => fail("Expected no partial source pair")
  }
  let good = brief_test_source("PMID- 1\nTI  - Good\n", name="good.nbib")
  for record_numbers in [[], [0], [2], [1, 2]] {
    try select_nbib({ source: good, record_numbers, }) catch {
      _ => ()
    } noraise {
      _ => fail("Expected invalid selection failure")
    }
  }
  for source in [{ ..good, name: "wrong.xml", }, { ..good, content_hex: "ff", }] {
    try intake_nbib({ source, author_filter: "", }) catch {
      _ => ()
    } noraise {
      _ => fail("Expected source validation failure")
    }
  }
}
