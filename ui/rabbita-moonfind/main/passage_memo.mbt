///|
struct EvidencePassage {
  id : String
  source_slot : Int
  source : BriefInputSource
  first_line : Int
  last_line : Int
  quote : String
  role : String
  note : String
} derive(Debug, Eq, ToJson, FromJson)

///|
struct PassageMemo {
  contract_id : String
  brief_id : String
  revision : Int
  question : String
  passages : Array[EvidencePassage]
} derive(Debug, Eq, ToJson, FromJson)

///|
struct PassageMemoState {
  key : String
  token : String
  memo : PassageMemo
  expected : String?
  blocked : Bool
  saved : Bool
  unreadable : String
  notice : String
  sources : Array[BriefInputSource]
  source_slot : Int
  first_line : String
  last_line : String
  role : String
  note : String
}

///|
enum PassageMemoMsg {
  Question(String)
  PassageSource(Int)
  FromSearch(Int, Int)
  FirstLine(String)
  LastLine(String)
  Role(String)
  Note(String)
  Collect
  Annotate(String, String, String)
  RemovePassage(String)
  Save
  RetryRead
  ExportMarkdown
  ExportJson
}

///|
fn empty_passage_memo(draft : BriefDraft) -> PassageMemoState {
  {
    key: "moonfind.passage-memo.v1:" + draft.brief_id,
    token: brief_new_id(),
    memo: {
      contract_id: "moonfind.passage-memo.v1",
      brief_id: draft.brief_id,
      revision: 0,
      question: draft.question,
      passages: [],
    },
    expected: None,
    blocked: false,
    saved: true,
    unreadable: "",
    notice: "No passages collected for this brief in this browser.",
    sources: draft.sources,
    source_slot: 0,
    first_line: "1",
    last_line: "1",
    role: "question",
    note: "",
  }
}

///|
// Keep every original newline in the quote, including the last selected line's
// terminator. A trailing newline exposes a final empty line, as dossier search does.
extern "js" fn passage_slice_json(
  hex : String,
  first : Int,
  last : Int,
) -> String =
  #|(hex,first,last) => {
  #| try {
  #|  if(hex.length>65536 || !/^(?:[0-9a-fA-F]{2})*$/.test(hex)) throw new Error('Choose a valid UTF-8 capture up to 32 KiB.');
  #|  const text=new TextDecoder('utf-8',{fatal:true,ignoreBOM:true}).decode(Uint8Array.from(hex.match(/../g)||[],v=>parseInt(v,16)));
  #|  const starts=[0],ends=[]; for(const m of text.matchAll(/\r\n|\r|\n/g)){ends.push(m.index+m[0].length);starts.push(m.index+m[0].length);} ends.push(text.length);
  #|  if(!Number.isInteger(first)||!Number.isInteger(last)||first<1||last<first||last>starts.length) throw new Error('Choose an inclusive line range within 1–'+starts.length+'.');
  #|  const quote=text.slice(starts[first-1],ends[last-1]);
  #|  if(!quote.trim()) throw new Error('Choose a passage containing non-whitespace text.');
  #|  return JSON.stringify({quote,line_count:starts.length});
  #| } catch(error){return JSON.stringify({error:String(error)});}
  #| }

///|
fn passage_quote(
  source : BriefInputSource,
  first : Int,
  last : Int,
) -> String raise {
  match @json.parse(passage_slice_json(source.content_hex, first, last)) {
    { "quote": String(quote), .. } => quote
    { "error": String(message), .. } => fail(message)
    _ => fail("The source passage could not be read.")
  }
}

///|
fn passage_role_valid(role : String) -> Bool {
  role is ("support" | "contradiction" | "question" | "context")
}

