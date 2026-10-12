///|
fn reference_shortlist_panel(
  emit : @rabbita.Emit[Msg],
  view : BriefView,
  catalog : ReferenceCatalog,
) -> @rabbita.Html {
  let visible = reference_matches(view, catalog)
  let unavailable = view.reference_shortlist
    .filter(c => !reference_choice_current(view, catalog, c))
    .length()
  let hidden = view.reference_shortlist
    .filter(c => {
      reference_choice_current(view, catalog, c) &&
      !visible.contains(c.reference)
    })
    .length()
  section(id="reference-shortlist", [
    h3("Your reference shortlist"),
    p(
      "Choose individual cards across searches and DOI groups. Current-match downloads below remain separate from selected-reference downloads.",
    ),
    p(
      "\{view.reference_shortlist.length()} chosen · \{hidden} hidden by filters · \{unavailable} unavailable after source changes",
    ),
    p(
      "Temporary, session-only choices: reload, successful reopen or New blank brief clears the shortlist. Saving a brief does not save these choices. Appending sources keeps choices; removing or replacing sources marks all existing choices unavailable. Remove them and choose again. Download before leaving.",
    ),
    ul(
      view.reference_shortlist.map(c => {
        li([
          strong(
            if c.reference.title.is_blank() {
              "(Untitled reference)"
            } else {
              c.reference.title
            },
          ),
          p(
            "Source slot \{c.reference.source_slot} · " +
            c.reference.source_name +
            " · " +
            c.reference.format +
            " · original record \{c.reference.record_number}",
          ),
          p(
            if reference_choice_current(view, catalog, c) {
              "Selected"
            } else {
              "Unavailable: source changed or moved. Remove and reselect."
            },
          ),
          details([
            summary("Selected provenance"),
            p("Source digest (as recorded): " + c.reference.source_digest),
            p("Capture origin: " + c.capture.origin),
            p("Captured at: " + c.capture.captured_at),
          ]),
          if view.pending {
            div("")
          } else {
            action_button(
              "Remove this choice",
              emit(BriefAction(ReferenceList(Shortlist(Toggle(c))))),
            )
          },
        ])
      }),
    ),
    if view.pending {
      p(
        "Wait for the current brief operation before changing or downloading the shortlist.",
      )
    } else {
      div([
        action_button(
          "Clear shortlist",
          emit(BriefAction(ReferenceList(Shortlist(Clear)))),
        ),
        if !view.reference_shortlist.is_empty() &&
          unavailable == 0 &&
          catalog.issues.is_empty() {
          div([
            action_button(
              "Download selected references JSON",
              emit(BriefAction(ReferenceList(Shortlist(ExportJson)))),
            ),
            action_button(
              "Download selected references RIS",
              emit(BriefAction(ReferenceList(Shortlist(ExportRis)))),
            ),
            action_button(
              "Download selected references BibTeX",
              emit(BriefAction(ReferenceList(Shortlist(ExportBibtex)))),
            ),
            p(
              "BibTeX uses literal names and safe text escapes; exact originals and capture lineage remain in moonfind_provenance_hex (UTF-8 JSON). Missing fields stay absent. Review consumer formatting, omitted unsafe links and metadata before sharing; retain the dossier.",
            ),
            action_button(
              "Download selected references CSL JSON",
              emit(BriefAction(ReferenceList(Shortlist(ExportCsl)))),
            ),
            p(
              "CSL JSON exports the chosen cards with unique source-slot/record IDs and literal names, using the same field mapping as current matches. Original metadata remains in custom.moonfind.",
            ),
            p(
              "Downloads include every chosen record in selection order, including choices hidden by filters, with supplied abstracts and capture origins. Review before sharing. RIS field folding and type mapping match the current bibliography export.",
            ),
          ])
        } else {
          p(
            "Add choices and resolve unavailable or unreadable selections before downloading the shortlist.",
          )
        },
      ])
    },
  ])
}
