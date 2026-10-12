///|
struct CsvNumericCell {
  record_number : Int
  original : String
  value : Double?
  issue : String
} derive(Debug, Eq)

///|
struct CsvNumericSummary {
  cells : Array[CsvNumericCell]
  numeric_count : Int
  blank_count : Int
  invalid_count : Int
  minimum : Double?
  maximum : Double?
  sum : Double?
  mean : Double?
  arithmetic_issue : String
} derive(Debug, Eq)

///|
fn csv_numeric_finite(value : Double) -> Bool {
  value >= -1.7976931348623157e308 && value <= 1.7976931348623157e308
}

///|
// Only ASCII space, tab and physical line-break padding is ignored.
fn csv_numeric_trim(value : String) -> String {
  let chars = value.to_array()
  let mut first = 0
  let mut last = chars.length()
  while first < last && chars[first] is (' ' | '\t' | '\r' | '\n') {
    first += 1
  }
  while last > first && chars[last - 1] is (' ' | '\t' | '\r' | '\n') {
    last -= 1
  }
  String::from_array(chars[first:last].to_owned())
}

///|
// Accept the complete decimal token, never a locale number or numeric prefix.
fn csv_numeric_parse(original : String, record_number : Int) -> CsvNumericCell {
  let text = csv_numeric_trim(original)
  let cell : CsvNumericCell = {
    record_number,
    original,
    value: None,
    issue: "",
  }
  if text.is_empty() {
    return { ..cell, issue: "blank", }
  }
  let chars = text.to_array()
  let mut i = 0
  if chars[i] is ('+' | '-') {
    i += 1
  }
  let mut digits = 0
  let mut nonzero = false
  while i < chars.length() && chars[i] is ('0'..='9') {
    nonzero = nonzero || chars[i] != '0'
    digits += 1
    i += 1
  }
  if i < chars.length() && chars[i] == '.' {
    i += 1
    while i < chars.length() && chars[i] is ('0'..='9') {
      nonzero = nonzero || chars[i] != '0'
      digits += 1
      i += 1
    }
  }
  if digits == 0 {
    return { ..cell, issue: "not_decimal", }
  }
  if i < chars.length() && chars[i] is ('e' | 'E') {
    i += 1
    if i < chars.length() && chars[i] is ('+' | '-') {
      i += 1
    }
    let start = i
    while i < chars.length() && chars[i] is ('0'..='9') {
      i += 1
    }
    if i == start {
      return { ..cell, issue: "not_decimal", }
    }
  }
  if i != chars.length() {
    return { ..cell, issue: "not_decimal", }
  }
  let value = @string.parse_double(text) catch {
    _ => return { ..cell, issue: "out_of_range", }
  }
  if !csv_numeric_finite(value) {
    return { ..cell, issue: "out_of_range", }
  }
  if value == 0.0 && nonzero {
    return { ..cell, issue: "underflow_to_zero", }
  }
  { ..cell, value: Some(value), }
}

///|
fn csv_numeric_rows(view : CsvView) -> Array[CsvRow] {
  guard view.intake is Some(intake) else { return [] }
  match view.numeric_scope {
    "all" => intake.rows
    "matching" => csv_filtered(view)
    "selected" =>
      intake.rows.filter(row => view.selected.contains(row.record_number))
    _ => []
  }
}

///|
fn csv_numeric_summary(view : CsvView) -> CsvNumericSummary raise {
  guard view.intake is Some(intake) &&
    view.numeric_column > 0 &&
    view.numeric_column <= intake.columns.length() else {
    fail("Choose a numeric column explicitly after importing a CSV.")
  }
  guard ["all", "matching", "selected"].contains(view.numeric_scope) else {
    fail("Choose all, matching or selected rows.")
  }
  let cells = csv_numeric_rows(view).map(row => {
    csv_numeric_parse(row.values[view.numeric_column - 1], row.record_number)
  })
  csv_numeric_summarize_cells(cells)
}

