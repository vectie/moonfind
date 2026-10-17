///|
/// User-authored preparation only. Sources are captured bytes, never fetched.
pub(all) struct BriefSourceInputV1 {
  name : String
  origin : String
  captured_at : String
  kind : String
  content_hex : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct ResearchBriefV1 {
  contract_id : String
  brief_id : String
  parent_revision : String?
  question : String
  objective : String
  audience : String
  decision : String
  source_restrictions : String
  requested_filenames : Array[String]
  acceptance_criteria : String
  sources : Array[BriefSourceInputV1]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn brief_boundary() -> String {
  "Prepared brief only. No research, source analysis, factual verification, requested output creation, acceptance-criteria approval or provider call has occurred. Source bytes and user provenance are retained, not endorsed. Local captures do not monitor or refresh their original files."
}

///|
pub fn brief_safe_id(value : String) -> Bool {
  value.length() >= 1 &&
  value.length() <= 80 &&
  value.all(ch => {
    (ch >= 'a' && ch <= 'z') ||
    (ch >= 'A' && ch <= 'Z') ||
    (ch >= '0' && ch <= '9') ||
    ch == '-' ||
    ch == '_'
  })
}

///|
pub fn brief_filename(value : String) -> Bool {
  !value.is_blank() &&
  value.length() <= 160 &&
  value != "." &&
  value != ".." &&
  !value.contains("/") &&
  !value.contains("\\") &&
  value.all(ch => ch.to_int() >= 32 && ch.to_int() != 127)
}

///|
pub fn brief_issues(brief : ResearchBriefV1) -> Array[String] {
  let issues : Array[String] = []
  if brief.contract_id != "moonfind.research-brief.v1" ||
    !brief_safe_id(brief.brief_id) {
    issues.push("A supported contract and safe brief ID are required")
  }
  for
    (name, value) in [
      ("Question", brief.question),
      ("Objective", brief.objective),
      ("Audience", brief.audience),
      ("Decision", brief.decision),
      ("Source restrictions", brief.source_restrictions),
      ("Acceptance criteria", brief.acceptance_criteria),
    ] {
    if value.is_blank() || value.length() > 8000 {
      issues.push(name + " is required and must be at most 8000 characters")
    }
  }
  if brief.requested_filenames.is_empty() ||
    brief.requested_filenames.length() > 12 {
    issues.push(
      "Record 1–12 requested output filenames; these are requests, not generated files",
    )
  }
  let names : Array[String] = []
  for name in brief.requested_filenames {
    if !brief_filename(name) || names.contains(name.to_lower()) {
      issues.push("Requested output filenames must be safe and unique")
    }
    names.push(name.to_lower())
  }
  if brief.sources.is_empty() || brief.sources.length() > 8 {
    issues.push("Select 1–8 local or pasted sources")
  }
  let mut bytes = 0
  for source in brief.sources {
    if !brief_filename(source.name) ||
      source.origin.is_blank() ||
      source.origin.length() > 2000 ||
      source.captured_at.is_blank() ||
      source.captured_at.length() > 80 ||
      !(source.kind is ("pasted-text" | "local-file")) {
      issues.push(
        "Every source needs a safe name, origin, capture time and supported capture kind",
      )
    }
    let lower = source.name.to_lower()
    if ![".txt", ".md", ".csv", ".json", ".bib", ".ris", ".enw", ".nbib"].any(ext => {
        lower.has_suffix(ext)
      }) {
      issues.push(
        "Only UTF-8 text, Markdown, CSV, JSON, BibTeX and RIS are supported; PDF and binary extraction are unavailable",
      )
    }
    if source.content_hex.length() % 2 != 0 ||
      source.content_hex.length() > 65536 ||
      !source.content_hex.all(ch => {
        (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f')
      }) {
      issues.push(
        "Each exact source must be at most 32 KiB and use canonical hexadecimal bytes",
      )
    }
    bytes += source.content_hex.length() / 2
  }
  if bytes > 131072 {
    issues.push("The selected source dossier is limited to 128 KiB total")
  }
  issues
}
