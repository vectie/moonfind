///|
fn reference_list_panel(
  emit : @rabbita.Emit[Msg],
  view : BriefView,
) -> @rabbita.Html {
  let catalog = reference_catalog(view)
  let matches = reference_matches(view, catalog)
  let counts = reference_doi_counts(catalog)
  section(
    id="unified-reference-list",
    style=surface() + ["padding:16px", "display:grid", "gap:12px"],
    [
      h3("Unified bibliography reading list"),
      p(
        "Add selected references from BibTeX, RIS, EndNote, PubMed NBIB or CSL JSON to this brief, or reopen a saved brief. Search all retained selections together and inspect same-DOI candidates. References stay separate; matching DOI text does not establish that records describe the same work. Metadata and supplied abstracts are not read full text.",
      ),
      field_label(
        "Search retained references",
        text_field(
          view.reference_query,
          "Title, author, editor, DOI, source name, abstract or ID",
          emit.map(value => BriefAction(ReferenceList(Query(value)))),
        ),
      ),
      action_button(
        if view.reference_duplicates {
          "Same-DOI candidates only: on"
        } else {
          "Same-DOI candidates only: off"
        },
        emit(BriefAction(ReferenceList(Duplicates))),
      ),
      if view.reference_doi_filter.is_empty() {
        div("")
      } else {
        p("Exact DOI group: " + view.reference_doi_filter)
      },
      action_button(
        "Clear reading-list filters",
        emit(BriefAction(ReferenceList(Clear))),
      ),
      reference_timeline_panel(emit, view, catalog),
      p(
        "\{matches.length()} matching references of \{catalog.references.length()} retained. Filters apply to the download too. Candidate counts include all retained cards, including peers hidden by search.",
      ),
      p(
        "DOI matching trims outer whitespace, removes one doi: or http(s)://(dx.)doi.org/ prefix and folds ASCII case for DOI-shaped tokens. Missing or malformed DOI text has no candidate group. No title matching or automatic merge.",
      ),
      ul(catalog.issues.map(issue => li(issue))),
      reference_shortlist_panel(emit, view, catalog),
      screening_panel(emit, view),
      reading_notes_panel(emit, view),
      if matches.is_empty() {
        p(
          "No matching references. Add a bibliography selection or adjust the text, DOI and publication-year filters.",
        )
      } else {
        div("")
      },
      ul(
        matches.map(r => {
          li(
            style=[
              "padding:12px", "border-bottom:1px solid #314563", "overflow-wrap:anywhere",
            ],
            [
              if view.pending {
                p(
                  "Wait for the current brief operation before choosing references.",
                )
              } else {
                let choice = reference_choice(view, r)
                action_button(
                  if view.reference_shortlist.contains(choice) {
                    "Remove from shortlist"
                  } else {
                    "Add to shortlist"
                  },
                  emit(BriefAction(ReferenceList(Shortlist(Toggle(choice))))),
                )
              },
              if view.pending || view.reading_notes.blocked {
                div("")
              } else {
                action_button(
                  "New reading note for this snapshot",
                  emit(
                    BriefAction(
                      ReadingNotes(
                        view.reading_notes.key,
                        view.reading_notes.notebook.revision,
                        Create(reference_choice(view, r)),
                      ),
                    ),
                  ),
                )
              },
              strong(
                if r.title.is_blank() {
                  "(Untitled reference)"
                } else {
                  r.title
                },
              ),
              p(
                "Source slot \{r.source_slot} · " +
                r.source_name +
                " · " +
                r.format +
                " · original record \{r.record_number}",
              ),
              p(
                "Citation key: " +
                r.citation_key +
                " · item ID (" +
                r.item_id_kind +
                "): " +
                r.item_id,
              ),
              p(
                "Authors: " +
                r.authors.join("; ") +
                " · Editors: " +
                r.editors.join("; "),
              ),
              p(r.issued + " · " + r.venue + " · " + r.availability),
              p(
                match reference_publication_year(r.issued) {
                  Some(year) =>
                    "Publication year (from supplied metadata): \{year}"
                  None =>
                    "Publication year: unclassified; inspect the original date above."
                },
              ),
              p("DOI: " + r.doi),
              p("URL (source text): " + r.url),
              if counts.get(r.doi_match_key).unwrap_or(0) > 1 {
                action_button(
                  "Inspect \{counts.get(r.doi_match_key).unwrap_or(0)} same-DOI candidates",
                  emit(BriefAction(ReferenceList(ShowDoi(r.doi_match_key)))),
                )
              } else {
                p("No same-DOI candidate group")
              },
              details([
                summary("Abstract and provenance"),
                pre(
                  style=["white-space:pre-wrap", "font:inherit"],
                  r.abstract_text,
                ),
                p("Original source digest (as recorded): " + r.source_digest),
                p("Selection capture: " + r.selection_name),
              ]),
            ],
          )
        }),
      ),
      p(
        "Download contains exactly the matching reference metadata, supplied abstracts and contributing capture origins. It includes no source-file bodies and does not save the brief. Review these details before sharing; retain the saved dossier to recover the original bytes.",
      ),
      if catalog.issues.is_empty() &&
        !view.pending &&
        reference_timeline_problem(view.reference_timeline) is None {
        div([
          action_button(
            "Download current reading list JSON",
            emit(BriefAction(ReferenceList(Export))),
          ),
          action_button(
            "Download current bibliography RIS",
            emit(BriefAction(ReferenceList(ExportRis))),
          ),
          action_button(
            "Download current bibliography BibTeX",
            emit(BriefAction(ReferenceList(ExportBibtex))),
          ),
          p(
            "BibTeX uses literal names and safe text escapes; exact originals and capture lineage remain in moonfind_provenance_hex (UTF-8 JSON). Missing fields stay absent. Review consumer formatting, omitted unsafe links and metadata before sharing; retain the dossier.",
          ),
          action_button(
            "Download current bibliography CSL JSON",
            emit(BriefAction(ReferenceList(ExportCsl))),
          ),
          p(
            "CSL JSON uses unique source-slot/record citation IDs and literal names. Original IDs and metadata remain in custom.moonfind. Unknown types use article; unsupported dates stay literal. Inspect citation formatting in your reference manager before use. No original files or full-text review are included.",
          ),
          p(
            "RIS exports matching cards for reference managers, without merging duplicates. Line breaks and controls become spaces in citation fields. Notes retain exact supplied metadata and source identity; unknown types become GEN. Only HTTP(S) URLs and recognized DOI text enter link fields. Review before importing or sharing; this is not a full-text review or a restorable dossier.",
          ),
        ])
      } else {
        p(
          "Wait for the brief operation, resolve unreadable selections and correct any year bounds before downloading.",
        )
      },
    ],
  )
}
