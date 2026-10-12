///|
pub(all) struct BriefSourceV1 {
  slot : Int
  name : String
  origin : String
  captured_at : String
  kind : String
  availability : String
  archive_path : String
  byte_count : Int
  digest : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct BriefSnapshotV1 {
  contract_id : String
  revision_id : String
  state : String
  brief : @research.ResearchBriefV1
  sources : Array[BriefSourceV1]
  boundary : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct BriefStatusV1 {
  contract_id : String
  brief_id : String
  revision_id : String
  state : String
  snapshot : BriefSnapshotV1?
  issues : Array[String]
} derive(Debug, ToJson, FromJson)

///|
pub(all) struct BriefListItemV1 {
  brief_id : String
  revision_id : String
  question : String
  state : String
} derive(Debug, ToJson, FromJson)

///|
fn brief_revision_valid(id : String) -> Bool {
  id.length() == 73 &&
  id.has_prefix("revision-") &&
  id[9:].iter().all(ch => (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f'))
}

///|
fn brief_identity(brief : @research.ResearchBriefV1) -> String {
  "revision-" + @store.digest_json(brief.to_json())[7:].to_owned()
}

///|
fn brief_root(config : Config) -> String {
  config.workspace + "/.moonsuite/products/moonfind/briefs"
}

///|
fn brief_directory(
  config : Config,
  id : String,
  revision : String,
) -> String raise {
  guard @research.brief_safe_id(id) && brief_revision_valid(revision) else {
    fail("Invalid brief or revision ID")
  }
  brief_root(config) + "/" + id + "/" + revision
}

///|
fn brief_source_bytes(source : @research.BriefSourceInputV1) -> Bytes raise {
  let out = @buffer.Buffer()
  fn digit(code : Int) -> Int {
    if code <= 57 {
      code - 48
    } else {
      code - 87
    }
  }
  for i = 0; i < source.content_hex.length(); i = i + 2 {
    out.write_byte(
      (digit(source.content_hex[i].to_int()) * 16 +
      digit(source.content_hex[i + 1].to_int())).to_byte(),
    )
  }
  let bytes = out.to_bytes()
  let text = @utf8.decode(bytes) catch {
    _ => fail("Unsupported binary or non-UTF-8 source: " + source.name)
  }
  guard @utf8.encode(text) == bytes &&
    text.all(ch => {
      ch == '\n' ||
      ch == '\r' ||
      ch == '\t' ||
      (ch.to_int() >= 32 && ch.to_int() != 127)
    }) else {
    fail("Unsupported binary control bytes: " + source.name)
  }
  bytes
}

///|
fn brief_snapshot(brief : @research.ResearchBriefV1) -> BriefSnapshotV1 raise {
  let issues = @research.brief_issues(brief)
  guard issues.is_empty() else { fail(issues.join("; ")) }
  let sources : Array[BriefSourceV1] = []
  for i, input in brief.sources {
    let bytes = brief_source_bytes(input)
    let extension = input.name.split(".").last().unwrap().to_owned().to_lower()
    sources.push({
      slot: i + 1,
      name: input.name,
      origin: input.origin,
      captured_at: input.captured_at,
      kind: input.kind,
      availability: "retained-local-capture",
      archive_path: "sources/source-\{i + 1}." + extension,
      byte_count: bytes.length(),
      digest: @store.digest_text(@utf8.decode(bytes)),
    })
  }
  {
    contract_id: "moonfind.brief-snapshot.v1",
    revision_id: brief_identity(brief),
    state: "prepared",
    brief,
    sources,
    boundary: @research.brief_boundary(),
  }
}

///|
async fn brief_regular_bytes(path : String) -> Bytes {
  guard @fs.kind(path, follow_symlink=false) == Regular else {
    fail("Missing or non-regular retained file")
  }
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let size = file.size()
  guard size <= 1048576L else {
    fail("Retained file exceeds the bounded brief storage limit")
  }
  file.read_exactly_at(size.to_int(), position=0L)
}

///|
async fn brief_write_immutable(path : String, bytes : Bytes) -> Unit {
  let existing = Some(@fs.kind(path, follow_symlink=false)) catch { _ => None }
  if existing is Some(_) {
    guard brief_regular_bytes(path) == bytes else {
      fail("Existing retained bytes conflict; nothing was overwritten")
    }
    return
  }
  let pending = path + ".pending"
  let pending_kind = Some(@fs.kind(pending, follow_symlink=false)) catch {
    _ => None
  }
  if pending_kind is Some(kind) {
    guard kind == Regular else {
      fail("Interrupted write is not a regular staging file")
    }
  }
  @fs.write_file(
    pending,
    bytes,
    create_mode=CreateOrTruncate,
    permission=0o600,
    sync=Full,
  )
  @fs.rename(pending, path, replace=false)
}

///|
async fn brief_check_directory(
  config : Config,
  id : String,
  revision : String,
) -> String {
  let mut path = config.workspace
  for part in [".moonsuite", "products", "moonfind", "briefs", id, revision] {
    path += "/" + part
    guard @fs.kind(path, follow_symlink=false) == Directory else {
      fail("Missing or non-directory brief storage")
    }
  }
  path
}

///|
pub async fn brief_status(
  config : Config,
  id : String,
  revision : String,
) -> BriefStatusV1 {
  let base : BriefStatusV1 = {
    contract_id: "moonfind.brief-status.v1",
    brief_id: id,
    revision_id: revision,
    state: "incomplete",
    snapshot: None,
    issues: [],
  }
  try {
    ignore(brief_directory(config, id, revision))
    let directory = brief_check_directory(config, id, revision)
    let bytes = brief_regular_bytes(directory + "/snapshot.json")
    let saved : BriefSnapshotV1 = @json.from_json(
      @json.parse(@utf8.decode(bytes)),
    )
    let expected = brief_snapshot(saved.brief)
    guard saved == expected &&
      saved.brief.brief_id == id &&
      saved.revision_id == revision &&
      @utf8.encode(saved.to_json().stringify(indent=2) + "\n") == bytes else {
      fail("Retained brief identity or snapshot bytes changed")
    }
    let issues : Array[String] = []
    for i, source in saved.sources {
      try {
        guard @fs.kind(directory + "/sources", follow_symlink=false) ==
          Directory else {
          fail("Missing retained sources directory")
        }
        let retained = brief_regular_bytes(
          directory + "/" + source.archive_path,
        )
        guard retained == brief_source_bytes(saved.brief.sources[i]) else {
          fail("Retained source bytes differ: " + source.name)
        }
      } catch {
        error =>
          issues.push("Source \{source.slot} (" + source.name + "): \{error}")
      }
    }
    {
      ..base,
      state: if issues.is_empty() {
        "prepared"
      } else {
        "incomplete"
      },
      snapshot: Some(saved),
      issues,
    }
  } catch {
    error => { ..base, issues: ["\{error}"], }
  }
}

///|
pub async fn list_briefs(config : Config) -> Array[BriefListItemV1] {
  let root = brief_root(config)
  if !@fs.exists(root) {
    return []
  }
  let mut checked = config.workspace
  for part in [".moonsuite", "products", "moonfind", "briefs"] {
    checked += "/" + part
    guard @fs.kind(checked, follow_symlink=false) == Directory else {
      fail("Brief storage is not a directory")
    }
  }
  let items : Array[BriefListItemV1] = []
  for id in @fs.readdir(root, sort=true).filter(@research.brief_safe_id) {
    if @fs.kind(root + "/" + id, follow_symlink=false) != Directory {
      continue
    }
    for
      revision in @fs.readdir(root + "/" + id, sort=true).filter(
        brief_revision_valid,
      ) {
      guard items.length() < 200 else {
        fail("Brief catalog exceeds the supported 200-revision limit")
      }
      let status = brief_status(config, id, revision)
      items.push({
        brief_id: id,
        revision_id: revision,
        question: status.snapshot
        .map(s => s.brief.question)
        .unwrap_or("Incomplete capture; retry the original save"),
        state: status.state,
      })
    }
  }
  items
}

///|
/// Content identity covers all fields, capture provenance and exact bytes.
/// Commit marker is last. Identical interrupted saves may fill missing files;
/// committed or conflicting bytes are never overwritten or silently repaired.
pub async fn save_brief(
  config : Config,
  brief : @research.ResearchBriefV1,
) -> BriefStatusV1 {
  let snapshot = brief_snapshot(brief)
  let directory = brief_directory(config, brief.brief_id, snapshot.revision_id)
  let mut root = config.workspace
  for part in [".moonsuite", "products", "moonfind", "briefs"] {
    root += "/" + part
    ensure_delivery_directory(root)
  }
  let lock_kind = Some(@fs.kind(root + "/save.lock", follow_symlink=false)) catch {
    _ => None
  }
  if lock_kind is Some(kind) {
    guard kind == Regular else { fail("Brief lock is not a regular file") }
  }
  let lock = @fs.open(
    root + "/save.lock",
    mode=ReadWrite,
    create_mode=OpenOrCreate,
    permission=0o600,
  )
  defer lock.close()
  lock.lock(Exclusive)
  if @fs.exists(directory + "/snapshot.json") {
    return brief_status(config, brief.brief_id, snapshot.revision_id)
  }
  if !@fs.exists(directory) {
    guard list_briefs(config).length() < 200 else {
      fail(
        "The brief catalog has reached its 200-revision limit; no new revision was written",
      )
    }
  }
  match brief.parent_revision {
    Some(parent) => {
      guard brief_revision_valid(parent) && parent != snapshot.revision_id else {
        fail("Invalid parent revision")
      }
      let previous = brief_status(config, brief.brief_id, parent)
      guard previous.state == "prepared" else {
        fail(
          "The parent revision is missing or incomplete; restore its original bytes first",
        )
      }
    }
    None =>
      if @fs.exists(root + "/" + brief.brief_id) {
        guard @fs.readdir(root + "/" + brief.brief_id).all(name => {
          name == snapshot.revision_id
        }) else {
          fail(
            "This brief ID already has another basis; reopen it and save a revision, or choose a new ID",
          )
        }
      }
  }
  ensure_delivery_directory(root + "/" + brief.brief_id)
  ensure_delivery_directory(directory)
  ensure_delivery_directory(directory + "/sources")
  for i, source in snapshot.sources {
    brief_write_immutable(
      directory + "/" + source.archive_path,
      brief_source_bytes(brief.sources[i]),
    )
  }
  brief_write_immutable(
    directory + "/snapshot.json",
    @utf8.encode(snapshot.to_json().stringify(indent=2) + "\n"),
  )
  brief_status(config, brief.brief_id, snapshot.revision_id)
}
