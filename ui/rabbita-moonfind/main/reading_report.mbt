///|
// Locale-independent search casing, with sigma folded across substring boundaries.
// No Unicode normalization or changes to retained text and reference identity.
extern "js" fn reading_report_search_key(value : String) -> String =
  #|value => value.toLowerCase().replace(/\u03c2/g, '\u03c3')

///|
// Search the retained snapshot, never a replacement source or DOI peer.
fn reading_report_matches(view : BriefView) -> Array[ReadingNote] {
  let query = reading_report_search_key(
    view.reading_notes.report_query.trim().to_owned(),
  )
  let scope = view.reading_notes.report_scope
  view.reading_notes.notebook.notes.filter(note => {
    let current = reading_note_current(view, note)
    let r = note.reference
    (
      scope == "all" ||
      (scope == "attached" && current) ||
      (scope == "detached" && !current)
    ) &&
    reading_report_search_key(
      [
        note.id,
        note.text,
        r.title,
        r.authors.join("; "),
        r.editors.join("; "),
        r.source_name,
        r.format,
        r.item_id,
        r.citation_key,
        r.reference_type,
        r.issued,
        r.venue,
        r.keywords,
        r.doi,
        r.url,
        r.abstract_text,
        r.availability,
        note.capture.origin,
        note.capture.captured_at,
      ].join("\n"),
    ).contains(query)
  })
}

///|
// A fence longer than EVERY backtick run keeps all source text literal, including
// hostile Markdown/HTML, CRLF, empty lines, and code fences in handwritten notes.
fn reading_report_literal(text : String) -> String {
  let mut longest = 0
  let mut run = 0
  for char in text {
    if char == '`' {
      run += 1
      if run > longest {
        longest = run
      }
    } else {
      run = 0
    }
  }
  let fence = "`".repeat(if longest < 3 { 3 } else { longest + 1 })
  fence +
  "\n" +
  text +
  (if text.has_suffix("\n") { "" } else { "\n" }) +
  fence +
  "\n\n"
}

///|
fn reading_report_markdown(view : BriefView) -> String raise {
  let state = view.reading_notes
  guard !view.pending &&
    !state.blocked &&
    state.notebook.brief_id == view.draft.brief_id &&
    state.key == "moonfind.reading-notes.v1:" + view.draft.brief_id else {
    fail("Wait for a readable notebook for the current brief before exporting.")
  }
  guard state.report_scope is ("all" | "attached" | "detached") else {
    fail("Choose a supported reading-note scope.")
  }
  // Reuse the notebook's validated snapshot contract; do not export corrupt state.
  reading_notes_backup(state) |> ignore
  let notes = reading_report_matches(view)
  let out = StringBuilder()
  out.write_string("# Annotated reading report\n\n")
  out.write_string(
    "Handwritten research notes and retained reference snapshots. Supplied abstracts and digests are recorded claims, not a full-text review or scientific verification.\n\n",
  )
  out.write_string("## Report scope\n\n")
  out.write_string(
    reading_report_literal(
      [
        "Brief ID: " + view.draft.brief_id,
        "Notebook revision: \{state.notebook.revision}",
        "Snapshot scope: " + state.report_scope,
        "Search (trimmed, case-insensitive literal substring): " +
        state.report_query.trim().to_owned(),
        "Matching notes: \{notes.length()} of \{state.notebook.notes.length()}",
        "Browser save status: " +
        (if state.saved {
          "verified saved"
        } else {
          "NOT VERIFIED SAVED; current in-memory edits included"
        }),
      ].join("\n"),
    ),
  )
  out.write_string(
    "Each matching note is separate, in notebook order. Bibliography filters and the temporary shortlist do not change this report. Detached snapshots remain historical notes and are never retargeted.\n\n",
  )
  if notes.is_empty() {
    out.write_string("No reading notes match this scope and search.\n\n")
  }
  for index, note in notes {
    let r = note.reference
    out.write_string("## Note \{index + 1}\n\n")
    out.write_string("### Retained reference\n\n")
    out.write_string(
      reading_report_literal(
        [
          "Note ID: " + note.id,
          "Snapshot status: " +
          (if reading_note_current(view, note) {
            "attached to the current brief"
          } else {
            "detached; retained snapshot only"
          }),
          "Title: " + r.title,
          "Authors: " + r.authors.join("; "),
          "Editors: " + r.editors.join("; "),
          "Issued: " + r.issued,
          "Venue: " + r.venue,
          "Type: " + r.reference_type,
          "Citation key: " + r.citation_key,
          "Original item ID (" + r.item_id_kind + "): " + r.item_id,
          "Keywords: " + r.keywords,
          "DOI as recorded: " + r.doi,
          "URL as recorded: " + r.url,
          "Availability: " + r.availability,
          "Source file: " + r.source_name,
          "Source format: " + r.format,
          "Retained source slot: \{r.source_slot}",
          "Original record: \{r.record_number}",
          "Source digest as recorded (not reverified): " + r.source_digest,
          "Selection capture: " + note.capture.name,
          "Capture origin: " + note.capture.origin,
          "Captured at: " + note.capture.captured_at,
          "Capture kind: " + note.capture.kind,
        ].join("\n"),
      ),
    )
    out.write_string("### Supplied abstract\n\n")
    if r.abstract_text.is_empty() {
      out.write_string("No abstract supplied.\n\n")
    } else {
      out.write_string(reading_report_literal(r.abstract_text))
    }
    out.write_string("### Your reading note\n\n")
    if note.text.is_empty() {
      out.write_string("No handwritten text yet.\n\n")
    } else {
      out.write_string(reading_report_literal(note.text))
    }
  }
  out.write_string("## About this file\n\n")
  out.write_string(
    "This reading report omits original source bodies and full selection-capture bytes. It is not a restorable notebook backup, native brief save, citation-style bibliography, accepted decision, or completed research answer. All supplied text is literal; URLs are not fetched or made into links. Review private notes, abstracts and source origins before sharing. Use the JSON backup to preserve the complete notebook.\n",
  )
  let content = out.to_string()
  guard brief_text_hex(content).length() <= 2 * 1024 * 1024 else {
    fail(
      "Annotated report exceeds 1 MiB. Narrow the note search or snapshot scope.",
    )
  }
  content
}

///|
extern "js" fn reading_report_download(content : String) -> String =
  #|content => {
  #| let url,link;
  #| try {
  #|  url=URL.createObjectURL(new Blob([content],{type:'text/markdown;charset=utf-8'}));
  #|  link=document.createElement('a'); link.href=url; link.download='moonfind-annotated-reading-report.md';
  #|  document.body.appendChild(link); link.click(); return '';
  #| } catch (_) {return 'Annotated report download failed; your notes and filters remain available. Try again.';}
  #| finally {if(link) link.remove(); if(url) setTimeout(()=>URL.revokeObjectURL(url),1000);}
  #|}
