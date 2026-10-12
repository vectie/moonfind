///|
struct BriefInputSource {
  name : String
  origin : String
  captured_at : String
  kind : String
  content_hex : String
} derive(Debug, Eq, ToJson, FromJson)

///|
struct BriefDraft {
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
  sources : Array[BriefInputSource]
} derive(Debug, Eq, ToJson, FromJson)

///|
struct BriefSource {
  slot : Int
  name : String
  origin : String
  captured_at : String
  kind : String
  availability : String
  archive_path : String
  byte_count : Int
  digest : String
} derive(Debug, ToJson, FromJson)

///|
struct BriefSnapshot {
  contract_id : String
  revision_id : String
  state : String
  brief : BriefDraft
  sources : Array[BriefSource]
  boundary : String
} derive(Debug, ToJson, FromJson)

///|
struct BriefStatus {
  contract_id : String
  brief_id : String
  revision_id : String
  state : String
  snapshot : BriefSnapshot?
  issues : Array[String]
} derive(Debug, FromJson)

///|
struct BriefListItem {
  brief_id : String
  revision_id : String
  question : String
  state : String
} derive(Debug, FromJson)

///|
struct BriefView {
  transcript : TranscriptView
  json_evidence : JsonEvidenceView
  reading_notes : ReadingNotesState
  reading_note_sessions : Map[String, ReadingNotesState]
  reference_shortlist : Array[ReferenceChoice]
  reference_source_generation : Int
  reference_query : String
  reference_duplicates : Bool
  reference_doi_filter : String
  reference_timeline : ReferenceTimeline
  search_query : String
  search_fold : Bool
  search_open : (Int, Int)?
  ris : RisView
  bibtex : BibtexView
  csl : CslView
  csv : CsvView
  draft : BriefDraft
  generation : Int
  pending : Bool
  catalog : Array[BriefListItem]
  opened : BriefStatus?
  error : String?
  storage_problem : String?
  restored_draft : Bool
  paste_name : String
  paste_origin : String
  paste_text : String
}

///|
enum BriefMsg {
  Transcript(TranscriptMsg)
  JsonEvidence(JsonEvidenceMsg)
  ReadingNotes(String, Int, ReadingNotesMsg)
  ReferenceList(ReferenceListMsg)
  SearchQuery(String)
  SearchFold
  SearchOpen(Int, Int)
  SearchExport
  Ris(RisMsg)
  Bibtex(BibtexMsg)
  Csl(CslMsg)
  Csv(CsvMsg)
  New
  Edit(String, String)
  PasteField(String, String)
  AddPaste
  ChooseFiles
  FilesLoaded(Int, String)
  RemoveSource(Int)
  Save
  Open(String, String)
  Loaded(Int, String, String, Result[Json, Error])
  Refresh
  Listed(Int, Result[Json, Error])
}

///|
extern "js" fn brief_new_id() -> String =
  #|() => 'brief-' + (globalThis.crypto?.randomUUID?.() || Date.now().toString(36) + '-' + Math.random().toString(36).slice(2))

///|
extern "js" fn brief_now() -> String = "() => new Date().toISOString()"

///|
extern "js" fn browser_brief_mode() -> Bool =
  #|() => globalThis.location?.pathname === '/apps/moonfind/briefs'

///|
extern "js" fn brief_source_preview(hex : String) -> String =
  #|hex => { try { return new TextDecoder('utf-8', {fatal:true, ignoreBOM:true}).decode(Uint8Array.from(hex.match(/../g) || [], part => parseInt(part,16))); } catch (_) { return 'Unsupported source encoding; save will reject these bytes'; } }

///|
extern "js" fn brief_text_hex(text : String) -> String =
  #|(text) => Array.from(new TextEncoder().encode(text), b => b.toString(16).padStart(2, '0')).join('')

///|
extern "js" fn brief_choose_files(
  done : (String) -> Unit,
  accept : String,
  multiple : Bool,
) -> Unit =
  #|(done, accept, multiple) => {
  #|  const input = document.createElement('input'); input.type = 'file'; input.multiple = multiple;
  #|  input.accept = accept;
  #|  input.addEventListener('change', async () => {
  #|    try {
  #|      const files = Array.from(input.files || []);
  #|      if (files.length > 8 || files.reduce((n, f) => n + f.size, 0) > 131072) throw new Error('Choose at most 8 sources and 128 KiB total');
  #|      const sources = [];
  #|      for (const file of files) {
  #|        if (file.size > 32768 || !/\.(txt|md|csv|json|bib|ris)$/i.test(file.name)) throw new Error('Only UTF-8 text, Markdown, CSV, JSON, BibTeX or RIS up to 32 KiB each is supported');
  #|        const bytes = new Uint8Array(await file.arrayBuffer());
  #|        const text = new TextDecoder('utf-8', {fatal: true, ignoreBOM: true}).decode(bytes);
  #|        if (/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(text)) throw new Error('Binary control bytes are unsupported');
  #|        sources.push({name: file.name, origin: 'User-selected local file: ' + file.name, captured_at: new Date().toISOString(), kind: 'local-file', content_hex: Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('')});
  #|      }
  #|      done(JSON.stringify({sources}));
  #|    } catch (error) { done(JSON.stringify({error: String(error)})); }
  #|  }, {once: true});
  #|  input.click();
  #|}

