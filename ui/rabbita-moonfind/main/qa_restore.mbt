///|
// Every retained-session read is bound to the snapshot that authorized it.
// Neither a matching run nor a matching session key alone is sufficient.
struct QaRestoreRequest {
  workspace_generation : Int
  run_id : String
  gateway : String
  cwd : String
  session_key : String
} derive(Debug, Eq)

///|
fn snapshot_qa_state(snapshot : WorkspaceSnapshot) -> String {
  match snapshot.qa_agent_status {
    "reconnect-required" => "reconnect-required"
    "creation-uncertain" => "creation-uncertain"
    "retained" | "grounded_verified" =>
      if snapshot.qa_cowork_session_key is Some(key) && !key.is_blank() {
        "retained"
      } else {
        "creation-uncertain"
      }
    "not-created" | "not-published" =>
      if snapshot.qa_cowork_session_key is Some(key) && !key.is_blank() {
        "reconnect-required"
      } else {
        "not-created"
      }
    _ => "creation-uncertain"
  }
}

///|
fn qa_restore_current(model : Model, request : QaRestoreRequest) -> Bool {
  model.pending_qa_restore == Some(request) &&
  model.workspace_generation == request.workspace_generation &&
  model.workspace.map(ws => ws.run_id) == Some(request.run_id) &&
  model.gateway_published &&
  model.gateway_base == request.gateway &&
  model.book_dir == request.cwd &&
  model.trusted_book_dir == request.cwd &&
  model.qa_canonical_key == Some(request.session_key) &&
  model.qa_agent_status == "retained" &&
  model.pending_qa is None &&
  model.pending_question is None
}

///|
fn qa_submission_current(model : Model, request : ModelSubmission) -> Bool {
  submission_current(model, request, model.pending_qa) &&
  model.workspace_generation == request.workspace_generation &&
  model.gateway_published &&
  model.trusted_book_dir == request.cwd
}

///|
fn qa_session_key_matches(model : Model, session : CoworkSessionDetail) -> Bool {
  model.qa_canonical_key == Some(session.session.session_key)
}

///|
fn qa_preparation_failed(model : Model, error : String) -> Model {
  {
    ..model,
    pending_qa: None,
    qa_ready: false,
    qa_error: Some(
      error +
      " The retained session is kept. Finish preparation explicitly or check its state.",
    ),
    error: Some(error),
    notice: None,
  }
}

///|
fn qa_retained_issue(model : Model) -> String? {
  if model.qa_agent_status == "reconnect-required" {
    Some(
      "This retained Q&A belongs to a different Book or MoonClaw gateway. Restore the original trusted host configuration, then check the retained session. No replacement session will be created.",
    )
  } else if model.book_dir != model.trusted_book_dir {
    Some(
      "Restore the trusted Book folder before reconnecting this retained Q&A session.",
    )
  } else if model.qa_agent_status == "creation-uncertain" ||
    model.qa_agent_status == "creating" {
    Some(
      "Q&A creation may already have reached MoonClaw. Check the retained session before trying again; no replacement will be created automatically.",
    )
  } else {
    None
  }
}
