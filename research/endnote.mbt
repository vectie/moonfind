///|
/// An ordered tagged field, including fields outside the card projection.
pub(all) struct EndnoteFieldV1 {
  tag : String
  value : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Metadata from one EndNote tagged-text record. Ordinals refer to the original
/// file, and fields retain all supplied tags in their original order.
pub(all) struct EndnoteReferenceV1 {
  record_number : Int
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
  fields : Array[EndnoteFieldV1]
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A selected metadata companion; the original .enw is retained separately.
pub(all) struct EndnoteSelectionV1 {
  contract_id : String
  source_name : String
  source_digest : String
  references : Array[EndnoteReferenceV1]
} derive(Debug, Eq, ToJson, FromJson)

///|
fn endnote_first(
  fields : Array[EndnoteFieldV1],
  tags : Array[String],
) -> String {
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
fn endnote_values(
  fields : Array[EndnoteFieldV1],
  tag : String,
) -> Array[String] {
  fields
  .filter(field => field.tag == tag && !field.value.is_blank())
  .map(field => field.value)
}

///|
fn endnote_card(
  fields : Array[EndnoteFieldV1],
  number : Int,
) -> EndnoteReferenceV1 raise {
  guard fields.length() > 1 &&
    fields.any(field => field.tag != "0" && !field.value.is_blank()) else {
    fail("EndNote record \{number} has no reference metadata")
  }
  let title = endnote_first(fields, ["T"])
  {
    record_number: number,
    reference_type: endnote_first(fields, ["0"]),
    title: if title.is_blank() {
      "Untitled reference \{number}"
    } else {
      title
    },
    authors: endnote_values(fields, "A"),
    editors: endnote_values(fields, "E"),
    year: endnote_first(fields, ["D"]),
    venue: endnote_first(fields, ["J", "B"]),
    keywords: endnote_values(fields, "K").join("; "),
    doi: endnote_first(fields, ["R"]),
    url: endnote_first(fields, ["U"]),
    abstract_text: endnote_first(fields, ["X"]),
    fields,
  }
}

///|
/// Parse a bounded EndNote tagged-text dialect, not an EndNote binary library.
/// Records require %0 plus a nonempty type and a blank-line separator. A field
/// starts with percent, one visible ASCII character, then a space. Indented
/// continuation lines are supported; unknown tags remain ordered metadata.
///
/// ```mbt check
/// test {
///   let records = parse_endnote("%0 Book\n%T Local evidence\n%A Rivera, Ana\n")
///   assert_eq(records[0].title, "Local evidence")
/// }
/// ```
pub fn parse_endnote(text : String) -> Array[EndnoteReferenceV1] raise {
  let cards : Array[EndnoteReferenceV1] = []
  let mut fields : Array[EndnoteFieldV1] = []
  let text = if text.has_prefix("\uFEFF") { text[1:].to_owned() } else { text }
  for line_index, raw in text.split("\n").collect() {
    let line = raw.to_owned().trim_end().to_owned()
    if line.is_blank() {
      if !fields.is_empty() {
        cards.push(endnote_card(fields, cards.length() + 1))
        fields = []
      }
      continue
    }
    // Test the original line's space so a blank tag value remains well formed.
    let tagged = raw.length() >= 3 &&
      raw[0] == '%' &&
      raw[1] >= '!' &&
      raw[1] <= '~' &&
      raw[1] != '%' &&
      raw[2] == ' '
    if tagged {
      let tag = raw[1:2].to_owned()
      let value = raw[3:].trim().to_owned()
      if tag == "0" {
        guard fields.is_empty() else {
          fail(
            "EndNote records require a blank separator before line \{line_index + 1}",
          )
        }
        guard !value.is_blank() else {
          fail("EndNote reference type is empty at line \{line_index + 1}")
        }
      } else {
        guard !fields.is_empty() else {
          fail("Expected EndNote %0 record at line \{line_index + 1}")
        }
      }
      fields.push({ tag, value, })
    } else if !fields.is_empty() &&
      (line.has_prefix(" ") || line.has_prefix("\t")) {
      let last = fields.length() - 1
      guard fields[last].tag != "0" else {
        fail("EndNote reference type cannot continue at line \{line_index + 1}")
      }
      fields[last] = {
        ..fields[last],
        value: fields[last].value + "\n" + line.trim().to_owned(),
      }
    } else {
      fail(
        "Expected EndNote %tag space value or indented continuation at line \{line_index + 1}",
      )
    }
  }
  if !fields.is_empty() {
    cards.push(endnote_card(fields, cards.length() + 1))
  }
  guard !cards.is_empty() else { fail("No EndNote records found") }
  cards
}

///|
/// Filter author text without changing original record ordinals.
pub fn filter_endnote_author(
  references : Array[EndnoteReferenceV1],
  author : String,
) -> Array[EndnoteReferenceV1] {
  fn lower(value : String) -> String {
    String::from_iter(value.iter().map(@unicode.to_lowercase))
  }
  let query = lower(author.trim().to_owned())
  references.filter(reference => {
    query.is_empty() ||
    reference.authors.any(name => lower(name).contains(query))
  })
}
