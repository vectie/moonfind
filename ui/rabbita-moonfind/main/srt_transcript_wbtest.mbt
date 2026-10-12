///|
fn srt_test_text() -> String {
  "\u{FEFF}007\r\n00:00:01,200 --> 00:00:04,500\r\nGarcía: Clinic handoffs take too long 🌒.\r\nWe copy the same notes.\r\n\r\n42\r\n00:00:03,000 --> 00:00:06,100\r\nResearcher: How long?\r\n\r\n42\r\n00:00:06,100 --> 00:00:09,050\r\n<v García>Clinic handoffs take five minutes. <script>literal</script>\r\n\r\n9007199254740993\r\n00:00:10,000 --> 00:00:12,000\r\nThe school has no such issue.\r\n"
}

///|
fn srt_test_source(text : String) -> BriefInputSource {
  {
    name: "interview.srt.txt",
    origin: "User-selected timed transcript: interview.srt; exact original bytes retained as interview.srt.txt",
    captured_at: "2026-10-10T20:00:00Z",
    kind: "local-file",
    content_hex: brief_text_hex(text),
  }
}

///|
fn srt_test_fixture() -> BriefView {
  let view = {
    ..initial_brief_view(),
    draft: { ..brief_fixture_draft(), sources: [], },
  }
  transcript_test_apply(
    view,
    FileLoaded(
      view.generation,
      ({ "source": ToJson::to_json(srt_test_source(srt_test_text())) } : Json).stringify(),
    ),
  )
}

///|
extern "js" fn srt_test_evidence(name : String, content : String) -> Unit =
  #|(name,content)=>{if(process.env.MOONFIND_SRT_EVIDENCE)process.getBuiltinModule('fs').writeFileSync(process.env.MOONFIND_SRT_EVIDENCE+'/'+name,content);}

///|
test "SRT imports exact UTF8 BOM CRLF and retains identifiers overlap source lines and literal payload" {
  let source = srt_test_source(srt_test_text())
  let capture = transcript_capture(source)
  assert_eq(capture.format, "subrip")
  assert_eq(capture.ignored_blocks, 0)
  assert_eq(capture.cues.length(), 4)
  assert_eq(capture.cues.map(cue => cue.number), [1, 2, 3, 4])
  assert_eq(capture.cues.map(cue => cue.identifier), [
    "007", "42", "42", "9007199254740993",
  ])
  assert_eq(capture.cues.map(cue => cue.line), [2, 7, 11, 15])
  assert_eq(capture.cues.map(cue => cue.start_ms), [1200, 3000, 6100, 10000])
  assert_eq(capture.cues.map(cue => cue.end_ms), [4500, 6100, 9050, 12000])
  assert_eq(capture.cues[0].timing, "00:00:01,200 --> 00:00:04,500")
  assert_eq(
    capture.cues[0].text,
    "García: Clinic handoffs take too long 🌒.\nWe copy the same notes.",
  )
  assert_true(capture.cues.all(cue => cue.speaker.is_empty()))
  assert_eq(brief_source_preview(source.content_hex), srt_test_text())
  let hour = transcript_capture(
    srt_test_source("1\n00:59:59,999 --> 01:00:00,001\nBoundary\n"),
  )
  assert_eq(hour.cues[0].start_ms, 3599999)
  assert_eq(hour.cues[0].end_ms, 3600001)
  let carriage_return = transcript_capture(
    srt_test_source("1\r00:00:00,000 --> 00:00:01,000\rText\r"),
  )
  assert_eq(carriage_return.cues[0].line, 2)
  assert_eq(
    transcript_capture(transcript_test_source(transcript_test_text())).format,
    "webvtt",
  )
  srt_test_evidence("original-interview.srt", srt_test_text())
  srt_test_evidence(
    "parsed-srt.json",
    ToJson::to_json(capture).stringify(indent=2),
  )
}

