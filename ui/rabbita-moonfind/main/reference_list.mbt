///|
// The slot and original record remain separate identities even for a DOI match.
struct ReadingReference {
  source_slot : Int
  selection_name : String
  source_name : String
  source_digest : String
  format : String
  record_number : Int
  item_id : String
  item_id_kind : String
  citation_key : String
  reference_type : String
  title : String
  authors : Array[String]
  editors : Array[String]
  issued : String
  venue : String
  keywords : String
  doi : String
  doi_match_key : String
  url : String
  abstract_text : String
  availability : String
} derive(Debug, Eq, ToJson, FromJson)

///|
struct ReferenceCatalog {
  references : Array[ReadingReference]
  issues : Array[String]
}

///|
// Only recognize a conservative DOI-shaped token. This is not DOI validation.
extern "js" fn reference_doi_key(value : String) -> String =
  #|value => {
  #| const token=value.trim().replace(/^(?:doi:\s*|https?:\/\/(?:dx\.)?doi\.org\/)/i,'');
  #| return /^10\.[0-9]{4,9}\/[^\s<>"\u0000-\u001f\u007f-\u009f]+$/.test(token) ? token.replace(/[A-Z]/g,c=>c.toLowerCase()) : '';
  #|}

///|
extern "js" fn reference_capture_text(hex : String) -> String =
  #|hex => {
  #| if(hex.length>65536 || !/^(?:[0-9a-fA-F]{2})+$/.test(hex)) return '';
  #| try {return new TextDecoder('utf-8',{fatal:true}).decode(Uint8Array.from(hex.match(/../g),p=>parseInt(p,16)));} catch (_) {return '';}
  #|}

