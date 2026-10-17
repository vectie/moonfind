///|
fn json_records_source(text : String) -> BriefInputSource {
  {
    name: "observations.json",
    origin: "Synthetic interview evidence 月🌒",
    captured_at: "2026-10-10T14:00:00Z",
    kind: "local-file",
    content_hex: brief_text_hex(text),
  }
}

///|
fn json_records_text() -> String {
  let text =
    #|{"collection":"synthetic", "observations":[
    #| {"id":9007199254740993,"segment":"clinic","note":"García: slow handoff\nCheck timing 🌒","value":1.2300e+02,"unknown":null,"nested":{"private":"keep all fields"}},
    #| {"id":9007199254740994,"segment":"school","note":"<script>literal</script>","value":-0,"unknown":"","tags":["a","b"]},
    #| {"id":9007199254740993,"segment":"clinic","note":"Σωκράτης: fast handoff","value":1e400,"active":false}
    #| ],"a/b":{"~items":[{"":"empty field","__proto__":"text","constructor":"also text"}]}}
  text
}

///|
fn json_records_apply(view : BriefView, action : JsonEvidenceMsg) -> BriefView {
  update(_ => @rabbita.none, BriefAction(JsonEvidence(action)), {
    ..initial_model(),
    brief: view,
  }).1.brief
}

///|
fn json_records_fixture() -> BriefView {
  let view = {
    ..initial_brief_view(),
    draft: {
      ..brief_fixture_draft(),
      sources: [json_records_source(json_records_text())],
    },
  }
  let view = json_records_apply(view, Source(1))
  let view = json_records_apply(view, Pointer("/observations"))
  json_records_apply(view, Explore)
}

///|
extern "js" fn json_records_evidence(name : String, content : String) -> Unit =
  #|(name,content) => {if(process.env.MOONFIND_JSON_EVIDENCE)process.getBuiltinModule('fs').writeFileSync(process.env.MOONFIND_JSON_EVIDENCE+'/'+name,content);}

///|
test "JSON evidence parses lossless records and distinguishes missing null empty nested fields" {
  let table = json_evidence_table(
    json_records_source(json_records_text()),
    "/observations",
  )
  assert_eq(table.rows.length(), 3)
  assert_eq(table.columns, [
    "id", "segment", "note", "value", "unknown", "nested", "tags", "active",
  ])
  assert_eq(table.rows.map(row => row.pointer), [
    "/observations/0", "/observations/1", "/observations/2",
  ])
  assert_eq(table.rows[0].cells[0], {
    kind: "number",
    text: "9007199254740993",
  })
  assert_eq(table.rows[0].cells[3].text, "1.2300e+02")
  assert_eq(table.rows[1].cells[3].text, "-0")
  assert_eq(table.rows[2].cells[3].text, "1e400")
  assert_eq(table.rows[0].cells[4], { kind: "null", text: "null", })
  assert_eq(table.rows[1].cells[4], { kind: "string", text: "", })
  assert_eq(table.rows[2].cells[4], { kind: "missing", text: "", })
  assert_eq(table.rows[0].cells[5], {
    kind: "object",
    text: "{\"private\":\"keep all fields\"}",
  })
  assert_eq(table.rows[1].cells[6], { kind: "array", text: "[\"a\",\"b\"]", })
  assert_eq(table.rows[2].cells[7], { kind: "boolean", text: "false", })
  assert_true(table.rows[0].cells[2].text.contains("\nCheck timing 🌒"))
  json_records_evidence("original.json", json_records_text())
  json_records_evidence(
    "table.json",
    ToJson::to_json(table).stringify(indent=2),
  )
}

