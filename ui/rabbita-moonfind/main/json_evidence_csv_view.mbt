///|
fn json_evidence_csv_panel(
  emit : @rabbita.Emit[Msg],
  view : BriefView,
) -> @rabbita.Html {
  details([
    summary("Project selected JSON fields to CSV"),
    p(
      "Choose nested fields to take selected records into a spreadsheet. Enter a JSON array of one to eight record-relative pointers, such as [\"/site\",\"/metrics/count\"]. Pointer order becomes column order. This includes selected records hidden by search.",
    ),
    field_label(
      "CSV field pointers (JSON array)",
      textarea(
        value=view.json_evidence.csv_fields,
        rows=3,
        disabled=view.pending,
        on_input=emit.map(value => BriefAction(JsonEvidence(CsvFields(value)))),
        style=["width:100%", "box-sizing:border-box"],
        "",
      ),
    ),
    p(
      "Each chosen field has value, kind and encoding columns. Missing and blocked paths stay distinct from null or empty text. Strings are decoded; numbers, objects and arrays keep original JSON spelling. Containers include all their nested fields. Review the preview before sharing.",
    ),
    try {
      let csv = json_evidence_csv(view)
      div([
        p(
          "\{csv.record_count} selected records · \{csv.field_count} projected fields · \{csv.escaped_cells} cells with an explicit apostrophe prefix",
        ),
        pre(
          style=[
            "white-space:pre-wrap", "overflow-wrap:anywhere", "max-height:320px",
            "overflow:auto",
          ],
          csv.text,
        ),
      ])
    } catch {
      error => p("\{error}")
    },
    action_button(
      "Download selected projected CSV",
      emit(BriefAction(JsonEvidence(DownloadCsv))),
    ),
    p(
      "Import value columns as text in your spreadsheet to preserve long integers, dates and numeric spellings. Formula-like values and leading apostrophes/controls get one apostrophe prefix, marked in the encoding column; removing it can restore an active formula. CSV quoting alone does not protect formulas. Spreadsheet behavior varies.",
    ),
    p(
      "CSV contains only the chosen fields and source record/line/pointer locators. It has no source name, origin, digest or whole source body; keep the original dossier or provenance JSON extract. The full original remains in the brief. This does not redact that dossier, judge evidence, save an artifact to the brief, or prove a browser download reached disk. Settings are temporary and preview updates with selection.",
    ),
  ])
}
