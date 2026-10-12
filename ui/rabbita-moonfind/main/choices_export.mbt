///|
fn choice_boundary() -> String {
  "User-authored comparison of retained research. No automatic ranking, model-verified recommendation, company decision, customer-demand proof or acceptance is implied. Empty entries mean Unknown / not recorded. Source claims retain their original attribution and uncertainty."
}

///|
fn choice_evidence_status(current : Bool) -> String {
  if current {
    "Matches the currently loaded research projection"
  } else {
    "Historical or unavailable current context: review retained citations before using this brief"
  }
}

///|
fn choice_export_json(sheet : ChoiceWorksheet, current : Bool) -> Json {
  {
    "contract_id": "moonfind.decision-brief.v1",
    "boundary": choice_export_boundary(sheet),
    "evidence_status": choice_evidence_status(current),
    "company_decision_recorded": false,
    "worksheet": sheet.to_json(),
  }
}

///|
fn choice_export_boundary(sheet : ChoiceWorksheet) -> String {
  choice_boundary() +
  (if sheet.history.unwrap_or([]).is_empty() {
    ""
  } else {
    " Continued worksheet: assessments and chosen direction are carried user preferences, not revalidated findings. Changed or removed citations are Unknown in active references; exact earlier receipts and decisions are retained in worksheet history."
  })
}

///|
fn choice_markdown(sheet : ChoiceWorksheet, current : Bool) -> String {
  let out = StringBuilder()
  out.write_string(
    "# Research decision brief\n\n" + choice_export_boundary(sheet) + "\n\n",
  )
  out.write_string(
    "Run: " + sheet.evidence.run_id + "\nRevision: \{sheet.revision}\n\n",
  )
  out.write_string("Evidence: " + choice_evidence_status(current) + "\n\n")
  out.write_string(
    "## Decision question\n\n" + choice_unknown(sheet.question) + "\n\n",
  )
  out.write_string(
    "Audience: " +
    choice_unknown(sheet.audience) +
    "\n\nCommitment reference (user supplied): " +
    choice_unknown(sheet.commitment_ref) +
    "\n\n",
  )
  out.write_string("## User-recorded direction\n\n")
  let chosen = sheet.options
    .filter(value => value.id == sheet.chosen_option_id)
    .get(0)
  out.write_string(
    "Chosen option: " +
    chosen
    .map(value => choice_unknown(value.name) + " (" + value.id + ")")
    .unwrap_or("Undecided") +
    "\n\n",
  )
  out.write_string(
    "Reasoning: " +
    choice_unknown(sheet.reasoning) +
    "\n\nNext action: " +
    choice_unknown(sheet.next_action) +
    "\n\n",
  )
  for option in sheet.options {
    out.write_string(
      "## " + choice_unknown(option.name) + " (" + option.id + ")\n\n",
    )
    for index, criterion in sheet.criteria {
      out.write_string(
        "### Criterion: " +
        choice_unknown(criterion) +
        "\n\nUser assessment: " +
        choice_unknown(option.assessments[index]) +
        "\n\n",
      )
    }
    out.write_string(
      "Strongest source: " + choice_source_note(sheet, option) + "\n\n",
    )
    if option.evidence_review_note is Some(note) {
      out.write_string("Evidence review: " + note + "\n\n")
    }
    if option.retained_source is Some(source) {
      out.write_string(
        "Historical source (unresolved for this revision):\n\n" +
        choice_paper_receipt(source) +
        "\n\n",
      )
    }
    if option.retained_claim is Some(claim) {
      out.write_string(
        "Historical claim (unresolved for this revision):\n\n" +
        choice_claim_receipt(claim) +
        "\n\n",
      )
    }
    if option.claim_id == "" {
      out.write_string("Source claim: Unknown / not selected\n\n")
    } else {
      match
        choice_claims(sheet)
        .filter(value => value.claim_id == option.claim_id)
        .get(0) {
        Some(claim) => {
          out.write_string(
            "Retained analysis claim " +
            claim.claim_id +
            ": " +
            claim.statement +
            "\n\n",
          )
          out.write_string(
            "Source IDs: " +
            claim.paper_ids.join(", ") +
            "\nLocation: " +
            claim.evidence_location +
            "\nReported confidence: " +
            claim.confidence +
            "\nCounterevidence: " +
            choice_unknown(claim.counterevidence) +
            "\n\n",
          )
        }
        None =>
          out.write_string(
            "Unresolved retained claim reference: " + option.claim_id + "\n\n",
          )
      }
    }
    out.write_string(
      "Contradictions: " +
      choice_unknown(option.contradiction) +
      "\n\nUnknowns: " +
      choice_unknown(option.unknowns) +
      "\n\nCost of being wrong: " +
      choice_unknown(option.cost_of_error) +
      "\n\nSmallest falsifying experiment: " +
      choice_unknown(option.experiment) +
      "\n\n",
    )
  }
  for card in sheet.experiments.unwrap_or([]) {
    out.write_string("\n" + experiment_markdown(card) + "\n")
  }
  out.write_string("## Retained source register\n\n")
  for source in sheet.evidence.papers {
    out.write_string(
      "### " +
      source.title +
      "\n\nID: " +
      source.paper_id +
      "\nVersion: " +
      source.versioned_id +
      "\nDigest: " +
      source.source_digest +
      "\nURL: " +
      source.abs_url +
      "\nPublished: " +
      source.published_at.unwrap_or("Unknown") +
      "\nUpdated: " +
      source.updated_at.unwrap_or("Unknown") +
      "\nRetrieved (epoch milliseconds): " +
      source.retrieved_at.map(value => value.to_string()).unwrap_or("Unknown") +
      "\n\nRetained abstract/input text: " +
      source.abstract_text +
      "\n\n",
    )
  }
  out.write_string("## Retained research summaries\n\n")
  for summary in sheet.evidence.summaries {
    out.write_string(
      "Source " +
      summary.paper_id +
      ": " +
      summary.one_sentence +
      "\n\nProblem: " +
      summary.problem +
      "\nMethod: " +
      summary.method +
      "\nEvidence: " +
      summary.evidence +
      "\nLimitations: " +
      summary.limitations.join("; ") +
      "\nOpen questions: " +
      summary.open_questions.join("; ") +
      "\n\n",
    )
    for claim in summary.claims {
      out.write_string(
        "Claim " +
        claim.claim_id +
        ": " +
        claim.statement +
        "\nSource IDs: " +
        claim.paper_ids.join(", ") +
        "\nLocation: " +
        claim.evidence_location +
        "\nReported confidence: " +
        claim.confidence +
        "\nCounterevidence: " +
        choice_unknown(claim.counterevidence) +
        "\n\n",
      )
    }
  }
  out.to_string()
}
