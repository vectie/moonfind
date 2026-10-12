///|
// Notes are independent point-in-time records, never a DOI-keyed metadata merge.
struct ReadingNote {
  id : String
  reference : ReadingReference
  capture : BriefInputSource
  text : String
  attached : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
struct ReadingNotebook {
  contract_id : String
  brief_id : String
  revision : Int
  sources : Array[BriefInputSource]
  notes : Array[ReadingNote]
} derive(Debug, Eq, ToJson, FromJson)

///|
struct ReadingNotesState {
  key : String
  notebook : ReadingNotebook
  expected : String?
  blocked : Bool
  saved : Bool
  selected : String
  notice : String
  unreadable : String
  report_query : String
  report_scope : String
  import_text : String
  import_token : String
  import_preview : ReadingNotesImport?
}

///|
enum ReadingNotesMsg {
  Create(ReferenceChoice)
  Select(String)
  Write(String, String)
  Save
  RetryRead
  ReportQuery(String)
  ReportScope(String)
  ClearReport
  ExportReport
  ExportBackup
  ImportText(String)
  PreviewImport
  ConfirmImport(String)
  ChooseBackup
  BackupLoaded(String, String)
  CancelImport
}

///|
fn empty_reading_notes(draft : BriefDraft) -> ReadingNotesState {
  {
    key: "moonfind.reading-notes.v1:" + draft.brief_id,
    notebook: {
      contract_id: "moonfind.reading-notes.v1",
      brief_id: draft.brief_id,
      revision: 0,
      sources: draft.sources,
      notes: [],
    },
    expected: None,
    blocked: false,
    saved: true,
    selected: "",
    notice: "No reading notes saved for this brief in this browser.",
    unreadable: "",
    report_query: "",
    report_scope: "all",
    import_text: "",
    import_token: "",
    import_preview: None,
  }
}

///|
fn reading_notes_decode(
  text : String,
  brief_id : String,
) -> ReadingNotebook raise {
  guard brief_text_hex(text).length() <= 2 * 1024 * 1024 else {
    fail("Reading notebook exceeds 1 MiB")
  }
  let book : ReadingNotebook = @json.from_json(@json.parse(text))
  guard book.contract_id == "moonfind.reading-notes.v1" &&
    book.brief_id == brief_id &&
    book.revision >= 0 &&
    book.notes.length() <= 100 &&
    book.sources.length() <= 8 else {
    fail("Unsupported or mismatched reading notebook")
  }
  let ids : Map[String, Bool] = Map([])
  for note in book.notes {
    guard !note.id.is_blank() &&
      !ids.contains(note.id) &&
      note.text.length() <= 10000 &&
      note.reference.source_slot > 0 &&
      note.reference.source_slot <= 8 &&
      reference_selection(note.capture, note.reference.source_slot).contains(
        note.reference,
      ) else {
      fail("Invalid or mismatched retained note snapshot")
    }
    ids[note.id] = true
    if note.attached &&
      book.sources.get(note.reference.source_slot - 1) != Some(note.capture) {
      fail("Attached reading note has a mismatched source capture")
    }
  }
  book
}

///|
fn restore_reading_notes(draft : BriefDraft) -> ReadingNotesState {
  let state = empty_reading_notes(draft)
  let reply = @json.parse(choice_storage_read(state.key)) catch {
    _ => Json::null()
  }
  match reply {
    { "missing": True, .. } => state
    { "value": String(value), .. } =>
      try {
        let notebook = reading_notes_decode(value, draft.brief_id)
        {
          ..state,
          notebook,
          expected: Some(value),
          notice: "Restored exact browser-local reading notes and capture snapshots.",
        }
      } catch {
        error =>
          {
            ..state,
            expected: Some(value),
            blocked: true,
            unreadable: value,
            notice: "Stored notes are unreadable and have not been replaced. Copy the retained bytes before repairing browser storage. Details: \{error}",
          }
      }
    _ =>
      {
        ..state,
        blocked: true,
        notice: "Browser reading-note storage could not be read. Saving is paused to preserve existing bytes. Retry reading when storage is available.",
      }
  }
}

///|
// Compare-before-write prevents a stale tab from overwriting another tab's notes.
extern "js" fn reading_notes_storage_write(
  key : String,
  present : Bool,
  expected : String,
  value : String,
) -> String =
  #|(key,present,expected,value) => {
  #| try {
  #|  const store=globalThis.localStorage;
  #|  if(!store) return 'Browser storage is unavailable. Keep this page open and copy your notes before leaving.';
  #|  if(store.getItem(key)!==(present?expected:null)) return 'Stored notes changed elsewhere. Your edits remain here; existing stored bytes were not replaced. Copy your edits before reloading.';
  #|  store.setItem(key,value);
  #|  if(store.getItem(key)!==value) return 'Browser save could not be verified. Keep this page open and copy your notes.';
  #|  return '';
  #| } catch (_) {return 'Browser note save failed. Your edits remain in this session; retry Save or copy your notes before leaving.';}
  #|}

///|
fn save_reading_notes(state : ReadingNotesState) -> ReadingNotesState {
  if state.blocked {
    return state
  }
  let value = ToJson::to_json(state.notebook).stringify()
  if brief_text_hex(value).length() > 2 * 1024 * 1024 {
    return {
      ..state,
      saved: false,
      notice: "Notebook exceeds 1 MiB. Existing stored bytes are unchanged; shorten a note before retrying Save.",
    }
  }
  let error = reading_notes_storage_write(
    state.key,
    state.expected is Some(_),
    state.expected.unwrap_or(""),
    value,
  )
  if error.is_empty() {
    {
      ..state,
      expected: Some(value),
      saved: true,
      notice: "Saved in this browser only. Native brief Save does not include these notes.",
    }
  } else {
    { ..state, saved: false, notice: error, }
  }
}

///|
fn commit_reading_note(
  previous : ReadingNotesState,
  edited : ReadingNotesState,
) -> ReadingNotesState {
  if brief_text_hex(ToJson::to_json(edited.notebook).stringify()).length() >
    2 * 1024 * 1024 {
    {
      ..previous,
      notice: "This edit would exceed the 1 MiB notebook limit. The previous notes and stored bytes are unchanged.",
    }
  } else {
    save_reading_notes(edited)
  }
}

///|
fn sync_reading_notes(view : BriefView) -> BriefView {
  let key = "moonfind.reading-notes.v1:" + view.draft.brief_id
  let sessions = view.reading_note_sessions.copy()
  let state = if view.reading_notes.key == key {
    view.reading_notes
  } else {
    sessions[view.reading_notes.key] = view.reading_notes
    sessions.get(key).unwrap_or_else(() => restore_reading_notes(view.draft))
  }
  let book = state.notebook
  let next = if !state.blocked && book.sources != view.draft.sources {
    let appended = reference_sources_appended(book.sources, view.draft.sources)
    let edited = {
      ..state,
      notebook: {
        ..book,
        sources: view.draft.sources,
        revision: book.revision + 1,
        notes: book.notes.map(note => {
          if appended {
            note
          } else {
            { ..note, attached: false, }
          }
        }),
      },
    }
    // Empty notebooks need no storage; source transitions with notes are retained.
    if book.notes.is_empty() {
      edited
    } else {
      save_reading_notes(edited)
    }
  } else {
    state
  }
  let next = match next.import_preview {
    Some(preview) if preview.revision != next.notebook.revision =>
      { ..next, import_preview: None, }
    _ => next
  }
  { ..view, reading_notes: next, reading_note_sessions: sessions, }
}

///|
fn reading_note_current(view : BriefView, note : ReadingNote) -> Bool {
  note.attached &&
  view.draft.sources.get(note.reference.source_slot - 1) == Some(note.capture) &&
  reference_catalog(view).references.contains(note.reference)
}

///|
fn update_reading_notes(
  emit : @rabbita.Emit[Msg],
  key : String,
  revision : Int,
  action : ReadingNotesMsg,
  view : BriefView,
) -> (@rabbita.Cmd, BriefView) {
  let state = view.reading_notes
  let book = state.notebook
  if view.pending {
    return (@rabbita.none, view)
  }
  if key != state.key || revision != book.revision {
    return (
      @rabbita.none,
      {
        ..view,
        reading_notes: {
          ..state,
          notice: "That note action is stale. Review the current brief and note before trying again.",
        },
      },
    )
  }
  if action is ChooseBackup && !state.blocked {
    let token = brief_new_id()
    return (
      @cmd.custom_cmd(scheduler => {
        reading_notes_choose_backup(value => {
          scheduler.add(
            emit(
              BriefAction(
                ReadingNotes(key, revision, BackupLoaded(token, value)),
              ),
            ),
          )
        })
      }),
      {
        ..view,
        reading_notes: {
          ..state,
          import_token: token,
          import_preview: None,
          notice: "Choose a reading-note JSON backup to preview. No notes will change until you confirm.",
        },
      },
    )
  }
  let next = match action {
    RetryRead if state.blocked => restore_reading_notes(view.draft)
    RetryRead => state
    _ if state.blocked => state
    ReportQuery(query) => { ..state, report_query: query, }
    ReportScope(scope) =>
      if scope is ("all" | "attached" | "detached") {
        { ..state, report_scope: scope, }
      } else {
        state
      }
    ClearReport => { ..state, report_query: "", report_scope: "all", }
    ExportReport => {
      let error = reading_report_download(reading_report_markdown(view)) catch {
        error => "\{error}"
      }
      {
        ..state,
        notice: if error.is_empty() {
          "Annotated report download requested for the matching in-memory notes. Check the actual file; it includes private notes and source metadata. Notes and native brief are unchanged."
        } else {
          error
        },
      }
    }
    ExportBackup
    | ImportText(_)
    | PreviewImport
    | ConfirmImport(_)
    | CancelImport
    | ChooseBackup
    | BackupLoaded(_, _) => update_reading_notes_transfer(action, state)
    Select(id) =>
      if book.notes.any(note => note.id == id) {
        { ..state, selected: id, }
      } else {
        state
      }
    Save => save_reading_notes(state)
    Create(choice) =>
      if !reference_choice_current(view, reference_catalog(view), choice) {
        {
          ..state,
          notice: "This reference changed. Choose its current card again; no note was created.",
        }
      } else if book.notes.length() >= 100 {
        {
          ..state,
          notice: "This notebook already has 100 notes. Existing notes are unchanged.",
        }
      } else {
        let id = brief_new_id()
        let note : ReadingNote = {
          id,
          reference: choice.reference,
          capture: choice.capture,
          text: "",
          attached: true,
        }
        commit_reading_note(state, {
          ..state,
          selected: id,
          notebook: {
            ..book,
            revision: book.revision + 1,
            notes: book.notes + [note],
          },
        })
      }
    Write(id, text) =>
      if text.length() > 10000 {
        {
          ..state,
          notice: "A reading note can contain at most 10,000 characters. The previous note is unchanged.",
        }
      } else if state.selected != id || !book.notes.any(note => note.id == id) {
        { ..state, notice: "Select the retained note before editing it.", }
      } else {
        commit_reading_note(state, {
          ..state,
          notebook: {
            ..book,
            revision: book.revision + 1,
            notes: book.notes.map(note => {
              if note.id == id {
                { ..note, text, }
              } else {
                note
              }
            }),
          },
        })
      }
  }
  (@rabbita.none, sync_reading_notes({ ..view, reading_notes: next, }))
}
