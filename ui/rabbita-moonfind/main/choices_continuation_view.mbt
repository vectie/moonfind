///|
fn choice_continuation_view(
  emit : @rabbita.Emit[Msg],
  sheet : ChoiceWorksheet,
  model : Model,
) -> @rabbita.Html {
  let problem = choice_continuation_issue(sheet, model.workspace)
  let history = sheet.history.unwrap_or([])
  details(
    attrs=@html.Attrs::build().data_set(
      "testid", "choice-evidence-continuation",
    ),
    [
      summary(
        "Compare updated evidence · \{history.length()} earlier versions retained",
      ),
      p(
        "Review the source and claim changes before continuing this decision. This uses the loaded research only; it does not run a provider.",
      ),
      if problem != "" {
        p(class="choice-warning", problem)
      } else {
        let evidence = choice_evidence(model.workspace.unwrap())
        let changes = choice_deltas(sheet, evidence)
        div([
          if changes.is_empty() {
            p("No source, claim or analysis changes to continue.")
          } else {
            div([
              p(
                "\{changes.length()} changed records. Your criteria, assessments, chosen option and next action will be carried forward as your unreviewed work. Changed or removed citations become Unknown, with the exact earlier receipts kept below and in history.",
              ),
              div(
                changes.map(change => {
                  details([
                    summary(
                      change.status + " " + change.kind + " · " + change.id,
                    ),
                    p(
                      "Affected options: " +
                      (if change.affected_options.is_empty() {
                        "None currently cited"
                      } else {
                        change.affected_options.join(", ")
                      }),
                    ),
                    h3("Before"),
                    p(
                      style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
                      change.before,
                    ),
                    h3("Now"),
                    p(
                      style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
                      change.after,
                    ),
                  ])
                }),
              ),
              button(
                disabled=model.choices.save_blocked || history.length() >= 20,
                on_click=emit(
                  EditChoices(
                    ContinueEvidence(
                      sheet.revision,
                      evidence.to_json().stringify(),
                    ),
                  ),
                ),
                "Continue with this evidence",
              ),
            ])
          },
          if history.length() >= 20 {
            p(
              class="choice-warning",
              "The 20-version history is full. Download the complete JSON backup. Continuing is paused; no older version is discarded.",
            )
          } else {
            @html.nothing
          },
        ])
      },
      if !history.is_empty() {
        div([
          h3("Earlier worksheet versions"),
          p(
            "Every earlier source receipt, assessment and choice remains in the JSON backup. Download an individual version to inspect or restore it using the existing backup control.",
          ),
          div(
            history.map(archive => {
              details([
                summary("Revision \{archive.revision} · " + archive.question),
                p("Chosen option: " + choice_unknown(archive.chosen_option_id)),
                p("Reasoning: " + choice_unknown(archive.reasoning)),
                p("Next action: " + choice_unknown(archive.next_action)),
                button(
                  on_click=emit(
                    EditChoices(ExportRevision(archive.revision, "json")),
                  ),
                  "Download revision \{archive.revision} · JSON",
                ),
                button(
                  on_click=emit(
                    EditChoices(ExportRevision(archive.revision, "md")),
                  ),
                  "Download revision \{archive.revision} · Markdown",
                ),
              ])
            }),
          ),
        ])
      } else {
        @html.nothing
      },
    ],
  )
}

///|
fn choice_retained_citations(item : ChoiceOption) -> @rabbita.Html {
  div([
    match item.evidence_review_note {
      Some(note) => p(class="choice-warning", note)
      None => @html.nothing
    },
    match item.retained_source {
      Some(source) =>
        details([
          summary(
            "Historical source · " +
            source.paper_id +
            " · unresolved for this revision",
          ),
          p(
            style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
            choice_paper_receipt(source),
          ),
          evidence_source_link("Open historical source", source.abs_url),
        ])
      None => @html.nothing
    },
    match item.retained_claim {
      Some(claim) =>
        details([
          summary(
            "Historical claim · " +
            claim.claim_id +
            " · unresolved for this revision",
          ),
          p(
            style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
            choice_claim_receipt(claim),
          ),
        ])
      None => @html.nothing
    },
  ])
}
