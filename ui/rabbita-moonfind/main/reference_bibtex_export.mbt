///|
// Input is retained display text, never trusted TeX. In particular, escaped
// braces still affect classic BibTeX's brace counter; use balanced text macros.
extern "js" fn reference_bibtex_literal(value : String) -> String =
  #|value => {
  #| const escapes={'\\':'\\textbackslash{}','{':'\\textbraceleft{}','}':'\\textbraceright{}','%':'\\%','$':'\\$','#':'\\#','&':'\\&','_':'\\_','^':'\\textasciicircum{}','~':'\\textasciitilde{}','<':'\\textless{}','>':'\\textgreater{}','|':'\\textbar{}'};
  #| return Array.from(value.replace(/[\u0000-\u001f\u007f-\u009f\u2028\u2029]/g,' ')).map(c=>escapes[c]||c).join('');
  #|}

///|
// Link fields are verbatim in some readers. Omit anything requiring TeX escapes
// rather than emitting an executable token or a misleading rewritten link.
extern "js" fn reference_bibtex_link(value : String) -> String =
  #|value => /^[\x21-\x7e]+$/.test(value) && !/[\\{}%$#&_^~]/.test(value) ? value : ''

///|
fn reference_bibtex_type(r : ReadingReference) -> String {
  let kind = csv_lower(r.reference_type)
  match (r.format, kind) {
    ("bibtex", "article")
    | ("ris", "jour" | "mgzn")
    | ("csl", "article-journal" | "article-magazine") => "article"
    ("bibtex", "book") | ("ris", "book") | ("csl", "book") => "book"
    ("bibtex", "incollection") | ("ris", "chap") | ("csl", "chapter") =>
      "incollection"
    ("bibtex", "inproceedings" | "conference")
    | ("ris", "cpaper")
    | ("csl", "paper-conference") => "inproceedings"
    ("bibtex", "proceedings") | ("ris", "conf") => "proceedings"
    ("bibtex", "techreport") | ("ris", "rprt") | ("csl", "report") =>
      "techreport"
    ("bibtex", "unpublished") | ("ris", "unpb") | ("csl", "manuscript") =>
      "unpublished"
    ("bibtex", "booklet" | "manual" | "inbook" | "phdthesis" | "mastersthesis") =>
      kind
    // A generic thesis does not establish its degree. Unknown types stay misc.
    _ => "misc"
  }
}

///|
fn reference_bibtex_field(
  lines : Array[String],
  name : String,
  value : String,
) -> Unit {
  if !value.is_blank() {
    lines.push("  " + name + " = {{" + reference_bibtex_literal(value) + "}},")
  }
}

///|
fn reference_bibtex_records(
  view : BriefView,
  references : Array[ReadingReference],
  scope : String,
) -> String raise {
  guard !references.is_empty() else {
    fail(
      "No references to export as BibTeX. Clear the filters or add references.",
    )
  }
  let lines : Array[String] = []
  for r in references {
    let key = "moonfind-slot-\{r.source_slot}-record-\{r.record_number}"
    let kind = reference_bibtex_type(r)
    lines.push("@" + kind + "{" + key + ",")
    reference_bibtex_field(lines, "title", r.title)
    for (name, names) in [("author", r.authors), ("editor", r.editors)] {
      let names = names.filter(n => !n.is_blank())
      if !names.is_empty() {
        lines.push(
          "  " +
          name +
          " = {" +
          names.map(n => "{" + reference_bibtex_literal(n) + "}").join(" and ") +
          "},",
        )
      }
    }
    match reference_publication_year(r.issued) {
      Some(year) => lines.push("  year = {\{year}},")
      None => ()
    }
    if kind == "article" {
      reference_bibtex_field(lines, "journal", r.venue)
    } else if kind is ("incollection" | "inproceedings") {
      reference_bibtex_field(lines, "booktitle", r.venue)
    }
    reference_bibtex_field(lines, "keywords", r.keywords)
    reference_bibtex_field(lines, "abstract", r.abstract_text)
    let doi = if r.doi_match_key.is_empty() {
      ""
    } else {
      reference_bibtex_link(reference_ris_doi(r.doi))
    }
    let url = reference_bibtex_link(reference_ris_url(r.url))
    for (name, value) in [("doi", doi), ("url", url)] {
      if !value.is_empty() {
        lines.push("  " + name + " = {" + value + "},")
      }
    }
    let capture = view.draft.sources[r.source_slot - 1]
    let provenance : Json = {
      "contract_id": "moonfind.reference-bibtex-export.v1",
      "citation_key": key,
      "brief_id": view.draft.brief_id,
      "export_scope": scope,
      "reference": ToJson::to_json(r),
      "capture": {
        "name": capture.name,
        "origin": capture.origin,
        "captured_at": capture.captured_at,
        "kind": capture.kind,
      },
      "boundary": "Supplied metadata and abstract only; source digest not reverified. Literal display names, no inferred person parts. Original metadata is retained here as UTF-8 JSON hex; consumers may discard this field. No original file bodies, full-text review or verified publication claim.",
    }
    lines.push(
      "  moonfind_provenance_hex = {" +
      brief_text_hex(provenance.stringify()) +
      "},",
    )
    lines.push("}")
    lines.push("")
  }
  let output = lines.join("\n")
  guard brief_text_hex(output).length() <= 2 * 1024 * 1024 else {
    fail("BibTeX export exceeds 1 MiB; reduce the exported references.")
  }
  output
}

///|
fn reference_bibtex_export(view : BriefView) -> String raise {
  reference_timeline_require(view)
  guard !view.pending else {
    fail("Wait for the current brief operation before exporting.")
  }
  let catalog = reference_catalog(view)
  guard catalog.issues.is_empty() else {
    fail("Resolve unreadable bibliography selections before exporting BibTeX.")
  }
  reference_bibtex_records(
    view,
    reference_matches(view, catalog),
    "current-matches",
  )
}

///|
fn reference_shortlist_bibtex(view : BriefView) -> String raise {
  reference_bibtex_records(
    view,
    reference_shortlist_records(view),
    "explicit-shortlist",
  )
}

///|
extern "js" fn reference_bibtex_download(
  content : String,
  selected : Bool,
) -> String =
  #|(content,selected) => {
  #| let url,link;
  #| try {
  #|  url=URL.createObjectURL(new Blob([content],{type:'application/x-bibtex;charset=utf-8'}));
  #|  link=document.createElement('a'); link.href=url;
  #|  link.download=selected?'moonfind-selected-references.bib':'moonfind-reading-list.bib';
  #|  document.body.appendChild(link); link.click(); return '';
  #| } catch (_) {return 'BibTeX download failed; references and choices remain available. Try again.';}
  #| finally {if(link) link.remove(); if(url) setTimeout(()=>URL.revokeObjectURL(url),1000);}
  #|}
