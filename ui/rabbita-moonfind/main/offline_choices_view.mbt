///|
fn offline_source_text(citation : OfflineCitation) -> String {
  "Brief: " +
  citation.brief_id +
  "\nSaved revision: " +
  citation.revision_id +
  "\nSlot: \{citation.source.slot}\nFilename: " +
  citation.source.name +
  "\nOrigin (user supplied): " +
  citation.source.origin +
  "\nCaptured: " +
  citation.source.captured_at +
  "\nKind: " +
  citation.source.kind +
  "\nAvailability: " +
  citation.source.availability +
  "\nRecorded source digest (native receipt or user-supplied import; not recomputed here): " +
  citation.source.digest +
  "\nBytes: \{citation.source.byte_count}\nArchive member: " +
  citation.source.archive_path +
  "\n\nRetained capture text (not independently verified):\n" +
  brief_source_preview(citation.capture.content_hex)
}

///|
fn offline_version_markdown(value : OfflineVersion) -> String {
  let text = StringBuilder()
  text.write_string(
    "## Worksheet revision \{value.revision}\n\nSaved brief: " +
    value.basis.brief.brief_id +
    "\nSource revision: " +
    value.basis.revision_id +
    "\n\n",
  )
  text.write_string(
    "Prepared-brief contract: " +
    value.basis.brief.contract_id +
    "\nParent saved revision: " +
    value.basis.brief.parent_revision.unwrap_or("None / original capture") +
    "\nSnapshot contract: " +
    value.basis.contract_id +
    "\n\n",
  )
  text.write_string(
    "Decision question: " +
    choice_unknown(value.question) +
    "\n\nAudience: " +
    choice_unknown(value.audience) +
    "\n\nUser-supplied commitment reference: " +
    choice_unknown(value.commitment_ref) +
    "\n\n",
  )
  text.write_string(
    "Chosen option: " +
    choice_unknown(value.chosen_option_id) +
    "\n\nRationale: " +
    choice_unknown(value.reasoning) +
    "\n\nNext action: " +
    choice_unknown(value.next_action) +
    "\n\n",
  )
  for item in value.options {
    text.write_string(
      "### Option " + item.id + ": " + choice_unknown(item.name) + "\n\n",
    )
    for i, criterion in value.criteria {
      text.write_string(
        "Criterion: " +
        choice_unknown(criterion) +
        "\nUser assessment: " +
        choice_unknown(item.assessments[i]) +
        "\n\n",
      )
    }
    text.write_string(
      "Strongest retained source: " + choice_unknown(item.source_slot) + "\n\n",
    )
    if offline_citation(value.basis, item.source_slot) is Some(source) {
      text.write_string(offline_source_text(source) + "\n\n")
    }
    if item.historical_source is Some(source) {
      text.write_string(
        "Historical citation, unresolved in this revision:\n" +
        offline_source_text(source) +
        "\n\n",
      )
    }
    for
      (label_, entry) in [
        ("Contradictions", item.contradiction),
        ("Unknowns", item.unknowns),
        ("Cost of error", item.cost_of_error),
        (
          "Smallest next experiment (user-authored, unexecuted)",
          item.experiment,
        ),
      ] {
      text.write_string(label_ + ": " + choice_unknown(entry) + "\n\n")
    }
  }
  text.write_string(
    "### Complete saved preparation basis\n\nResearch question: " +
    value.basis.brief.question +
    "\n\nObjective: " +
    value.basis.brief.objective +
    "\n\nAudience: " +
    value.basis.brief.audience +
    "\n\nDecision: " +
    value.basis.brief.decision +
    "\n\nSource restrictions: " +
    value.basis.brief.source_restrictions +
    "\n\nRequested files (not generated): " +
    value.basis.brief.requested_filenames.join(", ") +
    "\n\nAcceptance criteria (not approved): " +
    value.basis.brief.acceptance_criteria +
    "\n\n" +
    value.basis.boundary +
    "\n\n",
  )
  for source in value.basis.sources {
    if offline_citation(value.basis, "source-\{source.slot}") is Some(citation) {
      text.write_string(
        "### Retained source \{source.slot}\n\n" +
        offline_source_text(citation) +
        "\n\n",
      )
    }
  }
  text.to_string()
}

