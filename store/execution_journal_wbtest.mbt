///|
fn journal_catalog() -> @integration.CapabilityCatalogV1 {
  {
    contract_id: "moonflow.capability-catalog.v1",
    catalog_id: "journal-test",
    compiled_at: "2026-07-31T00:00:00Z",
    conformant: true,
    products: [
      { product_id: "moonfind", pack_id: "moonfind", pack_version: "0.1.0", },
    ],
    operations: [
      {
        operation_ref: @integration.moonfind_analysis_operation_ref(),
        product_id: "moonfind",
        pack_id: "moonfind",
        pack_version: "0.1.0",
        tool_id: "research.prepare-analysis",
        adapter_id: "moonfind-pack-local-v1",
        protocol: "moonflow.adapter.v2",
        authority: "sandbox-execution",
        input_schema_ref: @integration.moonfind_analysis_input_schema_ref(),
        output_schema_ref: @integration.moonfind_analysis_output_schema_ref(),
        claim_ceiling: "execution-result",
        idempotent: true,
        review_required: false,
        supports_cancel: true,
        supports_reconcile: true,
        health_checked_at: "2026-07-30T00:00:00Z",
        health_valid_until: "2026-08-01T00:00:00Z",
        health_evidence_ref: "health/moonfind.json",
        health_evidence_digest: "sha256:" + "a".repeat(64),
      },
    ],
    issues: [],
  }
}

///|
async test "execution journal recovers the latest synced complete revision" {
  let workspace = @fs.tmpdir(prefix="moonfind-execution-journal-")
  let prepared = @integration.prepare_analysis_execution(
    journal_catalog(),
    "run-journal",
    "book-journal",
    "sha256:" + "0".repeat(64),
    ["records/run.json"],
    { "run_id": "run-journal" },
    "2026-07-31T00:00:00Z",
    30000,
  )
  ignore(append_execution_record(workspace, prepared))
  let submitting = @integration.mark_execution_submitting(
    prepared, "2026-07-31T00:00:01Z",
  )
  let path = append_execution_record(workspace, submitting)
  @fs.write_file(
    path,
    @utf8.encode("{\"torn\":"),
    create_mode=OpenOrCreate,
    append=true,
  )
  guard read_latest_execution_record(workspace, "run-journal")
    is Some(recovered) else {
    fail("expected recovered execution record")
  }
  assert_eq(recovered.revision, 2)
  assert_eq(recovered.state, "submitting")
  assert_eq(recovered.idempotency_key, prepared.idempotency_key)
  @fs.rmdir(workspace, recursive=true)
}
