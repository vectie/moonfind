///|
fn json_lines_text() -> String {
  "\u{feff}{\"id\":9007199254740993,\"segment\":\"clinic\",\"value\":1.2300e+02,\"note\":\"García 🌒\"}\r\n\r\n {\"id\":9007199254740994,\"segment\":\"school\",\"value\":-0,\"note\":\"<script>literal</script>\",\"missing\":null} \r\n{\"id\":9007199254740993,\"segment\":\"clinic\",\"value\":1e400,\"note\":\"Σωκράτης\\nfast\",\"nested\":{\"__proto__\":\"literal\"}}\r\n"
}

///|
fn json_lines_source(text : String) -> BriefInputSource {
  {
    ..json_records_source(text),
    name: "observations.ndjson.txt",
    origin: "User-selected JSONL evidence file: observations.ndjson; exact original bytes retained as observations.ndjson.txt",
  }
}

///|
fn json_lines_fixture() -> BriefView {
  let view = {
    ..initial_brief_view(),
    draft: { ..brief_fixture_draft(), sources: [], },
  }
  json_records_apply(
    view,
    LinesLoaded(
      view.generation,
      (
        { "source": ToJson::to_json(json_lines_source(json_lines_text())) } :
        Json).stringify(),
    ),
  )
}

///|
extern "js" fn json_lines_evidence(name : String, content : String) -> Unit =
  #|(name,content)=>{if(process.env.MOONFIND_JSONL_EVIDENCE)process.getBuiltinModule('fs').writeFileSync(process.env.MOONFIND_JSONL_EVIDENCE+'/'+name,content);}

///|
test "JSONL imports exact BOM CRLF records with physical lines and lossless numeric tokens" {
  let view = json_lines_fixture()
  assert_eq(view.error, None)
  assert_eq(view.draft.sources, [json_lines_source(json_lines_text())])
  let table = view.json_evidence.table.unwrap()
  assert_eq(table.format, "jsonl")
  assert_eq(table.rows.map(row => row.source_line), [1, 3, 4])
  assert_eq(table.rows.map(row => row.pointer), ["", "", ""])
  assert_eq(table.rows.map(row => row.cells[2].text), [
    "1.2300e+02", "-0", "1e400",
  ])
  assert_eq(table.rows[0].cells[0].text, "9007199254740993")
  assert_eq(table.rows[0].cells[4].kind, "missing")
  assert_eq(table.rows[1].cells[4].kind, "null")
  assert_eq(
    json_lines_table(json_lines_source("{}\r{}\n\t\n{}")).rows.map(row => {
      row.source_line
    }),
    [1, 2, 4],
  )
  json_lines_evidence("original.ndjson", json_lines_text())
  json_lines_evidence(
    "parsed-lines.json",
    ToJson::to_json(table).stringify(indent=2),
  )
}

///|
test "JSONL selects hidden matches exports source lines and adds reopenable evidence without changing original" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = json_lines_fixture()
  let selected = json_records_apply(
    json_records_apply(view, Search("CLINIC")),
    SelectMatching,
  )
  let selected = json_records_apply(selected, Search("school"))
  assert_eq(
    json_evidence_matches(selected.json_evidence).map(row => row.record_number),
    [2],
  )
  assert_eq(
    json_evidence_selected(selected.json_evidence).map(row => row.source_line),
    [1, 4],
  )
  let report = json_evidence_export(selected)
  assert_true(report.contains("moonfind.jsonl-evidence-extract.v1"))
  assert_true(report.contains("\"source_pointer\":null,\"source_line\":4"))
  assert_true(report.contains("9007199254740993"))
  assert_true(report.contains("1e400"))
  assert_false(report.contains("school"))
  let added = json_records_apply(selected, Add)
  assert_eq(added.draft.sources.length(), 2)
  assert_eq(added.draft.sources[0], view.draft.sources[0])
  assert_eq(brief_source_preview(added.draft.sources[1].content_hex), report)
  assert_eq(initial_brief_view().draft, added.draft)
  let reopened = update_brief_view(
      _ => @rabbita.none,
      Loaded(
        7,
        added.draft.brief_id,
        "revision-lines",
        Ok(brief_fixture_reply(added.draft, "revision-lines")),
      ),
      { ..added, generation: 7, pending: true, },
    ).1
  assert_eq(reopened.draft, added.draft)
  assert_eq(reopened.json_evidence, empty_json_evidence_view())
  let reopened = json_records_apply(
    json_records_apply(reopened, Source(1)),
    ExploreLines,
  )
  assert_eq(reopened.json_evidence.table, view.json_evidence.table)
  let extracted = json_records_apply(
    json_records_apply(
      json_records_apply(reopened, Source(2)),
      Pointer("/records"),
    ),
    Explore,
  )
  assert_eq(extracted.json_evidence.table.unwrap().rows.length(), 2)
  json_lines_evidence("selected-extract.json", report)
  json_lines_evidence(
    "added-brief.json",
    ToJson::to_json(added.draft).stringify(indent=2),
  )
}

