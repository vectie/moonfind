///|
fn correction_test_apply(
  view : BriefView,
  number : Int,
  text : String,
) -> BriefView {
  transcript_test_apply(
    transcript_test_apply(
      transcript_test_apply(view, Revise(Begin(number))),
      Revise(Write(text)),
    ),
    Revise(Apply),
  )
}

///|
extern "js" fn correction_test_evidence(name : String, text : String) -> Unit =
  #|(name,text)=>{if(process.env.MOONFIND_CORRECTION_EVIDENCE)process.getBuiltinModule('fs').writeFileSync(process.env.MOONFIND_CORRECTION_EVIDENCE+'/'+name,text);}

///|
test "corrections preserve exact WebVTT outside edited payloads including BOM CRLF notes style and timing settings" {
  let view = transcript_test_fixture()
  let corrected = correction_test_apply(
    view, 1, "<v García>Clinic handoffs take too long 🌒.\nWe reuse the same notes.\nClarified by researcher.",
  )
  assert_eq(corrected.error, None)
  let corrected = correction_test_apply(
    corrected, 3, "<v García>Fifteen minutes. <script>literal</script>",
  )
  assert_eq(corrected.error, None)
  let source = transcript_revision_source(corrected)
  let expected = transcript_test_text()
    .replace(
      old="We copy the same notes.",
      new="We reuse the same notes.\r\nClarified by researcher.",
    )
    .replace(old="Five minutes.", new="Fifteen minutes.")
  assert_eq(source.content_hex, brief_text_hex(expected))
  assert_eq(corrected.draft, view.draft)
  assert_eq(corrected.transcript.capture, view.transcript.capture)
  assert_eq(source.name, "moonfind-revised-transcript.vtt.txt")
  assert_true(source.origin.contains("User-edited transcript working copy"))
  assert_true(source.origin.contains(view.draft.sources[0].origin))
  let parsed = transcript_capture(source)
  assert_eq(parsed.ignored_blocks, 2)
  assert_eq(parsed.cues[2].line, 17)
  assert_eq(
    parsed.cues.map(cue => cue.timing),
    view.transcript.capture.unwrap().cues.map(cue => cue.timing),
  )
  correction_test_evidence("original-interview.vtt", transcript_test_text())
  correction_test_evidence("revised-interview.vtt", expected)
  correction_test_evidence(
    "revised-vtt-capture.json",
    ToJson::to_json(parsed).stringify(indent=2),
  )
}

///|
test "corrections preserve SRT duplicate supplied identifiers overlaps and exact unselected text" {
  let view = srt_test_fixture()
  let corrected = correction_test_apply(
    view, 3, "García: Clinic handoffs take fifteen minutes.\nResearcher correction, not checked against audio.",
  )
  assert_eq(corrected.error, None)
  let source = transcript_revision_source(corrected)
  let expected = srt_test_text().replace(
    old="<v García>Clinic handoffs take five minutes. <script>literal</script>",
    new="García: Clinic handoffs take fifteen minutes.\r\nResearcher correction, not checked against audio.",
  )
  assert_eq(source.content_hex, brief_text_hex(expected))
  assert_eq(source.name, "moonfind-revised-transcript.srt.txt")
  let parsed = transcript_capture(source)
  assert_eq(parsed.cues.map(cue => cue.identifier), [
    "007", "42", "42", "9007199254740993",
  ])
  assert_eq(parsed.cues[1], view.transcript.capture.unwrap().cues[1])
  assert_eq(parsed.cues[2].speaker, "")
  correction_test_evidence("original-interview.srt", srt_test_text())
  correction_test_evidence("revised-interview.srt", expected)
}

///|
test "corrections handle mixed newlines and final unterminated cue without reconstructing other blocks" {
  let original = "WEBVTT\r\n\r\n00:00.000 --> 00:01.000\r\nfirst\nsecond\r\n\r\n00:01.000 --> 00:02.000\rlast"
  let view = transcript_test_apply(
    {
      ..initial_brief_view(),
      draft: {
        ..brief_fixture_draft(),
        sources: [transcript_test_source(original)],
      },
    },
    Open(1),
  )
  let corrected = correction_test_apply(view, 2, "last corrected\nnew line")
  assert_eq(corrected.error, None)
  assert_eq(
    brief_source_preview(transcript_revision_source(corrected).content_hex),
    original.replace(old="last", new="last corrected\rnew line"),
  )
  let first = correction_test_apply(
    corrected, 1, "first corrected\nsecond corrected",
  )
  assert_eq(first.error, None)
  assert_eq(
    brief_source_preview(transcript_revision_source(first).content_hex),
    original
    .replace(old="first\nsecond", new="first corrected\nsecond corrected")
    .replace(old="last", new="last corrected\rnew line"),
  )
}

