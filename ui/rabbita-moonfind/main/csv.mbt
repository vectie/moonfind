///|
struct CsvRow {
  record_number : Int
  values : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
struct CsvIntake {
  source : BriefInputSource
  columns : Array[String]
  rows : Array[CsvRow]
  total_count : Int
} derive(Debug, FromJson)

///|
struct CsvSelection {
  contract_id : String
  source_name : String
  source_digest : String
  source_row_count : Int
  column_numbers : Array[Int]
  columns : Array[String]
  rows : Array[CsvRow]
} derive(Debug, FromJson)

///|
struct CsvView {
  intake : CsvIntake?
  query : String
  column_number : Int
  selected : Array[Int]
  columns : Array[Int]
  category_column : Int
  category_filtered : Bool
  comparison_column : Int
  numeric_column : Int
  numeric_scope : String
  numeric_detail : String
  extract_scope : String
}

///|
enum CsvMsg {
  Choose
  FileLoaded(Int, String)
  Imported(Int, Result[Json, Error])
  Filter(String)
  SearchColumn(Int)
  CategoryColumn(Int)
  CategoryScope(Bool)
  SelectCategory(String)
  DownloadCategories
  NumericColumn(Int)
  NumericScope(String)
  NumericDetail(String)
  DownloadNumeric
  ComparisonColumn(Int)
  DownloadComparison
  ExtractScope(String)
  DownloadExtract
  Toggle(Int)
  ToggleColumn(Int)
  SelectMatching
  ClearRows
  AddSelected
  Selected(Int, Result[Json, Error])
}

///|
fn empty_csv_view() -> CsvView {
  {
    intake: None,
    query: "",
    column_number: 0,
    selected: [],
    columns: [],
    category_column: 1,
    category_filtered: false,
    numeric_column: 0,
    comparison_column: 0,
    numeric_scope: "all",
    numeric_detail: "numeric",
    extract_scope: "selected",
  }
}

///|
extern "js" fn csv_lower(value : String) -> String =
  #|value => Array.from(value, ch => ch.toLowerCase()).join('')

///|
fn csv_filtered(view : CsvView) -> Array[CsvRow] {
  let query = csv_lower(view.query.trim().to_owned())
  view.intake
  .map(intake => {
    intake.rows.filter(row => {
      if view.column_number == 0 {
        row.values.any(value => csv_lower(value).contains(query))
      } else {
        row.values
        .get(view.column_number - 1)
        .map(value => csv_lower(value).contains(query))
        .unwrap_or(false)
      }
    })
  })
  .unwrap_or([])
}

///|
fn csv_toggle(values : Array[Int], number : Int) -> Array[Int] {
  if values.contains(number) {
    values.filter(value => value != number)
  } else {
    values + [number]
  }
}

///|
fn update_csv_view(
  emit : @rabbita.Emit[Msg],
  action : CsvMsg,
  view : BriefView,
) -> (@rabbita.Cmd, BriefView) {
  match action {
    Choose
    | Filter(_)
    | SearchColumn(_)
    | CategoryColumn(_)
    | CategoryScope(_)
    | SelectCategory(_)
    | DownloadCategories
    | NumericColumn(_)
    | NumericScope(_)
    | NumericDetail(_)
    | DownloadNumeric
    | ComparisonColumn(_)
    | DownloadComparison
    | ExtractScope(_)
    | DownloadExtract
    | Toggle(_)
    | ToggleColumn(_)
    | SelectMatching
    | ClearRows
    | AddSelected if view.pending => (@rabbita.none, view)
    Choose => {
      let generation = view.generation
      (
        @cmd.custom_cmd(scheduler => {
          brief_choose_files(
            raw => {
              scheduler.add(emit(BriefAction(Csv(FileLoaded(generation, raw)))))
            },
            ".csv",
            false,
          )
        }),
        view,
      )
    }
    FileLoaded(generation, _) if generation != view.generation || view.pending =>
      (@rabbita.none, view)
    FileLoaded(_, raw) =>
      try {
        let payload = @json.parse(raw)
        if payload is { "error": String(message), .. } {
          fail(message)
        }
        guard payload is { "sources": sources, .. } else {
          fail("No CSV file selected")
        }
        let sources : Array[BriefInputSource] = @json.from_json(sources)
        if sources.is_empty() {
          return (@rabbita.none, view)
        }
        guard sources.length() == 1 else {
          fail("Import one CSV table at a time")
        }
        let generation = view.generation + 1
        (
          @http.post(product_api_url("/api/v1/briefs/csv/intake"))
          .with_json({
            "source": sources[0].to_json(),
            "query": "",
            "column_number": 0,
          })
          .expect_json(
            emit.map(reply => BriefAction(Csv(Imported(generation, reply)))),
          ),
          { ..view, generation, pending: true, error: None, },
        )
      } catch {
        error => (@rabbita.none, { ..view, error: Some("\{error}"), })
      }
    Imported(generation, _) | Selected(generation, _) if generation !=
      view.generation ||
      !view.pending => (@rabbita.none, view)
    Imported(_, Err(error)) | Selected(_, Err(error)) =>
      (@rabbita.none, { ..view, pending: false, error: Some("\{error}"), })
    Imported(_, Ok(payload)) =>
      try {
        if brief_reply_error(payload) is Some(message) {
          fail(message)
        }
        let intake : CsvIntake = @json.from_json(payload)
        (
          @rabbita.none,
          {
            ..view,
            pending: false,
            csv: {
              intake: Some(intake),
              query: "",
              column_number: 0,
              selected: [],
              columns: Array::makei(intake.columns.length(), i => i + 1),
              category_column: 1,
              category_filtered: false,
              numeric_column: 0,
              comparison_column: 0,
              numeric_scope: "all",
              numeric_detail: "numeric",
              extract_scope: "selected",
            },
            error: None,
          },
        )
      } catch {
        error =>
          (@rabbita.none, { ..view, pending: false, error: Some("\{error}"), })
      }
    Filter(query) => (@rabbita.none, { ..view, csv: { ..view.csv, query, }, })
    CategoryColumn(number) => {
      guard view.csv.intake is Some(intake) &&
        number > 0 &&
        number <= intake.columns.length() else {
        return (@rabbita.none, view)
      }
      (
        @rabbita.none,
        { ..view, csv: { ..view.csv, category_column: number, }, },
      )
    }
    CategoryScope(filtered) =>
      (
        @rabbita.none,
        { ..view, csv: { ..view.csv, category_filtered: filtered, }, },
      )
    SelectCategory(value) => {
      let groups = csv_categories(view.csv)
      guard groups.filter(group => group.value == value).get(0) is Some(group) else {
        return (@rabbita.none, view)
      }
      (
        @rabbita.none,
        { ..view, csv: { ..view.csv, selected: group.record_numbers.copy(), }, },
      )
    }
    DownloadCategories => {
      let error = csv_categories_download(csv_categories_export(view.csv)) catch {
        error => "\{error}"
      }
      (
        @rabbita.none,
        { ..view, error: if error.is_empty() { None } else { Some(error) }, },
      )
    }
    ComparisonColumn(number) => {
      guard view.csv.intake is Some(intake) &&
        number >= 0 &&
        number <= intake.columns.length() else {
        return (@rabbita.none, view)
      }
      (
        @rabbita.none,
        { ..view, csv: { ..view.csv, comparison_column: number, }, },
      )
    }
    DownloadComparison => {
      let error = csv_comparison_download(csv_comparison_export(view.csv)) catch {
        error => "\{error}"
      }
      (
        @rabbita.none,
        { ..view, error: if error.is_empty() { None } else { Some(error) }, },
      )
    }
    NumericColumn(number) => {
      guard view.csv.intake is Some(intake) &&
        number >= 0 &&
        number <= intake.columns.length() else {
        return (@rabbita.none, view)
      }
      (@rabbita.none, { ..view, csv: { ..view.csv, numeric_column: number, }, })
    }
    NumericScope(scope) => {
      guard ["all", "matching", "selected"].contains(scope) else {
        return (@rabbita.none, view)
      }
      (@rabbita.none, { ..view, csv: { ..view.csv, numeric_scope: scope, }, })
    }
    NumericDetail(detail) => {
      guard ["numeric", "blank", "invalid", "minimum", "maximum"].contains(
        detail,
      ) else {
        return (@rabbita.none, view)
      }
      (@rabbita.none, { ..view, csv: { ..view.csv, numeric_detail: detail, }, })
    }
    DownloadNumeric => {
      let error = csv_numeric_download(csv_numeric_export(view.csv)) catch {
        error => "\{error}"
      }
      (
        @rabbita.none,
        { ..view, error: if error.is_empty() { None } else { Some(error) }, },
      )
    }
    ExtractScope(scope) => {
      guard ["all", "matching", "selected"].contains(scope) else {
        return (@rabbita.none, view)
      }
      (@rabbita.none, { ..view, csv: { ..view.csv, extract_scope: scope, }, })
    }
    DownloadExtract => {
      let error = csv_extract_download(csv_extract_text(view.csv)) catch {
        error => "\{error}"
      }
      (
        @rabbita.none,
        { ..view, error: if error.is_empty() { None } else { Some(error) }, },
      )
    }
    SearchColumn(column_number) =>
      (@rabbita.none, { ..view, csv: { ..view.csv, column_number, }, })
    Toggle(number) =>
      (
        @rabbita.none,
        {
          ..view,
          csv: { ..view.csv, selected: csv_toggle(view.csv.selected, number), },
        },
      )
    ToggleColumn(number) =>
      (
        @rabbita.none,
        {
          ..view,
          csv: { ..view.csv, columns: csv_toggle(view.csv.columns, number), },
        },
      )
    ClearRows =>
      (@rabbita.none, { ..view, csv: { ..view.csv, selected: [], }, })
    SelectMatching => {
      let selected = view.csv.selected.copy()
      for row in csv_filtered(view.csv) {
        if !selected.contains(row.record_number) {
          selected.push(row.record_number)
        }
      }
      (@rabbita.none, { ..view, csv: { ..view.csv, selected, }, })
    }
    AddSelected => {
      guard view.csv.intake is Some(intake) &&
        !view.csv.selected.is_empty() &&
        !view.csv.columns.is_empty() else {
        return (
          @rabbita.none,
          {
            ..view,
            error: Some("Select at least one data row and one output column"),
          },
        )
      }
      guard view.draft.sources.length() <= 6 else {
        return (
          @rabbita.none,
          {
            ..view,
            error: Some(
              "CSV selection uses two source slots: the complete original file and selected rows",
            ),
          },
        )
      }
      let generation = view.generation + 1
      (
        @http.post(product_api_url("/api/v1/briefs/csv/select"))
        .with_json({
          "source": intake.source.to_json(),
          "record_numbers": view.csv.selected.to_json(),
          "column_numbers": view.csv.columns.to_json(),
        })
        .expect_json(
          emit.map(reply => BriefAction(Csv(Selected(generation, reply)))),
        ),
        { ..view, generation, pending: true, error: None, },
      )
    }
    Selected(_, Ok(payload)) =>
      try {
        if brief_reply_error(payload) is Some(message) {
          fail(message)
        }
        let sources : Array[BriefInputSource] = @json.from_json(payload)
        (
          @rabbita.none,
          {
            ..brief_edited(view, {
              ..view.draft,
              sources: view.draft.sources + sources,
            }),
            pending: false,
            csv: empty_csv_view(),
          },
        )
      } catch {
        error =>
          (@rabbita.none, { ..view, pending: false, error: Some("\{error}"), })
      }
  }
}
