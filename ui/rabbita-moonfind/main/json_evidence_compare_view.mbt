///|
fn json_evidence_comparison_panel(
  emit : @rabbita.Emit[Msg],
  view : BriefView,
) -> @rabbita.Html {
  let state = view.json_evidence
  details([
    summary("Compare two JSON evidence snapshots"),
    p(
      "Compare the currently explored source as Before with another loaded capture as After. Choose a unique typed key and one to eight nested fields. All records are included, regardless of search or selection. Labels do not infer which capture is newer.",
    ),
    p(
      "Before: source \{state.slot}. The current explorer's array pointer and JSON/JSONL format apply.",
    ),
    field_label(
      "After source",
      select(
        disabled=view.pending,
        on_change=emit.map(value => {
          BriefAction(
            JsonEvidence(
              CompareSource(@string.parse_int(value) catch { _ => 0 }),
            ),
          )
        }),
        [
          option(
            value="0",
            selected=state.compare_slot == 0,
            "Choose another source",
          ),
        ] +
        view.draft.sources.mapi((index, source) => {
          option(
            value=(index + 1).to_string(),
            selected=state.compare_slot == index + 1,
            "Source \{index + 1}: " + source.name,
          )
        }),
      ),
    ),
    field_label(
      "After source format",
      select(
        disabled=view.pending,
        on_change=emit.map(value => {
          BriefAction(JsonEvidence(CompareLines(value == "jsonl")))
        }),
        [
          option(value="json", selected=!state.compare_lines, "JSON array"),
          option(
            value="jsonl",
            selected=state.compare_lines,
            "JSONL physical lines",
          ),
        ],
      ),
    ),
    field_label(
      "After JSON Pointer to array (ignored for JSONL)",
      text_field(
        state.compare_pointer,
        "Empty for root, or /observations",
        emit.map(value => BriefAction(JsonEvidence(CompareField(0, value)))),
      ),
    ),
    field_label(
      "Unique record key pointer (both sources)",
      text_field(
        state.compare_key,
        "/id",
        emit.map(value => BriefAction(JsonEvidence(CompareField(1, value)))),
      ),
    ),
    field_label(
      "Comparison field pointers (JSON array)",
      textarea(
        value=state.compare_fields,
        rows=3,
        disabled=view.pending,
        on_input=emit.map(value => {
          BriefAction(JsonEvidence(CompareField(2, value)))
        }),
        style=["width:100%", "box-sizing:border-box"],
        "",
      ),
    ),
    p(
      "Every record needs a unique nonempty string, number or boolean key. Strings match by decoded exact text; numbers match by exact token spelling. Missing, null, empty or duplicate keys stop the comparison with record numbers. No guess or positional pairing is made.",
    ),
    p(
      "Selected fields compare kind and exact source token. Null, missing, blocked and empty string remain distinct. Number spelling, string escapes, and whitespace/order inside chosen containers count as changes. Unchanged fields does not mean the whole record or evidence is unchanged.",
    ),
    try {
      let comparison = json_evidence_comparison(view)
      div([
        p(
          "\{comparison.added} added · \{comparison.removed} removed · \{comparison.changed} changed · \{comparison.unchanged_fields} unchanged requested fields",
        ),
        details([
          summary("Inspect before/after values, keys and source locators"),
          pre(
            style=[
              "white-space:pre-wrap", "overflow-wrap:anywhere", "max-height:440px",
              "overflow:auto",
            ],
            comparison.text,
          ),
        ]),
      ])
    } catch {
      error => p("\{error}")
    },
    action_button(
      "Download snapshot comparison JSON",
      emit(BriefAction(JsonEvidence(DownloadComparison))),
    ),
    p(
      "Preview and download use current sources/settings, never a cached result. Output includes every compared key and selected field, both source descriptors and locators. Selected containers include all descendants. It omits unselected fields and full source bodies, but can still contain private data. Review before sharing. This does not edit sources, change selection, save the brief, verify a digest or prove a browser save reached disk.",
    ),
  ])
}
