///|
struct CsvComparisonGroup {
  category : String
  summary : CsvNumericSummary
} derive(Debug, Eq)

///|
fn csv_comparison(view : CsvView) -> Array[CsvComparisonGroup] raise {
  // Validate both explicit fields, including empty scopes.
  ignore(csv_numeric_summary(view))
  let intake = view.intake.unwrap()
  guard view.comparison_column > 0 &&
    view.comparison_column <= intake.columns.length() else {
    fail("Choose a comparison category column explicitly.")
  }
  let groups : Map[String, Array[CsvNumericCell]] = Map([])
  for row in csv_numeric_rows(view) {
    let category = row.values[view.comparison_column - 1]
    let cell = csv_numeric_parse(
      row.values[view.numeric_column - 1],
      row.record_number,
    )
    match groups.get(category) {
      Some(cells) => cells.push(cell)
      None => groups[category] = [cell]
    }
  }
  groups
  .iter()
  .map(pair => CsvComparisonGroup::{
    category: pair.0,
    summary: csv_numeric_summarize_cells(pair.1),
  })
  .to_array()
}

///|
fn csv_comparison_export(view : CsvView) -> String raise {
  let groups = csv_comparison(view)
  let intake = view.intake.unwrap()
  (
    {
      "contract_id": "moonfind.csv-category-comparison.v1",
      "source": ToJson::to_json(intake.source),
      "source_data_rows": intake.total_count,
      "category_column_number": view.comparison_column,
      "category_column_name": intake.columns[view.comparison_column - 1],
      "numeric_column_number": view.numeric_column,
      "numeric_column_name": intake.columns[view.numeric_column - 1],
      "scope": view.numeric_scope,
      "scoped_record_numbers": csv_numeric_rows(view)
      .map(row => row.record_number)
      .to_json(),
      "active_search": {
        "query": view.query,
        "column_number": view.column_number,
        "applied": view.numeric_scope == "matching",
      },
      "groups": groups
      .map(group => {
        (
          {
            "category": group.category,
            "summary": csv_numeric_summary_json(group.summary),
          } : Json)
      })
      .to_json(),
      "semantics": "Exact category strings, including empty cells; no trimming, case folding or Unicode normalization. Groups follow first source occurrence; cells follow source order. Numeric grammar and compensated binary64 arithmetic match the numeric summary. Blank and invalid numeric cells are excluded, never zero-filled. Every unavailable statistic and excluded value is explicit null. Groups are descriptive; no ranking, weighting, significance or unit inference.",
      "boundary": "Includes the entire original CSV as content_hex, including hidden and unselected records. Review before sharing; not redaction. Supplied metadata is not authenticated. Downloading does not save the brief or validate observations. Session-only exploration.",
    } : Json).stringify(indent=2)
}

///|
extern "js" fn csv_comparison_download(content : String) -> String =
  #|content => {
  #| let url;
  #| try {
  #|   url=URL.createObjectURL(new Blob([content],{type:'application/json;charset=utf-8'}));
  #|   const link=document.createElement('a'); link.href=url; link.download='moonfind-csv-category-comparison.json';
  #|   document.body.appendChild(link); link.click(); link.remove(); return '';
  #| } catch (_) { return 'Category comparison download failed; intake remains available. Try again.'; }
  #| finally { if(url) setTimeout(() => URL.revokeObjectURL(url),1000); }
  #|}

///|
fn csv_comparison_panel(
  emit : @rabbita.Emit[Msg],
  view : BriefView,
) -> @rabbita.Html {
  guard view.csv.intake is Some(intake) else { return div("") }
  let result = Some(csv_comparison(view.csv)) catch { _ => None }
  details(open=true, [
    summary("Compare numeric values by category"),
    p(
      "Uses the explicitly chosen numeric column and scope above. Choose a category column below to compare groups without changing row selection or output columns. Categories are exact strings, including empty cells; order is first source occurrence. Unequal group sizes and missing values remain visible. Descriptive comparison is not evidence of causation or statistical significance.",
    ),
    field_label(
      "Comparison category column",
      select(
        on_change=emit.map(value => {
          BriefAction(
            Csv(ComparisonColumn(@string.parse_int(value) catch { _ => 0 })),
          )
        }),
        [
          option(
            value="0",
            selected=view.csv.comparison_column == 0,
            "Choose a category column",
          ),
        ] +
        intake.columns.mapi((i, name) => {
          option(
            value=(i + 1).to_string(),
            selected=view.csv.comparison_column == i + 1,
            name,
          )
        }),
      ),
    ),
    match result {
      None =>
        p(
          "Choose both the numeric column above and comparison category column. No column is inferred.",
        )
      Some(groups) =>
        div([
          p(
            "\{groups.length()} categories in scope: " +
            view.csv.numeric_scope +
            ". Numeric column: " +
            intake.columns[view.csv.numeric_column - 1],
          ),
          if groups.is_empty() {
            p(
              "No records in this scope. No categories or statistics are invented.",
            )
          } else {
            div("")
          },
          csv_table(
            [
              "Category (exact JSON string)", "Rows", "Numeric", "Blank", "Invalid",
              "Minimum", "Maximum", "Sum", "Mean",
            ],
            record_label="Group",
            groups.mapi((i, group) => {
              let stats = group.summary
              CsvRow::{
                record_number: i + 1,
                values: [
                  group.category.to_json().stringify(),
                  stats.cells.length().to_string(),
                  stats.numeric_count.to_string(),
                  stats.blank_count.to_string(),
                  stats.invalid_count.to_string(),
                  csv_numeric_value(stats.minimum),
                  csv_numeric_value(stats.maximum),
                  csv_numeric_value(stats.sum),
                  csv_numeric_value(stats.mean),
                ],
              }
            }),
          ),
          div(
            groups.map(group => {
              details([
                summary(
                  "Source records for " + group.category.to_json().stringify(),
                ),
                p(group.summary.arithmetic_issue),
                csv_table(
                  intake.columns,
                  intake.rows.filter(row => {
                    group.summary.cells.any(cell => {
                      cell.record_number == row.record_number
                    })
                  }),
                ),
                div(
                  group.summary.cells
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
              ])
            }),
          ),
          p(
            "Download contains every group's exact cells and logical source-record numbers, plus the entire original CSV, including hidden and unselected data. Review before sharing; this is not redaction. Download does not save the brief.",
          ),
          action_button(
            "Download category comparison JSON",
            emit(BriefAction(Csv(DownloadComparison))),
          ),
        ])
    },
  ])
}
