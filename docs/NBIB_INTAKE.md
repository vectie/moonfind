# Local PubMed/MEDLINE NBIB citation intake

In the brief studio, choose **Import PubMed NBIB bibliography** and select a
UTF-8 `.nbib` file. Inspect citation cards, PMID, author names, publication year,
venue, DOI, supplied abstract and the expandable ordered field list. Filter by
author, select original record numbers, then **Add selected references to brief**.
Selections survive author-filter changes.

The existing brief remains editable. Selected citations enter the unified
reading list, searchable by PMID, title, author and other projected metadata.
Use publication-year filters, same-DOI candidate groups, the session shortlist
and JSON/RIS/CSL/BibTeX downloads. Matching DOI or PMID text never merges records
or establishes that they are the same publication.

An addition keeps the byte-exact original `.nbib` plus `nbib-selection.json`
(`moonfind.nbib-selection.v1`). The companion binds selected original ordinals,
PMIDs and all ordered fields to the source name and digest. Save/Open retains
both captures through the ordinary brief workflow. Dossier export contains both
and a readable selected-citation section. The shortlist is session-only.

## Supported local subset

- UTF-8, optional leading BOM, LF or CRLF. A record starts with `PMID- ` and a
  positive numeric identifier. Blank lines, a new PMID, or EOF close a record.
- Field tags occupy columns 1–4, are two to four uppercase ASCII letters/digits,
  and are padded with spaces before `- ` in columns 5–6. Six-space continuation
  lines fold into the preceding value with one space. PMID cannot continue.
- Each record needs nonempty metadata beyond PMID. A missing title receives an
  explicit untitled label. The complete input must parse before anything is added.
- `TI`/`BTI` supplies title; ordered `FAU`/`AU` pairs prefer the full author name
  while unpaired `AU` names remain; `CN` retains group authors and `FED` editors.
- `DP` supplies the publication date. A simple leading year is projected for
  existing year controls; range/uncertain dates remain literal and unclassified.
  `JT`/`TA`/`BTI` supplies venue; `OT` and `MH` supply keyword text; `AB` supplies
  abstract text. Every supplied field, including repeated/unknown tags, is kept.
- The first `AID` ending in ` [doi]`, then `LID`, supplies DOI text. Other
  identifier kinds are retained without being mistaken for DOIs. `PT` supplies
  type, preferring Journal Article when present. Recognized journal/book/chapter
  types use existing export mappings; other types use the existing generic fallback.
- The displayed PubMed record URL is derived from the supplied PMID and remains
  unopened. A source digest attests captured bytes, not citation correctness.

Field meanings and `.nbib` export context follow the National Library of
Medicine's [PubMed Help: PubMed format](https://pubmed.ncbi.nlm.nih.gov/help/#pubmed-format),
consulted 2026-10-14. The parser rules above are an explicit local subset, not a
claim to support every historical MEDLINE, XML, or vendor-specific export.

## Limits and evidence boundary

The existing limits apply: 32 KiB per capture, eight source slots, 128 KiB total
saved dossier. An addition uses two slots; selected structured metadata must
also fit 32 KiB. Select fewer records when the companion is too large.

Selecting citations is not redaction: the complete original includes unselected
citations, affiliations, identifiers and other supplied fields. Review both
captures before sharing. Reading-list downloads contain the citation projection;
the original plus companion in the dossier preserve the complete supplied fields.

This is local citation preparation for MOONFIND-B02 and MOONFIND-UC02. It does not
fetch PubMed, open links, acquire full text, validate biomedical claims, start
MoonClaw, contact a model/citation provider, or confer researcher acceptance.
Metadata-only and metadata-plus-abstract states remain distinct from full-text
review. A malformed final record leaves the current brief unchanged.
