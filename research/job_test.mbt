///|
fn report_job() -> ResearchJob {
  {
    contract_id: research_job_contract_version(),
    job_id: "battery-review",
    objective: "Compare solid-state battery interface evidence",
    audience: "materials research team",
    source_scope: ["permitted literature", "supplied lab notes"],
    requested_outputs: [
      {
        output_id: "report",
        title: "Evidence review",
        kind: "report",
        format: "text/markdown",
        acceptance_criteria: ["claims cited", "limitations stated"],
      },
    ],
    created_at: 10L,
  }
}

///|
fn report_delivery() -> DeliveryManifest {
  {
    contract_id: delivery_manifest_contract_version(),
    job_id: "battery-review",
    outputs: [
      {
        output_id: "report",
        artifact_ref: "deliverables/report.md",
        media_type: "text/markdown",
        artifact_digest: "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        byte_length: 1200L,
        evidence_refs: ["evidence/claims.json"],
        checks: [
          {
            criterion: "claims cited",
            status: "passed",
            evidence_ref: "checks/citations.json",
          },
          {
            criterion: "limitations stated",
            status: "passed",
            evidence_ref: "checks/limitations.json",
          },
        ],
      },
    ],
    open_gaps: [],
    review_status: "pending-review",
    delivered_at: 20L,
  }
}

///|
test "a research job delivers all requested files with evidence and checks" {
  assert_true(validate_research_job(report_job()).is_empty())
  assert_true(delivery_manifest_complete(report_job(), report_delivery()))
}

///|
test "a missing output cannot be called delivered" {
  let manifest = { ..report_delivery(), outputs: [], }
  assert_false(delivery_manifest_complete(report_job(), manifest))
}

///|
test "unsafe artifacts and incomplete acceptance checks block delivery" {
  let original = report_delivery()
  let output = original.outputs[0]
  let manifest = {
    ..original,
    outputs: [
      {
        ..output,
        artifact_ref: "../private/report.md",
        checks: [output.checks[0]],
      },
    ],
  }
  assert_false(delivery_manifest_complete(report_job(), manifest))
}
