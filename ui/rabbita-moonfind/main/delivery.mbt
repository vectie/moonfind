///|
struct DeliveryFile {
  name : String
  media_type : String
  byte_count : Int
  digest : String
} derive(Debug, ToJson, FromJson)

///|
struct DeliveryManifest {
  contract_id : String
  run_id : String
  delivery_id : String
  run_digest : String
  source_digest : String
  files : Array[DeliveryFile]
  boundary : String
} derive(Debug, ToJson, FromJson)

///|
struct DeliveryStatus {
  contract_id : String
  run_id : String
  state : String
  detail : String
  manifest : DeliveryManifest?
  issues : Array[String]
  versions : Array[String]
} derive(Debug, ToJson, FromJson)

///|
struct DeliveryRequest {
  generation : Int
  workspace_generation : Int
  context : String
  run_id : String
  source_digest : String
  selected_id : String?
  preparing : Bool
} derive(Debug, Eq)

///|
struct DeliveryView {
  generation : Int
  workspace_ready : Bool
  workspace_generation : Int
  context : String
  pending : DeliveryRequest?
  status : DeliveryStatus?
  selected_id : String?
  versions : Array[String]
  error : String?
}

///|
fn empty_delivery(generation : Int) -> DeliveryView {
  {
    generation,
    workspace_ready: false,
    workspace_generation: -1,
    context: "",
    pending: None,
    status: None,
    selected_id: None,
    versions: [],
    error: None,
  }
}

///|
fn safe_delivery_id(id : String) -> Bool {
  id.length() == 73 &&
  id.has_prefix("delivery-") &&
  id[9:]
  .iter()
  .all(character => {
    match character {
      'a'..='f' | '0'..='9' => true
      _ => false
    }
  })
}

///|
fn delivery_file_url(id : String, name : String) -> String? {
  if safe_delivery_id(id) &&
    [
      "report.md", "evidence.json", "synthesis.json", "manifest.json", "package.zip",
    ].contains(name) {
    Some(product_api_url("/api/v1/delivery/" + id + "/" + name))
  } else {
    None
  }
}

///|
fn delivery_context_current(model : Model) -> Bool {
  model.delivery.workspace_generation == model.workspace_generation &&
  model.delivery.context == review_result_context(model)
}

///|
fn delivery_request_current(model : Model, request : DeliveryRequest) -> Bool {
  delivery_context_current(model) && model.delivery.pending == Some(request)
}

///|
fn delivery_manifest_valid(manifest : DeliveryManifest) -> Bool {
  manifest.contract_id == "moonfind.delivery-manifest.v1" &&
  safe_delivery_id(manifest.delivery_id) &&
  !manifest.run_id.is_blank() &&
  !manifest.run_digest.is_blank() &&
  !manifest.source_digest.is_blank() &&
  manifest.files.length() == 3 &&
  ["report.md", "evidence.json", "synthesis.json"].all(name => {
    manifest.files.filter(file => file.name == name).length() == 1
  }) &&
  manifest.files.all(file => {
    file.byte_count >= 0 &&
    !file.digest.is_blank() &&
    !file.media_type.is_blank()
  })
}

///|
fn delivery_status_issue(
  request : DeliveryRequest,
  status : DeliveryStatus,
) -> String? {
  if status.contract_id != "moonfind.delivery-status.v1" ||
    !["not-prepared", "complete", "incomplete", "stale", "unavailable"].contains(
      status.state,
    ) ||
    !status.versions.all(safe_delivery_id) {
    return Some(
      "The host returned an unsupported delivery status or version identifier.",
    )
  }
  if status.run_id != request.run_id {
    return Some(
      "The delivery reply belongs to another run. Reload the current result.",
    )
  }
  if status.state == "complete" || status.state == "stale" {
    guard status.manifest is Some(manifest) &&
      delivery_manifest_valid(manifest) &&
      status.run_id == manifest.run_id &&
      status.issues.is_empty() else {
      return Some(
        "The package is not complete and validated. Its file links are withheld.",
      )
    }
    match request.selected_id {
      Some(id) if manifest.delivery_id != id =>
        return Some(
          "The host returned a different saved package than the one selected.",
        )
      None if status.state == "complete" &&
        (
          manifest.run_id != request.run_id ||
          manifest.source_digest != request.source_digest
        ) =>
        return Some(
          "This package does not match the displayed synthesis. Reload before preparing it.",
        )
      _ => ()
    }
  }
  None
}

