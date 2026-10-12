///|
fn extract_fixture() -> BriefView {
  let original = "id,segment,note,private\r\n001,clinic,\"García: \"\"handoff\"\", 20 minutes\nNeeds timing check.\",secret-one\r\n002,school,\"=HYPERLINK(\"\"https://example.invalid\"\",\"\"link\"\")\",secret-two\r\n003,clinic,\"月面 <script>alert(1)</script>\rSecond line\",secret-three\r\n004,library,,secret-four\r\n"
  let rows : Array[CsvRow] = [
    {
      record_number: 2,
      values: [
        "001", "clinic", "García: \"handoff\", 20 minutes\nNeeds timing check.",
        "secret-one",
      ],
    },
    {
      record_number: 3,
      values: [
        "002", "school", "=HYPERLINK(\"https://example.invalid\",\"link\")", "secret-two",
      ],
    },
    {
      record_number: 4,
      values: [
        "003", "clinic", "月面 <script>alert(1)</script>\rSecond line", "secret-three",
      ],
    },
    { record_number: 5, values: ["004", "library", "", "secret-four"], },
  ]
  let source : BriefInputSource = {
    name: "csv-extract.csv",
    origin: "Synthetic local research table",
    captured_at: "2026-10-10T00:00:00Z",
    kind: "local-file",
    content_hex: brief_text_hex(original),
  }
  update_csv_view(
    _ => @rabbita.none,
    Imported(
      5,
      Ok({
        "source": ToJson::to_json(source),
        "columns": ["id", "segment", "note", "private"],
        "rows": rows.to_json(),
        "total_count": 4,
      }),
    ),
    { ..initial_brief_view(), generation: 5, pending: true, },
  ).1
}

///|
fn extract_apply(view : BriefView, action : CsvMsg) -> BriefView {
  update(_ => @rabbita.none, BriefAction(Csv(action)), {
    ..initial_model(),
    brief: view,
  }).1.brief
}

///|
fn extract_ready() -> BriefView {
  let view = extract_apply(extract_fixture(), SearchColumn(2))
  let view = extract_apply(view, Filter(" CLINIC "))
  let view = extract_apply(view, SelectMatching)
  let view = extract_apply(view, ToggleColumn(2))
  extract_apply(view, ToggleColumn(4))
}

///|
extern "js" fn extract_evidence(name : String, content : String) -> Unit =
  #|(name,content) => { if(process.env.MOONFIND_EXTRACT_EVIDENCE) process.getBuiltinModule('fs').writeFileSync(process.env.MOONFIND_EXTRACT_EVIDENCE+'/'+name,content); }

///|
test "extract UI actions project chosen columns and hidden selected records" {
  let view = extract_ready()
  assert_eq(view.csv.extract_scope, "selected")
  assert_eq(view.csv.selected, [2, 4])
  assert_eq(view.csv.columns, [1, 3])
  let hidden = extract_apply(view, Filter("library"))
  let selected = csv_extract(hidden.csv)
  assert_eq(selected.columns, ["id", "note"])
  assert_eq(selected.rows.map(row => row.record_number), [2, 4])
  assert_eq(selected.rows[0].values[0], "001")
  assert_eq(csv_filtered(hidden.csv).map(row => row.record_number), [5])
  let matching = extract_apply(hidden, ExtractScope("matching"))
  assert_eq(csv_extract(matching.csv).rows.map(row => row.record_number), [5])
  let all = extract_apply(hidden, ExtractScope("all"))
  assert_eq(csv_extract(all.csv).rows.map(row => row.record_number), [
    2, 3, 4, 5,
  ])
  assert_eq(all.csv.numeric_scope, "all")
  let independent = extract_apply(all, NumericScope("matching"))
  assert_eq(csv_extract(independent.csv), csv_extract(all.csv))
  assert_eq(
    extract_apply(hidden, ExtractScope("invalid")).csv.extract_scope,
    "selected",
  )
  assert_eq(hidden.draft, view.draft)
  assert_eq(hidden.csv.intake.unwrap().source, view.csv.intake.unwrap().source)
  for
    (name, state) in [
      ("selected.csv", hidden),
      ("matching.csv", matching),
      ("all.csv", all),
    ] {
    let text = csv_extract_text(state.csv)
    assert_false(text.contains("secret-"))
    assert_false(text.contains("private"))
    assert_false(text.contains("content_hex"))
    extract_evidence(name, text)
  }
  extract_evidence(
    "original.csv",
    brief_source_preview(view.csv.intake.unwrap().source.content_hex),
  )
}

