# Local EndNote tagged-text bibliography

Open the brief studio, choose **Import EndNote bibliography**, and select a UTF-8 `.enw` file. Inspect title, authors, year, DOI, URL, abstract and the expandable original tag list. Filter by author, select records, then add the selection to the brief. Changing the author filter keeps the selected original record numbers.

Each addition retains two ordinary sources: the complete original file, byte-for-byte, and `endnote-selection.json`. The companion has contract `moonfind.endnote-selection.v1`, original filename, source digest and selected metadata. Unknown and repeated tags stay in each selected record's ordered `fields` list. Field values are trimmed and indented continuations joined by LF; exact source spelling and line endings remain in the original capture.

Selected records enter the existing unified reading list, DOI candidate groups, publication-year controls, session shortlist, and JSON/RIS/CSL/BibTeX downloads. Ordinary Save and Open retain the source pair. The shortlist itself remains session-only. Dossier export includes both sources and a readable selected-reference section. Selecting records does not redact the original file: it still contains every unselected record and tag. Review the dossier before sharing.

## Supported dialect

- UTF-8, optionally with a leading BOM; LF and CRLF line endings.
- Each record begins with `%0 ` followed by a nonempty reference type.
- One or more blank lines separate records. EOF closes the last record. A new `%0` without a blank separator is rejected.
- Tags begin in column one: percent, one visible ASCII character, then a space. Unknown tags are retained without interpretation.
- Repeated `%A` author and `%E` editor fields remain separate names; `%T` title, `%D` year, `%J`/`%B` venue, `%K` keywords, `%R` DOI, `%U` URL and `%X` abstract form the card projection. The year and type remain supplied text.
- As a bounded extension, nonblank lines beginning with a space or tab continue the preceding field, except `%0`. A blank line always ends the record. Unindented untagged lines are rejected.
- Missing optional title uses an explicit untitled-reference label. Each record must contain at least one nonempty field besides its reference type.
- The entire file must parse before any intake or selection succeeds. A malformed final record cannot insert earlier records partially.

The format mapping follows Clarivate's [Creating a Tagged EndNote Import File](https://docs.endnote.com/docs/endnote/2025/v1/macos/en/content/08import/creating_a_taggedenimprtfl.htm), consulted 2026-10-14. The local UTF-8 and indented-continuation rules above are this implementation's explicit bounds, not a claim of universal EndNote compatibility.

## Limits and provenance

The existing limits remain: 32 KiB per source, eight source slots and 128 KiB total dossier. A selection needs two slots; its structured metadata must also fit 32 KiB. Smaller selections may be required because retaining all tags increases companion size.

This is tagged-text intake only. It does not open `.enl`/`.enlx` binary libraries, XML exports, file attachment paths or linked URLs. DOI values are not resolved or verified. Importing an abstract does not mean the full text was reviewed. There are no citation-provider, model-provider, account, upload, deployment or credential operations.
