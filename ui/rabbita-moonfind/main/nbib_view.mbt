///|
fn nbib_card_view(reference : NbibReference) -> @rabbita.Html {
  div(style=["display:grid", "gap:6px", "overflow-wrap:anywhere"], [
    strong("\{reference.record_number}. " + reference.title),
    p("Supplied PMID: " + reference.pmid),
    p(
      reference.authors.join("; ") +
      " · " +
      reference.year +
      " · " +
      reference.reference_type,
    ),
    p("DOI: " + (if reference.doi.is_blank() { "—" } else { reference.doi })),
    p("PubMed record URL (derived, unopened): " + reference.url),
    pre(style=["white-space:pre-wrap", "font:inherit"], reference.abstract_text),
    p(
      if reference.abstract_text.is_blank() {
        "Metadata only; no full text reviewed."
      } else {
        "Metadata and supplied abstract; no full text reviewed."
      },
    ),
    details([
      summary("All supplied tags (including unmapped fields)"),
      pre(
        style=["white-space:pre-wrap", "font:inherit"],
        reference.fields
        .map(field => field.tag + " - " + field.value)
        .join("\n"),
      ),
    ]),
  ])
}

///|
fn nbib_panel(emit : @rabbita.Emit[Msg], view : BriefView) -> @rabbita.Html {
  section(
    id="nbib-bibliography",
    style=surface() + ["padding:16px", "display:grid", "gap:12px"],
    [
      h3("Local PubMed NBIB bibliography"),
      p(
        "Import PubMed/MEDLINE citation cards from a local .nbib file. Inspect PMID, title, authors, publication year, DOI and supplied abstract, then add selected citations to the editable brief and unified reading list. The complete original remains alongside selected metadata, including unselected records. No remote citation lookup.",
      ),
      action_button(
        "Import PubMed NBIB bibliography",
        emit(BriefAction(Nbib(Choose))),
      ),
      match view.nbib.intake {
        None =>
          p(
            "UTF-8 .nbib PubMed/MEDLINE tagged text up to 32 KiB. Records begin with PMID; six-space wrapped lines are supported. Each selection uses two of eight source slots. Unknown/repeated fields remain inspectable. XML, full text and online PubMed searches are outside this local import.",
          )
        Some(intake) =>
          div([
            p(
              intake.source.name +
              " · \{intake.total_count} references imported · \{view.nbib.selected.length()} selected",
            ),
            field_label(
              "Filter by author",
              text_field(
                view.nbib.author_filter,
                "Author name",
                emit.map(value => BriefAction(Nbib(Filter(value)))),
              ),
            ),
            p(
              "\{nbib_filtered(view.nbib).length()} matching references; selections remain when the filter changes.",
            ),
            ul(
              nbib_filtered(view.nbib).map(reference => {
                li(style=["padding:12px", "border-bottom:1px solid #314563"], [
                  nbib_card_view(reference),
                  action_button(
                    (if view.nbib.selected.contains(reference.record_number) {
                      "Deselect record "
                    } else {
                      "Select record "
                    }) +
                    reference.record_number.to_string(),
                    emit(BriefAction(Nbib(Toggle(reference.record_number)))),
                  ),
                ])
              }),
            ),
            action_button(
              "Add selected references to brief",
              emit(BriefAction(Nbib(AddSelected))),
              primary=true,
            ),
          ])
      },
    ],
  )
}

///|
fn nbib_retained_selection(source : BriefInputSource) -> @rabbita.Html {
  if source.name != "nbib-selection.json" {
    return div("")
  }
  let selection : NbibSelection? = Some(
    @json.from_json(@json.parse(brief_source_preview(source.content_hex))),
  ) catch {
    _ => None
  }
  match selection {
    Some(selection) if selection.contract_id == "moonfind.nbib-selection.v1" =>
      details(open=true, [
        summary("Selected reference cards from " + selection.source_name),
        ul(selection.references.map(reference => li(nbib_card_view(reference)))),
      ])
    _ => div("")
  }
}
