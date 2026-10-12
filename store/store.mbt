///|
fn safe_id(value : String) -> Bool {
  !value.is_blank() &&
  !value.contains("/") &&
  !value.contains("\\") &&
  !value.contains("..")
}

///|
pub fn run_directory(workspace : String, run_id : String) -> String raise {
  guard !workspace.is_blank() && safe_id(run_id) else {
    fail("workspace and safe run_id are required")
  }
  let root = if workspace.has_suffix("/") {
    workspace[:workspace.length() - 1].to_owned()
  } else {
    workspace
  }
  root + "/.moonsuite/products/moonfind/runs/" + run_id
}

///|
pub async fn ensure_run_directory(
  workspace : String,
  run_id : String,
) -> String {
  let directory = run_directory(workspace, run_id)
  if !@fs.exists(directory) {
    @fs.mkdir(directory, permission=0o755, recursive=true)
  }
  directory
}

///|
pub async fn read_json(path : String) -> Json {
  @json.parse(@fs.read_file(path).text())
}

///|
pub async fn write_json(path : String, value : Json) -> Unit {
  @fs.write_file(
    path,
    @utf8.encode(value.stringify(indent=2) + "\n"),
    create=0o644,
    truncate=true,
  )
}

///|
pub async fn write_run_artifact(
  workspace : String,
  run_id : String,
  name : String,
  value : Json,
) -> Unit {
  guard safe_id(name) && name.has_suffix(".json") else {
    fail("artifact name must be a safe JSON filename")
  }
  let directory = ensure_run_directory(workspace, run_id)
  let path = directory + "/" + name
  write_json(path, value)
}

///|
fn hex_digit(value : Int) -> Char {
  if value < 10 {
    (value + 48).unsafe_to_char()
  } else {
    (value - 10 + 97).unsafe_to_char()
  }
}

///|
pub fn digest_json(value : Json) -> String {
  let bytes = @crypto.sha256(@utf8.encode(value.stringify()))
  let builder = StringBuilder::new()
  for byte in bytes {
    let number = byte.to_int()
    builder.write_char(hex_digit(number / 16))
    builder.write_char(hex_digit(number % 16))
  }
  "sha256:" + builder.to_string()
}

///|
/// Digest exact persisted bytes represented as text. Cross-product evidence
/// must bind the file representation, not a re-serialized JSON value.
pub fn digest_text(value : String) -> String {
  let bytes = @crypto.sha256(@utf8.encode(value))
  let builder = StringBuilder::new()
  for byte in bytes {
    let number = byte.to_int()
    builder.write_char(hex_digit(number / 16))
    builder.write_char(hex_digit(number % 16))
  }
  "sha256:" + builder.to_string()
}

///|
pub fn digest_bytes(value : Bytes) -> String {
  let bytes = @crypto.sha256(value)
  let builder = StringBuilder::new()
  for byte in bytes {
    let number = byte.to_int()
    builder.write_char(hex_digit(number / 16))
    builder.write_char(hex_digit(number % 16))
  }
  "sha256:" + builder.to_string()
}

///|
fn safe_declared_artifact_ref(reference : String) -> Bool {
  !reference.is_blank() &&
  !reference.has_prefix("/") &&
  !reference.contains("\\") &&
  !reference.split("/").any(part => part.is_blank() || part is ("." | ".."))
}

///|
/// Reproduce MoonClaw's `declared_artifact_digest` over exact persisted bytes:
/// first hash every artifact, render `<ref>|<sha256:digest>` in the supplied
/// order, join identities with a newline, then hash that aggregate.
pub fn digest_declared_artifact_bytes(
  artifacts : Array[(String, Bytes)],
) -> String raise {
  guard !artifacts.is_empty() else {
    fail("declared artifact digest requires at least one artifact")
  }
  let identities : Array[String] = []
  let references : Array[String] = []
  for artifact in artifacts {
    let (reference, bytes) = artifact
    guard safe_declared_artifact_ref(reference) &&
      !references.contains(reference) else {
      fail("declared artifact references must be safe and unique")
    }
    references.push(reference)
    identities.push("\{reference}|\{digest_bytes(bytes)}")
  }
  digest_bytes(@utf8.encode(identities.join("\n")))
}
