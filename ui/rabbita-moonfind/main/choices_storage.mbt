///|
extern "js" fn choice_storage_read(key : String) -> String =
  #| key => {
  #|   try {
  #|     if (!globalThis.localStorage) return JSON.stringify({error:"Browser storage is unavailable. Download a JSON backup before leaving."});
  #|     const value = globalThis.localStorage.getItem(key);
  #|     return JSON.stringify(value === null ? {missing:true} : {value});
  #|   } catch (_) { return JSON.stringify({error:"Browser storage could not be read. Existing bytes have not been replaced."}); }
  #| }

///|
extern "js" fn choice_storage_write(key : String, value : String) -> String =
  #| (key, value) => {
  #|   try {
  #|     if (!globalThis.localStorage) return "Browser storage is unavailable. Download a JSON backup before leaving.";
  #|     globalThis.localStorage.setItem(key, value);
  #|     if (globalThis.localStorage.getItem(key) !== value) return "Browser save could not be verified. Download a JSON backup.";
  #|     return "";
  #|   } catch (_) { return "Browser save failed. Your edits remain in this session; download a JSON backup or retry Save."; }
  #| }

///|
extern "js" fn choice_download(content : String, format : String) -> String =
  #| (content, format) => {
  #|   try {
  #|     if (typeof document === "undefined" || typeof URL.createObjectURL !== "function") return "Download is unavailable in this host.";
  #|     const ext = format === "json" ? "json" : "md";
  #|     const url = URL.createObjectURL(new Blob([content], {type: ext === "json" ? "application/json;charset=utf-8" : "text/plain;charset=utf-8"}));
  #|     const link = document.createElement("a");
  #|     link.href = url; link.download = (format === "experiment-md" ? "moonfind-experiment-plan." : "moonfind-decision-brief.") + ext;
  #|     document.body.appendChild(link); link.click(); link.remove();
  #|     setTimeout(() => URL.revokeObjectURL(url), 1000);
  #|     return "";
  #|   } catch (_) { return "Download failed. Your worksheet is unchanged; try again."; }
  #| }

///|
fn choice_restore_state(
  key : String,
  workspace : DurableResearchWorkspace,
  reply : String,
) -> ChoiceState {
  let state = {
    ..empty_choices(),
    key,
    sheet: Some(new_choice_sheet(workspace)),
  }
  let parsed = @json.parse(reply) catch { _ => Json::null() }
  match parsed {
    { "missing": True, .. } =>
      {
        ..state,
        notice: "New browser-local worksheet. Edits autosave here; keep a downloaded backup.",
      }
    { "value": String(value), .. } =>
      match choice_decode(value, workspace.run_id) {
        Ok(sheet) =>
          {
            ..state,
            sheet: Some(sheet),
            notice: "Restored browser-local worksheet revision \{sheet.revision}.",
          }
        Err(error) =>
          {
            ..state,
            notice: error +
            " Saving is paused; restore a valid JSON backup to continue.",
            save_blocked: true,
            recovery_input: value,
          }
      }
    { "error": String(error), .. } =>
      {
        ..state,
        notice: error + " Saving is paused until a valid backup is restored.",
        save_blocked: true,
      }
    _ =>
      {
        ..state,
        notice: "Storage response is unreadable. Saving is paused; restore a valid JSON backup.",
        save_blocked: true,
      }
  }
}

///|
fn sync_choices(model : Model) -> Model {
  guard model.workspace is Some(workspace) else { return model }
  let identity : Json = {
    "book": model.trusted_book_dir,
    "run": workspace.run_id,
  }
  let key = "moonfind.choice.v1:" + identity.stringify()
  if model.choices.key == key {
    return model
  }
  let sessions = model.choice_sessions.copy()
  if model.choices.key != "" {
    sessions[model.choices.key] = model.choices
  }
  let restored = match sessions.get(key) {
    Some(retained) => retained
    None => choice_restore_state(key, workspace, choice_storage_read(key))
  }
  { ..model, choices: restored, choice_sessions: sessions, }
}

///|
fn save_choices(state : ChoiceState) -> ChoiceState {
  guard state.sheet is Some(sheet) else { return state }
  if state.save_blocked {
    return {
      ..state,
      notice: "Saving is paused to preserve unreadable stored data. Download your edits or restore a valid backup.",
    }
  }
  let error = choice_storage_write(state.key, sheet.to_json().stringify())
  {
    ..state,
    notice: if error == "" {
      "Saved revision \{sheet.revision} in this browser. Download a backup for portability."
    } else {
      error
    },
  }
}

