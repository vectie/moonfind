///|
// One physical line per RIS field; embedded tags can never become records.
extern "js" fn reference_ris_line(value : String) -> String =
  #|value => value.replace(/[\u0000-\u001f\u007f-\u009f\u2028\u2029]/g,' ').trim()

///|
extern "js" fn reference_ris_doi(value : String) -> String =
  #|value => value.trim().replace(/^(?:doi:\s*|https?:\/\/(?:dx\.)?doi\.org\/)/i,'')

///|
extern "js" fn reference_ris_url(value : String) -> String =
  #|value => /^https?:\/\/[^\s\u0000-\u001f\u007f-\u009f]+$/i.test(value.trim()) ? value.trim() : ''

///|
extern "js" fn reference_ris_year(value : String) -> String =
  #|value => {const m=/^([0-9]{4})(?:$|[-/\s])/.exec(value.trim()); return m ? m[1] : '';}

///|
fn reference_ris_type(r : ReadingReference) -> String {
  let kind = csv_lower(r.reference_type)
  match (r.format, kind) {
    ("nbib", "journal article") => "JOUR"
    ("nbib", "book") => "BOOK"
    ("nbib", "book chapter") => "CHAP"
    ("endnote", "journal article") => "JOUR"
    ("endnote", "book" | "edited book") => "BOOK"
    ("endnote", "book section") => "CHAP"
    ("endnote", "conference paper") => "CPAPER"
    ("endnote", "conference proceeding") => "CONF"
    ("endnote", "thesis") => "THES"
    ("endnote", "report") => "RPRT"
    ("endnote", "web page" | "blog") => "ELEC"
    ("endnote", "newspaper article") => "NEWS"
    ("endnote", "magazine article") => "MGZN"
    ("endnote", "dataset") => "DATA"
    ("endnote", "unpublished work") => "UNPB"
    ("bibtex", "article") | ("csl", "article-journal") => "JOUR"
    ("bibtex", "book") | ("csl", "book") => "BOOK"
    ("bibtex", "inbook" | "incollection") | ("csl", "chapter") => "CHAP"
    ("bibtex", "inproceedings" | "conference") | ("csl", "paper-conference") =>
      "CPAPER"
    ("bibtex", "proceedings") => "CONF"
    ("bibtex", "phdthesis" | "mastersthesis") | ("csl", "thesis") => "THES"
    ("bibtex", "techreport") | ("csl", "report") => "RPRT"
    ("csl", "webpage" | "post-weblog") => "ELEC"
    ("ris", _) =>
      match r.reference_type {
        "JOUR"
        | "BOOK"
        | "CHAP"
        | "CPAPER"
        | "CONF"
        | "THES"
        | "RPRT"
        | "ELEC"
        | "GEN"
        | "NEWS"
        | "MGZN"
        | "DATA"
        | "UNPB" => r.reference_type
        _ => "GEN"
      }
    _ => "GEN"
  }
}

///|
fn reference_ris_field(
  lines : Array[String],
  tag : String,
  value : String,
) -> Unit {
  let value = reference_ris_line(value)
  if !value.is_empty() {
    lines.push(tag + "  - " + value)
  }
}

///|
fn reference_ris_export(view : BriefView) -> String raise {
  guard !view.pending else {
    fail("Wait for the current brief operation before exporting.")
  }
  let catalog = reference_catalog(view)
  guard catalog.issues.is_empty() else {
    fail("Resolve unreadable bibliography selections before exporting RIS.")
  }
  let matches = reference_matches(view, catalog)
  reference_timeline_require(view)
  reference_ris_records(view, matches)
}

///|
fn reference_ris_records(
  view : BriefView,
  matches : Array[ReadingReference],
) -> String raise {
  guard !matches.is_empty() else {
    fail(
      "No matching references to export as RIS. Clear the filters or add references.",
    )
  }
  let lines : Array[String] = []
  for r in matches {
    lines.push("TY  - " + reference_ris_type(r))
    reference_ris_field(
      lines,
      "ID",
      "moonfind-slot-\{r.source_slot}-record-\{r.record_number}",
    )
    reference_ris_field(lines, "TI", r.title)
    for author in r.authors {
      reference_ris_field(lines, "AU", author)
    }
    for editor in r.editors {
      reference_ris_field(lines, "ED", editor)
    }
    reference_ris_field(lines, "PY", reference_ris_year(r.issued))
    reference_ris_field(lines, "T2", r.venue)
    reference_ris_field(lines, "KW", r.keywords)
    if !r.doi_match_key.is_empty() {
      reference_ris_field(lines, "DO", reference_ris_doi(r.doi))
    }
    reference_ris_field(lines, "UR", reference_ris_url(r.url))
    reference_ris_field(lines, "AB", r.abstract_text)
    let source = view.draft.sources[r.source_slot - 1]
    // JSON escaping preserves original multiline/control data inside a single
    // safe RIS note. This is provenance as supplied, not independently verified.
    let note : Json = {
      "contract_id": "moonfind.reference-ris-note.v1",
      "brief_id": view.draft.brief_id,
      "reference": ToJson::to_json(r),
      "capture_origin": source.origin,
      "captured_at": source.captured_at,
      "boundary": "Supplied metadata and abstract only; source digest not reverified. No full-text, publication-identity, scientific-truth or review claim. Citation fields may be folded; this note retains originals.",
    }
    // U+2028/U+2029 are legal JSON but some RIS consumers split them as lines.
    lines.push("N1  - " + reference_ris_note(note.stringify()))
    lines.push("ER  -")
    lines.push("")
  }
  let output = lines.join("\r\n") + "\r\n"
  guard brief_text_hex(output).length() <= 2 * 1024 * 1024 else {
    fail("RIS export exceeds 1 MiB; reduce the number of exported references.")
  }
  output
}

///|
extern "js" fn reference_ris_note(value : String) -> String =
  #|value => value.replace(/[\u007f-\u009f\u2028\u2029]/g,c=>'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0'))

///|
extern "js" fn reference_ris_download(content : String) -> String =
  #|content => {
  #| let url,link;
  #| try {
  #|  url=URL.createObjectURL(new Blob([content],{type:'application/x-research-info-systems;charset=utf-8'}));
  #|  link=document.createElement('a'); link.href=url; link.download='moonfind-reading-list.ris';
  #|  document.body.appendChild(link); link.click(); return '';
  #| } catch (_) {return 'RIS download failed; the current reference list remains available. Try again.';}
  #| finally {if(link) link.remove(); if(url) setTimeout(()=>URL.revokeObjectURL(url),1000);}
  #|}
