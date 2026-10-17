# Pivot long-form evidence into a comparison table

MoonFind turns bounded research sources into inspectable evidence for a decision.
For MOONFIND-UC02 source intake, this adds the inverse of existing wide-table
unpivot: compare respondents or experiments side by side across question/metric
columns. It performs a real local transformation, without provider requests.

From the repository root, with Node 20+ and no extra packages:

    node scripts/csv_pivot.mjs inspect --csv fixtures/pivot-responses.csv
    node scripts/csv_pivot.mjs preview --csv fixtures/pivot-responses.csv --plan fixtures/pivot-plan.json
    node scripts/csv_pivot.mjs convert --csv fixtures/pivot-responses.csv --plan fixtures/pivot-plan.json --out-dir /path/to/new-pivot-bundle

Choose three distinct exact source headers for row identity, output column and
value. Row/column values match exactly as text; leading zeroes and number spelling
are preserved. Rows and columns follow first appearance. Duplicate cells default
to nothing implicitly: the plan must explicitly choose error, first or last.
Error refuses all duplicate pairs; first/last select a source record in input
order, including an explicitly blank value. No numeric aggregation is performed.
All contributing records and the selected record are recorded in provenance.json.

Choose Import CSV table in the existing brief studio and open pivoted.csv. Search
002 in the person column, select matching rows and inspect or extract the result.
Missing cells become empty text, distinguished from observed empty values by the
absence/presence of their provenance cell entry. A blank column value or output
header collision refuses; the row identity may be empty. Keep source.csv and
provenance.json beside the derived CSV when sharing or interpreting it. CSV import
does not automatically ingest the provenance sidecar. Retained originals include
all unused data; this workflow is not a redaction mechanism. Formula-looking text
is preserved: use safe text import before opening it in spreadsheet software.

The original byte-for-byte input, derived CSV, provenance and hash manifest are
written only to a new directory. Existing destinations are refused. Source access
metadata is operator-declared and not independently verified. No external source,
provider, credentials or network is used.

Bounds: source/output CSV and provenance each <=32 KiB, plan <=16 KiB, at most
512 input records and 32 input columns, 31 pivot value columns. Existing parser
rejects malformed UTF-8/CSV, ambiguous headers and ragged rows. Output expansion
or large provenance refuses rather than truncates; select a smaller source first.

Tests:

    MOONFIND_PIVOT_EVIDENCE=/path/to/new-evidence MOONFIND_RETAINED_UI=/path/to/r704/build-ui/js/release/build/main/main.js node --test scripts/test_csv_pivot.mjs

4 tests pass: transform and provenance, duplicate policies, real CLI conversion,
and pinned compiled production Imported/Filter/SelectMatching/CSV-extract reducers.
The consumer SHA and unchanged source pins are checked. Its intake response is
supplied by the test, and browser bootstrap is omitted. No live host, browser,
installed Save/reopen, native rebuild, provider or full release qualification.
Broader failed/unrun release gates remain blocking. No MoonBit source/interface
changed; native check/info/fmt was not run.
