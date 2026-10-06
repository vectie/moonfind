///|
struct NativeModelRoute {
  contract_id : String
  run_id : String
  cwd : String
  catalog_ready : Bool
  default_ready : Bool
  default_model : String
  models : Array[String]
  blocker : String
} derive(Debug, FromJson)

///|
struct ModelSubmission {
  run_id : String
  cwd : String
  gateway : String
  selector : String
  generation : Int
  workspace_generation : Int
  title : String
  grounding_context : String
} derive(Debug, Eq)

///|
fn route_matches_workspace(model : Model, route : NativeModelRoute) -> Bool {
  route.contract_id == "moonfind.native-model-route.v1" &&
  model.workspace.map(ws => ws.run_id) == Some(route.run_id) &&
  route.cwd == model.book_dir
}

///|
fn current_model_catalog(model : Model) -> NativeModelRoute? {
  model.native_route.filter(route => {
    !model.route_loading &&
    model.gateway_published &&
    model.book_dir == model.trusted_book_dir &&
    route_matches_workspace(model, route) &&
    route.catalog_ready
  })
}

///|
fn catalog_choices(route : NativeModelRoute) -> Array[String] {
  let choices : Array[String] = []
  for selector in route.models {
    if selector.has_prefix("moongate/") &&
      selector.length() > 9 &&
      selector == selector.trim().to_owned() &&
      !choices.contains(selector) {
      choices.push(selector)
    }
  }
  choices
}

///|
fn verified_default(route : NativeModelRoute) -> String? {
  if route.default_ready && catalog_choices(route).contains(route.default_model) {
    Some(route.default_model)
  } else {
    None
  }
}

///|
fn select_catalog_model(
  model : Model,
  generation : Int,
  selector : String,
) -> Model {
  guard generation == model.route_generation &&
    current_model_catalog(model)
    .map(route => catalog_choices(route).contains(selector))
    .unwrap_or(false) else {
    return model
  }
  // Choosing is local only. Pin the exact choice like an explicit edit so a
  // later catalog refresh cannot move it to another configured default.
  if model.model_name == selector {
    return {
      ..model,
      model_source: "user",
      saved_selection_key: None,
      saved_selection_error: None,
    }
  }
  {
    ..invalidate_unsubmitted_selection(model),
    model_name: selector,
    model_source: "user",
    saved_selection_key: None,
    saved_selection_error: None,
  }
}

///|
fn execution_reply_current(
  model : Model,
  reply : ResearchExecutionProjection,
) -> Bool {
  execution_context_current(model, reply) &&
  model.research_execution
  .map(current => reply.revision >= current.revision)
  .unwrap_or(false)
}

///|
fn execution_context_current(
  model : Model,
  reply : ResearchExecutionProjection,
) -> Bool {
  model.workspace.map(ws => ws.run_id) == Some(reply.run_id) &&
  model.research_execution
  .map(current => {
    current.run_id == reply.run_id &&
    current.request_id == reply.request_id &&
    current.attempt_id == reply.attempt_id &&
    current.idempotency_key == reply.idempotency_key &&
    current.operation_ref == reply.operation_ref
  })
  .unwrap_or(false)
}

///|
fn invalidate_unsubmitted_selection(model : Model) -> Model {
  let abandon_research = model.pending_research is Some(_) &&
    !model.research_message_sent
  {
    ..model,
    pending_research: if abandon_research {
      None
    } else {
      model.pending_research
    },
    research_session: if abandon_research {
      None
    } else {
      model.research_session
    },
    qa_session: model.qa_session,
    qa_agent_status: if model.pending_qa is Some(_) &&
      model.qa_canonical_key is None {
      "creation-uncertain"
    } else {
      model.qa_agent_status
    },
    pending_qa: None,
    pending_question: None,
    qa_error: None,
  }
}

///|
fn model_route_issue(model : Model, cwd : String) -> String? {
  if model.model_source == "automatic" {
    if model.saved_selection_key is Some(_) {
      return Some("Waiting to restore the saved session's model selection.")
    }
    if model.saved_selection_error is Some(error) {
      return Some(error)
    }
  }
  let explicit_legacy = !model.model_name.trim().is_blank() &&
    !model.model_name.trim().has_prefix("moongate/") &&
    (model.model_source == "user" || model.model_source == "saved")
  if explicit_legacy && !model.gateway_base.contains("/api/v1/cowork-gateway") {
    return if cwd.is_blank() {
      Some("Choose a workspace for the explicit legacy session.")
    } else {
      None
    }
  }
  if cwd != model.book_dir || model.workspace is None {
    return Some(
      "The selected folder is not bound to the current trusted MoonFind workspace.",
    )
  }
  if model.route_loading &&
    (model.model_name.is_blank() || model.model_name.has_prefix("moongate/")) {
    return Some("Refreshing model availability for this workspace.")
  }
  if model.gateway_base.contains("/api/v1/cowork-gateway") &&
    cwd != model.trusted_book_dir {
    return Some(
      "This Cowork relay is bound to " +
      model.trusted_book_dir +
      ". Restore that folder before starting; no other workspace default was used.",
    )
  }
  if model.model_name.trim().is_blank() {
    return Some(
      model.native_route
      .map(route => route.blocker)
      .filter(value => !value.is_blank())
      .unwrap_or(
        "The trusted host has not verified a configured native default. Choose a model explicitly or refresh the host route.",
      ),
    )
  }
  if !model.model_name.trim().has_prefix("moongate/") {
    return if model.model_source == "user" || model.model_source == "saved" {
      None
    } else {
      Some("Automatic selection requires a verified native MoonGate model.")
    }
  }
  match model.native_route {
    Some(route) if route.contract_id == "moonfind.native-model-route.v1" &&
      model.workspace.map(ws => ws.run_id) == Some(route.run_id) &&
      route.cwd == cwd &&
      route.catalog_ready &&
      route.models.contains(model.model_name.trim().to_owned()) => None
    Some(route) if route.cwd != cwd =>
      Some(
        "The selected folder differs from the trusted route workspace. Restore the host-bound folder before starting.",
      )
    Some(route) =>
      Some(
        if !route.blocker.is_blank() {
          route.blocker
        } else {
          "The exact selected native model is unavailable in this workspace's live catalog."
        },
      )
    None =>
      Some(
        "Native model availability has not been verified for this workspace.",
      )
  }
}