///|
fn csv_numeric_summarize_cells(
  cells : Array[CsvNumericCell],
) -> CsvNumericSummary {
  let values = cells.filter_map(cell => cell.value)
  let mut minimum : Double? = None
  let mut maximum : Double? = None
  let mut sum = 0.0
  let mut compensation = 0.0
  let mut overflow = false
  // Neumaier compensated addition in source order; never serialize non-finite values.
  for value in values {
    minimum = Some(
      match minimum {
        Some(old) => if value < old { value } else { old }
        None => value
      },
    )
    maximum = Some(
      match maximum {
        Some(old) => if value > old { value } else { old }
        None => value
      },
    )
    if !overflow {
      let next = sum + value
      if !csv_numeric_finite(next) {
        overflow = true
      } else {
        compensation += if sum.abs() >= value.abs() {
          sum - next + value
        } else {
          value - next + sum
        }
        sum = next
        if !csv_numeric_finite(compensation) {
          overflow = true
        }
      }
    }
  }
  let total = sum + compensation
  if !csv_numeric_finite(total) {
    overflow = true
  }
  let available = !values.is_empty() && !overflow
  let mean = if available {
    Some(total / values.length().to_double())
  } else {
    None
  }
  {
    cells,
    numeric_count: values.length(),
    blank_count: cells.filter(cell => cell.issue == "blank").length(),
    invalid_count: cells
    .filter(cell => !cell.issue.is_empty() && cell.issue != "blank")
    .length(),
    minimum,
    maximum,
    sum: if available {
      Some(total)
    } else {
      None
    },
    mean,
    arithmetic_issue: if overflow {
      "Running sum overflowed; sum and mean are unavailable."
    } else if values.is_empty() {
      "No numeric values; all statistics are unavailable."
    } else {
      ""
    },
  }
}

///|
fn csv_numeric_details(
  summary : CsvNumericSummary,
  detail : String,
) -> Array[Int] {
  summary.cells
  .filter(cell => {
    match detail {
      "numeric" => cell.value is Some(_)
      "blank" => cell.issue == "blank"
      "invalid" => !cell.issue.is_empty() && cell.issue != "blank"
      "minimum" => cell.value is Some(_) && cell.value == summary.minimum
      "maximum" => cell.value is Some(_) && cell.value == summary.maximum
      _ => false
    }
  })
  .map(cell => cell.record_number)
}

///|
fn csv_numeric_optional_json(value : Double?) -> Json {
  match value {
    Some(value) => value.to_json()
    None => Json::null()
  }
}

///|
// Keep every key present: unavailable statistics and excluded cells are JSON null.
// Derived struct serialization omits None fields, which violates this contract.
fn csv_numeric_summary_json(result : CsvNumericSummary) -> Json {
  {
    "cells": result.cells
    .map(cell => {
      (
        {
          "record_number": cell.record_number,
          "original": cell.original,
          "value": csv_numeric_optional_json(cell.value),
          "issue": cell.issue,
        } : Json)
    })
    .to_json(),
    "numeric_count": result.numeric_count,
    "blank_count": result.blank_count,
    "invalid_count": result.invalid_count,
    "minimum": csv_numeric_optional_json(result.minimum),
    "maximum": csv_numeric_optional_json(result.maximum),
    "sum": csv_numeric_optional_json(result.sum),
    "mean": csv_numeric_optional_json(result.mean),
    "arithmetic_issue": result.arithmetic_issue,
  }
}

///|
fn csv_numeric_export(view : CsvView) -> String raise {
  let result = csv_numeric_summary(view)
  let intake = view.intake.unwrap()
  (
    {
      "contract_id": "moonfind.csv-numeric-summary.v1",
      "source": ToJson::to_json(intake.source),
      "source_data_rows": intake.total_count,
      "column_number": view.numeric_column,
      "column_name": intake.columns[view.numeric_column - 1],
      "scope": view.numeric_scope,
      "scoped_record_numbers": result.cells
      .map(cell => cell.record_number)
      .to_json(),
      "active_search": {
        "query": view.query,
        "column_number": view.column_number,
        "applied": view.numeric_scope == "matching",
      },
      "summary": csv_numeric_summary_json(result),
      "semantics": "Explicit column. ASCII decimal with optional sign, decimal point and e/E exponent; ASCII space/tab/CR/LF padding ignored. No commas, currency, percent, units, hex, Unicode digits, NaN or Infinity. Blank and invalid cells excluded, never zero-filled. Finite IEEE-754 binary64 values; rounding is approximate. Underflow to zero rejected. Neumaier sum in source order; sum overflow makes sum and mean unavailable. Null is unavailable, not zero. Min/max ties compare parsed binary64 values. Record 1 is the header.",
      "boundary": "Includes the entire original CSV as content_hex, including hidden and unselected data. Review before sharing; not redaction. Supplied metadata and bytes are not authenticated. This session-only reading artifact does not save the brief, validate observations, establish representative sampling or imply statistical significance or completed research.",
    } : Json).stringify(indent=2)
}

///|
extern "js" fn csv_numeric_download(content : String) -> String =
  #|content => {
  #| let url;
  #| try {
  #|   url=URL.createObjectURL(new Blob([content],{type:'application/json;charset=utf-8'}));
  #|   const link=document.createElement('a'); link.href=url; link.download='moonfind-csv-numeric-summary.json';
  #|   document.body.appendChild(link); link.click(); link.remove(); return '';
  #| } catch (_) { return 'Numeric summary download failed; intake remains available. Try again.'; }
  #| finally { if(url) setTimeout(() => URL.revokeObjectURL(url),1000); }
  #|}
