///|
fn choice_input(
  emit : @rabbita.Emit[Msg],
  label_text : String,
  value_ : String,
  action : (String) -> ChoiceMsg,
) -> @rabbita.Html {
  field_label(
    label_text,
    textarea(
      value=value_,
      rows=2,
      placeholder="Unknown / not recorded",
      attrs=@html.Attrs::build().aria_label(label_text),
      on_input=emit.map(value => EditChoices(action(value))),
      style=[
        "width:100%", "box-sizing:border-box", "resize:vertical", "min-height:44px",
        "font:inherit", "padding:10px", "color:#edf5ff", "background:#07101f", "border:1px solid #314563",
        "border-radius:8px",
      ],
      "",
    ),
  )
}

///|
fn choice_option_view(
  emit : @rabbita.Emit[Msg],
  sheet : ChoiceWorksheet,
  item : ChoiceOption,
  workspace : DurableResearchWorkspace?,
) -> @rabbita.Html {
  let sources = [
    option(
      value="",
      selected=item.source_id == "",
      "Unknown / no source selected",
    ),
  ]
  if item.source_id != "" &&
    !sheet.evidence.papers.any(source => source.paper_id == item.source_id) {
    sources.push(
      option(
        value=item.source_id,
        selected=true,
        "Unresolved: " + item.source_id,
      ),
    )
  }
  for source in sheet.evidence.papers {
    sources.push(
      option(
        value=source.paper_id,
        selected=item.source_id == source.paper_id,
        source.title + " · " + source.versioned_id,
      ),
    )
  }
  let claims = [
    option(
      value="",
      selected=item.claim_id == "",
      "Unknown / no claim selected",
    ),
  ]
  if item.claim_id != "" &&
    !choice_claims(sheet).any(claim => claim.claim_id == item.claim_id) {
    claims.push(
      option(value=item.claim_id, selected=true, "Unresolved: " + item.claim_id),
    )
  }
  for claim in choice_claims(sheet) {
    claims.push(
      option(
        value=claim.claim_id,
        selected=item.claim_id == claim.claim_id,
        claim.claim_id + " · " + claim.statement,
      ),
    )
  }
  let source = sheet.evidence.papers
    .filter(value => value.paper_id == item.source_id)
    .get(0)
  let source_current = source
    .map(old => {
      workspace
      .map(ws => {
        ws.papers.unwrap_or([]).any(now => choice_same_source_content(old, now))
      })
      .unwrap_or(false)
    })
    .unwrap_or(false)
  article(class="choice-option", [
    h3(item.id),
    choice_retained_citations(item),
    choice_input(emit, "Option name · " + item.id, item.name, value => {
      SetOption(item.id, "name", value)
    }),
    div(
      sheet.criteria.mapi((index, criterion) => {
        choice_input(
          emit,
          "Assessment · " + choice_unknown(criterion) + " · " + item.id,
          item.assessments[index],
          value => SetAssessment(item.id, index, value),
        )
      }),
    ),
    details([
      summary("Sources, uncertainty and experiment"),
      p(
        "Choose retained evidence. Your assessments are user-authored; a selected source does not verify the interpretation.",
      ),
      field_label(
        "Strongest source · " + item.id,
        select(
          attrs=@html.Attrs::build().aria_label(
            "Strongest source · " + item.id,
          ),
          on_change=emit.map(value => {
            EditChoices(SetOption(item.id, "source", value))
          }),
          sources,
        ),
      ),
      p(choice_source_note(sheet, item)),
      match source {
        Some(value) =>
          div([
            evidence_source_link("Open retained source", value.abs_url),
            p(
              "Published: " +
              value.published_at.unwrap_or("Unknown") +
              " · Updated: " +
              value.updated_at.unwrap_or("Unknown"),
            ),
            p(
              "Retrieved (epoch milliseconds): " +
              value.retrieved_at
              .map(time => time.to_string())
              .unwrap_or("Unknown"),
            ),
            if source_current {
              small(
                "Source content matches the current projection; retrieval receipts may differ",
              )
            } else {
              p(
                class="choice-warning",
                "This cited source is changed, removed or unavailable in the current projection. Its original record is retained.",
              )
            },
          ])
        None => @html.nothing
      },
      field_label(
        "Retained analysis claim · " + item.id,
        select(
          attrs=@html.Attrs::build().aria_label(
            "Retained analysis claim · " + item.id,
          ),
          on_change=emit.map(value => {
            EditChoices(SetOption(item.id, "claim", value))
          }),
          claims,
        ),
      ),
      match
        choice_claims(sheet)
        .filter(value => value.claim_id == item.claim_id)
        .get(0) {
        Some(claim) =>
          div([
            p(claim.statement),
            evidence_citations(claim.paper_ids, sheet.evidence.papers),
            p("Location: " + claim.evidence_location),
            p("Reported confidence: " + claim.confidence),
            p(
              "Source counterevidence: " + choice_unknown(claim.counterevidence),
            ),
          ])
        None => @html.nothing
      },
      choice_input(emit, "Contradiction · " + item.id, item.contradiction, value => {
        SetOption(item.id, "contradiction", value)
      }),
      choice_input(emit, "Unknowns · " + item.id, item.unknowns, value => {
        SetOption(item.id, "unknowns", value)
      }),
      choice_input(
        emit,
        "Cost of being wrong · " + item.id,
        item.cost_of_error,
        value => SetOption(item.id, "cost", value),
      ),
      choice_input(
        emit,
        "Smallest falsifying experiment · " + item.id,
        item.experiment,
        value => SetOption(item.id, "experiment", value),
      ),
    ]),
    if sheet.options.length() > 2 {
      button(
        on_click=emit(EditChoices(RemoveOption(item.id))),
        "Remove " + item.id,
      )
    } else {
      @html.nothing
    },
  ])
}