///|
fn blank_brief() -> BriefDraft {
  {
    contract_id: "moonfind.research-brief.v1",
    brief_id: brief_new_id(),
    parent_revision: None,
    question: "",
    objective: "",
    audience: "",
    decision: "",
    source_restrictions: "Use only the selected local captures. No remote fetching.",
    requested_filenames: ["research-report.md"],
    acceptance_criteria: "",
    sources: [],
  }
}

///|
fn initial_brief_view() -> BriefView {
  let (restored, storage_problem) : (BriefDraft?, String?) = try {
    match @json.parse(choice_storage_read("moonfind.offline-brief.v1")) {
      { "value": String(value), .. } => {
        let draft : BriefDraft = @json.from_json(@json.parse(value))
        guard draft.contract_id == "moonfind.research-brief.v1" &&
          !draft.brief_id.is_blank() else {
          fail("Unsupported stored brief")
        }
        (Some(draft), None)
      }
      { "missing": True, .. } => (None, None)
      { "error": String(message), .. } => fail(message)
      _ => fail("Unknown browser storage response")
    }
  } catch {
    error =>
      (
        None,
        Some(
          "The previous browser draft could not be read and has not been replaced. Recover it or use New blank brief explicitly before replacing its browser copy. Details: \{error}",
        ),
      )
  }
  let draft = restored.unwrap_or_else(blank_brief)
  sync_reading_notes({
    reading_notes: restore_reading_notes(draft),
    reading_note_sessions: {},
    ris: empty_ris_view(),
    reference_shortlist: [],
    reference_source_generation: 0,
    reference_query: "",
    reference_duplicates: false,
    reference_doi_filter: "",
    reference_timeline: initial_reference_timeline(),
    search_query: "",
    search_fold: false,
    search_open: None,
    bibtex: empty_bibtex_view(),
    csl: empty_csl_view(),
    csv: empty_csv_view(),
    json_evidence: empty_json_evidence_view(),
    transcript: empty_transcript_view(),
    draft,
    generation: 0,
    pending: false,
    catalog: [],
    opened: None,
    error: None,
    storage_problem,
    restored_draft: restored is Some(_),
    paste_name: "notes.txt",
    paste_origin: "",
    paste_text: "",
  })
}

///|
fn brief_reply_error(payload : Json) -> String? {
  match payload {
    { "error": { "message": String(message), .. }, .. } => Some(message)
    _ => None
  }
}

///|
fn brief_catalog_command(
  emit : @rabbita.Emit[Msg],
  generation : Int,
) -> @rabbita.Cmd {
  @http.get(product_api_url("/api/v1/briefs")).expect_json(
    emit.map(result => BriefAction(Listed(generation, result))),
  )
}

///|
fn brief_edited(view : BriefView, draft : BriefDraft) -> BriefView {
  let parent = match view.opened {
    Some(status) if status.state == "prepared" => Some(status.revision_id)
    _ => draft.parent_revision
  }
  {
    ..view,
    draft: { ..draft, parent_revision: parent, },
    opened: None,
    generation: view.generation + 1,
    reference_source_generation: if reference_sources_appended(
        view.draft.sources,
        draft.sources,
      ) {
      view.reference_source_generation
    } else {
      view.reference_source_generation + 1
    },
    search_open: None,
    error: None,
  }
}

///|
fn update_brief(
  emit : @rabbita.Emit[Msg],
  action : BriefMsg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  let (command, view) = update_brief_view(emit, action, model.brief)
  let error = if view.draft != model.brief.draft && view.storage_problem is None {
    let failure = choice_storage_write(
      "moonfind.offline-brief.v1",
      view.draft.to_json().stringify(),
    )
    if failure.is_blank() {
      view.error
    } else {
      Some(
        "Browser draft retention failed. Keep this page open until the native host confirms save: " +
        failure,
      )
    }
  } else {
    view.error
  }
  (command, { ..model, brief: { ..view, error, }, })
}

