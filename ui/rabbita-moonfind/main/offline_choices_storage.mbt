///|
struct OfflineChoiceState {
  key : String
  sheet : OfflineWorksheet?
  notice : String
  blocked : Bool
  recovery : String
}

///|
enum OfflineChoiceMsg {
  OpenOffline(String)
  EditOffline(String, Int, Int, ChoiceMsg)
  ContinueOffline(String, Int, Int, String)
}

///|
fn empty_offline_choices() -> OfflineChoiceState {
  { key: "", sheet: None, notice: "", blocked: false, recovery: "", }
}

///|
fn offline_current(model : Model, sheet : OfflineWorksheet) -> Bool {
  offline_open_basis(model)
  .map(value => value.to_json() == sheet.current.basis.to_json())
  .unwrap_or(false)
}

///|
fn offline_restore(
  key : String,
  basis : BriefSnapshot,
  reply : String,
) -> OfflineChoiceState {
  let base = {
    ..empty_offline_choices(),
    key,
    sheet: Some(new_offline_sheet(basis)),
  }
  let parsed = @json.parse(reply) catch { _ => Json::null() }
  match parsed {
    { "missing": True, .. } =>
      {
        ..base,
        notice: "New offline comparison from this saved revision. Edits autosave locally; download a complete JSON backup.",
      }
    { "value": String(text), .. } =>
      match offline_decode(text, basis.brief.brief_id) {
        Ok(sheet) =>
          {
            ..base,
            sheet: Some(sheet),
            notice: "Restored offline comparison. Its exact retained basis is shown below; opening a different revision never silently replaces its evidence or direction.",
          }
        Err(error) =>
          {
            ..base,
            blocked: true,
            recovery: text,
            notice: error +
            " Saving is paused to preserve the original bytes. Back up first, then explicitly restore valid JSON.",
          }
      }
    _ =>
      {
        ..base,
        blocked: true,
        notice: "Browser comparison could not be read. Edits stay in this visit; saving is paused until a valid backup is explicitly restored.",
      }
  }
}

///|
fn offline_save(state : OfflineChoiceState) -> OfflineChoiceState {
  guard state.sheet is Some(sheet) else { return state }
  if state.blocked {
    return {
      ..state,
      notice: "Saving is paused to preserve unreadable stored bytes. Download current edits or restore a valid backup explicitly.",
    }
  }
  let text = sheet.to_json().stringify()
  let error = if offline_export_json(sheet, false).stringify(indent=2).length() +
    1 >
    2000000 {
    "Offline backup limit exceeded. This session is unsaved; shorten text or download it for salvage."
  } else {
    choice_storage_write(state.key, text)
  }
  {
    ..state,
    notice: if error == "" {
      "Saved offline worksheet revision \{sheet.current.revision} in this browser. No research or company decision was submitted."
    } else {
      error
    },
  }
}

///|
extern "js" fn offline_download(text : String, format : String) -> String =
  #| (text, format) => {
  #|   try {
  #|     if (typeof document === 'undefined' || typeof URL.createObjectURL !== 'function') return 'Download is unavailable here. Exact export text is shown below for copying.';
  #|     const ext = format === 'json' ? 'json' : 'md';
  #|     const url = URL.createObjectURL(new Blob([text], {type:ext === 'json' ? 'application/json;charset=utf-8' : 'text/plain;charset=utf-8'}));
  #|     const link=document.createElement('a');link.href=url;link.download='moonfind-offline-decision-brief.'+ext;
  #|     document.body.appendChild(link);link.click();link.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);return '';
  #|   } catch (_) { return 'Download failed. Exact export text is shown below; your worksheet is unchanged.'; }
  #| }

///|
fn offline_export_state(
  state : OfflineChoiceState,
  sheet : OfflineWorksheet,
  current : Bool,
  format : String,
) -> OfflineChoiceState {
  let text = if format == "json" {
    offline_export_json(sheet, current).stringify(indent=2) + "\n"
  } else {
    offline_markdown(sheet, current)
  }
  let error = offline_download(text, format)
  {
    ..state,
    recovery: text,
    notice: if error == "" {
      "Download requested for the exact displayed worksheet. Its complete export text is also available below."
    } else {
      error
    },
  }
}

