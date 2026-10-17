///|
struct TranscriptCue {
  number : Int
  identifier : String
  line : Int
  start_ms : Int
  end_ms : Int
  timing : String
  speaker : String
  text : String
} derive(Debug, Eq, ToJson, FromJson)

///|
struct TranscriptCapture {
  format : String
  cues : Array[TranscriptCue]
  ignored_blocks : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
struct TranscriptView {
  slot : Int
  source : BriefInputSource?
  capture : TranscriptCapture?
  query : String
  selected : Array[Int]
  revision : TranscriptRevision
} derive(Debug, Eq)

///|
enum TranscriptMsg {
  Revise(TranscriptRevisionMsg)
  Choose
  FileLoaded(Int, String)
  Open(Int)
  Search(String)
  Toggle(Int)
  SelectMatching
  Clear
  Download
  Add
}

///|
fn empty_transcript_view() -> TranscriptView {
  {
    slot: 0,
    source: None,
    capture: None,
    query: "",
    selected: [],
    revision: empty_transcript_revision(),
  }
}

///|
// WebVTT and SubRip are bounded text formats, never inserted as HTML or executed.
// Cue payload and timestamps remain literal; normalization affects parsing only.
extern "js" fn transcript_parse(hex : String) -> String =
  #|hex => {
  #| try {
  #|  if(hex.length>65536 || !/^(?:[0-9a-f]{2})*$/.test(hex))throw Error('Choose canonical UTF-8 transcript bytes up to 32 KiB.');
  #|  const raw=new TextDecoder('utf-8',{fatal:true,ignoreBOM:true}).decode(Uint8Array.from(hex.match(/../g)||[],h=>parseInt(h,16)));
  #|  if(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(raw))throw Error('Binary control bytes are unsupported.');
  #|  const lines=raw.replace(/^\uFEFF/,'').split(/\r\n|\r|\n/);
  #|  const vtt=/^WEBVTT(?:[ \t].*)?$/.test(lines[0])&&!lines[0].includes('-->');
  #|  if(!vtt&&!/^\d+$/.test(lines[0]))throw Error('Expected a WEBVTT header or a numeric SubRip (SRT) cue identifier.');
  #|  const format=vtt?'webvtt':'subrip';
  #|  let at=vtt?1:0;
  #|  if(vtt)while(at<lines.length&&lines[at]!==''){if(lines[at].includes('-->')||lines[at].startsWith('X-TIMESTAMP-MAP'))throw Error('Use a blank line after the header and local cue timestamps without X-TIMESTAMP-MAP.');at++;}
  #|  const cues=[];let ignored_blocks=0;
  #|  const time=s=>{
  #|   const m=(vtt?/^(?:(\d{2}):)?([0-5]\d):([0-5]\d)\.(\d{3})$/:/^(\d{2}):([0-5]\d):([0-5]\d),(\d{3})$/).exec(s);
  #|   if(!m)throw Error(vtt?'Use mm:ss.mmm or hh:mm:ss.mmm timestamps (up to 99 hours).':'Use SubRip hh:mm:ss,mmm timestamps (up to 99 hours).');
  #|   return ((Number(m[1]||0)*60+Number(m[2]))*60+Number(m[3]))*1000+Number(m[4]);
  #|  };
  #|  while(at<lines.length){
  #|   if(lines[at]===''){at++;continue;}
  #|   const begin=at,block=[];
  #|   while(at<lines.length&&lines[at]!=='')block.push(lines[at++]);
  #|   if(vtt&&/^(?:NOTE(?:[ \t]|$)|STYLE$|REGION$)/.test(block[0])){ignored_blocks++;continue;}
  #|   let index=0,identifier='';
  #|   if(!vtt){if(!/^\d+$/.test(block[0]))throw Error('Expected a numeric SubRip cue identifier at source line '+(begin+1)+'.');identifier=block[0];index=1;}
  #|   else if(!block[0].includes('-->')){identifier=block[0];index++;}
  #|   const timing=block[index]||'';
  #|   const m=(vtt?/^(\S+)[ \t]+-->[ \t]+(\S+)(?:[ \t]+[^\r\n]*)?$/:/^(\S+)[ \t]+-->[ \t]+(\S+)[ \t]*$/).exec(timing);
  #|   if(!m)throw Error('Expected cue timing at source line '+(begin+index+1)+'.');
  #|   const start_ms=time(m[1]),end_ms=time(m[2]);
  #|   if(end_ms<=start_ms)throw Error('Cue end must follow its start at line '+(begin+index+1)+'.');
  #|   if(cues.length&&start_ms<cues[cues.length-1].start_ms)throw Error('Cue start times must be in source order. Overlapping cues are supported.');
  #|   const text=block.slice(index+1).join('\n');
  #|   if(!text.trim())throw Error('Cue text is empty at source line '+(begin+index+1)+'.');
  #|   if(text.includes('-->'))throw Error('Unexpected cue timing in payload; separate cues with a blank line.');
  #|   const voice=vtt?/^<v(?:\.[^ >]+)*[ \t]+([^>]+)>/.exec(text):null;
  #|   cues.push({number:cues.length+1,identifier,line:begin+index+1,start_ms,end_ms,timing,speaker:voice?voice[1]:'',text});
  #|   if(cues.length>512)throw Error('Use at most 512 transcript cues.');
  #|  }
  #|  if(!cues.length)throw Error('No timed transcript cues were found.');
  #|  return JSON.stringify({capture:{format,cues,ignored_blocks}});
  #| }catch(error){return JSON.stringify({error:String(error)});}
  #|}

///|
fn transcript_capture(source : BriefInputSource) -> TranscriptCapture raise {
  match @json.parse(transcript_parse(source.content_hex)) {
    { "capture": capture, .. } => @json.from_json(capture)
    { "error": String(error), .. } => fail(error)
    _ => fail("Transcript could not be read.")
  }
}

///|
extern "js" fn transcript_choose(done : (String) -> Unit) -> Unit =
  #|done=>{
  #| try {
  #| const input=document.createElement('input');input.type='file';input.accept='.vtt,.srt,.txt';input.multiple=false;
  #| input.addEventListener('cancel',()=>done(JSON.stringify({cancelled:true})),{once:true});
  #| input.addEventListener('change',async()=>{
  #|  try{
  #|   const files=Array.from(input.files||[]);if(!files.length){done(JSON.stringify({cancelled:true}));return;}
  #|   if(files.length!==1)throw Error('Choose one WebVTT or SubRip transcript.');
  #|   const file=files[0];if(!/\.(vtt|srt|txt)$/i.test(file.name)||file.size>32768)throw Error('Choose one UTF-8 .vtt, .srt or .txt transcript up to 32 KiB.');
  #|   const name=/\.(vtt|srt)$/i.test(file.name)?file.name+'.txt':file.name;
  #|   if(name.length>160||/[\\/\u0000-\u001f\u007f]/.test(name))throw Error('Use a safe transcript filename of at most 156 characters.');
  #|   const bytes=new Uint8Array(await file.arrayBuffer());if(bytes.length>32768)throw Error('Transcript bytes exceed 32 KiB.');
  #|   const text=new TextDecoder('utf-8',{fatal:true,ignoreBOM:true}).decode(bytes);
  #|   if(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(text))throw Error('Binary control bytes are unsupported.');
  #|   done(JSON.stringify({source:{name,origin:'User-selected timed transcript: '+file.name+'; exact original bytes retained as '+name,captured_at:new Date().toISOString(),kind:'local-file',content_hex:Array.from(bytes,b=>b.toString(16).padStart(2,'0')).join('')}}));
  #|  }catch(error){done(JSON.stringify({error:String(error)}));}
  #| },{once:true});input.click();
  #| }catch(error){done(JSON.stringify({error:String(error)}));}
  #|}

///|
fn sync_transcript(view : BriefView) -> BriefView {
  if view.transcript.source is Some(source) &&
    view.draft.sources.get(view.transcript.slot - 1) != Some(source) {
    { ..view, transcript: empty_transcript_view(), }
  } else {
    view
  }
}

///|
fn transcript_matching(state : TranscriptView) -> Array[TranscriptCue] {
  let query = json_evidence_fold(state.query.trim().to_owned())
  state.capture
  .map(capture => {
    capture.cues.filter(cue => {
      query.is_empty() ||
      json_evidence_fold(
        cue.speaker + " " + cue.text + " " + cue.identifier + " " + cue.timing,
      ).contains(query)
    })
  })
  .unwrap_or([])
}

///|
fn transcript_selected(state : TranscriptView) -> Array[TranscriptCue] {
  state.capture
  .map(capture => {
    capture.cues.filter(cue => state.selected.contains(cue.number))
  })
  .unwrap_or([])
}

///|
fn transcript_indented(value : String) -> String {
  value.split("\n").map(line => "    " + line.to_owned()).collect().join("\n")
}

///|
fn transcript_report(view : BriefView) -> String raise {
  let state = view.transcript
  guard state.source is Some(source) &&
    state.capture is Some(capture) &&
    view.draft.sources.get(state.slot - 1) == Some(source) else {
    fail("Open a current transcript before exporting quotations.")
  }
  let cues = transcript_selected(state)
  guard !cues.is_empty() else { fail("Select at least one transcript cue.") }
  let (revision, digest) : (Json, Json) = match view.opened {
    Some(status) if status.state == "prepared" &&
      status.snapshot is Some(snapshot) &&
      snapshot.brief == view.draft &&
      snapshot.revision_id == status.revision_id &&
      snapshot.sources.get(state.slot - 1) is Some(saved) &&
      saved.slot == state.slot &&
      saved.name == source.name &&
      saved.origin == source.origin &&
      saved.captured_at == source.captured_at &&
      saved.kind == source.kind &&
      saved.byte_count * 2 == source.content_hex.length() =>
      (Json::string(status.revision_id), Json::string(saved.digest))
    _ => (Json::null(), Json::null())
  }
  let metadata : Json = {
    "contract_id": "moonfind.transcript-excerpts.v1",
    "prepared_revision_id": revision,
    "host_recorded_digest": digest,
    "brief_id": view.draft.brief_id,
    "source_slot": state.slot,
    "source_name": source.name,
    "source_origin": source.origin,
    "captured_at": source.captured_at,
    "source_format": capture.format,
    "source_cue_count": capture.cues.length(),
    "selected_cue_count": cues.length(),
    "ignored_non_cue_blocks": capture.ignored_blocks,
  }
  let sections = cues.map(cue => {
    let locator : Json = {
      "source_cue": cue.number,
      "source_line": cue.line,
      "identifier": cue.identifier,
      "start_ms": cue.start_ms,
      "end_ms": cue.end_ms,
      "timing": cue.timing,
      "speaker_annotation": cue.speaker,
    }
    "## Cue " +
    cue.number.to_string() +
    "\n\n" +
    transcript_indented(locator.stringify()) +
    "\n\n" +
    transcript_indented(cue.text) +
    "\n"
  })
  "# Selected transcript quotations\n\n" +
  "Local " +
  (if capture.format == "subrip" { "SubRip (SRT)" } else { "WebVTT" }) +
  " text only. No audio/video was loaded or checked. Cue times, speaker annotations and quotations are supplied evidence, not verified speech or findings. Non-cue blocks remain in the retained original. A null digest/revision means there is no matching prepared host snapshot for this draft.\n\n" +
  transcript_indented(metadata.stringify(indent=2)) +
  "\n\n" +
  sections.join("\n") +
  "\nThe complete original remains in the brief. This report contains selected cues only; selection does not redact the source dossier.\n"
}

///|
extern "js" fn transcript_download(content : String) -> String =
  #|content=>{
  #| let url,link;try{
  #|  url=URL.createObjectURL(new Blob([content],{type:'text/markdown;charset=utf-8'}));
  #|  link=document.createElement('a');link.href=url;link.download='moonfind-transcript-excerpts.md';document.body.appendChild(link);link.click();return '';
  #| }catch(_){return 'Transcript download failed; selections remain. Try again.';}
  #| finally{if(link){try{link.remove();}catch(_){}}if(url)setTimeout(()=>URL.revokeObjectURL(url),1000);}
  #|}

///|
fn update_transcript(
  emit : @rabbita.Emit[Msg],
  action : TranscriptMsg,
  view : BriefView,
) -> (@rabbita.Cmd, BriefView) {
  if view.pending {
    return (@rabbita.none, view)
  }
  let view = sync_transcript(view)
  let state = view.transcript
  let next = try {
    match action {
      Revise(action) => update_transcript_revision(action, view)
      Choose | Open(_) | FileLoaded(_, _) if transcript_revision_pending(state) =>
        fail(
          "Retain or discard transcript corrections before opening another source. Cancel the current cue edit if needed.",
        )
      Choose => {
        let generation = view.generation
        return (
          @cmd.custom_cmd(scheduler => {
            transcript_choose(raw => {
              scheduler.add(
                emit(BriefAction(Transcript(FileLoaded(generation, raw)))),
              )
            })
          }),
          view,
        )
      }
      FileLoaded(generation, _) if generation != view.generation => view
      FileLoaded(_, raw) => {
        let payload = @json.parse(raw)
        if payload is { "cancelled": True, .. } {
          return (@rabbita.none, view)
        }
        if payload is { "error": String(error), .. } {
          fail(error)
        }
        guard payload is { "source": value, .. } else {
          fail("No transcript source was selected.")
        }
        let source : BriefInputSource = @json.from_json(value)
        let capture = transcript_capture(source)
        guard view.draft.sources.length() < 8 &&
          view.draft.sources.fold(init=source.content_hex.length(), (
            total,
            source,
          ) => total + source.content_hex.length()) <=
          262144 else {
          fail(
            "Transcript import needs one available source slot and 128 KiB total space.",
          )
        }
        {
          ..brief_edited(view, {
            ..view.draft,
            sources: view.draft.sources + [source],
          }),
          transcript: {
            slot: view.draft.sources.length() + 1,
            source: Some(source),
            capture: Some(capture),
            query: "",
            selected: [],
            revision: empty_transcript_revision(),
          },
        }
      }
      Open(slot) => {
        guard view.draft.sources.get(slot - 1) is Some(source) else {
          return (
            @rabbita.none,
            { ..view, transcript: empty_transcript_view(), error: None, },
          )
        }
        let capture = transcript_capture(source)
        {
          ..view,
          transcript: {
            slot,
            source: Some(source),
            capture: Some(capture),
            query: "",
            selected: [],
            revision: empty_transcript_revision(),
          },
          error: None,
        }
      }
      Search(query) => { ..view, transcript: { ..state, query, }, error: None, }
      Toggle(number) => {
        guard state.capture is Some(capture) &&
          capture.cues.any(cue => cue.number == number) else {
          return (@rabbita.none, view)
        }
        {
          ..view,
          transcript: { ..state, selected: csv_toggle(state.selected, number), },
          error: None,
        }
      }
      SelectMatching => {
        let selected = state.selected.copy()
        for cue in transcript_matching(state) {
          if !selected.contains(cue.number) {
            selected.push(cue.number)
          }
        }
        { ..view, transcript: { ..state, selected, }, error: None, }
      }
      Clear => { ..view, transcript: { ..state, selected: [], }, error: None, }
      Download => {
        let error = transcript_download(transcript_report(view))
        { ..view, error: if error.is_empty() { None } else { Some(error) }, }
      }
      Add => {
        let content = transcript_report(view)
        let hex = brief_text_hex(content)
        guard view.draft.sources.length() < 8 &&
          hex.length() <= 65536 &&
          view.draft.sources.fold(init=hex.length(), (total, source) => {
            total + source.content_hex.length()
          }) <=
          262144 else {
          fail(
            "Excerpts must fit one available source slot, 32 KiB per source and 128 KiB total. Select fewer cues or download separately.",
          )
        }
        let capture : BriefInputSource = {
          name: "transcript-excerpts.md",
          origin: "Selected time-coded quotations from source slot " +
          state.slot.to_string() +
          ": " +
          state.source.unwrap().name,
          captured_at: brief_now(),
          kind: "pasted-text",
          content_hex: hex,
        }
        {
          ..brief_edited(view, {
            ..view.draft,
            sources: view.draft.sources + [capture],
          }),
          transcript: { ..state, selected: [], },
        }
      }
    }
  } catch {
    error => { ..view, error: Some("\{error}"), }
  }
  (@rabbita.none, next)
}