///|
fn update_choices(model : Model, action : ChoiceMsg) -> Model {
  let state = model.choices
  guard state.sheet is Some(sheet) else { return model }
  let next = match action {
    Experiment(key, revision, preview, worksheet, operation) =>
      if key != state.key ||
        revision != sheet.revision ||
        worksheet != sheet.to_json().stringify() ||
        preview !=
        model.workspace
        .map(value => choice_evidence(value).to_json().stringify())
        .unwrap_or("") {
        {
          ..state,
          notice: "The worksheet or research changed since this action. Review the current test card and try again; no experiment was changed.",
        }
      } else {
        match operation {
          Download(id) =>
            match
              sheet.experiments
              .unwrap_or([])
              .filter(value => value.id == id)
              .get(0) {
              None =>
                { ..state, notice: "That test card is no longer available.", }
              Some(card) => {
                let error = choice_download(
                  experiment_markdown(card) +
                  "\nCurrent context: " +
                  experiment_context(card, sheet, model.workspace) +
                  "\n",
                  "experiment-md",
                )
                {
                  ..state,
                  notice: if error == "" {
                    "Download requested for this exact test card. Use the JSON worksheet backup to restore all tests and history."
                  } else {
                    error
                  },
                }
              }
            }
          _ =>
            match experiment_change(sheet, operation) {
              Err(error) => { ..state, notice: error, }
              Ok(edited) => save_choices({ ..state, sheet: Some(edited), })
            }
        }
      }
    ContinueEvidence(revision, preview) =>
      if state.save_blocked {
        {
          ..state,
          notice: "Restore a valid backup before continuing; unreadable stored data is preserved.",
        }
      } else if revision != sheet.revision ||
        model.workspace
        .map(ws => choice_evidence(ws).to_json().stringify())
        .unwrap_or("") !=
        preview {
        {
          ..state,
          notice: "The worksheet or research changed since this preview. Review the new comparison and continue again.",
        }
      } else {
        match choice_continue(sheet, model.workspace) {
          Err(error) => { ..state, notice: error, }
          Ok(continued) => save_choices({ ..state, sheet: Some(continued), })
        }
      }
    ExportRevision(revision, format) =>
      match
        sheet.history
        .unwrap_or([])
        .filter(value => value.revision == revision)
        .get(0) {
        None => { ..state, notice: "That retained version is not available.", }
        Some(archive) => {
          let previous = choice_version(sheet, archive)
          let current = choice_current(previous, model.workspace)
          let content = if format == "json" {
            choice_export_json(previous, current).stringify(indent=2) + "\n"
          } else {
            choice_markdown(previous, current)
          }
          let error = choice_download(content, format)
          {
            ..state,
            notice: if error == "" {
              "Download requested for retained revision \{revision}. Current work is unchanged."
            } else {
              error
            },
          }
        }
      }
    SetRecovery(text) => { ..state, recovery_input: text, }
    Restore =>
      match choice_decode(state.recovery_input, sheet.evidence.run_id) {
        Err(error) => { ..state, notice: error, }
        Ok(restored) =>
          // A successful import replaces only this local draft after an explicit
          // action. The user can download the outgoing draft before restoring.
          save_choices({ ..state, sheet: Some(restored), save_blocked: false, })
      }
    Save => save_choices(state)
    Export(format) => {
      let current = choice_current(sheet, model.workspace)
      let text = if format == "json" {
        choice_export_json(sheet, current).stringify(indent=2) + "\n"
      } else {
        choice_markdown(sheet, current)
      }
      let error = choice_download(text, format)
      {
        ..state,
        notice: if error == "" {
          "Download requested for the exact displayed revision. This records no company decision or review."
        } else {
          error
        },
      }
    }
    _ => {
      let edited = choice_edit(sheet, action)
      if choice_export_json(edited, false).stringify(indent=2).length() + 1 >
        2000000 {
        {
          ..state,
          notice: "This edit would exceed the 2-million-character backup limit. The previous draft and its history are unchanged.",
        }
      } else {
        save_choices({ ..state, sheet: Some(edited), })
      }
    }
  }
  { ..model, choices: next, }
}