///|
test "JSON evidence pointer traverses escaped fields empty keys and array indexes" {
  let table = json_evidence_table(
    json_records_source(json_records_text()),
    "/a~1b/~0items",
  )
  assert_eq(table.rows[0].pointer, "/a~1b/~0items/0")
  assert_eq(table.columns, ["", "__proto__", "constructor"])
  assert_eq(table.rows[0].cells[1].text, "text")
  let raw =
    #|{"": [[{}, {"a": "escaped \" bracket ] } and slash \\"}]]}
  let source = json_records_source(raw)
  let table = json_evidence_table(source, "//0")
  assert_eq(table.rows.length(), 2)
  assert_eq(table.rows[0].cells[0].kind, "missing")
  assert_eq(
    json_evidence_table(json_records_source("\u{feff}[{}]"), "").rows[0].pointer,
    "/0",
  )
  assert_eq(json_evidence_table(json_records_source("[]"), "").columns, [])
  for
    pointer in [
      "observations", "/absent", "/observations/00", "/observations/-", "/observations/99",
      "/a~2b", "/a~", "/observations/0",
    ] {
    assert_true(
      json_records_rejected(json_records_source(json_records_text()), pointer),
    )
  }
}

///|
test "JSON evidence rejects unsupported shapes malformed inputs and ambiguous duplicate keys" {
  for
    raw in [
      "{", "[1]", "[null]", "[[]]", "{\"a\":1}", "true", "[{},]", "[{\"a\":1,\"a\":2}]",
      "[{\"a\":1,\"\\u0061\":2}]", "[{\"nested\":{\"a\":1,\"a\":2}}]",
    ] {
    assert_true(json_records_rejected(json_records_source(raw), ""))
  }
  for hex in ["0", "zz", "ff"] {
    assert_true(
      json_records_rejected(
        { ..json_records_source("[]"), content_hex: hex, },
        "",
      ),
    )
  }
  let view = json_records_apply(json_records_fixture(), Pointer("/missing"))
  assert_true(view.json_evidence.table is None)
  let failed = json_records_apply(view, Explore)
  assert_true(failed.error.unwrap().contains("Pointer"))
  assert_eq(failed.draft, view.draft)
  assert_true(failed.json_evidence.table is None)
  let repaired = json_records_apply(
    json_records_apply(failed, Pointer("/observations")),
    Explore,
  )
  assert_eq(repaired.json_evidence.table.unwrap().rows.length(), 3)
  assert_eq(repaired.error, None)
}

///|
test "JSON evidence search selection export preserve hidden records and exact source order" {
  let view = json_records_fixture()
  let filtered = json_records_apply(view, Search("  CLINIC  "))
  assert_eq(
    json_evidence_matches(filtered.json_evidence).map(row => row.record_number),
    [1, 3],
  )
  let selected = json_records_apply(
    json_records_apply(filtered, Toggle(3)),
    SelectMatching,
  )
  assert_eq(selected.json_evidence.selected, [3, 1])
  let hidden = json_records_apply(selected, Search("school"))
  assert_eq(
    json_evidence_selected(hidden.json_evidence).map(row => row.record_number),
    [1, 3],
  )
  assert_eq(json_records_apply(hidden, Toggle(500)).json_evidence.selected, [
    3, 1,
  ])
  assert_eq(
    json_evidence_matches(
      json_records_apply(hidden, Search("ΣΩΚΡΆΤΗΣ")).json_evidence,
    ).length(),
    1,
  )
  assert_eq(
    json_evidence_matches(
      json_records_apply(hidden, Search("[a-z]")).json_evidence,
    ).length(),
    0,
  )
  let content = json_evidence_export(hidden)
  assert_true(content.contains("9007199254740993"))
  assert_true(content.contains("1.2300e+02"))
  assert_true(content.contains("1e400"))
  assert_false(content.contains("9007199254740994"))
  assert_false(content.contains("content_hex"))
  assert_eq(hidden.draft, view.draft)
  assert_true(
    @json.parse(content)
    is {
      "selected_record_count": Number(2, ..),
      "prepared_revision_id": Null,
      "source": { "host_recorded_digest": Null, .. },
      ..
    },
  )
  json_records_evidence("selected-extract.json", content)
  let empty = json_records_apply(hidden, Clear)
  assert_true(
    @json.parse(json_evidence_export(empty)) is { "records": Array([]), .. },
  )
  assert_true(
    json_records_apply(empty, Add).error.unwrap().contains("at least one"),
  )
  assert_eq(json_records_apply(empty, Add).draft, view.draft)
  json_records_evidence("empty-extract.json", json_evidence_export(empty))
}

