///|
// A non-recursive complete earlier worksheet. History never silently evicts it.
struct ChoiceArchive {
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
  experiments : Array[ChoiceExperiment]?
} derive(Debug, ToJson, FromJson)

///|
fn choice_archive(sheet : ChoiceWorksheet) -> ChoiceArchive {
  {
    revision: sheet.revision,
    next_option: sheet.next_option,
    evidence: sheet.evidence,
    question: sheet.question,
    audience: sheet.audience,
    commitment_ref: sheet.commitment_ref,
    criteria: sheet.criteria,
    options: sheet.options,
    chosen_option_id: sheet.chosen_option_id,
    reasoning: sheet.reasoning,
    next_action: sheet.next_action,
    experiments: sheet.experiments,
  }
}

///|
fn choice_unarchive(archive : ChoiceArchive) -> ChoiceWorksheet {
  {
    contract_id: "moonfind.choice-worksheet.v1",
    revision: archive.revision,
    next_option: archive.next_option,
    evidence: archive.evidence,
    question: archive.question,
    audience: archive.audience,
    commitment_ref: archive.commitment_ref,
    criteria: archive.criteria,
    options: archive.options,
    chosen_option_id: archive.chosen_option_id,
    reasoning: archive.reasoning,
    next_action: archive.next_action,
    history: None,
    experiments: archive.experiments,
  }
}

///|
fn choice_version(
  sheet : ChoiceWorksheet,
  archive : ChoiceArchive,
) -> ChoiceWorksheet {
  let earlier = sheet.history
    .unwrap_or([])
    .filter(value => value.revision < archive.revision)
  {
    ..choice_unarchive(archive),
    history: if earlier.is_empty() {
      None
    } else {
      Some(earlier)
    },
  }
}

///|
struct ChoiceDelta {
  kind : String
  id : String
  status : String
  before : String
  after : String
  affected_options : Array[String]
} derive(Debug, ToJson)

///|
extend EvidencePaper with ToJson::{to_json}

///|
extend EvidenceClaim with ToJson::{to_json}

///|
extend EvidenceSummary with ToJson::{to_json}

///|
fn choice_paper_receipt(paper : EvidencePaper) -> String {
  paper.title +
  "\nID: " +
  paper.paper_id +
  "\nVersion: " +
  paper.versioned_id +
  "\nDigest: " +
  paper.source_digest +
  "\nPublished: " +
  paper.published_at.unwrap_or("Unknown") +
  "\nUpdated: " +
  paper.updated_at.unwrap_or("Unknown") +
  "\nRetrieved (epoch ms): " +
  paper.retrieved_at.map(value => value.to_string()).unwrap_or("Unknown") +
  "\nSource: " +
  paper.abs_url +
  "\nAbstract: " +
  paper.abstract_text
}

///|
fn choice_same_source_content(
  before : EvidencePaper,
  after : EvidencePaper,
) -> Bool {
  { ..before, retrieved_at: None, }.to_json() ==
  { ..after, retrieved_at: None, }.to_json()
}

///|
fn choice_claim_receipt(claim : EvidenceClaim) -> String {
  claim.statement +
  "\nSources: " +
  claim.paper_ids.join(", ") +
  "\nLocation: " +
  claim.evidence_location +
  "\nReported confidence: " +
  claim.confidence +
  "\nCounterevidence: " +
  choice_unknown(claim.counterevidence)
}

///|
fn choice_evidence_issue(evidence : ChoiceEvidence) -> String {
  let papers : Array[String] = []
  for paper in evidence.papers {
    if paper.paper_id.is_blank() ||
      papers.contains(paper.paper_id) ||
      paper.versioned_id.is_blank() ||
      paper.source_digest.is_blank() {
      return "Source identities or digest receipts are missing or duplicated."
    }
    papers.push(paper.paper_id)
  }
  let claims : Map[String, EvidenceClaim] = Map([])
  let summaries : Array[String] = []
  for summary in evidence.summaries {
    if !papers.contains(summary.paper_id) ||
      summaries.contains(summary.paper_id) {
      return "Research summaries have missing or duplicate source identities."
    }
    summaries.push(summary.paper_id)
    for claim in summary.claims {
      if claim.claim_id.is_blank() ||
        !claim.paper_ids.all(id => papers.contains(id)) {
        return "A claim has a missing identity or unresolved source."
      }
      if claims.get(claim.claim_id) is Some(old) &&
        old.to_json() != claim.to_json() {
        return "Different claims reuse the same identity."
      }
      claims[claim.claim_id] = claim
    }
  }
  ""
}