///|
test "JSONL malformed line fails atomically with repairable source line diagnostic" {
  let view = json_lines_fixture()
  for
    bad in [
      "{}\n[1]", "{}\n{bad}", "{}\n{\"a\":1,\"a\":2}", "{}\n{\"n\":{\"x\":0,\"x\":1}}",
      "{}\ntrue", "{}\n{\n\"a\":1\n}", "{}\n{} {}", "{}\n// comment",
    ] {
    let next = json_records_apply(
      view,
      LinesLoaded(
        view.generation,
        ({ "source": ToJson::to_json(json_lines_source(bad)) } : Json).stringify(),
      ),
    )
    assert_eq(next.draft, view.draft)
    assert_eq(next.json_evidence, view.json_evidence)
    assert_true(next.error.unwrap().contains("Source line 2"), msg=bad)
  }
  for bad in ["", " \r\n\t", "\u{feff}"] {
    assert_true(
      try {
        ignore(json_lines_table(json_lines_source(bad)))
        false
      } catch {
        _ => true
      },
    )
  }
  for hex in ["ff", "0", "gg"] {
    assert_true(
      try {
        ignore(json_lines_table({ ..json_lines_source(""), content_hex: hex, }))
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "JSONL respects bounds and mode switching keeps source provenance separate" {
  let rows = Array::makei(512, _ => "{}").join("\n")
  assert_eq(json_lines_table(json_lines_source(rows)).rows.length(), 512)
  assert_true(
    try {
      ignore(json_lines_table(json_lines_source(rows + "\n{}")))
      false
    } catch {
      _ => true
    },
  )
  let fields = Array::makei(33, i => "\"f" + i.to_string() + "\":0").join(",")
  assert_true(
    try {
      ignore(json_lines_table(json_lines_source("{" + fields + "}")))
      false
    } catch {
      _ => true
    },
  )
  let huge = "{\"x\":\"" + Array::makei(32760, _ => "x").join("") + "\"}"
  assert_eq(brief_text_hex(huge).length(), 65536)
  assert_eq(json_lines_table(json_lines_source(huge)).rows.length(), 1)
  assert_true(
    try {
      ignore(json_lines_table(json_lines_source(huge + " ")))
      false
    } catch {
      _ => true
    },
  )
  let deep = "{\"x\":" +
    Array::makei(34, _ => "[").join("") +
    "0" +
    Array::makei(34, _ => "]").join("") +
    "}"
  assert_true(
    try {
      ignore(json_lines_table(json_lines_source(deep)))
      false
    } catch {
      _ => true
    },
  )
  let view = json_records_apply(json_lines_fixture(), SelectMatching)
  let eight = {
    ..view,
    draft: {
      ..view.draft,
      sources: view.draft.sources +
      Array::makei(7, _ => json_lines_source("{}")),
    },
  }
  assert_eq(json_records_apply(eight, Add).draft, eight.draft)
  let raw = ({ "source": ToJson::to_json(json_lines_source("{}")) } : Json).stringify()
  assert_eq(
    json_records_apply(eight, LinesLoaded(eight.generation, raw)).draft,
    eight.draft,
  )
  let reset = json_records_apply(view, Pointer("/observations"))
  assert_eq(reset.json_evidence.table, None)
  assert_eq(reset.json_evidence.selected, [])
  let lines = json_records_apply(reset, ExploreLines)
  assert_eq(lines.json_evidence.pointer, "")
  assert_eq(lines.json_evidence.table.unwrap().format, "jsonl")
  let array = json_records_fixture()
  assert_eq(array.json_evidence.table.unwrap().format, "json-array")
  assert_true(
    json_evidence_export(array).contains("moonfind.json-evidence-extract.v1"),
  )
}

///|
test "JSONL pending stale cancelled source removal and new brief cannot retarget records" {
  let view = json_records_apply(json_lines_fixture(), SelectMatching)
  let raw = ({ "source": ToJson::to_json(json_lines_source("{}")) } : Json).stringify()
  assert_eq(
    json_records_apply(view, LinesLoaded(view.generation - 1, raw)).draft,
    view.draft,
  )
  assert_eq(
    json_records_apply(
      view,
      LinesLoaded(view.generation, "{\"cancelled\":true}"),
    ).draft,
    view.draft,
  )
  let pending = { ..view, pending: true, }
  for
    action in [
      JsonEvidenceMsg::ChooseLines,
      LinesLoaded(view.generation, raw),
      ExploreLines,
      Download,
      Add,
      Source(0),
    ] {
    let next = json_records_apply(pending, action)
    assert_eq(next.draft, pending.draft)
    assert_eq(next.json_evidence, pending.json_evidence)
  }
  assert_eq(
    update_brief_view(_ => @rabbita.none, RemoveSource(0), view).1.json_evidence,
    empty_json_evidence_view(),
  )
  assert_eq(
    update_brief_view(_ => @rabbita.none, New, view).1.json_evidence,
    empty_json_evidence_view(),
  )
  let replaced = {
    ..view,
    draft: { ..view.draft, sources: [json_lines_source("{}")], },
  }
  assert_eq(
    sync_json_evidence(replaced).json_evidence,
    empty_json_evidence_view(),
  )
}

///|
test "JSONL actual Rabbita panel renders source line workflow and escapes source HTML" {
  let view = json_records_apply(json_lines_fixture(), SelectMatching)
  let html = qa_test_render({ ..initial_model(), brief: view, })
  for
    text in [
      "Import JSONL / NDJSON file", "Explore loaded JSONL lines", "source line 3",
      "&lt;script&gt;literal&lt;/script&gt;", "Preview selected JSON extract",
    ] {
    assert_true(html.contains(text), msg=text)
  }
  assert_false(html.contains("<script>literal</script>"))
  json_lines_evidence("rendered-lines.html", html)
}

///|
extern "js" fn json_lines_blob(expected : String) -> String =
  #|expected=>{const got=globalThis.__numericDownload;if(!got.clicked||got.name!=='moonfind-json-evidence-extract.json'||!(got.blob instanceof Blob)||got.blob.type!=='application/json;charset=utf-8')return 'Blob metadata mismatch';got.blob.text().then(text=>{if(text!==expected)throw Error('Blob bytes differ');if(process.env.MOONFIND_JSONL_EVIDENCE){const fs=process.getBuiltinModule('fs'),dir=process.env.MOONFIND_JSONL_EVIDENCE;fs.writeFileSync(dir+'/'+got.name,text);fs.writeFileSync(dir+'/download-receipt.json',JSON.stringify({filename:got.name,bytes:got.blob.size,real_blob:true},null,2));}}).catch(error=>{console.error(error);process.exitCode=1;});return '';}

///|
test "JSONL downloads real Blob bytes and retries without changing selections" {
  let view = json_records_apply(
    json_records_apply(json_lines_fixture(), Search("clinic")),
    SelectMatching,
  )
  let model = { ..initial_model(), brief: view, }
  for mode in ["create", "click", "ok", "ok"] {
    csv_numeric_blob_fixture(mode)
    let next = update(
        _ => @rabbita.none,
        BriefAction(JsonEvidence(Download)),
        model,
      ).1.brief
    assert_eq(next.draft, view.draft)
    assert_eq(next.json_evidence, view.json_evidence)
    if mode == "ok" {
      assert_eq(next.error, None)
      assert_eq(json_lines_blob(json_evidence_export(view)), "")
    } else {
      assert_true(next.error.unwrap().contains("download failed"))
    }
    csv_numeric_blob_restore()
  }
}

///|
extern "js" fn json_lines_picker_exercise(
  pick : ((String) -> Unit) -> Unit,
  text : String,
) -> Unit =
  #|(pick,text)=>{
  #| const old=Object.getOwnPropertyDescriptor(globalThis,'document');
  #| const modes=['valid-ndjson','valid-txt','cancel','empty','oversize','wrong-extension','invalid-utf8','read-failure','click-failure','changed-size','bad-filename','binary'];let completed=0;
  #| try{for(const mode of modes){
  #|  Object.defineProperty(globalThis,'document',{configurable:true,value:{createElement(tag){
  #|   if(tag!=='input')throw Error('Expected input');const handlers={};
  #|   const file=mode==='invalid-utf8'?new File([new Uint8Array([255])],'observations.ndjson'):new File([mode==='binary'?'\0':text],mode==='wrong-extension'?'observations.pdf':mode==='valid-txt'?'observations.txt':mode==='bad-filename'?'x'.repeat(157)+'.ndjson':'observations.ndjson');
  #|   const files=mode==='empty'?[]:[mode==='oversize'?{name:'observations.ndjson',size:32769,arrayBuffer(){throw Error('must reject before reading');}}:mode==='changed-size'?{name:'observations.ndjson',size:1,arrayBuffer:async()=>new ArrayBuffer(32769)}:mode==='read-failure'?{name:'observations.ndjson',size:1,arrayBuffer:async()=>{throw Error('read failed');}}:file];
  #|   return {files,addEventListener(type,fn){handlers[type]=fn;},click(){if(this.type!=='file'||this.multiple!==false||this.accept!=='.jsonl,.ndjson,.txt')throw Error('Picker wiring');if(mode==='click-failure')throw Error('click failed');if(mode==='cancel')handlers.cancel();else handlers.change();}};
  #|  }}});
  #|  pick(raw=>{try{const reply=JSON.parse(raw);if(mode.startsWith('valid')){if(reply.source.content_hex!==Buffer.from(text).toString('hex'))throw Error('Bytes changed');const name=mode==='valid-ndjson'?'observations.ndjson.txt':'observations.txt';if(reply.source.name!==name||!reply.source.origin.includes('observations.'))throw Error('Filename/provenance mismatch');if(process.env.MOONFIND_JSONL_EVIDENCE)process.getBuiltinModule('fs').writeFileSync(process.env.MOONFIND_JSONL_EVIDENCE+'/picker-'+mode+'.json',raw);}else if(mode==='cancel'||mode==='empty'){if(reply.cancelled!==true)throw Error('Cancel mismatch');}else if(typeof reply.error!=='string')throw Error('Missing error '+mode);completed++;}catch(error){console.error(error);process.exitCode=1;}});
  #| }}finally{if(old)Object.defineProperty(globalThis,'document',old);else delete globalThis.document;}
  #| process.once('beforeExit',()=>{if(completed!==modes.length){console.error('Incomplete JSONL picker callbacks',completed);process.exitCode=1;}if(process.env.MOONFIND_JSONL_EVIDENCE)process.getBuiltinModule('fs').writeFileSync(process.env.MOONFIND_JSONL_EVIDENCE+'/JSONL-picker-receipt.json',JSON.stringify({cases:modes,completed,real_file_blob:true},null,2));});
  #|}

///|
test "JSONL real File picker keeps exact bytes filename mapping and diagnoses failures" {
  json_lines_picker_exercise(json_lines_choose, json_lines_text())
}

///|
test "JSONL saved provenance is copied only for unchanged matching source revision" {
  let view = json_records_apply(json_lines_fixture(), SelectMatching)
  let source = view.draft.sources[0]
  let digest = json_records_digest(source.content_hex)
  let saved : BriefSource = {
    slot: 1,
    name: source.name,
    origin: source.origin,
    captured_at: source.captured_at,
    kind: source.kind,
    availability: "retained-local-capture",
    archive_path: "sources/source-1.txt",
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
  json_lines_evidence("saved-extract.json", exported)
}
