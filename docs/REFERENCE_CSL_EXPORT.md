# Export a citation library as CSL JSON

The brief studio's **Unified bibliography reading list** can now produce a
standard CSL JSON array for citation tools that accept that format. Use it to
carry references selected from BibTeX, RIS and CSL sources into a writing
project without manually transcribing the retained citation metadata.

## Choose the scope and download

1. Import a local bibliography using the existing BibTeX, RIS or CSL JSON panel,
   then **Add selected references to brief**. Repeat for another format, or reopen
   a saved brief with retained selection captures. Try the synthetic
   `fixtures/local-bibliography.bib`, `local-bibliography.ris` and
   `local-bibliography.csl.json` examples.
2. Search the unified list and optionally inspect an exact same-DOI group.
   **Download current bibliography CSL JSON** saves exactly the matching cards,
   in the selected reading-list order, as `moonfind-reading-list.csl.json`.
   [Publication-year scope and ordering](REFERENCE_PUBLICATION_YEARS.md) apply.
3. To choose individual references across searches, **Add to shortlist** on each
   card. **Download selected references CSL JSON** saves all chosen cards in
   selection order as `moonfind-selected-references.csl.json`, including choices
   hidden by the current filters. Same-DOI candidates remain separate records.
4. Import the `.csl.json` file into a citation tool that supports CSL JSON, or use
   it as a bibliography in a writing tool such as Pandoc. Use the exported `id`
   (also supplied as `citation-key`), for example `moonfind-slot-2-record-1`, when
   citing it. Inspect the resulting names, dates and citation style before use.
5. Keep the saved MoonFind dossier alongside the export for original source
   bytes. The CSL file is a citation library, not a saved brief or an annotation
   backup. Downloading does not change sources, filters or choices, or save a
   brief revision. Shortlists retain their existing session-only lifetime.

No matching cards, an empty shortlist, unreadable selections or stale shortlist
choices produce a repairable message rather than a partial file. Pending brief
operations block downloads. A failed download leaves the same scope available
for retry. Source removal/replacement requires choosing affected shortlist cards
again; appending sources preserves valid choices.

## Field and fidelity contract

The output follows the [CSL input-data schema](https://raw.githubusercontent.com/citation-style-language/schema/master/schemas/input/csl-data.json)
for the exported subset. It has a top-level array, required string `id` and `type`,
and standard optional fields. No proprietary wrapper surrounds the array.

- IDs and citation keys are generated from source slot and original record
  number. They are unique within an export and remain the same across search
  and shortlist exports of that record. They are not global publication IDs:
  slots can change after source removal, and another brief may use the same IDs.
  Rename conflicting IDs before combining separate brief libraries.
- `title`, `container-title`, `keyword` and `abstract` retain supplied strings.
  A venue already flattened by intake is used as `container-title`; the exporter
  cannot recover whether that value originally came from a publisher field.
- `author` and `editor` contain `literal` name objects. Existing cards contain
  display strings, so the exporter does not guess family/given names, particles
  or corporate authors. Blank names are omitted. Citation styles may consequently
  leave personal names uninverted or un-abbreviated; edit in a reference manager
  if structured names are needed.
- `issued.date-parts` preserves numeric year, year-month or year-month-day
  precision for 0001–9999, with valid calendar months/days, including leap years.
  A pair separated by ` / ` becomes a two-date range when both dates qualify.
  Other supplied date text stays in `issued.literal`, including uncertain dates,
  seasons, unsupported syntax and invalid calendar dates. No missing month/day
  is filled in. Original spacing/zero padding remains in provenance.
- A DOI-shaped value has one DOI label/resolver prefix removed. Only an HTTP(S)
  URL-shaped value enters `URL`. Unsupported link text remains in provenance;
  no link is fetched or independently validated.
- Blank fields are omitted. No missing volume, pages, issue, publisher, attachment
  or other metadata is invented. Fields discarded by the original intake cannot
  be recovered by this export. Unicode, quotes, controls and markup are JSON
  data; external citation tools may render their own markup conventions.

BibTeX article maps to article-journal; book to book; inbook/incollection to
chapter; inproceedings/conference to paper-conference; theses to thesis;
techreport to report; unpublished to manuscript. RIS JOUR, BOOK, CHAP, CPAPER,
THES, RPRT, UNPB, ELEC, NEWS, MGZN and DATA map to the corresponding journal,
book, chapter, conference-paper, thesis, report, manuscript, webpage, newspaper,
magazine and dataset types. Recognized CSL types are retained. Other types,
including BibTeX proceedings and RIS CONF/GEN, use generic `article`. Their exact
original type remains in provenance; no journal/full-text status is implied.

Each item's `custom.moonfind` records `moonfind.reference-csl-export.v1`, brief
identity, scope, exact typed reading-list card, capture origin/time and a boundary
statement. The original citation key, potentially very large numeric ID as
lossless text, original type/date/link text, availability, source filename,
record number and claimed source digest all remain there. Digests are supplied
claims, not reverified by this export. The schema reserves `custom` for additional
metadata; consumers may discard it. No source-file bodies or unrelated captures
are included. Review abstracts and capture origins before sharing.

## Limits and qualification

Maximum output is 1 MiB UTF-8; narrow the search or shortlist if exceeded.
MoonFind's existing CSL intake remains limited to 32 KiB per source, so a larger
export must be narrowed before re-importing into MoonFind. Existing source/brief
limits and host import behavior are unchanged.

Focused tests exercise the production reducers, field writer, literal HTML
rendering and real Blob bytes through controlled DOM boundaries. A retained
acceptance harness round-trips example exports through byte-identical current
`parse_csl` production blocks in a core-only JS package. This verifies parser
compatibility in isolation, not the native host, browser file picker, browser
disk save, Pandoc, Zotero or another external reference manager. No citation-style
rendering, full-text review, scientific result, accepted answer, provider run or
company decision is implied. Cumulative qualification remains R50.
