///|
fn csv_numeric_bound(text : String, label : String) -> Double? raise {
  let parsed = csv_numeric_parse(text, 0)
  if parsed.issue == "blank" {
    return None
  }
  guard parsed.value is Some(value) else {
    fail(label + " must be a finite decimal number: " + parsed.issue)
  }
  Some(value)
}

///|
fn csv_numeric_range(view : CsvView) -> Array[CsvRow] raise {
  let lower = csv_numeric_bound(view.numeric_lower, "Lower bound")
  let upper = csv_numeric_bound(view.numeric_upper, "Upper bound")
  guard lower is Some(_) || upper is Some(_) else {
    fail("Enter at least one bound; leave the other blank for an open end.")
  }
  if lower is Some(lo) && upper is Some(hi) && lo > hi {
    fail("Lower bound must not exceed upper bound.")
  }
  let summary = csv_numeric_summary(view)
  let ids = summary.cells
    .filter(cell => {
      match cell.value {
        None => false
        Some(value) =>
          lower.map(lo => value >= lo).unwrap_or(true) &&
          upper.map(hi => value <= hi).unwrap_or(true)
      }
    })
    .map(cell => cell.record_number)
  view.intake.unwrap().rows.filter(row => ids.contains(row.record_number))
}

///|
fn csv_numeric_range_panel(
  emit : @rabbita.Emit[Msg],
  view : BriefView,
) -> @rabbita.Html {
  let result = Ok(csv_numeric_range(view.csv)) catch {
    error => Err("\{error}")
  }
  div([
    p(
      "Numeric range: inclusive bounds in the chosen numeric column and summary scope. Blank cells and invalid numbers never match. Comparisons use approximate binary64 values. Editing the range does not alter existing selections.",
    ),
    field_label(
      "Lower bound (inclusive)",
      text_field(
        view.csv.numeric_lower,
        "For example -2.5",
        emit.map(value => BriefAction(Csv(NumericLower(value)))),
      ),
    ),
    field_label(
      "Upper bound (inclusive)",
      text_field(
        view.csv.numeric_upper,
        "For example 1e2",
        emit.map(value => BriefAction(Csv(NumericUpper(value)))),
      ),
    ),
    match result {
      Err(message) => p(message)
      Ok(rows) =>
        div([
          p(
            "\{rows.length()} matching source records. Inspect the full rows below, select individual records or select all range rows, then use the existing Add selected CSV evidence action. Other selected rows remain selected.",
          ),
          csv_table(view.csv.intake.unwrap().columns, rows, choose=row => {
            action_button(
              if view.csv.selected.contains(row.record_number) {
                "Deselect"
              } else {
                "Select"
              },
              emit(BriefAction(Csv(Toggle(row.record_number)))),
            )
          }),
          action_button(
            "Select all range rows",
            emit(BriefAction(Csv(SelectNumericRange))),
          ),
        ])
    },
  ])
}
