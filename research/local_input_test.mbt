///|
fn covered_input(
  id : String,
  sequence_number : Int,
  status : LocalInputStatus,
  duplicate_of? : String? = None,
  failure_reason? : String? = None,
) -> LocalInputRecord {
  {
    input_id: id,
    relative_path: "pages/\{id}.jpg",
    source_digest: "sha256:digest-\{id}",
    byte_length: 100L,
    media_type: "image/jpeg",
    sequence_number,
    status,
    extraction_artifact: if status == Used || status == Extracted {
      Some("raw/extracted/\{id}.md")
    } else {
      None
    },
    evidence_anchors: if status == Used {
      ["page:\{sequence_number}"]
    } else {
      []
    },
    provenance_ref: "local-import:\{id}",
    duplicate_of,
    failure_reason,
  }
}

///|
test "local input ledger becomes ready only when every source is usable" {
  let ledger : LocalInputCoverageLedger = {
    contract_version: local_input_coverage_contract_version(),
    ledger_id: "ledger-1",
    source_label: "private-local-corpus",
    expected_input_count: 2,
    inputs: [covered_input("page-2", 2, Used), covered_input("page-3", 3, Used)],
    known_missing_inputs: ["page-1"],
    created_at: 1L,
    updated_at: 2L,
  }
  let summary = summarize_local_input_coverage(ledger)
  assert_true(summary.accounting_complete)
  assert_true(summary.research_ready)
  assert_eq(summary.used_input_count, 2)
}

///|
test "accounted unsupported input blocks research readiness" {
  let ledger : LocalInputCoverageLedger = {
    contract_version: local_input_coverage_contract_version(),
    ledger_id: "ledger-unsupported",
    source_label: "private-local-corpus",
    expected_input_count: 2,
    inputs: [
      covered_input("page-2", 2, Used),
      covered_input(
        "page-3",
        3,
        Unsupported,
        failure_reason=Some("no safe extractor"),
      ),
    ],
    known_missing_inputs: ["page-1"],
    created_at: 1L,
    updated_at: 2L,
  }
  let summary = summarize_local_input_coverage(ledger)
  assert_true(summary.accounting_complete)
  assert_false(summary.research_ready)
  assert_eq(summary.blocked_input_count, 1)
}

///|
test "duplicate input must bind to a used original" {
  let ledger : LocalInputCoverageLedger = {
    contract_version: local_input_coverage_contract_version(),
    ledger_id: "ledger-duplicate",
    source_label: "private-local-corpus",
    expected_input_count: 2,
    inputs: [
      covered_input("page-2", 2, Extracted),
      covered_input("page-3", 3, Duplicate, duplicate_of=Some("page-2")),
    ],
    known_missing_inputs: [],
    created_at: 1L,
    updated_at: 2L,
  }
  let summary = summarize_local_input_coverage(ledger)
  assert_false(summary.accounting_complete)
  assert_false(summary.research_ready)
  assert_true(
    summary.issues.any(fn(issue) {
      issue.contains("duplicate local input must reference a used original")
    }),
  )
}
