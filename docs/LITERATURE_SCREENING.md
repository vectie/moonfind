# Screen an imported literature set

Use **Screen literature for this question** in the brief studio's unified
bibliography reading list. It works with the existing BibTeX, RIS, CSL JSON,
EndNote and PubMed NBIB selections; no provider or network lookup is involved.

## A useful local journey

1. State the question in your brief. Import a bibliography and add selected
   citations using its existing intake panel.
2. Choose **Screen citation**. Inspect the supplied title, authors, date and
   abstract, choose **include**, **exclude** or **undecided**, and enter a reason.
   Empty reasons cannot be saved. Missing abstracts remain visibly metadata-only.
3. **Save decision** records your judgment. **Save and next unscreened** records
   it and opens the first still-unscreened citation within the reading-list
   text/DOI/year filters. It ignores the screening-status filter when finding the
   next citation. Undecided is an explicit judgment, distinct from unscreened.
4. Filter by screening status. Counts always cover all currently attached
   citations; the rows intersect this status with the reading-list filters.
5. Revisit a citation and change its decision or reason. Saving appends a
   revision; the old decision remains in **Complete decision history**. Saving
   unchanged text does not add a duplicate revision. Save or cancel edited text
   before choosing another citation.
6. Download **visible screening CSV** for the current rows and latest reasons,
   or **complete screening history JSON** for all history and retained captures.

## Persistence and identity

Confirmed decisions autosave under a browser-local key for the exact brief ID.
Reload restores them. Native **Save prepared brief** retains the brief and
sources, but does not contain screening decisions. Reopening that brief in the
same browser recovers its separate screening history. **New blank brief** starts
an isolated history; existing histories remain. Unconfirmed editor changes are
retained only while this page is open, including across New/Reopen in the same
session, and are excluded from exports. Save them before reloading.

Each decision retains the exact citation, source slot, original record number
and selection capture. Same-DOI records remain independent. Appending sources
preserves prior decisions. Reimporting the same selection into another slot
creates unscreened citations; it does not inherit earlier decisions.

Removing, replacing or reordering any source detaches existing decisions
conservatively. Their snapshots and reasons remain in history, but do not apply
to current citations, even if those source bytes are added again later. Screen
the current citation again. This prevents accidental transfer to a moved record.

Browser-storage failure leaves the in-memory history visible and marked **NOT
VERIFIED SAVED**. Retry saving or export before leaving. A stale tab cannot
overwrite different stored bytes. Unreadable stored data is displayed unchanged
and blocks writes until a successful retry; there is no automatic repair or
deletion. A browser-local save is not a cross-device backup.

## Export semantics and bounds

- CSV contains exactly the visible current citations, their latest decision and
  reason, source digest, original record number, availability and decision
  sequence. Empty results yield headers only. Cells are quoted; values beginning
  with spreadsheet formula prefixes, including after whitespace, receive a
  leading apostrophe. JSON retains the exact reason without that presentation
  transformation.
- JSON includes the visible-row projection plus the entire decision history,
  previous revisions, detached snapshots and full selection-capture bodies,
  regardless of filters. It can contain private rationales and metadata for
  records hidden by the current view. Review it before sharing. It is readable
  evidence, with no automatic import/restore workflow. Unrelated brief source
  bodies and whole original bibliography files are omitted; keep the dossier
  separately if you need those original bytes.
- Limits: 2,000 UTF-16 code units per reason, 200 confirmed revisions and 1 MiB
  serialized history per brief; 2 MiB CSV and 4 MiB formatted JSON exports.
  A limit refuses the new edit or export without silently evicting history.
- Screening filters do not alter the ordinary reference exports, session
  shortlist, free-form reading notes, original files or native brief contents.

These are human-authored screening judgments on supplied metadata/abstracts.
They do not establish full-text review, scientific truth, external identity,
artifact acceptance, customer demand or MoonBook knowledge approval. Origin and
digest fields remain recorded source claims.

## Verification

The R704 checks exercise the production reducers, storage and Blob downloads,
plus actual mounted Rabbita events against a controlled DOM. Save/Open replies
and imported citation selections are explicit test fixtures; no native
retention, real-browser layout, configured-provider or scientific acceptance is
claimed by these checks. A real Chromium/native-host journey was not run.