///|
test "SRT rejects unsupported timing incomplete blocks and malformed later cues without partial intake" {
  let view = transcript_test_apply(srt_test_fixture(), SelectMatching)
  for
    text in [
      "1", "1\n00:00:00,000 --> 00:00:01,000", "one\n00:00:00,000 --> 00:00:01,000\ntext",
      "1\n00:00.000 --> 00:01.000\ntext", "1\n00:00:00.000 --> 00:00:01.000\ntext",
      "1\n00:60:00,000 --> 01:01:00,000\ntext", "1\n00:00:00,000 --> 100:00:00,000\ntext",
      "1\n00:00:01,000 --> 00:00:01,000\ntext", "1\n00:00:02,000 --> 00:00:01,000\ntext",
      "1\n00:00:00,000 --> 00:00:01,000 X1:1\ntext", "1\n00:00:00,000 --> 00:00:01,000\ntext\n2\n00:00:01,000 --> 00:00:02,000\ntext",
      "1\n00:00:02,000 --> 00:00:03,000\ntext\n\n2\n00:00:01,000 --> 00:00:02,000\ntext",
      "1\n00:00:00,000 --> 00:00:01,000\ntext\n\nNOTE omitted evidence",
    ] {
    assert_true(transcript_test_rejected(text), msg=text)
    let failed = transcript_test_apply(
      view,
      FileLoaded(
        view.generation,
        ({ "source": ToJson::to_json(srt_test_source(text)) } : Json).stringify(),
      ),
    )
    assert_eq(failed.draft, view.draft)
    assert_eq(failed.transcript, view.transcript)
    assert_true(failed.error is Some(_))
  }
}

///|
test "SRT searches and selects hidden quotations with source-order reports and prepared provenance" {
  let view = srt_test_fixture()
  let selected = transcript_test_apply(
    transcript_test_apply(
      transcript_test_apply(view, Search("  CLINIC  ")),
      Toggle(3),
    ),
    SelectMatching,
  )
  assert_eq(selected.transcript.selected, [3, 1])
  let hidden = transcript_test_apply(selected, Search("school"))
  assert_eq(transcript_matching(hidden.transcript).map(cue => cue.number), [4])
  assert_eq(transcript_selected(hidden.transcript).map(cue => cue.number), [
    1, 3,
  ])
  assert_eq(
    transcript_matching(transcript_test_apply(hidden, Search("42")).transcript).map(cue => {
        cue.number
      },
    ),
    [2, 3],
  )
  assert_eq(
    transcript_matching(
      transcript_test_apply(hidden, Search("00:00:03,000")).transcript,
    ).map(cue => cue.number),
    [2],
  )
  let source = view.draft.sources[0]
  let digest = json_records_digest(source.content_hex)
  let prepared = {
    ..hidden,
    opened: Some({
      contract_id: "moonfind.brief-status.v1",
      brief_id: view.draft.brief_id,
      revision_id: "revision-srt",
      state: "prepared",
      issues: [],
      snapshot: Some({
        contract_id: "moonfind.brief-snapshot.v1",
        revision_id: "revision-srt",
        state: "prepared",
        brief: view.draft,
        sources: [
          {
            slot: 1,
            name: source.name,
            origin: source.origin,
            captured_at: source.captured_at,
            kind: source.kind,
            availability: "retained-local-capture",
            archive_path: "sources/source-1.txt",
            byte_count: source.content_hex.length() / 2,
            digest,
          },
        ],
        boundary: "Synthetic host snapshot",
      }),
    }),
  }
  let report = transcript_report(prepared)
  assert_true(report.contains("Local SubRip (SRT) text only"))
  assert_true(report.contains("\"source_format\": \"subrip\""))
  assert_true(report.contains("\"source_line\":11"))
  assert_true(report.contains("\"identifier\":\"007\""))
  assert_true(report.contains(digest))
  assert_true(report.contains("    <v García>Clinic"))
  assert_false(report.contains("How long?"))
  assert_false(report.contains("school has"))
  let edited = update_brief_view(
      _ => @rabbita.none,
      Edit("question", "A revised decision"),
      prepared,
    ).1
  assert_true(
    transcript_report(edited).contains("\"host_recorded_digest\": null"),
  )
  assert_eq(edited.draft.parent_revision, Some("revision-srt"))
  srt_test_evidence("prepared-srt-excerpts.md", report)
}