///|
fn offline_markdown(sheet : OfflineWorksheet, current : Bool) -> String {
  let text = StringBuilder()
  text.write_string(
    "# Offline decision brief\n\n" +
    offline_boundary() +
    "\n\n" +
    (if current {
      "The complete basis matches the currently loaded native prepared snapshot."
    } else {
      "Historical or unavailable native context. Retained and restored copies do not independently prove the host still has these bytes."
    }) +
    "\n\n",
  )
  text.write_string(offline_version_markdown(sheet.current))
  if !sheet.history.is_empty() {
    text.write_string(
      "# Complete retained earlier versions\n\nAssessments and chosen directions are historical user entries, not revalidated findings.\n\n",
    )
    for version in sheet.history {
      text.write_string(offline_version_markdown(version))
    }
  }
  text.write_string(
    "Use the companion versioned JSON backup to restore exact bytes, stable option IDs and full retained history. No research-run or MoonProj-import contract is claimed.\n",
  )
  text.to_string()
}

///|
fn offline_option_view(
  emit : @rabbita.Emit[Msg],
  value : OfflineVersion,
  item : OfflineOption,
) -> @rabbita.Html {
  let options = [
    option(
      value="",
      selected=item.source_slot == "",
      "Unknown / no source selected",
    ),
  ]
  for source in value.basis.sources {
    options.push(
      option(
        value="source-\{source.slot}",
        selected=item.source_slot == "source-\{source.slot}",
        "Slot \{source.slot}: " + source.name + " · " + source.digest,
      ),
    )
  }
  article(class="choice-option", [
    h3(item.id),
    choice_input(emit, "Offline option name · " + item.id, item.name, text => {
      SetOption(item.id, "name", text)
    }),
    div(
      value.criteria.mapi((i, criterion) => {
        choice_input(
          emit,
          "Offline assessment · " +
          choice_unknown(criterion) +
          " · " +
          item.id,
          item.assessments[i],
          text => SetAssessment(item.id, i, text),
        )
      }),
    ),
    field_label(
      "Strongest local capture · " + item.id,
      select(
        attrs=@html.Attrs::build().aria_label(
          "Strongest local capture · " + item.id,
        ),
        on_change=emit.map(text => {
          EditChoices(SetOption(item.id, "source", text))
        }),
        options,
      ),
    ),
    match offline_citation(value.basis, item.source_slot) {
      Some(source) =>
        details([
          summary("Inspect exact selected capture"),
          pre(
            style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
            offline_source_text(source),
          ),
        ])
      None =>
        p(
          "Unknown: no strongest source selected. No favorable score is inferred.",
        )
    },
    match item.historical_source {
      Some(source) =>
        details([
          summary("Historical source: changed or removed; unresolved now"),
          pre(
            style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
            offline_source_text(source),
          ),
        ])
      None => @html.nothing
    },
    choice_input(
      emit,
      "Offline contradictions · " + item.id,
      item.contradiction,
      text => SetOption(item.id, "contradiction", text),
    ),
    choice_input(emit, "Offline unknowns · " + item.id, item.unknowns, text => {
      SetOption(item.id, "unknowns", text)
    }),
    choice_input(
      emit,
      "Offline cost of error · " + item.id,
      item.cost_of_error,
      text => SetOption(item.id, "cost", text),
    ),
    choice_input(
      emit,
      "Smallest next experiment · " + item.id,
      item.experiment,
      text => SetOption(item.id, "experiment", text),
    ),
    if value.options.length() > 2 {
      button(
        on_click=emit(EditChoices(RemoveOption(item.id))),
        "Remove offline " + item.id,
      )
    } else {
      @html.nothing
    },
  ])
}

