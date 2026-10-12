///|
fn bibtex_card_view(reference : BibtexReference) -> @rabbita.Html {
  div(style=["display:grid", "gap:6px", "overflow-wrap:anywhere"], [
    strong("[" + reference.citation_key + "] " + reference.title),
    p(
      reference.authors.join("; ") +
      " · " +
      reference.year +
      " · " +
      reference.reference_type,
    ),
    p(reference.venue + " · " + reference.availability),
    p("Keywords: " + reference.keywords),
    p("DOI: " + (if reference.doi.is_blank() { "—" } else { reference.doi })),
    p("URL: " + (if reference.url.is_blank() { "—" } else { reference.url })),
    pre(style=["white-space:pre-wrap", "font:inherit"], reference.abstract_text),
  ])
}

///|
fn bibtex_panel(emit : @rabbita.Emit[Msg], view : BriefView) -> @rabbita.Html {
  section(
    id="bibtex-bibliography",
    style=surface() + ["padding:16px", "display:grid", "gap:12px"],
    [
      h3("Local BibTeX bibliography"),
      p(
        "Import a local .bib export from Zotero, JabRef or a reference manager. Search citation keys, titles, authors, years, venues and keywords, then select your evidence set. The original file and selected metadata stay together. Abstracts and metadata do not establish that full text was read.",
      ),
      action_button(
        "Import BibTeX bibliography",
        emit(BriefAction(Bibtex(Choose))),
      ),
      match view.bibtex.intake {
        None =>
          p(
            "UTF-8 BIBTEX up to 32 KiB. Each added bibliography uses two of the brief’s eight source slots.",
          )
        Some(intake) =>
          div([
            p(
              intake.source.name +
              " · \{intake.total_count} references imported · \{view.bibtex.selected.length()} selected",
            ),
            field_label(
              "Search references",
              text_field(
                view.bibtex.query,
                "Citation key, title, author, year, venue or keyword",
                emit.map(value => BriefAction(Bibtex(Filter(value)))),
              ),
            ),
            p(
              "\{bibtex_filtered(view.bibtex).length()} matching references; selections remain when the filter changes.",
            ),
            ul(
              bibtex_filtered(view.bibtex).map(reference => {
                li(style=["padding:12px", "border-bottom:1px solid #314563"], [
                  bibtex_card_view(reference),
                  action_button(
                    (if view.bibtex.selected.contains(reference.record_number) {
                      "Deselect record "
                    } else {
                      "Select record "
                    }) +
                    reference.record_number.to_string(),
                    emit(BriefAction(Bibtex(Toggle(reference.record_number)))),
                  ),
                ])
              }),
            ),
            action_button(
              "Add selected references to brief",
              emit(BriefAction(Bibtex(AddSelected))),
              primary=true,
            ),
          ])
      },
    ],
  )
}

///|
fn bibtex_retained_selection(source : BriefInputSource) -> @rabbita.Html {
  if source.name != "bibtex-selection.json" {
    return div("")
  }
  let selection : BibtexSelection? = Some(
    @json.from_json(@json.parse(brief_source_preview(source.content_hex))),
  ) catch {
    _ => None
  }
  match selection {
    Some(selection) if selection.contract_id == "moonfind.bibtex-selection.v1" =>
      details(open=true, [
        summary("Selected reference cards from " + selection.source_name),
        ul(
          selection.references.map(reference => li(bibtex_card_view(reference))),
        ),
      ])
    _ => div("")
  }
}
