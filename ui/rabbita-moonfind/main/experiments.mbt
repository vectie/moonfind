///|
// Local, user-authored records. Neither a source claim nor a report is proof.
struct ExperimentObservation {
  recorded_revision : Int
  status : String
  measurement : String
  notes : String
} derive(Debug, ToJson, FromJson)

///|
struct ExperimentDecision {
  recorded_revision : Int
  before_option_id : String
  before_reasoning : String
  before_next_action : String
  chosen_option_id : String
  reasoning : String
  next_action : String
} derive(Debug, ToJson, FromJson)

///|
struct ChoiceExperiment {
  contract_id : String
  id : String
  created_revision : Int
  origin_question : String
  origin_option : ChoiceOption
  origin_criteria : Array[String]
  origin_evidence : ChoiceEvidence
  hypothesis : String
  procedure : String
  measurable_outcome : String
  disconfirming_threshold : String
  constraints : String
  prepared_revision : Int?
  observation_status : String
  observation_measurement : String
  observation_notes : String
  observation : ExperimentObservation?
  revision_option_id : String
  revision_reasoning : String
  revision_next_action : String
  decision : ExperimentDecision?
} derive(Debug, ToJson, FromJson)

///|
extend ChoiceOption with ToJson::{to_json}

///|
enum ExperimentMsg {
  Start(String)
  Edit(String, String, String)
  Prepare(String)
  Record(String)
  Revise(String)
  Download(String)
} derive(Debug)

///|
fn experiment_boundary() -> String {
  "Browser-local experiment plan and explicitly user-reported observations. No test is executed, no result is independently verified, and no truth, MoonBook review or MoonProj approval is created. Measurements never automatically choose a winner."
}

///|
fn experiment_source(card : ChoiceExperiment) -> EvidencePaper? {
  card.origin_evidence.papers
  .filter(value => value.paper_id == card.origin_option.source_id)
  .get(0)
}

///|
fn experiment_missing(card : ChoiceExperiment) -> Array[String] {
  let missing : Array[String] = []
  for
    (label_, value) in [
      ("hypothesis", card.hypothesis),
      ("procedure", card.procedure),
      ("measurable outcome", card.measurable_outcome),
      ("disconfirming threshold", card.disconfirming_threshold),
      ("constraints", card.constraints),
    ] {
    if value.is_blank() {
      missing.push(label_)
    }
  }
  missing
}

///|
fn experiment_binding_issue(
  sheet : ChoiceWorksheet,
  option : ChoiceOption,
) -> String {
  if option.name.is_blank() {
    return "Name the existing option before starting a test card."
  }
  if choice_evidence_issue(sheet.evidence) != "" {
    return "The retained evidence has invalid source receipts. Repair the worksheet before starting a test."
  }
  if !sheet.evidence.papers.any(value => value.paper_id == option.source_id) {
    return "Select a retained strongest source for this option before starting a source-bound test."
  }
  if option.claim_id != "" &&
    !choice_claims(sheet).any(claim => {
      claim.claim_id == option.claim_id &&
      claim.paper_ids.contains(option.source_id)
    }) {
    return "The selected claim must exist and cite this option's strongest source, or clear the claim selection."
  }
  ""
}

///|
fn choice_experiments_issue(sheet : ChoiceWorksheet) -> String {
  let cards = sheet.experiments.unwrap_or([])
  if cards.length() > 12 {
    return "Experiment retention is limited to 12 cards per worksheet; no cards were discarded."
  }
  for index, card in cards {
    if card.contract_id != "moonfind.choice-experiment.v1" ||
      card.id != "test-\{index + 1}" ||
      card.created_revision < 1 ||
      card.created_revision > sheet.revision ||
      card.origin_evidence.run_id != sheet.evidence.run_id ||
      card.origin_option.id.is_blank() ||
      card.origin_criteria.is_empty() ||
      card.origin_criteria.length() > 6 ||
      card.origin_option.assessments.length() != card.origin_criteria.length() {
      return "Experiment version, identity, revision or source run is invalid."
    }
    let original = { ..sheet, evidence: card.origin_evidence, }
    if experiment_binding_issue(original, card.origin_option) != "" {
      return "An experiment's original option or source snapshot is incomplete."
    }
    if !["unknown", "incomplete", "measured"].contains(card.observation_status) {
      return "Experiment observation status must be unknown, incomplete or measured."
    }
    if card.prepared_revision is Some(revision) &&
      (
        revision <= card.created_revision ||
        revision > sheet.revision ||
        !experiment_missing(card).is_empty()
      ) {
      return "Prepared experiment fields or revision are invalid."
    }
    if card.observation is Some(report) {
      if card.prepared_revision is None ||
        report.recorded_revision <= card.prepared_revision.unwrap_or(0) ||
        report.recorded_revision > sheet.revision ||
        report.notes.is_blank() ||
        !["unknown", "incomplete", "measured"].contains(report.status) ||
        (report.status == "measured" && report.measurement.is_blank()) ||
        report.status != card.observation_status ||
        report.measurement != card.observation_measurement ||
        report.notes != card.observation_notes {
        return "User-reported observation is incomplete or has inconsistent frozen fields."
      }
    }
    if card.decision is Some(decision) {
      if card.observation is None ||
        decision.recorded_revision <=
        card.observation.map(value => value.recorded_revision).unwrap_or(0) ||
        decision.recorded_revision > sheet.revision ||
        decision.reasoning.is_blank() ||
        decision.next_action.is_blank() ||
        decision.chosen_option_id != card.revision_option_id ||
        decision.reasoning != card.revision_reasoning ||
        decision.next_action != card.revision_next_action {
        return "Explicit experiment choice revision is incomplete or inconsistent."
      }
    }
    for
      field in [
        card.hypothesis,
        card.procedure,
        card.measurable_outcome,
        card.disconfirming_threshold,
        card.constraints,
        card.observation_measurement,
        card.observation_notes,
        card.revision_reasoning,
        card.revision_next_action,
      ] {
      if field.length() > 10000 {
        return "Experiment fields are limited to 10,000 characters each."
      }
    }
  }
  ""
}

