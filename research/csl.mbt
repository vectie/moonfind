///|
/// Local CSL JSON metadata; record_number always refers to the original array.
/// item_id is lossless text; item_id_kind preserves string/number identity even
/// when a JavaScript client cannot represent a large numeric ID precisely.
pub(all) struct CslReferenceV1 {
  record_number : Int
  item_id : String
  item_id_kind : String
  citation_key : String
  reference_type : String
  title : String
  authors : Array[String]
  editors : Array[String]
  year : String
  issued : String
  venue : String
  keywords : String
  doi : String
  url : String
  abstract_text : String
  availability : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct CslSelectionV1 {
  contract_id : String
  source_name : String
  source_digest : String
  references : Array[CslReferenceV1]
} derive(Debug, Eq, ToJson, FromJson)

///|
fn csl_string(fields : Map[String, Json], name : String) -> String raise {
  match fields.get(name) {
    None => ""
    Some(String(value)) => value
    _ => fail("CSL JSON: '\{name}' must be a string when supplied")
  }
}

///|
fn csl_scalar(value : Json) -> String raise {
  match value {
    String(text) if !text.is_blank() => text
    Number(_, ..) => value.stringify()
    _ =>
      fail("CSL JSON: IDs and date parts must be nonblank strings or numbers")
  }
}

///|
fn csl_names(fields : Map[String, Json], name : String) -> Array[String] raise {
  let names = match fields.get(name) {
    None => return []
    Some(Array(names)) => names
    _ => fail("CSL JSON: '\{name}' must be an array of name objects")
  }
  names.map(person => {
    guard person is Object(parts) else {
      fail("CSL JSON: '\{name}' entries must be name objects")
    }
    let literal = csl_string(parts, "literal")
    if !literal.is_blank() {
      literal
    } else {
      let family = [
          csl_string(parts, "non-dropping-particle"),
          csl_string(parts, "family"),
        ]
        .filter(s => !s.is_blank())
        .join(" ")
      let given = [
          csl_string(parts, "given"),
          csl_string(parts, "dropping-particle"),
        ]
        .filter(s => !s.is_blank())
        .join(" ")
      let display = [family, given, csl_string(parts, "suffix")]
        .filter(s => !s.is_blank())
        .join(", ")
      guard !display.is_blank() else {
        fail("CSL JSON: '\{name}' entry needs a literal, family or given name")
      }
      display
    }
  })
}

///|
// Display supplied dates, including ranges/literal dates, without inferring a
// retrieval date or interpreting calendar precision as evidence quality.
fn csl_issued(fields : Map[String, Json]) -> (String, String) raise {
  let date = match fields.get("issued") {
    None => return ("", "")
    Some(Object(date)) => date
    _ => fail("CSL JSON: 'issued' must be a date object")
  }
  match date.get("date-parts") {
    Some(Array(dates)) if dates.length() >= 1 && dates.length() <= 2 => {
      let mut year = ""
      let rendered = dates.map(date => {
        guard date is Array(parts) && parts.length() >= 1 && parts.length() <= 3 else {
          fail("CSL JSON: each issued date needs 1–3 date parts")
        }
        let parts = parts.map(csl_scalar)
        if year.is_empty() {
          year = parts[0]
        }
        parts.join("-")
      })
      (year, rendered.join(" / "))
    }
    None => {
      let literal = csl_string(date, "literal")
      let raw = csl_string(date, "raw")
      ("", if !literal.is_blank() { literal } else { raw })
    }
    _ => fail("CSL JSON: 'date-parts' needs one date or a two-date range")
  }
}

///|
/// Read the CSL JSON array exported by reference managers. No URLs, attachments,
/// citation styles or embedded markup are fetched or executed. Unknown fields
/// remain available in the unchanged original source.
pub fn parse_csl(text : String) -> Array[CslReferenceV1] raise {
  let text = if text.has_prefix("\uFEFF") { text[1:].to_owned() } else { text }
  guard @json.parse(text) is Array(items) && !items.is_empty() else {
    fail("CSL JSON: expected a nonempty bibliography array; export as CSL JSON")
  }
  let seen : Map[String, Bool] = {}
  let references : Array[CslReferenceV1] = []
  for index, item in items {
    try {
      guard item is Object(fields) else {
        fail("CSL JSON: each bibliography item must be an object")
      }
      guard fields.get("id") is Some(item_id) else {
        fail("CSL JSON: each item needs an id")
      }
      let id_text = csl_scalar(item_id)
      let identity = item_id.stringify()
      guard !seen.contains(identity) else {
        fail("CSL JSON: duplicate item id \{identity}")
      }
      seen[identity] = true
      let reference_type = csl_string(fields, "type")
      guard !reference_type.is_blank() else {
        fail("CSL JSON: each item needs a type")
      }
      let key = csl_string(fields, "citation-key")
      let title = csl_string(fields, "title")
      let abstract_text = csl_string(fields, "abstract")
      let (year, issued) = csl_issued(fields)
      let venue = csl_string(fields, "container-title")
      references.push({
        record_number: index + 1,
        item_id: id_text,
        item_id_kind: if item_id is String(_) {
          "string"
        } else {
          "number"
        },
        citation_key: if key.is_blank() {
          id_text
        } else {
          key
        },
        reference_type,
        title: if title.is_blank() {
          "Untitled reference " + id_text
        } else {
          title
        },
        authors: csl_names(fields, "author"),
        editors: csl_names(fields, "editor"),
        year,
        issued,
        venue: if venue.is_blank() {
          csl_string(fields, "publisher")
        } else {
          venue
        },
        keywords: csl_string(fields, "keyword"),
        doi: csl_string(fields, "DOI"),
        url: csl_string(fields, "URL"),
        abstract_text,
        availability: if abstract_text.is_blank() {
          "metadata-only"
        } else {
          "metadata-and-abstract"
        },
      })
    } catch {
      error => fail("Record \{index + 1}: \{error}")
    }
  }
  references
}

///|
/// Case-insensitive metadata search; source record positions never change.
pub fn filter_csl(
  references : Array[CslReferenceV1],
  query : String,
) -> Array[CslReferenceV1] {
  fn lower(value : String) -> String {
    String::from_iter(value.iter().map(@unicode.to_lowercase))
  }
  let query = lower(query.trim().to_owned())
  references.filter(reference => {
    lower(
      [
        reference.item_id,
        reference.citation_key,
        reference.title,
        reference.authors.join("; "),
        reference.editors.join("; "),
        reference.year,
        reference.issued,
        reference.venue,
        reference.keywords,
        reference.doi,
      ].join(" "),
    ).contains(query)
  })
}
