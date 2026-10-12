///|
pub(all) struct CslIntakeRequestV1 {
  source : @research.BriefSourceInputV1
  query : String
} derive(Debug, ToJson, FromJson)

///|
pub(all) struct CslIntakeV1 {
  source : @research.BriefSourceInputV1
  references : Array[@research.CslReferenceV1]
  total_count : Int
} derive(Debug, ToJson, FromJson)

///|
pub(all) struct CslSelectRequestV1 {
  source : @research.BriefSourceInputV1
  record_numbers : Array[Int]
} derive(Debug, ToJson, FromJson)

///|
fn csl_source_text(source : @research.BriefSourceInputV1) -> String raise {
  guard @research.brief_filename(source.name) &&
    source.name.to_lower().has_suffix(".json") &&
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
      "Choose a UTF-8 .json source up to 32 KiB with its origin and capture time",
    )
  }
  @utf8.decode(brief_source_bytes(source))
}

///|
/// Parse only supplied local bytes; no DOI lookup, URL fetch or citation provider.
pub fn intake_csl(request : CslIntakeRequestV1) -> CslIntakeV1 raise {
  let references = @research.parse_csl(csl_source_text(request.source))
  {
    source: request.source,
    references: @research.filter_csl(references, request.query),
    total_count: references.length(),
  }
}

///|
/// Prepare two ordinary brief captures: the byte-exact input and a structured
/// selection companion. Existing save/reopen/export retains both together.
pub fn select_csl(
  request : CslSelectRequestV1,
) -> Array[@research.BriefSourceInputV1] raise {
  let text = csl_source_text(request.source)
  let references = @research.parse_csl(text)
  guard !request.record_numbers.is_empty() &&
    request.record_numbers.all(number => {
      number >= 1 && number <= references.length()
    }) else {
    fail("Select at least one record number from this CSL JSON source")
  }
  let selected = references.filter(reference => {
    request.record_numbers.contains(reference.record_number)
  })
  let selection : @research.CslSelectionV1 = {
    contract_id: "moonfind.csl-selection.v1",
    source_name: request.source.name,
    source_digest: @store.digest_text(text),
    references: selected,
  }
  let bytes = @utf8.encode(selection.to_json().stringify(indent=2) + "\n")
  guard bytes.length() <= 32768 else {
    fail("Selected card metadata exceeds 32 KiB; select fewer references")
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
      name: "csl-selection.json",
      origin: "Selected CSL JSON references from " + request.source.name,
      captured_at: request.source.captured_at,
      kind: "pasted-text",
      content_hex: hex.to_string(),
    },
  ]
}

///|
fn csl_readable_selections(brief : @research.ResearchBriefV1) -> String {
  let out = StringBuilder()
  for source in brief.sources {
    if source.name == "csl-selection.json" {
      let selection : @research.CslSelectionV1? = Some(
        @json.from_json(@json.parse(@utf8.decode(brief_source_bytes(source)))),
      ) catch {
        _ => None
      }
      if selection is Some(selection) &&
        selection.contract_id == "moonfind.csl-selection.v1" {
        out.write_string(
          "## Selected CSL JSON references\n\nLocal metadata and supplied abstracts only; cited full text was not retrieved.\n\nSource: " +
          selection.source_name +
          "\nSource digest: " +
          selection.source_digest +
          "\n\n",
        )
        for reference in selection.references {
          out.write_string(
            "### [" +
            reference.citation_key +
            "] " +
            reference.title +
            "\n\nSource record: " +
            reference.record_number.to_string() +
            "\nAuthors: " +
            reference.authors.join("; ") +
            "\nEditors: " +
            reference.editors.join("; ") +
            "\nCSL item ID (" +
            reference.item_id_kind +
            "): " +
            reference.item_id +
            "\nYear: " +
            reference.year +
            "\nIssued: " +
            reference.issued +
            "\nVenue: " +
            reference.venue +
            "\nAvailability: " +
            reference.availability +
            "\nDOI: " +
            reference.doi +
            "\nURL: " +
            reference.url +
            "\n\n" +
            reference.abstract_text +
            "\n\n",
          )
        }
      }
    }
  }
  out.to_string()
}
