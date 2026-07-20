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