///|
fn decode_delivery(
  result : Result[Json, Error],
) -> Result[DeliveryStatus, String] {
  match result {
    Err(error) => Err("\{error}")
    Ok(payload) => {
      if payload
        is {
          "error": {
            "contract_id": "moonfind.ui-host-error.v1",
            "message": String(message),
            ..
          },
          ..
        } {
        return Err(message)
      }
      let status : DeliveryStatus = @json.from_json(payload) catch {
        error => return Err("Invalid delivery response: \{error}")
      }
      Ok(status)
    }
  }
}

///|
fn delivery_command(
  emit : @rabbita.Emit[Msg],
  request : DeliveryRequest,
) -> @rabbita.Cmd {
  let endpoint = if request.preparing {
    "/api/v1/delivery/prepare"
  } else {
    "/api/v1/delivery" + request.selected_id.map(id => "/" + id).unwrap_or("")
  }
  let http_request = if request.preparing {
    @http.post(product_api_url(endpoint)).with_json({
      "contract_id": "moonfind.delivery-prepare.v1",
      "run_id": request.run_id,
      "source_digest": request.source_digest,
    })
  } else {
    @http.get(product_api_url(endpoint))
  }
  http_request.expect_json(
    emit.map(result => DeliveryLoaded(request, decode_delivery(result))),
  )
}

///|
fn begin_delivery(
  emit : @rabbita.Emit[Msg],
  model : Model,
  selected_id : String?,
  preparing : Bool,
) -> (@rabbita.Cmd, Model) {
  let request : DeliveryRequest = {
    generation: model.delivery.generation + 1,
    workspace_generation: model.workspace_generation,
    context: review_result_context(model),
    run_id: model.workspace.map(ws => ws.run_id).unwrap_or(""),
    source_digest: model.moontown_result
    .bind(result => result.source_digest)
    .unwrap_or(""),
    selected_id,
    preparing,
  }
  (
    delivery_command(emit, request),
    {
      ..model,
      delivery: {
        generation: request.generation,
        workspace_ready: true,
        workspace_generation: request.workspace_generation,
        context: request.context,
        pending: Some(request),
        status: None,
        selected_id,
        versions: if delivery_context_current(model) {
          model.delivery.versions
        } else {
          []
        },
        error: None,
      },
    },
  )
}

///|
fn update_delivery(
  emit : @rabbita.Emit[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    RefreshDelivery | PrepareDelivery | SelectDelivery(_) if model.delivery.pending
      is Some(_) => (@rabbita.none, model)
    RefreshDelivery if model.workspace is Some(_) &&
      model.delivery.workspace_ready => begin_delivery(emit, model, None, false)
    PrepareDelivery if current_synthesis(model) is Some(_) &&
      delivery_context_current(model) &&
      model.delivery.selected_id is None &&
      !model.delivery.status
      .map(status => status.state == "complete")
      .unwrap_or(false) => begin_delivery(emit, model, None, true)
    SelectDelivery(id) if delivery_context_current(model) &&
      model.delivery.versions.contains(id) &&
      safe_delivery_id(id) => begin_delivery(emit, model, Some(id), false)
    DeliveryLoaded(request, _) if !delivery_request_current(model, request) =>
      (@rabbita.none, model)
    DeliveryLoaded(_, Err(error)) =>
      (
        @rabbita.none,
        {
          ..model,
          delivery: {
            ..model.delivery,
            pending: None,
            status: None,
            error: Some(error),
          },
        },
      )
    DeliveryLoaded(request, Ok(status)) => {
      let issue = delivery_status_issue(request, status)
      (
        @rabbita.none,
        {
          ..model,
          delivery: {
            ..model.delivery,
            pending: None,
            status: if issue is None {
              Some(status)
            } else {
              None
            },
            versions: if status.contract_id == "moonfind.delivery-status.v1" &&
              status.run_id == request.run_id &&
              status.versions.all(safe_delivery_id) {
              status.versions
            } else {
              model.delivery.versions
            },
            error: issue,
          },
        },
      )
    }
    _ => (@rabbita.none, model)
  }
}
