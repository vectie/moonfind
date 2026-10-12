///|
/// Metadata read from a local RIS record. Record numbers are one-based in the
/// original file, including when the card list is filtered.
pub(all) struct RisReferenceV1 {
  record_number : Int
  reference_type : String
  title : String
  authors : Array[String]
  year : String
  doi : String
  url : String
  abstract_text : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A retained selection companion, stored beside the unchanged original RIS.
pub(all) struct RisSelectionV1 {
  contract_id : String
  source_name : String
  source_digest : String
  references : Array[RisReferenceV1]
} derive(Debug, Eq, ToJson, FromJson)

///|
fn ris_first(fields : Array[(String, String)], tags : Array[String]) -> String {
  for tag in tags {
    for (key, value) in fields {
      if key == tag && !value.is_blank() {
        return value
      }
    }
  }
  ""
}

///|
fn ris_card(fields : Array[(String, String)], number : Int) -> RisReferenceV1 {
  let authors : Array[String] = []
  for (tag, value) in fields {
    if (tag == "AU" || tag == "A1") && !value.is_blank() {
      authors.push(value)
    }
  }
  let date = ris_first(fields, ["PY", "Y1", "DA"])
  let year = if date.length() >= 4 &&
    date[:4].iter().all(ch => ch >= '0' && ch <= '9') {
    date[:4].to_owned()
  } else {
    date
  }
  let title = ris_first(fields, ["TI", "T1", "CT"])
  {
    record_number: number,
    reference_type: ris_first(fields, ["TY"]),
    title: if title.is_blank() {
      "Untitled reference \{number}"
    } else {
      title
    },
    authors,
    year,
    doi: ris_first(fields, ["DO"]),
    url: ris_first(fields, ["UR", "L1"]),
    abstract_text: ris_first(fields, ["AB", "N2"]),
  }
}

///|
/// Read TY/ER-delimited RIS records, preserving repeated AU/A1 fields and
/// continuation lines. Unknown fields remain available in the original source.
pub fn parse_ris(text : String) -> Array[RisReferenceV1] raise {
  let cards : Array[RisReferenceV1] = []
  let mut fields : Array[(String, String)] = []
  let mut active = false
  let text = if text.has_prefix("\uFEFF") { text[1:].to_owned() } else { text }
  for line_index, raw in text.split("\n").collect() {
    let line = raw.to_owned().trim_end().to_owned()
    let tagged = line.length() >= 5 &&
      line[2] == ' ' &&
      line[3] == ' ' &&
      line[4] == '-' &&
      line[:2]
      .iter()
      .all(ch => (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9'))
    if tagged {
      let tag = line[:2].to_owned()
      let value = line[5:].trim().to_owned()
      if tag == "TY" {
        guard !active else {
          fail("RIS record missing ER before line \{line_index + 1}")
        }
        active = true
        fields = [(tag, value)]
      } else if tag == "ER" {
        guard active else { fail("RIS ER has no TY at line \{line_index + 1}") }
        cards.push(ris_card(fields, cards.length() + 1))
        active = false
        fields = []
      } else if active {
        fields.push((tag, value))
      } else {
        fail("RIS field outside a TY/ER record at line \{line_index + 1}")
      }
    } else if active && !fields.is_empty() {
      let last = fields.length() - 1
      let (tag, value) = fields[last]
      fields[last] = (tag, value + "\n" + line.trim().to_owned())
    } else if !line.is_blank() {
      fail("Expected RIS TY record at line \{line_index + 1}")
    }
  }
  guard !active else { fail("RIS final record is missing ER") }
  guard !cards.is_empty() else { fail("No RIS records found") }
  cards
}

///|
/// Case-insensitive author substring filter; never renumbers source records.
pub fn filter_ris_author(
  references : Array[RisReferenceV1],
  author : String,
) -> Array[RisReferenceV1] {
  fn lower(value : String) -> String {
    String::from_iter(value.iter().map(@unicode.to_lowercase))
  }
  let query = lower(author.trim().to_owned())
  references.filter(reference => {
    query.is_empty() ||
    reference.authors.any(name => lower(name).contains(query))
  })
}
