# Inspect missing and mixed-type JSON evidence

The existing brief explorer can now group records by the presence and type of
any top-level field. This helps a researcher find observations with an absent
outcome, distinguish an explicit null from unanswered text, or separate numeric
measurements from numeric-looking strings before preparing a source extract.
No field is filled in, converted, scored or judged scientifically complete.

For a field inside an object or array, use the separate
[nested-field lens](JSON_NESTED_FIELD_LENS.md). It follows an explicit relative
JSON Pointer and can inspect paths absent from every record.

## Try the synthetic fixture

1. Open `/apps/moonfind/briefs`, choose the local file
   [`fixtures/json-field-coverage.json`](../fixtures/json-field-coverage.json),
   select its source slot, enter `/observations`, then **Explore JSON array**.
2. Open **Inspect JSON field coverage**, then the `outcome` field. Its five-source
   denominator is shown beside every category: missing 1, null 1, empty-string 1,
   string 2, and zero records in each remaining category.
3. Choose **Replace selection: missing · 1 / 5**. Source record 4 is now the
   entire selection. Any prior selection is replaced and the search is cleared,
   making the selected row visible again. Inspect its original `/observations/3`
   locator. `null` selects record 1; `empty-string` selects record 2. The string
   category selects both `unknown` and a single space, without trimming them.
4. Use **Preview selected JSON extract** and its existing download action to
   retain source provenance, or **Add selected JSON records to brief** to create
   a derived source using the existing save/reopen path. The original capture
   remains untouched. All fields of selected records are included.
5. For a mixed-type check, open `count`. Number selects records 1 and 2; string
   selects record 3. Existing **Preview selected raw NDJSON records** preserves
   the exact integer `9007199254740993`. No float conversion occurs in coverage.
6. The same controls work after **Explore loaded JSONL lines** or **Import JSONL /
   NDJSON file**. Selections use one-based record identities, while the original
   physical source-line numbers remain in the table and provenance extract.

## Scope and semantics

- The denominator is every record in the explored array or JSONL capture,
  irrespective of search and selection. Nested objects/arrays remain single
  top-level values; nested fields are not inspected recursively.
- Each field partitions the source records into exactly eight disjoint groups:
  missing, null, empty-string, string (nonempty), number, boolean, array, object.
  Zero and negative zero are numbers; false is boolean; `[]` and `{}` are present
  containers. A whitespace-only string is nonempty. No truthiness coercion occurs.
- Field names retain first-seen order. Empty names and names containing `/`, `~`,
  Unicode or prototype-like words are literal labels. Record ordering is original
  source order, and repeated identical source objects remain separate records.
- A zero-count category deliberately clears selection. Search is also cleared.
  Existing **Select matching JSON records** still adds to selection instead;
  category buttons explicitly say **Replace selection** to distinguish them.
- Coverage and selections are temporary. Switching source/pointer or replacing
  the loaded source resets exploration through the existing guards. Saving or
  reopening does not persist a coverage selection; add an extract and save it
  when the selected evidence needs to be retained.
- The existing 32 KiB source, 512-record, 32-field and 32-level nesting limits
  apply. Empty arrays or records with no fields do not invent fields/categories.
- A field absent from every object never appears in the union of field names.
  There is no schema of required fields, expected type, cross-source merge,
  sampling, statistical confidence or automatic completeness judgment.

Review original/private fields before exporting. Selection is not redaction of
an original dossier. Source text is inert and no URLs or instructions are run.
No new endpoint, provider call, permission, file upload, accepted research state
or company authority is introduced. Existing browser downloads are requests,
not evidence that a file actually reached disk.

## Qualification

Run from the repository root:

```sh
node --test scripts/test_json_field_coverage.mjs scripts/test_json_evidence_ndjson.mjs
```

R468 ran 14 focused coverage tests plus the 30 existing NDJSON tests (44 passed).
They execute the actual production JavaScript extern bodies extracted from the
MoonBit files: lossless JSON/JSONL intake, field grouping and selection, existing
NDJSON output and reimport. They cover the documented fixture, every category,
source denominators, literal field names, source locators, hidden selections,
empty data, nonmutation, lossless numeric spellings and the maximum shape.
Separately named source-wiring checks inspect the UI and reducer connections;
they do not execute MoonBit wrappers, reducers or rendering.

MoonBit compilation, a graphical browser, the file picker, real disk downloads,
native host save/reopen and provider/full-product execution were not run here.
Dependencies were unavailable and no install, substitution, network or Moon
command was attempted. This focused result does not advance the cumulative
R50 qualification or merge the separate R51–55 tracks.

PRD rationale: MoonFind UC02/B02 requires inspectable local source intake, and
R02 says missing evidence must remain unknown. This bounded data-shape workflow
helps expose missing observations without claiming to fulfill the broader
scientific comparison or configured-provider research journey.
