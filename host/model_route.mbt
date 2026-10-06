///|
pub(all) struct NativeModelRouteV1 {
  contract_id : String
  run_id : String
  cwd : String
  catalog_ready : Bool
  default_ready : Bool
  default_model : String
  models : Array[String]
  blocker : String
} derive(Debug, ToJson, FromJson)

///|
struct CoworkModelRouteV1 {
  contract_id : String
  cwd : String
  catalog_ready : Bool
  default_ready : Bool
  default_model : String
  models : Array[String]
  blocker : String
} derive(FromJson)

///|
fn unavailable_model_route(
  config : Config,
  blocker : String,
) -> NativeModelRouteV1 {
  {
    contract_id: "moonfind.native-model-route.v1",
    run_id: config.run_id,
    cwd: config.book_workspace,
    catalog_ready: false,
    default_ready: false,
    default_model: "",
    models: [],
    blocker,
  }
}

///|
fn project_model_route(config : Config, value : Json) -> NativeModelRouteV1 {
  let route : CoworkModelRouteV1 = @json.from_json(value) catch {
    _ =>
      return unavailable_model_route(
        config, "Cowork returned an unsupported native model-route contract.",
      )
  }
  if route.contract_id != "moonclaw.cowork-model-route.v1" ||
    route.cwd != config.book_workspace {
    return unavailable_model_route(
      config, "Cowork model-route context differs from the trusted MoonFind workspace.",
    )
  }
  let models = route.models.filter(name => {
    name.has_prefix("moongate/") &&
    name.length() > 9 &&
    name == name.trim().to_owned()
  })
  let catalog_ready = route.catalog_ready &&
    !models.is_empty() &&
    models.length() == route.models.length()
  let ready = catalog_ready &&
    route.default_ready &&
    models.contains(route.default_model)
  {
    contract_id: "moonfind.native-model-route.v1",
    run_id: config.run_id,
    cwd: config.book_workspace,
    catalog_ready,
    default_ready: ready,
    default_model: if ready {
      route.default_model
    } else {
      ""
    },
    models: if catalog_ready {
      models
    } else {
      []
    },
    blocker: if ready {
      ""
    } else if !route.blocker.is_blank() {
      route.blocker
    } else {
      "Cowork did not verify a configured native default for this workspace."
    },
  }
}

///|
fn cowork_headers(config : Config) -> Map[String, String] {
  let headers = { "Content-Type": "application/json; charset=utf-8" }
  match config.moonclaw_gateway_token {
    Some(token) if !token.is_blank() =>
      headers["Authorization"] = "Bearer " + token
    _ => ()
  }
  headers
}

///|
async fn fetch_cowork_json(
  config : Config,
  path : String,
  body : Json?,
) -> Json {
  guard config.moonclaw_gateway_base is Some(base) && !base.is_blank() else {
    fail("MoonClaw Cowork gateway is not configured.")
  }
  let (response, data) = try {
    match body {
      Some(value) =>
        @http.post(
          trimmed_base(base) + path,
          value,
          headers=cowork_headers(config),
        )
      None =>
        @http.get(trimmed_base(base) + path, headers=cowork_headers(config))
    }
  } catch {
    _ => fail("MoonClaw Cowork transport is unavailable.")
  }
  guard response.code >= 200 && response.code < 300 else {
    fail("MoonClaw Cowork returned HTTP \{response.code} for \{path}.")
  }
  @json.parse(data.text())
}

///|
// The injected transport is the same boundary used by the production host;
// fixture tests never open a socket or inspect credentials.
async fn native_model_route_with(
  config : Config,
  fetch~ : async (String, Json) -> Json,
) -> NativeModelRouteV1 {
  if config.moonclaw_gateway_base is None {
    return unavailable_model_route(
      config, "MoonClaw Cowork gateway is not configured.",
    )
  }
  let value = fetch("/v1/cowork/model-route", { "cwd": config.book_workspace }) catch {
    _ =>
      return unavailable_model_route(
        config, "Cowork native model-route endpoint is unavailable or unauthorized; no native default was selected.",
      )
  }
  project_model_route(config, value)
}