///|
test "corrections cancel current edit restore one cue discard all and no-op without changing original" {
  let view = transcript_test_fixture()
  let same = correction_test_apply(
    view,
    1,
    view.transcript.capture.unwrap().cues[0].text,
  )
  assert_eq(same.transcript.revision, empty_transcript_revision())
  let first = correction_test_apply(view, 1, "Changed first cue")
  let writing = transcript_test_apply(
    transcript_test_apply(first, Revise(Begin(3))),
    Revise(Write("Not yet applied")),
  )
  let blocked = transcript_test_apply(writing, Revise(Begin(2)))
  assert_eq(blocked.transcript, writing.transcript)
  assert_true(blocked.error.unwrap().contains("Apply or cancel"))
  let canceled = transcript_test_apply(writing, Revise(Cancel))
  assert_eq(
    canceled.transcript.revision.corrections,
    first.transcript.revision.corrections,
  )
  let second = correction_test_apply(canceled, 3, "Changed third cue")
  let restored = transcript_test_apply(second, Revise(Restore(1)))
  assert_eq(
    restored.transcript.revision.corrections.map(correction => correction.number),
    [3],
  )
  let original_again = correction_test_apply(
    restored,
    3,
    view.transcript.capture.unwrap().cues[2].text,
  )
  assert_eq(original_again.transcript.revision, empty_transcript_revision())
  assert_eq(
    transcript_test_apply(second, Revise(Discard)).transcript.revision,
    empty_transcript_revision(),
  )
  assert_eq(second.draft, view.draft)
}

///|
test "corrections reject malformed and oversize edits atomically with recoverable typed text" {
  let view = correction_test_apply(
    transcript_test_fixture(),
    1,
    "Valid first correction",
  )
  for
    text in [
      "",
      " \t ",
      "one\n\ntwo",
      "one\n \ntwo",
      "\none",
      "one\n",
      "one --> two",
      "one\u{0000}two",
      Array::makei(32768, _ => "x").join(""),
    ] {
    let writing = transcript_test_apply(
      transcript_test_apply(view, Revise(Begin(3))),
      Revise(Write(text)),
    )
    let failed = transcript_test_apply(writing, Revise(Apply))
    assert_true(failed.error is Some(_))
    assert_eq(failed.draft, writing.draft)
    assert_eq(failed.transcript, writing.transcript)
    let blocked = transcript_test_apply(writing, Revise(Retain))
    assert_eq(blocked.draft, view.draft)
    assert_true(blocked.error.unwrap().contains("Apply or cancel"))
  }
  let normalized = correction_test_apply(view, 3, "one\r\ntwo\rthree")
  assert_eq(normalized.error, None)
  assert_eq(
    transcript_capture(transcript_revision_source(normalized)).cues[2].text,
    "one\ntwo\nthree",
  )
}

///|
test "corrections root workflow retains revised source searches it makes excerpts and restores browser and native-shaped brief" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = transcript_test_apply(transcript_test_fixture(), Toggle(3))
  let corrected = correction_test_apply(
    view, 3, "<v García>Fifteen minutes. <img src=x onerror=bad()>",
  )
  let html = qa_test_render({ ..initial_model(), brief: corrected, })
  for
    label in [
      "Correct transcript text", "Compare changed cue 3", "Retain revised transcript and use quotations",
      "Download revised VTT / SRT", "&lt;img src=x", "original loaded capture",
    ] {
    assert_true(html.contains(label), msg=label)
  }
  assert_false(html.contains("<img src=x"))
  assert_true(transcript_report(corrected).contains("Five minutes."))
  assert_false(transcript_report(corrected).contains("Fifteen minutes."))
  let retained = transcript_test_apply(corrected, Revise(Retain))
  assert_eq(retained.error, None)
  assert_eq(retained.draft.sources.length(), 2)
  assert_eq(retained.draft.sources[0], view.draft.sources[0])
  assert_eq(retained.transcript.slot, 2)
  assert_eq(retained.transcript.selected, [3])
  assert_eq(retained.transcript.revision, empty_transcript_revision())
  let searched = transcript_test_apply(retained, Search("fifteen"))
  assert_eq(transcript_matching(searched.transcript).map(cue => cue.number), [3])
  let report = transcript_report(searched)
  assert_true(report.contains("Fifteen minutes."))
  assert_true(report.contains("User-edited transcript working copy"))
  assert_false(report.contains("Five minutes."))
  let added = transcript_test_apply(searched, Add)
  assert_eq(added.draft.sources.length(), 3)
  assert_eq(added.draft.sources[0], view.draft.sources[0])
  assert_eq(initial_brief_view().draft, added.draft)
  let reopened = update_brief_view(
      _ => @rabbita.none,
      Loaded(
        17,
        added.draft.brief_id,
        "revision-correction",
        Ok(brief_fixture_reply(added.draft, "revision-correction")),
      ),
      { ..added, generation: 17, pending: true, },
    ).1
  assert_eq(reopened.draft, added.draft)
  assert_eq(
    transcript_test_apply(reopened, Open(2)).transcript.capture,
    retained.transcript.capture,
  )
  correction_test_evidence("correction-workspace.html", html)
  correction_test_evidence("revised-quotation-report.md", report)
  correction_test_evidence(
    "retained-correction-brief.json",
    ToJson::to_json(added.draft).stringify(indent=2),
  )
}

