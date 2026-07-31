///|
async test "MoonTown callback ingest is idempotent and remains pending review" {
  let workspace = @fs.tmpdir(prefix="moonfind-moontown-ingest")
  let run_id = "result-ingest-test"
  let handoff : @moontown.TownResearchHandoff = @json.from_json({
    "contract_version": "moontown.civic.communication.handoff.v1",
    "handoff_id": "moonfind-result-ingest-test-research-salon",
    "producer": "moonfind",
    "producer_run_id": run_id,
    "scenario": {
      "id": "moonfind-result-ingest-test",
      "title": "Research salon",
      "communication_pattern_id": "research-salon",
      "building_id": "research-salon",
      "building_book_id": "synthesis",
      "domain_label": "research",
      "topic": "robotics",
      "cadence": "once",
      "skill_name": "synthesis",
      "skill_description": "challenge",
      "protocol_channel": "moonfind.research.cross-paper.v1",
      "reduction_kind": "evidence-backed-idea-synthesis",
      "output_channel": "moonfind.research.ideas.v1",
      "review_gate": "named-human",
      "review_owner": "moonbook.bookkeeper",
      "review_reason": "review",
      "backlog_path": "research/backlog.md",
      "synthesis_path": "research/synthesis.md",
      "metrics_path": "research/metrics.md",
      "review_path": "reviews/research.md",
      "returned_ideas_path": "research/returned.md",
      "participant_contract_path": "research/participants.md",
      "quality_rules": [],
      "skill_rules": [],
      "participants": [
        {
          "book_id": "paper-a",
          "title": "A",
          "focus_area": "a",
          "perspective": "a",
          "cadence": "once",
          "current_question": "a?",
          "contribution": "a",
          "next_artifact": "a.md",
        },
        {
          "book_id": "paper-b",
          "title": "B",
          "focus_area": "b",
          "perspective": "b",
          "cadence": "once",
          "current_question": "b?",
          "contribution": "b",
          "next_artifact": "b.md",
        },
      ],
      "ideas": [],
    },
  })
  @store.write_run_artifact(
    workspace,
    run_id,
    "moontown-handoff.json",
    handoff.to_json(),
  )
  let receipt : @moontown.TownExecutionReceipt = @json.from_json({
    "contract_version": "moontown.civic.communication.receipt.v1",
    "handoff_id": handoff.handoff_id,
    "producer": "moonfind",
    "producer_run_id": run_id,
    "consumer": "moontown",
    "scenario_id": handoff.scenario.id,
    "round_id": "round-1",
    "round_number": 1,
    "status": "completed",
    "reducer_kind": "moonclaw",
    "participant_count": 2,
    "reviewable_output_count": 1,
    "review_status": "pending",
    "building_book_id": "synthesis",
    "artifact_refs": [
      "books/synthesis/research.md", "books/synthesis/review.md",
    ],
    "summary": "completed",
  })
  let output : @moontown.TownSynthesisOutput = @json.from_json({
    "contract_id": "civic.communication.output.v1",
    "scenario_id": handoff.scenario.id,
    "participant_book_ids": ["paper-a", "paper-b"],
    "ideas": [
      {
        "id": "idea-1",
        "title": "Testable bridge",
        "summary": "A cross-paper bridge.",
        "participating_books": ["paper-a", "paper-b"],
        "research_questions": ["What would falsify it?"],
        "why_it_matters": "It connects the evidence.",
        "next_experiment": "Run the falsifier.",
      },
    ],
  })
  let idempotency_key = @moontown.town_result_idempotency_key(run_id)
  let request : @moontown.TownResultIngestRequest = {
    contract_id: "moonfind.moontown-result-ingest.v1",
    idempotency_key,
    handoff_id: handoff.handoff_id,
    producer_run_id: run_id,
    receipt,
    output,
    source: {
      "contract_id": "moontown.research-handoff-result-source.v1",
      "operation_ref": "moontown/civic.communication.synthesize@0.1.0",
      "request_ref": "requests/run.json",
      "result_ref": "results/run.json",
      "receipt_ref": "receipts/run.json",
      "adapter_result": {
        "request_id": "request-\{handoff.handoff_id}",
        "attempt_id": "attempt-1",
        "idempotency_key": idempotency_key,
        "product_id": "moontown",
        "status": "succeeded",
      },
    },
  }
  let config : Config = {
    workspace,
    run_id,
    book_workspace: workspace,
    public_base_url: "http://127.0.0.1:4313",
    capability_catalog_path: None,
    moonclaw_gateway_base: None,
    moonclaw_submit_url: None,
    moonclaw_reconcile_url: None,
    moontown_base_url: None,
  }
  let first = ingest_moontown_result(config, request)
  let replay = ingest_moontown_result(config, request)
  assert_eq(first.state, "ingested-pending-review")
  assert_eq(first.review_status, "pending")
  assert_eq(first.idea_count, 1)
  assert_eq(first.to_json(), replay.to_json())
  assert_true(@fs.exists(run_artifact(config, "moontown-receipt.json")))
  assert_true(@fs.exists(run_artifact(config, "moontown-reducer-output.json")))
  assert_true(
    @fs.exists(run_artifact(config, "moontown-result-ingest-v1.json")),
  )
}
