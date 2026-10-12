///|
struct JsonEvidenceLensRow {
  record_number : Int
  source_line : Int
  record_pointer : String
  value_pointer : String
  kind : String
  text : String
  raw : String
} derive(Debug, Eq, FromJson)

///|
struct JsonEvidenceLens {
  pointer : String
  total : Int
  rows : Array[JsonEvidenceLensRow]
  buckets : Array[JsonEvidenceCoverageBucket]
} derive(Debug, Eq, FromJson)

///|
// Reuse the source parser's exact token nodes; no second parser, flattened
// source or floating-point representation is introduced by the field lens.
fn json_evidence_lens(state : JsonEvidenceView) -> JsonEvidenceLens raise {
  guard state.source is Some(source) && state.table is Some(table) else {
    fail("Explore a current JSON or JSONL capture before inspecting a field.")
  }
  guard !state.lens_pointer.is_empty() else {
    fail(
      "Enter a field pointer such as /interview/outcome. Use / for an empty member name.",
    )
  }
  match
    @json.parse(
      json_evidence_parse_mode(
        source.content_hex,
        state.pointer,
        table.format == "jsonl",
        state.lens_pointer,
      ),
    ) {
    { "error": String(message), .. } => fail(message)
    { "lens": lens, .. } => @json.from_json(lens)
    _ => fail("Nested JSON field inspection is unavailable.")
  }
}

///|
fn json_evidence_lens_selection(
  lens : JsonEvidenceLens,
  kind : String,
) -> Array[Int] raise {
  for bucket in lens.buckets {
    if bucket.kind == kind {
      return bucket.records.copy()
    }
  }
  fail("Choose a current nested-field category.")
}

///|
fn json_evidence_lens_panel(
  emit : @rabbita.Emit[Msg],
  state : JsonEvidenceView,
) -> @rabbita.Html {
  details([
    summary("Inspect a nested JSON field"),
    p(
      "Follow one exact JSON Pointer inside every source record, for example /interview/outcome or /visits/0/duration. This lens does not flatten arrays or change source records. Search does not restrict the inspection.",
    ),
    field_label(
      "Field pointer relative to each record",
      text_field(
        state.lens_pointer,
        "/interview/outcome (escape / as ~1 and ~ as ~0)",
        emit.map(value => BriefAction(JsonEvidence(LensPointer(value)))),
      ),
    ),
    action_button(
      "Inspect nested field",
      emit(BriefAction(JsonEvidence(ExploreLens))),
    ),
    p(
      "Missing means an object member or array position is absent. Blocked means a scalar/null parent or an incompatible array index prevents traversal. Neither means the final value is null. Counts describe data shape, not truth or completeness.",
    ),
    match state.lens {
      None =>
        p(
          "Enter a field pointer and inspect it. Editing the pointer clears this lens; existing record selections remain until you replace or clear them.",
        )
      Some(lens) =>
        div(style=["display:grid", "gap:8px"], [
          p(
            "Requested field " +
            lens.pointer +
            " · \{lens.total} source records. Categories replace the selection and clear search, including zero-count categories.",
          ),
          div(
            style=["display:flex", "gap:8px", "flex-wrap:wrap"],
            lens.buckets.map(bucket => {
              action_button(
                "Replace selection: " +
                bucket.kind +
                " · \{bucket.count} / \{lens.total}",
                emit(BriefAction(JsonEvidence(SelectLens(bucket.kind)))),
              )
            }),
          ),
          div(style=["overflow:auto", "max-height:400px"], [
            @html.table(style=["border-collapse:collapse", "width:100%"], [
              @html.thead([
                @html.tr([
                  @html.th("Source record"),
                  @html.th("Requested value pointer"),
                  @html.th("Kind / value"),
                  @html.th("Selection"),
                ]),
              ]),
              @html.tbody(
                lens.rows.map(row => {
                  @html.tr([
                    @html.td(
                      "\{row.record_number} · " +
                      (if row.source_line > 0 {
                        "source line \{row.source_line}"
                      } else {
                        row.record_pointer
                      }),
                    ),
                    @html.td(row.value_pointer),
                    @html.td(style=["padding:8px", "overflow-wrap:anywhere"], [
                      p(row.kind),
                      pre(
                        style=["white-space:pre-wrap"],
                        if row.kind == "missing" {
                          "(member or position absent; requested pointer does not resolve)"
                        } else if row.kind == "blocked" {
                          "(parent shape prevents traversal; requested pointer does not resolve)"
                        } else if row.kind == "empty-string" {
                          "(empty string)"
                        } else {
                          row.text
                        },
                      ),
                      if row.kind == "missing" || row.kind == "blocked" {
                        div("")
                      } else {
                        details([
                          summary("Exact source JSON token"),
                          pre(style=["white-space:pre-wrap"], row.raw),
                        ])
                      },
                    ]),
                    @html.td([
                      action_button(
                        (if state.selected.contains(row.record_number) {
                          "Deselect JSON record "
                        } else {
                          "Select JSON record "
                        }) +
                        row.record_number.to_string(),
                        emit(
                          BriefAction(JsonEvidence(Toggle(row.record_number))),
                        ),
                      ),
                    ]),
                  ])
                }),
              ),
            ]),
          ]),
          p(
            "Use the existing JSON extract, NDJSON or Add to brief actions below to retain selected original records. Every original field is included, not just this lens value. Review private fields before sharing. JSONL pointers are relative to the object at the displayed physical source line.",
          ),
        ])
    },
  ])
}
