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
pub fn town_result_idempotency_key(run_id : String) -> String {
  "\{town_handoff_id(run_id)}/research-salon/attempt-1"
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
pub(all) struct TownSynthesisIdea {
  id : String
  title : String
  summary : String
  participating_books : Array[String]
  research_questions : Array[String]
  why_it_matters : String
  next_experiment : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct TownSynthesisOutput {
  contract_id : String
  scenario_id : String
  participant_book_ids : Array[String]
  ideas : Array[TownSynthesisIdea]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct TownResultIngestRequest {
  contract_id : String
  idempotency_key : String
  handoff_id : String
  producer_run_id : String
  receipt : TownExecutionReceipt
  output : TownSynthesisOutput
  source : Json
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
/// Validate a portable handoff before a host exposes it to MoonTown.
/// This verifies identity and review boundaries without importing MoonTown
/// implementation code.
pub fn validate_town_research_handoff(
  handoff : TownResearchHandoff,
  expected_run_id : String,
) -> Array[String] {
  let errors : Array[String] = []
  if handoff.contract_version != town_handoff_contract_version() {
    errors.push(
      "unsupported handoff contract `\{handoff.contract_version}`; expected `\{town_handoff_contract_version()}`",
    )
  }
  if handoff.handoff_id != town_handoff_id(expected_run_id) {
    errors.push("handoff_id does not match the MoonFind run")
  }
  if handoff.producer != "moonfind" ||
    handoff.producer_run_id != expected_run_id {
    errors.push("handoff producer binding does not match the MoonFind run")
  }
  if handoff.scenario.id != "moonfind-\{expected_run_id}" {
    errors.push("handoff scenario does not match the MoonFind run")
  }
  if handoff.scenario.communication_pattern_id != Some("research-salon") ||
    handoff.scenario.review_gate != "named-human" ||
    handoff.scenario.participants.length() < 2 {
    errors.push(
      "handoff must remain a multi-participant research salon with named-human review",
    )
  }
  errors
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

///|
pub fn validate_town_synthesis_output(
  output : TownSynthesisOutput,
  receipt : TownExecutionReceipt,
) -> Array[String] {
  let errors : Array[String] = []
  if output.contract_id != "civic.communication.output.v1" {
    errors.push("unsupported Moontown reducer-output contract")
  }
  if output.scenario_id != receipt.scenario_id {
    errors.push("reducer output scenario does not match the receipt")
  }
  if output.participant_book_ids.length() != receipt.participant_count ||
    output.participant_book_ids.length() < 2 {
    errors.push("participant books do not match the execution receipt")
  }
  if output.ideas.length() != receipt.reviewable_output_count ||
    output.ideas.is_empty() {
    errors.push("reviewable outputs do not match the execution receipt")
  }
  let ids : Array[String] = []
  for idea in output.ideas {
    if idea.id.is_blank() ||
      ids.contains(idea.id) ||
      idea.title.is_blank() ||
      idea.summary.is_blank() ||
      idea.why_it_matters.is_blank() ||
      idea.next_experiment.is_blank() ||
      idea.research_questions.is_empty() ||
      idea.participating_books.length() < 2 ||
      idea.participating_books.any(book => {
        !output.participant_book_ids.contains(book)
      }) {
      errors.push("invalid reviewable reducer output: \{idea.id}")
    } else {
      ids.push(idea.id)
    }
  }
  errors
}

///|
/// Validate a returned MoonTown result against the exact durable handoff.
/// This is intentionally stricter than validating the portable receipt and
/// reducer output separately: all cross-product and attempt identities must
/// correlate before MoonFind persists either artifact.
pub fn validate_town_result_ingest(
  request : TownResultIngestRequest,
  handoff : TownResearchHandoff,
  expected_run_id : String,
) -> Array[String] {
  let errors = validate_town_research_handoff(handoff, expected_run_id) +
    validate_town_execution_receipt(request.receipt, expected_run_id) +
    validate_town_synthesis_output(request.output, request.receipt)
  if request.contract_id != "moonfind.moontown-result-ingest.v1" {
    errors.push("unsupported MoonTown result-ingest contract")
  }
  if request.idempotency_key != town_result_idempotency_key(expected_run_id) {
    errors.push("MoonTown result idempotency key does not match the run")
  }
  if request.handoff_id != handoff.handoff_id ||
    request.producer_run_id != expected_run_id ||
    request.receipt.handoff_id != handoff.handoff_id ||
    request.receipt.scenario_id != handoff.scenario.id ||
    request.output.scenario_id != handoff.scenario.id {
    errors.push("MoonTown result identity does not match the durable handoff")
  }
  if request.receipt.reducer_kind != "moonclaw" {
    errors.push(
      "MoonTown production result must come from the MoonClaw reducer",
    )
  }
  if request.receipt.status != "completed" ||
    request.receipt.review_status != "pending" ||
    request.receipt.round_number < 1 {
    errors.push("MoonTown result must be completed and remain pending review")
  }
  let participant_ids = handoff.scenario.participants.map(participant => {
    participant.book_id
  })
  if request.receipt.participant_count != participant_ids.length() ||
    request.output.participant_book_ids != participant_ids {
    errors.push("MoonTown result participants do not match the exact handoff")
  }
  let artifact_refs : Array[String] = []
  for reference in request.receipt.artifact_refs {
    if reference.is_blank() || artifact_refs.contains(reference) {
      errors.push("MoonTown receipt artifact references must be unique")
    } else {
      artifact_refs.push(reference)
    }
  }
  guard request.source is Object(source) else {
    errors.push("MoonTown result requires a typed source envelope")
    return errors
  }
  match source.get("contract_id") {
    Some(String("moontown.research-handoff-result-source.v1")) => ()
    _ => errors.push("MoonTown result source contract is unsupported")
  }
  match source.get("operation_ref") {
    Some(String("moontown/civic.communication.synthesize@0.1.0")) => ()
    _ => errors.push("MoonTown result source operation is unsupported")
  }
  for field in ["request_ref", "result_ref", "receipt_ref"] {
    match source.get(field) {
      Some(String(value)) if !value.is_blank() &&
        !value.has_prefix("/") &&
        !value.contains("..") &&
        !value.contains("\\") => ()
      _ =>
        errors.push("MoonTown result source \{field} is not a safe reference")
    }
  }
  match source.get("adapter_result") {
    Some(Object(result)) => {
      let expected_request_id = "request-\{handoff.handoff_id}"
      match
        (
          result.get("request_id"),
          result.get("attempt_id"),
          result.get("idempotency_key"),
          result.get("product_id"),
          result.get("status"),
        ) {
        (
          Some(String(request_id)),
          Some(String("attempt-1")),
          Some(String(idempotency_key)),
          Some(String("moontown")),
          Some(String("succeeded")),
        ) if request_id == expected_request_id &&
          idempotency_key == request.idempotency_key => ()
        _ =>
          errors.push(
            "MoonTown adapter result does not match the immutable execution attempt",
          )
      }
    }
    _ => errors.push("MoonTown result source lacks the adapter result")
  }
  errors
}