///|
test "extract serialization quotes every exact string without inference" {
  assert_eq(
    csv_extract_record([
      "a,b", "a\"b", "", "\r", "\n", "\r\n", "月🌒", "001", "=1+1", " x ",
    ]),
    "\"a,b\",\"a\"\"b\",\"\",\"\r\",\"\n\",\"\r\n\",\"月🌒\",\"001\",\"=1+1\",\" x \"\r\n",
  )
  let view = extract_ready()
  let text = csv_extract_text(view.csv)
  assert_eq(
    text, "\"id\",\"note\"\r\n\"001\",\"García: \"\"handoff\"\", 20 minutes\nNeeds timing check.\"\r\n\"003\",\"月面 <script>alert(1)</script>\rSecond line\"\r\n",
  )
  let intake = view.csv.intake.unwrap()
  let header = {
    ..view.csv,
    intake: Some({
      ..intake,
      columns: ["id,code", "segment", "note\"quoted\nheader", "private"],
    }),
  }
  assert_true(
    csv_extract_text(header).has_prefix(
      "\"id,code\",\"note\"\"quoted\nheader\"\r\n",
    ),
  )
}

///|
test "extract source order duplicates blanks and empty scopes are deterministic" {
  let view = extract_ready()
  let reordered = {
    ..view.csv,
    selected: [4, 2, 4, 999],
    columns: [3, 1, 3, 99],
  }
  assert_eq(csv_extract(reordered), csv_extract(view.csv))
  let empty = extract_apply(view, ClearRows)
  assert_eq(csv_extract_text(empty.csv), "\"id\",\"note\"\r\n")
  let no_match = extract_apply(
    extract_apply(view, ExtractScope("matching")),
    Filter("absent"),
  )
  assert_eq(csv_extract(no_match.csv).rows, [])
  assert_eq(csv_extract_text(no_match.csv), "\"id\",\"note\"\r\n")
  extract_evidence("empty.csv", csv_extract_text(empty.csv))
  let blank = extract_apply(
    extract_apply(view, ExtractScope("matching")),
    Filter("library"),
  )
  assert_eq(csv_extract_text(blank.csv), "\"id\",\"note\"\r\n\"004\",\"\"\r\n")
}

///|
test "extract missing intake columns and malformed row remain repairable" {
  let error = csv_extract_text(empty_csv_view()) catch { error => "\{error}" }
  assert_true(error.contains("Import a CSV"))
  let view = extract_ready()
  let empty = { ..view.csv, columns: [], }
  let error = csv_extract_text(empty) catch { error => "\{error}" }
  assert_true(error.contains("at least one output column"))
  let invalid = { ..view.csv, extract_scope: "bad", }
  let error = csv_extract_text(invalid) catch { error => "\{error}" }
  assert_true(error.contains("Choose all"))
  let intake = view.csv.intake.unwrap()
  let malformed = {
    ..view.csv,
    intake: Some({ ..intake, rows: [{ record_number: 2, values: ["001"], }], }),
  }
  let error = csv_extract_text(malformed) catch { error => "\{error}" }
  assert_true(error.contains("row shape changed"))
  let blocked = extract_apply({ ..view, csv: empty, }, DownloadExtract)
  assert_true(blocked.error.unwrap().contains("at least one output column"))
  assert_eq(blocked.draft, view.draft)
}

///|
test "extract rendering exposes real scope controls projection preview and text import warning" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = extract_ready()
  let html = qa_test_render({ ..initial_model(), brief: view, })
  assert_true(html.contains("Download a reusable CSV extract"))
  assert_true(html.contains("Rows in CSV download"))
  assert_true(html.contains("Selected rows, including hidden selections"))
  assert_true(html.contains("Rows matching the current search"))
  assert_true(html.contains("All source rows"))
  assert_true(html.contains("2 data rows · 2 columns in the download"))
  assert_true(html.contains("Preview CSV download"))
  assert_true(html.contains("Download CSV extract"))
  assert_true(html.contains("import every column as text"))
  assert_true(html.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
  assert_false(html.contains("<script>alert(1)</script>"))
  extract_evidence("rendered-selected.html", html)
  let no_rows = extract_apply(view, ClearRows)
  assert_true(
    qa_test_render({ ..initial_model(), brief: no_rows, }).contains(
      "Download contains the header only",
    ),
  )
}