///|
pub async fn native_model_route(config : Config) -> NativeModelRouteV1 {
  native_model_route_with(config, fetch=(path, body) => {
    fetch_cowork_json(config, path, Some(body))
  })
}

///|
fn safe_cowork_key(key : String) -> Bool {
  !key.is_blank() &&
  key.length() <= 200 &&
  key
  .iter()
  .all(c => {
    (c >= 'a' && c <= 'z') ||
    (c >= 'A' && c <= 'Z') ||
    (c >= '0' && c <= '9') ||
    c is (':' | '-' | '_')
  })
}

///|
async fn registered_cowork_keys(config : Config) -> Array[String] {
  let directory = run_artifact(config, "cowork-host-sessions")
  let keys : Array[String] = []
  if !@fs.exists(directory) {
    return keys
  }
  for name in @fs.readdir(directory) {
    if !name.has_suffix(".json") {
      continue
    }
    let value = @store.read_json(directory + "/" + name)
    if value
      is {
        "contract_id": String("moonfind.cowork-session-binding.v1"),
        "run_id": String(run_id),
        "session_key": String(key),
        "cwd": String(cwd),
        "gateway": String(gateway),
        ..
      } &&
      run_id == config.run_id &&
      cwd == config.book_workspace &&
      gateway == config.moonclaw_gateway_base.unwrap_or("") &&
      safe_cowork_key(key) {
      keys.push(key)
    }
  }
  keys.sort()
  keys
}

///|
async fn register_cowork_key(config : Config, key : String) -> Unit {
  guard safe_cowork_key(key) else { fail("Invalid Cowork session key.") }
  let directory = @store.run_directory(config.workspace, config.run_id) +
    "/cowork-host-sessions"
  ensure_cowork_binding_directory(directory)
  let name = @store.digest_json(key.to_json()).replace(old=":", new="-")
  let path = directory + "/" + name + ".json"
  let value : Json = {
    "contract_id": "moonfind.cowork-session-binding.v1",
    "run_id": config.run_id,
    "session_key": key,
    "cwd": config.book_workspace,
    "gateway": config.moonclaw_gateway_base.unwrap_or(""),
  }
  if @fs.exists(path) {
    guard @store.read_json(path) == value else {
      fail("Cowork session binding conflicts with an existing record.")
    }
    return
  }
  let temporary = path + ".pending"
  @fs.write_file(
    temporary,
    value.stringify(),
    create_mode=CreateNew,
    permission=0o600,
    sync=Full,
  )
  @fs.rename(temporary, path, replace=false)
}

///|
// mkdir(recursive=true) in the pinned async version may report EEXIST on a
// concurrently created ancestor before the final directory exists. Create one
// level at a time so each competing mkdir has an independently checked result.
async fn ensure_cowork_binding_directory(directory : String) -> Unit {
  let mut prefix = if directory.has_prefix("/") { "/" } else { "" }
  for component in directory.split("/") {
    if component.is_empty() {
      continue
    }
    prefix = if prefix == "/" || prefix.is_empty() {
      prefix + component.to_owned()
    } else {
      prefix + "/" + component.to_owned()
    }
    if !@fs.exists(prefix) {
      @fs.mkdir(prefix) catch {
        error => if !@fs.exists(prefix) { raise error }
      }
    }
  }
}

///|
fn checkpoint_session_authorized(
  key : String,
  persisted : String?,
  registered : Array[String],
) -> Bool {
  safe_cowork_key(key) && (registered.contains(key) || persisted == Some(key))
}

///|
fn valid_checkpoint_session_binding(
  config : Config,
  key : String,
  value : Json,
) -> Bool {
  value
  is {
    "session": {
      "session": { "session_key": String(observed), "cwd": String(cwd), .. },
      ..
    },
    ..
  } &&
  observed == key &&
  cwd == config.book_workspace
}