///|
fn choice_continuation_issue(
  sheet : ChoiceWorksheet,
  workspace : DurableResearchWorkspace?,
) -> String {
  guard workspace is Some(current) else {
    return "Load the current research workspace to compare evidence."
  }
  if current.run_id != sheet.evidence.run_id {
    return "This worksheet belongs to a different research run."
  }
  if current.papers is None || current.summaries is None {
    return "Current evidence is unavailable. Missing projection data is not a removal."
  }
  if !current.validation_issues.is_empty() {
    return "The current research projection has unresolved validation issues."
  }
  let problem = choice_evidence_issue(choice_evidence(current))
  if problem != "" {
    return problem
  }
  let old_problem = choice_evidence_issue(sheet.evidence)
  if old_problem != "" {
    return "Retained evidence cannot be compared safely: " + old_problem
  }
  ""
}

///|
fn choice_deltas(
  sheet : ChoiceWorksheet,
  current : ChoiceEvidence,
) -> Array[ChoiceDelta] {
  let changes : Array[ChoiceDelta] = []
  for old in sheet.evidence.papers {
    let now = current.papers
      .filter(value => value.paper_id == old.paper_id)
      .get(0)
    if now.map(value => value.to_json() == old.to_json()).unwrap_or(false) {
      continue
    }
    changes.push({
      kind: "Source",
      id: old.paper_id,
      status: match now {
        Some(value) =>
          if choice_same_source_content(old, value) {
            "Retrieval refreshed"
          } else {
            "Changed"
          }
        None => "Removed"
      },
      before: choice_paper_receipt(old),
      after: now
      .map(choice_paper_receipt)
      .unwrap_or("Not in the current projection"),
      affected_options: sheet.options
      .filter(value => {
        value.source_id == old.paper_id ||
        choice_claims(sheet).any(claim => {
          claim.claim_id == value.claim_id &&
          claim.paper_ids.contains(old.paper_id)
        })
      })
      .map(value => value.id),
    })
  }
  for now in current.papers {
    if !sheet.evidence.papers.any(value => value.paper_id == now.paper_id) {
      changes.push({
        kind: "Source",
        id: now.paper_id,
        status: "Added",
        before: "Not in the retained projection",
        after: choice_paper_receipt(now),
        affected_options: [],
      })
    }
  }
  let prior_claims = choice_claims(sheet)
  let current_sheet = { ..sheet, evidence: current, }
  let current_claims = choice_claims(current_sheet)
  for old in prior_claims {
    let now = current_claims
      .filter(value => value.claim_id == old.claim_id)
      .get(0)
    if now.map(value => value.to_json() == old.to_json()).unwrap_or(false) {
      continue
    }
    changes.push({
      kind: "Claim",
      id: old.claim_id,
      status: if now is Some(_) {
        "Changed"
      } else {
        "Removed"
      },
      before: choice_claim_receipt(old),
      after: now
      .map(choice_claim_receipt)
      .unwrap_or("Not in the current projection"),
      affected_options: sheet.options
      .filter(value => value.claim_id == old.claim_id)
      .map(value => value.id),
    })
  }
  for now in current_claims {
    if !prior_claims.any(value => value.claim_id == now.claim_id) {
      changes.push({
        kind: "Claim",
        id: now.claim_id,
        status: "Added",
        before: "Not in the retained projection",
        after: choice_claim_receipt(now),
        affected_options: [],
      })
    }
  }
  for old in sheet.evidence.summaries {
    let now = current.summaries
      .filter(value => value.paper_id == old.paper_id)
      .get(0)
    if now.map(value => value.to_json() == old.to_json()).unwrap_or(false) {
      continue
    }
    changes.push({
      kind: "Analysis",
      id: old.paper_id,
      status: if now is Some(_) {
        "Changed"
      } else {
        "Removed"
      },
      before: old.to_json().stringify(indent=2),
      after: now
      .map(value => value.to_json().stringify(indent=2))
      .unwrap_or("Not in the current projection"),
      affected_options: sheet.options
      .filter(value => value.source_id == old.paper_id)
      .map(value => value.id),
    })
  }
  for now in current.summaries {
    if !sheet.evidence.summaries.any(value => value.paper_id == now.paper_id) {
      changes.push({
        kind: "Analysis",
        id: now.paper_id,
        status: "Added",
        before: "Not in the retained projection",
        after: now.to_json().stringify(indent=2),
        affected_options: [],
      })
    }
  }
  if current.question != sheet.evidence.question {
    changes.push({
      kind: "Research question",
      id: current.run_id,
      status: "Changed",
      before: sheet.evidence.question,
      after: current.question,
      affected_options: sheet.options.map(value => value.id),
    })
  }
  changes
}

