///|
fn reading_report_panel(
  emit : @rabbita.Emit[Msg],
  view : BriefView,
) -> @rabbita.Html {
  let state = view.reading_notes
  fn message(action) {
    BriefAction(ReadingNotes(state.key, state.notebook.revision, action))
  }
  section(id="annotated-reading-report", [
    h3("Find notes and make an annotated reading report"),
    p(
      "Search your handwritten notes and retained reference metadata, abstracts and origins. The matching notes below and Markdown report use this scope, independently of bibliography filters and the shortlist. Filters are temporary and are not stored in the JSON backup.",
    ),
    if view.pending || state.blocked {
      p("Wait for a readable notebook before searching or downloading notes.")
    } else {
      div([
        field_label(
          "Search reading notes",
          input(
            value=state.report_query,
            attrs=@html.Attrs::build().aria_label("Search reading notes"),
            on_input=emit.map(query => message(ReportQuery(query))),
          ),
        ),
        field_label(
          "Reading-note snapshot scope",
          select(on_change=emit.map(scope => message(ReportScope(scope))), [
            option(
              value="all",
              selected=state.report_scope == "all",
              "All retained notes",
            ),
            option(
              value="attached",
              selected=state.report_scope == "attached",
              "Attached to this brief",
            ),
            option(
              value="detached",
              selected=state.report_scope == "detached",
              "Detached retained snapshots",
            ),
          ]),
        ),
        action_button("Clear note filters", emit(message(ClearReport))),
        p(
          "\{reading_report_matches(view).length()} matching of \{state.notebook.notes.length()} retained notes. Notebook order is preserved.",
        ),
        try {
          let content = reading_report_markdown(view)
          div([
            details([
              summary("Preview annotated reading report"),
              pre(
                style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
                content,
              ),
            ]),
            action_button(
              "Download annotated reading report Markdown",
              emit(message(ExportReport)),
            ),
          ])
        } catch {
          error => p("\{error}")
        },
        p(
          "The report includes matching handwritten text, supplied abstracts and provenance, including unsaved edits. It omits original source bodies and full capture bytes. Review private text before sharing. Downloading does not save notes or the native brief; use JSON backup for restoration.",
        ),
      ])
    },
  ])
}
