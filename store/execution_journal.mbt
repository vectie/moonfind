///|
pub fn execution_journal_path(
  workspace : String,
  run_id : String,
) -> String raise {
  run_directory(workspace, run_id) + "/capability-execution.jsonl"
}

///|
fn execution_json_without_null_fields(value : Json) -> Json {
  match value {
    Object(fields) => {
      let cleaned : Map[String, Json] = {}
      for key, item in fields {
        if item is Null {
          continue
        }
        cleaned[key] = execution_json_without_null_fields(item)
      }
      Json::object(cleaned)
    }
    Array(values) => Json::array(values.map(execution_json_without_null_fields))
    _ => value
  }
}

///|
fn last_valid_execution_record(
  text : String,
) -> @integration.ResearchExecutionRecordV1? {
  let lines = text.split("\n").to_array()
  for i = lines.length() - 1; i >= 0; i = i - 1 {
    let line = lines[i].trim()
    if line.is_blank() {
      continue
    }
    try @json.parse(line) catch {
      _ => ()
    } noraise {
      value =>
        try @json.from_json(execution_json_without_null_fields(value)) catch {
          _ => ()
        } noraise {
          record => return Some(record)
        }
    }
  }
  None
}

///|
/// Recover the latest complete append-only execution checkpoint. A torn final
/// line is ignored; the previous synced checkpoint remains authoritative.
pub async fn read_latest_execution_record(
  workspace : String,
  run_id : String,
) -> @integration.ResearchExecutionRecordV1? {
  let path = execution_journal_path(workspace, run_id)
  if !@fs.exists(path) {
    return None
  }
  last_valid_execution_record(@fs.read_file(path).text())
}

///|
/// Append and fully sync one monotonic execution checkpoint. The immutable
/// request, attempt and idempotency identities may never drift across rows.
pub async fn append_execution_record(
  workspace : String,
  record : @integration.ResearchExecutionRecordV1,
) -> String {
  guard record.contract_id == "moonfind.research-execution-record.v1" &&
    record.run_id == record.invocation.request.run_id &&
    record.request_id == record.invocation.request.request_id &&
    record.attempt_id == record.invocation.request.attempt_id &&
    record.idempotency_key == record.invocation.request.idempotency_key else {
    fail("execution checkpoint identity is inconsistent")
  }
  let directory = ensure_run_directory(workspace, record.run_id)
  let path = directory + "/capability-execution.jsonl"
  match read_latest_execution_record(workspace, record.run_id) {
    Some(previous) => {
      guard record.revision == previous.revision + 1 &&
        record.operation_ref == previous.operation_ref &&
        record.request_id == previous.request_id &&
        record.attempt_id == previous.attempt_id &&
        record.idempotency_key == previous.idempotency_key &&
        record.invocation == previous.invocation else {
        fail("execution checkpoint is not the next immutable revision")
      }
    }
    None => {
      guard record.revision == 1 && record.state == "prepared" else {
        fail("execution journal must begin with revision 1 prepared")
      }
    }
  }
  @fs.write_file(
    path,
    @utf8.encode(
      execution_json_without_null_fields(record.to_json()).stringify() + "\n",
    ),
    sync=Full,
    append=true,
    create_mode=OpenOrCreate,
    permission=0o600,
  )
  path
}