///|
test "JSON evidence add retains original and browser draft and reopens as ordinary source" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let selected = json_records_apply(json_records_fixture(), SelectMatching)
  let expected = json_evidence_export(selected)
  let added = json_records_apply(selected, Add)
  assert_eq(added.draft.sources.length(), 2)
  assert_eq(added.draft.sources[0], selected.draft.sources[0])
  assert_eq(brief_source_preview(added.draft.sources[1].content_hex), expected)
  assert_eq(added.draft.sources[1].name, "json-evidence-extract.json")
  assert_eq(added.draft.sources[1].kind, "pasted-text")
  assert_eq(added.json_evidence.selected, [])
  assert_eq(json_records_apply(added, Add).draft.sources.length(), 2)
  assert_eq(initial_brief_view().draft, added.draft)
  let saved = brief_fixture_reply(added.draft, "revision-json")
  let reopened = update_brief_view(
      _ => @rabbita.none,
      Loaded(8, added.draft.brief_id, "revision-json", Ok(saved)),
      { ..added, generation: 8, pending: true, },
    ).1
  assert_eq(reopened.draft, added.draft)
  assert_eq(reopened.json_evidence, empty_json_evidence_view())
  let extracted = json_records_apply(
    json_records_apply(
      json_records_apply(reopened, Source(2)),
      Pointer("/records"),
    ),
    Explore,
  )
  assert_eq(extracted.json_evidence.table.unwrap().rows.length(), 3)
  json_records_evidence(
    "added-brief.json",
    ToJson::to_json(added.draft).stringify(indent=2),
  )
}

