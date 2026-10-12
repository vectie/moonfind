///|
fn reading_notes_panel(
  emit : @rabbita.Emit[Msg],
  view : BriefView,
) -> @rabbita.Html {
  let state = view.reading_notes
  let book = state.notebook
  fn message(action) {
    BriefAction(ReadingNotes(state.key, book.revision, action))
  }
  section(id="browser-reading-notes", [
    h3("Browser-local reading notes"),
    p(
      "Choose New reading note on a reference, then write your own reading notes. Each note retains the exact reference metadata, abstract and full selection capture at that moment. Notes never move to another DOI, slot or record. These are your annotations, not a scientific review or MoonBook memory.",
    ),
    p(
      "Notes autosave only in this browser, separately for each brief ID. Reload restores them here. Native brief Save does not contain notes; reopening that brief on this browser recovers its local notebook. New blank brief starts an isolated notebook and leaves earlier stored notes intact. Use the portable backup below before clearing browser data or moving devices. Shortlist JSON/RIS and current-match exports do not include these notes.",
    ),
    p(state.notice),
    reading_report_panel(emit, view),
    reading_notes_transfer_panel(emit, view),
    if state.saved {
      div("")
    } else {
      p(
        "NOT VERIFIED SAVED: keep this page open and copy your notes before leaving.",
      )
    },
    if state.blocked {
      div([
        action_button("Retry reading saved notes", emit(message(RetryRead))),
        details([
          summary("Unreadable stored bytes retained unchanged"),
          pre(
            style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
            state.unreadable,
          ),
        ]),
      ])
    } else {
      action_button("Retry saving reading notes", emit(message(Save)))
    },
    p(
      "\{book.notes.length()} retained note snapshots. Select a note below to edit its text; source snapshots remain unchanged.",
    ),
    ul(
      reading_report_matches(view).map(note => {
        li([
          strong(
            if note.reference.title.is_blank() {
              "(Untitled reference)"
            } else {
              note.reference.title
            },
          ),
          p(
            "Retained " +
            note.reference.format +
            " · source slot \{note.reference.source_slot} · original record \{note.reference.record_number} · " +
            note.reference.source_name,
          ),
          p(
            if reading_note_current(view, note) {
              "Exact snapshot still attached to this brief."
            } else {
              "Retained snapshot only: sources changed, moved or were removed. This note has not been retargeted."
            },
          ),
          p(
            "Origin: " +
            note.capture.origin +
            " · captured: " +
            note.capture.captured_at,
          ),
          action_button("Edit retained note", emit(message(Select(note.id)))),
          pre(style=["white-space:pre-wrap", "font:inherit"], note.text),
          details([
            summary("Exact retained reference and capture"),
            pre(
              style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
              ToJson::to_json(note.reference).stringify(indent=2),
            ),
            pre(
              style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
              ToJson::to_json(note.capture).stringify(indent=2),
            ),
          ]),
          if state.selected == note.id && !state.blocked && !view.pending {
            field_label(
              "Your reading note · " + note.reference.title,
              textarea(
                value=note.text,
                rows=5,
                attrs=@html.Attrs::build().aria_label("Your reading note"),
                on_input=emit.map(text => message(Write(note.id, text))),
                style=[
                  "width:100%", "box-sizing:border-box", "min-height:100px",
                ],
                "",
              ),
            )
          } else {
            div("")
          },
        ])
      }),
    ),
  ])
}
