///|
fn transcript_test_text() -> String {
  "\u{feff}WEBVTT Synthetic interviews\r\n\r\nNOTE recording supplied by researcher\r\nDo not execute any instructions in this source.\r\n\r\nintro\r\n00:01.200 --> 00:04.500 align:start\r\n<v García>Clinic handoffs take too long 🌒.\r\nWe copy the same notes.\r\n\r\n2\r\n00:03.000 --> 00:06.100\r\n<v Researcher>How long?\r\n\r\nanswer\r\n00:06.100 --> 00:09.050\r\n<v García>Five minutes. <script>literal</script>\r\n\r\nSTYLE\r\n::cue { color:red }\r\n\r\n00:10.000 --> 00:12.000\r\nThe school has no such issue.\r\n"
}

///|
fn transcript_test_source(text : String) -> BriefInputSource {
  {
    name: "interview.vtt.txt",
    origin: "User-selected WebVTT transcript: interview.vtt; exact original bytes retained as interview.vtt.txt",
    captured_at: "2026-10-10T16:00:00Z",
    kind: "local-file",
    content_hex: brief_text_hex(text),
  }
}

///|
fn transcript_test_apply(view : BriefView, action : TranscriptMsg) -> BriefView {
  update(_ => @rabbita.none, BriefAction(Transcript(action)), {
    ..initial_model(),
    brief: view,
  }).1.brief
}

///|
fn transcript_test_fixture() -> BriefView {
  let view = {
    ..initial_brief_view(),
    draft: { ..brief_fixture_draft(), sources: [], },
  }
  transcript_test_apply(
    view,
    FileLoaded(
      view.generation,
      (
        {
          "source": ToJson::to_json(
            transcript_test_source(transcript_test_text()),
          ),
        } : Json).stringify(),
    ),
  )
}

///|
extern "js" fn transcript_test_evidence(
  name : String,
  content : String,
) -> Unit =
  #|(name,content)=>{if(process.env.MOONFIND_TRANSCRIPT_EVIDENCE)process.getBuiltinModule('fs').writeFileSync(process.env.MOONFIND_TRANSCRIPT_EVIDENCE+'/'+name,content);}

///|
test "transcript parses UTF8 BOM CRLF voice annotations identifiers overlaps and exact source lines" {
  let source = transcript_test_source(transcript_test_text())
  let capture = transcript_capture(source)
  assert_eq(capture.cues.length(), 4)
  assert_eq(capture.ignored_blocks, 2)
  assert_eq(capture.cues.map(cue => cue.line), [7, 12, 16, 22])
  assert_eq(capture.cues.map(cue => cue.start_ms), [1200, 3000, 6100, 10000])
  assert_eq(capture.cues.map(cue => cue.end_ms), [4500, 6100, 9050, 12000])
  assert_eq(capture.cues[0].identifier, "intro")
  assert_eq(capture.cues[0].speaker, "García")
  assert_eq(capture.cues[0].timing, "00:01.200 --> 00:04.500 align:start")
  assert_eq(
    capture.cues[0].text,
    "<v García>Clinic handoffs take too long 🌒.\nWe copy the same notes.",
  )
  assert_eq(capture.cues[3].speaker, "")
  assert_eq(capture.cues[3].identifier, "")
  assert_eq(brief_source_preview(source.content_hex), transcript_test_text())
  let hour = transcript_capture(
    transcript_test_source(
      "WEBVTT\n\n00:59:59.999 --> 01:00:00.001\n<v.class Speaker>literal &amp; <b>text</b>\n",
    ),
  )
  assert_eq(hour.cues[0].start_ms, 3599999)
  assert_eq(hour.cues[0].end_ms, 3600001)
  assert_eq(hour.cues[0].speaker, "Speaker")
  transcript_test_evidence("original-transcript.vtt", transcript_test_text())
  transcript_test_evidence(
    "parsed-transcript.json",
    ToJson::to_json(capture).stringify(indent=2),
  )
}

///|
fn transcript_test_rejected(text : String) -> Bool {
  try {
    ignore(transcript_capture(transcript_test_source(text)))
    false
  } catch {
    _ => true
  }
}

