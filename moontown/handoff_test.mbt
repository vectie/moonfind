///|
test "Moonfind accepts a bound review-pending Moontown receipt" {
  let run_id = "humanoid-cross-paper-demo"
  let receipt = @moontown.TownExecutionReceipt::{
    contract_version: @moontown.town_receipt_contract_version(),
    handoff_id: @moontown.town_handoff_id(run_id),
    producer: "moonfind",
    producer_run_id: run_id,
    consumer: "moontown",
    scenario_id: "moonfind-\{run_id}",
    round_id: "moonfind-\{run_id}-round-1",
    round_number: 1,
    status: "completed",
    reducer_kind: "fixture",
    participant_count: 3,
    reviewable_output_count: 1,
    review_status: "pending",
    building_book_id: "moonfind-synthesis-book",
    artifact_refs: ["research/cross-paper-synthesis.md", "reviews/moonfind.md"],
    summary: "completed",
  }
  assert_eq(
    @moontown.validate_town_execution_receipt(receipt, run_id).length(),
    0,
  )
}

///|
test "Moonfind rejects an unbound or prematurely accepted receipt" {
  let receipt = @moontown.TownExecutionReceipt::{
    contract_version: @moontown.town_receipt_contract_version(),
    handoff_id: "wrong",
    producer: "moonfind",
    producer_run_id: "wrong",
    consumer: "moontown",
    scenario_id: "wrong",
    round_id: "round-1",
    round_number: 1,
    status: "completed",
    reducer_kind: "moonclaw",
    participant_count: 3,
    reviewable_output_count: 1,
    review_status: "accepted",
    building_book_id: "moonfind-synthesis-book",
    artifact_refs: [],
    summary: "invalid",
  }
  assert_true(
    @moontown.validate_town_execution_receipt(
      receipt, "humanoid-cross-paper-demo",
    ).length() >=
    4,
  )
}

///|
test "Moonfind validates the typed research-salon handoff before host exposure" {
  let handoff : @moontown.TownResearchHandoff = @json.from_json({
    "contract_version": "moontown.civic.communication.handoff.v1",
    "handoff_id": "moonfind-run-1-research-salon",
    "producer": "moonfind",
    "producer_run_id": "run-1",
    "scenario": {
      "id": "moonfind-run-1",
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
  assert_true(
    @moontown.validate_town_research_handoff(handoff, "run-1").is_empty(),
  )
  assert_true(
    !@moontown.validate_town_research_handoff(handoff, "other").is_empty(),
  )
  let receipt = @moontown.TownExecutionReceipt::{
    contract_version: @moontown.town_receipt_contract_version(),
    handoff_id: handoff.handoff_id,
    producer: "moonfind",
    producer_run_id: "run-1",
    consumer: "moontown",
    scenario_id: handoff.scenario.id,
    round_id: "moonfind-run-1-round-1",
    round_number: 1,
    status: "completed",
    reducer_kind: "moonclaw",
    participant_count: 2,
    reviewable_output_count: 1,
    review_status: "pending",
    building_book_id: handoff.scenario.building_book_id,
    artifact_refs: ["books/synthesis/research.md", "books/synthesis/review.md"],
    summary: "completed",
  }
  let output = @moontown.TownSynthesisOutput::{
    contract_id: "civic.communication.output.v1",
    scenario_id: handoff.scenario.id,
    participant_book_ids: ["paper-a", "paper-b"],
    ideas: [
      {
        id: "idea-1",
        title: "Testable bridge",
        summary: "A cross-paper bridge.",
        participating_books: ["paper-a", "paper-b"],
        research_questions: ["What would falsify it?"],
        why_it_matters: "It connects the evidence.",
        next_experiment: "Run the falsifier.",
      },
    ],
  }
  let request = @moontown.TownResultIngestRequest::{
    contract_id: "moonfind.moontown-result-ingest.v1",
    idempotency_key: @moontown.town_result_idempotency_key("run-1"),
    handoff_id: handoff.handoff_id,
    producer_run_id: "run-1",
    receipt,
    output,
    source: {
      "contract_id": "moontown.research-handoff-result-source.v1",
      "operation_ref": "moontown/civic.communication.synthesize@0.1.0",
      "request_ref": "requests/run-1.json",
      "result_ref": "results/run-1.json",
      "receipt_ref": "receipts/run-1.json",
      "adapter_result": {
        "request_id": "request-\{handoff.handoff_id}",
        "attempt_id": "attempt-1",
        "idempotency_key": @moontown.town_result_idempotency_key("run-1"),
        "product_id": "moontown",
        "status": "succeeded",
      },
    },
  }
  assert_true(
    @moontown.validate_town_result_ingest(request, handoff, "run-1").is_empty(),
  )
  assert_true(
    !@moontown.validate_town_result_ingest(
      { ..request, idempotency_key: "different-attempt" },
      handoff,
      "run-1",
    ).is_empty(),
  )
}
