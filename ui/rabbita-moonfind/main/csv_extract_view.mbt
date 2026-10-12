///|
fn csv_extract_panel(
  emit : @rabbita.Emit[Msg],
  view : BriefView,
) -> @rabbita.Html {
  section(style=["display:grid", "gap:8px"], [
    h3("Download a reusable CSV extract"),
    p(
      "Download only the chosen rows and output columns as moonfind-csv-extract.csv. The original file and source metadata are not embedded in this download. Review the preview before sharing it.",
    ),
    field_label(
      "Rows in CSV download",
      select(
        on_change=emit.map(value => BriefAction(Csv(ExtractScope(value)))),
        [
          option(
            value="selected",
            selected=view.csv.extract_scope == "selected",
            "Selected rows, including hidden selections",
          ),
          option(
            value="matching",
            selected=view.csv.extract_scope == "matching",
            "Rows matching the current search",
          ),
          option(
            value="all",
            selected=view.csv.extract_scope == "all",
            "All source rows",
          ),
        ],
      ),
    ),
    p(
      "Cells are preserved as text, including leading zeroes and formula-like values. In a spreadsheet, import every column as text; CSV quoting does not prevent formulas or automatic date/number conversion.",
    ),
    try {
      let extract = csv_extract(view.csv)
      div([
        p(
          "\{extract.rows.length()} data rows · \{extract.columns.length()} columns in the download. Source order is preserved.",
        ),
        if extract.rows.is_empty() {
          p("No rows in this scope. Download contains the header only.")
        } else {
          div("")
        },
        details([
          summary("Preview CSV download"),
          p(
            "Source record numbers below help you inspect the extract; they are not an extra column in the CSV. Record 1 is the original header.",
          ),
          csv_table(extract.columns, extract.rows),
        ]),
        action_button(
          "Download CSV extract",
          emit(BriefAction(Csv(DownloadExtract))),
        ),
      ])
    } catch {
      error => p("\{error}")
    },
    p(
      "This download does not save the brief or change its sources. Adding selected evidence to a brief still retains the complete original CSV.",
    ),
  ])
}