///|
fn update_offline_choices(model : Model, action : OfflineChoiceMsg) -> Model {
  if action is OpenOffline(token) {
    guard offline_open_basis(model) is Some(basis) &&
      basis.to_json().stringify() == token else {
      return {
        ..model,
        offline_choices: {
          ..model.offline_choices,
          notice: "The saved brief changed or is incomplete. Reopen a prepared revision and choose Start again; no worksheet changed.",
        },
      }
    }
    let key = "moonfind.offline-choice.v1:" +
      [basis.brief.brief_id].to_json().stringify()
    if model.offline_choices.key == key {
      return model
    }
    if model.offline_generation >= 2147483647 {
      return {
        ..model,
        offline_choices: {
          ..model.offline_choices,
          notice: "Session action counter exhausted. Back up your worksheet, then reload before switching comparisons.",
        },
      }
    }
    let sessions = model.offline_choice_sessions.copy()
    if model.offline_choices.key != "" {
      sessions[model.offline_choices.key] = model.offline_choices
    }
    let state = sessions
      .get(key)
      .unwrap_or_else(() => {
        offline_restore(key, basis, choice_storage_read(key))
      })
    return {
      ..model,
      offline_choices: state,
      offline_generation: model.offline_generation + 1,
      offline_choice_sessions: sessions,
    }
  }
  let state = model.offline_choices
  guard state.sheet is Some(sheet) else { return model }
  let mut restored_generation = false
  let next = match action {
    OpenOffline(_) => state
    ContinueOffline(key, revision, generation, token) => {
      if key != state.key ||
        revision != sheet.current.revision ||
        generation != model.offline_generation {
        return model
      }
      if state.blocked {
        {
          ..state,
          notice: "Restore a valid backup before continuing; original stored bytes remain preserved.",
        }
      } else {
        match offline_open_basis(model) {
          Some(basis) if basis.to_json().stringify() == token =>
            match offline_continue(sheet, basis) {
              Ok(next) => offline_save({ ..state, sheet: Some(next), })
              Err(error) => { ..state, notice: error, }
            }
          _ =>
            {
              ..state,
              notice: "The saved source preview changed. Reopen it and review the current comparison; nothing was continued.",
            }
        }
      }
    }
    EditOffline(key, revision, generation, operation) => {
      if key != state.key ||
        revision != sheet.current.revision ||
        generation != model.offline_generation {
        return model
      }
      match operation {
        SetRecovery(value) => { ..state, recovery: value, }
        Restore =>
          if model.offline_generation >= 2147483647 {
            {
              ..state,
              notice: "Session action counter exhausted. Back up the worksheet and reload before restoring.",
            }
          } else {
            match
              offline_decode(state.recovery, sheet.current.basis.brief.brief_id) {
              Err(error) => { ..state, notice: error, }
              Ok(restored) => {
                restored_generation = true
                offline_save({ ..state, sheet: Some(restored), blocked: false, })
              }
            }
          }
        Save => offline_save(state)
        Export(format) =>
          offline_export_state(
            state,
            sheet,
            offline_current(model, sheet),
            format,
          )
        ExportRevision(revision, format) =>
          match
            sheet.history.filter(value => value.revision == revision).get(0) {
            None =>
              {
                ..state,
                notice: "That retained offline version is unavailable.",
              }
            Some(version) => {
              let old = {
                ..sheet,
                current: version,
                history: sheet.history.filter(value => value.revision < revision),
              }
              offline_export_state(
                state,
                old,
                offline_current(model, old),
                format,
              )
            }
          }
        ContinueEvidence(_, _) | Experiment(_, _, _, _, _) => state
        _ => {
          let edited = offline_edit(sheet, operation)
          if offline_export_json(edited, false).stringify(indent=2).length() + 1 >
            2000000 {
            {
              ..state,
              notice: "This edit would exceed the complete backup limit. The previous version and history are unchanged.",
            }
          } else {
            offline_save({ ..state, sheet: Some(edited), })
          }
        }
      }
    }
  }
  {
    ..model,
    offline_choices: next,
    offline_generation: if restored_generation {
      model.offline_generation + 1
    } else {
      model.offline_generation
    },
  }
}