///|
fn offline_choices_panel(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let state = model.offline_choices
  let basis = offline_open_basis(model)
  section(id="offline-choice-worksheet", class="choice-panel", [
    h2("Compare choices from a saved offline brief"),
    p(offline_boundary()),
    p(
      "Local save scope: this browser origin and brief ID. Workspaces served from the same origin with the same ID share a local comparison; its exact retained basis stays visible and never silently changes.",
    ),
    match basis {
      None =>
        p(
          "Save or reopen a complete prepared brief above to start or continue. Unsaved edits and incomplete native snapshots cannot become an evidence basis.",
        )
      Some(saved) =>
        div([
          p(
            "Opened native basis: " +
            saved.brief.brief_id +
            " / " +
            saved.revision_id,
          ),
          button(
            on_click=emit(
              OfflineChoices(OpenOffline(saved.to_json().stringify())),
            ),
            "Open saved comparison or start from this revision",
          ),
        ])
    },
    p(
      attrs=@html.Attrs::build().role("status").aria_live("polite"),
      state.notice,
    ),
    match state.sheet {
      None => @html.nothing
      Some(sheet) => {
        let value = sheet.current
        let keyed_emit : @rabbita.Emit[Msg] = msg => {
          match msg {
            EditChoices(action) =>
              emit(
                OfflineChoices(
                  EditOffline(
                    state.key,
                    value.revision,
                    model.offline_generation,
                    action,
                  ),
                ),
              )
            _ => @rabbita.none
          }
        }
        let selected = [
          option(value="", selected=value.chosen_option_id == "", "Undecided"),
        ]
        for item in value.options {
          selected.push(
            option(
              value=item.id,
              selected=value.chosen_option_id == item.id,
              item.id + " · " + choice_unknown(item.name),
            ),
          )
        }
        div([
          p(
            "Worksheet revision \{value.revision} · retained basis: " +
            value.basis.brief.brief_id +
            " / " +
            value.basis.revision_id,
          ),
          p(
            class="choice-context",
            if offline_current(model, sheet) {
              "Complete retained basis matches the currently loaded native prepared revision."
            } else {
              "Historical or unavailable current native basis. This worksheet retains its original sources; opening another brief never silently rebinds it."
            },
          ),
          match basis {
            Some(next) if next.brief.brief_id == value.basis.brief.brief_id &&
              next.to_json() != value.basis.to_json() =>
              details(open=true, [
                summary(
                  "Compare with the opened saved revision before continuing",
                ),
                p(
                  "Opened revision: " +
                  next.revision_id +
                  ". Existing assessments and direction will be carried as user entries, not revalidated. Changed or removed source citations become unresolved; the complete earlier version stays in history.",
                ),
                p(
                  "Prepared question: " +
                  value.basis.brief.question +
                  " → " +
                  next.brief.question,
                ),
                p(
                  "Prepared decision: " +
                  value.basis.brief.decision +
                  " → " +
                  next.brief.decision,
                ),
                p(
                  "Prepared objective: " +
                  value.basis.brief.objective +
                  " → " +
                  next.brief.objective,
                ),
                ul(
                  value.basis.sources.map(old => {
                    let now = next.sources
                      .filter(source => source.slot == old.slot)
                      .get(0)
                    li(
                      "Slot \{old.slot} · " +
                      old.name +
                      " · " +
                      old.digest +
                      " · " +
                      old.origin +
                      " · " +
                      old.captured_at +
                      " → " +
                      now
                      .map(source => {
                        source.name +
                        " · " +
                        source.digest +
                        " · " +
                        source.origin +
                        " · " +
                        source.captured_at
                      })
                      .unwrap_or("Removed"),
                    )
                  }),
                ),
                ul(
                  next.sources
                  .filter(source => {
                    !value.basis.sources.any(old => old.slot == source.slot)
                  })
                  .map(source => {
                    li(
                      "Added slot \{source.slot} · " +
                      source.name +
                      " · " +
                      source.digest,
                    )
                  }),
                ),
                button(
                  on_click=emit(
                    OfflineChoices(
                      ContinueOffline(
                        state.key,
                        value.revision,
                        model.offline_generation,
                        next.to_json().stringify(),
                      ),
                    ),
                  ),
                  "Continue explicitly with this saved basis",
                ),
              ])
            _ => @html.nothing
          },
          choice_input(
            keyed_emit,
            "Offline decision question",
            value.question,
            text => SetField("question", text),
          ),
          choice_input(keyed_emit, "Offline audience", value.audience, text => {
            SetField("audience", text)
          }),
          choice_input(
            keyed_emit,
            "Optional commitment reference (text only; no import)",
            value.commitment_ref,
            text => SetField("commitment", text),
          ),
          h3("Shared comparison criteria"),
          div(
            value.criteria.mapi((i, criterion) => {
              choice_input(
                keyed_emit,
                "Offline criterion \{i + 1}",
                criterion,
                text => SetCriterion(i, text),
              )
            }),
          ),
          button(
            disabled=value.criteria.length() >= 6,
            on_click=keyed_emit(EditChoices(AddCriterion)),
            "Add offline criterion",
          ),
          div(
            class="choice-options",
            value.options.map(item => {
              offline_option_view(keyed_emit, value, item)
            }),
          ),
          button(
            disabled=value.options.length() >= 4,
            on_click=keyed_emit(EditChoices(AddOption)),
            "Add offline alternative",
          ),
          field_label(
            "Your offline direction (optional)",
            select(
              on_change=keyed_emit.map(text => {
                EditChoices(SetField("chosen", text))
              }),
              selected,
            ),
          ),
          choice_input(keyed_emit, "Offline rationale", value.reasoning, text => {
            SetField("reasoning", text)
          }),
          choice_input(keyed_emit, "Offline next action", value.next_action, text => {
            SetField("next", text)
          }),
          button(
            on_click=keyed_emit(EditChoices(Save)),
            "Retry saving offline worksheet",
          ),
          button(
            on_click=keyed_emit(EditChoices(Export("md"))),
            "Download complete offline brief · Markdown",
          ),
          button(
            on_click=keyed_emit(EditChoices(Export("json"))),
            "Download complete offline JSON / backup",
          ),
          details([
            summary("Inspect full retained source dossier"),
            div(
              value.basis.sources.map(source => {
                details([
                  summary("Slot \{source.slot}: " + source.name),
                  pre(
                    style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
                    offline_source_text(
                      offline_citation(value.basis, "source-\{source.slot}").unwrap(),
                    ),
                  ),
                ])
              }),
            ),
          ]),
          details([
            summary(
              "Retained earlier worksheet versions (\{sheet.history.length()})",
            ),
            ul(
              sheet.history.map(old => {
                li([
                  p("Worksheet \{old.revision} · " + old.basis.revision_id),
                  button(
                    on_click=keyed_emit(
                      EditChoices(ExportRevision(old.revision, "json")),
                    ),
                    "Download earlier JSON \{old.revision}",
                  ),
                  button(
                    on_click=keyed_emit(
                      EditChoices(ExportRevision(old.revision, "md")),
                    ),
                    "Download earlier Markdown \{old.revision}",
                  ),
                ])
              }),
            ),
          ]),
          details([
            summary("Copy export text or restore an offline backup"),
            p(
              "Back up first. Restore explicitly replaces this browser-local comparison for the same brief, including its history. Imported source copies do not independently verify native retention. Research-run worksheet formats are not accepted here.",
            ),
            choice_input(
              keyed_emit,
              "Offline JSON backup / export text",
              state.recovery,
              text => SetRecovery(text),
            ),
            button(
              on_click=keyed_emit(EditChoices(Restore)),
              "Restore this offline comparison",
            ),
          ]),
        ])
      }
    },
  ])
}
