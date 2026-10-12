///|
fn csl_card_view(reference : CslReference) -> @rabbita.Html {
  div(style=["display:grid", "gap:6px", "overflow-wrap:anywhere"], [
    strong("[" + reference.citation_key + "] " + reference.title),
    p(
      "Source record \{reference.record_number} · CSL item ID (" +
      reference.item_id_kind +
      "): " +
      reference.item_id,
    ),
    p(
      "Authors: " +
      reference.authors.join("; ") +
      " · " +
      reference.issued +
      " · " +
      reference.reference_type,
    ),
    p("Editors: " + reference.editors.join("; ")),
    p(reference.venue + " · " + reference.availability),
    p("Keywords: " + reference.keywords),
    p("DOI: " + (if reference.doi.is_blank() { "—" } else { reference.doi })),
    p("URL: " + (if reference.url.is_blank() { "—" } else { reference.url })),
    pre(style=["white-space:pre-wrap", "font:inherit"], reference.abstract_text),
  ])
}

///|
fn csl_panel(emit : @rabbita.Emit[Msg], view : BriefView) -> @rabbita.Html {
  section(
    id="csl-bibliography",
    style=surface() + ["padding:16px", "display:grid", "gap:12px"],
    [
      h3("Local CSL JSON bibliography"),
      p(
        "Export a bibliography as CSL JSON from Zotero or another reference manager, then import its .json file. Search item IDs, citation keys, titles, authors, editors, dates, venues, keywords or DOI and select references for your brief. The original file and selected metadata stay together. Metadata and supplied abstracts do not establish that full text was read.",
      ),
      action_button(
        "Import CSL JSON bibliography",
        emit(BriefAction(Csl(Choose))),
      ),
      match view.csl.intake {
        None =>
          p(
            "UTF-8 CSL JSON up to 32 KiB. Each added bibliography uses two of the brief’s eight source slots.",
          )
        Some(intake) =>
          div([
            p(
              intake.source.name +
              " · \{intake.total_count} references imported · \{view.csl.selected.length()} selected",
            ),
            field_label(
              "Search references",
              text_field(
                view.csl.query,
                "ID, citation key, title, author, editor, date, venue, keyword or DOI",
                emit.map(value => BriefAction(Csl(Filter(value)))),
              ),
            ),
            p(
              "\{csl_filtered(view.csl).length()} matching references; selections remain when the filter changes.",
            ),
            ul(
              csl_filtered(view.csl).map(reference => {
                li(style=["padding:12px", "border-bottom:1px solid #314563"], [
                  csl_card_view(reference),
                  action_button(
                    (if view.csl.selected.contains(reference.record_number) {
                      "Deselect record "
                    } else {
                      "Select record "
                    }) +
                    reference.record_number.to_string(),
                    emit(BriefAction(Csl(Toggle(reference.record_number)))),
                  ),
                ])
              }),
            ),
            action_button(
              "Add selected references to brief",
              emit(BriefAction(Csl(AddSelected))),
              primary=true,
            ),
          ])
      },
    ],
  )
}

///|
fn csl_retained_selection(source : BriefInputSource) -> @rabbita.Html {
  if source.name != "csl-selection.json" {
    return div("")
  }
  let selection : CslSelection? = Some(
    @json.from_json(@json.parse(brief_source_preview(source.content_hex))),
  ) catch {
    _ => None
  }
  match selection {
    Some(selection) if selection.contract_id == "moonfind.csl-selection.v1" =>
      details(open=true, [
        summary("Selected reference cards from " + selection.source_name),
        ul(selection.references.map(reference => li(csl_card_view(reference)))),
      ])
    _ => div("")
  }
}
