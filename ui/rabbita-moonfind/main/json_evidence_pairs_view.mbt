///|
fn json_evidence_pairs_panel(
  emit : @rabbita.Emit[Msg],
  state : JsonEvidenceView,
) -> @rabbita.Html {
  details([
    summary("Compare observed JSON value pairs"),
    p(
      "Discover which values occur together, such as site and interview outcome, without entering expected values. This counts every source record, including records hidden by search or not selected. It does not compare separate sources or judge evidence quality.",
    ),
    field_label(
      "First comparison field pointer",
      text_field(
        state.pair_first_pointer,
        "/site",
        emit.map(value => BriefAction(JsonEvidence(PairPointer(0, value)))),
      ),
    ),
    field_label(
      "Second comparison field pointer",
      text_field(
        state.pair_second_pointer,
        "/interview/outcome",
        emit.map(value => BriefAction(JsonEvidence(PairPointer(1, value)))),
      ),
    ),
    action_button(
      "Preview observed value pairs",
      emit(BriefAction(JsonEvidence(PreviewPairs))),
    ),
    p(
      "Strings group by exact decoded text, including case and whitespace. Numbers group by exact source spelling: 1, 1.0 and 1e0 differ. Null, missing and blocked paths remain separate. Objects and arrays form non-scalar groups by kind only; their contents are not compared.",
    ),
    match state.pairs {
      None =>
        p(
          "Choose two different field pointers and preview. Editing either pointer clears the breakdown and keeps your existing selection.",
        )
      Some(pairs) =>
        div(style=["display:grid", "gap:8px"], [
          p(
            "\{pairs.total} source records · \{pairs.groups.length()} observed pairs · \{pairs.scalar_count} with two scalar/null values · \{pairs.gap_count} with absent, blocked or non-scalar fields",
          ),
          p(
            "Pairs appear in first-observed order. Counts describe this capture only; there is no sampling, statistical inference, causal claim or automatic recommendation. Unobserved combinations are not fabricated.",
          ),
          div(style=["overflow:auto", "max-height:440px"], [
            @html.table(style=["border-collapse:collapse", "width:100%"], [
              @html.thead([
                @html.tr([
                  @html.th(pairs.first_pointer),
                  @html.th(pairs.second_pointer),
                  @html.th("Records"),
                  @html.th("Source evidence and selection"),
                ]),
              ]),
              @html.tbody(
                pairs.groups.map(group => {
                  @html.tr([
                    @html.td([
                      p(group.first.kind),
                      pre(
                        style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
                        group.first.display,
                      ),
                    ]),
                    @html.td([
                      p(group.second.kind),
                      pre(
                        style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
                        group.second.display,
                      ),
                    ]),
                    @html.td("\{group.count} / \{pairs.total}"),
                    @html.td([
                      p(
                        if group.scalar {
                          "Observed scalar/null pair"
                        } else {
                          "Contains an absent, blocked or non-scalar field"
                        },
                      ),
                      action_button(
                        "Replace selection with pair \{group.pair_number} (\{group.count} records)",
                        emit(
                          BriefAction(
                            JsonEvidence(SelectPair(group.pair_number)),
                          ),
                        ),
                      ),
                      details([
                        summary("Inspect exact source values and locators"),
                        div(
                          group.rows.map(row => {
                            div([
                              p(
                                "Record \{row.record_number} · " +
                                (if row.source_line > 0 {
                                  "source line \{row.source_line}"
                                } else {
                                  row.record_pointer
                                }),
                              ),
                              div(
                                row.values.map(value => {
                                  div([
                                    p(value.value_pointer + " · " + value.kind),
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
                }),
              ),
            ]),
          ]),
          p(
            "Selecting a pair replaces the entire selection and clears search. Use Preview selected JSON extract, raw NDJSON or Add selected JSON records to brief below. Every original field is included. The full original remains in the dossier; review private fields before sharing.",
          ),
        ])
    },
  ])
}
