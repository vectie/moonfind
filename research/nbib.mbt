///|
/// An ordered PubMed/MEDLINE field. Unknown and repeated tags are retained.
pub(all) struct NbibFieldV1 {
  tag : String
  value : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A local citation projection. PMID, dates, identifiers and abstracts remain
/// supplied metadata; none are looked up or independently verified.
pub(all) struct NbibReferenceV1 {
  record_number : Int
  pmid : String
  reference_type : String
  title : String
  authors : Array[String]
  editors : Array[String]
  year : String
  venue : String
  keywords : String
  doi : String
  url : String
  abstract_text : String
  fields : Array[NbibFieldV1]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct NbibSelectionV1 {
  contract_id : String
  source_name : String
  source_digest : String
  references : Array[NbibReferenceV1]
} derive(Debug, Eq, ToJson, FromJson)

///|
fn nbib_first(fields : Array[NbibFieldV1], tags : Array[String]) -> String {
  for tag in tags {
    for field in fields {
      if field.tag == tag && !field.value.is_blank() {
        return field.value
      }
    }
  }
  ""
}

///|
fn nbib_values(fields : Array[NbibFieldV1], tag : String) -> Array[String] {
  fields
  .filter(field => field.tag == tag && !field.value.is_blank())
  .map(field => field.value)
}

///|
// FAU/AU are paired by their supplied sequence, not by assumed name matching.
// This retains initials-only authors in mixed older/newer exports.
fn nbib_authors(fields : Array[NbibFieldV1]) -> Array[String] {
  let authors : Array[String] = []
  let mut full : String? = None
  for field in fields {
    if field.value.is_blank() {
      continue
    }
    match field.tag {
      "FAU" => {
        if full is Some(name) {
          authors.push(name)
        }
        full = Some(field.value)
      }
      "AU" => {
        authors.push(full.unwrap_or(field.value))
        full = None
      }
      "CN" => {
        if full is Some(name) {
          authors.push(name)
        }
        full = None
        authors.push(field.value)
      }
      _ => ()
    }
  }
  if full is Some(name) {
    authors.push(name)
  }
  authors
}

///|
// Only project an unambiguous leading year; keep ranges/uncertainty literal so
// the existing timeline does not incorrectly classify them as one year.
fn nbib_year(date : String) -> String {
  if date.length() < 4 ||
    !date[:4].all(ch => ch >= '0' && ch <= '9') ||
    (date.length() > 4 && date[4] != ' ') ||
    date.contains("-") ||
    date.contains("/") ||
    date.contains("?") {
    return date
  }
  let mut digits = 0
  for ch in date[4:] {
    digits = if ch >= '0' && ch <= '9' { digits + 1 } else { 0 }
    if digits >= 4 {
      return date
    }
  }
  date[:4].to_owned()
}

///|
fn nbib_card(
  fields : Array[NbibFieldV1],
  number : Int,
) -> NbibReferenceV1 raise {
  guard fields.any(field => field.tag != "PMID" && !field.value.is_blank()) else {
    fail("PubMed NBIB record \{number} has no citation metadata")
  }
  let pmid = nbib_first(fields, ["PMID"])
  let title = nbib_first(fields, ["TI", "BTI"])
  let date = nbib_first(fields, ["DP"])
  let types = nbib_values(fields, "PT")
  let mut doi = ""
  for tag in ["AID", "LID"] {
    for value in nbib_values(fields, tag) {
      if doi.is_empty() && value.has_suffix(" [doi]") {
        doi = value[:value.length() - 6].trim().to_owned()
      }
    }
  }
  {
    record_number: number,
    pmid,
    reference_type: if types.contains("Journal Article") {
      "Journal Article"
    } else {
      types.get(0).unwrap_or("")
    },
    title: if title.is_blank() {
      "Untitled citation \{number}"
    } else {
      title
    },
    authors: nbib_authors(fields),
    editors: nbib_values(fields, "FED"),
    year: nbib_year(date),
    venue: nbib_first(fields, ["JT", "TA", "BTI"]),
    keywords: (nbib_values(fields, "OT") + nbib_values(fields, "MH")).join("; "),
    doi,
    url: "https://pubmed.ncbi.nlm.nih.gov/" + pmid + "/",
    abstract_text: nbib_values(fields, "AB").join("\n\n"),
    fields,
  }
}

///|
/// Parse locally supplied PubMed/MEDLINE tagged text (.nbib), with a numeric
/// PMID starting each record. Tags occupy columns 1–4, followed by '- ';
/// six-space continuations fold with one space. A blank line, next PMID, or
/// EOF closes a record. Original bytes should be kept alongside this projection.
///
/// ```mbt check
/// test {
///   let cards = parse_nbib("PMID- 123\nTI  - Local evidence\nAU  - Rivera A\n")
///   assert_eq(cards[0].pmid, "123")
///   assert_eq(cards[0].authors, ["Rivera A"])
/// }
/// ```
pub fn parse_nbib(text : String) -> Array[NbibReferenceV1] raise {
  let cards : Array[NbibReferenceV1] = []
  let mut fields : Array[NbibFieldV1] = []
  let text = if text.has_prefix("\uFEFF") { text[1:].to_owned() } else { text }
  for line_index, raw in text.split("\n").collect() {
    let line = raw.trim_end().to_owned()
    if line.is_blank() {
      if !fields.is_empty() {
        cards.push(nbib_card(fields, cards.length() + 1))
        fields = []
      }
      continue
    }
    if line.has_prefix("      ") {
      guard !fields.is_empty() && fields[fields.length() - 1].tag != "PMID" else {
        fail("Unexpected PubMed NBIB continuation at line \{line_index + 1}")
      }
      let last = fields.length() - 1
      fields[last] = {
        ..fields[last],
        value: (fields[last].value + " " + line.trim().to_owned())
        .trim()
        .to_owned(),
      }
      continue
    }
    guard raw.length() >= 6 && raw[4] == '-' && raw[5] == ' ' else {
      fail("Expected PubMed NBIB TAG - value at line \{line_index + 1}")
    }
    let tag = raw[:4].trim_end().to_owned()
    guard tag.length() >= 2 &&
      tag.all(ch => (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9')) else {
      fail("Invalid PubMed NBIB field tag at line \{line_index + 1}")
    }
    let value = raw[6:].trim().to_owned()
    if tag == "PMID" {
      guard !value.is_empty() &&
        value.all(ch => ch >= '0' && ch <= '9') &&
        value.iter().any(ch => ch != '0') else {
        fail(
          "PubMed NBIB PMID must be a positive numeric identifier at line \{line_index + 1}",
        )
      }
      if !fields.is_empty() {
        cards.push(nbib_card(fields, cards.length() + 1))
        fields = []
      }
    } else {
      guard !fields.is_empty() else {
        fail("Expected PubMed NBIB PMID record at line \{line_index + 1}")
      }
    }
    fields.push({ tag, value, })
  }
  if !fields.is_empty() {
    cards.push(nbib_card(fields, cards.length() + 1))
  }
  guard !cards.is_empty() else { fail("No PubMed NBIB records found") }
  cards
}

///|
/// Filter author text while retaining the original file record ordinals.
pub fn filter_nbib_author(
  references : Array[NbibReferenceV1],
  author : String,
) -> Array[NbibReferenceV1] {
  fn lower(value : String) -> String {
    String::from_iter(value.iter().map(@unicode.to_lowercase))
  }
  let query = lower(author.trim().to_owned())
  references.filter(reference => {
    query.is_empty() ||
    reference.authors.any(name => lower(name).contains(query))
  })
}
