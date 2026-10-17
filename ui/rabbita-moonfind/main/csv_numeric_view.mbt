///|
fn csv_numeric_value(value : Double?) -> String {
  value.map(value => value.to_string()).unwrap_or("unavailable")
}

///|
fn csv_numeric_panel(
  emit : @rabbita.Emit[Msg],
  view : BriefView,
) -> @rabbita.Html {
  guard view.csv.intake is Some(intake) else { return div("") }
  let result = Some(csv_numeric_summary(view.csv)) catch { _ => None }
  details(open=true, [
    summary("Numeric column summary and source records"),
    p(
      "Choose a column explicitly. Decimal point and e/E exponent are supported; currency, percentages, units and thousands separators are not. Only outer ASCII whitespace is ignored. Blank and invalid cells are excluded, never treated as zero. Values and arithmetic use approximate binary64 numbers, not exact decimal accounting.",
    ),
    field_label(
      "Summarize numeric column",
      select(
        on_change=emit.map(value => {
          BriefAction(
            Csv(NumericColumn(@string.parse_int(value) catch { _ => 0 })),
          )
        }),
        [
          option(
            value="0",
            selected=view.csv.numeric_column == 0,
            "Choose a column",
          ),
        ] +
        intake.columns.mapi((i, name) => {
          option(
            value=(i + 1).to_string(),
            selected=view.csv.numeric_column == i + 1,
            name,
          )
        }),
      ),
    ),
    field_label(
      "Numeric summary scope",
      select(
        on_change=emit.map(value => BriefAction(Csv(NumericScope(value)))),
        [
          option(
            value="all",
            selected=view.csv.numeric_scope == "all",
            "All imported rows",
          ),
          option(
            value="matching",
            selected=view.csv.numeric_scope == "matching",
            "Current matching rows",
          ),
          option(
            value="selected",
            selected=view.csv.numeric_scope == "selected",
            "Selected rows, including hidden rows",
          ),
        ],
      ),
    ),
    csv_numeric_range_panel(emit, view),
    match result {
      None =>
        p(
          "Choose the column whose values you want to summarize. No numeric column is inferred.",
        )
      Some(result) =>
        div(style=["display:grid", "gap:10px"], [
          p(
            "\{result.cells.length()} scoped rows · \{result.numeric_count} numeric · \{result.blank_count} blank · \{result.invalid_count} invalid",
          ),
          p(
            "Minimum: " +
            csv_numeric_value(result.minimum) +
            " · Maximum: " +
            csv_numeric_value(result.maximum),
          ),
          p(
            "Sum: " +
            csv_numeric_value(result.sum) +
            " · Mean: " +
            csv_numeric_value(result.mean),
          ),
          p(result.arithmetic_issue),
          field_label(
            "Inspect contributing or excluded source records",
            select(
              on_change=emit.map(value => BriefAction(Csv(NumericDetail(value)))),
              [
                option(
                  value="numeric",
                  selected=view.csv.numeric_detail == "numeric",
                  "Numeric values",
                ),
                option(
                  value="blank",
                  selected=view.csv.numeric_detail == "blank",
                  "Blank cells",
                ),
                option(
                  value="invalid",
                  selected=view.csv.numeric_detail == "invalid",
                  "Invalid numeric cells",
                ),
                option(
                  value="minimum",
                  selected=view.csv.numeric_detail == "minimum",
                  "Minimum value records (all ties)",
                ),
                option(
                  value="maximum",
                  selected=view.csv.numeric_detail == "maximum",
                  "Maximum value records (all ties)",
                ),
              ],
            ),
          ),
          p(
            "Drill-down preserves the complete source rows and logical record numbers. Changing summary or drill-down does not change the evidence selection, search or output columns.",
          ),
          csv_table(
            intake.columns,
            intake.rows.filter(row => {
              csv_numeric_details(result, view.csv.numeric_detail).contains(
                row.record_number,
              )
            }),
          ),
          details([
            summary("Excluded numeric cells and reasons"),
            div(
              result.cells
              .filter(cell => !cell.issue.is_empty())
              .map(cell => {
                p(
                  "Record \{cell.record_number}: " +
                  cell.original.to_json().stringify() +
                  " · " +
                  cell.issue,
                )
              }),
            ),
          ]),
          p(
            "Download includes the entire original CSV, even for matching or selected rows, plus exact cell text and source record membership. Review before sharing. Downloading does not save this session-only exploration or the brief.",
          ),
          action_button(
            "Download numeric summary JSON",
            emit(BriefAction(Csv(DownloadNumeric))),
          ),
        ])
    },
  ])
}
