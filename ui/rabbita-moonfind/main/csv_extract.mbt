///|
struct CsvExtract {
  columns : Array[String]
  rows : Array[CsvRow]
} derive(Debug, Eq)

///|
// Project in source order, irrespective of selection click order. This never
// includes the original source object or any unchosen cell in the download.
fn csv_extract(view : CsvView) -> CsvExtract raise {
  guard view.intake is Some(intake) else {
    fail("Import a CSV table before downloading an extract.")
  }
  guard ["all", "matching", "selected"].contains(view.extract_scope) else {
    fail("Choose all, matching or selected rows for the CSV extract.")
  }
  let positions = Array::makei(intake.columns.length(), i => i).filter(i => {
    view.columns.contains(i + 1)
  })
  guard !positions.is_empty() else {
    fail("Choose at least one output column for the CSV extract.")
  }
  let rows = match view.extract_scope {
    "all" => intake.rows
    "matching" => csv_filtered(view)
    "selected" =>
      intake.rows.filter(row => view.selected.contains(row.record_number))
    _ => []
  }
  let projected : Array[CsvRow] = []
  for row in rows {
    guard row.values.length() == intake.columns.length() else {
      fail("CSV row shape changed. Import the table again before exporting.")
    }
    projected.push({
      record_number: row.record_number,
      values: positions.map(i => row.values[i]),
    })
  }
  { columns: positions.map(i => intake.columns[i]), rows: projected, }
}

///|
// Quote every field, including empty strings and headers. Quotes are doubled;
// record separators are CRLF, while line breaks inside cell strings stay exact.
fn csv_extract_record(values : Array[String]) -> String {
  let output = StringBuilder()
  for index, value in values {
    if index > 0 {
      output.write_char(',')
    }
    output.write_char('"')
    for ch in value {
      output.write_char(ch)
      if ch == '"' {
        output.write_char('"')
      }
    }
    output.write_char('"')
  }
  output.write_string("\r\n")
  output.to_string()
}

///|
fn csv_extract_text(view : CsvView) -> String raise {
  let extract = csv_extract(view)
  let output = StringBuilder()
  output.write_string(csv_extract_record(extract.columns))
  for row in extract.rows {
    output.write_string(csv_extract_record(row.values))
  }
  output.to_string()
}

///|
extern "js" fn csv_extract_download(content : String) -> String =
  #|content => {
  #| let url, link;
  #| try {
  #|   url=URL.createObjectURL(new Blob([content],{type:'text/csv;charset=utf-8'}));
  #|   link=document.createElement('a'); link.href=url; link.download='moonfind-csv-extract.csv';
  #|   document.body.appendChild(link); link.click(); return '';
  #| } catch (_) { return 'CSV extract download failed; your table and selections remain available. Try again.'; }
  #| finally { if(link) { try { link.remove(); } catch (_) {} } if(url) setTimeout(() => URL.revokeObjectURL(url),1000); }
  #|}
