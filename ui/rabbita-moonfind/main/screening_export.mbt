///|
fn screening_export_ready(view : BriefView) -> Unit raise {
  guard !view.pending &&
    !view.screening.blocked &&
    view.screening.log.brief_id == view.draft.brief_id &&
    reference_catalog(view).issues.is_empty() &&
    reference_timeline_problem(view.reference_timeline) is None else {
    fail(
      "Wait for the brief operation and resolve unreadable sources, storage or invalid year filters before exporting screening results.",
    )
  }
}

///|
fn screening_json(view : BriefView) -> String raise {
  screening_export_ready(view)
  let result = (
    {
      "contract_id": "moonfind.screening-report.v1",
      "brief_id": view.draft.brief_id,
      "question": view.draft.question,
      "scope": view.screening.scope,
      "reading_list_filters": {
        "query": view.reference_query,
        "doi_candidates_only": view.reference_duplicates,
        "doi_group": view.reference_doi_filter,
        "publication_years": ToJson::to_json(view.reference_timeline),
      },
      "visible_rows": screening_matches(view)
      .map(reference => {
        (
          {
            "reference": ToJson::to_json(reference),
            "status": screening_status(view, reference),
            "latest_decision": screening_latest(view, reference).to_json(),
          } : Json)
      })
      .to_json(),
      "history_revision": view.screening.log.revision,
      "complete_history": ToJson::to_json(view.screening.log.decisions),
      "browser_save_verified": view.screening.saved,
      "boundary": "Human-authored citation screening, not scientific acceptance or full-text review. Visible rows respect text/DOI/year and screening-status filters. Complete history includes all decisions, prior revisions and detached captures, including private rationales and full selection-capture bodies. Other brief source bodies are excluded. An unsaved editor is not a confirmed decision and is excluded. This export is inspectable JSON; no automatic restore/import is provided. Native brief Save does not include this browser-local history.",
    } : Json).stringify(indent=2)
  guard brief_text_hex(result).length() <= 8 * 1024 * 1024 else {
    fail(
      "Screening report exceeds 4 MiB; narrow the visible-row filters before exporting.",
    )
  }
  result
}

///|
// Quote every CSV cell and neutralize spreadsheet formula prefixes.
extern "js" fn screening_csv_cell(value : String) -> String =
  #|value => {
  #| const safe=/^[\s\u0000-\u001f\u007f]*[=+\-@]/u.test(value) ? "'"+value : value;
  #| return '"'+safe.replaceAll('"','""')+'"';
  #|}

///|
fn screening_csv(view : BriefView) -> String raise {
  screening_export_ready(view)
  let lines = [
    [
      "brief_id", "source_slot", "source_name", "source_digest", "original_record",
      "title", "authors", "availability", "doi", "screening_status", "rationale",
      "decision_sequence",
    ]
    .map(screening_csv_cell)
    .join(","),
  ]
  for reference in screening_matches(view) {
    let entry = screening_latest(view, reference)
    lines.push(
      [
        view.draft.brief_id,
        reference.source_slot.to_string(),
        reference.source_name,
        reference.source_digest,
        reference.record_number.to_string(),
        reference.title,
        reference.authors.join("; "),
        reference.availability,
        reference.doi,
        screening_status(view, reference),
        entry.map(x => x.rationale).unwrap_or(""),
        entry.map(x => x.sequence.to_string()).unwrap_or(""),
      ]
      .map(screening_csv_cell)
      .join(","),
    )
  }
  let result = lines.join("\r\n") + "\r\n"
  guard brief_text_hex(result).length() <= 4 * 1024 * 1024 else {
    fail("Screening CSV exceeds 2 MiB; narrow the visible-row filters.")
  }
  result
}

///|
extern "js" fn screening_download(content : String, csv : Bool) -> String =
  #|(content,csv) => {
  #| let url,link;
  #| try {
  #|  url=URL.createObjectURL(new Blob([content],{type:csv?'text/csv;charset=utf-8':'application/json;charset=utf-8'}));
  #|  link=document.createElement('a'); link.href=url; link.download=csv?'moonfind-screening.csv':'moonfind-screening-history.json';
  #|  document.body.appendChild(link); link.click(); return '';
  #| } catch (_) {return 'Screening download failed. Decisions remain available; retry before leaving.';}
  #| finally {if(link) link.remove(); if(url) setTimeout(()=>URL.revokeObjectURL(url),1000);}
  #|}
