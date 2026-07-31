///|
fn request_issue(issues : Array[String], detail : String) -> Unit {
  if !issues.contains(detail) {
    issues.push(detail)
  }
}

///|
fn safe_request_artifact(reference : String) -> Bool {
  reference.has_prefix("requests/") &&
  reference.has_suffix(".json") &&
  !reference.contains("..") &&
  !reference.contains("\\") &&
  !reference.contains("//")
}

///|
/// Validate a complete stage-to-request bundle before the publisher copies any
/// artifact. Dependency outputs are intentionally absent: MoonFlow appends
/// accepted dependency artifacts after registration.
pub fn validate_robotics_request_materialization(
  desired : DesiredCapabilityGraphV2,
  materialization : RoboticsRequestMaterializationV1,
  payloads : Array[RoboticsRequestPayloadV1],
) -> Array[String] {
  let issues : Array[String] = []
  if materialization.contract_id !=
    "moonfind.robotics-request-materialization.v1" {
    request_issue(issues, "materialization-contract-unsupported")
  }
  if materialization.graph_id != desired.graph_id ||
    materialization.graph_source_digest != desired.source_digest {
    request_issue(issues, "materialization-graph-identity-mismatch")
  }
  if !materialization.complete || !materialization.unresolved_fields.is_empty() {
    request_issue(issues, "materialization-incomplete")
  }
  if materialization.entries.length() != desired.stages.length() ||
    payloads.length() != desired.stages.length() {
    request_issue(issues, "materialization-cardinality-mismatch")
  }
  for stage in desired.stages {
    if stage.input_artifacts.length() != 1 {
      request_issue(issues, "\{stage.stage_id}:request-artifact-not-exact-one")
      continue
    }
    let artifact_ref = stage.input_artifacts[0]
    if !safe_request_artifact(artifact_ref) {
      request_issue(issues, "\{stage.stage_id}:request-artifact-unsafe")
    }
    let entries = materialization.entries.filter(entry => {
      entry.stage_id == stage.stage_id
    })
    guard entries is [entry] else {
      request_issue(issues, "\{stage.stage_id}:materialization-entry-missing")
      continue
    }
    if entry.artifact_ref != artifact_ref ||
      stage.input_schema_ref != Some(entry.input_schema_ref) {
      request_issue(
        issues,
        "\{stage.stage_id}:materialization-binding-mismatch",
      )
    }
    match robotics_request_schema_digest(entry.input_schema_ref) {
      Some(expected) =>
        if entry.schema_digest != expected {
          request_issue(
            issues,
            "\{stage.stage_id}:request-schema-registry-digest-mismatch",
          )
        }
      None =>
        request_issue(
          issues,
          "\{stage.stage_id}:request-schema-registry-missing",
        )
    }
    if entry.required_top_level_fields.is_empty() {
      request_issue(
        issues,
        "\{stage.stage_id}:request-required-field-registry-empty",
      )
    }
    let matches = payloads.filter(payload => {
      payload.artifact_ref == artifact_ref
    })
    guard matches is [payload] else {
      request_issue(issues, "\{stage.stage_id}:request-payload-missing")
      continue
    }
    if payload.payload_digest != entry.payload_digest {
      request_issue(issues, "\{stage.stage_id}:request-payload-digest-mismatch")
    }
    guard payload.payload is Object(fields) else {
      request_issue(issues, "\{stage.stage_id}:request-payload-not-object")
      continue
    }
    for required in entry.required_top_level_fields {
      if fields.get(required) is None {
        request_issue(
          issues,
          "\{stage.stage_id}:request-required-field-missing:\{required}",
        )
      }
    }
    match entry.constant_top_level_fields {
      Object(constants) =>
        for key, expected in constants {
          if fields.get(key) != Some(expected) {
            request_issue(
              issues,
              "\{stage.stage_id}:request-constant-mismatch:\{key}",
            )
          }
        }
      _ =>
        request_issue(
          issues,
          "\{stage.stage_id}:request-constant-registry-invalid",
        )
    }
    match robotics_request_contract_constant(entry.input_schema_ref) {
      Some((field, expected)) =>
        if fields.get(field) != Some(Json::string(expected)) {
          request_issue(
            issues,
            "\{stage.stage_id}:request-pack-contract-mismatch:\{field}",
          )
        }
      None => ()
    }
  }
  issues
}