///|
fn experiment_start(
  sheet : ChoiceWorksheet,
  id : String,
) -> Result[ChoiceWorksheet, String] {
  let cards = sheet.experiments.unwrap_or([])
  if cards.length() >= 12 {
    return Err(
      "All 12 test cards are retained. Download the complete backup; no earlier test is discarded.",
    )
  }
  guard sheet.options.filter(value => value.id == id).get(0) is Some(option) else {
    return Err(
      "That option is no longer available. Review the current worksheet.",
    )
  }
  let issue = experiment_binding_issue(sheet, option)
  if issue != "" {
    return Err(issue)
  }
  let card : ChoiceExperiment = {
    contract_id: "moonfind.choice-experiment.v1",
    id: "test-\{cards.length() + 1}",
    created_revision: sheet.revision + 1,
    origin_question: sheet.question,
    origin_option: option,
    origin_criteria: sheet.criteria.copy(),
    origin_evidence: sheet.evidence,
    hypothesis: "",
    procedure: option.experiment,
    measurable_outcome: "",
    disconfirming_threshold: "",
    constraints: "",
    prepared_revision: None,
    observation_status: "unknown",
    observation_measurement: "",
    observation_notes: "",
    observation: None,
    revision_option_id: sheet.chosen_option_id,
    revision_reasoning: "",
    revision_next_action: "",
    decision: None,
  }
  Ok({ ..sheet, experiments: Some(cards + [card]), })
}

///|
fn experiment_edit(
  card : ChoiceExperiment,
  field : String,
  value : String,
) -> ChoiceExperiment {
  match field {
    "hypothesis" if card.prepared_revision is None =>
      { ..card, hypothesis: value, }
    "procedure" if card.prepared_revision is None =>
      { ..card, procedure: value, }
    "outcome" if card.prepared_revision is None =>
      { ..card, measurable_outcome: value, }
    "threshold" if card.prepared_revision is None =>
      { ..card, disconfirming_threshold: value, }
    "constraints" if card.prepared_revision is None =>
      { ..card, constraints: value, }
    "status" if card.observation is None &&
      ["unknown", "incomplete", "measured"].contains(value) =>
      { ..card, observation_status: value, }
    "measurement" if card.observation is None =>
      { ..card, observation_measurement: value, }
    "notes" if card.observation is None => { ..card, observation_notes: value, }
    "chosen" if card.decision is None => { ..card, revision_option_id: value, }
    "reasoning" if card.decision is None =>
      { ..card, revision_reasoning: value, }
    "next" if card.decision is None => { ..card, revision_next_action: value, }
    _ => card
  }
}

