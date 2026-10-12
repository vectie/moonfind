///|
// Selection is bound to the actual capture, record and source-list generation,
// never a DOI, citation key or slot alone. Source mutation invalidates old picks.
struct ReferenceChoice {
  reference : ReadingReference
  capture : BriefInputSource
  source_generation : Int
} derive(Debug, Eq)

///|
enum ReferenceShortlistMsg {
  Toggle(ReferenceChoice)
  Clear
  ExportJson
  ExportRis
  ExportCsl
  ExportBibtex
}

///|
fn reference_sources_appended(
  before : Array[BriefInputSource],
  after : Array[BriefInputSource],
) -> Bool {
  before.length() <= after.length() &&
  before.mapi((i, source) => source == after[i]).all(x => x)
}

///|
fn reference_choice(
  view : BriefView,
  reference : ReadingReference,
) -> ReferenceChoice {
  {
    reference,
    capture: view.draft.sources[reference.source_slot - 1],
    source_generation: view.reference_source_generation,
  }
}

///|
fn reference_choice_current(
  view : BriefView,
  catalog : ReferenceCatalog,
  choice : ReferenceChoice,
) -> Bool {
  choice.source_generation == view.reference_source_generation &&
  view.draft.sources.get(choice.reference.source_slot - 1) ==
  Some(choice.capture) &&
  catalog.references.contains(choice.reference)
}

///|
fn reference_shortlist_records(
  view : BriefView,
) -> Array[ReadingReference] raise {
  guard !view.pending else {
    fail("Wait for the current brief operation before exporting the shortlist.")
  }
  guard !view.reference_shortlist.is_empty() else {
    fail("The shortlist is empty. Add individual references first.")
  }
  let catalog = reference_catalog(view)
  guard catalog.issues.is_empty() else {
    fail(
      "Resolve unreadable bibliography selections before exporting the shortlist.",
    )
  }
  guard view.reference_shortlist.all(c => {
    reference_choice_current(view, catalog, c)
  }) else {
    fail(
      "The shortlist contains choices from changed or moved sources. Remove those choices and select the current records again.",
    )
  }
  view.reference_shortlist.map(c => c.reference)
}

///|
fn reference_shortlist_json(view : BriefView) -> String raise {
  let references = reference_shortlist_records(view)
  let captures : Array[Json] = []
  for i, source in view.draft.sources {
    if references.any(r => r.source_slot == i + 1) {
      captures.push({
        "source_slot": i + 1,
        "name": source.name,
        "origin": source.origin,
        "captured_at": source.captured_at,
        "kind": source.kind,
      })
    }
  }
  let result = (
    {
      "contract_id": "moonfind.reference-shortlist.v1",
      "brief_id": view.draft.brief_id,
      "export_scope": "explicit-shortlist",
      "exported_count": references.length(),
      "references": references.to_json(),
      "selection_captures": captures.to_json(),
      "semantics": "Exactly the individually chosen records, in selection order, independent of current search or DOI filters. Same-DOI records and repeated source captures stay separate. Removing a choice and adding it again moves it to the end.",
      "boundary": "Session-only selection, not saved with the brief or browser draft; reload, successful reopen and New blank brief clear it. Source removal or replacement makes existing choices unavailable until removed and reselected. Appending sources preserves choices. Metadata, abstracts, digests and origins are supplied claims, not verified full text or publication identity. No original capture bodies; retain the dossier and review before sharing.",
    } : Json).stringify(indent=2)
  guard brief_text_hex(result).length() <= 2 * 1024 * 1024 else {
    fail("Shortlist JSON exceeds 1 MiB; remove some choices before exporting.")
  }
  result
}

///|
fn reference_shortlist_ris(view : BriefView) -> String raise {
  reference_ris_records(view, reference_shortlist_records(view))
}

///|
fn update_reference_shortlist(
  action : ReferenceShortlistMsg,
  view : BriefView,
) -> (@rabbita.Cmd, BriefView) {
  // Also guard this reducer when called directly, not only through its parent.
  if view.pending {
    return (@rabbita.none, view)
  }
  match action {
    Clear => (@rabbita.none, { ..view, reference_shortlist: [], error: None, })
    Toggle(choice) => {
      if view.reference_shortlist.contains(choice) {
        return (
          @rabbita.none,
          {
            ..view,
            reference_shortlist: view.reference_shortlist.filter(c => {
              c != choice
            }),
            error: None,
          },
        )
      }
      if !reference_choice_current(view, reference_catalog(view), choice) {
        return (
          @rabbita.none,
          {
            ..view,
            error: Some(
              "This reference changed. Select it again from the current results.",
            ),
          },
        )
      }
      (
        @rabbita.none,
        {
          ..view,
          reference_shortlist: view.reference_shortlist + [choice],
          error: None,
        },
      )
    }
    ExportJson | ExportRis | ExportCsl | ExportBibtex => {
      let result = try {
        match action {
          ExportJson =>
            reference_shortlist_download(reference_shortlist_json(view), false)
          ExportBibtex =>
            reference_bibtex_download(reference_shortlist_bibtex(view), true)
          ExportCsl =>
            reference_csl_download(reference_shortlist_csl(view), true)
          _ => reference_shortlist_download(reference_shortlist_ris(view), true)
        }
      } catch {
        error => "\{error}"
      }
      (
        @rabbita.none,
        { ..view, error: if result.is_empty() { None } else { Some(result) }, },
      )
    }
  }
}

///|
extern "js" fn reference_shortlist_download(
  content : String,
  ris : Bool,
) -> String =
  #|(content,ris) => {
  #| let url,link;
  #| try {
  #|  url=URL.createObjectURL(new Blob([content],{type:ris?'application/x-research-info-systems;charset=utf-8':'application/json;charset=utf-8'}));
  #|  link=document.createElement('a'); link.href=url; link.download=ris?'moonfind-selected-references.ris':'moonfind-selected-references.json';
  #|  document.body.appendChild(link); link.click(); return '';
  #| } catch (_) {return 'Shortlist download failed; your choices remain available. Try again.';}
  #| finally {if(link) link.remove(); if(url) setTimeout(()=>URL.revokeObjectURL(url),1000);}
  #|}
