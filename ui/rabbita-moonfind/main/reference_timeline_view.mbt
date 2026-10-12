///|
fn reference_timeline_panel(
  emit : @rabbita.Emit[Msg],
  view : BriefView,
  catalog : ReferenceCatalog,
) -> @rabbita.Html {
  let timeline = view.reference_timeline
  let search_matches = reference_search_matches(view, catalog)
  let known = search_matches
    .filter(r => reference_publication_year(r.issued) is Some(_))
    .length()
  let unknown = search_matches.length() - known
  div(style=["display:grid", "gap:10px"], [
    strong("Explore publication years"),
    p(
      "Before date filtering: \{known} references with recognized years and \{unknown} with unclassified dates among the current text/DOI matches. Supplied dates are metadata, not verified publication dates.",
    ),
    field_label(
      "Publication date scope",
      select(
        on_change=emit.map(value => {
          BriefAction(ReferenceList(Timeline(Scope(value))))
        }),
        [
          ("all", "All retained dates"),
          ("years", "Recognized publication years"),
          ("unclassified", "Unclassified dates only"),
        ].map(item => {
          let (value, label) = item
          option(value~, selected=timeline.scope == value, label)
        }),
      ),
    ),
    if timeline.scope == "years" {
      div([
        field_label(
          "From year (inclusive)",
          text_field(
            timeline.from_year,
            "Any earlier year",
            emit.map(value => BriefAction(ReferenceList(Timeline(From(value))))),
          ),
        ),
        field_label(
          "Through year (inclusive)",
          text_field(
            timeline.through_year,
            "Any later year",
            emit.map(value => {
              BriefAction(ReferenceList(Timeline(Through(value))))
            }),
          ),
        ),
        p(
          "Use four-digit years; a blank bound is open-ended. Unclassified dates are excluded from this scope.",
        ),
      ])
    } else {
      div("")
    },
    field_label(
      "Reading-list order",
      select(
        on_change=emit.map(value => {
          BriefAction(ReferenceList(Timeline(Order(value))))
        }),
        [
          ("source", "Original source order"),
          ("newest", "Newest publication year first"),
          ("oldest", "Oldest publication year first"),
        ].map(item => {
          let (value, label) = item
          option(value~, selected=timeline.order == value, label)
        }),
      ),
    ),
    match reference_timeline_problem(timeline) {
      Some(problem) => p(style=["color:#fca5a5"], problem)
      None => div("")
    },
    p(
      "Recognized: one valid numeric YYYY, YYYY-M or YYYY-M-D date. Blank, literal, uncertain and range dates remain unclassified. In year order they follow dated references; ties keep original source order. Current-match JSON/RIS/CSL downloads follow this view. Shortlist choices retain selection order.",
    ),
  ])
}
