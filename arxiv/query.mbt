///|
fn query_hex_digit(value : Int) -> Char {
  if value < 10 {
    ('0'.to_int() + value).unsafe_to_char()
  } else {
    ('A'.to_int() + value - 10).unsafe_to_char()
  }
}

///|
pub fn encode_query_component(value : String) -> String {
  let builder = StringBuilder::new()
  for byte in @utf8.encode(value) {
    let code = byte.to_int()
    let safe = (code >= 'a' && code <= 'z') ||
      (code >= 'A' && code <= 'Z') ||
      (code >= '0' && code <= '9') ||
      code == '-'.to_int() ||
      code == '_'.to_int() ||
      code == '.'.to_int() ||
      code == '~'.to_int()
    if safe {
      builder.write_char(code.unsafe_to_char())
    } else {
      builder.write_char('%')
      builder.write_char(query_hex_digit(code / 16))
      builder.write_char(query_hex_digit(code % 16))
    }
  }
  builder.to_string()
}

///|
pub fn search_url(query : String, max_results : Int) -> String raise {
  guard !query.is_blank() && max_results is (1..=100) else {
    fail("arXiv query must be non-empty and max_results must be 1..100")
  }
  "https://export.arxiv.org/api/query?search_query=" +
  encode_query_component(query) +
  "&start=0&max_results=" +
  max_results.to_string() +
  "&sortBy=submittedDate&sortOrder=descending"
}
