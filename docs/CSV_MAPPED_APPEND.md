# Append explicitly mapped local CSV datasets

For MoonFind source intake (MOONFIND-UC02), combine separate survey batches into
one evidence table. This is append, not join or unpivot: each original data row
appears exactly once, even if respondent IDs and values repeat across sources.

Use Node 20+ with no packages or network access. From the repository root:

```
node scripts/csv_append.mjs inspect --csv fixtures/append-east.csv
node scripts/csv_append.mjs inspect --csv fixtures/append-west.csv
node scripts/csv_append.mjs preview --csv fixtures/append-east.csv --csv fixtures/append-west.csv --plan fixtures/append-plan.json
node scripts/csv_append.mjs convert --csv fixtures/append-east.csv --csv fixtures/append-west.csv --plan fixtures/append-plan.json --out-dir /path/to/new-append-bundle
```

Inspect both inputs first. The plan lists output column names and one source
entry per `--csv` argument, in exactly that order. Each source's `mapping` is an
array of exact original header names, aligned with the output column array.
Every output column must be mapped explicitly for every source; there is no
inferred match, missing-column padding, duplicate mapping or implicit coercion.
The IDs must be unique. Supply actual origin, capture time, restrictions and
`access: "permitted"` only when authorized. These declarations are not verified.
The example fixtures are synthetic and must not be treated as research evidence.

Preview the entire candidate table before conversion. Output starts with
`source_id` and `source_record`, then your chosen output columns. The logical
record number counts the header as 1 and does not count embedded newlines as new
records. Rows stay in input order, then original record order. Duplicate IDs,
blank values, Unicode, newlines and formula-looking strings are preserved.

In the ordinary MoonFind brief studio, choose **Import CSV table** and select
`appended.csv`. Inspect the columns, search `west` in the source ID column,
select matching rows and download a selected CSV extract. Keep both provenance
columns selected if the extracted rows must remain traceable. Source IDs resolve
through `provenance.json` to original filenames, digests, origins, capture times,
restrictions and exact mapping. Its row map resolves each output logical record
to its original retained file and record. The bundle includes every original
byte as `source-1.csv`, `source-2.csv`, etc., plus a digest manifest. Include these
files with the brief when distributing derived evidence: importing appended.csv
alone does not automatically import or enforce this sidecar provenance.

The full original files retain unused columns and private data. This is not a
redaction tool. CSV quoting does not neutralize formulas in spreadsheet apps;
MoonFind treats cells as text. Do not open untrusted CSV in a formula-executing
spreadsheet without its own safe-import controls. Conversion refuses an existing
output directory or symlink and does not modify the input files.

## Bounds and qualification

- 2–8 datasets, each 1–32,768 bytes of strict UTF-8 CSV, 1–32 source columns,
  at most 512 source data records; duplicate/blank/normalized-ambiguous headers
  and ragged rows are refused by the shared parser.
- Plan up to 16,384 bytes; 1–30 mapped columns plus two reserved provenance
  columns; 512 combined output records; appended CSV and provenance each at
  most 32,768 bytes. A no-data result refuses. Output expansion refuses rather
  than truncates. Reduce source datasets explicitly if a bound is reached.
- Input basename <=512 characters, source ID/capture text <=80, origin and
  restriction text <=2,000, output header <=512. Exact metadata keys required.
- The retained R704 compiled production explorer reducer imports the supplied
  intake response, filters source ID, selects matching rows and exports them in
  focused Node tests. Its browser bootstrap is deliberately not run. The host
  response is supplied by the test using the shared CSV parser, not a live host.
- No native input changes/builds, browser interaction, host endpoint, installed
  save/reopen or full release qualification. Failed/unrun wider gates remain
  blocking. No external sources or providers are contacted.

Tests require a retained compiled R704 UI and an evidence directory:

```
MOONFIND_RETAINED_UI=/path/to/r704/build-ui/js/release/build/main/main.js MOONFIND_APPEND_EVIDENCE=/path/to/new-evidence node --test scripts/test_csv_append.mjs
```

The test pins the retained binary SHA-256. `retained_ui_inputs.json` records the
unchanged source inputs used by that consumer; review these against the accepted
R704 baseline. This companion CLI intentionally does not modify the native UI.
