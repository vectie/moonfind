///|
struct ReviewStorage {
  key : String
  blocked : Bool
  notice : String
  recovery : String
}

///|
struct SavedReviewDraft {
  contract_id : String
  context : String
  draft : ReviewDraft
} derive(ToJson, FromJson)

///|
extend SavedReviewDraft with ToJson::{to_json}

///|
fn empty_review_storage() -> ReviewStorage {
  { key: "", blocked: false, notice: "", recovery: "", }
}

///|
fn blank_review_draft() -> ReviewDraft {
  {
    outcome: "",
    scope: "",
    message: "",
    information_severity: 1,
    information_summary: "Record what evidence was missing before the synthesis decision.",
    recognition_severity: 0,
    recognition_summary: "The named reviewer recognized the material evidence boundary.",
    decisiveness_severity: 1,
    decisiveness_summary: "Record what reviewed rule or experiment is still required before action.",
  }
}

///|
fn review_draft_json(model : Model) -> String {
  let envelope : SavedReviewDraft = {
    contract_id: "moonfind.review-draft.v1",
    context: review_result_context(model),
    draft: review_draft(model),
  }
  envelope.to_json().stringify(indent=2)
}

///|
fn decode_review_draft(
  text : String,
  model : Model,
) -> Result[ReviewDraft, String] {
  if model.trusted_book_dir.is_blank() {
    return Err("A trusted Book workspace is required to restore this draft.")
  }
  if text.length() > 131072 {
    return Err("Review draft exceeds the 128-KiB character limit.")
  }
  let value : SavedReviewDraft = @json.from_json(@json.parse(text)) catch {
    _ => return Err("Review draft is unreadable or has an unsupported shape.")
  }
  let draft = value.draft
  if value.contract_id != "moonfind.review-draft.v1" ||
    value.context != review_result_context(model) {
    return Err(
      "Review draft belongs to a different version, Book, run or exact synthesis digest.",
    )
  }
  if !(draft.outcome is ("" | "approve_subset" | "request_changes" | "reject")) ||
    [
      draft.information_severity,
      draft.recognition_severity,
      draft.decisiveness_severity,
    ].any(value => value < 0 || value > 5) {
    return Err("Review draft has invalid decision or Three-Gap fields.")
  }
  guard current_synthesis(model) is Some(output) else {
    return Err("Reload a correlated synthesis before restoring a draft.")
  }
  if review_scope_ids(draft.scope).any(id => {
      !safe_review_scope_id(id) || !output.ideas.any(idea => idea.id == id)
    }) {
    return Err(
      "Review draft includes an ID outside the exact displayed synthesis.",
    )
  }
  Ok(draft)
}

///|
fn restore_review_storage(model : Model, session : ReviewDraft?) -> Model {
  guard !model.trusted_book_dir.is_blank() &&
    current_synthesis(model) is Some(_) else {
    return { ..model, review_storage: empty_review_storage(), }
  }
  let key = "moonfind.review-draft.v1:" + review_result_context(model)
  let base : ReviewStorage = {
    key,
    blocked: false,
    notice: "No saved draft for this exact result. Edits autosave in this browser; keep a JSON backup.",
    recovery: "",
  }
  let reply = @json.parse(choice_storage_read(key)) catch { _ => Json::null() }
  let (storage, draft) = match reply {
    { "missing": True, .. } => (base, blank_review_draft())
    { "value": String(raw), .. } =>
      match decode_review_draft(raw, model) {
        Ok(draft) =>
          (
            {
              ..base,
              notice: "Restored a browser-local form draft for this exact Book, run and synthesis. No approval, receipt or submission was restored.",
            },
            draft,
          )
        Err(error) =>
          (
            {
              ..base,
              blocked: true,
              recovery: raw,
              notice: error +
              " Saving is paused to preserve the original bytes. Download them, then explicitly restore a valid backup or clear this draft.",
            },
            blank_review_draft(),
          )
      }
    _ =>
      (
        {
          ..base,
          blocked: true,
          notice: "Browser draft could not be read. Saving is paused; retry reading, restore a valid backup or explicitly clear this draft.",
        },
        blank_review_draft(),
      )
  }
  let storage = if session is Some(retained) &&
    retained.to_json() != draft.to_json() {
    {
      ..storage,
      notice: "Restored edits retained during this visit. These fields are not verified saved; retry saving or download a backup. " +
      storage.notice,
    }
  } else {
    storage
  }
  apply_review_draft(
    { ..model, review_storage: storage, },
    session.unwrap_or(draft),
  )
}

///|
fn save_review_draft(model : Model) -> Model {
  guard !model.trusted_book_dir.is_blank() &&
    current_synthesis(model) is Some(_) &&
    model.review_storage.key ==
    "moonfind.review-draft.v1:" + review_result_context(model) else {
    return model
  }
  if model.review_storage.blocked {
    return {
      ..model,
      review_storage: {
        ..model.review_storage,
        notice: "Edits remain in this visit. Saving is paused to preserve unreadable storage; download your draft or explicitly restore/clear.",
      },
    }
  }
  let text = review_draft_json(model)
  let error = if text.length() > 131072 {
    "Draft exceeds the 128-KiB character limit; edits remain unsaved in this visit. Shorten the text or download a backup."
  } else {
    choice_storage_write(model.review_storage.key, text)
  }
  {
    ..model,
    review_storage: {
      ..model.review_storage,
      notice: if error == "" {
        "Saved this exact-result form draft in this browser. It is not a submitted review or approval."
      } else {
        error
      },
    },
  }
}

