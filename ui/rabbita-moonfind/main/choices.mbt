///|
struct ChoiceEvidence {
  run_id : String
  question : String
  papers : Array[EvidencePaper]
  summaries : Array[EvidenceSummary]
} derive(Debug, ToJson, FromJson)

///|
extend ChoiceEvidence with ToJson::{to_json}

///|
struct ChoiceOption {
  id : String
  name : String
  assessments : Array[String]
  source_id : String
  claim_id : String
  contradiction : String
  unknowns : String
  cost_of_error : String
  experiment : String
  retained_source : EvidencePaper?
  retained_claim : EvidenceClaim?
  evidence_review_note : String?
} derive(Debug, ToJson, FromJson)

///|
struct ChoiceWorksheet {
  contract_id : String
  revision : Int
  next_option : Int
  evidence : ChoiceEvidence
  question : String
  audience : String
  commitment_ref : String
  criteria : Array[String]
  options : Array[ChoiceOption]
  chosen_option_id : String
  reasoning : String
  next_action : String
  history : Array[ChoiceArchive]?
  experiments : Array[ChoiceExperiment]?
} derive(Debug, ToJson, FromJson)

///|
extend ChoiceWorksheet with ToJson::{to_json}

///|
struct ChoiceState {
  key : String
  sheet : ChoiceWorksheet?
  notice : String
  save_blocked : Bool
  recovery_input : String
} derive(Debug)

///|
enum ChoiceMsg {
  SetField(String, String)
  SetCriterion(Int, String)
  AddCriterion
  SetOption(String, String, String)
  SetAssessment(String, Int, String)
  AddOption
  RemoveOption(String)
  Save
  Export(String)
  SetRecovery(String)
  Restore
  ContinueEvidence(Int, String)
  ExportRevision(Int, String)
  Experiment(String, Int, String, String, ExperimentMsg)
} derive(Debug)

///|
fn empty_choices() -> ChoiceState {
  { key: "", sheet: None, notice: "", save_blocked: false, recovery_input: "", }
}

///|
fn choice_evidence(workspace : DurableResearchWorkspace) -> ChoiceEvidence {
  {
    run_id: workspace.run_id,
    question: workspace.query,
    papers: workspace.papers.unwrap_or([]).copy(),
    summaries: workspace.summaries.unwrap_or([]).copy(),
  }
}

///|
fn new_choice_option(id : String, count : Int) -> ChoiceOption {
  {
    id,
    name: "",
    assessments: Array::make(count, ""),
    source_id: "",
    claim_id: "",
    contradiction: "",
    unknowns: "",
    cost_of_error: "",
    experiment: "",
    retained_source: None,
    retained_claim: None,
    evidence_review_note: None,
  }
}

///|
fn new_choice_sheet(workspace : DurableResearchWorkspace) -> ChoiceWorksheet {
  {
    contract_id: "moonfind.choice-worksheet.v1",
    revision: 1,
    next_option: 3,
    evidence: choice_evidence(workspace),
    question: workspace.query,
    audience: "",
    commitment_ref: "",
    criteria: ["Evidence for the intended outcome"],
    options: [
      new_choice_option("option-1", 1),
      new_choice_option("option-2", 1),
    ],
    chosen_option_id: "",
    reasoning: "",
    next_action: "",
    history: None,
    experiments: None,
  }
}

///|
fn choice_current(
  sheet : ChoiceWorksheet,
  workspace : DurableResearchWorkspace?,
) -> Bool {
  workspace
  .map(value => {
    choice_continuation_issue(sheet, Some(value)) == "" &&
    choice_deltas(sheet, choice_evidence(value)).is_empty()
  })
  .unwrap_or(false)
}

///|
fn choice_claims(sheet : ChoiceWorksheet) -> Array[EvidenceClaim] {
  let result : Array[EvidenceClaim] = []
  for summary in sheet.evidence.summaries {
    for claim in summary.claims {
      if !result.any(value => value.claim_id == claim.claim_id) {
        result.push(claim)
      }
    }
  }
  result
}