///|
test "corrections block source switching and pending operations and detect replacement without applying old edits" {
  let view = correction_test_apply(transcript_test_fixture(), 1, "Changed cue")
  for
    action in [
      TranscriptMsg::Choose,
      Open(1),
      FileLoaded(view.generation, "{\"cancelled\":true}"),
    ] {
    let blocked = transcript_test_apply(view, action)
    assert_eq(blocked.transcript, view.transcript)
    assert_eq(blocked.draft, view.draft)
    assert_true(blocked.error.unwrap().contains("Retain or discard"))
  }
  for
    action in [
      TranscriptRevisionMsg::Begin(2),
      Write("bad"),
      Apply,
      Cancel,
      Restore(1),
      Discard,
      Download,
      Retain,
    ] {
    let pending = transcript_test_apply(
      { ..view, pending: true, },
      Revise(action),
    )
    assert_eq(pending.transcript, view.transcript)
    assert_eq(pending.draft, view.draft)
  }
  let replaced = {
    ..view,
    draft: {
      ..view.draft,
      sources: [
        { ..view.draft.sources[0], content_hex: brief_text_hex("different"), },
      ],
    },
  }
  assert_true(transcript_test_apply(replaced, Revise(Retain)).error is Some(_))
  assert_eq(
    transcript_test_apply(replaced, Revise(Retain)).draft,
    replaced.draft,
  )
  let fresh = update_brief_view(_ => @rabbita.none, New, view).1
  assert_eq(fresh.transcript, empty_transcript_view())
}

///|
test "corrections source slot and dossier limits preserve working text for separate download" {
  let view = correction_test_apply(transcript_test_fixture(), 1, "Changed cue")
  let full = {
    ..view,
    draft: {
      ..view.draft,
      sources: view.draft.sources +
      Array::makei(7, _ => transcript_test_source("x")),
    },
  }
  let blocked = transcript_test_apply(full, Revise(Retain))
  assert_eq(blocked.draft, full.draft)
  assert_eq(blocked.transcript, full.transcript)
  assert_true(blocked.error.unwrap().contains("source slot"))
  ignore(transcript_revision_source(full))
  let near = {
    ..view,
    draft: {
      ..view.draft,
      sources: view.draft.sources +
      Array::makei(4, _ => {
        transcript_test_source(Array::makei(32600, _ => "x").join(""))
      }),
    },
  }
  assert_eq(transcript_test_apply(near, Revise(Retain)).draft, near.draft)
  assert_true(
    transcript_test_apply(near, Revise(Retain)).error
    .unwrap()
    .contains("128 KiB"),
  )
  let attributed = {
    ..view.draft.sources[0],
    origin: Array::makei(2000, _ => "a").join(""),
  }
  let long_origin = {
    ..view,
    draft: { ..view.draft, sources: [attributed], },
    transcript: { ..view.transcript, source: Some(attributed), },
  }
  let blocked = transcript_test_apply(long_origin, Revise(Retain))
  assert_eq(blocked.draft, long_origin.draft)
  assert_eq(blocked.transcript, long_origin.transcript)
  assert_true(blocked.error.unwrap().contains("2,000-character"))
  ignore(transcript_revision_source(long_origin))
}

///|
extern "js" fn correction_test_blob(
  expected_hex : String,
  format : String,
) -> String =
  #|(expected_hex,format)=>{
  #| const got=globalThis.__numericDownload,name='moonfind-revised-transcript.'+(format==='subrip'?'srt':'vtt');
  #| const mime=format==='subrip'?'application/x-subrip;charset=utf-8':'text/vtt;charset=utf-8';
  #| if(!got.clicked||got.name!==name||!(got.blob instanceof Blob)||got.blob.type!==mime)return 'Revised transcript download metadata mismatch';
  #| got.blob.arrayBuffer().then(buffer=>{const bytes=Buffer.from(buffer);if(bytes.toString('hex')!==expected_hex)throw Error('Revised transcript Blob mismatch');if(process.env.MOONFIND_CORRECTION_EVIDENCE){const fs=process.getBuiltinModule('fs'),dir=process.env.MOONFIND_CORRECTION_EVIDENCE;fs.writeFileSync(dir+'/'+name,bytes);if(fs.readFileSync(dir+'/'+name).toString('hex')!==expected_hex)throw Error('Physical revised file readback mismatch');fs.writeFileSync(dir+'/'+name+'.receipt.json',JSON.stringify({filename:name,mime:got.blob.type,bytes:got.blob.size,sha256:process.getBuiltinModule('crypto').createHash('sha256').update(bytes).digest('hex'),real_blob:true,readback_equal:true},null,2));}}).catch(error=>{console.error(error);process.exitCode=1;});return '';
  #|}

