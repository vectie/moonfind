# Correct specific cells in a local CSV working copy

Use this companion when a particular observation has a known transcription
error. Choose individual logical records and exact column names. Each correction
requires the expected old string and an explicit replacement. Another cell with
the same value is left alone. MoonFind does not infer which observation is right.

Requires Node 20+, no dependencies. From the repository root:

```sh
node scripts/csv_correct.mjs inspect --csv fixtures/cell-corrections.csv
node scripts/csv_correct.mjs preview --csv fixtures/cell-corrections.csv --plan fixtures/cell-corrections-plan.json
node scripts/csv_correct.mjs convert --csv fixtures/cell-corrections.csv --plan fixtures/cell-corrections-plan.json --out-dir ./correction-bundle
```

1. Inspect the source. Copy the displayed `source_digest` into a new plan and
   choose logical record numbers from `rows`. Header is record 1; data starts at
   record 2. A quoted multiline field is one cell, not multiple records.
2. Copy the sample plan. Supply `record_number`, exact `column`, `expected_old`
   and `replacement` for each intended change. Empty strings are allowed. Values
   are case- and whitespace-sensitive. No numbers, nulls or automatic coercion.
   Enter the source origin, capture time, restrictions and `access: permitted`.
   These are your declarations, not verified licensing or observation facts.
3. Preview all changes and the resulting table. The preview includes old/new
   values, one-based column positions, source and derived logical records and
   output digest. Review the whole table before conversion. A stale source digest
   or mismatched old value refuses both preview and conversion; inspect and
   explicitly review a revised plan rather than discarding the guard.
4. Convert into a new directory. An existing destination is refused. The source
   file is never overwritten; output is `corrected.csv`, plus exact `source.csv`,
   `provenance.json` and a final digest `manifest.json`.
5. In the existing brief studio, choose **Import CSV table** and import
   `correction-bundle/corrected.csv`. Search the `segment` column for `clinic`,
   select matching records, then use the existing selected-row CSV extract.
   The fixture selects records 2 and 5; record 4 deliberately keeps `clinc`.
   The multiline observation at record 3 and empty confidence at record 5 are
   also explicitly corrected. Leading-zero IDs and all other strings remain.

The preview is read-only. Conversion validates the complete plan again; it does
not persist a preview session or grant permission to change a different source.
Replacing the input bytes, even just adding a BOM, requires a new reviewed digest.

## Provenance and safe boundaries

The companion retains the complete original file byte for byte, including BOM,
line endings, unselected rows and private columns. This is not redaction. Review
the whole bundle before sharing it. The derived file quotes every field and uses
CRLF record separators. It preserves row/column order and every unedited cell
string, but does not preserve the source's CSV spelling. Headers, record count
and column count cannot change through this command.

`provenance.json` retains the supplied plan, operator declaration, original and
derived digests, and each corrected cell's old/new string and exact source/output
coordinates. Every unlisted cell has identity lineage: the same logical record
and column, with the unchanged string. `plan_digest` identifies the retained
plan serialized as two-space-indented JSON plus a newline, not original plan
file bytes. Changes are listed in source order and preserve their original
`plan_correction_number`. Corrections are simultaneous; duplicate cell targets
are refused, so one correction cannot depend on another correction's output.

Keep the provenance companion with the working copy. Existing CSV intake and
extract do not automatically load this sidecar or claim that corrected data was
present in the original source. Formula-like strings, HTML and links remain
text here; spreadsheet applications may interpret formulas when opening CSV.

Limits: input, corrected CSV and provenance each at most 32 KiB; plan at most
16 KiB; at most 512 data rows, 32 columns and 512 explicit corrections. Oversized
results refuse without truncation. Input must be valid UTF-8 comma CSV with
unique nonblank headers. Replacement strings must contain valid Unicode.
Unknown plan fields, header edits, out-of-range records, nonexistent columns,
duplicate JSON keys/targets and no-op replacements refuse before writing output.

This is a local Node companion. Tests run the actual CLI and feed its output
through pinned current production CSV import/filter/select/extract reducers.
That test supplies intake JSON and does not mount the browser, call native host
intake or qualify installed persistence, source transport, licensing or a full
research delivery. No network or provider is used.