///|
test "SRT quotation sources persist and reopen beside unchanged originals and discard stale callbacks" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = transcript_test_apply(
    transcript_test_apply(srt_test_fixture(), Search("clinic")),
    SelectMatching,
  )
  let expected = transcript_report(view)
  let added = transcript_test_apply(view, Add)
  assert_eq(added.draft.sources.length(), 2)
  assert_eq(added.draft.sources[0], view.draft.sources[0])
  assert_eq(brief_source_preview(added.draft.sources[1].content_hex), expected)
  assert_eq(added.transcript.selected, [])
  assert_eq(transcript_test_apply(added, Add).draft, added.draft)
  assert_eq(initial_brief_view().draft, added.draft)
  let reopened = update_brief_view(
      _ => @rabbita.none,
      Loaded(
        8,
        added.draft.brief_id,
        "revision-srt",
        Ok(brief_fixture_reply(added.draft, "revision-srt")),
      ),
      { ..added, generation: 8, pending: true, },
    ).1
  assert_eq(reopened.draft, added.draft)
  assert_eq(reopened.transcript, empty_transcript_view())
  assert_eq(
    transcript_test_apply(reopened, Open(1)).transcript.capture,
    view.transcript.capture,
  )
  let raw = (
    { "source": ToJson::to_json(srt_test_source(srt_test_text())) } : Json).stringify()
  assert_eq(
    transcript_test_apply(added, FileLoaded(added.generation - 1, raw)).draft,
    added.draft,
  )
  assert_eq(
    transcript_test_apply(
      { ..added, pending: true, },
      FileLoaded(added.generation, raw),
    ).draft,
    added.draft,
  )
  assert_eq(
    transcript_test_apply(
      added,
      FileLoaded(added.generation, "{\"cancelled\":true}"),
    ).draft,
    added.draft,
  )
  assert_eq(
    update_brief_view(_ => @rabbita.none, RemoveSource(0), added).1.transcript,
    empty_transcript_view(),
  )
  srt_test_evidence(
    "added-srt-brief.json",
    ToJson::to_json(added.draft).stringify(indent=2),
  )
  srt_test_evidence(
    "reopened-srt-brief.json",
    ToJson::to_json(reopened.draft).stringify(indent=2),
  )
  srt_test_evidence("selected-srt-excerpts.md", expected)
}

///|
test "SRT keeps source limits and fails atomic import when brief has no available source slot" {
  let cues = Array::makei(512, index => {
    index.to_string() + "\n00:00:00,000 --> 00:00:01,000\nx\n\n"
  }).join("")
  assert_eq(transcript_capture(srt_test_source(cues)).cues.length(), 512)
  assert_true(
    transcript_test_rejected(cues + "513\n00:00:00,000 --> 00:00:01,000\nx\n"),
  )
  let prefix = "1\n00:00:00,000 --> 00:00:01,000\n"
  let exact = prefix + Array::makei(32768 - prefix.length(), _ => "x").join("")
  assert_eq(transcript_capture(srt_test_source(exact)).cues.length(), 1)
  assert_true(transcript_test_rejected(exact + "x"))
  let view = srt_test_fixture()
  let full = {
    ..view,
    draft: {
      ..view.draft,
      sources: Array::makei(8, _ => view.draft.sources[0]),
    },
  }
  let failed = transcript_test_apply(
    full,
    FileLoaded(
      full.generation,
      ({ "source": ToJson::to_json(srt_test_source(srt_test_text())) } : Json).stringify(),
    ),
  )
  assert_eq(failed.draft, full.draft)
  assert_eq(failed.transcript, full.transcript)
  assert_true(failed.error.unwrap().contains("source slot"))
}

///|
extern "js" fn srt_picker_exercise(
  pick : ((String) -> Unit) -> Unit,
  consume : (String) -> String,
  text : String,
) -> Unit =
  #|(pick,consume,text)=>{
  #| const old=Object.getOwnPropertyDescriptor(globalThis,'document');
  #| const modes=['srt','uppercase','txt','cancel','invalid-utf8','malformed-second-cue'];let completed=0;
  #| try{for(const mode of modes){
  #|  const name=mode==='uppercase'?'interview.SRT':mode==='txt'?'interview.txt':'interview.srt';
  #|  const bytes=mode==='invalid-utf8'?new Uint8Array([255]):mode==='malformed-second-cue'?text+'\r\nwrong\r\n00:00:20,000 --> 00:00:21,000\r\nbroken':text;
  #|  Object.defineProperty(globalThis,'document',{configurable:true,value:{createElement(tag){
  #|   if(tag!=='input')throw Error('Expected input');const handlers={};
  #|   return {files:[new File([bytes],name)],addEventListener(type,fn){handlers[type]=fn;},click(){if(this.type!=='file'||this.multiple!==false||this.accept!=='.vtt,.srt,.txt')throw Error('Picker wiring');if(mode==='cancel')handlers.cancel();else handlers.change();}};
  #|  }}});
  #|  pick(raw=>{try{const reply=JSON.parse(raw);if(mode==='cancel'){if(!reply.cancelled)throw Error('Cancellation not preserved');}else if(mode==='invalid-utf8'){if(!reply.error)throw Error('Invalid UTF8 accepted');}else{const receipt=JSON.parse(consume(raw));if(mode==='malformed-second-cue'){if(receipt.sources!==0||!receipt.error)throw Error('Partial malformed import');}else{if(receipt.sources!==1||receipt.format!=='subrip'||receipt.hex!==Buffer.from(text).toString('hex'))throw Error('Picker/reducer byte mismatch');if(receipt.name!==name+(mode==='txt'?'':'.txt')||!reply.source.origin.includes(name))throw Error('Original filename lost');if(process.env.MOONFIND_SRT_EVIDENCE)process.getBuiltinModule('fs').writeFileSync(process.env.MOONFIND_SRT_EVIDENCE+'/picker-'+mode+'.json',raw);}}completed++;}catch(error){console.error(error);process.exitCode=1;}});
  #| }}finally{if(old)Object.defineProperty(globalThis,'document',old);else delete globalThis.document;}
  #| process.once('beforeExit',()=>{if(completed!==modes.length){console.error('Incomplete SRT picker callbacks',completed);process.exitCode=1;}if(process.env.MOONFIND_SRT_EVIDENCE)process.getBuiltinModule('fs').writeFileSync(process.env.MOONFIND_SRT_EVIDENCE+'/srt-picker-receipt.json',JSON.stringify({cases:modes,completed,real_file_blob:true,production_reducer:true},null,2));});
  #|}

