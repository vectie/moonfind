# Nested JSON children as research observations

Use a local saved JSON file containing parent records with repeated child
observations, such as studies with measurements or interviews with responses.
Choose one parent array, one relative child-array or child-map pointer and explicit fields.
The companion emits one ordinary CSV row per child, with exact source identity
and parent/child locations. It never creates a Cartesian product or infers a key.

This is a Node 20+ local product companion. It needs no dependencies, network,
native rebuild or provider. The ordinary CSV explorer is unchanged.

## Inspect → plan → preview → convert → select

From this source root:

```sh
node scripts/json_children.mjs inspect --json fixtures/child-observations.json
node scripts/json_children.mjs preview --json fixtures/child-observations.json --plan fixtures/child-observations-plan.json
node scripts/json_children.mjs convert --json fixtures/child-observations.json --plan fixtures/child-observations-plan.json --out-dir ./child-review
```

1. Inspect prints the exact SHA-256 source digest and array/map locations. It shows
   at most 64 arrays and 64 objects, with eight child types/decoded keys per
   container, reporting each shortened inventory explicitly. An object is a
   possible map, not an automatic selection. Inspection is not permission to use
   or publish a file.
2. Make a separate plan following `fixtures/child-observations-plan.json`. Enter
   the inspected digest; a changed source, even changed whitespace, requires a
   new digest and review. `parent_pointer` selects an array of object records.
   `children_pointer` is nonempty and relative to each parent. JSON Pointer uses
   `~1` for a slash, `~0` for a tilde, and zero-based canonical array indexes.
3. Choose `child_mode`: `records` requires every child to be an object; `scalars`
   accepts strings, numbers, booleans and null, with every child field pointer
   empty to select the entire scalar. Mixed scalar kinds remain distinct via
   kind columns. Object/scalar mixtures refuse; no row silently disappears.
4. Choose `empty_arrays` and `missing_arrays` independently as `error` or `skip`.
   Preview lists every parent, state, child count and action. An error policy
   exposes blockers and candidate rows but prevents all conversion. Skip creates
   no invented observation. Null/scalar child containers always refuse.
5. Choose 1–13 fields. Each has `scope` (`parent` or `child`), relative `pointer`,
   and an explicit output `name`. At least one child field is required. Each
   selected field produces its value column and a sibling `name_kind` column.
   Provide operator-declared origin, capture time, restrictions and permitted
   access. This does not establish license or authenticate the source.
6. Preview does not write files. Convert requires a new output directory and
   writes `source.json`, `observations.csv`, `provenance.json`, then a digest
   `manifest.json`. Existing files, directories and symlink destinations refuse.
7. In MoonFind use **Import CSV table** on `observations.csv`. Search a column,
   filter, select matching observations, and extract selected CSV. In the sample,
   search `label` for `follow-up`: two separate child observations remain, with
   pointers `/studies/0/readings/1` and `/studies/1/readings/1`.
   Keep the complete original and provenance sidecar with the extracted evidence.

The sample has four child observations. Two further parents have an empty or
missing child array; the explicit skip policies retain both in the parent
inventory. It contains large numbers, `-0`, exponent spelling, an escaped string,
a formula-like string, null and a missing field to make fidelity visible.

## Keyed child maps across parents

For a study whose `readings` is an object such as
`{"10":{"value":1},"2":{"value":2}}`, choose the explicit
`moonfind.json-child-map-plan.v1` contract. The existing array contract remains
unchanged; a map is never inferred from array mode or vice versa.

```sh
node scripts/json_children.mjs inspect --json fixtures/child-map-observations.json
node scripts/json_children.mjs preview --json fixtures/child-map-observations.json --plan fixtures/child-map-observations-plan.json
node scripts/json_children.mjs convert --json fixtures/child-map-observations.json --plan fixtures/child-map-observations-plan.json --out-dir ./child-map-review
```

Use the supplied plan as an example:

- `parent_pointer` selects `/studies`; `children_pointer` selects `/readings`
  relative to each parent. One map per parent is expanded; other fields stay
  intact. There is no recursive flattening or Cartesian expansion.
- Set `empty_maps` and `missing_maps` separately to `error` or `skip`. Preview
  retains every parent's state, count and action. An error blocks conversion of
  the entire bundle, even if other parents have candidate rows. Skip creates no
  placeholder row. Null, scalar and array containers refuse in map mode.
- Choose `child_mode` as `records` for object values or `scalars` for scalar
  values. The mode is checked for every member. Fields use explicit scopes
  `parent`, `key`, or `value`; at least one key and one value field are required.
  A key field must use pointer `""` and returns the exact quoted original key
  token. A scalar value field must use pointer `""`; record values can select
  nested fields or their complete original token. Parent fields retain context.
- Preview columns and rows show parent, key and value fields with their kind
  columns. Missing value fields remain empty with kind `missing`, distinct from
  empty keys (`""`), null values and empty strings.
- Rows follow parent array order, then the original textual map-member order.
  Numeric-looking keys are not sorted or converted into array indexes: `"10"`
  precedes `"2"` in the example. `child_index` is a zero-based member ordinal,
  not the key. Empty, escaped, slash/tilde and numeric keys are supported.
