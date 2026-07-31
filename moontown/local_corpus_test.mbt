///|
fn local_salon_ledger() -> @research.LocalInputCoverageLedger {
  {
    contract_version: @research.local_input_coverage_contract_version(),
    ledger_id: "deepseek-ledger",
    source_label: "private-local-corpus",
    expected_input_count: 1,
    inputs: [
      {
        input_id: "page-2",
        relative_path: "pages/page-2.jpg",
        source_digest: "sha256:page-2",
        byte_length: 100L,
        media_type: "image/jpeg",
        sequence_number: 2,
        status: @research.LocalInputStatus::Used,
        extraction_artifact: Some("raw/extracted/page-2.md"),
        evidence_anchors: ["page:2"],
        provenance_ref: "local-import:page-2",
        duplicate_of: None,
        failure_reason: None,
      },
    ],
    known_missing_inputs: ["page-1"],
    created_at: 1L,
    updated_at: 2L,
  }
}

///|
test "local corpus salon is coverage gated and keeps source roles distinct" {
  let handoff = local_corpus_handoff(
    local_salon_ledger(),
    "deepseek-research-book",
    "DeepSeek strategy and technical claims",
  )
  assert_eq(handoff.scenario.participants.length(), 4)
  assert_true(
    handoff.scenario.communication_pattern_id == Some("research-salon"),
  )
  assert_true(
    handoff.scenario.quality_rules.any(fn(rule) {
      rule.contains("one source sequence")
    }),
  )
  assert_eq(handoff.producer_run_id, "deepseek-ledger")
}

///|
test "local corpus salon rejects an unusable ledger" {
  let blocked = {
    ..local_salon_ledger(),
    inputs: [
      {
        ..local_salon_ledger().inputs[0],
        status: @research.LocalInputStatus::Failed,
        extraction_artifact: None,
        evidence_anchors: [],
        failure_reason: Some("unreadable"),
      },
    ],
  }
  let rejected = try {
    ignore(
      local_corpus_handoff(
        blocked, "deepseek-research-book", "DeepSeek strategy and technical claims",
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