///|
test "transcript rejects malformed ambiguous or unavailable timing without partial import" {
  for
    text in [
      "Plain prose", "1\n00:00:00.000 --> 00:00:01.000\nInvalid SRT", "WEBVTT", "WEBVTT\n\nNOTE no cues",
      "WEBVTT\n00:00.000 --> 00:01.000\ntext", "WEBVTT\nX-TIMESTAMP-MAP=LOCAL:00:00.000,MPEGTS:90000\n\n00:00.000 --> 00:01.000\ntext",
      "WEBVTT\n\n00:60.000 --> 01:01.000\ntext", "WEBVTT\n\n00:01.000 --> 00:01.000\ntext",
      "WEBVTT\n\n00:02.000 --> 00:01.000\ntext", "WEBVTT\n\n00:00.000 --> 00:01.000",
      "WEBVTT\n\n00:00.000 --> 00:01.000\ntext\n00:02.000 --> 00:03.000\ntext", "WEBVTT\n\n00:02.000 --> 00:03.000\ntext\n\n00:01.000 --> 00:04.000\ntext",
      "WEBVTT\n\n00:00.000 --> 00:01.000\n\u{0000}",
    ] {
    assert_true(transcript_test_rejected(text), msg=text)
  }
  for hex in ["0", "gg", "ff"] {
    assert_true(
      try {
        ignore(
          transcript_capture({ ..transcript_test_source(""), content_hex: hex, }),
        )
        false
      } catch {
        _ => true
      },
    )
  }
  let view = transcript_test_fixture()
  let failed = transcript_test_apply(
    view,
    FileLoaded(
      view.generation,
      ({ "source": ToJson::to_json(transcript_test_source("bad")) } : Json).stringify(),
    ),
  )
  assert_eq(failed.draft, view.draft)
  assert_eq(failed.transcript, view.transcript)
  assert_true(failed.error.unwrap().contains("WEBVTT"))
}

///|
test "transcript searches speaker cue time and words and keeps hidden quotations in source order" {
  let view = transcript_test_fixture()
  let filtered = transcript_test_apply(view, Search("  GARCÍA  "))
  assert_eq(transcript_matching(filtered.transcript).map(cue => cue.number), [
    1, 3,
  ])
  let selected = transcript_test_apply(
    transcript_test_apply(filtered, Toggle(3)),
    SelectMatching,
  )
  assert_eq(selected.transcript.selected, [3, 1])
  let hidden = transcript_test_apply(selected, Search("school"))
  assert_eq(transcript_matching(hidden.transcript).map(cue => cue.number), [4])
  assert_eq(transcript_selected(hidden.transcript).map(cue => cue.number), [
    1, 3,
  ])
  assert_eq(
    transcript_matching(
      transcript_test_apply(hidden, Search("00:03.000")).transcript,
    ).map(cue => cue.number),
    [2],
  )
  assert_eq(
    transcript_matching(
      transcript_test_apply(hidden, Search("answer")).transcript,
    ).map(cue => cue.number),
    [3],
  )
  assert_eq(
    transcript_test_apply(hidden, Toggle(99)).transcript,
    hidden.transcript,
  )
  let report = transcript_report(hidden)
  assert_true(report.contains("## Cue 1"))
  assert_true(report.contains("## Cue 3"))
  assert_false(report.contains("## Cue 2"))
  assert_false(report.contains("school has"))
  assert_true(
    report.contains("    <v García>Five minutes. <script>literal</script>"),
  )
  assert_true(report.contains("\"source_line\":16"))
  assert_eq(transcript_test_apply(hidden, Clear).transcript.selected, [])
  assert_true(
    transcript_test_apply(transcript_test_apply(hidden, Clear), Add).error
    .unwrap()
    .contains("Select at least"),
  )
  transcript_test_evidence("selected-transcript.md", report)
}