///|
test "corrections production download creates reusable VTT and SRT Blobs with failure retry repeat and physical readback" {
  for base in [transcript_test_fixture(), srt_test_fixture()] {
    let view = correction_test_apply(
      base, 1, "Corrected synthetic clinic interview text 🌒.",
    )
    let revised = transcript_revision_source(view)
    let model = { ..initial_model(), brief: view, }
    for mode in ["create", "click", "ok", "ok"] {
      csv_numeric_blob_fixture(mode)
      let after = update(
          _ => @rabbita.none,
          BriefAction(Transcript(Revise(Download))),
          model,
        ).1.brief
      assert_eq(after.draft, view.draft)
      assert_eq(after.transcript, view.transcript)
      if mode == "ok" {
        assert_eq(after.error, None)
        assert_eq(
          correction_test_blob(
            revised.content_hex,
            view.transcript.capture.unwrap().format,
          ),
          "",
        )
      } else {
        assert_true(after.error.unwrap().contains("download failed"))
      }
      csv_numeric_blob_restore()
    }
  }
}

///|
test "corrections survive same-draft prepared incomplete and failed save replies while explicit successful open resets them" {
  let applied = correction_test_apply(
    transcript_test_fixture(),
    1,
    "Applied correction",
  )
  let editing = transcript_test_apply(
    transcript_test_apply(applied, Revise(Begin(3))),
    Revise(Write("Unapplied correction")),
  )
  let model = { ..initial_model(), brief: editing, }
  let saving = update(_ => @rabbita.none, BriefAction(Save), model).1
  let revision = "revision-correction-save"
  let prepared = brief_fixture_reply(editing.draft, revision)
  let incomplete : Json = {
    "contract_id": "moonfind.brief-status.v1",
    "brief_id": editing.draft.brief_id,
    "revision_id": revision,
    "state": "incomplete",
    "snapshot": Json::null(),
    "issues": ["Synthetic incomplete save"],
  }
  for
    payload in [
      prepared,
      incomplete,
      ({ "error": { "message": "Synthetic failed save" } } : Json),
    ] {
    let reply = update(
        _ => @rabbita.none,
        BriefAction(
          Loaded(
            saving.brief.generation,
            editing.draft.brief_id,
            "",
            Ok(payload),
          ),
        ),
        saving,
      ).1
    assert_eq(reply.brief.transcript, editing.transcript)
    assert_eq(reply.brief.draft, editing.draft)
    assert_false(reply.brief.pending)
    let retry = update(_ => @rabbita.none, BriefAction(Save), reply).1
    assert_eq(retry.brief.transcript, editing.transcript)
  }
  let failed = update(
      _ => @rabbita.none,
      BriefAction(
        Loaded(
          saving.brief.generation,
          editing.draft.brief_id,
          "",
          Err(Failure("Synthetic transport failure")),
        ),
      ),
      saving,
    ).1
  assert_eq(failed.brief.transcript, editing.transcript)
  let retry = update(_ => @rabbita.none, BriefAction(Save), failed).1
  let saved = update(
      _ => @rabbita.none,
      BriefAction(
        Loaded(retry.brief.generation, editing.draft.brief_id, "", Ok(prepared)),
      ),
      retry,
    ).1
  assert_eq(saved.brief.transcript, editing.transcript)
  let opening = update(
      _ => @rabbita.none,
      BriefAction(Open(editing.draft.brief_id, revision)),
      saved,
    ).1
  let incomplete_open = update(
      _ => @rabbita.none,
      BriefAction(
        Loaded(
          opening.brief.generation,
          editing.draft.brief_id,
          revision,
          Ok(incomplete),
        ),
      ),
      opening,
    ).1
  assert_eq(incomplete_open.brief.transcript, editing.transcript)
  let opened = update(
      _ => @rabbita.none,
      BriefAction(
        Loaded(
          opening.brief.generation,
          editing.draft.brief_id,
          revision,
          Ok(prepared),
        ),
      ),
      opening,
    ).1
  assert_eq(opened.brief.transcript, empty_transcript_view())
}
