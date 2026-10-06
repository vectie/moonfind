///|
pub(all) struct DeliveryFileV1 {
  name : String
  media_type : String
  byte_count : Int
  digest : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct DeliveryManifestV1 {
  contract_id : String
  run_id : String
  delivery_id : String
  run_digest : String
  source_digest : String
  files : Array[DeliveryFileV1]
  boundary : String
} derive(Debug, ToJson, FromJson)

///|
pub(all) struct DeliveryStatusV1 {
  contract_id : String
  run_id : String
  state : String
  detail : String
  manifest : DeliveryManifestV1?
  issues : Array[String]
  versions : Array[String]
} derive(Debug, ToJson, FromJson)

///|
pub(all) struct DeliveryPrepareV1 {
  contract_id : String
  run_id : String
  source_digest : String
} derive(Debug, ToJson, FromJson)

///|
fn delivery_boundary() -> String {
  "A file projection of retained research and returned synthesis, not new research. Digests attest bytes only. Source abstracts are not full-text review; claims, contradictions, unknowns and experiments still require named-human review."
}

///|
fn delivery_id_valid(id : String) -> Bool {
  id.length() == 73 &&
  id.has_prefix("delivery-") &&
  id[9:]
  .to_owned()
  .all(ch => (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f'))
}

///|
fn delivery_root(config : Config) -> String raise {
  run_artifact(config, "deliveries")
}

///|
fn delivery_directory(config : Config, id : String) -> String raise {
  guard delivery_id_valid(id) else { fail("Invalid delivery version") }
  delivery_root(config) + "/" + id
}

///|
async fn ensure_delivery_directory(path : String) -> Unit {
  if !@fs.exists(path) {
    @fs.mkdir(path, recursive=true, permission=0o700) catch {
      _ => if !@fs.exists(path) { fail("Could not create delivery directory") }
    }
  }
  guard @fs.kind(path, follow_symlink=false) == Directory else {
    fail("Delivery storage is not a directory")
  }
}

///|
fn delivery_identity(manifest : DeliveryManifestV1) -> String {
  let digest = @store.digest_json({ ..manifest, delivery_id: "", }.to_json())
  "delivery-" + digest[7:].to_owned()
}

///|
fn delivery_media_type(name : String) -> String raise {
  match name {
    "report.md" => "text/markdown; charset=utf-8"
    "evidence.json" | "synthesis.json" | "manifest.json" =>
      "application/json; charset=utf-8"
    _ => fail("Unknown delivery file")
  }
}

///|
async fn delivery_versions(config : Config) -> Array[String] {
  let root = delivery_root(config)
  if !@fs.exists(root) {
    return []
  }
  @fs.readdir(root, sort=true).filter(delivery_id_valid)
}

///|
async fn delivery_manifest(config : Config, id : String) -> DeliveryManifestV1 {
  let directory = delivery_directory(config, id)
  let manifest_text = @fs.read_file(directory + "/manifest.json").text()
  let manifest : DeliveryManifestV1 = @json.from_json(
    @json.parse(manifest_text),
  )
  guard manifest.contract_id == "moonfind.delivery-manifest.v1" &&
    manifest_text == manifest.to_json().stringify(indent=2) + "\n" &&
    manifest.run_id == config.run_id &&
    manifest.delivery_id == id &&
    delivery_identity(manifest) == id &&
    manifest.boundary == delivery_boundary() &&
    manifest.files.map(file => file.name) ==
    ["report.md", "evidence.json", "synthesis.json"] else {
    fail("Delivery manifest identity or requested file set is invalid")
  }
  for file in manifest.files {
    guard file.media_type == delivery_media_type(file.name) &&
      file.byte_count >= 0 else {
      fail("Delivery manifest file metadata is invalid")
    }
  }
  manifest
}

///|
async fn delivery_checked_bytes(
  config : Config,
  manifest : DeliveryManifestV1,
  file : DeliveryFileV1,
) -> Bytes {
  let path = delivery_directory(config, manifest.delivery_id) + "/" + file.name
  guard @fs.exists(path) else { fail("Missing file: " + file.name) }
  guard @fs.kind(path, follow_symlink=false) == Regular else {
    fail("Not a regular delivery file: " + file.name)
  }
  let bytes = @fs.read_file(path).binary()
  // Text files are written as UTF-8. Re-encoding must retain every byte before
  // the existing exact-text digest can attest a download.
  let text = @utf8.decode(bytes) catch {
    _ => fail("Invalid UTF-8: " + file.name)
  }
  guard @utf8.encode(text) == bytes &&
    bytes.length() == file.byte_count &&
    @store.digest_text(text) == file.digest else {
    fail("Changed file: " + file.name)
  }
  bytes
}

///|
async fn delivery_current_digests(config : Config) -> (String, String) {
  let run_text = @fs.read_file(run_artifact(config, "run.json")).text()
  let run : @research.ResearchRun = @json.from_json(@json.parse(run_text))
  guard run.run_id == config.run_id else {
    fail("Research run identity differs")
  }
  let town = handoff_status(config, None)
  let result = completed_result_view(config, town)
  guard result.state == "available" && result.source_digest is Some(digest) else {
    fail("The correlated synthesis is unavailable")
  }
  (@store.digest_text(run_text), digest)
}

///|
/// Read-only status; never creates, repairs or regenerates a package.
pub async fn delivery_status(
  config : Config,
  delivery_id? : String,
) -> DeliveryStatusV1 {
  let versions = delivery_versions(config)
  let empty : DeliveryStatusV1 = {
    contract_id: "moonfind.delivery-status.v1",
    run_id: config.run_id,
    state: "not-prepared",
    detail: "Prepare a file package from the displayed synthesis. Earlier versions remain unchanged.",
    manifest: None,
    issues: [],
    versions,
  }
  try {
    let id = match delivery_id {
      Some(id) => id
      None => {
        let path = run_artifact(config, "delivery-latest.json")
        if !@fs.exists(path) {
          return empty
        }
        guard @store.read_json(path) is { "delivery_id": String(id), .. } else {
          fail("The latest delivery pointer is malformed")
        }
        id
      }
    }
    let manifest = delivery_manifest(config, id)
    let issues : Array[String] = []
    for file in manifest.files {
      ignore(delivery_checked_bytes(config, manifest, file)) catch {
        error => issues.push("\{error}")
      }
    }
    let current = try {
      let (run_digest, source_digest) = delivery_current_digests(config)
      run_digest == manifest.run_digest &&
      source_digest == manifest.source_digest
    } catch {
      _ => false
    }
    {
      ..empty,
      manifest: Some(manifest),
      issues,
      state: if !issues.is_empty() {
        "incomplete"
      } else if current {
        "complete"
      } else {
        "stale"
      },
      detail: if !issues.is_empty() {
        "This version has missing or changed files. Intact files remain readable; the complete ZIP is unavailable. Restore exact bytes or prepare a new version after revising the research."
      } else if current {
        "All three files match this manifest and the current retained research. Ready for inspection, not an acceptance or truth claim."
      } else {
        "Historical version: its files are intact, but the current run or synthesis differs or is unavailable. You can still inspect and download this exact version."
      },
    }
  } catch {
    error =>
      {
        ..empty,
        state: "unavailable",
        detail: "The selected delivery could not be read. No files were changed.",
        issues: ["\{error}"],
      }
  }
}

///|
/// Explicit preparation is content-addressed and idempotent. Existing versions
/// are never overwritten, including incomplete ones.
pub async fn prepare_delivery(
  config : Config,
  request : DeliveryPrepareV1,
) -> DeliveryStatusV1 {
  guard request.contract_id == "moonfind.delivery-prepare.v1" &&
    request.run_id == config.run_id else {
    fail("Reload the current run before preparing files")
  }
  let run_text = @fs.read_file(run_artifact(config, "run.json")).text()
  let run : @research.ResearchRun = @json.from_json(@json.parse(run_text))
  guard run.run_id == config.run_id else {
    fail("Research run identity differs")
  }
  let result = completed_result_view(config, handoff_status(config, None))
  guard result.state == "available" &&
    result.source_digest is Some(source_digest) &&
    result.output is Some(output) &&
    request.source_digest == source_digest else {
    fail(
      "The displayed synthesis changed or is unavailable. Reload before preparing files.",
    )
  }
  let contents = delivery_contents(run, output)
  let files = contents.map(item => {
    let (name, text) = item
    DeliveryFileV1::{
      name,
      media_type: delivery_media_type(name),
      byte_count: @utf8.encode(text).length(),
      digest: @store.digest_text(text),
    }
  })
  let initial : DeliveryManifestV1 = {
    contract_id: "moonfind.delivery-manifest.v1",
    run_id: config.run_id,
    delivery_id: "",
    run_digest: @store.digest_text(run_text),
    source_digest,
    files,
    boundary: delivery_boundary(),
  }
  let manifest = { ..initial, delivery_id: delivery_identity(initial), }
  let (current_run, current_source) = delivery_current_digests(config)
  guard current_run == manifest.run_digest && current_source == source_digest else {
    fail("Research changed while preparing files. Reload and try again.")
  }
  let root = delivery_root(config)
  ensure_delivery_directory(root)
  let lock = @fs.open(
    root + "/prepare.lock",
    mode=ReadWrite,
    create_mode=OpenOrCreate,
    permission=0o600,
  )
  defer lock.close()
  lock.lock(Exclusive)
  let directory = delivery_directory(config, manifest.delivery_id)
  ensure_delivery_directory(directory)
  if !@fs.exists(directory + "/manifest.json") {
    for item in contents {
      let (name, text) = item
      ensure_immutable_review_artifact(directory + "/" + name, text, name)
    }
    ensure_immutable_review_artifact(
      directory + "/manifest.json",
      manifest.to_json().stringify(indent=2) + "\n",
      "delivery manifest",
    )
  }
  let status = delivery_status(config, delivery_id=manifest.delivery_id)
  if status.state == "complete" {
    let pointer = run_artifact(config, "delivery-latest.json")
    let latest : Json = { "delivery_id": manifest.delivery_id }
    @fs.write_file(
      pointer + ".tmp",
      latest.stringify() + "\n",
      create_mode=CreateOrTruncate,
      permission=0o600,
      sync=Full,
    )
    @fs.rename(pointer + ".tmp", pointer, replace=true)
  }
  status
}

///|
/// Read the exact retained bytes. Historical packages remain downloadable;
/// corruption is never silently replaced with regenerated content.
pub async fn read_delivery_file(
  config : Config,
  delivery_id : String,
  name : String,
) -> Bytes {
  let manifest = delivery_manifest(config, delivery_id)
  if name == "manifest.json" {
    return @fs.read_file(
      delivery_directory(config, delivery_id) + "/manifest.json",
    ).binary()
  }
  if name == "package.zip" {
    let files : Array[(String, Bytes)] = []
    for file in manifest.files {
      files.push((file.name, delivery_checked_bytes(config, manifest, file)))
    }
    files.push(
      (
        "manifest.json",
        @fs.read_file(
          delivery_directory(config, delivery_id) + "/manifest.json",
        ).binary(),
      ),
    )
    return delivery_zip(files)
  }
  guard manifest.files.filter(file => file.name == name).get(0) is Some(file) else {
    fail("Unknown delivery file")
  }
  delivery_checked_bytes(config, manifest, file)
}
