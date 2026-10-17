///|
struct TranscriptCorrection {
  number : Int
  text : String
} derive(Debug, Eq, ToJson)

///|
struct TranscriptRevision {
  editing : Int
  text : String
  corrections : Array[TranscriptCorrection]
} derive(Debug, Eq)

///|
enum TranscriptRevisionMsg {
  Begin(Int)
  Write(String)
  Apply
  Cancel
  Restore(Int)
  Discard
  Download
  Retain
}

///|
fn empty_transcript_revision() -> TranscriptRevision {
  { editing: 0, text: "", corrections: [], }
}

///|
fn transcript_corrected_text(state : TranscriptView, number : Int) -> String {
  for correction in state.revision.corrections {
    if correction.number == number {
      return correction.text
    }
  }
  state.capture
  .bind(capture => capture.cues.get(number - 1))
  .map(cue => cue.text)
  .unwrap_or("")
}

///|
fn transcript_editor_dirty(state : TranscriptView) -> Bool {
  state.revision.editing > 0 &&
  state.revision.text !=
  transcript_corrected_text(state, state.revision.editing)
}

///|
fn transcript_revision_pending(state : TranscriptView) -> Bool {
  !state.revision.corrections.is_empty() || transcript_editor_dirty(state)
}

///|
extern "js" fn transcript_correction_text(text : String) -> String =
  #|text=>text.replace(/\r\n?/g,'\n')

///|
// Replace only selected cue payload spans. Everything outside those spans keeps
// its original UTF-8 bytes, including BOM, mixed delimiters and non-cue blocks.
extern "js" fn transcript_splice_corrections(
  hex : String,
  capture_json : String,
  corrections_json : String,
) -> String =
  #|(hex,capture_json,corrections_json)=>{
  #| try {
  #|  const raw=new TextDecoder('utf-8',{fatal:true,ignoreBOM:true}).decode(Uint8Array.from(hex.match(/../g)||[],h=>parseInt(h,16)));
  #|  const capture=JSON.parse(capture_json),corrections=JSON.parse(corrections_json);
  #|  const lines=[];const re=/([^\r\n]*)(\r\n|\r|\n|$)/g;let m;
  #|  while((m=re.exec(raw))&&m[0].length)lines.push({body:m[1],eol:m[2],start:m.index,end:re.lastIndex});
  #|  const changes=[],seen=new Set();
  #|  for(const edit of corrections){
  #|   if(!Number.isInteger(edit.number)||edit.number<1||edit.number>capture.cues.length||seen.has(edit.number))throw Error('Choose distinct current transcript cues.');
  #|   seen.add(edit.number);const cue=capture.cues[edit.number-1],text=edit.text;
  #|   if(typeof text!=='string'||!text.trim()||text.includes('\r')||text.split('\n').some(line=>!line.trim())||text.includes('-->')||/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(text))throw Error('Cue text must be nonempty, with no blank lines, timing arrows or binary control characters.');
  #|   const timing=lines[cue.line-1];if(!timing||timing.body!==cue.timing)throw Error('Transcript cue locator changed. Reopen the source.');
  #|   let end=cue.line;while(end<lines.length&&lines[end].body!=='')end++;
  #|   const old=lines.slice(cue.line,end);if(!old.length||old.map(line=>line.body).join('\n')!==cue.text)throw Error('Transcript cue text changed. Reopen the source.');
  #|   const delimiter=old[0].eol||timing.eol||'\n';
  #|   const replacement=text.split('\n').map((body,i,all)=>body+(i===all.length-1?old[old.length-1].eol:delimiter)).join('');
  #|   changes.push({start:old[0].start,end:old[old.length-1].end,replacement});
  #|  }
  #|  changes.sort((a,b)=>b.start-a.start);let result=raw;
  #|  for(const edit of changes)result=result.slice(0,edit.start)+edit.replacement+result.slice(edit.end);
  #|  const bytes=new TextEncoder().encode(result);if(bytes.length>32768)throw Error('Revised transcript exceeds 32 KiB. Shorten the correction or use a smaller source.');
  #|  return JSON.stringify({hex:Array.from(bytes,b=>b.toString(16).padStart(2,'0')).join('')});
  #| }catch(error){return JSON.stringify({error:String(error)});}
  #|}