///|
fn passage_memo_decode(text : String, brief_id : String) -> PassageMemo raise {
  guard brief_text_hex(text).length() <= 2 * 1024 * 1024 else {
    fail("The complete passage collection exceeds 1 MiB.")
  }
  let memo : PassageMemo = @json.from_json(@json.parse(text))
  guard memo.contract_id == "moonfind.passage-memo.v1" &&
    memo.brief_id == brief_id &&
    !brief_id.is_blank() &&
    memo.revision >= 0 &&
    memo.question.length() <= 10000 &&
    memo.passages.length() <= 24 else {
    fail("Unsupported or mismatched passage collection.")
  }
  let ids : Map[String, Bool] = Map([])
  for passage in memo.passages {
    guard !passage.id.is_blank() &&
      !ids.contains(passage.id) &&
      passage.source_slot > 0 &&
      passage.source_slot <= 8 &&
      passage_role_valid(passage.role) &&
      passage.note.length() <= 10000 &&
      passage.quote ==
      passage_quote(passage.source, passage.first_line, passage.last_line) else {
      fail(
        "A retained passage does not match its source snapshot or annotations.",
      )
    }
    ids[passage.id] = true
  }
  memo
}

///|
fn restore_passage_memo(draft : BriefDraft) -> PassageMemoState {
  let state = empty_passage_memo(draft)
  let reply = @json.parse(choice_storage_read(state.key)) catch {
    _ => Json::null()
  }
  match reply {
    { "missing": True, .. } => state
    { "value": String(value), .. } =>
      {
        ..state,
        memo: passage_memo_decode(value, draft.brief_id),
        expected: Some(value),
        notice: "Restored your browser-local passage collection and exact source snapshots.",
      } catch {
        error =>
          {
            ..state,
            expected: Some(value),
            blocked: true,
            unreadable: value,
            notice: "Stored collection could not be read and was not replaced. Retain the bytes below before repair. Details: \{error}",
          }
      }
    _ =>
      {
        ..state,
        blocked: true,
        notice: "Browser storage could not be read. Collection writes are paused; retry reading when storage is available.",
      }
  }
}

///|
fn save_passage_memo(state : PassageMemoState) -> PassageMemoState {
  if state.blocked {
    return state
  }
  let value = ToJson::to_json(state.memo).stringify()
  let issue = try {
    ignore(passage_memo_decode(value, state.memo.brief_id))
    reading_notes_storage_write(
      state.key,
      state.expected is Some(_),
      state.expected.unwrap_or(""),
      value,
    )
  } catch {
    error => "\{error}"
  }
  if issue.is_empty() {
    {
      ..state,
      expected: Some(value),
      saved: true,
      notice: "Passage collection saved in this browser. Native brief Save does not include it.",
    }
  } else {
    {
      ..state,
      saved: false,
      notice: issue +
      " Your collection remains in this session; download it or retry Save.",
    }
  }
}

///|
fn commit_passage_memo(
  state : PassageMemoState,
  memo : PassageMemo,
) -> PassageMemoState {
  let issue = try {
    ignore(
      passage_memo_decode(ToJson::to_json(memo).stringify(), memo.brief_id),
    )
    ""
  } catch {
    error => "\{error}"
  }
  if issue.is_empty() {
    save_passage_memo({ ..state, memo, })
  } else {
    { ..state, notice: issue + " Previous passages are unchanged.", }
  }
}

///|
fn sync_passage_memo(view : BriefView) -> BriefView {
  let key = "moonfind.passage-memo.v1:" + view.draft.brief_id
  let sessions = view.passage_memo_sessions.copy()
  let state = if view.passage_memo.key == key {
    view.passage_memo
  } else {
    sessions[view.passage_memo.key] = view.passage_memo
    let restored = sessions
      .get(key)
      .unwrap_or_else(() => restore_passage_memo(view.draft))
    { ..restored, token: brief_new_id(), }
  }
  let state = if state.sources != view.draft.sources {
    {
      ..state,
      sources: view.draft.sources,
      source_slot: 0,
      token: brief_new_id(),
    }
  } else {
    state
  }
  { ..view, passage_memo: state, passage_memo_sessions: sessions, }
}

///|
fn passage_current(view : BriefView, passage : EvidencePassage) -> Bool {
  view.draft.sources.get(passage.source_slot - 1) == Some(passage.source)
}

