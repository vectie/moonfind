///|
pub fn research_job_contract_version() -> String {
  "moonfind.research-job.v1"
}

///|
pub fn delivery_manifest_contract_version() -> String {
  "moonfind.delivery-manifest.v1"
}

///|
pub(all) struct RequestedOutput {
  output_id : String
  title : String
  kind : String
  format : String
  acceptance_criteria : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct ResearchJob {
  contract_id : String
  job_id : String
  objective : String
  audience : String
  source_scope : Array[String]
  requested_outputs : Array[RequestedOutput]
  created_at : Int64
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct DeliveryCheck {
  criterion : String
  status : String
  evidence_ref : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct DeliveredOutput {
  output_id : String
  artifact_ref : String
  media_type : String
  artifact_digest : String
  byte_length : Int64
  evidence_refs : Array[String]
  checks : Array[DeliveryCheck]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct DeliveryManifest {
  contract_id : String
  job_id : String
  outputs : Array[DeliveredOutput]
  open_gaps : Array[String]
  review_status : String
  delivered_at : Int64
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct DeliveryEvidenceOutput {
  output_id : String
  evidence_refs : Array[String]
  checks : Array[DeliveryCheck]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct DeliveryEvidence {
  contract_id : String
  job_id : String
  outputs : Array[DeliveryEvidenceOutput]
} derive(Debug, Eq, ToJson, FromJson)

///|
fn safe_job_artifact_ref(value : String) -> Bool {
  !value.is_blank() &&
  !value.has_prefix("/") &&
  !value.contains("\\") &&
  !value.split("/").contains("..")
}

///|
pub fn validate_research_job(job : ResearchJob) -> Array[String] {
  let issues : Array[String] = []
  if job.contract_id != research_job_contract_version() {
    issues.push("unsupported research job contract")
  }
  if job.job_id.is_blank() ||
    job.objective.is_blank() ||
    job.audience.is_blank() {
    issues.push("job identity, objective and audience are required")
  }
  if job.created_at < 0 {
    issues.push("job creation time must be non-negative")
  }
  if job.source_scope.is_empty() ||
    job.source_scope.any(fn(source) { source.is_blank() }) {
    issues.push("job needs an explicit source scope")
  }
  if job.requested_outputs.is_empty() {
    issues.push("at least one requested output is required")
  }
  let output_ids : Array[String] = []
  for output in job.requested_outputs {
    if output.output_id.is_blank() || output_ids.contains(output.output_id) {
      issues.push("requested output IDs must be non-empty and unique")
    }
    output_ids.push(output.output_id)
    if output.title.is_blank() ||
      output.kind.is_blank() ||
      output.format.is_blank() ||
      output.acceptance_criteria.is_empty() {
      issues.push(
        "requested output needs a title, kind, format and acceptance criteria",
      )
    }
    let criteria : Array[String] = []
    for criterion in output.acceptance_criteria {
      if criterion.is_blank() || criteria.contains(criterion) {
        issues.push("acceptance criteria must be non-empty and unique")
      }
      criteria.push(criterion)
    }
  }
  issues
}

///|
pub fn delivery_manifest_issues(
  job : ResearchJob,
  manifest : DeliveryManifest,
) -> Array[String] {
  let issues = validate_research_job(job)
  if manifest.contract_id != delivery_manifest_contract_version() ||
    manifest.job_id != job.job_id ||
    manifest.delivered_at < job.created_at {
    issues.push("delivery manifest identity or time does not match the job")
  }
  if manifest.review_status != "pending-review" &&
    manifest.review_status != "accepted" {
    issues.push("delivery review status must be explicit")
  }
  if !manifest.open_gaps.is_empty() {
    issues.push("delivery has open gaps")
  }
  let delivered_ids : Array[String] = []
  for output in manifest.outputs {
    if output.output_id.is_blank() || delivered_ids.contains(output.output_id) {
      issues.push("delivered output IDs must be non-empty and unique")
    }
    delivered_ids.push(output.output_id)
    let mut requested : RequestedOutput? = None
    for item in job.requested_outputs {
      if item.output_id == output.output_id {
        requested = Some(item)
      }
    }
    match requested {
      None => issues.push("delivery contains an unrequested output")
      Some(spec) => {
        if !safe_job_artifact_ref(output.artifact_ref) ||
          output.media_type != spec.format ||
          !output.artifact_digest.has_prefix("sha256:") ||
          output.artifact_digest.length() != 71 ||
          output.byte_length <= 0L {
          issues.push(
            "delivered output lacks a safe, content-addressed artifact",
          )
        }
        if output.evidence_refs.is_empty() ||
          output.evidence_refs.any(fn(value) { !safe_job_artifact_ref(value) }) {
          issues.push("delivered output needs safe evidence references")
        }
        let checked : Array[String] = []
        for check in output.checks {
          if !spec.acceptance_criteria.contains(check.criterion) ||
            checked.contains(check.criterion) ||
            check.status != "passed" ||
            !safe_job_artifact_ref(check.evidence_ref) {
            issues.push("delivery check is missing, duplicated or not passed")
          }
          checked.push(check.criterion)
        }
        if spec.acceptance_criteria.any(fn(criterion) {
            !checked.contains(criterion)
          }) {
          issues.push("requested acceptance criterion was not checked")
        }
      }
    }
  }
  if job.requested_outputs.any(fn(output) {
      !delivered_ids.contains(output.output_id)
    }) {
    issues.push("requested output is missing from delivery")
  }
  issues
}

///|
/// Checks the manifest's declared coverage and receipts. The trusted host must
/// verify file bytes, digests, and referenced receipts before delivery.
pub fn delivery_manifest_complete(
  job : ResearchJob,
  manifest : DeliveryManifest,
) -> Bool {
  delivery_manifest_issues(job, manifest).is_empty()
}
