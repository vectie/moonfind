///|
fn experiment_action(
  model : Model,
  sheet : ChoiceWorksheet,
  action : ExperimentMsg,
) -> ChoiceMsg {
  Experiment(
    model.choices.key,
    sheet.revision,
    model.workspace
    .map(value => choice_evidence(value).to_json().stringify())
    .unwrap_or(""),
    sheet.to_json().stringify(),
    action,
  )
}

///|
fn experiment_field(
  emit : @rabbita.Emit[Msg],
  model : Model,
  sheet : ChoiceWorksheet,
  card : ChoiceExperiment,
  label_ : String,
  field : String,
  value : String,
  frozen : Bool,
) -> @rabbita.Html {
  if frozen {
    div([@html.h4(label_ + " · " + card.id), p(choice_unknown(value))])
  } else {
    choice_input(emit, label_ + " · " + card.id, value, text => {
      experiment_action(model, sheet, Edit(card.id, field, text))
    })
  }
}

///|
fn experiment_card_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
  sheet : ChoiceWorksheet,
  card : ChoiceExperiment,
) -> @rabbita.Html {
  let prepared = card.prepared_revision is Some(_)
  let reported = card.observation is Some(_)
  let decided = card.decision is Some(_)
  let status_options = ["unknown", "incomplete", "measured"].map(value => {
    option(value~, selected=card.observation_status == value, value)
  })
  let choices = [
    option(value="", selected=card.revision_option_id == "", "Undecided"),
  ]
  for item in sheet.options {
    choices.push(
      option(
        value=item.id,
        selected=card.revision_option_id == item.id,
        choice_unknown(item.name) + " · " + item.id,
      ),
    )
  }
  if card.revision_option_id != "" &&
    !sheet.options.any(item => item.id == card.revision_option_id) {
    choices.push(
      option(
        value=card.revision_option_id,
        selected=true,
        "Removed option: " + card.revision_option_id,
      ),
    )
  }
  article(
    class="choice-option",
    attrs=@html.Attrs::build().data_set("testid", card.id),
    [
      h3(card.id + " · " + card.origin_option.name),
      p(
        if decided {
          "Explicit choice revision retained"
        } else if reported {
          "User-reported observations retained; choice unchanged until you apply a revision"
        } else if prepared {
          "Frozen plan; waiting for your observations"
        } else {
          "Draft plan; incomplete fields remain unknown"
        },
      ),
      p(
        class="choice-warning",
        experiment_context(card, sheet, model.workspace),
      ),
      details([
        summary("Original option and source snapshot · " + card.id),
        p(
          "Research run: " +
          card.origin_evidence.run_id +
          " · Created at worksheet revision \{card.created_revision}",
        ),
        p("Original question: " + choice_unknown(card.origin_question)),
        p(
          "Original option: " +
          card.origin_option.id +
          " · " +
          card.origin_option.name,
        ),
        p(
          "Original uncertainty: " + choice_unknown(card.origin_option.unknowns),
        ),
        match experiment_source(card) {
          Some(source) =>
            div([
              pre(choice_paper_receipt(source)),
              evidence_source_link("Open original source", source.abs_url),
            ])
          None => p("Original source is unavailable")
        },
        p(
          "All original criteria, assessments, source receipts and claims are retained in the JSON backup.",
        ),
      ]),
      experiment_field(
        emit,
        model,
        sheet,
        card,
        "Hypothesis",
        "hypothesis",
        card.hypothesis,
        prepared,
      ),
      experiment_field(
        emit,
        model,
        sheet,
        card,
        "Procedure",
        "procedure",
        card.procedure,
        prepared,
      ),
      experiment_field(
        emit,
        model,
        sheet,
        card,
        "Measurable outcome and units",
        "outcome",
        card.measurable_outcome,
        prepared,
      ),
      experiment_field(
        emit,
        model,
        sheet,
        card,
        "Disconfirming threshold",
        "threshold",
        card.disconfirming_threshold,
        prepared,
      ),
      experiment_field(
        emit,
        model,
        sheet,
        card,
        "Constraints and stop conditions",
        "constraints",
        card.constraints,
        prepared,
      ),
      if !prepared {
        div([
          p(
            "Complete all five fields, then freeze the plan before reporting results. Use explicit Unknown or None statements where appropriate; these remain your assertions.",
          ),
          button(
            on_click=emit(
              EditChoices(experiment_action(model, sheet, Prepare(card.id))),
            ),
            "Freeze test plan · " + card.id,
          ),
        ])
      } else {
        @html.nothing
      },
      button(
        on_click=emit(
          EditChoices(experiment_action(model, sheet, Download(card.id))),
        ),
        "Download test plan · " + card.id,
      ),
      if prepared {
        div([
          @html.h4("Your observations · " + card.id),
          p(
            "Enter results you report yourself after conducting the test outside MoonFind. Unknown and incomplete measurements are never treated as a failed or passed hypothesis.",
          ),
          if reported {
            p("User-reported measurement status: " + card.observation_status)
          } else {
            field_label(
              "Measurement status · " + card.id,
              select(
                attrs=@html.Attrs::build().aria_label(
                  "Measurement status · " + card.id,
                ),
                on_change=emit.map(value => {
                  EditChoices(
                    experiment_action(
                      model,
                      sheet,
                      Edit(card.id, "status", value),
                    ),
                  )
                }),
                status_options,
              ),
            )
          },
          experiment_field(
            emit,
            model,
            sheet,
            card,
            "Observed measurement and units",
            "measurement",
            card.observation_measurement,
            reported,
          ),
          experiment_field(
            emit,
            model,
            sheet,
            card,
            "Observation notes, gaps and limitations",
            "notes",
            card.observation_notes,
            reported,
          ),
          if !reported {
            button(
              on_click=emit(
                EditChoices(experiment_action(model, sheet, Record(card.id))),
              ),
              "Record my reported observations · " + card.id,
            )
          } else {
            @html.nothing
          },
        ])
      } else {
        @html.nothing
      },
      if reported {
        div([
          @html.h4("Explicitly revise your choice · " + card.id),
          p(
            "Review the original source, measurement status and current alternatives. Only Apply updates the local chosen direction, reasoning and next action. The previous worksheet is retained as a version.",
          ),
          if decided {
            p(
              "Recorded chosen option: " +
              choice_unknown(card.revision_option_id),
            )
          } else {
            field_label(
              "Revised chosen option · " + card.id,
              select(
                attrs=@html.Attrs::build().aria_label(
                  "Revised chosen option · " + card.id,
                ),
                on_change=emit.map(value => {
                  EditChoices(
                    experiment_action(
                      model,
                      sheet,
                      Edit(card.id, "chosen", value),
                    ),
                  )
                }),
                choices,
              ),
            )
          },
          experiment_field(
            emit,
            model,
            sheet,
            card,
            "Revision reasoning and remaining uncertainty",
            "reasoning",
            card.revision_reasoning,
            decided,
          ),
          experiment_field(
            emit,
            model,
            sheet,
            card,
            "Revised next action",
            "next",
            card.revision_next_action,
            decided,
          ),
          if !decided {
            button(
              on_click=emit(
                EditChoices(experiment_action(model, sheet, Revise(card.id))),
              ),
              "Apply my choice revision · " + card.id,
            )
          } else {
            @html.nothing
          },
        ])
      } else {
        @html.nothing
      },
    ],
  )
}

///|
fn experiments_panel(
  emit : @rabbita.Emit[Msg],
  model : Model,
  sheet : ChoiceWorksheet,
) -> @rabbita.Html {
  let cards = sheet.experiments.unwrap_or([])
  section(
    attrs=@html.Attrs::build().data_set("testid", "source-bound-experiments"),
    [
      h3("Plan a source-bound test"),
      p(experiment_boundary()),
      p(
        "Choose an existing option to capture its original assessment and source. Each new test is separate; editing an option later never rewrites an earlier card.",
      ),
      if cards.is_empty() {
        p(
          "No test cards yet. Name an option and select its strongest source, then start its test card.",
        )
      } else {
        @html.nothing
      },
      div(
        sheet.options.map(item => {
          button(
            disabled=cards.length() >= 12,
            on_click=emit(
              EditChoices(experiment_action(model, sheet, Start(item.id))),
            ),
            "Start test card · " + item.id,
          )
        }),
      ),
      p(
        "\{cards.length()}/12 test cards retained. Drafts autosave with this worksheet; JSON backups include every test and earlier worksheet version.",
      ),
      div(cards.map(card => experiment_card_view(emit, model, sheet, card))),
    ],
  )
}
