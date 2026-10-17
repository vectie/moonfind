///|
fn json_evidence_panel(
  emit : @rabbita.Emit[Msg],
  view : BriefView,
) -> @rabbita.Html {
  let state = view.json_evidence
  section(
    id="json-evidence",
    style=surface() + ["padding:16px", "display:grid", "gap:12px"],
    [
      h3("Explore loaded JSON evidence"),
      p(
        "Import a JSONL / NDJSON file, add a JSON file or paste JSON using the source controls below. Explore an array or keyed object of observations, search its fields, and select records for a reusable extract. Each member value must be an object. Original source bytes stay in the brief. This does not fetch sources or verify claims.",
      ),
      action_button(
        "Import JSONL / NDJSON file",
        emit(BriefAction(JsonEvidence(ChooseLines))),
      ),
      field_label(
        "Loaded JSON source",
        select(
          on_change=emit.map(value => {
            BriefAction(
              JsonEvidence(Source(@string.parse_int(value) catch { _ => 0 })),
            )
          }),
          [option(value="0", selected=state.slot == 0, "Choose a source")] +
          view.draft.sources.mapi((index, source) => {
            option(
              value=(index + 1).to_string(),
              selected=state.slot == index + 1,
              "Source \{index + 1}: " + source.name,
            )
          }),
        ),
      ),
      field_label(
        "JSON Pointer to array or keyed observations",
        text_field(
          state.pointer,
          "Empty for root, or /observations (escape / as ~1 and ~ as ~0)",
          emit.map(value => BriefAction(JsonEvidence(Pointer(value)))),
        ),
      ),
      action_button(
        "Explore JSON records",
        emit(BriefAction(JsonEvidence(Explore))),
      ),
      action_button(
        "Explore loaded JSONL lines",
        emit(BriefAction(JsonEvidence(ExploreLines))),
      ),
      p(
        "JSONL uses one object per physical line; blank lines are skipped. The container pointer applies only to Explore JSON records. For keyed objects, member names remain escaped source pointers in source order, never synthetic record fields. Save and reopen the brief, choose the retained source and re-enter this pointer to continue exploring.",
      ),
      p(
        "Up to 32 KiB, 512 object records, 32 distinct top-level fields and 32 nesting levels. Nested objects and arrays are literal JSON. Fields keep their first-seen order; numbers keep their exact spelling. Missing, null and empty text are distinct.",
      ),
      match state.table {
        None => div("")
        Some(table) =>
          div(style=["display:grid", "gap:12px"], [
            p(
              "\{table.rows.length()} source records · \{json_evidence_matches(state).length()} matching · \{state.selected.length()} selected",
            ),
            json_evidence_coverage_panel(emit, table),
            json_evidence_lens_panel(emit, state),
            json_evidence_cohort_panel(emit, state),
            json_evidence_pairs_panel(emit, state),
            json_evidence_comparison_panel(emit, view),
            field_label(
              "Search JSON field values",
              text_field(
                state.query,
                "Case-insensitive literal text",
                emit.map(value => BriefAction(JsonEvidence(Search(value)))),
              ),
            ),
            p(
              "Record numbers and JSONL physical source lines are one-based; JSON Pointer array indexes are zero-based. Selections remain when searches change. The extract includes every field of each selected object, including nested and currently hidden content.",
            ),
            div(style=["display:flex", "gap:8px", "flex-wrap:wrap"], [
              action_button(
                "Select matching JSON records",
                emit(BriefAction(JsonEvidence(SelectMatching))),
              ),
              action_button(
                "Clear JSON selection",
                emit(BriefAction(JsonEvidence(Clear))),
              ),
            ]),
            div(
              style=["overflow-x:auto", "max-height:400px", "overflow-y:auto"],
              [
                @html.table(style=["border-collapse:collapse", "width:100%"], [
                  @html.thead([
                    @html.tr(
                      [@html.th("Source record / pointer")] +
                      table.columns.map(name => {
                        @html.th(
                          if name.is_empty() {
                            "(empty field name)"
                          } else {
                            name
                          },
                        )
                      }) +
                      [@html.th("Selection")],
                    ),
                  ]),
                  @html.tbody(
                    json_evidence_matches(state).map(row => {
                      @html.tr(
                        [
                          @html.td(
                            "\{row.record_number} · " +
                            (if table.format == "jsonl" {
                              "source line " + row.source_line.to_string()
                            } else {
                              row.pointer
                            }),
                          ),
                        ] +
                        row.cells.map(cell => {
                          @html.td(
                            style=[
                              "padding:8px", "white-space:pre-wrap", "overflow-wrap:anywhere",
                            ],
                            [
                              p(cell.kind),
                              pre(
                                style=["white-space:pre-wrap"],
                                if cell.kind == "missing" {
                                  "(field absent)"
                                } else if cell.kind == "string" &&
                                  cell.text.is_empty() {
                                  "(empty string)"
                                } else {
                                  cell.text
                                },
                              ),
                            ],
                          )
                        }) +
                        [
                          @html.td([
                            action_button(
                              (if state.selected.contains(row.record_number) {
                                "Deselect JSON record "
                              } else {
                                "Select JSON record "
                              }) +
                              row.record_number.to_string(),
                              emit(
                                BriefAction(
                                  JsonEvidence(Toggle(row.record_number)),
                                ),
                              ),
                            ),
                          ]),
                        ],
                      )
                    }),
                  ),
                ]),
              ],
            ),
            details([
              summary("Preview selected JSON extract"),
              pre(
                style=[
                  "white-space:pre-wrap", "overflow-wrap:anywhere", "max-height:320px",
                  "overflow:auto",
                ],
                json_evidence_export(view) catch {
                  error => "\{error}"
                },
              ),
            ]),
            action_button(
              "Download selected JSON extract",
              emit(BriefAction(JsonEvidence(Download))),
            ),
            details([
              summary("Preview selected raw NDJSON records"),
              pre(
                style=[
                  "white-space:pre-wrap", "overflow-wrap:anywhere", "max-height:320px",
                  "overflow:auto",
                ],
                json_evidence_ndjson(view) catch {
                  error => "\{error}"
                },
              ),
            ]),
            action_button(
              "Download selected raw NDJSON records",
              emit(BriefAction(JsonEvidence(DownloadNdjson))),
            ),
            p(
              "NDJSON contains every field of selected records, including hidden selections, in original source order. One object per line; only structural whitespace is removed. Number and string escape spellings are preserved. No envelope, keyed member names, locators, origin or digest is added. Keep the original dossier or JSON extract for provenance and keyed identity. Review private fields before sharing; consumers may round numeric values.",
            ),
            json_evidence_csv_panel(emit, view),
            action_button(
              "Add selected JSON records to brief",
              emit(BriefAction(JsonEvidence(Add))),
              primary=true,
            ),
            p(
              "Download contains selected objects and source name, origin, capture time and record locators; no original source body. Adding uses one source slot and clears selection. Save the brief to retain it with the complete original; selection is not redaction of that dossier. Review private fields before sharing.",
            ),
          ])
      },
    ],
  )
}
