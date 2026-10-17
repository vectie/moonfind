///|
fn empty_screening(draft : BriefDraft) -> ScreeningState {
  {
    key: "moonfind.reference-screening.v1:" + draft.brief_id,
    log: {
      contract_id: "moonfind.reference-screening.v1",
      brief_id: draft.brief_id,
      revision: 0,
      sources: draft.sources,
      decisions: [],
    },
    expected: None,
    blocked: false,
    saved: true,
    unreadable: "",
    notice: "No screening decisions saved for this brief in this browser.",
    scope: "all",
    editor: None,
    decision: "undecided",
    rationale: "",
  }
}

///|
fn screening_decode(text : String, brief_id : String) -> ScreeningLog raise {
  guard brief_text_hex(text).length() <= 2 * 1024 * 1024 else {
    fail("Screening log exceeds 1 MiB")
  }
  let log : ScreeningLog = @json.from_json(@json.parse(text))
  guard log.contract_id == "moonfind.reference-screening.v1" &&
    log.brief_id == brief_id &&
    log.revision >= log.decisions.length() &&
    log.sources.length() <= 8 &&
    log.decisions.length() <= 200 else {
    fail("Unsupported or mismatched screening log")
  }
  for index, entry in log.decisions {
    guard entry.sequence == index + 1 &&
      screening_valid_decision(entry.decision) &&
      !entry.rationale.is_blank() &&
      entry.rationale.length() <= 2000 &&
      entry.reference.source_slot > 0 &&
      entry.reference.source_slot <= 8 &&
      reference_selection(entry.capture, entry.reference.source_slot).contains(
        entry.reference,
      ) else {
      fail("Invalid screening decision or mismatched retained citation")
    }
    guard !entry.attached ||
      log.sources.get(entry.reference.source_slot - 1) == Some(entry.capture) else {
      fail("Attached screening decision has a different source capture")
    }
  }
  log
}

///|
fn restore_screening(draft : BriefDraft) -> ScreeningState {
  let state = empty_screening(draft)
  let response = @json.parse(choice_storage_read(state.key)) catch {
    _ => Json::null()
  }
  match response {
    { "missing": True, .. } => state
    { "value": String(value), .. } =>
      try {
        let log = screening_decode(value, draft.brief_id)
        {
          ..state,
          log,
          expected: Some(value),
          notice: "Restored browser-local screening decisions and revision history.",
        }
      } catch {
        error =>
          {
            ..state,
            blocked: true,
            expected: Some(value),
            unreadable: value,
            notice: "Stored screening history is unreadable and has not been replaced. Retain these bytes before repairing storage. Details: \{error}",
          }
      }
    _ =>
      {
        ..state,
        blocked: true,
        notice: "Browser screening storage could not be read. Retry reading when storage is available; existing data will not be overwritten.",
      }
  }
}

///|
extern "js" fn screening_storage_write(
  key : String,
  present : Bool,
  expected : String,
  value : String,
) -> String =
  #|(key,present,expected,value) => {
  #| try {
  #|  const store=globalThis.localStorage;
  #|  if(!store) return 'Screening storage is unavailable. Export the in-memory history before leaving.';
  #|  if(store.getItem(key)!==(present?expected:null)) return 'Screening history changed in another tab. Your decisions remain here; existing stored bytes were not replaced. Export before reloading.';
  #|  store.setItem(key,value);
  #|  if(store.getItem(key)!==value) return 'Screening save could not be verified. Export your in-memory history before leaving.';
  #|  return '';
  #| } catch (_) {return 'Screening save failed. Decisions remain in this session. Retry Save or export before leaving.';}
  #|}

///|
fn save_screening(state : ScreeningState) -> ScreeningState {
  if state.blocked {
    return state
  }
  let value = ToJson::to_json(state.log).stringify()
  if brief_text_hex(value).length() > 2 * 1024 * 1024 {
    return {
      ..state,
      saved: false,
      notice: "Screening history exceeds 1 MiB. Existing stored bytes were not changed.",
    }
  }
  let problem = screening_storage_write(
    state.key,
    state.expected is Some(_),
    state.expected.unwrap_or(""),
    value,
  )
  if problem.is_empty() {
    {
      ..state,
      expected: Some(value),
      saved: true,
      notice: "Decision history saved in this browser only. Native brief Save does not include screening decisions.",
    }
  } else {
    { ..state, saved: false, notice: problem, }
  }
}

///|
fn sync_screening(view : BriefView) -> BriefView {
  let key = "moonfind.reference-screening.v1:" + view.draft.brief_id
  let sessions = view.screening_sessions.copy()
  let state = if key == view.screening.key {
    view.screening
  } else {
    sessions[view.screening.key] = view.screening
    sessions.get(key).unwrap_or_else(() => restore_screening(view.draft))
  }
  let updated = if !state.blocked && state.log.sources != view.draft.sources {
    let appended = reference_sources_appended(
      state.log.sources,
      view.draft.sources,
    )
    let edited = {
      ..state,
      log: {
        ..state.log,
        revision: state.log.revision + 1,
        sources: view.draft.sources,
        decisions: state.log.decisions.map(entry => {
          if appended {
            entry
          } else {
            { ..entry, attached: false, }
          }
        }),
      },
    }
    if state.log.decisions.is_empty() {
      edited
    } else {
      save_screening(edited)
    }
  } else {
    state
  }
  { ..view, screening: updated, screening_sessions: sessions, }
}