///|
fn choice_decode(
  text : String,
  run_id : String,
) -> Result[ChoiceWorksheet, String] {
  if text.length() > 2000000 {
    return Err("Worksheet backup exceeds the 2-million-character limit.")
  }
  let parsed = @json.parse(text) catch {
    _ => return Err("Worksheet backup is not valid JSON.")
  }
  let body = match parsed {
    {
      "contract_id": String("moonfind.decision-brief.v1"),
      "worksheet": value,
      ..
    } => value
    _ => parsed
  }
  let value : ChoiceWorksheet = @json.from_json(body) catch {
    _ =>
      return Err(
        "Worksheet backup is unreadable. Its saved bytes were not replaced.",
      )
  }
  if value.contract_id != "moonfind.choice-worksheet.v1" ||
    value.evidence.run_id != run_id ||
    value.revision < 1 ||
    value.options.length() < 2 ||
    value.options.length() > 4 ||
    value.criteria.is_empty() ||
    value.criteria.length() > 6 ||
    value.next_option < 3 ||
    value.next_option > 1000000 {
    return Err(
      "Worksheet version, run, or bounded shape does not match this workspace.",
    )
  }
  let ids : Array[String] = []
  for option in value.options {
    if option.id.is_blank() ||
      ids.contains(option.id) ||
      option.assessments.length() != value.criteria.length() {
      return Err("Worksheet option identities or criteria are inconsistent.")
    }
    if option.id.has_prefix("option-") {
      let number = @string.parse_int(option.id[7:].to_owned()) catch {
        _ => return Err("Worksheet reserved option identity is invalid.")
      }
      if number < 1 || number >= value.next_option {
        return Err(
          "Worksheet next-option identity must follow every retained option.",
        )
      }
    }
    ids.push(option.id)
  }
  if value.chosen_option_id != "" && !ids.contains(value.chosen_option_id) {
    return Err("Chosen option is not retained in this worksheet.")
  }
  if ids.contains("option-\{value.next_option}") {
    return Err(
      "Worksheet next-option identity collides with a retained option.",
    )
  }
  if value.history.unwrap_or([]).length() > 20 {
    return Err("Worksheet history exceeds the 20-version retention limit.")
  }
  let experiment_issue = choice_experiments_issue(value)
  if experiment_issue != "" {
    return Err(experiment_issue)
  }
  let mut prior_revision = 0
  for archive in value.history.unwrap_or([]) {
    if archive.revision <= prior_revision ||
      archive.revision >= value.revision ||
      archive.evidence.run_id != run_id {
      return Err("Worksheet history is not an earlier revision of this run.")
    }
    prior_revision = archive.revision
    if choice_decode(choice_unarchive(archive).to_json().stringify(), run_id)
      is Err(_) {
      return Err("A retained worksheet version is invalid.")
    }
  }
  Ok(value)
}

///|
// Edits keep source references and stable option IDs intact. No scoring occurs.
fn choice_edit(sheet : ChoiceWorksheet, action : ChoiceMsg) -> ChoiceWorksheet {
  if sheet.revision >= 2147483647 {
    return sheet
  }
  let next = match action {
    SetField(field, text) =>
      match field {
        "question" => { ..sheet, question: text, }
        "audience" => { ..sheet, audience: text, }
        "commitment" => { ..sheet, commitment_ref: text, }
        "chosen" =>
          if text == "" || sheet.options.any(value => value.id == text) {
            { ..sheet, chosen_option_id: text, }
          } else {
            sheet
          }
        "reasoning" => { ..sheet, reasoning: text, }
        "next" => { ..sheet, next_action: text, }
        _ => sheet
      }
    SetCriterion(index, text) =>
      {
        ..sheet,
        criteria: sheet.criteria.mapi((i, value) => {
          if i == index {
            text
          } else {
            value
          }
        }),
      }
    AddCriterion if sheet.criteria.length() < 6 =>
      {
        ..sheet,
        criteria: sheet.criteria + [""],
        options: sheet.options.map(value => {
          ..value,
          assessments: value.assessments + [""],
        }),
      }
    AddOption if sheet.options.length() < 4 && sheet.next_option < 1000000 =>
      {
        ..sheet,
        next_option: sheet.next_option + 1,
        options: sheet.options +
        [
          new_choice_option(
            "option-\{sheet.next_option}",
            sheet.criteria.length(),
          ),
        ],
      }
    RemoveOption(id) if sheet.options.length() > 2 =>
      {
        ..sheet,
        options: sheet.options.filter(value => value.id != id),
        chosen_option_id: if sheet.chosen_option_id == id {
          ""
        } else {
          sheet.chosen_option_id
        },
      }
    SetOption(id, field, text) =>
      {
        ..sheet,
        options: sheet.options.map(value => {
          if value.id != id {
            return value
          }
          match field {
            "name" => { ..value, name: text, }
            "source" => { ..value, source_id: text, retained_source: None, }
            "claim" => { ..value, claim_id: text, retained_claim: None, }
            "contradiction" => { ..value, contradiction: text, }
            "unknowns" => { ..value, unknowns: text, }
            "cost" => { ..value, cost_of_error: text, }
            "experiment" => { ..value, experiment: text, }
            _ => value
          }
        }),
      }
    SetAssessment(id, index, text) =>
      {
        ..sheet,
        options: sheet.options.map(value => {
          if value.id == id {
            {
              ..value,
              assessments: value.assessments.mapi((i, old) => {
                if i == index {
                  text
                } else {
                  old
                }
              }),
            }
          } else {
            value
          }
        }),
      }
    _ => sheet
  }
  if next.to_json() == sheet.to_json() {
    sheet
  } else {
    { ..next, revision: sheet.revision + 1, }
  }
}

///|
fn choice_unknown(text : String) -> String {
  if text.is_blank() {
    "Unknown / not recorded"
  } else {
    text
  }
}

///|
fn choice_source_note(sheet : ChoiceWorksheet, option : ChoiceOption) -> String {
  if option.source_id == "" {
    return "Unknown: no strongest source selected"
  }
  match
    sheet.evidence.papers
    .filter(value => value.paper_id == option.source_id)
    .get(0) {
    Some(source) =>
      source.title +
      " · " +
      source.versioned_id +
      " · " +
      source.source_digest
    None => "Unresolved retained source reference: " + option.source_id
  }
}