///|
fn passage_memo_markdown(view : BriefView) -> String raise {
  let state = view.passage_memo
  guard !view.pending &&
    !state.blocked &&
    state.key == "moonfind.passage-memo.v1:" + view.draft.brief_id else {
    fail("Wait for a readable passage collection for this brief.")
  }
  let memo = passage_memo_decode(
    ToJson::to_json(state.memo).stringify(),
    view.draft.brief_id,
  )
  let out = StringBuilder()
  out.write_string("# Evidence passage memo\n\n")
  out.write_string(
    "Researcher-selected quotations and interpretations. Support, contradiction, question and context are your labels, not verified findings. No recommendation, source authentication or completed research answer is inferred.\n\n",
  )
  out.write_string("## Question being explored\n\n")
  out.write_string(
    reading_report_literal(
      if memo.question.is_blank() {
        "No question recorded yet."
      } else {
        memo.question
      },
    ),
  )
  out.write_string(
    reading_report_literal(
      "Brief ID: " +
      memo.brief_id +
      "\nCollection revision: \{memo.revision}\nPassages: \{memo.passages.length()}\nBrowser save status: " +
      (if state.saved {
        "verified saved"
      } else {
        "NOT VERIFIED SAVED; current in-memory edits included"
      }),
    ),
  )
  if memo.passages.is_empty() {
    out.write_string("No evidence passages collected yet.\n\n")
  }
  for index, passage in memo.passages {
    out.write_string("## Passage \{index + 1}\n\n")
    out.write_string(
      reading_report_literal(
        [
          "Passage ID: " + passage.id,
          "Researcher label: " + passage.role,
          "Source: " + passage.source.name,
          "Original source slot: \{passage.source_slot}",
          "Inclusive lines: \{passage.first_line}–\{passage.last_line}",
          "Origin as supplied: " + passage.source.origin,
          "Capture time as supplied: " + passage.source.captured_at,
          "Capture kind: " + passage.source.kind,
          "Snapshot status: " +
          (if passage_current(view, passage) {
            "exact capture still in this brief slot"
          } else {
            "historical snapshot; current source moved, changed or was removed"
          }),
        ].join("\n"),
      ),
    )
    out.write_string("### Exact quoted passage\n\n")
    out.write_string(reading_report_literal(passage.quote))
    out.write_string("### Researcher interpretation / open question\n\n")
    out.write_string(
      reading_report_literal(
        if passage.note.is_blank() {
          "No interpretation recorded. This passage remains unassessed."
        } else {
          passage.note
        },
      ),
    )
  }
  out.write_string(
    "## Scope and recovery\n\nAll collected passages appear in collection order. Quoted CRLF, CR and LF endings are retained; line numbering follows those delimiters. A closing-fence separator may add a newline after a quote. Full source bodies are omitted here. The complete collection JSON includes exact original source bytes, including private or unselected content. Browser storage is scoped to origin and brief ID, not a native workspace; use distinct IDs for independent workspaces. Native brief Save, bibliography notes, choice worksheets and provider jobs remain separate. Review this memo before sharing.\n",
  )
  let content = out.to_string()
  guard brief_text_hex(content).length() <= 2 * 1024 * 1024 else {
    fail("The memo exceeds 1 MiB; use the complete collection JSON instead.")
  }
  content
}

///|
extern "js" fn passage_memo_download(content : String, json : Bool) -> String =
  #|(content,json) => {
  #| let url,link; try {
  #|  url=URL.createObjectURL(new Blob([content],{type:json?'application/json;charset=utf-8':'text/markdown;charset=utf-8'}));
  #|  link=document.createElement('a'); link.href=url; link.download=json?'moonfind-passage-collection.json':'moonfind-evidence-passage-memo.md'; document.body.appendChild(link); link.click(); return '';
  #| } catch(_){return 'Passage download failed; the collection remains available. Try again.';}
  #| finally {if(link)link.remove(); if(url)setTimeout(()=>URL.revokeObjectURL(url),1000);}
  #| }

