# Browser-local reference reading notes

In the unified bibliography list, choose **New reading note for this snapshot**
on a BibTeX, CSL JSON or RIS record. Select the retained note in the notebook and
type your own observation, question or reading summary. Edits autosave locally;
read the save status. The notebook keeps the exact reference projection and
selection capture, including its original bytes as hexadecimal, origin and
capture time. It does not interpret notes or mark papers scientifically reviewed.

Each note gets a separate identity. Same DOI, citation key, numeric item ID,
record number or identical repeated capture never merges notes. Choosing a card
again explicitly creates another note; use **Edit retained note** to continue
an existing one. Filters and the temporary shortlist do not change notes.

## Retention and source changes

- Browser storage is namespaced by brief ID under `moonfind.reading-notes.v1:`.
  Reload restores the last browser brief and that brief's notebook. Successful
  reopening of a saved native brief restores this browser's notebook for its ID.
- **Native brief Save does not save notes.** Notes are neither part of the native
  brief schema nor MoonBook memory. Moving devices, clearing browser data or
  using another origin does not transfer them automatically. Use the portable
  backup and restore workflow below.
- New blank brief gets a new ID and empty notebook. Earlier stored notebooks
  remain untouched. Save, failed reopen and edits to brief text retain notes.
  Switching back in the same page also retains unsaved notes after a quota error.
- Appending sources keeps existing snapshots attached. Removing, replacing or
  observably reordering sources detaches earlier notes conservatively. The note
  and its original capture stay visible and editable. They never retarget by DOI
  or by the new contents of a slot. Re-adding an old source does not reattach an
  already detached note. Create a fresh note explicitly on the current record.
- Source-list continuity is stored with the notebook. Reload/reopen compares it
  with the current draft before showing attachment status. An indistinguishable
  exchange of byte-identical captures has no observable source-list change;
  nevertheless each note retains its own original snapshot and identity.

The full *selection capture* is retained, not a newly fetched paper or an implied
full-text copy. Supplied digests, titles, authors and abstracts remain claims.

## Errors and limits

Unreadable, wrong-brief, unsupported, oversized or internally mismatched stored
notebooks are preserved verbatim. Saving and editing are paused, with retained
raw bytes visible for manual recovery. **Retry reading saved notes** retries the
read without replacing data. A quota or write/verification failure leaves edits
in memory, marks them **NOT VERIFIED SAVED**, and offers retry Save. Copy them
before leaving. Compare-before-write refuses an observed competing tab change;
this is a synchronous best-effort guard, not a transactional multi-tab database.

There are at most 100 notes, 10,000 UTF-16 code units per note and 1 MiB UTF-8 per
notebook. A note edit/create crossing the notebook limit leaves the prior state
unchanged. Portable JSON backup/import is available below. No note deletion or native
storage migration is included. Existing current-match and selected JSON/RIS exports keep their
original exact scopes and exclude handwritten notes. The R222 shortlist remains
ephemeral; this feature does not silently make it durable.

## Qualification boundary

The compiled production reducers and actual localStorage calls are exercised in
separate Node 24.19 processes with experimental file-backed Web Storage. This
proves the local serialized writer/reader and source-change behavior under that
runtime, not graphical-browser usability, browser-policy behavior, native host
persistence, live provider research, or a scientific review. The new core tests
are unconditional; a dedicated restart case is explicitly activated for three
separate process runs. Existing environment-dependent native-fixture tests may
return early without their host fixtures.

## Portable backup and restore

Open **Portable reading-note backup and import** in the notebook. **Download
reading notes JSON backup** writes `moonfind-reading-notes.json` with the current
notebook, including exact note IDs, all retained reference/capture snapshots,
detached notes and unsaved in-memory edits. The versioned format is
`moonfind.reading-notes.v1`; compact UTF-8 JSON has the same 1 MiB limit as stored
notebooks. A requested download is not proof that the browser saved a file:
check the actual file before clearing browser data. This file contains private
notes and complete retained captures; review its contents before sharing it.

To restore on another browser/device:

1. Open the same saved brief there. Its brief ID must match the backup. The
   backup does not contain the brief itself, and is not a native brief import.
2. Choose **Choose reading-note backup JSON file** and select one UTF-8 `.json`
   file up to 1 MiB, or paste the JSON in the backup field.
3. Choose **Preview reading-note import**. Read the added/skipped/detached
   counts, exact note text and retained snapshots. Nothing is written yet.
4. Choose **Confirm reading-note merge** to merge, or **Cancel reading-note
   import** to discard the pending input and preview without changing notes.
5. Check the normal save status. On quota, unreadable storage or an observed
   competing-tab write, never assume success. Merged notes may remain in memory
   with **NOT VERIFIED SAVED**; keep the page open, download a backup and retry
   Save when appropriate.

Existing note IDs with identical text, reference and capture are skipped. The
existing note's attachment status stays unchanged. Repeated import is a no-op;
existing text is never overwritten. If any matching ID has different text or a
different snapshot, the entire import is refused before any notes are changed.
Keep both backups and resolve the differing content outside the importer; this
version has no conflict-resolution editor. Distinct note IDs remain distinct,
even for identical captures or DOI peers.

New imported notes attach only if the backup's full source list exactly matches
the current brief and the note was attached in the backup. Otherwise they remain
editable detached snapshots. Import never adds sources to the brief, follows
links, fetches evidence, retargets by DOI or reattaches an existing detached note.
A changed notebook invalidates its preview; a changed backup input invalidates
confirmation. Late file callbacks cannot replace newer input or another brief.
Malformed, unsupported, wrong-brief, internally mismatched or over-limit imports
are refused. Corrupt stored notebooks must first be recovered through the
existing read-retry/manual recovery path; import does not overwrite them.

Native brief Save, shortlist lifetime and selected/current JSON/RIS export scopes
are unchanged. Backup/restore is a local annotation transfer, not publication
verification, full-text rights, scientific review or MoonBook approval.

## Search and readable reports

[Find notes and export an annotated reading report](ANNOTATED_READING_REPORT.md)
combines handwritten-text/metadata search with attached or detached snapshot
scope. The notebook shows the matching cards and previews a Markdown report of
those notes, abstracts and provenance without full source/capture bytes. Its
scope is separate from bibliography filters, the shortlist and the JSON backup.