///|
fn choice_continue(
  sheet : ChoiceWorksheet,
  workspace : DurableResearchWorkspace?,
) -> Result[ChoiceWorksheet, String] {
  let problem = choice_continuation_issue(sheet, workspace)
  if problem != "" {
    return Err(problem)
  }
  let evidence = choice_evidence(workspace.unwrap())
  let changes = choice_deltas(sheet, evidence)
  if changes.is_empty() {
    return Ok(sheet)
  }
  if sheet.revision >= 2147483647 {
    return Err(
      "The revision counter is exhausted. Download the existing worksheet; it has not been changed.",
    )
  }
  let history = sheet.history.unwrap_or([])
  if history.length() >= 20 {
    return Err(
      "All 20 earlier versions are retained. Download this complete backup; continuation is paused rather than discarding history.",
    )
  }
  let changed_sources = changes
    .filter(value => {
      value.kind == "Source" &&
      (value.status == "Changed" || value.status == "Removed")
    })
    .map(value => value.id)
  let changed_claims = changes
    .filter(value => value.kind == "Claim" && value.status != "Added")
    .map(value => value.id)
  let previous_claims = choice_claims(sheet)
  let next = {
    ..sheet,
    revision: sheet.revision + 1,
    evidence,
    history: Some(history + [choice_archive(sheet)]),
    options: sheet.options.map(option => {
      let old_source = sheet.evidence.papers
        .filter(value => value.paper_id == option.source_id)
        .get(0)
      let old_claim = previous_claims
        .filter(value => value.claim_id == option.claim_id)
        .get(0)
      let source_changed = changed_sources.contains(option.source_id) ||
        (option.source_id != "" && old_source is None)
      let claim_changed = changed_claims.contains(option.claim_id) ||
        (option.claim_id != "" && old_claim is None) ||
        old_claim
        .map(claim => claim.paper_ids.any(id => changed_sources.contains(id)))
        .unwrap_or(false)
      {
        ..option,
        source_id: if source_changed {
          ""
        } else {
          option.source_id
        },
        claim_id: if claim_changed {
          ""
        } else {
          option.claim_id
        },
        retained_source: if source_changed {
          old_source
        } else {
          option.retained_source
        },
        retained_claim: if claim_changed {
          old_claim
        } else {
          option.retained_claim
        },
        evidence_review_note: Some(
          "Carried forward from revision \{sheet.revision}. Your assessment and chosen direction have not been revalidated. Changed or removed citations are historical; choose current citations after reviewing the evidence." +
          (if source_changed {
            " Previous unresolved source ID: " + option.source_id + "."
          } else {
            ""
          }) +
          (if claim_changed {
            " Previous unresolved claim ID: " + option.claim_id + "."
          } else {
            ""
          }),
        ),
      }
    }),
  }
  if choice_export_json(next, false).stringify(indent=2).length() + 1 > 2000000 {
    return Err(
      "Retaining this version would exceed the backup size limit. Download the existing complete history; no version was removed.",
    )
  }
  Ok(next)
}