///|
test "JSON evidence pending new source changes and pointers invalidate only exploration" {
  let view = json_records_apply(json_records_fixture(), SelectMatching)
  let pending = { ..view, pending: true, }
  for
    action in [
      Source(1),
      Pointer(""),
      Explore,
      Search("x"),
      Toggle(1),
      SelectMatching,
      Clear,
      Download,
      Add,
    ] {
    let next = json_records_apply(pending, action)
    assert_eq(next.json_evidence, view.json_evidence)
    assert_eq(next.draft, view.draft)
    assert_eq(next.error, view.error)
  }
  let edited = update_brief_view(
      _ => @rabbita.none,
      Edit("question", "New question"),
      view,
    ).1
  assert_eq(edited.json_evidence, view.json_evidence)
  let appended = {
    ..view,
    draft: {
      ..view.draft,
      sources: view.draft.sources + [json_records_source("[]")],
    },
  }
  assert_eq(sync_json_evidence(appended).json_evidence, view.json_evidence)
  let replaced = {
    ..view,
    draft: { ..view.draft, sources: [json_records_source("[]")], },
  }
  assert_eq(
    sync_json_evidence(replaced).json_evidence,
    empty_json_evidence_view(),
  )
  assert_true(
    try {
      ignore(json_evidence_export(replaced))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(
    update_brief_view(_ => @rabbita.none, RemoveSource(0), view).1.json_evidence,
    empty_json_evidence_view(),
  )
  assert_eq(
    update_brief_view(_ => @rabbita.none, New, pending).1.json_evidence,
    empty_json_evidence_view(),
  )
  assert_eq(
    json_records_apply(view, Source(0)).json_evidence,
    empty_json_evidence_view(),
  )
  let changed = json_records_apply(view, Pointer("/a~1b/~0items"))
  assert_true(changed.json_evidence.table is None)
  assert_eq(changed.json_evidence.selected, [])
}

///|
test "JSON evidence bounds allow exact limits and prevent partial add" {
  let rows = "[" + Array::makei(512, _ => "{}").join(",") + "]"
  assert_eq(
    json_evidence_table(json_records_source(rows), "").rows.length(),
    512,
  )
  assert_true(
    json_records_rejected(
      json_records_source("[" + Array::makei(513, _ => "{}").join(",") + "]"),
      "",
    ),
  )
  let fields = Array::makei(32, i => "\"f\{i}\":\{i}").join(",")
  assert_eq(
    json_evidence_table(json_records_source("[{" + fields + "}]"), "").columns.length(),
    32,
  )
  assert_true(
    json_records_rejected(
      json_records_source("[{" + fields + ",\"extra\":0}]"),
      "",
    ),
  )
  let full = "[{\"a\":\"" + Array::makei(32758, _ => "x").join("") + "\"}]"
  assert_eq(brief_text_hex(full).length(), 65536)
  assert_eq(json_evidence_table(json_records_source(full), "").rows.length(), 1)
  assert_true(json_records_rejected(json_records_source(full + " "), ""))
  let deep = Array::makei(34, _ => "[").join("") +
    "{}" +
    Array::makei(34, _ => "]").join("")
  assert_true(json_records_rejected(json_records_source(deep), ""))
  let view = json_records_apply(json_records_fixture(), SelectMatching)
  let eight = {
    ..view,
    draft: {
      ..view.draft,
      sources: view.draft.sources +
      Array::makei(7, _ => json_records_source("[]")),
    },
  }
  assert_true(
    json_records_apply(eight, Add).error.unwrap().contains("source slot"),
  )
  assert_eq(json_records_apply(eight, Add).draft, eight.draft)
  let huge = {
    ..view,
    draft: { ..view.draft, sources: [json_records_source(full)], },
    json_evidence: empty_json_evidence_view(),
  }
  let huge = json_records_apply(
    json_records_apply(json_records_apply(huge, Source(1)), Explore),
    SelectMatching,
  )
  assert_true(json_records_apply(huge, Add).error.unwrap().contains("32 KiB"))
  assert_eq(json_records_apply(huge, Add).draft, huge.draft)
  assert_true(json_evidence_export(huge).length() > 32768)
}

///|
test "JSON evidence rendered workflow exposes pointers types exact values and escaped markup" {
  let view = json_records_apply(json_records_fixture(), SelectMatching)
  let html = qa_test_render({ ..initial_model(), brief: view, })
  for
    label in [
      "Explore loaded JSON evidence", "JSON Pointer to array", "Preview selected JSON extract",
      "Add selected JSON records to brief", "Download selected JSON extract", "9007199254740993",
      "1.2300e+02", "/observations/0", "(field absent)", "(empty string)", "&lt;script&gt;literal&lt;/script&gt;",
    ] {
    assert_true(html.contains(label))
  }
  assert_false(html.contains("<script>literal</script>"))
  json_records_evidence("rendered-json-evidence.html", html)
}

///|
extern "js" fn json_records_blob_verify(expected : String) -> String =
  #|expected=>{
  #| const got=globalThis.__numericDownload;
  #| if(!got.clicked||got.name!=='moonfind-json-evidence-extract.json'||!(got.blob instanceof Blob)||got.blob.type!=='application/json;charset=utf-8')return 'JSON evidence download metadata mismatch';
  #| got.blob.text().then(text=>{
  #|   if(text!==expected)throw Error('JSON evidence Blob content mismatch');
  #|   if(process.env.MOONFIND_JSON_EVIDENCE){const fs=process.getBuiltinModule('fs'),dir=process.env.MOONFIND_JSON_EVIDENCE;fs.writeFileSync(dir+'/'+got.name,text);fs.writeFileSync(dir+'/download-receipt.json',JSON.stringify({filename:got.name,mime:got.blob.type,bytes:got.blob.size,sha256:process.getBuiltinModule('crypto').createHash('sha256').update(text).digest('hex'),real_blob:true},null,2));}
  #| }).catch(error=>{console.error(error);process.exitCode=1;});return '';
  #|}

///|
test "JSON evidence actual Blob download failure retry repeat preserve draft and selections" {
  let view = json_records_apply(
    json_records_apply(json_records_fixture(), Search("clinic")),
    SelectMatching,
  )
  let model = { ..initial_model(), brief: view, }
  for mode in ["create", "click", "ok", "ok"] {
    csv_numeric_blob_fixture(mode)
    let after = update(
        _ => @rabbita.none,
        BriefAction(JsonEvidence(Download)),
        model,
      ).1.brief
    assert_eq(after.draft, view.draft)
    assert_eq(after.json_evidence, view.json_evidence)
    if mode == "ok" {
      assert_eq(after.error, None)
      assert_eq(json_records_blob_verify(json_evidence_export(view)), "")
    } else {
      assert_true(after.error.unwrap().contains("download failed"))
    }
    csv_numeric_blob_restore()
  }
}

///|
fn json_records_rejected(source : BriefInputSource, pointer : String) -> Bool {
  try {
    ignore(json_evidence_table(source, pointer))
    false
  } catch {
    _ => true
  }
}

///|
extern "js" fn json_records_digest(hex : String) -> String =
  #|hex=>'sha256:'+process.getBuiltinModule('crypto').createHash('sha256').update(Buffer.from(hex,'hex')).digest('hex')

///|
test "JSON evidence saved provenance is copied only for unchanged matching source revision" {
  let view = json_records_apply(json_records_fixture(), SelectMatching)
  let source = view.draft.sources[0]
  let digest = json_records_digest(source.content_hex)
  let saved : BriefSource = {
    slot: 1,
    name: source.name,
    origin: source.origin,
    captured_at: source.captured_at,
    kind: source.kind,
    availability: "retained-local-capture",
    archive_path: "sources/source-1.json",
    byte_count: source.content_hex.length() / 2,
    digest,
  }
  let snapshot : BriefSnapshot = {
    contract_id: "moonfind.brief-snapshot.v1",
    revision_id: "revision-fixture",
    state: "prepared",
    brief: view.draft,
    sources: [saved],
    boundary: "Synthetic saved source fixture",
  }
  let prepared = {
    ..view,
    opened: Some({
      contract_id: "moonfind.brief-status.v1",
      brief_id: view.draft.brief_id,
      revision_id: "revision-fixture",
      state: "prepared",
      snapshot: Some(snapshot),
      issues: [],
    }),
  }
  let exported = json_evidence_export(prepared)
  assert_true(exported.contains(digest))
  assert_true(
    @json.parse(exported)
    is { "prepared_revision_id": String("revision-fixture"), .. },
  )
  let edited = update_brief_view(
      _ => @rabbita.none,
      Edit("question", "Changed question"),
      prepared,
    ).1
  assert_true(
    @json.parse(json_evidence_export(edited))
    is {
      "prepared_revision_id": Null,
      "source": { "host_recorded_digest": Null, .. },
      ..
    },
  )
  let added = json_records_apply(prepared, Add)
  assert_eq(added.draft.parent_revision, Some("revision-fixture"))
  assert_true(
    brief_source_preview(added.draft.sources[1].content_hex).contains(digest),
  )
  assert_eq(added.draft.sources[0], source)
  let stale = {
    ..prepared,
    draft: { ..prepared.draft, question: "Different draft", },
  }
  assert_true(
    @json.parse(json_evidence_export(stale))
    is { "prepared_revision_id": Null, .. },
  )
  let large = json_records_source(
    "[\"" + Array::makei(32500, _ => "x").join("") + "\"]",
  )
  let full = {
    ..view,
    draft: {
      ..view.draft,
      sources: view.draft.sources + [large, large, large, large],
    },
  }
  assert_true(
    full.draft.sources.fold(init=0, (n, source) => {
      n + source.content_hex.length()
    }) <=
    262144,
  )
  let rejected = json_records_apply(full, Add)
  assert_true(rejected.error.unwrap().contains("128 KiB"))
  assert_eq(rejected.draft, full.draft)
  json_records_evidence("saved-extract.json", exported)
}
