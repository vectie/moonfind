# Curate references across searches

In the brief studio, retain BibTeX, RIS and/or CSL JSON selections with the
existing intake controls. In **Unified bibliography reading list**, search for
an author, title, ID or topic, inspect a DOI group, and click **Add to shortlist**
on individual cards. Change the query and add other references. The shortlist
shows every choice, including cards hidden by current filters.

Use **Remove this choice** in the shortlist, or **Remove from shortlist** on a
matching card. **Clear reading-list filters** keeps the choices. **Clear
shortlist** keeps the filters and source captures. Removing and re-adding a
choice places it at the end. Same-DOI candidates, missing DOIs, same citation
keys, and duplicate source captures remain individually selectable.

## Two export scopes

- **Download selected references JSON/RIS** exports exactly the chosen records,
  in selection order, regardless of filters. Empty shortlists cannot download.
  Filenames are `moonfind-selected-references.json` and
  `moonfind-selected-references.ris`.
- Existing **Download current reading list JSON** and **Download current
  bibliography RIS** still export only current matches. They never substitute
  the shortlist. Existing JSON and RIS contracts remain available.

Selected JSON uses `moonfind.reference-shortlist.v1`, explicit scope, brief ID,
record count, complete projected references and contributing capture origins,
timestamps and kinds. It excludes original source bodies. RIS uses the existing
[portable mapping](REFERENCE_RIS_EXPORT.md), with each exact projected record
and its origin/timestamp in a JSON note. Source slot and original record number
are provenance within this brief, not global publication identifiers. Both
selected outputs have a 1 MiB UTF-8 byte cap. Oversize or failed downloads retain
the choices. No download proves scientific validity or completes a research job.

## Temporary state and changing sources

The shortlist is session-only UI state. It is not part of the saved brief or
browser draft. Reload, successful reopen (even of the same brief), and **New
blank brief** clear it. A successful save, failed reopen, failed save, brief text
edits and filter changes keep it. Download before leaving or reopening.

Appending sources through the existing intake reducers preserves choices.
Removing, replacing or reordering existing sources conservatively invalidates
all previous choices. Their metadata and capture provenance remain visible as
unavailable, and selected exports are blocked until those choices are removed
and the desired current records are selected again. This includes moving an
identical source capture into another slot: it cannot inherit a prior choice.
The policy intentionally prefers explicit reselection over guessing continuity.

Identity binds the capture's complete stored value, original record projection
and source-list generation. A DOI, citation key, filename or slot alone cannot
retarget a choice. Unreadable bibliography captures block selected exports.
Pending brief operations disable shortlist changes/downloads; **New blank
brief** retains the established ability to abandon a pending operation.

## Qualification boundary

Compiled tests exercise production BibTeX/CSL/RIS selection reducers, shortlist
and brief reducers, actual Rabbita rendering, separate exports, source mutation,
stale actions, pending states, New/reopen/save, download failures and retry.
The download fixture uses real Node Blobs and verifies their ArrayBuffer UTF-8
bytes, MIME types and filenames, controlling only the document/URL boundary.
Synthetic host-shaped metadata does not qualify native parsing or persistence.
No graphical browser, external reference manager, provider/gateway, full-text
review, accepted scientific claim or cross-product integration is implied.

See [Browser-local reference reading notes](BROWSER_READING_NOTES.md) for independent persistent handwritten notes. The shortlist remains session-only.

## CSL JSON citation-library download

**Download selected references CSL JSON** uses this same shortlist and selection
order, including hidden choices. See [CSL JSON export](REFERENCE_CSL_EXPORT.md)
for generated citation IDs, literal names, supported fields and limitations.
