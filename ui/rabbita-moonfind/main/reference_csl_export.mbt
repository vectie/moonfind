///|
// Supported CSL types follow the CSL input-data schema. Unknown input types
// remain verbatim in custom.moonfind.reference and use the generic article type.
fn reference_csl_type(r : ReadingReference) -> String {
  let kind = csv_lower(r.reference_type)
  match (r.format, kind) {
    ("nbib", "journal article") => "article-journal"
    ("nbib", "book") => "book"
    ("nbib", "book chapter") => "chapter"
    ("endnote", "journal article") => "article-journal"
    ("endnote", "book" | "edited book") => "book"
    ("endnote", "book section") => "chapter"
    ("endnote", "conference paper") => "paper-conference"
    ("endnote", "thesis") => "thesis"
    ("endnote", "report") => "report"
    ("endnote", "web page") => "webpage"
    ("endnote", "blog") => "post-weblog"
    ("endnote", "newspaper article") => "article-newspaper"
    ("endnote", "magazine article") => "article-magazine"
    ("endnote", "dataset") => "dataset"
    ("endnote", "unpublished work") => "manuscript"
    ("bibtex", "article") | ("ris", "jour") => "article-journal"
    ("bibtex", "book") | ("ris", "book") => "book"
    ("bibtex", "inbook" | "incollection") | ("ris", "chap") => "chapter"
    ("bibtex", "inproceedings" | "conference") | ("ris", "cpaper") =>
      "paper-conference"
    ("bibtex", "phdthesis" | "mastersthesis") | ("ris", "thes") => "thesis"
    ("bibtex", "techreport") | ("ris", "rprt") => "report"
    ("bibtex", "unpublished") | ("ris", "unpb") => "manuscript"
    ("ris", "elec") => "webpage"
    ("ris", "news") => "article-newspaper"
    ("ris", "mgzn") => "article-magazine"
    ("ris", "data") => "dataset"
    ("csl", _) =>
      match kind {
        "article"
        | "article-journal"
        | "article-magazine"
        | "article-newspaper"
        | "bill"
        | "book"
        | "broadcast"
        | "chapter"
        | "classic"
        | "collection"
        | "dataset"
        | "document"
        | "entry"
        | "entry-dictionary"
        | "entry-encyclopedia"
        | "event"
        | "figure"
        | "graphic"
        | "hearing"
        | "interview"
        | "legal_case"
        | "legislation"
        | "manuscript"
        | "map"
        | "motion_picture"
        | "musical_score"
        | "pamphlet"
        | "paper-conference"
        | "patent"
        | "performance"
        | "periodical"
        | "personal_communication"
        | "post"
        | "post-weblog"
        | "regulation"
        | "report"
        | "review"
        | "review-book"
        | "software"
        | "song"
        | "speech"
        | "standard"
        | "thesis"
        | "treaty"
        | "webpage" => kind
        _ => "article"
      }
    _ => "article"
  }
}

///|
// Only unambiguous complete numeric dates become date-parts. Other supplied
// text (including seasons, uncertain dates and partial ranges) stays literal.
extern "js" fn reference_csl_date_json(value : String) -> String =
  #|value => {
  #| const one = text => {
  #|  const m=/^([0-9]{4})(?:-([0-9]{1,2})(?:-([0-9]{1,2}))?)?$/.exec(text);
  #|  if(!m) return null;
  #|  const parts=m.slice(1).filter(v=>v!==undefined).map(Number);
  #|  const [y,mo,d]=parts;
  #|  if(y<1 || (mo!==undefined && (mo<1 || mo>12))) return null;
  #|  if(d!==undefined) { const days=[31,(y%4===0 && (y%100!==0 || y%400===0))?29:28,31,30,31,30,31,31,30,31,30,31]; if(d<1 || d>days[mo-1]) return null; }
  #|  return parts;
  #| };
  #| const pieces=value.trim().split(' / '), dates=pieces.map(one);
  #| return JSON.stringify(pieces.length<=2 && dates.every(Boolean) ? {'date-parts':dates} : {literal:value});
  #|}

