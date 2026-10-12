# Explore JSONL / NDJSON observation exports

A local event log or observation export often has one JSON object per line,
rather than an enclosing JSON array. The brief studio can now read that format
without converting or rounding its values. It remains local evidence preparation,
not a research conclusion, a provider run, or verification of the observations.

To reuse chosen observations in another line-oriented tool, the same explorer
now offers [selected raw NDJSON output](SELECTED_NDJSON_OUTPUT.md), with a
preview and no added envelope or provenance fields.

## Use the included synthetic example

1. In `/apps/moonfind/briefs`, find **Explore loaded JSON evidence** and choose
   **Import JSONL / NDJSON file**. Open `fixtures/observation-events.ndjson`.
2. The table shows three object records at physical source lines 1, 3 and 4.
   The blank line remains in the original. Field values retain their types;
   missing, null, empty strings and nested JSON remain distinct.
3. Search `CLINIC`, then **Select matching JSON records**. Search `school` to
   inspect the excluded record; your two clinic selections remain selected.
4. Open **Preview selected JSON extract**. Download the JSON or choose
   **Add selected JSON records to brief**. The original and selected extract are
   separate ordinary source captures. Save with the existing brief save action.
5. Reopen the brief. Choose the retained `.ndjson.txt` source in the source
   selector, then **Explore loaded JSONL lines**. To explore the added JSON
   extract instead, select it, enter `/records`, and choose **Explore JSON array**.

You can also paste JSONL under a `.txt` filename using existing source controls,
select that source, and choose **Explore loaded JSONL lines**. The array pointer
is ignored and cleared by that button. Changing pointer or source clears the old
table and selections. Selection and search are temporary; only adding and saving
retains the extract. Import appends one source; adding an extract appends another.
The original is never rewritten or deleted by exploration.

## Exact bytes and locators

`.jsonl` and `.ndjson` filenames gain `.txt` for the existing text-capture host
contract. `.txt` names stay unchanged. Origin records the original filename and
mapping. All original UTF-8 bytes, including BOM, CRLF and blank lines, remain
unchanged. No native intake endpoint or root-module format contract is changed.

The new `moonfind.jsonl-evidence-extract.v1` envelope contains source metadata,
`source_format: "jsonl"`, total/selected counts and selected records in original
order. Each record contains its one-based `source_record`, one-based physical
`source_line`, `source_pointer: null`, and exact original object token span in
`record`. `array_pointer` is null, because JSONL has no document-wide JSON Pointer.
Object-internal whitespace, escape spelling, huge integers, negative zero,
trailing decimal zeroes and exponent tokens are preserved. Leading/trailing
whitespace outside each object and source line separators are not copied into
the extract; they remain in the original. JSON readers may still round numbers,
so use a lossless reader when exact numeric spelling matters.

The existing JSON-array extract contract and pointer meaning are unchanged.
The same download filename (`moonfind-json-evidence-extract.json`) is used for
both formats; the envelope declares which locator contract applies. Repeated
records and repeated IDs remain distinct. No field projection or redaction is
performed; every field of a selected object is exported.

For an unchanged matching prepared snapshot, the existing export copies its
host-issued digest and revision. Otherwise both are explicit nulls. Exploration
and download do not create or reverify a host digest. Source removal or replacement
clears exploration; pending requests and stale import callbacks cannot add input.
Failed parsing/import/add/download leaves existing source content intact.

## Format and limits

- UTF-8, one optional leading BOM, LF/CRLF/CR physical line boundaries.
- One object per nonblank line, optional surrounding spaces/tabs; blank lines
  are skipped but counted in physical locators. An empty/blank-only file is an error.
- Up to 32 KiB source bytes, 512 objects, 32 distinct top-level fields, and 32
  nesting levels. The existing eight-source/128 KiB brief total also applies.
- Multiline objects, scalar/array records, comments, JSON5, duplicate object keys
  (including nested duplicates), invalid UTF-8 and malformed lines are rejected.
  Line parsing errors name the physical line and never partially append a source.
- Extracts over the per-source bound can be downloaded separately. Reduce the
  selection before adding them to a brief. Nothing is silently truncated.

Private fields and origin metadata may be present in the extract. The complete
original remains in the dossier, including unselected information. Review before
sharing. Source HTML, scripts, links and instructions remain literal text.

## Verification boundary

Compiled-JS tests exercise production reducers, parser, exact File reads, actual
Blob output, Rabbita rendering, and source persistence using controlled browser
storage and synthetic host-shaped save/reopen replies. No graphical browser,
real browser disk-save, native host, external source, or provider was exercised.
Cumulative qualification remains R50; this workflow has separate focused evidence.