///|
fn update_passage_memo(
  key : String,
  token : String,
  action : PassageMemoMsg,
  view : BriefView,
) -> (@rabbita.Cmd, BriefView) {
  let state = view.passage_memo
  if view.pending {
    return (@rabbita.none, view)
  }
  if key != state.key || token != state.token {
    return (
      @rabbita.none,
      {
        ..view,
        passage_memo: {
          ..state,
          notice: "That passage action is stale. Use the current collection controls.",
        },
      },
    )
  }
  let memo = state.memo
  let next = match action {
    RetryRead if state.blocked => restore_passage_memo(view.draft)
    _ if state.blocked => state
    RetryRead => state
    Save => save_passage_memo(state)
    Question(question) =>
      commit_passage_memo(state, {
        ..memo,
        question,
        revision: memo.revision + 1,
      })
    PassageSource(slot) =>
      if slot > 0 && slot <= view.draft.sources.length() {
        {
          ..state,
          source_slot: slot,
          first_line: "1",
          last_line: "1",
          role: "question",
          note: "",
        }
      } else {
        { ..state, source_slot: 0, }
      }
    FromSearch(slot, line) =>
      if dossier_search(view).hits.any(hit => {
          hit.slot == slot && hit.line == line
        }) {
        {
          ..state,
          source_slot: slot,
          first_line: line.to_string(),
          last_line: line.to_string(),
          role: "question",
          note: "",
          notice: "Search hit selected. Inspect the full passage, extend the line range if needed, then collect it.",
        }
      } else {
        {
          ..state,
          notice: "The search hit changed. Search again before selecting it.",
        }
      }
    FirstLine(value) => { ..state, first_line: value, }
    LastLine(value) => { ..state, last_line: value, }
    Role(role) =>
      if passage_role_valid(role) {
        { ..state, role, }
      } else {
        state
      }
    Note(note) =>
      if note.length() <= 10000 {
        { ..state, note, }
      } else {
        {
          ..state,
          notice: "An interpretation is limited to 10,000 characters.",
        }
      }
    Collect =>
      try {
        guard state.source_slot > 0 &&
          state.source_slot <= view.draft.sources.length() else {
          fail("Choose a current source capture.")
        }
        let source = view.draft.sources[state.source_slot - 1]
        let first = @string.parse_int(state.first_line)
        let last = @string.parse_int(state.last_line)
        let quote = passage_quote(source, first, last)
        let passage : EvidencePassage = {
          id: brief_new_id(),
          source_slot: state.source_slot,
          source,
          first_line: first,
          last_line: last,
          quote,
          role: state.role,
          note: state.note,
        }
        commit_passage_memo(state, {
          ..memo,
          revision: memo.revision + 1,
          passages: memo.passages + [passage],
        })
      } catch {
        error => { ..state, notice: "\{error} No passage was added.", }
      }
    RemovePassage(id) =>
      if memo.passages.any(passage => passage.id == id) {
        commit_passage_memo(state, {
          ..memo,
          revision: memo.revision + 1,
          passages: memo.passages.filter(passage => passage.id != id),
        })
      } else {
        state
      }
    Annotate(id, role, note) =>
      if memo.passages.any(passage => passage.id == id) &&
        passage_role_valid(role) {
        commit_passage_memo(state, {
          ..memo,
          revision: memo.revision + 1,
          passages: memo.passages.map(passage => {
            if passage.id == id {
              { ..passage, role, note, }
            } else {
              passage
            }
          }),
        })
      } else {
        state
      }
    ExportMarkdown | ExportJson => {
      let issue = try {
        let content = if action is ExportMarkdown {
          passage_memo_markdown(view)
        } else {
          let value = ToJson::to_json(memo).stringify(indent=2)
          ignore(passage_memo_decode(value, view.draft.brief_id))
          value
        }
        passage_memo_download(content, action is ExportJson)
      } catch {
        error => "\{error}"
      }
      {
        ..state,
        notice: if issue.is_empty() {
          "Passage download requested. Check the actual file; browser save state is unchanged. Review private source content before sharing."
        } else {
          issue
        },
      }
    }
  }
  (@rabbita.none, { ..view, passage_memo: { ..next, token: brief_new_id(), }, })
}
