///|
fn endnote_card_view(reference : EndnoteReference) -> @rabbita.Html {
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
        .map(field => "%" + field.tag + " " + field.value)
        .join("\n"),
      ),
    ]),
  ])
}

///|
fn endnote_panel(emit : @rabbita.Emit[Msg], view : BriefView) -> @rabbita.Html {
  section(
    id="endnote-bibliography",
    style=surface() + ["padding:16px", "display:grid", "gap:12px"],
    [
      h3("Local EndNote bibliography"),
      p(
        "Import reference cards from a local .enw file. Browse titles, authors, year, DOI/URL and abstracts, then select the references for your brief. The original file is kept alongside your selected metadata. No remote citation lookup.",
      ),
      action_button(
        "Import EndNote bibliography",
        emit(BriefAction(Endnote(Choose))),
      ),
      match view.endnote.intake {
        None =>
          p(
            "UTF-8 .enw tagged text up to 32 KiB. Each record starts with %0 and records need a blank separator. Indented continuation lines are supported. Binary .enl/.enlx libraries are not supported. Each selection uses two of the brief’s eight source slots; attached-file tags are retained as text only.",
          )
        Some(intake) =>
          div([
            p(
              intake.source.name +
              " · \{intake.total_count} references imported · \{view.endnote.selected.length()} selected",
            ),
            field_label(
              "Filter by author",
              text_field(
                view.endnote.author_filter,
                "Author name",
                emit.map(value => BriefAction(Endnote(Filter(value)))),
              ),
            ),
            p(
              "\{endnote_filtered(view.endnote).length()} matching references; selections remain when the filter changes.",
            ),
            ul(
              endnote_filtered(view.endnote).map(reference => {
                li(style=["padding:12px", "border-bottom:1px solid #314563"], [
                  endnote_card_view(reference),
                  action_button(
                    (if view.endnote.selected.contains(reference.record_number) {
                      "Deselect record "
                    } else {
                      "Select record "
                    }) +
                    reference.record_number.to_string(),
                    emit(BriefAction(Endnote(Toggle(reference.record_number)))),
                  ),
                ])
              }),
            ),
            action_button(
              "Add selected references to brief",
              emit(BriefAction(Endnote(AddSelected))),
              primary=true,
            ),
          ])
      },
    ],
  )
}

///|
fn endnote_retained_selection(source : BriefInputSource) -> @rabbita.Html {
  if source.name != "endnote-selection.json" {
    return div("")
  }
  let selection : EndnoteSelection? = Some(
    @json.from_json(@json.parse(brief_source_preview(source.content_hex))),
  ) catch {
    _ => None
  }
  match selection {
    Some(selection) if selection.contract_id == "moonfind.endnote-selection.v1" =>
      details(open=true, [
        summary("Selected reference cards from " + selection.source_name),
        ul(
          selection.references.map(reference => li(endnote_card_view(reference))),
        ),
      ])
    _ => div("")
  }
}