///|
fn reference_selection(
  source : BriefInputSource,
  slot : Int,
) -> Array[ReadingReference] raise {
  let json = @json.parse(reference_capture_text(source.content_hex))
  let references : Array[ReadingReference] = []
  match source.name {
    "bibtex-selection.json" => {
      let selection : BibtexSelection = @json.from_json(json)
      guard selection.contract_id == "moonfind.bibtex-selection.v1" else {
        fail("Unsupported BibTeX selection contract")
      }
      for r in selection.references {
        references.push({
          source_slot: slot,
          selection_name: source.name,
          source_name: selection.source_name,
          source_digest: selection.source_digest,
          format: "bibtex",
          record_number: r.record_number,
          item_id: "",
          item_id_kind: "",
          citation_key: r.citation_key,
          reference_type: r.reference_type,
          title: r.title,
          authors: r.authors,
          editors: [],
          issued: r.year,
          venue: r.venue,
          keywords: r.keywords,
          doi: r.doi,
          doi_match_key: reference_doi_key(r.doi),
          url: r.url,
          abstract_text: r.abstract_text,
          availability: if r.abstract_text.is_blank() {
            "metadata-only"
          } else {
            "metadata-and-abstract"
          },
        })
      }
    }
    "csl-selection.json" => {
      let selection : CslSelection = @json.from_json(json)
      guard selection.contract_id == "moonfind.csl-selection.v1" else {
        fail("Unsupported CSL selection contract")
      }
      for r in selection.references {
        references.push({
          source_slot: slot,
          selection_name: source.name,
          source_name: selection.source_name,
          source_digest: selection.source_digest,
          format: "csl",
          record_number: r.record_number,
          item_id: r.item_id,
          item_id_kind: r.item_id_kind,
          citation_key: r.citation_key,
          reference_type: r.reference_type,
          title: r.title,
          authors: r.authors,
          editors: r.editors,
          issued: r.issued,
          venue: r.venue,
          keywords: r.keywords,
          doi: r.doi,
          doi_match_key: reference_doi_key(r.doi),
          url: r.url,
          abstract_text: r.abstract_text,
          availability: if r.abstract_text.is_blank() {
            "metadata-only"
          } else {
            "metadata-and-abstract"
          },
        })
      }
    }
    "ris-selection.json" => {
      let selection : RisSelection = @json.from_json(json)
      guard selection.contract_id == "moonfind.ris-selection.v1" else {
        fail("Unsupported RIS selection contract")
      }
      for r in selection.references {
        references.push({
          source_slot: slot,
          selection_name: source.name,
          source_name: selection.source_name,
          source_digest: selection.source_digest,
          format: "ris",
          record_number: r.record_number,
          item_id: "",
          item_id_kind: "",
          citation_key: "",
          reference_type: r.reference_type,
          title: r.title,
          authors: r.authors,
          editors: [],
          issued: r.year,
          venue: "",
          keywords: "",
          doi: r.doi,
          doi_match_key: reference_doi_key(r.doi),
          url: r.url,
          abstract_text: r.abstract_text,
          availability: if r.abstract_text.is_blank() {
            "metadata-only"
          } else {
            "metadata-and-abstract"
          },
        })
      }
    }
    "endnote-selection.json" => {
      let selection : EndnoteSelection = @json.from_json(json)
      guard selection.contract_id == "moonfind.endnote-selection.v1" else {
        fail("Unsupported EndNote selection contract")
      }
      for r in selection.references {
        references.push({
          source_slot: slot,
          selection_name: source.name,
          source_name: selection.source_name,
          source_digest: selection.source_digest,
          format: "endnote",
          record_number: r.record_number,
          item_id: "",
          item_id_kind: "",
          citation_key: "",
          reference_type: r.reference_type,
          title: r.title,
          authors: r.authors,
          editors: r.editors,
          issued: r.year,
          venue: r.venue,
          keywords: r.keywords,
          doi: r.doi,
          doi_match_key: reference_doi_key(r.doi),
          url: r.url,
          abstract_text: r.abstract_text,
          availability: if r.abstract_text.is_blank() {
            "metadata-only"
          } else {
            "metadata-and-abstract"
          },
        })
      }
    }
    "nbib-selection.json" => {
      let selection : NbibSelection = @json.from_json(json)
      guard selection.contract_id == "moonfind.nbib-selection.v1" else {
        fail("Unsupported PubMed NBIB selection contract")
      }
      for r in selection.references {
        references.push({
          source_slot: slot,
          selection_name: source.name,
          source_name: selection.source_name,
          source_digest: selection.source_digest,
          format: "nbib",
          record_number: r.record_number,
          item_id: r.pmid,
          item_id_kind: "pmid",
          citation_key: "",
          reference_type: r.reference_type,
          title: r.title,
          authors: r.authors,
          editors: r.editors,
          issued: r.year,
          venue: r.venue,
          keywords: r.keywords,
          doi: r.doi,
          doi_match_key: reference_doi_key(r.doi),
          url: r.url,
          abstract_text: r.abstract_text,
          availability: if r.abstract_text.is_blank() {
            "metadata-only"
          } else {
            "metadata-and-abstract"
          },
        })
      }
    }
    _ => ()
  }
  let seen : Map[Int, Bool] = Map([])
  for r in references {
    guard r.record_number > 0 &&
      !seen.contains(r.record_number) &&
      !r.source_name.is_blank() &&
      !r.source_digest.is_blank() else {
      fail("Missing source identity or repeated original record number")
    }
    seen[r.record_number] = true
  }
  references
}

///|
fn reference_catalog(view : BriefView) -> ReferenceCatalog {
  let references : Array[ReadingReference] = []
  let issues : Array[String] = []
  for index, source in view.draft.sources {
    if source.name
      is ("bibtex-selection.json"
      | "csl-selection.json"
      | "ris-selection.json"
      | "endnote-selection.json"
      | "nbib-selection.json") {
      try {
        let added = reference_selection(source, index + 1)
        for reference in added {
          references.push(reference)
        }
      } catch {
        _ =>
          issues.push(
            "Source slot \{index + 1}: " +
            source.name +
            " could not be read as a supported selection; repair or remove it before export.",
          )
      }
    }
  }
  { references, issues, }
}

