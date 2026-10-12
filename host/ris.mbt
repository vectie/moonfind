///|
pub(all) struct RisIntakeRequestV1 {
  source : @research.BriefSourceInputV1
  author_filter : String
} derive(Debug, ToJson, FromJson)

///|
pub(all) struct RisIntakeV1 {
  source : @research.BriefSourceInputV1
  references : Array[@research.RisReferenceV1]
  total_count : Int
} derive(Debug, ToJson, FromJson)

///|
pub(all) struct RisSelectRequestV1 {
  source : @research.BriefSourceInputV1
  record_numbers : Array[Int]
} derive(Debug, ToJson, FromJson)

///|
fn ris_source_text(source : @research.BriefSourceInputV1) -> String raise {
  guard @research.brief_filename(source.name) &&
    source.name.to_lower().has_suffix(".ris") &&
    !source.origin.is_blank() &&
    !source.captured_at.is_blank() &&
    (source.kind == "local-file" || source.kind == "pasted-text") &&
    source.content_hex.length() <= 65536 &&
    source.content_hex.length() % 2 == 0 &&
    source.content_hex.all(ch => {
      (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f')
    }) else {
    fail(
      "Choose a UTF-8 .ris source up to 32 KiB with its origin and capture time",
    )
  }
  @utf8.decode(brief_source_bytes(source))
}

///|
/// Parse only supplied local bytes; no DOI lookup, URL fetch or citation provider.
pub fn intake_ris(request : RisIntakeRequestV1) -> RisIntakeV1 raise {
  let references = @research.parse_ris(ris_source_text(request.source))
  {
    source: request.source,
    references: @research.filter_ris_author(references, request.author_filter),
    total_count: references.length(),
  }
}

///|
/// Prepare two ordinary brief captures: the byte-exact input and a structured
/// selection companion. Existing save/reopen/export retains both together.
pub fn select_ris(
  request : RisSelectRequestV1,
) -> Array[@research.BriefSourceInputV1] raise {
  let text = ris_source_text(request.source)
  let references = @research.parse_ris(text)
  guard !request.record_numbers.is_empty() &&
    request.record_numbers.all(number => {
      number >= 1 && number <= references.length()
    }) else {
    fail("Select at least one record number from this RIS source")
  }
  let selected = references.filter(reference => {
    request.record_numbers.contains(reference.record_number)
  })
  let selection : @research.RisSelectionV1 = {
    contract_id: "moonfind.ris-selection.v1",
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
      name: "ris-selection.json",
      origin: "Selected RIS references from " + request.source.name,
      captured_at: request.source.captured_at,
      kind: "pasted-text",
      content_hex: hex.to_string(),
    },
  ]
}

///|
fn ris_readable_selections(brief : @research.ResearchBriefV1) -> String {
  let out = StringBuilder()
  for source in brief.sources {
    if source.name == "ris-selection.json" {
      let selection : @research.RisSelectionV1? = Some(
        @json.from_json(@json.parse(@utf8.decode(brief_source_bytes(source)))),
      ) catch {
        _ => None
      }
      if selection is Some(selection) &&
        selection.contract_id == "moonfind.ris-selection.v1" {
        out.write_string(
          "## Selected RIS references\n\nSource: " +
          selection.source_name +
          "\nSource digest: " +
          selection.source_digest +
          "\n\n",
        )
        for reference in selection.references {
          out.write_string(
            "### Record \{reference.record_number}: " +
            reference.title +
            "\n\nAuthors: " +
            reference.authors.join("; ") +
            "\nYear: " +
            reference.year +
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
