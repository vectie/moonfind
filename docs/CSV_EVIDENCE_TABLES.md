# Explore a CSV evidence table

Use a local observation, interview or comparison table to prepare an evidence
subset for a research brief. No gateway, model or remote source is required.
This prepares the supplied evidence; it does not validate the observations or
produce a research answer.

## Try the included synthetic interviews

1. Open `/apps/moonfind/briefs` and complete the question, objective, audience,
   decision, requested filenames and acceptance criteria.
2. In **Explore a local CSV corpus**, choose **Import CSV table** and select
   [`fixtures/local-evidence.csv`](../fixtures/local-evidence.csv).
3. Search `CLINIC`. Searching all columns finds three rows. Set **Search in
   column** to `segment` to see only the two clinic rows.
4. Click **Select all matching rows**. Source records 2 and 4 are selected.
   You can toggle individual rows or clear all selections. Changing the search
   never discards selections, including rows now hidden by the filter.
5. Deselect output columns `segment` and `cost`. The selected-row extract will
   contain `id`, `observation` and `confidence`, in original column order.
6. Click **Add selected evidence rows to brief**, then save the brief. The saved
   source list contains the complete original CSV and `csv-selection.json`.
7. Reopen the saved revision. Its selected evidence table is visible. Download
   the brief Markdown or complete dossier ZIP. The Markdown includes the chosen
   table; the ZIP also includes the byte-exact original and JSON selection.

The synthetic result preserves a reported slow handoff alongside a conflicting
fast handoff. The next useful research step is a timing experiment; importing
these invented rows is not evidence about real customer demand.

## What is retained

- Original file name, origin, supplied capture time and exact original bytes.
- A digest-linked selection with the original data-row count, original one-based
  column positions, header names, source record numbers and cell strings.
- Original row and column ordering, even when selections were clicked in a
  different order. Repeated selections do not duplicate rows or columns.
- Leading zeroes, empty cells, quoted commas, quotes and multiline values.

Record 1 is the header. The first data record is 2. A multiline quoted cell is
one field in one logical record, so record numbers are not physical line numbers.

The entire original source remains in the dossier, including unselected rows
and columns. Projection is an editing aid, not redaction. Review the complete
source set before sharing it. Cell formulas, HTML and URLs remain text; they are
not evaluated or fetched.

For a separate reusable table containing only chosen cells, use the
[CSV extract download](CSV_EXTRACT_DOWNLOADS.md) controls. That download supports
all, current matching, or selected rows with the chosen output columns and does
not embed the original CSV. It does not change the retained-source behavior above.

## Supported format and limits

Use UTF-8 `.csv` with comma delimiters and unique nonblank header names. Optional
BOM, CRLF, LF, CR, double-quoted fields and doubled quote escapes are supported.
Every data record must have the header's number of fields. Unsupported quoting
or ragged rows return a repairable error without adding sources to the brief.
For another delimiter, export comma-delimited CSV first. There is no automatic numeric inference, source-row sorting or cell editing in
this workflow. Explicit numeric-column count/min/max/sum/mean with source-record
drill-down is available in [Numeric summaries](CSV_NUMERIC_SUMMARIES.md). Exact
text-category counts are described in [Category counts](CSV_CATEGORY_COUNTS.md).

The importer accepts at most 32 KiB, 32 columns and 512 data rows. Search is a
case-insensitive, trimmed literal substring in all fields or one column. The
selected JSON must also fit 32 KiB; select fewer rows or columns if it exceeds
that size. Each added table uses two of the existing eight source slots. The
brief's existing 128 KiB total limit still applies. Pre-add exploration is
temporary; add the selection and save to retain it for reopening.

## Local API

`POST /api/v1/briefs/csv/intake` accepts `source` (the existing brief source
object), `query` and `column_number` (0 for all fields, otherwise one-based).
It returns the original source, column names, matching rows and full data-row
count. Use an empty query to obtain all rows for local exploration.

`POST /api/v1/briefs/csv/select` accepts the same `source`, `record_numbers` and
`column_numbers`. It re-parses the original input and returns two ordinary brief
source inputs. Pass those to the existing brief save endpoint. The selection
contract is `moonfind.csv-selection.v1`; it makes no evidence-quality claim.
