# Build a reading list across reference-manager formats

For a literature window, use [publication-year exploration](REFERENCE_PUBLICATION_YEARS.md)
to combine inclusive year bounds, unclassified-date inspection and chronological
ordering with the search below. Current-match downloads follow that view.

To retain arbitrary individual choices across searches and DOI groups, use the
[session-only shortlist](REFERENCE_SHORTLIST.md) and its separate selected
JSON/RIS downloads. Current-match downloads below keep their existing scope.

For reference-manager exchange, the current matching list can also be exported
as [RIS](REFERENCE_RIS_EXPORT.md), with original metadata retained in notes, or
as [CSL JSON](REFERENCE_CSL_EXPORT.md), with typed provenance in custom metadata.

Use the local brief studio at `/apps/moonfind/briefs` to explore references from
several bibliographies together. This is useful when one collaborator supplied a
BibTeX export, another supplied RIS, and a Zotero collection arrived as CSL JSON.
No model, citation service, gateway or remote fetching is needed for the new
explorer. The existing import/save actions still use the local MoonFind host.

## Import, compare and export

1. Import a bibliography using the existing BibTeX, RIS or CSL JSON section.
   Select references and click **Add selected references to brief**. Repeat for
   other formats. Each bibliography still uses two of the eight source slots:
   its original file and its selected-reference JSON capture.
2. In **Unified bibliography reading list**, see all retained selection cards in
   one place. Unsaved imports still in an intake panel are not included until
   added to the brief. Reopening an existing saved brief also fills the list.
3. Search by source filename, format, original item ID, citation key, type, title,
   author, editor, issued date, venue, keyword, DOI, URL, abstract or availability.
   Search is a trimmed, case-insensitive literal substring. It neither interprets
   regular expressions nor normalizes Unicode.
4. Turn on **Same-DOI candidates only** to review potentially overlapping records.
   Click **Inspect N same-DOI candidates** to open that exact DOI group; this
   clears the previous text search and publication-year filters/order. Further searches narrow that group. The group
   is visible above the cards. **Clear reading-list filters** returns to all
   references in original source order. Toggling the candidates-only button clears an exact-group filter, keeping any publication-year window.
5. Inspect each card's source slot, source filename, format, original record,
   citation key/ID and abstract/provenance. Two records stay distinct even when
   their citation keys or DOI text match. Contradictory titles and abstracts are
   retained for human review. Nothing is merged, deleted or promoted to evidence.
6. **Download current reading list JSON** exports exactly the currently matching
   cards and descriptors for their contributing selection captures. Empty
   matches produce an explicit zero-record list. This provides a portable table
   for another local tool or collaborator without copying full source bodies.
7. Save the brief and retain its dossier when you need the original bytes and
   host manifests. Downloading the reading list does not save the brief. An
   unchanged prepared revision contributes its revision ID; a draft exports null.

## DOI candidates, not publication identity

Candidate matching trims outside whitespace and removes one of these prefixes,
case-insensitively: `doi:`, `http://doi.org/`, `https://doi.org/`,
`http://dx.doi.org/`, or `https://dx.doi.org/`. After removal it requires a token
starting `10.`, 4–9 digits, `/`, then a nonempty suffix with no whitespace,
control characters, angle brackets or double quotes. ASCII letters are folded to
lowercase. This is a conservative textual heuristic, not DOI validation.

Blank or malformed DOI text is retained on the card but has no candidate group.
URL/query punctuation is not stripped, percent encodings are not decoded and
Unicode is not normalized. There is no title-based matching. A longer DOI such
as `10.1234/shared.extra` never enters the exact `10.1234/shared` group.
Candidates include repeated DOI records within one selection and across formats.

Candidate counts describe the complete current catalog. A search can hide peers:
for example, one RIS card may remain visible while its label still reports four
same-DOI candidates. The exported `doi_candidate_counts` says `catalog_matches`
and lists only the exported cards, so it never silently adds hidden peers.

## Provenance and limits

The export contract is `moonfind.reference-reading-list.v1`. It preserves the
selection capture's source slot, original filename/digest, format and original
record number on every reference. Original CSL ID text and type are retained,
including numeric IDs larger than JavaScript's safe integer range. Missing fields
stay empty; absent abstracts are `metadata-only`. RIS fields not retained by the
existing importer are not reconstructed. Source slots refer to the current brief;
removing a capture updates the projection and slots immediately.

Digests are copied from retained selection metadata, not reverified by this UI.
The JSON is a reading artifact, not a restorable dossier or a CSL/citation-style
export. It contains matching metadata, supplied abstracts and contributing
capture origins; review those before sharing. No original capture bodies,
unmatched reference cards or unrelated source descriptors are exported. This is
not a claim that exported metadata is free of private information.

Recognized selection filenames are `bibtex-selection.json`, `ris-selection.json`
and `csl-selection.json`, with their corresponding v1 contracts. A malformed or
unsupported selection is shown as a source-slot issue and blocks export rather
than quietly producing an incomplete reading list. Generic JSON sources remain
ordinary captures and are not guessed to be bibliographies. Each recognized
capture retains the existing 32 KiB input bound. The eight-source/128 KiB brief
limits remain unchanged. There is no additional top-N truncation.

Filters are temporary UI state and survive source edits/reopening until cleared;
the contents are recomputed from the current brief every time. **New blank brief**
clears filters and sources. Pending host operations block reading-list actions.
Links and markup are escaped text and are never opened, fetched or executed.
No provider execution, full-text reading, scientific truth, research completion
or approval is implied.

## Verification

`ui/rabbita-moonfind/main/reference_list_wbtest.mbt` exercises production selection
reducers for all three formats, merged projection, search, same-DOI drill-down,
filtered export, source removal/replacement, prepared-revision projection, New,
stale replies, pending actions, malformed captures, escaped HTML and actual Blob
contents with a mocked DOM download boundary. Tests use synthetic host-shaped
selection captures. They do not requalify unchanged native import parsers, the
browser file picker, native persistence, graphical rendering or providers.