///|
fn reduce_brief_view(
  emit : @rabbita.Emit[Msg],
  action : BriefMsg,
  view : BriefView,
) -> (@rabbita.Cmd, BriefView) {
  match action {
    ReadingNotes(key, revision, action) =>
      update_reading_notes(emit, key, revision, action, view)
    ReferenceList(action) => update_reference_list(action, view)
    SearchQuery(query) =>
      (@rabbita.none, { ..view, search_query: query, search_open: None, })
    SearchFold =>
      (
        @rabbita.none,
        { ..view, search_fold: !view.search_fold, search_open: None, },
      )
    SearchOpen(slot, line) => {
      let results = dossier_search(view)
      (
        @rabbita.none,
        {
          ..view,
          search_open: if results.hits.any(hit => {
              hit.slot == slot && hit.line == line
            }) {
            Some((slot, line))
          } else {
            None
          },
        },
      )
    }
    SearchExport => {
      let result = dossier_download(dossier_export(view)) catch {
        error => "\{error}"
      }
      (
        @rabbita.none,
        { ..view, error: if result.is_empty() { None } else { Some(result) }, },
      )
    }
    Ris(action) => update_ris_view(emit, action, view)
    Bibtex(action) => update_bibtex_view(emit, action, view)
    Csl(action) => update_csl_view(emit, action, view)
    Csv(action) => update_csv_view(emit, action, view)
    JsonEvidence(action) => update_json_evidence(emit, action, view)
    Transcript(action) => update_transcript(emit, action, view)
    New =>
      (
        @rabbita.none,
        {
          ..view,
          ris: empty_ris_view(),
          bibtex: empty_bibtex_view(),
          csl: empty_csl_view(),
          csv: empty_csv_view(),
          json_evidence: empty_json_evidence_view(),
          transcript: empty_transcript_view(),
          draft: blank_brief(),
          reference_shortlist: [],
          reference_source_generation: view.reference_source_generation + 1,
          reference_query: "",
          reference_duplicates: false,
          reference_doi_filter: "",
          reference_timeline: initial_reference_timeline(),
          search_query: "",
          search_open: None,
          generation: view.generation + 1,
          pending: false,
          opened: None,
          error: None,
          storage_problem: None,
          restored_draft: false,
          paste_text: "",
        },
      )
    Edit(_, _) | AddPaste | ChooseFiles | RemoveSource(_) | Save | Open(_, _) if view.pending =>
      (@rabbita.none, view)
    Edit(field, value) => {
      let d = view.draft
      let draft = match field {
        "question" => { ..d, question: value, }
        "objective" => { ..d, objective: value, }
        "audience" => { ..d, audience: value, }
        "decision" => { ..d, decision: value, }
        "restrictions" => { ..d, source_restrictions: value, }
        "filenames" =>
          {
            ..d,
            requested_filenames: value
            .split("\n")
            .map(StringView::to_owned)
            .collect(),
          }
        "criteria" => { ..d, acceptance_criteria: value, }
        _ => d
      }
      (@rabbita.none, if draft == d { view } else { brief_edited(view, draft) })
    }
    PasteField(field, value) =>
      (
        @rabbita.none,
        match field {
          "name" => { ..view, paste_name: value, }
          "origin" => { ..view, paste_origin: value, }
          _ => { ..view, paste_text: value, }
        },
      )
    AddPaste => {
      if view.paste_origin.is_blank() ||
        view.paste_text.is_empty() ||
        view.draft.sources.length() >= 8 ||
        brief_text_hex(view.paste_text).length() > 65536 {
        return (
          @rabbita.none,
          {
            ..view,
            error: Some(
              "Record an origin and non-empty pasted text up to 32 KiB; at most 8 sources can be selected",
            ),
          },
        )
      }
      let source : BriefInputSource = {
        name: view.paste_name,
        origin: view.paste_origin,
        captured_at: brief_now(),
        kind: "pasted-text",
        content_hex: brief_text_hex(view.paste_text),
      }
      (
        @rabbita.none,
        {
          ..brief_edited(view, {
            ..view.draft,
            sources: view.draft.sources + [source],
          }),
          paste_text: "",
        },
      )
    }
    ChooseFiles => {
      let generation = view.generation
      (
        @cmd.custom_cmd(scheduler => {
          brief_choose_files(
            value => {
              scheduler.add(emit(BriefAction(FilesLoaded(generation, value))))
            },
            ".txt,.md,.csv,.json,.bib,.ris",
            true,
          )
        }),
        view,
      )
    }
    FilesLoaded(generation, _) if generation != view.generation || view.pending =>
      (@rabbita.none, view)
    FilesLoaded(_, raw) =>
      try {
        let payload = @json.parse(raw)
        if payload is { "error": String(error), .. } {
          return (@rabbita.none, { ..view, error: Some(error), })
        }
        guard payload is { "sources": sources, .. } else {
          fail("Invalid local source capture")
        }
        let sources : Array[BriefInputSource] = @json.from_json(sources)
        guard view.draft.sources.length() + sources.length() <= 8 else {
          fail("At most 8 sources can be selected")
        }
        (
          @rabbita.none,
          if sources.is_empty() {
            view
          } else {
            brief_edited(view, {
              ..view.draft,
              sources: view.draft.sources + sources,
            })
          },
        )
      } catch {
        error => (@rabbita.none, { ..view, error: Some("\{error}"), })
      }
    RemoveSource(index) => {
      let sources : Array[BriefInputSource] = []
      for i, source in view.draft.sources {
        if i != index {
          sources.push(source)
        }
      }
      (@rabbita.none, brief_edited(view, { ..view.draft, sources, }))
    }
    Save if view.opened.map(s => s.state == "prepared").unwrap_or(false) =>
      (@rabbita.none, view)
    Save => {
      let generation = view.generation + 1
      (
        @http.post(product_api_url("/api/v1/briefs"))
        .with_json(view.draft.to_json())
        .expect_json(
          emit.map(result => {
            BriefAction(Loaded(generation, view.draft.brief_id, "", result))
          }),
        ),
        { ..view, generation, pending: true, error: None, opened: None, },
      )
    }
    Open(id, revision) => {
      let generation = view.generation + 1
      (
        @http.get(product_api_url("/api/v1/briefs/" + id + "/" + revision)).expect_json(
          emit.map(result => {
            BriefAction(Loaded(generation, id, revision, result))
          }),
        ),
        { ..view, generation, pending: true, opened: None, error: None, },
      )
    }
    Loaded(generation, _, _, _) if generation != view.generation ||
      !view.pending => (@rabbita.none, view)
    Loaded(_, _, _, Err(error)) =>
      (
        @rabbita.none,
        {
          ..view,
          pending: false,
          error: Some(
            "Save/reopen was not confirmed. Retry the unchanged draft safely: \{error}",
          ),
        },
      )
    Loaded(_, id, revision, Ok(payload)) =>
      try {
        if brief_reply_error(payload) is Some(error) {
          fail(error)
        }
        let status : BriefStatus = @json.from_json(payload)
        guard status.contract_id == "moonfind.brief-status.v1" &&
          status.brief_id == id &&
          (revision.is_empty() || status.revision_id == revision) &&
          status.state is ("prepared" | "incomplete") else {
          fail("Host returned a different or unsupported brief revision")
        }
        let draft = if status.state == "prepared" {
          guard status.snapshot is Some(snapshot) &&
            snapshot.brief.brief_id == id &&
            snapshot.revision_id == status.revision_id &&
            snapshot.state == "prepared" else {
            fail("Prepared brief snapshot is missing or mismatched")
          }
          if revision.is_empty() && snapshot.brief != view.draft {
            fail("Saved brief does not match the submitted draft")
          }
          snapshot.brief
        } else {
          view.draft
        }
        (
          brief_catalog_command(emit, view.generation),
          {
            ..view,
            draft,
            reference_shortlist: if !revision.is_empty() &&
              status.state == "prepared" {
              []
            } else {
              view.reference_shortlist
            },
            reference_source_generation: if !revision.is_empty() &&
              status.state == "prepared" {
              view.reference_source_generation + 1
            } else {
              view.reference_source_generation
            },
            search_open: None,
            ris: empty_ris_view(),
            bibtex: empty_bibtex_view(),
            csl: empty_csl_view(),
            csv: empty_csv_view(),
            json_evidence: empty_json_evidence_view(),
            transcript: empty_transcript_view(),
            pending: false,
            opened: Some(status),
            restored_draft: if status.state == "prepared" {
              false
            } else {
              view.restored_draft
            },
            error: if status.issues.is_empty() {
              None
            } else {
              Some(status.issues.join("; "))
            },
          },
        )
      } catch {
        error =>
          (@rabbita.none, { ..view, pending: false, error: Some("\{error}"), })
      }
    Refresh => (brief_catalog_command(emit, view.generation), view)
    Listed(generation, _) if generation != view.generation =>
      (@rabbita.none, view)
    Listed(_, Err(error)) =>
      (
        @rabbita.none,
        { ..view, error: Some("Brief list unavailable: \{error}"), },
      )
    Listed(_, Ok(payload)) =>
      try {
        if brief_reply_error(payload) is Some(error) {
          fail(error)
        }
        let catalog : Array[BriefListItem] = @json.from_json(payload)
        (@rabbita.none, { ..view, catalog, })
      } catch {
        error =>
          (
            @rabbita.none,
            { ..view, error: Some("Brief list unavailable: \{error}"), },
          )
      }
  }
}

///|
fn update_brief_view(
  emit : @rabbita.Emit[Msg],
  action : BriefMsg,
  view : BriefView,
) -> (@rabbita.Cmd, BriefView) {
  let (command, next) = reduce_brief_view(emit, action, view)
  (command, sync_reading_notes(sync_json_evidence(sync_transcript(next))))
}
