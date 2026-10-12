///|
fn json_evidence_cohort_panel(
  emit : @rabbita.Emit[Msg],
  state : JsonEvidenceView,
) -> @rabbita.Html {
  let draft = state.cohort_draft
  details([
    summary("Select a JSON evidence cohort"),
    p(
      "Choose records meeting one or two exact field conditions, such as /site = \"school\" and /interview/outcome = \"unresolved\". The preview covers every source record, including rows hidden by search. It does not judge evidence quality.",
    ),
    field_label(
      "First field pointer",
      text_field(
        draft.first_pointer,
        "/site",
        emit.map(value => BriefAction(JsonEvidence(CohortField(0, value)))),
      ),
    ),
    field_label(
      "First exact scalar JSON value",
      text_field(
        draft.first_value,
        "\"school\"",
        emit.map(value => BriefAction(JsonEvidence(CohortField(1, value)))),
      ),
    ),
    field_label(
      "Combine conditions",
      select(
        on_change=emit.map(value => {
          BriefAction(JsonEvidence(CohortAny(value == "any")))
        }),
        [
          option(value="all", selected=!draft.any, "All conditions must match"),
          option(value="any", selected=draft.any, "Any condition may match"),
        ],
      ),
    ),
    field_label(
      "Second field pointer (optional)",
      text_field(
        draft.second_pointer,
        "/interview/outcome",
        emit.map(value => BriefAction(JsonEvidence(CohortField(2, value)))),
      ),
    ),
    field_label(
      "Second exact scalar JSON value (optional)",
      text_field(
        draft.second_value,
        "\"unresolved\"",
        emit.map(value => BriefAction(JsonEvidence(CohortField(3, value)))),
      ),
    ),
    p(
      "Quote strings; use true, false or null literally. Strings are case-sensitive and untrimmed after decoding JSON escapes. Numbers match exact source spellings: 1, 1.0 and 1e0 are different, as are 0 and -0. No numeric coercion or ranges. Objects and arrays are not scalar conditions.",
    ),
    p(
      "Missing and blocked paths are unknown, never null. All is no-match when one condition fails; Any is match when one condition succeeds. Otherwise a missing or blocked condition leaves the result unresolved. Leave both second-condition inputs empty to use one condition.",
    ),
    action_button(
      "Preview JSON cohort",
      emit(BriefAction(JsonEvidence(PreviewCohort))),
    ),
    match state.cohort {
      None =>
        p(
          "Preview before replacing selection. Editing a condition clears the preview but keeps your existing selections.",
        )
      Some(cohort) =>
        div(style=["display:grid", "gap:8px"], [
          p(
            "Mode: " +
            cohort.mode +
            " · \{cohort.total} source records · \{cohort.matched.length()} matching · \{cohort.excluded.length()} no-match · \{cohort.unresolved.length()} unresolved",
          ),
          div(
            cohort.conditions.mapi((index, condition) => {
              p(
                "Condition \{index + 1}: " +
                condition.pointer +
                " equals " +
                condition.value,
              )
            }),
          ),
          action_button(
            "Replace selection with matching cohort (\{cohort.matched.length()})",
            emit(BriefAction(JsonEvidence(SelectCohort("match")))),
          ),
          action_button(
            "Replace selection with unresolved records (\{cohort.unresolved.length()})",
            emit(BriefAction(JsonEvidence(SelectCohort("unresolved")))),
          ),
          p(
            "Replacing selection clears search. A zero-count choice clears the selection. Use the existing JSON extract, NDJSON or Add selected JSON records to brief actions below; every original field is included. Keep the original dossier for provenance and review private fields before sharing.",
          ),
          div(style=["overflow:auto", "max-height:400px"], [
            @html.table(style=["border-collapse:collapse", "width:100%"], [
              @html.thead([
                @html.tr([
                  @html.th("Source record"),
                  @html.th("Cohort result"),
                  @html.th("Exact condition evidence"),
                ]),
              ]),
              @html.tbody(
                cohort.rows.map(row => {
                  @html.tr([
                    @html.td(
                      "\{row.record_number} · " +
                      (if row.source_line > 0 {
                        "source line \{row.source_line}"
                      } else {
                        row.record_pointer
                      }),
                    ),
                    @html.td(row.status),
                    @html.td(
                      row.values.mapi((value_index, value) => {
                        div([
                          p(
                            "Condition \{value_index + 1} · " +
                            row.results[value_index] +
                            " · requested " +
                            value.value_pointer,
                          ),
                          pre(
                            style=[
                              "white-space:pre-wrap", "overflow-wrap:anywhere",
                            ],
                            if value.kind == "missing" ||
                              value.kind == "blocked" {
                              "(" +
                              value.kind +
                              "; requested pointer does not resolve)"
                            } else {
                              value.raw
                            },
                          ),
                        ])
                      }),
                    ),
                  ])
                }),
              ),
            ]),
          ]),
        ])
    },
  ])
}
