# Use a BibTeX bibliography in an offline research brief

MoonFind can turn a local `.bib` export into searchable, citation-keyed reference
cards. This is useful when the working evidence set already lives in Zotero,
JabRef, a paper's bibliography, or another reference manager.

## Import, narrow and retain

1. Open **Offline brief studio** (`/apps/moonfind/briefs`). Fill in the question,
   audience, decision and source restrictions as usual.
2. Choose **Import BibTeX bibliography** and select one UTF-8 `.bib` file.
   Try `fixtures/local-bibliography.bib`, a synthetic three-reference example.
3. Search references by citation key, title, author, year, venue or keyword.
   For the sample, `GARCÍA` finds records 1 and 3; `contact` or `2025` finds 1.
   Select the cards to use. Selections survive filter changes.
4. Choose **Add selected references to brief**. MoonFind retains the unchanged
   bibliography and a `bibtex-selection.json` companion. The companion records
   selected citation keys, parsed metadata, original filename and SHA-256 digest.
5. Save the brief. Reopen it to inspect the retained cards, or download the
   readable brief and complete source dossier. The readable brief has a
   **Selected BibTeX references** section; the ZIP includes the byte-exact `.bib`,
   selected-card JSON and manifest.

An import uses two of the eight source slots. Existing limits apply: 32 KiB per
source, 128 KiB combined. Large selections may need narrowing because structured
metadata can exceed the original file size. A failed parse adds no partial set.

## Use the selection to make progress on the question

From a saved brief, open the offline comparison worksheet. Name the options and
choose `bibtex-selection.json` as their strongest local capture. Refer to exact
keys such as `[garcia2025Lunar]` in assessments, contradictions and unknowns.
Record the next discriminating experiment or reading task, then export the
comparison as Markdown and JSON. The worksheet retains the exact saved revision
and source bytes, and its JSON backup can be restored in the same brief.

For example, the sample can support a user-authored comparison of contact
sensing versus tactile mapping, while recording that an abstract alone cannot
establish hardware transfer. No model provider or remote citation lookup is
needed for this workflow. A saved brief or worksheet is not a completed research
run, verified scientific result or approved decision.

## Supported bibliography syntax and limits

- Braced or parenthesized entries; nested braces; quoted values; numeric values;
  repeated authors separated by `and`, including brace-protected organization
  names; Unicode; comments; `@string` definitions and `#` concatenation
- Card fields: citation key, type, title, authors, year (or BibLaTeX `date`),
  journal/journaltitle/booktitle, keywords, DOI, URL and abstract
- `@preamble` is ignored. TeX commands and brace groups stay plain source text;
  no TeX, URLs or attachment paths are executed or fetched
- Duplicate citation keys, unfinished input and undefined string macros are
  reported as repairable import errors. Define a macro before using it
- Cross-reference inheritance, BibLaTeX `xdata`, TeX rendering and extended name
  syntax are not expanded. Unsupported fields remain in the original `.bib`;
  use a flattened reference-manager export when inherited fields are needed

Cards explicitly distinguish `metadata-only` from `metadata-and-abstract`.
Neither label means the cited full text was retrieved. Origin and capture time
are supplied with the local input; the digest binds its exact bytes.

## Local API

- `POST /api/v1/briefs/bibtex/intake`: `{source, query}` with an ordinary
  `BriefSourceInputV1` object. Returns the original source, total reference count
  and filtered cards. Empty query returns all cards; record numbers stay stable
- `POST /api/v1/briefs/bibtex/select`: `{source, record_numbers}`. Re-parses the
  supplied source and returns the original plus a selected metadata companion
- Ordinary brief save, reopen, `brief.md` and `dossier.zip` routes retain/export
  the result. No runtime submission is implicit in any of these operations

## Combine reference lists

After adding selected cards, use the [unified bibliography reading
list](UNIFIED_REFERENCE_READING_LIST.md) to search retained BibTeX, RIS and CSL
selections together, inspect same-DOI candidates and export the current list.
