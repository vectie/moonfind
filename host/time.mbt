///|
fn host_timestamp() -> String raise {
  let timestamp_ms = @async.now()
  let seconds = timestamp_ms / 1000L
  let value = @time.PlainDateTime::from_unix_second(
    seconds, 0, @time.utc_offset,
  )
  value.to_string() + "Z"
}

///|
fn trimmed_base(value : String) -> String {
  let base = value.trim().to_owned()
  if base.has_suffix("/") {
    base[:base.length() - 1].to_owned()
  } else {
    base
  }
}

///|
fn book_id_from_path(path : String) -> String {
  let parts = path
    .replace_all(old="\\", new="/")
    .split("/")
    .filter(part => !part.is_blank())
    .collect()
  if parts.is_empty() {
    "moonfind-research"
  } else {
    parts[parts.length() - 1].to_owned()
  }
}