///|
fn choices_panel(emit : @rabbita.Emit[Msg], model : Model) -> @rabbita.Html {
  let state = model.choices
  section(
    class="choice-panel",
    attrs=@html.Attrs::build().data_set("testid", "evidence-choice-worksheet"),
    [
      h2("Compare choices and decide the next test"),
      p(
        "Put 2–4 alternatives against the same criteria, inspect the evidence, and download an actionable decision brief.",
      ),
      match state.sheet {
        None =>
          p(
            "Load a research workspace to start a browser-local comparison. No provider is needed.",
          )
        Some(sheet) => {
          let selected = [
            option(value="", selected=sheet.chosen_option_id == "", "Undecided"),
          ]
          for item in sheet.options {
            selected.push(
              option(
                value=item.id,
                selected=sheet.chosen_option_id == item.id,
                choice_unknown(item.name) + " · " + item.id,
              ),
            )
          }
          div([
            p(class="choice-boundary", choice_boundary()),
            p(
              class=if choice_current(sheet, model.workspace) {
                "choice-context"
              } else {
                "choice-warning"
              },
              choice_evidence_status(choice_current(sheet, model.workspace)),
            ),
            choice_input(emit, "Decision question", sheet.question, value => {
              SetField("question", value)
            }),
            choice_continuation_view(emit, sheet, model),
            details([
              summary("Audience and MoonProj reference (optional)"),
              choice_input(emit, "Audience", sheet.audience, value => {
                SetField("audience", value)
              }),
              choice_input(
                emit,
                "MoonProj commitment reference",
                sheet.commitment_ref,
                value => SetField("commitment", value),
              ),
              small(
                "The reference is included in your downloaded brief. No MoonProj task is created or changed.",
              ),
            ]),
            h3("Shared comparison criteria"),
            div(
              sheet.criteria.mapi((index, criterion) => {
                choice_input(emit, "Criterion \{index + 1}", criterion, value => {
                  SetCriterion(index, value)
                })
              }),
            ),
            button(
              disabled=sheet.criteria.length() >= 6,
              on_click=emit(EditChoices(AddCriterion)),
              "Add criterion",
            ),
            div(
              class="choice-options",
              sheet.options.map(item => {
                choice_option_view(emit, sheet, item, model.workspace)
              }),
            ),
            button(
              disabled=sheet.options.length() >= 4 ||
                sheet.next_option >= 1000000,
              on_click=emit(EditChoices(AddOption)),
              "Add alternative",
            ),
            h3("Your direction and next action"),
            field_label(
              "Chosen option (optional)",
              select(
                attrs=@html.Attrs::build().aria_label(
                  "Chosen option (optional)",
                ),
                on_change=emit.map(value => {
                  EditChoices(SetField("chosen", value))
                }),
                selected,
              ),
            ),
            choice_input(emit, "Why this option?", sheet.reasoning, value => {
              SetField("reasoning", value)
            }),
            choice_input(emit, "Next action", sheet.next_action, value => {
              SetField("next", value)
            }),
            experiments_panel(emit, model, sheet),
            div(class="choice-actions", [
              button(on_click=emit(EditChoices(Save)), "Save in this browser"),
              button(
                on_click=emit(EditChoices(Export("md"))),
                "Download decision brief · Markdown",
              ),
              button(
                on_click=emit(EditChoices(Export("json"))),
                "Download JSON brief / backup",
              ),
            ]),
            p(
              attrs=@html.Attrs::build().role("status").aria_live("polite"),
              state.notice,
            ),
            details([
              summary("Restore a worksheet backup"),
              p(
                "Download the current draft first if you want to keep it. Paste a JSON brief or worksheet from this same run. Restore explicitly replaces only this browser-local draft; source changes remain marked historical.",
              ),
              choice_input(
                emit,
                "Worksheet JSON backup",
                state.recovery_input,
                value => SetRecovery(value),
              ),
              button(
                on_click=emit(EditChoices(Restore)),
                "Restore this local draft",
              ),
            ]),
          ])
        }
      },
    ],
  )
}
