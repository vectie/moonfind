///|
// These files belong to the host, not to research or MoonBook review metadata.
// An intent is durable before creation is sent. A lost response therefore never
// makes a later click create another session implicitly.
fn qa_session_scope(config : Config) -> Json {
  {
    "contract_id": "moonfind.qa-session-intent.v1",
    "workspace": config.workspace,
    "run_id": config.run_id,
    "cwd": config.book_workspace,
    "gateway": config.moonclaw_gateway_base.unwrap_or(""),
  }
}

///|
fn qa_session_binding(config : Config, key : String) -> Json {
  {
    "contract_id": "moonfind.qa-session-binding.v1",
    "scope": qa_session_scope(config),
    "session_key": key,
  }
}

///|
fn qa_gateway_has_nonsecret_identity(config : Config) -> Bool {
  // Gateway tokens remain exclusively in host configuration. Do not copy URL
  // userinfo, queries or fragments into a durable provenance record either.
  config.moonclaw_gateway_base
  .map(base => {
    (base.has_prefix("http://") || base.has_prefix("https://")) &&
    !base.contains("@") &&
    !base.contains("?") &&
    !base.contains("#") &&
    base == base.trim().to_owned()
  })
  .unwrap_or(false)
}

///|
async fn qa_session_retention(config : Config) -> (String?, String) {
  try {
    let intent_path = run_artifact(config, "qa-session-intent.json")
    let binding_path = run_artifact(config, "qa-session.json")
    let pending_path = binding_path + ".pending"
    let has_intent = @fs.exists(intent_path)
    let has_binding = @fs.exists(binding_path)
    let has_pending = @fs.exists(pending_path)
    if !has_intent && !has_binding && !has_pending {
      return (None, "not-created")
    }
    if !qa_gateway_has_nonsecret_identity(config) ||
      !has_intent ||
      @store.read_json(intent_path) != qa_session_scope(config) {
      return (None, "reconnect-required")
    }
    if !has_binding && !has_pending {
      return (None, "creation-uncertain")
    }
    // A complete synced temporary acknowledgement can be read back after a
    // failed rename. It contains only a canonical key returned by MoonClaw.
    let binding = @store.read_json(
      if has_binding {
        binding_path
      } else {
        pending_path
      },
    )
    guard binding
      is {
        "contract_id": String("moonfind.qa-session-binding.v1"),
        "scope": scope,
        "session_key": String(key),
        ..
      } &&
      scope == qa_session_scope(config) &&
      safe_cowork_key(key) else {
      return (None, "reconnect-required")
    }
    (Some(key), "retained")
  } catch {
    // A partially written/corrupt intent or acknowledgement must not be
    // mistaken for no prior attempt, nor prevent the research view loading.
    _ => (None, "creation-uncertain")
  }
}

///|
async fn begin_qa_session_creation(config : Config) -> String? {
  guard qa_gateway_has_nonsecret_identity(config) else {
    fail(
      "Q&A requires a configured gateway URL without embedded credentials, query or fragment.",
    )
  }
  let (key, status) = qa_session_retention(config)
  if key is Some(_) {
    return key
  }
  guard status == "not-created" else {
    fail(
      if status == "reconnect-required" {
        "The retained Q&A binding belongs to another Book, workspace or gateway. Restore the original host configuration before reconnecting."
      } else {
        "Q&A creation has an uncertain outcome. Check the saved session; another session was not created."
      },
    )
  }
  ensure_cowork_binding_directory(
    @store.run_directory(config.workspace, config.run_id),
  )
  // CreateNew is also the inter-request/reload claim. A competing request
  // cannot pass this point, even if the first request is still in flight.
  @fs.write_file(
    run_artifact(config, "qa-session-intent.json"),
    qa_session_scope(config).stringify(),
    create_mode=CreateNew,
    permission=0o600,
    sync=Full,
  ) catch {
    _ => {
      let (observed, _) = qa_session_retention(config)
      if observed is Some(_) {
        return observed
      }
      fail(
        "Q&A creation was not repeated. The host could not claim the attempt; check its saved session and workspace write access.",
      )
    }
  }
  None
}

///|
async fn retain_qa_session(config : Config, key : String) -> Unit {
  guard safe_cowork_key(key) else { fail("Invalid Q&A session key.") }
  guard @store.read_json(run_artifact(config, "qa-session-intent.json")) ==
    qa_session_scope(config) else {
    fail("Q&A creation intent no longer matches the trusted host scope.")
  }
  let path = run_artifact(config, "qa-session.json")
  let temporary = path + ".pending"
  let value = qa_session_binding(config, key)
  if @fs.exists(path) {
    guard @store.read_json(path) == value else {
      fail("A different canonical Q&A session is already retained.")
    }
    return
  }
  if @fs.exists(temporary) {
    guard @store.read_json(temporary) == value else {
      fail("Q&A acknowledgement conflicts with a prior write.")
    }
  } else {
    @fs.write_file(
      temporary,
      value.stringify(),
      create_mode=CreateNew,
      permission=0o600,
      sync=Full,
    )
  }
  @fs.rename(temporary, path, replace=false)
}

///|
fn qa_creation_requested(
  config : Config,
  path : String,
  body : Json?,
) -> Bool raise {
  guard body is Some(Object(fields)) else { return false }
  let purpose = fields.get("moonfind_purpose")
  let run_id = fields.get("moonfind_run_id")
  if purpose is None && run_id is None {
    return false
  }
  guard path == "/v1/cowork/sessions" &&
    purpose == Some("qa".to_json()) &&
    run_id == Some(config.run_id.to_json()) &&
    fields.get("cwd") == Some(config.book_workspace.to_json()) else {
    fail("Q&A creation scope differs from the trusted run and Book workspace.")
  }
  fields.remove("moonfind_purpose")
  fields.remove("moonfind_run_id")
  true
}