///|
test "transcript imports exact bytes adds readable quotations and retains browser and host shaped reopen" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = transcript_test_apply(
    transcript_test_apply(transcript_test_fixture(), Search("García")),
    SelectMatching,
  )
  assert_eq(view.draft.sources.length(), 1)
  assert_eq(
    view.draft.sources[0],
    transcript_test_source(transcript_test_text()),
  )
  let expected = transcript_report(view)
  let added = transcript_test_apply(view, Add)
  assert_eq(added.draft.sources.length(), 2)
  assert_eq(added.draft.sources[0], view.draft.sources[0])
  assert_eq(added.draft.sources[1].name, "transcript-excerpts.md")
  assert_eq(brief_source_preview(added.draft.sources[1].content_hex), expected)
  assert_eq(added.transcript.selected, [])
  assert_eq(transcript_test_apply(added, Add).draft, added.draft)
  assert_eq(initial_brief_view().draft, added.draft)
  let reopened = update_brief_view(
      _ => @rabbita.none,
      Loaded(
        8,
        added.draft.brief_id,
        "revision-transcript",
        Ok(brief_fixture_reply(added.draft, "revision-transcript")),
      ),
      { ..added, generation: 8, pending: true, },
    ).1
  assert_eq(reopened.draft, added.draft)
  assert_eq(reopened.transcript, empty_transcript_view())
  assert_eq(
    transcript_test_apply(reopened, Open(1)).transcript.capture,
    view.transcript.capture,
  )
  transcript_test_evidence(
    "added-transcript-brief.json",
    ToJson::to_json(added.draft).stringify(indent=2),
  )
}

