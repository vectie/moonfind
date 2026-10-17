# Consolidate repeated CSV observations with explicit keys

When several observations use the same operator-chosen identity, choose one
whole row per exact key and preserve the evidence behind that choice. This local
CLI creates a new ordinary CSV for MoonFind's existing **Import CSV table**
control. It never changes the input or merges individual cell values.

This extends the source-intake/provenance workflow (MOONFIND-UC02 and
MOONFIND-B02). Existing mapped append retains all duplicate observations. Existing
CSV join refuses duplicate nonempty right keys. Pivot chooses values for cells
in a reshaped table. None of those provides this explicit-key, whole-row
consolidation workflow.

## Inspect, preview, convert, explore

Run from the MoonFind repository with Node 20 or newer. No dependency install,
provider, network request or native build is required.

1. Inspect the exact headers and logical source records:

   ```text
   node scripts/csv_consolidate.mjs inspect --csv fixtures/record-consolidation.csv
   ```

2. Review `fixtures/record-consolidation-plan.json`. This synthetic example uses
   `participant` plus `visit` as an explicit composite key, chooses `keep-last`,
   refuses empty key components, and declares source origin, capture time,
   restrictions and permitted access. No key or access status is inferred.

3. Preview every group before writing:

   ```text
   node scripts/csv_consolidate.mjs preview --csv fixtures/record-consolidation.csv --plan fixtures/record-consolidation-plan.json
   ```

   The preview identifies all member source records, every differing non-key
   column and its exact values, the chosen source record, the new output record,
   and omitted source records. Check `can_convert` and `blockers`. A blocked
   policy preview still returns its groups successfully; it is not a converted
   bundle. Capacity-blocked previews retain the proposed selection and counts
   so the operator can understand the intended result, but `can_convert` is false.

4. Convert to a directory that does not already exist:

   ```text
   node scripts/csv_consolidate.mjs convert --csv fixtures/record-consolidation.csv --plan fixtures/record-consolidation-plan.json --out-dir local-consolidation-example
   ```

5. In MoonFind, choose **Import CSV table** and load
   `local-consolidation-example/consolidated.csv`. Search the `note` column for
   `corrected`, select matching rows, and download the selected CSV. The
   existing search is substring matching. The selected row contains the
   original `source_id=wave-b`, `source_record=2` and the added
   `consolidation_source_record=4` identifying its row in this input file.

The example has six input rows and four output rows. Group order is the order
each key first appears. The chosen input records, in output order, are 4, 6, 5,
7; original records 2 and 3 remain available in the original file and lineage.
Participant `001` at `followup` remains separate from their `baseline` group.
The multiline note belongs to one logical source record. The complete expected
output is `fixtures/record-consolidation-expected.csv`.

## Exact choices, not inferred truth

- `key_columns` must contain distinct exact existing header names. Keys compare
  decoded string tuples, case-sensitively and without trimming, numeric
  conversion or Unicode normalization. `001`, `1`, `A`, `a` and ` a` are distinct.
  Composite keys are encoded without delimiter collisions.
- `duplicate_policy` is required: `keep-first` or `keep-last` retains that whole
  original row in each group. First/last refers to input order, not timestamps,
  accuracy or authority. `error` blocks any repeated key, including entirely
  identical rows. To inspect those groups, use preview with `error`.
- `empty_keys` is required: `error` blocks any row having an empty-string key
  component; `keep-separate` preserves each such row as its own group. An empty
  key never matches another empty key. Whitespace alone is nonempty exact text.
- All differing non-key columns appear as conflicts, including supplied
  `source_id` or `source_record` columns. A conflict is simply unequal cell text,
  not a judgment that one observation is wrong. No blank-filling or cell merging
  occurs, and the tool cannot establish that equal keys represent the same entity.
- An empty table with valid headers creates an empty output table. The tool
  never invents a data row.

## Files and lineage

The new private directory contains:

- `source.csv`: exact original bytes, including omitted rows and unused/private
  information
- `consolidated.csv`: original columns and chosen cell values, plus
  `consolidation_source_record`, the chosen logical input record number
- `provenance.json`: original filename/digest and metadata, exact plan, all
  group memberships, conflicting values, chosen and omitted source records,
  output record links, derived digest and explicit policies
- `manifest.json`: byte counts and SHA-256 digests for those three files, written
  last; a missing manifest indicates an incomplete write

The original header is logical record 1 and data starts at 2. Source record
numbers are scoped to the original digest in the sidecar; they are not global
IDs. The output CSV has its own record numbers. Keep the source and sidecar with
the derived file, including when sharing an extract. Ordinary CSV intake does
not automatically consume the sidecar or preserve it alongside a selected CSV.
The added source-record column does survive ordinary CSV extraction.

For mapped-append inputs, existing `source_id` and `source_record` columns are
ordinary preserved cells; no meaning is guessed from their names. The added
column points to the appended input row. Keep the earlier append bundle too if
you need to follow those supplied IDs back to the original per-wave files.

This is not redaction. Formula-looking values remain unchanged text here, but
spreadsheet software may interpret them. Review the entire bundle before sharing.
Access, restrictions, origin and capture time are operator declarations.

## Bounds and recovery

CSV input must be UTF-8, comma-delimited and at most 32 KiB, with 1–31 unique
nonblank headers and at most 512 data records. Quoted commas, quotes, multiline
cells and an optional initial UTF-8 BOM are supported by the existing parser.
The reserved output header `consolidation_source_record`, including surrounding
whitespace variants, must not already exist. The extra column keeps output
within the ordinary explorer's 32-column limit.

Plans are at most 16 KiB and must contain exactly the demonstrated fields.
Unknown fields, missing permissions, malformed CSV, ambiguous headers and
duplicate JSON keys are refused. Each derived CSV and provenance file must fit
32 KiB independently. Therefore some inputs below the row and input-byte limits
still need to be split into smaller datasets; preview reports those capacity
blockers before conversion. The same key spread across separate batches will
not be consolidated across those batches.

Validation and serialization finish before the destination directory is made.
Existing directories, files and symlink destinations are refused. After an I/O
failure, inspect the partial directory, retain it if needed, then retry to a
different new directory. No automatic cleanup, overwrite or rollback is claimed.

## Verification scope

`scripts/test_csv_consolidate.mjs` has 12 focused tests. Set
`MOONFIND_CONSOLIDATE_EVIDENCE` to a retained directory and
`MOONFIND_RETAINED_UI` to the accepted R704 compiled production explorer
(`831f79da21c3b3d27fb456a8d67c46a176584c14b27a6932af052f697b1ebb0e`),
then run `node --test scripts/test_csv_consolidate.mjs`.

Tests cover group/conflict preview, both keep policies, duplicate/empty-key
blockers, composite-key collisions, case/Unicode/whitespace/number-like values,
multiline fields, original and earlier-append lineage, strict input/plan/output
bounds, manifests, real CLI conversion and retry refusal. The compiled production
`Imported`, `SearchColumn`, `Filter`, `SelectMatching` and `csv_extract_text`
functions execute against the new output. Source pins are checked against
`fixtures/retained_ui_inputs.json` before using that retained consumer.

The production intake response is supplied as JSON by this test and the browser
bootstrap is omitted. This does not qualify native host intake, browser mounting,
installed saving/reopening, providers, scientific correctness or full release.
No `.mbt` or `.mbti` source changes are needed for this local adapter.
