///|
// Offline captures are not research runs, papers, or model-authored claims.
struct OfflineCitation {
  brief_id : String
  revision_id : String
  source : BriefSource
  capture : BriefInputSource
} derive(ToJson, FromJson)

///|
struct OfflineOption {
  id : String
  name : String
  assessments : Array[String]
  source_slot : String
  contradiction : String
  unknowns : String
  cost_of_error : String
  experiment : String
  historical_source : OfflineCitation?
} derive(ToJson, FromJson)

///|
struct OfflineVersion {
  revision : Int
  next_option : Int
  basis : BriefSnapshot
  question : String
  audience : String
  commitment_ref : String
  criteria : Array[String]
  options : Array[OfflineOption]
  chosen_option_id : String
  reasoning : String
  next_action : String
} derive(ToJson, FromJson)

///|
struct OfflineWorksheet {
  contract_id : String
  current : OfflineVersion
  history : Array[OfflineVersion]
} derive(ToJson, FromJson)

///|
extend OfflineWorksheet with ToJson::{to_json}

///|
extend OfflineVersion with ToJson::{to_json}

///|
extend BriefSnapshot with ToJson::{to_json}

///|
extend BriefSource with ToJson::{to_json}

///|
fn offline_boundary() -> String {
  "User-authored comparison of a saved offline brief and its retained local captures. No research run, provider analysis, factual verification, automatic ranking, executed experiment, company decision or named approval is created. Empty fields mean Unknown / not recorded."
}

///|
fn offline_safe_filename(value : String) -> Bool {
  !value.is_blank() &&
  value.length() <= 160 &&
  value != "." &&
  value != ".." &&
  !value.contains("/") &&
  !value.contains("\\") &&
  value.all(ch => ch.to_int() >= 32 && ch.to_int() != 127)
}

///|
extern "js" fn offline_source_encoding_valid(hex : String) -> Bool =
  #| hex => { try { const bytes=Uint8Array.from(hex.match(/../g)||[],part=>parseInt(part,16)); const text=new TextDecoder('utf-8',{fatal:true,ignoreBOM:true}).decode(bytes); return !/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(text); } catch (_) { return false; } }