///|
test "SRT real File picker feeds production reducer and preserves extension mapping and interrupted import" {
  let empty = {
    ..initial_brief_view(),
    draft: { ..brief_fixture_draft(), sources: [], },
  }
  srt_picker_exercise(
    transcript_choose,
    raw => {
      let view = transcript_test_apply(empty, FileLoaded(empty.generation, raw))
      let receipt : Json = {
        "sources": view.draft.sources.length(),
        "error": view.error,
        "format": view.transcript.capture
        .map(capture => capture.format)
        .unwrap_or(""),
        "name": view.draft.sources
        .get(0)
        .map(source => source.name)
        .unwrap_or(""),
        "hex": view.draft.sources
        .get(0)
        .map(source => source.content_hex)
        .unwrap_or(""),
      }
      receipt.stringify()
    },
    srt_test_text(),
  )
}

///|
extern "js" fn srt_test_blob(expected : String) -> String =
  #|expected=>{
  #| const got=globalThis.__numericDownload;
  #| if(!got.clicked||got.name!=='moonfind-transcript-excerpts.md'||!(got.blob instanceof Blob)||got.blob.type!=='text/markdown;charset=utf-8')return 'SRT download metadata mismatch';
  #| got.blob.text().then(text=>{if(text!==expected)throw Error('SRT Blob mismatch');if(process.env.MOONFIND_SRT_EVIDENCE){const fs=process.getBuiltinModule('fs'),dir=process.env.MOONFIND_SRT_EVIDENCE;fs.writeFileSync(dir+'/'+got.name,text);fs.writeFileSync(dir+'/srt-download-receipt.json',JSON.stringify({filename:got.name,mime:got.blob.type,bytes:got.blob.size,sha256:process.getBuiltinModule('crypto').createHash('sha256').update(text).digest('hex'),real_blob:true},null,2));}}).catch(error=>{console.error(error);process.exitCode=1;});return '';
  #|}

///|
test "SRT renders literal quotation evidence and downloads real Blob with retry and repeat preserved selection" {
  let view = transcript_test_apply(
    transcript_test_apply(srt_test_fixture(), Search("clinic")),
    SelectMatching,
  )
  let model = { ..initial_model(), brief: view, }
  let html = qa_test_render(model)
  for
    text in [
      "Import WebVTT / SRT transcript", "source line 11", "00:00:06,100", "subrip",
      "&lt;script&gt;literal&lt;/script&gt;", "interview.srt.txt",
    ] {
    assert_true(html.contains(text), msg=text)
  }
  assert_false(html.contains("<script>literal</script>"))
  srt_test_evidence("rendered-srt.html", html)
  for mode in ["click", "ok", "ok"] {
    csv_numeric_blob_fixture(mode)
    let after = update(
        _ => @rabbita.none,
        BriefAction(Transcript(Download)),
        model,
      ).1.brief
    assert_eq(after.draft, view.draft)
    assert_eq(after.transcript, view.transcript)
    if mode == "ok" {
      assert_eq(after.error, None)
      assert_eq(srt_test_blob(transcript_report(view)), "")
    } else {
      assert_true(after.error.unwrap().contains("download failed"))
    }
    csv_numeric_blob_restore()
  }
}