///|
extern "js" fn review_draft_download(content : String) -> String =
  #| content => {
  #|   try {
  #|     if (typeof document === 'undefined' || typeof URL.createObjectURL !== 'function') return 'Download is unavailable in this host. Copy the JSON below.';
  #|     const url = URL.createObjectURL(new Blob([content], {type:'application/json;charset=utf-8'}));
  #|     const link = document.createElement('a'); link.href=url; link.download='moonfind-review-draft.json';
  #|     document.body.appendChild(link); link.click(); link.remove(); setTimeout(() => URL.revokeObjectURL(url),1000); return '';
  #|   } catch (_) { return 'Download failed. Copy the JSON below; your draft is unchanged.'; }
  #| }

///|
fn update_review_draft(
  model : Model,
  context : String,
  action : String,
  value : String,
) -> Model {
  guard !model.trusted_book_dir.is_blank() &&
    context == review_result_context(model) &&
    current_synthesis(model) is Some(_) else {
    return model
  }
  if action == "input" {
    return {
      ..model,
      review_storage: { ..model.review_storage, recovery: value, },
    }
  }
  if action == "backup" || action == "raw" {
    let text = if action == "raw" {
      model.review_storage.recovery
    } else {
      review_draft_json(model)
    }
    let error = review_draft_download(text)
    return {
      ..model,
      review_storage: {
        ..model.review_storage,
        recovery: text,
        notice: if error == "" {
          "JSON download requested. The same exact bytes are available below to copy."
        } else {
          error
        },
      },
    }
  }
  guard model.review_phase != ReviewPreparing else { return model }
  match action {
    "save" => save_review_draft(model)
    "retry" => restore_review_storage(model, Some(review_draft(model)))
    "clear" =>
      // Explicitly replace only this browser-local form with an empty draft.
      // Native review state and authority are untouched.
      save_review_draft(
        apply_review_draft(
          {
            ..model,
            review_storage: {
              ..model.review_storage,
              blocked: false,
              recovery: "",
            },
          },
          blank_review_draft(),
        ),
      )
    "restore" =>
      match decode_review_draft(model.review_storage.recovery, model) {
        Err(error) =>
          {
            ..model,
            review_storage: { ..model.review_storage, notice: error, },
          }
        Ok(draft) =>
          save_review_draft(
            apply_review_draft(
              {
                ..model,
                review_storage: { ..model.review_storage, blocked: false, },
              },
              draft,
            ),
          )
      }
    _ => model
  }
}

///|
fn review_draft_panel(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  if current_synthesis(model) is None {
    return @html.nothing
  }
  if model.trusted_book_dir.is_blank() {
    return p(
      "Trusted Book context is missing. The result remains readable, but review draft storage and preparation are unavailable until the host supplies that identity.",
    )
  }
  let context = review_result_context(model)
  details(class="review-draft-storage", open=true, [
    summary("Save, resume and back up this review draft"),
    p(
      "Browser-local pre-submit form only. Selected IDs, rationale and Three-Gap fields stay bound to this exact trusted Book, run and source digest. Other result drafts stay separately stored. Preparing a review still requires your explicit action.",
    ),
    p(
      attrs=@html.Attrs::build().role("status").aria_live("polite"),
      model.review_storage.notice,
    ),
    button(
      disabled=model.review_phase == ReviewPreparing,
      on_click=emit(ReviewDraftAction(context, "save", "")),
      "Retry saving draft",
    ),
    button(
      disabled=model.review_phase == ReviewPreparing,
      on_click=emit(ReviewDraftAction(context, "retry", "")),
      "Retry reading storage; keep my edits",
    ),
    button(
      on_click=emit(ReviewDraftAction(context, "backup", "")),
      "Download draft JSON",
    ),
    button(
      disabled=model.review_phase == ReviewPreparing,
      on_click=emit(ReviewDraftAction(context, "clear", "")),
      "Clear this local form draft",
    ),
    p(
      "Back up first. Clear replaces only this result's local draft with empty fields. Restore replaces only this local form; neither action submits, approves or erases native review history.",
    ),
    textarea(
      value=model.review_storage.recovery,
      rows=4,
      attrs=@html.Attrs::build().aria_label(
        "Review draft JSON backup or retained unreadable bytes",
      ),
      on_input=emit.map(value => ReviewDraftAction(context, "input", value)),
      "",
    ),
    button(
      on_click=emit(ReviewDraftAction(context, "raw", "")),
      "Download the JSON text above",
    ),
    button(
      disabled=model.review_phase == ReviewPreparing,
      on_click=emit(ReviewDraftAction(context, "restore", "")),
      "Restore this exact-result form draft",
    ),
  ])
}
