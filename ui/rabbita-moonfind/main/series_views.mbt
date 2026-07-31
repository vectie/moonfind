///|
fn selected_series(model : Model) -> SeriesUseCaseProjection? {
  model.series_catalog
  .filter(item => item.use_case_id == model.selected_series_id)
  .get(0)
}

///|
fn series_exclusion_label(exclusion : SeriesExclusionProjection) -> String {
  match exclusion.product_id {
    Some(value) => value
    None => exclusion.capability.unwrap_or("Unspecified capability")
  }
}

///|
fn series_is_inspected(model : Model, series_id : String) -> Bool {
  model.inspected_series
  .map(item => item.use_case_id == series_id)
  .unwrap_or(false)
}

///|
fn render_series_catalog(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  section(
    class="series-catalog",
    attrs=@html.Attrs::build()
      .aria_label("MoonSuite scenario templates")
      .data_set("testid", "series-catalog"),
    [
      div(class="series-heading", [
        div(class="series-title", [
          research_icon("habitat", size=24),
          div([small("SERIES TEMPLATE"), h2("Choose a cross-product outcome")]),
        ]),
        if model.series_catalog.is_empty() {
          button(
            class="series-retry",
            on_click=emit(RefreshSeriesCatalog),
            attrs=@html.Attrs::build().aria_label("Reload series templates"),
            [research_icon("refresh"), span("Reload")],
          )
        } else {
          select(
            on_change=emit.map(value => SelectSeries(value)),
            attrs=@html.Attrs::build().aria_label("Scenario template"),
            model.series_catalog.map(item => {
              option(
                value=item.use_case_id,
                selected=item.use_case_id == model.selected_series_id,
                item.title,
              )
            }),
          )
        },
      ]),
      match model.series_error {
        Some(error) =>
          div(
            class="series-error",
            attrs=@html.Attrs::build().role("status").aria_live("polite"),
            error,
          )
        None => @html.nothing
      },
      match selected_series(model) {
        None =>
          p(
            class="series-empty",
            "No validated scenario is available from the MoonFind host.",
          )
        Some(series) =>
          div(class="series-content", [
            div(class="series-summary", [
              div([
                strong(series.title),
                p(series.summary),
                small(
                  class="series-counts",
                  "\{series.phases.length()} phases · \{series.graph.stages.length()} desired stages",
                ),
              ]),
              div(class="series-boundary", [
                small("PRIMARY USER"),
                strong(series.primary_user),
                small(
                  "Catalog-shape validation only · execution commissioning is still pending",
                ),
              ]),
            ]),
            div(
              class="series-phases",
              series.phases.mapi((index, phase) => {
                let selected = phase.phase_id == model.selected_series_phase_id
                button(
                  class=if selected {
                    "series-phase selected"
                  } else {
                    "series-phase"
                  },
                  on_click=emit(SelectSeriesPhase(phase.phase_id)),
                  title=phase.product_ids.join(" · "),
                  attrs=@html.Attrs::build()
                    .aria_label(
                      "Phase \{index + 1}: \{phase.title}. \{phase.outcome}. Products: \{phase.product_ids.join(", ")}",
                    )
                    .aria_current(if selected { "step" } else { "false" }),
                  [
                    span(class="series-phase-icon", [
                      research_icon(
                        if phase.phase_id == "model" {
                          "habitat"
                        } else {
                          "series"
                        },
                      ),
                    ]),
                    div(class="series-phase-title", [
                      small("\{index + 1}"),
                      strong(phase.title),
                    ]),
                    p(phase.outcome),
                    div(
                      class="series-products",
                      phase.product_ids.map(product => span(product)),
                    ),
                    small(
                      class="series-stage-count",
                      "\{phase.stage_ids.length()} desired stages",
                    ),
                  ],
                )
              }),
            ),
            details(class="series-limits", [
              summary([research_icon("shield"), span("Limits & evidence")]),
              div(class="series-limits-content", [
                div(class="series-contract-facts", [
                  span([small("CONTRACT"), code(series.contract_id)]),
                  span([small("GRAPH"), code(series.graph.graph_id)]),
                  span([
                    small("COMPLETION"),
                    strong(series.completion_statement),
                  ]),
                ]),
                ul(
                  class="series-exclusions",
                  series.graph.intentional_exclusions
                  .unwrap_or([])
                  .map(exclusion => {
                    li([
                      strong(series_exclusion_label(exclusion)),
                      span(exclusion.reason),
                    ])
                  }),
                ),
                p(
                  class="series-evidence-boundary",
                  "This catalog proves a versioned desired graph exists. Its intake-and-seed operation is intentionally unpublished, so real capability projection must block there. It does not prove providers are healthy, authority is granted, evidence has been produced, or a run has executed.",
                ),
              ]),
            ]),
            div(class="series-primary-action", [
              div([
                small("SERIES GOAL"),
                strong(series.primary_action),
                p(
                  "Read-only catalog-shape validation. This does not create or execute a run.",
                ),
              ]),
              button(
                class="series-inspect",
                disabled=model.series_action_loading,
                on_click=emit(ValidateSeriesTemplate),
                attrs=@html.Attrs::build().aria_label(
                  if model.series_action_loading {
                    "Validating series template"
                  } else {
                    "Validate template"
                  },
                ),
                [
                  research_icon(
                    if model.series_action_loading {
                      "refresh"
                    } else {
                      "inspect"
                    },
                  ),
                  span(
                    if model.series_action_loading {
                      "Validating…"
                    } else {
                      "Validate template"
                    },
                  ),
                ],
              ),
            ]),
            match model.series_action_status {
              Some(status) =>
                div(
                  class="series-action-status",
                  attrs=@html.Attrs::build().role("status").aria_live("polite"),
                  [
                    research_icon("check"),
                    div([strong("Template shape validated"), p(status)]),
                  ],
                )
              None => @html.nothing
            },
            if series_is_inspected(model, series.use_case_id) {
              div(class="series-recovery", [
                div([
                  small("NEXT CONTROLLED STEP"),
                  strong("Open MoonDesk with this series context"),
                  p(
                    "The link carries the selected series and phase only. MoonDesk does not yet import it as a run; capability and semantic projection remain mandatory before MoonFlow can execute any stage.",
                  ),
                ]),
                a(
                  class="research-next",
                  href=moondesk_series_url(
                    series.use_case_id,
                    model.selected_series_phase_id,
                  ),
                  [research_icon("arrow"), span("Open MoonDesk canvas")],
                ),
              ])
            } else {
              @html.nothing
            },
            div(class="series-footer", [
              code(series.use_case_id),
              small(
                "No physical command, publication, or commercial-master authority is implied.",
              ),
            ]),
          ])
      },
    ],
  )
}
