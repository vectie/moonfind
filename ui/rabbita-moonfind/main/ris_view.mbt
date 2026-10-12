///|
fn ris_card_view(reference : RisReference) -> @rabbita.Html {
  div(style=["display:grid", "gap:6px", "overflow-wrap:anywhere"], [
    strong("\{reference.record_number}. " + reference.title),
    p(
      reference.authors.join("; ") +
      " · " +
      reference.year +
      " · " +
      reference.reference_type,
    ),
    p("DOI: " + (if reference.doi.is_blank() { "—" } else { reference.doi })),
    p("URL: " + (if reference.url.is_blank() { "—" } else { reference.url })),
    pre(style=["white-space:pre-wrap", "font:inherit"], reference.abstract_text),
  ])
}

///|
fn ris_panel(emit : @rabbita.Emit[Msg], view : BriefView) -> @rabbita.Html {
  section(
    id="ris-bibliography",
    style=surface() + ["padding:16px", "display:grid", "gap:12px"],
    [
      h3("Local RIS bibliography"),
      p(
        "Import reference cards from a local .ris file. Browse titles, authors, year, DOI/URL and abstracts, then select the references for your brief. The original file is kept alongside your selected metadata. No remote citation lookup.",
      ),
      action_button("Import RIS bibliography", emit(BriefAction(Ris(Choose)))),
      match view.ris.intake {
        None =>
          p(
            "UTF-8 RIS up to 32 KiB. Each added bibliography uses two of the brief’s eight source slots.",
          )
        Some(intake) =>
          div([
            p(
              intake.source.name +
              " · \{intake.total_count} references imported · \{view.ris.selected.length()} selected",
            ),
            field_label(
              "Filter by author",
              text_field(
                view.ris.author_filter,
                "Author name",
                emit.map(value => BriefAction(Ris(Filter(value)))),
              ),
            ),
            p(
              "\{ris_filtered(view.ris).length()} matching references; selections remain when the filter changes.",
            ),
            ul(
              ris_filtered(view.ris).map(reference => {
                li(style=["padding:12px", "border-bottom:1px solid #314563"], [
                  ris_card_view(reference),
                  action_button(
                    (if view.ris.selected.contains(reference.record_number) {
                      "Deselect record "
                    } else {
                      "Select record "
                    }) +
                    reference.record_number.to_string(),
                    emit(BriefAction(Ris(Toggle(reference.record_number)))),
                  ),
                ])
              }),
            ),
            action_button(
              "Add selected references to brief",
              emit(BriefAction(Ris(AddSelected))),
              primary=true,
            ),
          ])
      },
    ],
  )
}

///|
fn ris_retained_selection(source : BriefInputSource) -> @rabbita.Html {
  if source.name != "ris-selection.json" {
    return div("")
  }
  let selection : RisSelection? = Some(
    @json.from_json(@json.parse(brief_source_preview(source.content_hex))),
  ) catch {
    _ => None
  }
  match selection {
    Some(selection) if selection.contract_id == "moonfind.ris-selection.v1" =>
      details(open=true, [
        summary("Selected reference cards from " + selection.source_name),
        ul(selection.references.map(reference => li(ris_card_view(reference)))),
      ])
    _ => div("")
  }
}
