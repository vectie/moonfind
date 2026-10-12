///|
fn reading_notes_transfer_panel(
  emit : @rabbita.Emit[Msg],
  view : BriefView,
) -> @rabbita.Html {
  let state = view.reading_notes
  fn message(action) {
    BriefAction(ReadingNotes(state.key, state.notebook.revision, action))
  }
  if state.blocked || view.pending {
    return div("")
  }
  details([
    summary("Portable reading-note backup and import"),
    p(
      "Download a backup before moving browsers or clearing data. It contains this brief ID, exact note IDs, private handwritten text and full retained source captures, including detached notes and unsaved edits. Review before sharing; no server upload is performed.",
    ),
    action_button(
      "Download reading notes JSON backup",
      emit(message(ExportBackup)),
    ),
    p(
      "To restore on another browser, first open the same saved brief, then choose the downloaded JSON file below, or paste its contents. Preview shows the merge before confirmation. Existing notes are never overwritten; conflicting IDs refuse the whole import. Sources are not added to the brief. Changed source lists leave new notes detached.",
    ),
    action_button(
      "Choose reading-note backup JSON file",
      emit(message(ChooseBackup)),
    ),
    p("Current brief ID: " + state.notebook.brief_id),
    field_label(
      "Paste reading-note backup JSON (maximum 1 MiB)",
      textarea(
        value=state.import_text,
        rows=5,
        attrs=@html.Attrs::build().aria_label("Reading-note backup JSON"),
        on_input=emit.map(text => message(ImportText(text))),
        style=["width:100%", "box-sizing:border-box"],
        "",
      ),
    ),
    action_button("Preview reading-note import", emit(message(PreviewImport))),
    action_button("Cancel reading-note import", emit(message(CancelImport))),
    match state.import_preview {
      None => div("")
      Some(preview) =>
        div([
          p(
            "Preview: \{preview.added} new notes, \{preview.skipped} identical existing notes skipped, \{preview.detached} new notes detached. Nothing has been imported yet.",
          ),
          ul(
            preview.notebook.notes
            .filter(note => {
              !state.notebook.notes.any(retained => retained.id == note.id)
            })
            .map(note => {
              li([
                strong(note.reference.title),
                p("Note ID: " + note.id),
                p(
                  if note.attached {
                    "Exact source list retained"
                  } else {
                    "Detached retained snapshot"
                  },
                ),
                pre(
                  style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
                  note.text,
                ),
                details([
                  summary("Reference and full capture to import"),
                  pre(
                    style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
                    ToJson::to_json(note.reference).stringify(indent=2),
                  ),
                  pre(
                    style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
                    ToJson::to_json(note.capture).stringify(indent=2),
                  ),
                ]),
              ])
            }),
          ),
          action_button(
            "Confirm reading-note merge",
            emit(message(ConfirmImport(state.import_text))),
          ),
        ])
    },
  ])
}
