///|
fn experiment_markdown(card : ChoiceExperiment) -> String {
  let out = StringBuilder()
  out.write_string(
    "# Source-bound experiment " +
    card.id +
    "\n\n" +
    experiment_boundary() +
    "\n\n",
  )
  out.write_string(
    "Contract: " +
    card.contract_id +
    "\nResearch run: " +
    card.origin_evidence.run_id +
    "\nCreated worksheet revision: \{card.created_revision}\n\n",
  )
  out.write_string(
    "Plan status: " +
    card.prepared_revision
    .map(value => "Frozen at revision \{value}")
    .unwrap_or("DRAFT / not ready to execute") +
    "\n\n",
  )
  out.write_string(
    "## Original context\n\nQuestion: " +
    choice_unknown(card.origin_question) +
    "\n\nOption: " +
    card.origin_option.id +
    " · " +
    card.origin_option.name +
    "\n\n",
  )
  for i, criterion in card.origin_criteria {
    out.write_string(
      "Criterion: " +
      choice_unknown(criterion) +
      "\nAssessment: " +
      choice_unknown(card.origin_option.assessments[i]) +
      "\n\n",
    )
  }
  out.write_string(
    "Original contradiction: " +
    choice_unknown(card.origin_option.contradiction) +
    "\nOriginal unknowns: " +
    choice_unknown(card.origin_option.unknowns) +
    "\nCost of error: " +
    choice_unknown(card.origin_option.cost_of_error) +
    "\nOriginal experiment note: " +
    choice_unknown(card.origin_option.experiment) +
    "\n\n",
  )
  if experiment_source(card) is Some(source) {
    out.write_string(
      "### Original source receipt\n\n" + choice_paper_receipt(source) + "\n\n",
    )
  }
  for summary in card.origin_evidence.summaries {
    for claim in summary.claims {
      if claim.claim_id == card.origin_option.claim_id {
        out.write_string(
          "### Original selected claim\n\n" +
          choice_claim_receipt(claim) +
          "\n\n",
        )
      }
    }
  }
  for
    (label_, value) in [
      ("Hypothesis", card.hypothesis),
      ("Procedure", card.procedure),
      ("Measurable outcome and units", card.measurable_outcome),
      ("Disconfirming threshold", card.disconfirming_threshold),
      ("Constraints and stop conditions", card.constraints),
    ] {
    out.write_string("## " + label_ + "\n\n" + choice_unknown(value) + "\n\n")
  }
  match card.observation {
    None =>
      out.write_string(
        "## Observations\n\nNot recorded. Any draft notes below are unsubmitted user entries, not results.\n\nDraft status: " +
        card.observation_status +
        "\nDraft measurement: " +
        choice_unknown(card.observation_measurement) +
        "\nDraft notes: " +
        choice_unknown(card.observation_notes) +
        "\n\n",
      )
    Some(report) =>
      out.write_string(
        "## Explicitly user-reported observations\n\nRecorded worksheet revision: \{report.recorded_revision}\nMeasurement status: " +
        report.status +
        "\nMeasurement: " +
        choice_unknown(report.measurement) +
        "\nNotes, gaps and limitations: " +
        report.notes +
        "\n\nThese observations are not independently verified; no success/failure conclusion was computed.\n\n",
      )
  }
  match card.decision {
    None =>
      out.write_string(
        "## Choice revision\n\nNot applied. No direction was changed by this test card.\n\n",
      )
    Some(decision) =>
      out.write_string(
        "## Explicit user choice revision\n\nRecorded worksheet revision: \{decision.recorded_revision}\nPrevious option: " +
        choice_unknown(decision.before_option_id) +
        "\nPrevious reasoning: " +
        choice_unknown(decision.before_reasoning) +
        "\nPrevious next action: " +
        choice_unknown(decision.before_next_action) +
        "\n\nChosen option: " +
        choice_unknown(decision.chosen_option_id) +
        "\nReasoning: " +
        decision.reasoning +
        "\nNext action: " +
        decision.next_action +
        "\n\nThis is a historical user-recorded revision; later worksheet edits may differ.\n\n",
      )
  }
  out.write_string(
    "Use the versioned JSON worksheet backup to restore the full original evidence, drafts and history.\n",
  )
  out.to_string()
}
