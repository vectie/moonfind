///|
pub fn town_handoff_contract_version() -> String {
  "moontown.civic.communication.handoff.v1"
}

///|
pub fn town_receipt_contract_version() -> String {
  "moontown.civic.communication.receipt.v1"
}

///|
pub fn town_handoff_id(run_id : String) -> String {
  "moonfind-\{run_id}-research-salon"
}

///|
pub(all) struct TownResearchHandoff {
  contract_version : String
  handoff_id : String
  producer : String
  producer_run_id : String
  scenario : TownResearchScenario
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct TownExecutionReceipt {
  contract_version : String
  handoff_id : String
  producer : String
  producer_run_id : String
  consumer : String
  scenario_id : String
  round_id : String
  round_number : Int
  status : String
  reducer_kind : String
  participant_count : Int
  reviewable_output_count : Int
  review_status : String
  building_book_id : String
  artifact_refs : Array[String]
  summary : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn cross_paper_handoff(
  run : @research.ResearchRun,
) -> TownResearchHandoff raise {
  {
    contract_version: town_handoff_contract_version(),
    handoff_id: town_handoff_id(run.run_id),
    producer: "moonfind",
    producer_run_id: run.run_id,
    scenario: cross_paper_scenario(run),
  }
}

///|
pub fn validate_town_execution_receipt(
  receipt : TownExecutionReceipt,
  expected_run_id : String,
) -> Array[String] {
  let errors : Array[String] = []
  if receipt.contract_version != town_receipt_contract_version() {
    errors.push(
      "unsupported receipt contract `\{receipt.contract_version}`; expected `\{town_receipt_contract_version()}`",
    )
  }
  if receipt.handoff_id != town_handoff_id(expected_run_id) {
    errors.push("receipt handoff_id does not match the Moonfind run")
  }
  if receipt.producer != "moonfind" ||
    receipt.producer_run_id != expected_run_id {
    errors.push("receipt producer binding does not match the Moonfind run")
  }
  if receipt.consumer != "moontown" {
    errors.push("receipt consumer must be moontown")
  }
  if receipt.scenario_id != "moonfind-\{expected_run_id}" {
    errors.push("receipt scenario_id does not match the Moonfind run")
  }
  if !["completed", "blocked", "rejected"].contains(receipt.status) {
    errors.push("receipt status must be completed, blocked, or rejected")
  }
  if receipt.status == "completed" {
    if receipt.review_status != "pending" {
      errors.push("completed synthesis must remain pending human review")
    }
    if receipt.participant_count < 2 || receipt.reviewable_output_count < 1 {
      errors.push("completed synthesis must contain participants and outputs")
    }
    if receipt.artifact_refs.length() < 2 {
      errors.push("completed synthesis must identify durable artifacts")
    }
  } else if receipt.review_status != "blocked" {
    errors.push("non-completed synthesis receipt must be blocked")
  }
  errors
}
