///|
fn reference_list_export(view : BriefView) -> String raise {
  guard !view.pending else {
    fail("Wait for the current brief operation before exporting.")
  }
  let catalog = reference_catalog(view)
  guard catalog.issues.is_empty() else {
    fail(
      "Resolve unreadable bibliography selections before exporting the reading list.",
    )
  }
  let matches = reference_matches(view, catalog)
  reference_timeline_require(view)
  let counts = reference_doi_counts(catalog)
  let captures : Array[Json] = []
  for i, source in view.draft.sources {
    if matches.any(r => r.source_slot == i + 1) {
      captures.push({
        "source_slot": i + 1,
        "name": source.name,
        "origin": source.origin,
        "captured_at": source.captured_at,
        "kind": source.kind,
      })
    }
  }
  let revision_id : String? = match view.opened {
    Some(status) if status.state == "prepared" &&
      status.brief_id == view.draft.brief_id &&
      status.snapshot is Some(snapshot) &&
      snapshot.brief == view.draft => Some(status.revision_id)
    _ => None
  }
  (
    {
      "contract_id": "moonfind.reference-reading-list.v1",
      "brief_id": view.draft.brief_id,
      "revision_id": match revision_id {
        Some(id) => Json::string(id)
        None => Json::null()
      },
      "query": view.reference_query,
      "same_doi_candidates_only": view.reference_duplicates,
      "exact_doi_group": view.reference_doi_filter,
      "publication_year_scope": view.reference_timeline.scope,
      "from_year": if view.reference_timeline.scope == "years" {
        view.reference_timeline.from_year.to_json()
      } else {
        Json::null()
      },
      "through_year": if view.reference_timeline.scope == "years" {
        view.reference_timeline.through_year.to_json()
      } else {
        Json::null()
      },
      "reference_order": view.reference_timeline.order,
      "catalog_count": catalog.references.length(),
      "exported_count": matches.length(),
      "selection_captures": captures.to_json(),
      "references": matches.to_json(),
      "doi_candidate_counts": matches
      .filter(r => !r.doi_match_key.is_empty())
      .map(r => {
        (
          {
            "source_slot": r.source_slot,
            "record_number": r.record_number,
            "catalog_matches": counts.get(r.doi_match_key).unwrap_or(0),
          } : Json)
      })
      .to_json(),
      "semantics": "Exports exactly the currently matching cards in the selected order. Publication-year scope recognizes one valid numeric YYYY, YYYY-M or YYYY-M-D date; literal, blank, uncertain and range dates remain unclassified. Bounds are inclusive and blank bounds are open-ended. Year order places unclassified dates last and keeps source-slot/retained-record order for ties. Search is a trimmed, case-insensitive literal substring, without Unicode normalization. Candidate counts use the entire loaded catalog, so peers can be hidden by filters. DOI keys trim outside whitespace, remove one doi: or http(s)://(dx.)doi.org/ prefix, and fold ASCII case for a conservative DOI-shaped token. No percent decoding, punctuation stripping, title matching, merging or reference deduplication.",
      "boundary": "A reading list, not a restorable dossier, citation-style export, verified publication, full-text review, approved decision or research completion. Source digests are copied claims from retained selections, not reverified here. Use the saved dossier for original bytes and host manifests. Only matching reference metadata and contributing capture descriptors are exported; no original capture bodies are included. Missing metadata stays empty. Review metadata, abstracts and source origins before sharing.",
    } : Json).stringify(indent=2)
}

///|
extern "js" fn reference_list_download(content : String) -> String =
  #|content => {
  #| let url,link;
  #| try {
  #|  url=URL.createObjectURL(new Blob([content],{type:'application/json;charset=utf-8'}));
  #|  link=document.createElement('a'); link.href=url; link.download='moonfind-reference-reading-list.json';
  #|  document.body.appendChild(link); link.click(); return '';
  #| } catch (_) {return 'Reading-list download failed; the current reference list remains available. Try again.';}
  #| finally {if(link) link.remove(); if(url) setTimeout(()=>URL.revokeObjectURL(url),1000);}
  #|}