///|
fn reference_doi_counts(catalog : ReferenceCatalog) -> Map[String, Int] {
  let counts : Map[String, Int] = Map([])
  for reference in catalog.references {
    let key = reference.doi_match_key
    if !key.is_empty() {
      counts[key] = counts.get(key).unwrap_or(0) + 1
    }
  }
  counts
}

///|
fn reference_search_matches(
  view : BriefView,
  catalog : ReferenceCatalog,
) -> Array[ReadingReference] {
  let query = csl_lower(view.reference_query.trim().to_owned())
  let counts = reference_doi_counts(catalog)
  catalog.references.filter(r => {
    (
      view.reference_doi_filter.is_empty() ||
      r.doi_match_key == view.reference_doi_filter
    ) &&
    (!view.reference_duplicates || counts.get(r.doi_match_key).unwrap_or(0) > 1) &&
    csl_lower(
      [
        r.source_name,
        r.format,
        r.item_id,
        r.citation_key,
        r.reference_type,
        r.title,
        r.authors.join("; "),
        r.editors.join("; "),
        r.issued,
        r.venue,
        r.keywords,
        r.doi,
        r.doi_match_key,
        r.url,
        r.abstract_text,
        r.availability,
      ].join(" "),
    ).contains(query)
  })
}

///|
enum ReferenceListMsg {
  Timeline(ReferenceTimelineMsg)
  Shortlist(ReferenceShortlistMsg)
  Query(String)
  Duplicates
  Clear
  ShowDoi(String)
  Export
  ExportRis
  ExportCsl
  ExportBibtex
}

///|
fn update_reference_list(
  action : ReferenceListMsg,
  view : BriefView,
) -> (@rabbita.Cmd, BriefView) {
  if view.pending {
    return (@rabbita.none, view)
  }
  match action {
    Timeline(action) => update_reference_timeline(action, view)
    Shortlist(action) => update_reference_shortlist(action, view)
    Query(query) => (@rabbita.none, { ..view, reference_query: query, })
    Duplicates =>
      (
        @rabbita.none,
        {
          ..view,
          reference_duplicates: !view.reference_duplicates,
          reference_doi_filter: "",
        },
      )
    Clear =>
      (
        @rabbita.none,
        {
          ..view,
          reference_query: "",
          reference_duplicates: false,
          reference_doi_filter: "",
          reference_timeline: initial_reference_timeline(),
        },
      )
    ShowDoi(key) => {
      let counts = reference_doi_counts(reference_catalog(view))
      if counts.get(key).unwrap_or(0) <= 1 {
        return (@rabbita.none, view)
      }
      (
        @rabbita.none,
        {
          ..view,
          reference_query: "",
          reference_duplicates: true,
          reference_doi_filter: key,
          reference_timeline: initial_reference_timeline(),
        },
      )
    }
    Export => {
      let result = reference_list_download(reference_list_export(view)) catch {
        error => "\{error}"
      }
      (
        @rabbita.none,
        { ..view, error: if result.is_empty() { None } else { Some(result) }, },
      )
    }
    ExportBibtex => {
      let result = reference_bibtex_download(
        reference_bibtex_export(view),
        false,
      ) catch {
        error => "\{error}"
      }
      (
        @rabbita.none,
        { ..view, error: if result.is_empty() { None } else { Some(result) }, },
      )
    }
    ExportCsl => {
      let result = reference_csl_download(reference_csl_export(view), false) catch {
        error => "\{error}"
      }
      (
        @rabbita.none,
        { ..view, error: if result.is_empty() { None } else { Some(result) }, },
      )
    }
    ExportRis => {
      let result = reference_ris_download(reference_ris_export(view)) catch {
        error => "\{error}"
      }
      (
        @rabbita.none,
        { ..view, error: if result.is_empty() { None } else { Some(result) }, },
      )
    }
  }
}