///|
fn transcript_revision_source(view : BriefView) -> BriefInputSource raise {
  let state = view.transcript
  guard state.source is Some(source) &&
    state.capture is Some(capture) &&
    view.draft.sources.get(state.slot - 1) == Some(source) else {
    fail("Open a current transcript before preparing a revised copy.")
  }
  guard !state.revision.corrections.is_empty() else {
    fail(
      "Apply at least one changed cue before preparing a revised transcript.",
    )
  }
  guard !transcript_editor_dirty(state) else {
    fail(
      "Apply or cancel the current cue edit before preparing a revised transcript.",
    )
  }
  let hex = match
    @json.parse(
      transcript_splice_corrections(
        source.content_hex,
        ToJson::to_json(capture).stringify(),
        state.revision.corrections.to_json().stringify(),
      ),
    ) {
    { "hex": String(hex), .. } => hex
    { "error": String(message), .. } => fail(message)
    _ => fail("The revised transcript could not be prepared.")
  }
  let revised = {
    name: "moonfind-revised-transcript." +
    (if capture.format == "subrip" { "srt" } else { "vtt" }) +
    ".txt",
    origin: "User-edited transcript working copy from source slot \{state.slot}: " +
    source.name +
    "; original capture time: " +
    source.captured_at +
    "; original origin: " +
    source.origin +
    "; \{state.revision.corrections.length()} cue text corrections; timings unchanged; speech not verified",
    captured_at: brief_now(),
    kind: "pasted-text",
    content_hex: hex,
  }
  let parsed = transcript_capture(revised)
  guard parsed.format == capture.format &&
    parsed.cues.length() == capture.cues.length() &&
    parsed.ignored_blocks == capture.ignored_blocks else {
    fail("Corrections must preserve transcript structure.")
  }
  for i, cue in parsed.cues {
    let original = capture.cues[i]
    guard cue.number == original.number &&
      cue.identifier == original.identifier &&
      cue.timing == original.timing &&
      cue.start_ms == original.start_ms &&
      cue.end_ms == original.end_ms &&
      cue.text == transcript_corrected_text(state, cue.number) else {
      fail("Corrections must preserve cue identity and timestamps.")
    }
  }
  revised
}

///|
extern "js" fn transcript_revision_download(
  hex : String,
  format : String,
) -> String =
  #|(hex,format)=>{
  #| let url,link;try{
  #|  const bytes=Uint8Array.from(hex.match(/../g)||[],h=>parseInt(h,16));
  #|  url=URL.createObjectURL(new Blob([bytes],{type:format==='subrip'?'application/x-subrip;charset=utf-8':'text/vtt;charset=utf-8'}));
  #|  link=document.createElement('a');link.href=url;link.download='moonfind-revised-transcript.'+(format==='subrip'?'srt':'vtt');document.body.appendChild(link);link.click();return '';
  #| }catch(_){return 'Revised transcript download failed; corrections remain. Try again.';}
  #| finally{if(link){try{link.remove();}catch(_){}}if(url)setTimeout(()=>URL.revokeObjectURL(url),1000);}
  #|}

///|
fn update_transcript_revision(
  action : TranscriptRevisionMsg,
  view : BriefView,
) -> BriefView raise {
  let state = view.transcript
  let edit = state.revision
  match action {
    Begin(number) => {
      guard state.capture is Some(capture) &&
        capture.cues.get(number - 1) is Some(_) else {
        fail("Choose a current cue to correct.")
      }
      guard !transcript_editor_dirty(state) else {
        fail("Apply or cancel the current cue edit before editing another cue.")
      }
      {
        ..view,
        transcript: {
          ..state,
          revision: {
            ..edit,
            editing: number,
            text: transcript_corrected_text(state, number),
          },
        },
        error: None,
      }
    }
    Write(text) => {
      guard edit.editing > 0 else { return view }
      {
        ..view,
        transcript: { ..state, revision: { ..edit, text, }, },
        error: None,
      }
    }
    Apply => {
      guard state.capture is Some(capture) &&
        capture.cues.get(edit.editing - 1) is Some(cue) else {
        fail("Choose a current cue to correct.")
      }
      let text = transcript_correction_text(edit.text)
      let corrections = edit.corrections.filter(correction => {
        correction.number != cue.number
      })
      if text != cue.text {
        corrections.push({ number: cue.number, text, })
      }
      let candidate = {
        ..view,
        transcript: {
          ..state,
          revision: { editing: 0, text: "", corrections, },
        },
        error: None,
      }
      if !corrections.is_empty() {
        ignore(transcript_revision_source(candidate))
      }
      candidate
    }
    Cancel =>
      {
        ..view,
        transcript: { ..state, revision: { ..edit, editing: 0, text: "", }, },
        error: None,
      }
    Restore(number) => {
      guard !transcript_editor_dirty(state) else {
        fail("Cancel or apply the current cue edit before restoring a cue.")
      }
      {
        ..view,
        transcript: {
          ..state,
          revision: {
            editing: 0,
            text: "",
            corrections: edit.corrections.filter(correction => {
              correction.number != number
            }),
          },
        },
        error: None,
      }
    }
    Discard =>
      {
        ..view,
        transcript: { ..state, revision: empty_transcript_revision(), },
        error: None,
      }
    Download => {
      let source = transcript_revision_source(view)
      let error = transcript_revision_download(
        source.content_hex,
        state.capture.unwrap().format,
      )
      { ..view, error: if error.is_empty() { None } else { Some(error) }, }
    }
    Retain => {
      let source = transcript_revision_source(view)
      guard source.origin.length() <= 2000 else {
        fail(
          "Revised source attribution exceeds the 2,000-character brief limit. Download the revised file separately; original attribution and corrections remain here.",
        )
      }
      guard view.draft.sources.length() < 8 &&
        view.draft.sources.fold(init=source.content_hex.length(), (total, item) => {
          total + item.content_hex.length()
        }) <=
        262144 else {
        fail(
          "Revised transcript needs one available source slot and must fit the 128 KiB dossier. Download the revised file or free space first.",
        )
      }
      let capture = transcript_capture(source)
      {
        ..brief_edited(view, {
          ..view.draft,
          sources: view.draft.sources + [source],
        }),
        transcript: {
          ..state,
          slot: view.draft.sources.length() + 1,
          source: Some(source),
          capture: Some(capture),
          revision: empty_transcript_revision(),
        },
      }
    }
  }
}