///|
fn submission_context(model : Model, generation : Int) -> ModelSubmission {
  {
    run_id: model.workspace.map(ws => ws.run_id).unwrap_or(""),
    cwd: model.book_dir,
    gateway: model.gateway_base,
    selector: model.model_name.trim().to_owned(),
    generation,
    workspace_generation: model.workspace_generation,
    title: research_context_title(model),
    grounding_context: qa_projection_context(model),
  }
}

///|
fn submission_current(
  model : Model,
  request : ModelSubmission,
  pending : ModelSubmission?,
) -> Bool {
  pending == Some(request) &&
  model.workspace.map(ws => ws.run_id) == Some(request.run_id) &&
  (
    model.book_dir == request.cwd ||
    (model.pending_qa == Some(request) && qa_workspace(model) == request.cwd)
  ) &&
  model.gateway_base == request.gateway &&
  model.model_name.trim() == request.selector
}

///|
fn qa_workspace(model : Model) -> String {
  // Evidence is supplied inline. A research run's allocated folder is not
  // the trusted Book workspace and must not be substituted for it.
  model.book_dir
}

///|
fn configured_selection_issue(
  request : ModelSubmission,
  session : CoworkSessionDetail,
) -> String? {
  if session.session.cwd != Some(request.cwd) {
    return Some(
      "Cowork did not confirm the exact selected workspace; no command was submitted.",
    )
  }
  if session.session.model_override != Some(request.selector) {
    return Some(
      "Cowork did not confirm the exact selected model; no command was submitted.",
    )
  }
  None
}

///|
fn restore_model_selection(
  model : Model,
  session : CoworkSessionDetail,
) -> Model {
  if model.saved_selection_key is Some(key) &&
    session.session.session_key != key {
    return model
  }
  let model = {
    ..model,
    saved_selection_key: None,
    saved_selection_error: None,
  }
  if model.model_source == "user" ||
    model.pending_research is Some(_) ||
    model.pending_qa is Some(_) {
    return model
  }
  match session.session.model_override {
    Some(selector) if !selector.is_blank() =>
      { ..model, model_name: selector, model_source: "saved", }
    _ => model
  }
}

///|
fn apply_native_route(
  model : Model,
  generation : Int,
  route : NativeModelRoute,
) -> Model {
  if generation != model.route_generation ||
    route.contract_id != "moonfind.native-model-route.v1" ||
    model.workspace.map(ws => ws.run_id) != Some(route.run_id) ||
    route.cwd != model.book_dir {
    return model
  }
  let selectable = route.catalog_ready &&
    route.default_ready &&
    !route.default_model.is_blank() &&
    route.default_model.has_prefix("moongate/") &&
    route.models.contains(route.default_model)
  let can_select = model.model_source == "automatic" &&
    model.saved_selection_key is None &&
    model.saved_selection_error is None &&
    model.pending_research is None &&
    model.pending_qa is None &&
    model.pending_qa_restore is None &&
    model.research_session is None &&
    model.qa_session
    .bind(session => session.session.model_override)
    .filter(value => !value.trim().is_blank())
    is None
  {
    ..model,
    native_route: Some(route),
    route_loading: false,
    route_error: None,
    model_name: if can_select {
      if selectable {
        route.default_model
      } else {
        ""
      }
    } else {
      model.model_name
    },
  }
}

///|
fn load_native_route(
  emit : @rabbita.Emit[Msg],
  generation : Int,
) -> @rabbita.Cmd {
  @http.get(product_api_url("/api/v1/model-route")).expect_json(
    emit.map(result => {
      NativeRouteLoaded(
        generation,
        match result {
          Ok(value) => Ok(value)
          Err(error) => Err("\{error}")
        },
      )
    }),
  )
}

///|
fn load_saved_selection(
  emit : @rabbita.Emit[Msg],
  gateway : String,
  key : String,
  run_id : String,
) -> @rabbita.Cmd {
  @http.get("\{gateway}/v1/cowork/sessions/\{key}").expect_json(
    emit.map(result => {
      SavedSelectionRestored(run_id, key, decode_session(result))
    }),
  )
}
