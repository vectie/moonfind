///|
test "terminal review state does not require a live MoonClaw gateway" {
  let record : @integration.ResearchExecutionRecordV1 = @json.from_json({
    "contract_id": "moonfind.research-execution-record.v1",
    "revision": 6,
    "run_id": "run-1",
    "operation_ref": "moonfind/research.prepare-analysis@0.1.0",
    "request_id": "request-1",
    "attempt_id": "attempt-1",
    "idempotency_key": "moonfind/run-1/attempt-1",
    "state": "needs-review",
    "invocation": {
      "contract_id": "moonclaw.capability-invocation.v1",
      "adapter_id": "moonfind-pack-local-v1",
      "evaluated_at": "2026-07-31T00:00:00Z",
      "recorded_at": "2026-07-31T00:00:00Z",
      "attempt": 1,
      "request": {
        "request_id": "request-1",
        "run_id": "run-1",
        "book_id": "book-1",
        "work_item_id": "prepare-analysis",
        "declaration_id": "moonfind-prepare-analysis-v1",
        "attempt_id": "attempt-1",
        "idempotency_key": "moonfind/run-1/attempt-1",
        "product_id": "moonfind",
        "operation": "moonfind/research.prepare-analysis@0.1.0",
        "requested_authority": "sandbox-execution",
        "acceptance_criteria": ["command exists"],
        "input_contracts": ["moonfind/research-run@1.0.0"],
        "output_contracts": ["moonfind/moonclaw-research-command@1.0.0"],
        "required_claim": "execution-result",
        "input_digest": "sha256:0000000000000000000000000000000000000000000000000000000000000000",
        "input_artifacts": ["run.json"],
        "timeout_ms": 30000,
        "created_at": "2026-07-31T00:00:00Z",
      },
      "config": {},
      "input": {},
    },
    "error_kind": "",
    "requires_review": true,
    "next_action": "named-human-review",
    "updated_at": "2026-07-31T00:00:06Z",
  })
  assert_eq(execution_requires_moonclaw_gateway(Some(record)), false)
  assert_eq(
    execution_requires_moonclaw_gateway(
      Some({ ..record, state: "runtime-pending" }),
    ),
    true,
  )
}

///|
test "MoonTown handoff opens the canonical map with encoded typed parameters" {
  assert_eq(moontown_map_path(), "/index.html?seed=20260727")
  assert_eq(
    moontown_open_url(
      "http://127.0.0.1:17842/", "moontown.civic.communication.handoff.v1", "handoff / 中文",
      "http://127.0.0.1:4313/api/v1/moontown/handoff?run=a&b=c",
    ),
    "http://127.0.0.1:17842/index.html?seed=20260727&handoff_contract=moontown.civic.communication.handoff.v1&handoff_id=handoff%20%2F%20%E4%B8%AD%E6%96%87&handoff_url=http%3A%2F%2F127.0.0.1%3A4313%2Fapi%2Fv1%2Fmoontown%2Fhandoff%3Frun%3Da%26b%3Dc",
  )
}