///|
test "extract pending reimport new and stale callbacks preserve lifecycle" {
  let view = extract_apply(extract_ready(), ExtractScope("all"))
  let pending = { ..view, pending: true, generation: 6, }
  for action in [ExtractScope("matching"), DownloadExtract] {
    let after = extract_apply(pending, action)
    assert_eq(after.csv.extract_scope, "all")
    assert_eq(after.error, pending.error)
    assert_eq(csv_extract(after.csv), csv_extract(view.csv))
  }
  let stale = extract_apply(pending, Imported(5, Ok(Json::null())))
  assert_eq(stale.csv.extract_scope, "all")
  let (_, fresh) = update_brief_view(_ => @rabbita.none, New, pending)
  assert_eq(fresh.csv.extract_scope, "selected")
  assert_true(fresh.csv.intake is None)
  assert_true(
    extract_apply(fresh, Imported(6, Ok(Json::null()))).csv.intake is None,
  )
  assert_eq(extract_fixture().csv.extract_scope, "selected")
}

///|
test "extract bounded table includes every projected row and column" {
  let view = extract_fixture()
  let intake = view.csv.intake.unwrap()
  let state = {
    ..view.csv,
    extract_scope: "all",
    columns: Array::makei(32, i => 32 - i),
    intake: Some({
      ..intake,
      columns: Array::makei(32, i => "c\{i}"),
      rows: Array::makei(512, i => {
        record_number: i + 2,
        values: Array::makei(32, _ => ""),
      }),
      total_count: 512,
    }),
  }
  let extract = csv_extract(state)
  assert_eq(extract.columns[0], "c0")
  assert_eq(extract.columns[31], "c31")
  assert_eq(extract.rows.length(), 512)
  assert_eq(extract.rows[511].record_number, 513)
  assert_eq(extract.rows[511].values.length(), 32)
  extract_evidence("bounded.csv", csv_extract_text(state))
}

///|
extern "js" fn extract_blob_verify(expected : String) -> String =
  #|expected => {
  #| const got=globalThis.__numericDownload;
  #| if(!got.clicked || got.name!=='moonfind-csv-extract.csv' || !(got.blob instanceof Blob) || got.blob.type!=='text/csv;charset=utf-8') return 'CSV download metadata mismatch';
  #| got.blob.text().then(text=>{
  #|   if(text!==expected) throw Error('CSV Blob bytes differ');
  #|   if(process.env.MOONFIND_EXTRACT_EVIDENCE) {
  #|     const fs=process.getBuiltinModule('fs'), out=process.env.MOONFIND_EXTRACT_EVIDENCE;
  #|     fs.writeFileSync(out+'/'+got.name,text);
  #|     fs.writeFileSync(out+'/download-receipt.json',JSON.stringify({filename:got.name,mime:got.blob.type,bytes:got.blob.size,real_blob:true,sha256:process.getBuiltinModule('crypto').createHash('sha256').update(text).digest('hex')},null,2));
  #|   }
  #| }).catch(e=>{console.error(e);process.exitCode=1;}); return '';
  #|}

///|
test "extract real Blob action failure retry and repeat retain table brief and selection" {
  let view = extract_apply(extract_ready(), Filter("library"))
  let model = { ..initial_model(), brief: view, }
  for mode in ["create", "click", "ok", "ok"] {
    csv_numeric_blob_fixture(mode)
    let after = update(
        _ => @rabbita.none,
        BriefAction(Csv(DownloadExtract)),
        model,
      ).1.brief
    assert_eq(after.csv.selected, view.csv.selected)
    assert_eq(after.csv.columns, view.csv.columns)
    assert_eq(after.csv.query, "library")
    assert_eq(after.csv.intake.unwrap().source, view.csv.intake.unwrap().source)
    assert_eq(after.draft, view.draft)
    assert_eq(after.generation, view.generation)
    if mode == "ok" {
      assert_eq(after.error, None)
      assert_eq(extract_blob_verify(csv_extract_text(view.csv)), "")
    } else {
      assert_true(after.error.unwrap().contains("CSV extract download failed"))
    }
    csv_numeric_blob_restore()
  }
}