///|
fn reference_csl_field(
  fields : Map[String, Json],
  name : String,
  value : String,
) -> Unit {
  if !value.is_blank() {
    fields[name] = Json::string(value)
  }
}

///|
fn reference_csl_records(
  view : BriefView,
  references : Array[ReadingReference],
  scope : String,
) -> String raise {
  guard !references.is_empty() else {
    fail(
      "No references to export as CSL JSON. Clear the filters or add references.",
    )
  }
  let items : Array[Json] = []
  for r in references {
    let id = "moonfind-slot-\{r.source_slot}-record-\{r.record_number}"
    let fields : Map[String, Json] = {
      "id": Json::string(id),
      "citation-key": Json::string(id),
      "type": Json::string(reference_csl_type(r)),
    }
    reference_csl_field(fields, "title", r.title)
    reference_csl_field(fields, "container-title", r.venue)
    reference_csl_field(fields, "keyword", r.keywords)
    reference_csl_field(fields, "abstract", r.abstract_text)
    if !r.doi_match_key.is_empty() {
      reference_csl_field(fields, "DOI", reference_ris_doi(r.doi))
    }
    reference_csl_field(fields, "URL", reference_ris_url(r.url))
    for (name, names) in [("author", r.authors), ("editor", r.editors)] {
      let names = names.filter(n => !n.is_blank())
      if !names.is_empty() {
        fields[name] = names.map(n => ({ "literal": n } : Json)).to_json()
      }
    }
    if !r.issued.is_blank() {
      fields["issued"] = @json.parse(reference_csl_date_json(r.issued))
    }
    let capture = view.draft.sources[r.source_slot - 1]
    fields["custom"] = {
      "moonfind": {
        "contract_id": "moonfind.reference-csl-export.v1",
        "brief_id": view.draft.brief_id,
        "export_scope": scope,
        "reference": ToJson::to_json(r),
        "capture_origin": capture.origin,
        "captured_at": capture.captured_at,
        "boundary": "Supplied metadata and abstract only. Names are retained display strings, not reconstructed person objects. Original IDs/types/fields and claimed source digest remain here; no full-text, identity, scientific-truth or review claim. Keep the original dossier; consumers may discard custom fields.",
      },
    }
    items.push(Json::object(fields))
  }
  let output = items.to_json().stringify(indent=2) + "\n"
  guard brief_text_hex(output).length() <= 2 * 1024 * 1024 else {
    fail("CSL JSON export exceeds 1 MiB; reduce the exported references.")
  }
  output
}

///|
fn reference_csl_export(view : BriefView) -> String raise {
  reference_timeline_require(view)
  guard !view.pending else {
    fail("Wait for the current brief operation before exporting.")
  }
  let catalog = reference_catalog(view)
  guard catalog.issues.is_empty() else {
    fail(
      "Resolve unreadable bibliography selections before exporting CSL JSON.",
    )
  }
  reference_csl_records(
    view,
    reference_matches(view, catalog),
    "current-matches",
  )
}

///|
fn reference_shortlist_csl(view : BriefView) -> String raise {
  reference_csl_records(
    view,
    reference_shortlist_records(view),
    "explicit-shortlist",
  )
}

///|
extern "js" fn reference_csl_download(
  content : String,
  selected : Bool,
) -> String =
  #|(content,selected) => {
  #| let url,link;
  #| try {
  #|  url=URL.createObjectURL(new Blob([content],{type:'application/vnd.citationstyles.csl+json;charset=utf-8'}));
  #|  link=document.createElement('a'); link.href=url;
  #|  link.download=selected?'moonfind-selected-references.csl.json':'moonfind-reading-list.csl.json';
  #|  document.body.appendChild(link); link.click(); return '';
  #| } catch (_) {return 'CSL JSON download failed; references and choices remain available. Try again.';}
  #| finally {if(link) link.remove(); if(url) setTimeout(()=>URL.revokeObjectURL(url),1000);}
  #|}
