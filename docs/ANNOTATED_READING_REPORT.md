# Find reading notes and export an annotated report

Use the brief studio's **Browser-local reading notes** notebook to turn your
retained observations into an openable reading report. This works with notes on
BibTeX, CSL JSON and RIS references. No provider, gateway, reference-manager
account or native host change is needed for this new search/export step.

## Walk through the workflow

1. Import a bibliography, for example `fixtures/local-bibliography.csl.json`,
   using the existing intake controls. Add selected references to the brief.
2. In the unified list, use **New reading note for this snapshot** on two
   references. Select each retained note and write an observation, question or
   contradiction. For example, include `replication` in one note.
3. In **Find notes and make an annotated reading report**, search `REPLICATION`.
   The notebook cards and report preview now show only matching retained notes.
   Search checks handwritten text, note ID, reference metadata, supplied
   abstracts, source filenames, capture origins and capture timestamps. It is a
   trimmed, case-insensitive literal substring using locale-independent lowercase
   and Greek final-sigma folding, without Unicode normalization.
4. Choose **All retained notes**, **Attached to this brief**, or **Detached
   retained snapshots**. Search and snapshot scope are combined. Removing or
   replacing sources does not erase older notes: detached notes remain
   searchable and export their original reference/capture provenance.
5. Open **Preview annotated reading report** and inspect the exact Markdown.
   **Download annotated reading report Markdown** writes
   `moonfind-annotated-reading-report.md`. Open it in a text/Markdown viewer.
6. **Clear note filters** returns to all retained notes. Bibliography searches,
   DOI groups and the temporary shortlist have separate scopes and remain
   unchanged. Download the JSON backup separately if you need restoration.

## What the file contains

- Brief ID, notebook revision, query, scope, matched/total counts and browser
  save status. No matches produces an explicit empty report, not a stale file.
- Every matching note, in notebook order, with its own note ID. Same-DOI records
  and repeated notes remain separate; no deduplication or synthesis is inferred.
- Exact retained title, authors/editors, date, venue, reference type, citation
  key, original item ID/kind, keywords, DOI, URL and availability. Large numeric
  CSL IDs remain text without rounding.
- Original source file, format, slot, record number and supplied digest;
  selection capture name, kind, origin and capture timestamp. Detached status is
  explicit. Digests are copied from the retained snapshot, not reverified.
- Supplied abstract and your handwritten note text, including unsaved edits.
  Missing abstracts and empty notes have explicit labels. CRLF, Unicode and
  multiline text are preserved inside literal fenced blocks. A separator newline
  is added after text without a final newline so the closing fence is separate.

The report intentionally omits full source bodies and selection-capture bytes.
It does contain the chosen private notes, metadata, abstracts and source origins;
review those before sharing. Every supplied field is in a code fence longer than
any backtick run in that field's block. Source Markdown/HTML and URLs stay literal
in conforming Markdown viewers. No source link is fetched or opened.

## Lifetime, editing and limits

Filters are temporary UI state. They are not written to localStorage, the native
brief or the JSON backup. Reload and a new blank brief start with all notes and
an empty query. Existing in-page notebook switching keeps its session filters.
Changing a filter never edits or deletes notes. Editing a matching note so it no
longer matches can hide its card; clear the filters to find it again.

The report is generated from current in-memory notes at preview/download time,
including edits whose browser save failed. Their save status remains explicitly
**NOT VERIFIED SAVED**. A successful download request does not prove a disk file
was saved or make browser storage succeed. Check the actual file. A failed
create/click retains notes, filters and save status for retry.

The existing notebook bounds remain 100 notes, 10,000 UTF-16 code units per note
and 1 MiB serialized UTF-8. The report also has a 1 MiB UTF-8 output bound; literal
fences and labels can expand it, so narrow the query or scope if necessary. It
never truncates. Pending operations, unreadable notebooks and stale note actions
cannot download or modify the search. The existing note attachment rules apply.

This is a human-readable reading artifact, not a restorable notebook, native
brief save, formatted citation bibliography, scientific verification, accepted
company decision or completed research answer. JSON/RIS bibliography exports and
the complete JSON notebook backup keep their existing scopes and contracts.

## Focused verification

Nine `report *` compiled-JS tests exercise production note reducers and the root
message handler, actual Rabbita rendering, current/retained scopes, filter
independence, source changes, unsaved edits, wrong/stale/pending states, literal
fences, 100-note completeness and the output cap. The real Node Blob is read as
an ArrayBuffer and checked for exact UTF-8 bytes, filename and MIME type with
only the document/URL download boundary controlled. An independent Node verifier
parses emitted Markdown fences and checks every expected note, provenance and
excluded record against the retained fixture projection.

Input reference cards use synthetic host-shaped selection replies through the
existing production intake reducers. This does not requalify native bibliography
parsing, native persistence, graphical browser usability or actual browser file
saving. No provider-backed outcome is claimed. Cumulative qualification remains
R50; this workflow has separate focused acceptance.
