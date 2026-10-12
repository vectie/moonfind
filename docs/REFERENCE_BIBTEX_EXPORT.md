# Export a selected bibliography as BibTeX

In the brief studio's **Unified bibliography reading list**, choose **Download
current bibliography BibTeX** for the visible text/DOI/publication-year matches,
in the current order. Or choose individual cards across searches and use
**Download selected references BibTeX**. This includes hidden choices in selection
order. Identical DOI values, original citation keys, names and repeated source
captures do not collapse records. This extends the existing JSON/RIS/CSL writers;
it does not change intake, saved briefs, source bytes or reading notes.

The downloads are UTF-8 `moonfind-reading-list.bib` and
`moonfind-selected-references.bib`, MIME `application/x-bibtex;charset=utf-8`.
Keys are `moonfind-slot-N-record-M`, using the existing positive source slot and
original record number. They are unique within the current brief/export; source
removal can renumber slots, so these are not global or permanent publication IDs.
No source key is reused as executable bibliography syntax.

## Fields and bounded syntax

- Exported title, abstract and keywords use supplied display text. Titles retain
  case via an extra brace group. Blank fields are absent, never fabricated.
- Authors and editors are separate literal brace groups joined by `and`. Person
  parts, initials and corporate/person status are not inferred. Names containing
  the word `and` remain one name. A reference manager may render literal names
  differently from structured personal names.
- A single valid numeric YYYY, YYYY-M or YYYY-M-D date supplies only `year`.
  Impossible, uncertain, missing and range dates have no projected year. All
  original date text and precision remain in the custom field.
- Types: BibTeX's recognized classic types are retained (`conference` becomes
  `inproceedings`). RIS JOUR/MGZN and CSL article-journal/article-magazine become
  article; BOOK/book become book; CHAP/chapter become incollection;
  CPAPER/paper-conference become inproceedings; RIS CONF becomes proceedings;
  RPRT/report become techreport; UNPB/manuscript become unpublished. Everything
  else becomes misc, including generic thesis (the degree is unknown).
- Venue supplies journal for article, or booktitle for incollection and
  inproceedings. No publisher, institution, school, page range, volume or issue
  is inferred. Required-but-unavailable fields remain absent; citation styles
  can warn about incomplete records. Other venue text remains in provenance.
- Recognized DOI text loses only the existing doi:/HTTP(S) DOI prefix. URL must
  be HTTP(S). Link fields are omitted when not nonempty printable ASCII, or when
  they contain backslash, braces, %, $, #, &, _, ^ or ~. These are characters
  whose escaping is inconsistently interpreted by link consumers. Exact original
  DOI and URL remain in provenance. No URL is opened or resolved.
- Text controls/line separators become spaces. TeX special characters are escaped
  using a fixed literal vocabulary. Backslashes become textbackslash; braces
  become textbraceleft/textbraceright with balanced empty groups. Supplied TeX,
  including original BibTeX markup, is displayed literally and never trusted as
  a command. No @preamble, @string or crossref instructions are generated.
  Output is capped at 1 MiB of UTF-8; reduce scope if it exceeds the cap.

## Exact originals and source lineage

Each entry has `moonfind_provenance_hex`, lower-case hexadecimal UTF-8 JSON with
contract `moonfind.reference-bibtex-export.v1`. Decode that field as hex bytes,
then UTF-8 JSON. It records the generated key, brief ID, export scope, complete
original ReadingReference (including source name/digest, source slot, record,
original key/ID/type, dates, names and all retained metadata), plus capture name,
origin, captured-at and kind. The original title, controls, braces, Unicode,
unsupported link, date and type are preserved separately from citation fields.
No original capture body or credential is added. Digests are supplied claims,
not reverified here. This is not a restorable dossier or full-text review.
Keep the dossier and review source origins and metadata before sharing.

## Refusal and retry

Pending operations, unreadable selections and invalid active year bounds block
current exports. Empty matches also refuse. Shortlists ignore current filters
and invalid year bounds but reject empty, stale, replaced or moved choices.
Appending a source keeps valid choices. Reopen/New/reload keep their existing
shortlist-reset rules. A download creation/click failure leaves sources, filters
and choices intact and reports an error; retry uses the same chosen records.

## Compatibility and evidence

Format decisions are based on Oren Patashnik's original *BIBTEXing*, sections
3–4: [author manual](https://mirrors.ibiblio.org/pub/mirrors/CTAN/biblio/bibtex/contrib/doc/btxdoc.pdf).
The format permits extra fields, but ordinary styles can ignore them. Name-list
separators apply outside braces. This implementation deliberately projects a
small subset and does not claim full BibTeX or biblatex round-trip fidelity.

Retained fixtures are read by installed Pandoc 3.1.11.1 (`bibtex` to `csljson`) and
classic BibTeX 0.99d using a small inspection style, with exact keys/counts and
literal-name counts checked. There is no installed standard `.bst` style in this
environment. Parser acceptance is not typeset-reference acceptance.

Observed limits: Pandoc drops textbraceleft/textbraceright/textbar macros when
rendering citation text. It retains the other tested literal escapes. Exact
characters remain in the custom hex field. Consumers can discard custom fields;
no restoration support is claimed. UTF-8 is emitted without transliteration;
legacy BibTeX sorting, fonts and downstream Unicode/TeX/PDF behavior are untested.
Production reducers and real Node Blob bytes are tested through a controlled DOM
boundary, not an actual browser download, native host import, clipboard, desktop
reference manager, provider workflow or graphical acceptance.
