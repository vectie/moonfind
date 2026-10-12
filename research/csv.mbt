///|
/// Logical source records are one-based, including the header as record 1.
/// A quoted multiline cell is one field in one record. Values remain strings.
pub(all) struct CsvRowV1 {
  record_number : Int
  values : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct CsvTableV1 {
  columns : Array[String]
  rows : Array[CsvRowV1]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct CsvSelectionV1 {
  contract_id : String
  source_name : String
  source_digest : String
  source_row_count : Int
  column_numbers : Array[Int]
  columns : Array[String]
  rows : Array[CsvRowV1]
} derive(Debug, Eq, ToJson, FromJson)

///|
priv struct CsvReader {
  chars : Array[Char]
  mut pos : Int
}

///|
fn csv_separator(ch : Char) -> Bool {
  ch == ',' || ch == '\r' || ch == '\n'
}

///|
fn CsvReader::field(self : CsvReader) -> String raise {
  let value = StringBuilder()
  if self.chars.get(self.pos) == Some('"') {
    self.pos += 1
    while self.pos < self.chars.length() {
      let ch = self.chars[self.pos]
      self.pos += 1
      if ch == '"' {
        if self.chars.get(self.pos) == Some('"') {
          value.write_char('"')
          self.pos += 1
        } else {
          guard self.pos == self.chars.length() ||
            csv_separator(self.chars[self.pos]) else {
            fail("CSV: expected comma or record ending after a closing quote")
          }
          return value.to_string()
        }
      } else {
        value.write_char(ch)
      }
    }
    fail("CSV: unfinished quoted field")
  } else {
    while self.pos < self.chars.length() && !csv_separator(self.chars[self.pos]) {
      let ch = self.chars[self.pos]
      guard ch != '"' else { fail("CSV: quote inside an unquoted field") }
      value.write_char(ch)
      self.pos += 1
    }
    value.to_string()
  }
}

///|
/// Read a comma-delimited UTF-8 table with unique nonblank header names, up to
/// 32 columns and 512 data records. Quotes, escaped quotes, multiline fields,
/// CRLF/LF/CR and an optional BOM are supported. No values are evaluated.
pub fn parse_csv(text : String) -> CsvTableV1 raise {
  let reader : CsvReader = { chars: text.iter().collect(), pos: 0, }
  if reader.chars.get(0) == Some('\uFEFF') {
    reader.pos = 1
  }
  guard reader.pos < reader.chars.length() else { fail("CSV: missing header") }
  let records : Array[Array[String]] = []
  while reader.pos < reader.chars.length() {
    let fields : Array[String] = []
    while true {
      fields.push(reader.field())
      guard fields.length() <= 32 else {
        fail("CSV: at most 32 columns are supported")
      }
      if reader.chars.get(reader.pos) == Some(',') {
        reader.pos += 1
      } else {
        if reader.chars.get(reader.pos) == Some('\r') {
          reader.pos += 1
        }
        if reader.chars.get(reader.pos) == Some('\n') {
          reader.pos += 1
        }
        break
      }
    }
    records.push(fields)
    guard records.length() <= 513 else {
      fail("CSV: at most 512 data records are supported")
    }
  }
  let columns = records[0]
  let seen : Array[String] = []
  for column in columns {
    guard !column.is_blank() && !seen.contains(column) else {
      fail("CSV: use unique nonblank names in the first (header) record")
    }
    seen.push(column)
  }
  let rows : Array[CsvRowV1] = []
  for index = 1; index < records.length(); index = index + 1 {
    let values = records[index]
    guard values.length() == columns.length() else {
      fail(
        "CSV: record \{index + 1} has \{values.length()} fields; expected \{columns.length()}",
      )
    }
    rows.push({ record_number: index + 1, values, })
  }
  { columns, rows, }
}

///|
/// Case-insensitive literal substring search. Column 0 searches all fields;
/// other values are one-based column positions, independent of filtered rows.
pub fn filter_csv(
  table : CsvTableV1,
  query : String,
  column_number : Int,
) -> Array[CsvRowV1] raise {
  guard column_number >= 0 && column_number <= table.columns.length() else {
    fail("CSV: search column must be 0 (all) or an existing one-based column")
  }
  fn lower(text : String) -> String {
    String::from_iter(text.iter().map(@unicode.to_lowercase))
  }
  let query = lower(query.trim().to_owned())
  table.rows.filter(row => {
    if column_number == 0 {
      row.values.any(value => lower(value).contains(query))
    } else {
      lower(row.values[column_number - 1]).contains(query)
    }
  })
}

///|
/// Retain source ordering for rows and columns, regardless of click order.
pub fn project_csv(
  table : CsvTableV1,
  record_numbers : Array[Int],
  column_numbers : Array[Int],
) -> CsvTableV1 raise {
  guard !record_numbers.is_empty() &&
    record_numbers.all(number => {
      number >= 2 && number <= table.rows.length() + 1
    }) else {
    fail("CSV: select at least one existing data record (header is record 1)")
  }
  guard !column_numbers.is_empty() &&
    column_numbers.all(number => number >= 1 && number <= table.columns.length()) else {
    fail("CSV: select at least one existing column")
  }
  let indexes : Array[Int] = []
  for index = 0; index < table.columns.length(); index = index + 1 {
    if column_numbers.contains(index + 1) {
      indexes.push(index)
    }
  }
  {
    columns: indexes.map(index => table.columns[index]),
    rows: table.rows
    .filter(row => record_numbers.contains(row.record_number))
    .map(row => {
      record_number: row.record_number,
      values: indexes.map(index => row.values[index]),
    }),
  }
}
