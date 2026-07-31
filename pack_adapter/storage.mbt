///|
fn trimmed_workspace(workspace : String) -> String raise {
  guard !workspace.is_blank() else {
    fail("MoonFind pack adapter requires a workspace")
  }
  if workspace.has_suffix("/") && workspace.length() > 1 {
    workspace[:workspace.length() - 1].to_owned()
  } else {
    workspace
  }
}

///|
async fn canonical_workspace(config : AdapterConfig) -> (String, String) {
  let configured = trimmed_workspace(config.workspace)
  guard @fs.exists(configured) else {
    fail("MoonFind pack adapter workspace does not exist")
  }
  (configured, @fs.realpath(configured))
}

///|
fn exact_child(root : String, relative : String) -> String {
  if root == "/" {
    "/" + relative
  } else {
    root + "/" + relative
  }
}

///|
async fn ensure_unsymlinked_directory(
  configured_workspace : String,
  canonical_workspace : String,
  relative : String,
) -> String {
  let mut configured = configured_workspace
  let mut canonical = canonical_workspace
  for part in relative.split("/") {
    guard !part.is_blank() && part != "." && part != ".." else {
      fail("MoonFind pack adapter storage path is invalid")
    }
    configured = exact_child(configured, part.to_owned())
    canonical = exact_child(canonical, part.to_owned())
    if !@fs.exists(configured) {
      @fs.mkdir(configured, permission=0o700, recursive=false)
    }
    guard @fs.realpath(configured) == canonical else {
      fail("MoonFind pack adapter storage escaped through a symbolic link")
    }
  }
  configured
}

///|
fn attempt_digest(request : PackToolExecutionRequest) -> String {
  @store.digest_text(request.idempotency_key)[7:].to_owned()
}

///|
async fn attempt_directory(
  config : AdapterConfig,
  request : PackToolExecutionRequest,
  create : Bool,
) -> String? {
  let (configured_workspace, canonical) = canonical_workspace(config)
  let root_relative = ".moonsuite/products/moonfind/pack-tool-attempts"
  let root = exact_child(configured_workspace, root_relative)
  if !@fs.exists(root) {
    if !create {
      return None
    }
    ignore(
      ensure_unsymlinked_directory(
        configured_workspace, canonical, root_relative,
      ),
    )
  } else {
    guard @fs.realpath(root) == exact_child(canonical, root_relative) else {
      fail("MoonFind pack adapter attempt root is a symbolic-link escape")
    }
  }
  let digest = attempt_digest(request)
  let relative = root_relative + "/" + digest
  let directory = exact_child(configured_workspace, relative)
  if !@fs.exists(directory) {
    if !create {
      return None
    }
    ignore(
      ensure_unsymlinked_directory(configured_workspace, canonical, relative),
    )
  } else {
    guard @fs.realpath(directory) == exact_child(canonical, relative) else {
      fail("MoonFind pack adapter attempt directory is a symbolic-link escape")
    }
  }
  Some(directory)
}

///|
async fn write_atomic_json(path : String, value : Json) -> Unit {
  let temporary = path + ".tmp"
  @fs.write_file(
    temporary,
    @utf8.encode(value.stringify(indent=2) + "\n"),
    create_mode=CreateOrTruncate,
    permission=0o600,
    sync=Full,
  )
  @fs.rename(temporary, path, replace=true)
}

///|
async fn read_attempt_record(path : String) -> PackToolAttemptRecord? {
  if !@fs.exists(path) {
    return None
  }
  Some(@json.from_json(@json.parse(@fs.read_file(path).text()))) catch {
    error => fail("durable MoonFind pack-tool attempt is invalid: \{error}")
  }
}

///|
fn require_same_attempt(
  record : PackToolAttemptRecord,
  request : PackToolExecutionRequest,
) -> Unit raise {
  let lifecycle_valid = match (record.state, record.result) {
    ("submitted", None) => record.error_kind.is_blank()
    ("succeeded", Some(result)) =>
      record.error_kind.is_blank() &&
      result.to_json() ==
      successful_result(record.request, record.planned_output).to_json()
    _ => false
  }
  guard record.contract_id == "moonfind.pack-tool-attempt.v1" &&
    record.request_digest == @store.digest_json(request.to_json()) &&
    record.request.to_json() == request.to_json() &&
    record.request.request_id == request.request_id &&
    record.request.attempt_id == request.attempt_id &&
    record.request.idempotency_key == request.idempotency_key &&
    record.request.operation_ref == request.operation_ref &&
    record.request.run_id == request.run_id &&
    record.planned_output_digest == @store.digest_json(record.planned_output) &&
    lifecycle_valid else {
    fail(
      "idempotency key conflicts with a different MoonFind pack-tool attempt",
    )
  }
}

///|
async fn persist_attempt(path : String, record : PackToolAttemptRecord) -> Unit {
  write_atomic_json(path, record.to_json())
}

///|
async fn write_or_verify_output_artifact(
  config : AdapterConfig,
  request : PackToolExecutionRequest,
  output : Json,
) -> Unit {
  let (configured_workspace, canonical) = canonical_workspace(config)
  let relative_directory = "records/moonclaw-commands"
  let directory = ensure_unsymlinked_directory(
    configured_workspace, canonical, relative_directory,
  )
  let path = exact_child(configured_workspace, request.evidence_path)
  let canonical_path = exact_child(canonical, request.evidence_path)
  let rendered = output.stringify(indent=2) + "\n"
  if @fs.exists(path) {
    guard @fs.realpath(path) == canonical_path &&
      @fs.read_file(path).text() == rendered else {
      fail("MoonFind command evidence conflicts with the durable attempt")
    }
    return
  }
  let leaf = request.evidence_path[relative_directory.length() + 1:].to_owned()
  guard !leaf.is_blank() &&
    !leaf.contains("/") &&
    leaf.has_suffix(".json") &&
    path == directory + "/" + leaf else {
    fail("MoonFind command evidence path is not an exact pack-owned artifact")
  }
  let temporary = path + ".tmp"
  @fs.write_file(
    temporary,
    @utf8.encode(rendered),
    create_mode=CreateOrTruncate,
    permission=0o600,
    sync=Full,
  )
  @fs.rename(temporary, path, replace=false)
  guard @fs.realpath(path) == canonical_path else {
    fail("MoonFind command evidence escaped through a symbolic link")
  }
}
