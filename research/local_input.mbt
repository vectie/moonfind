///|
pub fn local_input_coverage_contract_version() -> String {
  "moonfind.local-input-coverage.v1"
}

///|
pub(all) enum LocalInputStatus {
  Ingested
  Extracted
  Used
  Duplicate
  Unsupported
  Failed
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct LocalInputRecord {
  input_id : String
  relative_path : String
  source_digest : String
  byte_length : Int64
  media_type : String
  sequence_number : Int
  status : LocalInputStatus
  extraction_artifact : String?
  evidence_anchors : Array[String]
  provenance_ref : String
  duplicate_of : String?
  failure_reason : String?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct LocalInputCoverageLedger {
  contract_version : String
  ledger_id : String
  source_label : String
  expected_input_count : Int
  inputs : Array[LocalInputRecord]
  known_missing_inputs : Array[String]
  created_at : Int64
  updated_at : Int64
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct LocalInputCoverageSummary {
  expected_input_count : Int
  accounted_input_count : Int
  used_input_count : Int
  duplicate_input_count : Int
  blocked_input_count : Int
  accounting_complete : Bool
  research_ready : Bool
  issues : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
fn input_reference_exists(
  inputs : ArrayView[LocalInputRecord],
  input_id : String,
) -> Bool {
  inputs.any(fn(input) { input.input_id == input_id })
}

///|
fn input_by_id(
  inputs : ArrayView[LocalInputRecord],
  input_id : String,
) -> LocalInputRecord? {
  for input in inputs {
    if input.input_id == input_id {
      return Some(input)
    }
  }
  None
}

///|
fn nonblank_unique(values : ArrayView[String]) -> Bool {
  let seen : Array[String] = []
  for value in values {
    if value.is_blank() || seen.contains(value) {
      return false
    }
    seen.push(value)
  }
  true
}

///|
fn validate_local_input_record(
  input : LocalInputRecord,
  inputs : ArrayView[LocalInputRecord],
) -> Array[String] {
  let issues : Array[String] = []
  if input.input_id.is_blank() ||
    input.relative_path.is_blank() ||
    input.source_digest.is_blank() ||
    input.media_type.is_blank() ||
    input.provenance_ref.is_blank() {
    issues.push("local input identity and provenance are required")
  }
  if input.relative_path.has_prefix("/") ||
    input.relative_path.contains("\\") ||
    input.relative_path.contains("..") {
    issues.push("local input relative_path must stay below the source root")
  }
  if !input.source_digest.has_prefix("sha256:") {
    issues.push("local input source_digest must be a sha256 digest")
  }
  if input.byte_length < 0L || input.sequence_number < 1 {
    issues.push(
      "local input size and sequence must be non-negative and ordered",
    )
  }
  if !nonblank_unique(input.evidence_anchors) {
    issues.push("local input evidence anchors must be unique and non-empty")
  }
  match input.status {
    Used =>
      if input.extraction_artifact is None ||
        input.evidence_anchors.is_empty() ||
        input.duplicate_of is Some(_) ||
        input.failure_reason is Some(_) {
        issues.push(
          "used local input requires an extraction artifact and evidence anchors",
        )
      }
    Extracted =>
      if input.extraction_artifact is None ||
        input.duplicate_of is Some(_) ||
        input.failure_reason is Some(_) {
        issues.push(
          "extracted local input requires an artifact without failure metadata",
        )
      }
    Ingested =>
      if input.extraction_artifact is Some(_) ||
        input.duplicate_of is Some(_) ||
        input.failure_reason is Some(_) {
        issues.push("ingested local input cannot claim later-stage evidence")
      }
    Duplicate =>
      match input.duplicate_of {
        Some(original_id) =>
          if original_id == input.input_id ||
            !input_reference_exists(inputs, original_id) {
            issues.push("duplicate local input must reference another input")
          } else {
            match input_by_id(inputs, original_id) {
              Some(original) if original.status == Used => ()
              _ =>
                issues.push(
                  "duplicate local input must reference a used original",
                )
            }
          }
        None => issues.push("duplicate local input requires duplicate_of")
      }
    Unsupported | Failed =>
      if input.failure_reason is None || input.duplicate_of is Some(_) {
        issues.push(
          "blocked local input requires a failure reason without duplicate metadata",
        )
      }
  }
  issues
}

///|
pub fn validate_local_input_coverage(
  ledger : LocalInputCoverageLedger,
) -> Array[String] {
  let issues : Array[String] = []
  if ledger.contract_version != local_input_coverage_contract_version() {
    issues.push("local input coverage contract version mismatch")
  }
  if ledger.ledger_id.is_blank() || ledger.source_label.is_blank() {
    issues.push("local input ledger identity and source label are required")
  }
  if ledger.expected_input_count < 1 ||
    ledger.inputs.length() != ledger.expected_input_count {
    issues.push("local input ledger does not match its expected input count")
  }
  if ledger.created_at < 0L || ledger.updated_at < ledger.created_at {
    issues.push("local input ledger timestamps are invalid")
  }
  if !nonblank_unique(ledger.known_missing_inputs) {
    issues.push("known missing inputs must be unique and non-empty")
  }
  let ids : Array[String] = []
  let paths : Array[String] = []
  let sequences : Array[Int] = []
  for input in ledger.inputs {
    if ids.contains(input.input_id) {
      issues.push("duplicate local input id: \{input.input_id}")
    } else {
      ids.push(input.input_id)
    }
    if paths.contains(input.relative_path) {
      issues.push("duplicate local input path: \{input.relative_path}")
    } else {
      paths.push(input.relative_path)
    }
    if sequences.contains(input.sequence_number) {
      issues.push(
        "duplicate local input sequence: \{input.sequence_number.to_string()}",
      )
    } else {
      sequences.push(input.sequence_number)
    }
    for issue in validate_local_input_record(input, ledger.inputs) {
      issues.push("\{input.input_id}: \{issue}")
    }
  }
  issues
}

///|
pub fn summarize_local_input_coverage(
  ledger : LocalInputCoverageLedger,
) -> LocalInputCoverageSummary {
  let issues = validate_local_input_coverage(ledger)
  let mut used_input_count = 0
  let mut duplicate_input_count = 0
  let mut blocked_input_count = 0
  let mut research_ready = issues.is_empty()
  for input in ledger.inputs {
    match input.status {
      Used => used_input_count = used_input_count + 1
      Duplicate => duplicate_input_count = duplicate_input_count + 1
      Ingested | Extracted | Unsupported | Failed => {
        blocked_input_count = blocked_input_count + 1
        research_ready = false
      }
    }
  }
  {
    expected_input_count: ledger.expected_input_count,
    accounted_input_count: ledger.inputs.length(),
    used_input_count,
    duplicate_input_count,
    blocked_input_count,
    accounting_complete: issues.is_empty(),
    research_ready,
    issues,
  }
}