///|
async fn bound_cowork_keys(config : Config) -> Array[String] {
  let keys = registered_cowork_keys(config)
  let (qa_key, _) = qa_session_retention(config)
  if qa_key is Some(key) && !keys.contains(key) {
    keys.push(key)
  }
  if current_execution(config) is Some({ moonclaw_session_key: Some(key), .. }) &&
    !keys.contains(key) {
    keys.push(key)
  }
  keys
}

///|
// A deliberately narrow relay. Host configuration owns the workspace, token,
// gateway and run. Browser requests cannot choose any of these bindings.
pub async fn cowork_relay(config : Config, path : String, body : Json?) -> Json {
  cowork_relay_with(
    config,
    path,
    body,
    load_keys=() => bound_cowork_keys(config),
    save_key=key => register_cowork_key(config, key),
    fetch=(path, body) => fetch_cowork_json(config, path, body),
  )
}

///|
async fn cowork_relay_with(
  config : Config,
  path : String,
  body : Json?,
  load_keys~ : async () -> Array[String],
  save_key~ : async (String) -> Unit,
  fetch~ : async (String, Json?) -> Json,
) -> Json {
  let parts = path.split("/").to_array()
  let creating = path == "/v1/cowork/sessions" && body is Some(_)
  let qa_creating = qa_creation_requested(config, path, body)
  let mut bound_key : String? = None
  if !creating {
    guard parts is ["", "v1", "cowork", "sessions", key, .. rest] &&
      safe_cowork_key(key.to_owned()) &&
      (
        (rest.is_empty() && body is None) ||
        (
          rest.length() == 1 &&
          (rest[0] == "config" || rest[0] == "messages") &&
          body is Some(_)
        )
      ) else {
      fail("Unsupported MoonFind Cowork relay route.")
    }
    guard load_keys().contains(key.to_owned()) else {
      fail("Cowork session is not bound to this MoonFind run.")
    }
    bound_key = Some(key.to_owned())
  }
  match body {
    Some(Object(fields)) => {
      if fields.get("cwd") is Some(value) &&
        value != config.book_workspace.to_json() {
        fail("Cowork workspace must match the trusted MoonFind host workspace.")
      }
      if path.has_suffix("/config") || path.has_suffix("/messages") {
        guard fields.get("model") is Some(String(value)) && !value.is_blank() else {
          fail(
            "An empty model would clear or bypass the Cowork override; choose an exact model first.",
          )
        }
      }
      fields["cwd"] = config.book_workspace.to_json()
    }
    Some(_) => fail("Cowork relay requires a JSON object.")
    None => ()
  }
  if bound_key is Some(key) {
    let observed = fetch("/v1/cowork/sessions/" + key, None)
    guard valid_checkpoint_session_binding(config, key, observed) else {
      fail(
        "Cowork session identity or workspace no longer matches its trusted binding.",
      )
    }
    if body is None {
      return observed
    }
  }
  if qa_creating && begin_qa_session_creation(config) is Some(key) {
    // An explicit retry of creation is readback of its known acknowledgement,
    // never a second POST to MoonClaw.
    let observed = fetch("/v1/cowork/sessions/" + key, None)
    guard valid_checkpoint_session_binding(config, key, observed) else {
      fail("The retained Q&A session no longer matches its trusted binding.")
    }
    return observed
  }
  let value = fetch(path, body)
  if creating {
    guard value
      is {
        "session": {
          "session": { "session_key": String(key), "cwd": String(cwd), .. },
          ..
        },
        ..
      } &&
      safe_cowork_key(key) &&
      cwd == config.book_workspace else {
      fail("Cowork returned an invalid session binding.")
    }
    if qa_creating {
      // Retain the canonical key before the generic relay registration. If
      // registration or HTTP acknowledgement fails, snapshot/readback still
      // knows this exact session and permits retry without creating another.
      retain_qa_session(config, key)
    }
    save_key(key)
  }
  value
}