///|
fn offline_basis_issue(basis : BriefSnapshot) -> String {
  if basis.contract_id != "moonfind.brief-snapshot.v1" ||
    basis.state != "prepared" ||
    basis.brief.contract_id != "moonfind.research-brief.v1" ||
    basis.brief.brief_id.is_blank() ||
    basis.brief.brief_id.length() > 80 ||
    !basis.brief.brief_id.all(ch => {
      (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '-' ||
      ch == '_'
    }) ||
    basis.revision_id.length() != 73 ||
    !basis.revision_id.has_prefix("revision-") ||
    !basis.revision_id[9:]
    .iter()
    .all(ch => (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f')) ||
    basis.sources.is_empty() ||
    basis.sources.length() > 8 ||
    basis.sources.length() != basis.brief.sources.length() {
    return "A complete, versioned saved brief and retained source dossier are required."
  }
  for
    field in [
      basis.brief.question,
      basis.brief.objective,
      basis.brief.audience,
      basis.brief.decision,
      basis.brief.source_restrictions,
      basis.brief.acceptance_criteria,
    ] {
    if field.is_blank() || field.length() > 8000 {
      return "Saved brief preparation fields are missing or oversized."
    }
  }
  if basis.brief.requested_filenames.is_empty() ||
    basis.brief.requested_filenames.length() > 12 {
    return "Saved brief requested-output names are incomplete."
  }
  let names : Array[String] = []
  for name in basis.brief.requested_filenames {
    if !offline_safe_filename(name) || names.contains(name.to_lower()) {
      return "Saved brief output names are unsafe or duplicated."
    }
    names.push(name.to_lower())
  }
  let mut total = 0
  for i, source in basis.sources {
    let input = basis.brief.sources[i]
    let extension = source.name
      .split(".")
      .last()
      .unwrap_or("")
      .to_owned()
      .to_lower()
    if source.slot != i + 1 ||
      source.name != input.name ||
      source.origin != input.origin ||
      source.captured_at != input.captured_at ||
      source.kind != input.kind ||
      source.availability != "retained-local-capture" ||
      source.digest.length() != 71 ||
      !source.digest.has_prefix("sha256:") ||
      !source.digest[7:]
      .iter()
      .all(ch => (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f')) ||
      source.byte_count != input.content_hex.length() / 2 ||
      input.content_hex.length() % 2 != 0 ||
      input.content_hex.length() > 65536 ||
      !input.content_hex.all(ch => {
        (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f')
      }) ||
      !offline_source_encoding_valid(input.content_hex) ||
      !offline_safe_filename(source.name) ||
      !["txt", "md", "csv", "json", "bib"].contains(extension) ||
      source.origin.is_blank() ||
      source.origin.length() > 2000 ||
      source.captured_at.is_blank() ||
      source.captured_at.length() > 80 ||
      !(source.kind is ("pasted-text" | "local-file")) ||
      source.archive_path != "sources/source-\{i + 1}." + extension {
      return "Saved source slot, provenance, digest or captured bytes are inconsistent."
    }
    total += source.byte_count
  }
  if total > 131072 {
    return "Saved source dossier exceeds 128 KiB."
  }
  ""
}

///|
fn offline_open_basis(model : Model) -> BriefSnapshot? {
  guard !model.brief.pending &&
    model.brief.error is None &&
    model.brief.opened is Some(status) &&
    status.contract_id == "moonfind.brief-status.v1" &&
    status.state == "prepared" &&
    status.issues.is_empty() &&
    status.snapshot is Some(basis) &&
    status.brief_id == basis.brief.brief_id &&
    status.revision_id == basis.revision_id &&
    model.brief.draft == basis.brief &&
    offline_basis_issue(basis) == "" else {
    return None
  }
  Some(basis)
}

///|
fn offline_citation(basis : BriefSnapshot, slot : String) -> OfflineCitation? {
  for i, source in basis.sources {
    if slot == "source-\{source.slot}" {
      return Some({
        brief_id: basis.brief.brief_id,
        revision_id: basis.revision_id,
        source,
        capture: basis.brief.sources[i],
      })
    }
  }
  None
}

///|
fn new_offline_sheet(basis : BriefSnapshot) -> OfflineWorksheet {
  {
    contract_id: "moonfind.offline-choice-worksheet.v1",
    current: {
      revision: 1,
      next_option: 3,
      basis,
      question: basis.brief.decision,
      audience: basis.brief.audience,
      commitment_ref: "",
      criteria: ["Evidence for the intended outcome"],
      options: [1, 2].map(i => {
        id: "option-\{i}",
        name: "",
        assessments: [""],
        source_slot: "",
        contradiction: "",
        unknowns: "",
        cost_of_error: "",
        experiment: "",
        historical_source: None,
      }),
      chosen_option_id: "",
      reasoning: "",
      next_action: "",
    },
    history: [],
  }
}

///|
// Reuse only the existing bounded form editor, never its research serialization,
// provenance, continuation, experiments, or import/export contracts. Empty run
// identity here is an internal adapter value, never an invented external run.
fn offline_edit_adapter(value : OfflineVersion) -> ChoiceWorksheet {
  {
    contract_id: "moonfind.offline-form-edit-internal",
    revision: value.revision,
    next_option: value.next_option,
    evidence: { run_id: "", question: "", papers: [], summaries: [], },
    question: value.question,
    audience: value.audience,
    commitment_ref: value.commitment_ref,
    criteria: value.criteria,
    options: value.options.map(item => {
      id: item.id,
      name: item.name,
      assessments: item.assessments,
      source_id: item.source_slot,
      claim_id: "",
      contradiction: item.contradiction,
      unknowns: item.unknowns,
      cost_of_error: item.cost_of_error,
      experiment: item.experiment,
      retained_source: None,
      retained_claim: None,
      evidence_review_note: None,
    }),
    chosen_option_id: value.chosen_option_id,
    reasoning: value.reasoning,
    next_action: value.next_action,
    history: None,
    experiments: None,
  }
}

///|
fn offline_edit(
  sheet : OfflineWorksheet,
  action : ChoiceMsg,
) -> OfflineWorksheet {
  if action is SetOption(_, "claim", _) {
    return sheet
  }
  if action is SetOption(_, "source", value) &&
    value != "" &&
    offline_citation(sheet.current.basis, value) is None {
    return sheet
  }
  let edited = choice_edit(offline_edit_adapter(sheet.current), action)
  {
    ..sheet,
    current: {
      ..sheet.current,
      revision: edited.revision,
      next_option: edited.next_option,
      question: edited.question,
      audience: edited.audience,
      commitment_ref: edited.commitment_ref,
      criteria: edited.criteria,
      chosen_option_id: edited.chosen_option_id,
      reasoning: edited.reasoning,
      next_action: edited.next_action,
      options: edited.options.map(item => {
        let old = sheet.current.options
          .filter(value => value.id == item.id)
          .get(0)
        {
          id: item.id,
          name: item.name,
          assessments: item.assessments,
          source_slot: item.source_id,
          contradiction: item.contradiction,
          unknowns: item.unknowns,
          cost_of_error: item.cost_of_error,
          experiment: item.experiment,
          historical_source: old.bind(value => {
            if value.source_slot == item.source_id {
              value.historical_source
            } else {
              None
            }
          }),
        }
      }),
    },
  }
}

///|
fn offline_version_issue(value : OfflineVersion, brief_id : String) -> String {
  let basis_issue = offline_basis_issue(value.basis)
  if basis_issue != "" {
    return basis_issue
  }
  if value.basis.brief.brief_id != brief_id ||
    value.revision < 1 ||
    value.next_option < 3 ||
    value.next_option > 1000000 ||
    value.criteria.is_empty() ||
    value.criteria.length() > 6 ||
    value.options.length() < 2 ||
    value.options.length() > 4 {
    return "Offline worksheet version, brief identity or bounded form is invalid."
  }
  let ids : Array[String] = []
  for item in value.options {
    if !item.id.has_prefix("option-") ||
      ids.contains(item.id) ||
      item.assessments.length() != value.criteria.length() {
      return "Offline option identities or criteria are inconsistent."
    }
    let number = @string.parse_int(item.id[7:].to_owned()) catch {
      _ => return "Invalid offline option identity."
    }
    if number < 1 || number >= value.next_option {
      return "Offline next-option identity collides with retained options."
    }
    if item.source_slot != "" &&
      offline_citation(value.basis, item.source_slot) is None {
      return "Offline strongest-source selection is outside the retained dossier."
    }
    if item.historical_source is Some(citation) &&
      (
        citation.brief_id != brief_id ||
        citation.revision_id.is_blank() ||
        citation.source.name != citation.capture.name ||
        citation.source.digest.is_blank()
      ) {
      return "Historical offline source citation is inconsistent."
    }
    ids.push(item.id)
  }
  if value.chosen_option_id != "" && !ids.contains(value.chosen_option_id) {
    return "Chosen offline option is not retained."
  }
  ""
}

///|
fn offline_decode(
  text : String,
  brief_id : String,
) -> Result[OfflineWorksheet, String] {
  if text.length() > 2000000 {
    return Err(
      "Offline worksheet exceeds the 2-million-character backup limit.",
    )
  }
  let parsed = @json.parse(text) catch {
    _ => return Err("Offline worksheet is not valid JSON.")
  }
  let body = match parsed {
    {
      "contract_id": "moonfind.offline-decision-brief.v1",
      "worksheet": value,
      ..
    } => value
    _ => parsed
  }
  let sheet : OfflineWorksheet = @json.from_json(body) catch {
    _ =>
      return Err(
        "Unsupported offline worksheet shape; original bytes remain unchanged.",
      )
  }
  if sheet.contract_id != "moonfind.offline-choice-worksheet.v1" ||
    sheet.history.length() > 20 {
    return Err("Unsupported offline worksheet contract or excessive history.")
  }
  let problem = offline_version_issue(sheet.current, brief_id)
  if problem != "" {
    return Err(problem)
  }
  let known_bases : Map[String, Json] = Map([])
  for version in sheet.history + [sheet.current] {
    let basis = version.basis.to_json()
    if known_bases.get(version.basis.revision_id) is Some(old) && old != basis {
      return Err(
        "One immutable saved revision has conflicting retained basis data.",
      )
    }
    known_bases[version.basis.revision_id] = basis
  }
  let mut previous = 0
  for version in sheet.history {
    if version.revision <= previous ||
      version.revision >= sheet.current.revision ||
      offline_version_issue(version, brief_id) != "" {
      return Err("Invalid retained offline worksheet history.")
    }
    previous = version.revision
  }
  for version in sheet.history + [sheet.current] {
    for item in version.options {
      if item.historical_source is Some(citation) &&
        !sheet.history.any(old => {
          old.revision < version.revision &&
          old.basis.brief.brief_id == citation.brief_id &&
          old.basis.revision_id == citation.revision_id &&
          old.options.any(option => {
            option.id == item.id &&
            option.source_slot == "source-\{citation.source.slot}"
          }) &&
          offline_citation(old.basis, "source-\{citation.source.slot}")
          .map(retained => {
            retained.source.to_json() == citation.source.to_json() &&
            retained.capture == citation.capture
          })
          .unwrap_or(false)
        }) {
        return Err(
          "Historical source citation is not bound to an earlier retained option and exact source dossier.",
        )
      }
    }
  }
  Ok(sheet)
}

///|
fn offline_continue(
  sheet : OfflineWorksheet,
  basis : BriefSnapshot,
) -> Result[OfflineWorksheet, String] {
  if offline_basis_issue(basis) != "" ||
    basis.brief.brief_id != sheet.current.basis.brief.brief_id {
    return Err(
      "Open a complete saved revision of this same brief before continuing.",
    )
  }
  if (sheet.history + [sheet.current]).any(version => {
      version.basis.revision_id == basis.revision_id &&
      version.basis.to_json() != basis.to_json()
    }) {
    return Err(
      "This immutable revision ID conflicts with an already retained basis. Nothing changed; recover a trusted backup or use a distinct brief ID.",
    )
  }
  if basis.to_json() == sheet.current.basis.to_json() {
    return Ok(sheet)
  }
  if sheet.current.revision >= 2147483647 || sheet.history.length() >= 20 {
    return Err(
      "Revision/history limit reached. Download the complete backup; no earlier version was discarded.",
    )
  }
  let current = sheet.current
  let next = {
    ..sheet,
    history: sheet.history + [current],
    current: {
      ..current,
      revision: current.revision + 1,
      basis,
      options: current.options.map(item => {
        let old = offline_citation(current.basis, item.source_slot)
        let now = offline_citation(basis, item.source_slot)
        let same = match (old, now) {
          (Some(a), Some(b)) =>
            a.source.to_json() == b.source.to_json() && a.capture == b.capture
          _ => false
        }
        if item.source_slot == "" || same {
          item
        } else {
          { ..item, source_slot: "", historical_source: old, }
        }
      }),
    },
  }
  if offline_export_json(next, false).stringify(indent=2).length() + 1 > 2000000 {
    return Err(
      "Retaining the next version would exceed the backup limit; no version changed or disappeared.",
    )
  }
  Ok(next)
}

///|
fn offline_export_json(sheet : OfflineWorksheet, current : Bool) -> Json {
  {
    "contract_id": "moonfind.offline-decision-brief.v1",
    "boundary": offline_boundary(),
    "native_basis_matches_loaded_revision": current,
    "company_decision_recorded": false,
    "provenance_note": "Native-source match is only a comparison with the currently loaded prepared snapshot. Restored historical copies are user-supplied, not independently reverified host records.",
    "worksheet": sheet.to_json(),
  }
}