///|
fn experiment_change(
  sheet : ChoiceWorksheet,
  action : ExperimentMsg,
) -> Result[ChoiceWorksheet, String] {
  if sheet.revision >= 2147483647 {
    return Err(
      "The revision counter is exhausted. Download the existing worksheet.",
    )
  }
  let result = match action {
    Start(id) => experiment_start(sheet, id)
    Download(_) => Ok(sheet)
    _ => {
      let id = match action {
        Edit(id, _, _) | Prepare(id) | Record(id) | Revise(id) => id
        _ => ""
      }
      let cards = sheet.experiments.unwrap_or([])
      guard cards.filter(value => value.id == id).get(0) is Some(card) else {
        return Err("That test card is no longer available.")
      }
      let mut changed = card
      let mut next = sheet
      match action {
        Edit(_, field, value) => {
          if value.length() > 10000 {
            return Err(
              "Experiment fields are limited to 10,000 characters. Shorten this entry; the saved draft is unchanged.",
            )
          }
          changed = experiment_edit(card, field, value)
        }
        Prepare(_) => {
          if card.prepared_revision is Some(_) {
            return Err(
              "This plan is already frozen. Start a separate test card for a new plan.",
            )
          }
          let missing = experiment_missing(card)
          if !missing.is_empty() {
            return Err(
              "Draft plan: complete " +
              missing.join(", ") +
              " before freezing the test plan.",
            )
          }
          changed = { ..card, prepared_revision: Some(sheet.revision + 1), }
        }
        Record(_) => {
          if card.prepared_revision is None {
            return Err(
              "Complete and freeze the plan before recording observations.",
            )
          }
          if card.observation is Some(_) {
            return Err(
              "This observation is already retained. Start a separate test for another run.",
            )
          }
          if card.observation_notes.is_blank() ||
            (
              card.observation_status == "measured" &&
              card.observation_measurement.is_blank()
            ) {
            return Err(
              "Describe what you observed or why it is unknown. A measured report also needs the measurement and units.",
            )
          }
          changed = {
            ..card,
            observation: Some({
              recorded_revision: sheet.revision + 1,
              status: card.observation_status,
              measurement: card.observation_measurement,
              notes: card.observation_notes,
            }),
          }
        }
        Revise(_) => {
          if card.observation is None {
            return Err(
              "Record your own observations before explicitly revising the choice.",
            )
          }
          if card.decision is Some(_) {
            return Err(
              "This explicit revision is already retained. Later edits do not rewrite it.",
            )
          }
          if card.revision_reasoning.is_blank() ||
            card.revision_next_action.is_blank() {
            return Err(
              "Explain the choice, including uncertainty, and enter the next action before applying a revision.",
            )
          }
          if card.revision_option_id != "" &&
            !sheet.options.any(value => value.id == card.revision_option_id) {
            return Err(
              "The proposed option was removed. Select a current option or Undecided.",
            )
          }
          let history = sheet.history.unwrap_or([])
          if history.length() >= 20 {
            return Err(
              "All 20 earlier worksheet versions are retained. Download the complete backup; revision is paused rather than removing history.",
            )
          }
          changed = {
            ..card,
            decision: Some({
              recorded_revision: sheet.revision + 1,
              before_option_id: sheet.chosen_option_id,
              before_reasoning: sheet.reasoning,
              before_next_action: sheet.next_action,
              chosen_option_id: card.revision_option_id,
              reasoning: card.revision_reasoning,
              next_action: card.revision_next_action,
            }),
          }
          next = {
            ..sheet,
            chosen_option_id: card.revision_option_id,
            reasoning: card.revision_reasoning,
            next_action: card.revision_next_action,
            history: Some(history + [choice_archive(sheet)]),
          }
        }
        _ => ()
      }
      Ok({
        ..next,
        experiments: Some(
          cards.map(value => if value.id == id { changed } else { value }),
        ),
      })
    }
  }
  match result {
    Err(error) => Err(error)
    Ok(candidate) => {
      if candidate.to_json() == sheet.to_json() {
        return Ok(sheet)
      }
      let next = { ..candidate, revision: sheet.revision + 1, }
      let issue = choice_experiments_issue(next)
      if issue != "" {
        return Err(issue)
      }
      if choice_export_json(next, false).stringify(indent=2).length() + 1 >
        2000000 {
        return Err(
          "This edit would exceed the 2-million-character backup limit. Download the retained worksheet; no original was removed.",
        )
      }
      Ok(next)
    }
  }
}

///|
fn experiment_context(
  card : ChoiceExperiment,
  sheet : ChoiceWorksheet,
  workspace : DurableResearchWorkspace?,
) -> String {
  let same_option = sheet.options.any(value => {
    value.to_json() == card.origin_option.to_json()
  })
  let same_source = workspace
    .map(value => {
      value.run_id == card.origin_evidence.run_id &&
      experiment_source(card)
      .map(old => {
        value.papers
        .unwrap_or([])
        .any(now => choice_same_source_content(old, now))
      })
      .unwrap_or(false)
    })
    .unwrap_or(false)
  if same_option && same_source && choice_current(sheet, workspace) {
    "Original option and source match the loaded context. This does not verify the hypothesis or observations."
  } else {
    "Historical snapshot: the option, source or research context has changed or is unavailable. The original plan remains bound to its retained evidence; review this difference before using its observations."
  }
}
