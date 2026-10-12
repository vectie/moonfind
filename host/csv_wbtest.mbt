///|
async test "CSV selected evidence rows survive save reopen and readable dossier export" {
  let original = "\uFEFFid,segment,note,cost\r\n001,clinic,\"García, first trial\",10.00\r\n002,school,Unselected,20\r\n003,clinic,\"Needs <review>\r\nsecond line\",30\r\n"
  let source = brief_test_source(original, name="interviews.csv")
  let intake = intake_csv({ source, query: "CLINIC", column_number: 2, })
  assert_eq(intake.total_count, 3)
  assert_eq(intake.rows.map(row => row.record_number), [2, 4])
  let sources = select_csv({
    source,
    record_numbers: [4, 2, 2],
    column_numbers: [3, 1, 1],
  })
  assert_eq(sources[0], source)
  let selected : @research.CsvSelectionV1 = @json.from_json(
    @json.parse(@utf8.decode(brief_source_bytes(sources[1]))),
  )
  assert_eq(selected.source_digest, @store.digest_text(original))
  assert_eq(selected.column_numbers, [1, 3])
  assert_eq(selected.columns, ["id", "note"])
  assert_eq(selected.rows.map(row => row.record_number), [2, 4])
  let config = {
    ..model_route_config(workspace=@fs.tmpdir(prefix="find-csv")),
    run_id: "",
  }
  let request = { ..brief_test_request(), brief_id: "csv-corpus", sources, }
  let saved = save_brief(config, request)
  let reopened = brief_status(config, request.brief_id, saved.revision_id)
  assert_eq(reopened.snapshot.unwrap().brief, request)
  let archive = @moonzip.unzip_sync(
    export_brief(config, request.brief_id, saved.revision_id, "dossier.zip").to_fixedarray(),
  )
  assert_eq(archive[2].0, "sources/source-1.csv")
  assert_eq(Bytes::from_fixedarray(archive[2].1), @utf8.encode(original))
  assert_eq(
    Bytes::from_fixedarray(archive[3].1),
    brief_source_bytes(sources[1]),
  )
  let readable = @utf8.decode(Bytes::from_fixedarray(archive[0].1))
  assert_true(readable.contains("| Source record | id | note |"))
  assert_true(readable.contains("| 2 | 001 | García, first trial |"))
  assert_true(readable.contains("Needs &lt;review&gt;<br>second line"))
  assert_false(readable.contains("Unselected"))
  assert_false(
    @fs.exists(config.workspace + "/.moonsuite/products/moonfind/runs"),
  )
}

///|
test "CSV intake and selected companion enforce bounded local sources" {
  let source = brief_test_source("a,b\nx,y", name="table.csv")
  for
    invalid in [
      { ..source, name: "table.tsv", },
      { ..source, content_hex: "ff", },
      { ..source, origin: "", },
      { ..source, kind: "url", },
    ] {
    assert_true(
      (try? intake_csv({ source: invalid, query: "", column_number: 0, }))
      is Err(_),
    )
  }
  assert_true(
    (try? select_csv({ source, record_numbers: [1], column_numbers: [1], }))
    is Err(_),
  )
  assert_true(
    (try? select_csv({ source, record_numbers: [2], column_numbers: [], }))
    is Err(_),
  )
  let huge = brief_test_source(
    "a\n" + String::make(32767, 'x'),
    name="huge.csv",
  )
  assert_true(
    (try? intake_csv({ source: huge, query: "", column_number: 0, })) is Err(_),
  )
  let escaped = brief_test_source(
    "a\n\"" + String::make(18000, '\\') + "\"",
    name="escaped.csv",
  )
  assert_eq(
    intake_csv({ source: escaped, query: "", column_number: 0, }).total_count,
    1,
  )
  assert_true(
    (try? select_csv({
      source: escaped,
      record_numbers: [2],
      column_numbers: [1],
    }))
    is Err(_),
  )
}
