# Explore local JSON evidence records

Use an observation, interview or comparison export as structured evidence without
retyping it into a spreadsheet. This extends the brief studio's existing generic
JSON capture intake. It does not interpret the observations or run a model.

Use [field coverage](JSON_FIELD_COVERAGE.md) to inspect missing/null/empty values
and mixed types, then select the corresponding source records for extraction.
Use the [nested-field lens](JSON_NESTED_FIELD_LENS.md) for an exact path inside
each record, such as `/interview/outcome` or `/visits/0/duration`, with original
value tokens and separate missing-path versus blocked-parent categories.

Use [JSON evidence cohorts](JSON_EVIDENCE_COHORTS.md) to combine one or two
exact scalar field conditions with All/Any logic, inspect unresolved paths, and
replace the selected records before extraction.

For tools that need one original object per line, use the new
[selected raw NDJSON output](SELECTED_NDJSON_OUTPUT.md) from the same selection.
The existing JSON extract below keeps provenance; the NDJSON output adds none.

## Try the included synthetic observations

1. Open `/apps/moonfind/briefs`. Use **Choose local files** to load
   [`fixtures/json-evidence.json`](../fixtures/json-evidence.json), or paste it
   with a filename and an origin using the existing source controls.
2. In **Explore loaded JSON evidence**, choose its source slot. The selector
   includes all loaded captures, so JSON pasted into a `.txt` capture also works.
3. Enter `/observations` in **JSON Pointer to array** and choose **Explore JSON
   array**. Leave the pointer empty for a top-level array. The table shows all
   three synthetic records, their original locators, field types and values.
4. Search `CLINIC` and choose **Select matching JSON records**. Records 1 and 3
   are selected, preserving conflicting slow and fast handoff observations.
   Search `school`: the selected clinic records remain selected while hidden.
5. Open **Preview selected JSON extract**. Download
   `moonfind-json-evidence-extract.json`, or **Add selected JSON records to brief**.
   Adding appends one ordinary JSON source and clears the selection; it does not
   alter the original. Save the brief using its existing local host save action.
6. Reopen the saved brief to inspect both original and extract in the source
   list. The extract itself can be explored at `/records`; original values are
   nested in each row's `record` field. Existing brief/dossier downloads retain
   both sources. Exploration filters and selection are temporary and reset on
   save/reopen or a new brief.

The selected extract is an openable JSON object with a versioned
`moonfind.json-evidence-extract.v1` envelope, brief ID, source slot/name/origin/
capture time/kind, array pointer, counts and source locators. Each output record
has a one-based `source_record`, a zero-based `source_pointer`, and the exact
original object in `record`. The original full document is not embedded.

For an unchanged prepared brief, the export copies the host-recorded source
digest and revision ID. For a draft or edited brief these fields are explicitly
null. The explorer does not compute or reverify a digest; save/reopen an unchanged
revision when you need its host-issued provenance. Adding an extract after a
prepared revision keeps that revision as the new draft's parent.

## Exact data, visible differences

- Numbers keep their exact JSON spelling, including `9007199254740993`, `-0`,
  decimal trailing zeroes, and exponent tokens. No floating-point conversion is
  used to display or export source values. Other JSON applications may still
  round or overflow numbers; use a lossless reader when that distinction matters.
- Missing fields, explicit `null`, empty strings, booleans and numbers remain
  distinct. Columns are the union of top-level field names in first-seen order.
  Nested objects and arrays are displayed as literal original JSON, not flattened.
- Selected objects remain in original array order, even if selected out of order.
  Equal IDs or repeated identical records are not deduplicated. Source pointers
  always identify the original array positions, not a search-result position.
- String cells display decoded text; original string escapes and object whitespace
  remain byte-for-byte in the exported object substrings. The surrounding extract
  envelope and array whitespace are newly serialized. Original capture bytes,
  including a possible UTF-8 BOM, remain unchanged in the brief.
- Search is a trimmed, case-insensitive literal substring over displayed field
  values, including literal nested JSON. It uses whole-string Unicode lowercase
  and Greek final-sigma folding, without normalization or regular expressions.
  Field names are not searched except where present in a nested literal value.
- An empty selection downloads an explicit zero-record extract. Adding requires
  at least one selection. No hidden or unselected record is added to the extract.
  Every field of each selected object is included; this is not column redaction.

## Pointer syntax and limits

Pointers follow JSON Pointer syntax: empty means root, `/observations` is an
object member, and `/groups/0/observations` traverses array index 0. Escape a `/`
inside a member name as `~1` and `~` as `~0`. The fixture's alternate array is at
`/a~1b/~0items`. Empty member names work. Array indexes cannot have leading zeroes,
and `-` is not a readable index. URI-fragment notation (`#/...`) is unsupported.

A capture must be valid UTF-8 JSON up to 32 KiB. One leading BOM is accepted.
Explore at most 512 object records, 32 distinct top-level fields, 32 nesting levels
and a 1,024-UTF-16-unit pointer. Arrays of scalars, JSONL, JSON5, duplicate object
keys anywhere in the capture, and missing/non-array pointers produce a repairable
error. Duplicate keys are refused because a source pointer would be ambiguous.
Empty arrays and empty object records are supported. No silent truncation occurs.

For newline-delimited exports, use the separate [JSONL intake workflow](JSONL_EVIDENCE.md). The JSON array button still expects a single JSON document; the JSONL button accepts one object per physical line.

Changing source or pointer clears the prior table/selection. Source removal,
replacement or a changed slot clears the explorer rather than retargeting the
selected records. Appending an unrelated source or editing brief text leaves the
exploration in place. Pending host requests pause explorer actions. No file-picker
callback or new remote endpoint was introduced.

Adding an extract requires an available source slot and the existing 32 KiB per
source / 128 KiB total / eight-source limits. A larger valid extract can still be
downloaded separately. Failure leaves the original draft and selections intact.
A requested browser download is not evidence that a file reached disk.

The original full source stays in the dossier, including unselected information.
Both selected objects and provenance can be private. Review all contents before
sharing. HTML, URLs and source instructions are inert text; none are followed.
This is local evidence preparation, not scientific review, full-text acquisition,
research completion, source-rights approval or proof of customer demand.

## Focused verification

`ui/rabbita-moonfind/main/json_evidence_wbtest.mbt` exercises production UI reducers,
lossless projection/export, search/selection, add/browser retention, host-shaped
save/reopen, original preservation, limits, real Rabbita HTML and actual Blob
bytes at a mocked DOM download boundary. Tests are unconditional. A separate
Node verifier checks emitted artifacts with independent JSON parsing and original
numeric-token inspection. This is not a native host, graphical browser,
file-picker, real disk-save or provider qualification.

## Discover combinations before choosing cohort values

Use [observed JSON value pairs](JSON_VALUE_PAIRS.md) to break down two nested
fields by the combinations actually present in this source. Inspect each pair's
count and exact source tokens, then replace the record selection for existing
JSON/NDJSON output or add-to-brief. Missing, blocked and non-scalar groups remain
visible. It does not compute statistical significance or infer causality.

## Take only chosen fields into a spreadsheet

[Projected CSV output](JSON_PROJECTED_CSV.md) exports selected records at one to
eight explicit nested pointers, with source locators and per-field value/kind/
encoding columns. Preview the result and import value columns as text to retain
number spellings. Choosing a container includes all of its descendants; the
original full source remains in the brief and dossier.
