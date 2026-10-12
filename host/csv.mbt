///|
pub(all) struct CsvIntakeRequestV1 {
  source : @research.BriefSourceInputV1
  query : String
  column_number : Int
} derive(Debug, ToJson, FromJson)

///|
pub(all) struct CsvIntakeV1 {
  source : @research.BriefSourceInputV1
  columns : Array[String]
  rows : Array[@research.CsvRowV1]
  total_count : Int
} derive(Debug, ToJson, FromJson)

///|
pub(all) struct CsvSelectRequestV1 {
  source : @research.BriefSourceInputV1
  record_numbers : Array[Int]
  column_numbers : Array[Int]
} derive(Debug, ToJson, FromJson)

///|
fn csv_source_text(source : @research.BriefSourceInputV1) -> String raise {
  guard @research.brief_filename(source.name) &&
    source.name.to_lower().has_suffix(".csv") &&
    !source.origin.is_blank() &&
    source.origin.length() <= 2000 &&
    !source.captured_at.is_blank() &&
    source.captured_at.length() <= 80 &&
    (source.kind == "local-file" || source.kind == "pasted-text") &&
    source.content_hex.length() <= 65536 &&
    source.content_hex.length() % 2 == 0 &&
    source.content_hex.all(ch => {
      (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f')
    }) else {
    fail(
      "Choose a UTF-8 .csv source up to 32 KiB with its origin and capture time",
    )
  }
  @utf8.decode(brief_source_bytes(source))
}

///|
/// Explore supplied CSV bytes only. Cell URLs and spreadsheet formulas are text.
pub fn intake_csv(request : CsvIntakeRequestV1) -> CsvIntakeV1 raise {
  let table = @research.parse_csv(csv_source_text(request.source))
  {
    source: request.source,
    columns: table.columns,
    rows: @research.filter_csv(table, request.query, request.column_number),
    total_count: table.rows.length(),
  }
}

///|
/// Add original bytes plus a row/column selection companion to an ordinary brief.
pub fn select_csv(
  request : CsvSelectRequestV1,
) -> Array[@research.BriefSourceInputV1] raise {
  let text = csv_source_text(request.source)
  let table = @research.parse_csv(text)
  let selected = @research.project_csv(
    table,
    request.record_numbers,
    request.column_numbers,
  )
  let column_numbers : Array[Int] = []
  for index = 0; index < table.columns.length(); index = index + 1 {
    if request.column_numbers.contains(index + 1) {
      column_numbers.push(index + 1)
    }
  }
  let selection : @research.CsvSelectionV1 = {
    contract_id: "moonfind.csv-selection.v1",
    source_name: request.source.name,
    source_digest: @store.digest_text(text),
    source_row_count: table.rows.length(),
    column_numbers,
    columns: selected.columns,
    rows: selected.rows,
  }
  let bytes = @utf8.encode(selection.to_json().stringify(indent=2) + "\n")
  guard bytes.length() <= 32768 else {
    fail("Selected CSV rows exceed 32 KiB; select fewer rows or columns")
  }
  let hex = StringBuilder()
  let digits = "0123456789abcdef"
  for byte in bytes {
    hex.write_char(digits.get_char(byte.to_int() / 16).unwrap())
    hex.write_char(digits.get_char(byte.to_int() % 16).unwrap())
  }
  [
    request.source,
    {
      name: "csv-selection.json",
      origin: "Selected CSV records from " + request.source.name,
      captured_at: request.source.captured_at,
      kind: "pasted-text",
      content_hex: hex.to_string(),
    },
  ]
}

///|
fn csv_markdown_cell(value : String) -> String {
  let out = StringBuilder()
  for ch in value {
    match ch {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '\r' => ()
      '\n' => out.write_string("<br>")
      '\\' | '|' | '*' | '_' | '[' | ']' | '`' => {
        out.write_char('\\')
        out.write_char(ch)
      }
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn csv_readable_selections(brief : @research.ResearchBriefV1) -> String {
  let out = StringBuilder()
  for source in brief.sources {
    if source.name == "csv-selection.json" {
      let selection : @research.CsvSelectionV1? = Some(
        @json.from_json(@json.parse(@utf8.decode(brief_source_bytes(source)))),
      ) catch {
        _ => None
      }
      if selection is Some(selection) &&
        selection.contract_id == "moonfind.csv-selection.v1" {
        out.write_string(
          "## Selected CSV evidence rows\n\nSource: " +
          csv_markdown_cell(selection.source_name) +
          "\nSource digest: " +
          selection.source_digest +
          "\n\nSelected \{selection.rows.length()} of \{selection.source_row_count} data records. Source record 1 is the header; multiline cells do not increment record numbers. Cells are supplied observations, not verified conclusions. The complete original CSV remains in the dossier, including unselected rows and columns.\n\n",
        )
        out.write_string(
          "| Source record | " +
          selection.columns.map(csv_markdown_cell).join(" | ") +
          " |\n",
        )
        out.write_string(
          "| --- | " + selection.columns.map(_ => "---").join(" | ") + " |\n",
        )
        for row in selection.rows {
          out.write_string(
            "| \{row.record_number} | " +
            row.values.map(csv_markdown_cell).join(" | ") +
            " |\n",
          )
        }
        out.write_string("\n")
      }
    }
  }
  out.to_string()
}
