# Export the current bibliography to RIS

In the local brief studio, add selected references from the existing BibTeX,
RIS and/or CSL JSON importers, or reopen a saved brief. The **Unified bibliography
reading list** panel combines the retained selections. Search it, optionally
choose same-DOI candidates or an exact DOI group, then choose **Download current
bibliography RIS**. Import `moonfind-reading-list.ris` into a reference manager
that accepts UTF-8 RIS and inspect its imported fields before using citations.

The export contains exactly the matching cards in the selected reading-list
order. [Publication-year scope and ordering](REFERENCE_PUBLICATION_YEARS.md)
apply. Same-DOI candidates remain separate records. Clearing filters
restores the full list. A zero-match view gives a repairable message instead of
an empty RIS file. Pending brief actions and unreadable selections block export.
The download leaves the brief, selection and filters unchanged, including on
failure. It does not save a brief revision or fetch URLs.

## Portable fields and fidelity

Records have `TY`/`ER` boundaries and CRLF lines. `ID` is a positional identity
like `moonfind-slot-4-record-1`, unique within the exported list; it is not a
globally stable publication ID and can change when sources are removed.

- `TI`: title; `AU`: one field per retained author; `ED`: one per retained editor
- `PY`: leading four-digit year when followed by end, whitespace, `-` or `/`
- `T2`: retained venue; `KW`: retained keyword string as one field, not split
- `DO`: recognized DOI text with one DOI label/resolver prefix removed; original
  case is retained. Invalid or missing DOI text is omitted from this field.
- `UR`: only a non-whitespace HTTP(S) URL-shaped string; not fetched or verified
- `AB`: the supplied abstract, never inferred or labeled as full text
- `N1`: one compact JSON provenance note containing the complete original typed
  reference, original type/date/IDs, source slot/name/digest and capture origin
  and time. Digests are copied source claims and are not reverified here.

Empty citation fields are omitted. Citation-field C0, DEL/C1 controls and Unicode
line/paragraph separators become individual spaces; leading/trailing whitespace
is removed. Notes JSON-escape these values and retain them exactly when decoded.
An embedded `ER` or `TY` line cannot synthesize extra fields or records. These
are data transformations for RIS exchange, not changes to the saved source.
Notes may include supplied abstracts and potentially sensitive source origins;
review before sharing. Original source-file bodies are not exported.

BibTeX article and CSL article-journal map to JOUR; book to BOOK; inbook,
incollection and chapter to CHAP; inproceedings, conference and paper-conference
to CPAPER; proceedings to CONF; theses to THES; technical reports to RPRT;
CSL webpage/post-weblog to ELEC. Existing RIS types JOUR, BOOK, CHAP, CPAPER,
CONF, THES, RPRT, ELEC, GEN, NEWS, MGZN, DATA and UNPB are retained.
Unmapped types become GEN; their originals remain in the note. This deliberately
limited mapping does not invent missing pages, volume, issue, publisher or dates.

## Limits and verification

The file must fit 1 MiB UTF-8. Existing source-intake and brief limits remain.
Names are the original importers' rendered name strings, not reconstructed CSL
person objects. All original supplied fields in the typed reading-list card
remain in the provenance note, but fields never projected by the original
importer cannot be recovered here. Keep the dossier and JSON reading-list export
for provenance review; this RIS file is not a restorable MoonFind dossier.

Consumers differ in handling GEN, ED, Unicode, notes, dates and duplicate records.
No external reference manager or native re-import is qualified by this feature.
Compiled UI tests exercise the writer, selection reducers, an independent strict
line reader, note round trips, rendered controls and actual Blob bytes. Supplied
metadata is not evidence of publication identity, full-text review, scientific
truth, author rights, approved conclusions or research completion.