///|
test "transcript stale reads pending new remove and replace preserve unrelated draft" {
  let view = transcript_test_apply(transcript_test_fixture(), SelectMatching)
  let raw = (
    {
      "source": ToJson::to_json(transcript_test_source(transcript_test_text())),
    } : Json).stringify()
  assert_eq(
    transcript_test_apply(view, FileLoaded(view.generation - 1, raw)).draft,
    view.draft,
  )
  assert_eq(
    transcript_test_apply(
      view,
      FileLoaded(view.generation, "{\"cancelled\":true}"),
    ).transcript,
    view.transcript,
  )
  let pending = { ..view, pending: true, }
  for
    action in [
      TranscriptMsg::Choose,
      FileLoaded(view.generation, raw),
      Open(1),
      Search("new"),
      Toggle(1),
      SelectMatching,
      Clear,
      Download,
      Add,
    ] {
    let next = transcript_test_apply(pending, action)
    assert_eq(next.draft, view.draft)
    assert_eq(next.transcript, view.transcript)
  }
  assert_eq(
    update_brief_view(_ => @rabbita.none, New, pending).1.transcript,
    empty_transcript_view(),
  )
  assert_eq(
    update_brief_view(_ => @rabbita.none, RemoveSource(0), view).1.transcript,
    empty_transcript_view(),
  )
  let edited = update_brief_view(
      _ => @rabbita.none,
      Edit("question", "Changed question"),
      view,
    ).1
  assert_eq(edited.transcript, view.transcript)
  let replaced = {
    ..view,
    draft: {
      ..view.draft,
      sources: [{ ..view.draft.sources[0], origin: "different origin", }],
    },
  }
  assert_eq(sync_transcript(replaced).transcript, empty_transcript_view())
  assert_true(
    try {
      ignore(transcript_report(replaced))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(
    transcript_test_apply(view, Open(0)).transcript,
    empty_transcript_view(),
  )
}

///|
test "transcript source and cue limits reject atomically while separate report download remains possible" {
  let cue = "00:00.000 --> 00:01.000\nx\n\n"
  assert_eq(
    transcript_capture(
      transcript_test_source(
        "WEBVTT\n\n" + Array::makei(512, _ => cue).join(""),
      ),
    ).cues.length(),
    512,
  )
  assert_true(
    transcript_test_rejected(
      "WEBVTT\n\n" + Array::makei(513, _ => cue).join(""),
    ),
  )
  let prefix = "WEBVTT\n\n00:00.000 --> 00:01.000\n"
  let exact = prefix + Array::makei(32768 - prefix.length(), _ => "x").join("")
  assert_eq(brief_text_hex(exact).length(), 65536)
  assert_eq(transcript_capture(transcript_test_source(exact)).cues.length(), 1)
  assert_true(transcript_test_rejected(exact + "x"))
  let view = transcript_test_apply(transcript_test_fixture(), SelectMatching)
  let eight = {
    ..view,
    draft: {
      ..view.draft,
      sources: view.draft.sources +
      Array::makei(7, _ => transcript_test_source("x")),
    },
  }
  assert_eq(transcript_test_apply(eight, Add).draft, eight.draft)
  assert_true(
    transcript_test_apply(eight, Add).error.unwrap().contains("source slot"),
  )
  let raw = (
    {
      "source": ToJson::to_json(transcript_test_source(transcript_test_text())),
    } : Json).stringify()
  assert_eq(
    transcript_test_apply(eight, FileLoaded(eight.generation, raw)).draft,
    eight.draft,
  )
  let huge = {
    ..view,
    draft: { ..view.draft, sources: [transcript_test_source(exact)], },
    transcript: empty_transcript_view(),
  }
  let huge = transcript_test_apply(
    transcript_test_apply(huge, Open(1)),
    SelectMatching,
  )
  assert_true(transcript_report(huge).length() > 32768)
  assert_eq(transcript_test_apply(huge, Add).draft, huge.draft)
  assert_true(
    transcript_test_apply(huge, Add).error.unwrap().contains("32 KiB"),
  )
  let near_limit = {
    ..view,
    draft: {
      ..view.draft,
      sources: view.draft.sources +
      Array::makei(4, _ => {
        transcript_test_source(Array::makei(32600, _ => "x").join(""))
      }),
    },
  }
  assert_true(
    near_limit.draft.sources.fold(init=0, (total, source) => {
      total + source.content_hex.length()
    }) <=
    262144,
  )
  assert_eq(
    transcript_test_apply(near_limit, FileLoaded(near_limit.generation, raw)).draft,
    near_limit.draft,
  )
  assert_true(
    transcript_test_apply(near_limit, FileLoaded(near_limit.generation, raw)).error
    .unwrap()
    .contains("128 KiB"),
  )
  assert_true(
    transcript_test_apply(near_limit, Add).error.unwrap().contains("128 KiB"),
  )
}

///|
test "transcript compiled panel escapes markup and shows readable source timing workflow" {
  let view = transcript_test_apply(transcript_test_fixture(), SelectMatching)
  let html = qa_test_render({ ..initial_model(), brief: view, })
  for
    text in [
      "Time-coded interview quotations", "Import WebVTT / SRT transcript", "Reopen a loaded transcript",
      "Download quotation report", "Add quotations to brief", "Preview quotation report",
      "source line 16", "00:06.100", "&lt;script&gt;literal&lt;/script&gt;", "interview.vtt.txt",
    ] {
    assert_true(html.contains(text), msg=text)
  }
  assert_false(html.contains("<script>literal</script>"))
  transcript_test_evidence("rendered-transcript.html", html)
}

///|
extern "js" fn transcript_test_blob(expected : String) -> String =
  #|expected=>{
  #| const got=globalThis.__numericDownload;
  #| if(!got.clicked||got.name!=='moonfind-transcript-excerpts.md'||!(got.blob instanceof Blob)||got.blob.type!=='text/markdown;charset=utf-8')return 'Transcript download metadata mismatch';
  #| got.blob.text().then(text=>{if(text!==expected)throw Error('Transcript Blob mismatch');if(process.env.MOONFIND_TRANSCRIPT_EVIDENCE){const fs=process.getBuiltinModule('fs'),dir=process.env.MOONFIND_TRANSCRIPT_EVIDENCE;fs.writeFileSync(dir+'/'+got.name,text);fs.writeFileSync(dir+'/transcript-download-receipt.json',JSON.stringify({filename:got.name,mime:got.blob.type,bytes:got.blob.size,sha256:process.getBuiltinModule('crypto').createHash('sha256').update(text).digest('hex'),real_blob:true},null,2));}}).catch(error=>{console.error(error);process.exitCode=1;});return '';
  #|}

///|
test "transcript real Blob failure retry and repeat leave source and quotation selection intact" {
  let view = transcript_test_apply(
    transcript_test_apply(transcript_test_fixture(), Search("García")),
    SelectMatching,
  )
  let model = { ..initial_model(), brief: view, }
  for mode in ["create", "click", "ok", "ok"] {
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
      assert_eq(transcript_test_blob(transcript_report(view)), "")
    } else {
      assert_true(after.error.unwrap().contains("download failed"))
    }
    csv_numeric_blob_restore()
  }
}

///|
extern "js" fn transcript_picker_exercise(
  pick : ((String) -> Unit) -> Unit,
  text : String,
) -> Unit =
  #|(pick,text)=>{
  #| const old=Object.getOwnPropertyDescriptor(globalThis,'document');
  #| const modes=['valid-vtt','valid-txt','cancel','empty','oversize','wrong-extension','invalid-utf8','read-failure','click-failure','changed-size','bad-filename','binary'];let completed=0;
  #| try{for(const mode of modes){
  #|  Object.defineProperty(globalThis,'document',{configurable:true,value:{createElement(tag){
  #|   if(tag!=='input')throw Error('Expected input');const handlers={};
  #|   const file=mode==='invalid-utf8'?new File([new Uint8Array([255])],'interview.vtt'):new File([mode==='binary'?'\0':text],mode==='wrong-extension'?'interview.pdf':mode==='valid-txt'?'interview.txt':mode==='bad-filename'?'x'.repeat(157)+'.vtt':'interview.vtt');
  #|   const files=mode==='empty'?[]:[mode==='oversize'?{name:'interview.vtt',size:32769,arrayBuffer(){throw Error('must reject before reading');}}:mode==='changed-size'?{name:'interview.vtt',size:1,arrayBuffer:async()=>new ArrayBuffer(32769)}:mode==='read-failure'?{name:'interview.vtt',size:1,arrayBuffer:async()=>{throw Error('read failed');}}:file];
  #|   return {files,addEventListener(type,fn){handlers[type]=fn;},click(){if(this.type!=='file'||this.multiple!==false||this.accept!=='.vtt,.srt,.txt')throw Error('Picker wiring');if(mode==='click-failure')throw Error('click failed');if(mode==='cancel')handlers.cancel();else handlers.change();}};
  #|  }}});
  #|  pick(raw=>{try{const reply=JSON.parse(raw);if(mode.startsWith('valid')){if(reply.source.content_hex!==Buffer.from(text).toString('hex'))throw Error('Bytes changed');const name=mode==='valid-vtt'?'interview.vtt.txt':'interview.txt';if(reply.source.name!==name||!reply.source.origin.includes('interview.'))throw Error('Filename/provenance mismatch');if(process.env.MOONFIND_TRANSCRIPT_EVIDENCE)process.getBuiltinModule('fs').writeFileSync(process.env.MOONFIND_TRANSCRIPT_EVIDENCE+'/picker-'+mode+'.json',raw);}else if(mode==='cancel'||mode==='empty'){if(reply.cancelled!==true)throw Error('Cancel mismatch');}else if(typeof reply.error!=='string')throw Error('Missing error '+mode);completed++;}catch(error){console.error(error);process.exitCode=1;}});
  #| }}finally{if(old)Object.defineProperty(globalThis,'document',old);else delete globalThis.document;}
  #| process.once('beforeExit',()=>{if(completed!==modes.length){console.error('Incomplete transcript picker callbacks',completed);process.exitCode=1;}if(process.env.MOONFIND_TRANSCRIPT_EVIDENCE)process.getBuiltinModule('fs').writeFileSync(process.env.MOONFIND_TRANSCRIPT_EVIDENCE+'/transcript-picker-receipt.json',JSON.stringify({cases:modes,completed,real_file_blob:true},null,2));});
  #|}

///|
test "transcript real File picker keeps exact bytes filename mapping and diagnoses failures" {
  transcript_picker_exercise(transcript_choose, transcript_test_text())
}

///|
test "transcript report prepared source provenance becomes explicit draft provenance after edit" {
  let view = transcript_test_apply(transcript_test_fixture(), SelectMatching)
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
  let prepared = {
    ..view,
    opened: Some({
      contract_id: "moonfind.brief-status.v1",
      brief_id: view.draft.brief_id,
      revision_id: "revision-transcript",
      state: "prepared",
      issues: [],
      snapshot: Some({
        contract_id: "moonfind.brief-snapshot.v1",
        revision_id: "revision-transcript",
        state: "prepared",
        brief: view.draft,
        sources: [saved],
        boundary: "Synthetic host snapshot",
      }),
    }),
  }
  let report = transcript_report(prepared)
  assert_true(report.contains(digest))
  assert_true(
    report.contains("\"prepared_revision_id\": \"revision-transcript\""),
  )
  let edited = update_brief_view(
      _ => @rabbita.none,
      Edit("question", "Different question"),
      prepared,
    ).1
  assert_true(
    transcript_report(edited).contains("\"host_recorded_digest\": null"),
  )
  assert_true(
    transcript_report(edited).contains("\"prepared_revision_id\": null"),
  )
  assert_eq(edited.draft.parent_revision, Some("revision-transcript"))
  transcript_test_evidence("prepared-transcript.md", report)
}
