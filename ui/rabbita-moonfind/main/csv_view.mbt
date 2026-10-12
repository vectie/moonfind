///|
fn csv_table(
  columns : Array[String],
  rows : Array[CsvRow],
  choose? : (CsvRow) -> @rabbita.Html,
  record_label? : String = "Source record",
) -> @rabbita.Html {
  div(style=["overflow-x:auto"], [
    @html.table(style=["border-collapse:collapse", "width:100%"], [
      @html.thead([
        @html.tr(
          [@html.th(record_label)] +
          columns.map(column => {
            @html.th(style=["text-align:left", "padding:8px"], column)
          }) +
          (if choose is Some(_) { [@html.th("Selection")] } else { [] }),
        ),
      ]),
      @html.tbody(
        rows.map(row => {
          @html.tr(
            [@html.td(row.record_number.to_string())] +
            row.values.map(value => {
              @html.td(
                style=[
                  "padding:8px", "border-top:1px solid #314563", "white-space:pre-wrap",
                  "overflow-wrap:anywhere",
                ],
                value,
              )
            }) +
            (match choose {
              Some(choose) => [@html.td([choose(row)])]
              None => []
            }),
          )
        }),
      ),
    ]),
  ])
}

///|
fn csv_panel(emit : @rabbita.Emit[Msg], view : BriefView) -> @rabbita.Html {
  section(
    id="csv-corpus",
    style=surface() + ["padding:16px", "display:grid", "gap:12px"],
    [
      h3("Explore a local CSV corpus"),
      p(
        "Import an interview, observation or evidence table. Search a column, select useful rows, and choose columns for your brief. The complete original file is retained too, including unselected data. Selection is not redaction or verification.",
      ),
      action_button("Import CSV table", emit(BriefAction(Csv(Choose)))),
      match view.csv.intake {
        None =>
          p(
            "UTF-8 comma-delimited CSV up to 32 KiB, 32 columns and 512 data rows. First record: unique nonblank header names. Quoted commas, quotes and multiline cells are supported.",
          )
        Some(intake) =>
          div(style=["display:grid", "gap:12px"], [
            p(
              intake.source.name +
              " · \{intake.total_count} data rows · \{view.csv.selected.length()} selected · \{view.csv.columns.length()} output columns",
            ),
            field_label(
              "Search cells",
              text_field(
                view.csv.query,
                "Case-insensitive literal text",
                emit.map(value => BriefAction(Csv(Filter(value)))),
              ),
            ),
            field_label(
              "Search in column",
              select(
                on_change=emit.map(value => {
                  BriefAction(
                    Csv(SearchColumn(@string.parse_int(value) catch { _ => 0 })),
                  )
                }),
                [
                  option(
                    value="0",
                    selected=view.csv.column_number == 0,
                    "All columns",
                  ),
                ] +
                intake.columns.mapi((index, column) => {
                  option(
                    value=(index + 1).to_string(),
                    selected=view.csv.column_number == index + 1,
                    column,
                  )
                }),
              ),
            ),
            p(
              "Output columns for CSV download and selected evidence added to the brief:",
            ),
            div(
              style=["display:flex", "gap:8px", "flex-wrap:wrap"],
              intake.columns.mapi((index, column) => {
                action_button(
                  (if view.csv.columns.contains(index + 1) {
                    "✓ "
                  } else {
                    "+ "
                  }) +
                  column,
                  emit(BriefAction(Csv(ToggleColumn(index + 1)))),
                )
              }),
            ),
            p(
              "\{csv_filtered(view.csv).length()} matching rows. Selection remains when filters change. Source record 1 is the header; quoted multiline cells stay in one record.",
            ),
            div(style=["display:flex", "gap:8px"], [
              action_button(
                "Select all matching rows",
                emit(BriefAction(Csv(SelectMatching))),
              ),
              action_button(
                "Clear row selection",
                emit(BriefAction(Csv(ClearRows))),
              ),
            ]),
            csv_extract_panel(emit, view),
            csv_categories_panel(emit, view),
            csv_numeric_panel(emit, view),
            csv_comparison_panel(emit, view),
            csv_table(intake.columns, csv_filtered(view.csv), choose=row => {
              action_button(
                (if view.csv.selected.contains(row.record_number) {
                  "Deselect record "
                } else {
                  "Select record "
                }) +
                row.record_number.to_string(),
                emit(BriefAction(Csv(Toggle(row.record_number)))),
              )
            }),
            action_button(
              "Add selected evidence rows to brief",
              emit(BriefAction(Csv(AddSelected))),
              primary=true,
            ),
          ])
      },
    ],
  )
}

///|
fn csv_retained_selection(source : BriefInputSource) -> @rabbita.Html {
  if source.name != "csv-selection.json" {
    return div("")
  }
  let selection : CsvSelection? = Some(
    @json.from_json(@json.parse(brief_source_preview(source.content_hex))),
  ) catch {
    _ => None
  }
  match selection {
    Some(selection) if selection.contract_id == "moonfind.csv-selection.v1" =>
      details(open=true, [
        summary("Selected evidence rows from " + selection.source_name),
        p(
          "\{selection.rows.length()} of \{selection.source_row_count} source data rows. Original column positions: " +
          selection.column_numbers.map(number => number.to_string()).join(", "),
        ),
        csv_table(selection.columns, selection.rows),
      ])
    _ => div("")
  }
}
