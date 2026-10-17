///|
// Confirmed decisions append to history; DOI peers never share a decision.
struct ScreeningDecision {
  sequence : Int
  reference : ReadingReference
  capture : BriefInputSource
  decision : String
  rationale : String
  attached : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
struct ScreeningLog {
  contract_id : String
  brief_id : String
  revision : Int
  sources : Array[BriefInputSource]
  decisions : Array[ScreeningDecision]
} derive(Debug, Eq, ToJson, FromJson)

///|
struct ScreeningState {
  key : String
  log : ScreeningLog
  expected : String?
  blocked : Bool
  saved : Bool
  unreadable : String
  notice : String
  scope : String
  editor : ReferenceChoice?
  decision : String
  rationale : String
}

///|
enum ScreeningMsg {
  Screen(ReferenceChoice)
  Decision(String)
  Rationale(String)
  SaveDecision(Bool)
  Cancel
  Scope(String)
  RetrySave
  RetryRead
  ExportJson
  ExportCsv
}

///|
fn screening_valid_decision(value : String) -> Bool {
  value is ("include" | "exclude" | "undecided")
}

///|
fn screening_latest(
  view : BriefView,
  reference : ReadingReference,
) -> ScreeningDecision? {
  let capture = view.draft.sources.get(reference.source_slot - 1)
  let mut latest = None
  for entry in view.screening.log.decisions {
    if entry.attached &&
      entry.reference == reference &&
      Some(entry.capture) == capture {
      latest = Some(entry)
    }
  }
  latest
}

///|
fn screening_status(view : BriefView, reference : ReadingReference) -> String {
  screening_latest(view, reference).map(x => x.decision).unwrap_or("unscreened")
}

///|
fn screening_matches(view : BriefView) -> Array[ReadingReference] {
  reference_matches(view, reference_catalog(view)).filter(reference => {
    view.screening.scope == "all" ||
    screening_status(view, reference) == view.screening.scope
  })
}

///|
fn screening_start(
  view : BriefView,
  choice : ReferenceChoice,
) -> ScreeningState {
  let state = view.screening
  if state.editor is Some(current) {
    if current == choice {
      return state
    }
    let previous = screening_latest(view, current.reference)
    let changed = state.rationale !=
      previous.map(x => x.rationale).unwrap_or("") ||
      state.decision != previous.map(x => x.decision).unwrap_or("undecided")
    if changed {
      return {
        ..state,
        notice: "Save or cancel your current editor changes before choosing another citation. Your rationale is still here.",
      }
    }
  }
  if !reference_choice_current(view, reference_catalog(view), choice) {
    return {
      ..state,
      notice: "This citation changed. Choose its current card again.",
    }
  }
  let previous = screening_latest(view, choice.reference)
  {
    ..state,
    editor: Some(choice),
    decision: previous.map(x => x.decision).unwrap_or("undecided"),
    rationale: previous.map(x => x.rationale).unwrap_or(""),
    notice: "Review the supplied metadata and abstract, choose a decision and explain why. Save decision records it; edits alone do not.",
  }
}

///|
fn screening_commit(view : BriefView, next~ : Bool) -> ScreeningState raise {
  let state = view.screening
  guard state.editor is Some(choice) else {
    fail("Choose a citation to screen first.")
  }
  guard reference_choice_current(view, reference_catalog(view), choice) else {
    fail(
      "The source changed while editing. Copy your rationale, then choose the current citation again.",
    )
  }
  guard screening_valid_decision(state.decision) &&
    !state.rationale.is_blank() &&
    state.rationale.length() <= 2000 else {
    fail(
      "Choose Include, Exclude or Undecided and enter a rationale of 1–2,000 characters.",
    )
  }
  let same = screening_latest(view, choice.reference) is Some(previous) &&
    previous.decision == state.decision &&
    previous.rationale == state.rationale
  let committed = if same {
    {
      ..state,
      notice: "This exact decision and rationale are already recorded. No duplicate history entry added.",
    }
  } else {
    guard state.log.decisions.length() < 200 else {
      fail(
        "This brief has 200 retained decisions. Export the history and use a new brief for further screening; no history was removed.",
      )
    }
    let log = {
      ..state.log,
      revision: state.log.revision + 1,
      decisions: state.log.decisions +
      [
        {
          sequence: state.log.decisions.length() + 1,
          reference: choice.reference,
          capture: choice.capture,
          decision: state.decision,
          rationale: state.rationale,
          attached: true,
        },
      ],
    }
    guard brief_text_hex(ToJson::to_json(log).stringify()).length() <=
      2 * 1024 * 1024 else {
      fail(
        "This decision would exceed the 1 MiB log limit. The previous history is unchanged.",
      )
    }
    save_screening({ ..state, log, })
  }
  if next {
    let updated = { ..view, screening: committed, }
    let remaining = reference_matches(updated, reference_catalog(updated)).filter(r => {
        screening_status(updated, r) == "unscreened"
      },
    )
    if remaining.get(0) is Some(reference) {
      let started = screening_start(
        updated,
        reference_choice(updated, reference),
      )
      {
        ..started,
        notice: committed.notice + " Next unscreened citation opened.",
      }
    } else {
      {
        ..committed,
        editor: None,
        notice: committed.notice +
        " No unscreened citations remain within the reading-list filters.",
      }
    }
  } else {
    committed
  }
}

///|
fn update_screening(
  key : String,
  revision : Int,
  action : ScreeningMsg,
  view : BriefView,
) -> (@rabbita.Cmd, BriefView) {
  let state = view.screening
  if view.pending {
    return (@rabbita.none, view)
  }
  if key != state.key || revision != state.log.revision {
    return (
      @rabbita.none,
      {
        ..view,
        screening: {
          ..state,
          notice: "That screening action is stale. Review the current brief before trying again.",
        },
      },
    )
  }
  let updated = try {
    match action {
      RetryRead if state.blocked => restore_screening(view.draft)
      RetryRead => state
      _ if state.blocked => state
      Screen(choice) => screening_start(view, choice)
      Decision(value) if screening_valid_decision(value) =>
        { ..state, decision: value, }
      Decision(_) => state
      Rationale(value) => { ..state, rationale: value, }
      SaveDecision(next) => screening_commit(view, next~)
      Cancel => { ..state, editor: None, rationale: "", }
      Scope(value) if value == "all" ||
        value == "unscreened" ||
        screening_valid_decision(value) => { ..state, scope: value, }
      Scope(_) => state
      RetrySave => save_screening(state)
      ExportJson | ExportCsv => {
        let csv = action is ExportCsv
        let content = if csv {
          screening_csv(view)
        } else {
          screening_json(view)
        }
        let problem = screening_download(content, csv)
        {
          ..state,
          notice: if problem.is_empty() {
            "Screening download requested. Check the file before leaving. Review private rationales and source metadata before sharing."
          } else {
            problem
          },
        }
      }
    }
  } catch {
    error => { ..state, notice: "\{error}", }
  }
  (@rabbita.none, { ..view, screening: updated, })
}