- Decoded keys must be unique within each object: `"a"` and `"\u0061"` in the
  same map refuse. The same decoded key in different parents remains separate.
  Its full source pointer and parent context distinguish the observations.

The example produces seven rows and inventories two skipped parents. Import
`observations.csv` with **Import CSV table**, choose `observation_key`, filter
for `10`, select matching rows, and extract. The result keeps both study rows,
with `/studies/0/readings/10` and `/studies/1/readings/10`, and the exact values
`9007199254740993` and `1e400`. Keep the original and sidecar with that extract.

Keyed plans use `moonfind.json-child-map-preview.v1`,
`moonfind.json-child-map-provenance.v1`, and `moonfind.json-child-map-bundle.v1`.
For each key cell, provenance marks `target: "member_key"`; its pointer locates
the member's value because RFC 6901 cannot address a key token. Its separate
`span_utf16` identifies the exact original key token, and the row's `child_key`
is the decoded key. For an empty key the pointer ends with `/`; that is a real
member location, not the map itself. Value cells retain their ordinary pointers.

## Fidelity and interpretation

The first five CSV columns are `source_digest`, `parent_index`, `parent_pointer`,
`child_index`, `child_pointer`. Indexes are zero-based and local to their array
or map-member order.
CSV header is logical record 1. Each provenance row binds its CSV record number
to the original parent and child, plus each field's absolute pointer, type and
half-open UTF-16 span in the decoded original. These are not byte offsets. A
leading UTF-8 BOM, when present, counts as one decoded UTF-16 unit. Source bytes
and manifest digests remain exact.

Present cells contain their exact original JSON token, not JavaScript values.
For example a string is `"hello"`, an escaped string stays `"\u0061"`, a number
can remain `9007199254740993`, `1.2300e+02` or `1e400`, and null stays `null`.
Objects and arrays selected as fields stay complete raw JSON tokens in one cell.
There is no numeric rounding, decimal/date interpretation, inferred score or
automatic coercion. Numbers outside binary64 remain ordinary evidence text.

A missing field is an empty CSV cell with kind `missing`. An empty JSON string
is `""` with kind `string`; null is `null` with kind `null`. Traversing through
a scalar is invalid, not a missing field. Scalar observations can repeat and
still have different child pointers. The only row order is parent order followed
by child order. All source content, including unselected/private fields and
skipped parents, is retained. This is not redaction or a privacy filter.

All duplicate object keys, including escaped-equivalent keys, refuse rather than
choose a value. Invalid JSON, invalid UTF-8, escaped unpaired Unicode surrogates,
unsupported plan fields, ambiguous/reserved column names and stale digest refuse.
Formula-like source strings stay inert JSON text in this workflow; other software
can interpret imported text differently. Inspect before opening in a spreadsheet.

## Bounds and recovery

- Original JSON: 1–32,768 bytes, 10,000 values, 64 nested containers.
- Plan: 16 KiB; pointer: 1,024 UTF-16 units; field name: 80 units.
- At most 512 parent records and 512 expanded observations. At most 13 chosen
  fields plus five lineage columns gives 31 output columns (consumer limit 32).
- CSV and provenance are independently at most 32 KiB. Source duplication across
  children can hit either byte limit before the row limit. Reduce the input or
  field selection explicitly; the companion never silently truncates rows/cells.
- CSV byte growth and lineage growth are checked during expansion. A bounded
  source cannot amplify into a giant persisted fixture or partial accepted file.

Parsing, planning and derivation finish before creating output. A write failure
can leave an incomplete new directory; retain it as failed evidence, inspect the
error, and choose a different new directory for a reviewed retry. A directory
without the final manifest is not a completed bundle. Never repair the original
in place; use a separate input copy and re-inspect its changed digest.

## Verification boundary

`scripts/test_json_child_maps.mjs` executes the actual companion API and
inspect/preview/convert CLI, exact token/span checks, map policies, decoded-key
uniqueness, and an array-plan regression. Its generated CSV is fed to current
retained production explorer reducers:
Imported → SearchColumn → Filter → SelectMatching → csv_extract_text.

Set `MOONFIND_CHILD_MAP_EVIDENCE` to a new evidence directory,
`MOONFIND_RETAINED_EVIDENCE` to the retained R765 evidence directory, and
`MOONFIND_WORKSPACE` to the workspace containing those retained build inputs.
Then run `node --test scripts/test_json_child_maps.mjs`. The test must verify
`range-runtime.cjs` SHA-256
`b4ced4539764212ff329a646ef409d8bb1c8885d87cf2fe4be183022421181b7`, both exact
source/interface pin manifests, all current source entries, and all retained
compiler/dependency entries. It cannot skip or reuse stale source pins.
The older `test_json_children.mjs` and R704 `retained_ui_inputs.json` fixture are
historical evidence; their UI pins do not describe the current source tree.

That journey supplies actual derived CSV intake JSON and skips browser bootstrap.
It is not native host, browser mounting, installed save/reopen or production
qualification. Ordinary CSV intake does not automatically read the provenance
sidecar. The selected CSV retains digest and exact pointers; retain the sidecar
and original for field-level auditing. No MoonBit/public interface changes or new
native builds occurred. This supports the MOONFIND-UC02/B02 source-intake workflow
and R02 evidence inspection, not completion of their authored acceptance criteria, provider work,
source licensing, full release or autonomous decision authority.
