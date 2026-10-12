# Download a reusable CSV extract

The local-corpus explorer can download a table containing only the rows and
columns you choose. Use it for a spreadsheet, a follow-up analysis, or a small
evidence table without manually copying cells out of the brief's selection JSON.
This is a local file output; it does not call a model or submit a research job.

## Try the synthetic research table

1. Open the brief studio at `/apps/moonfind/briefs`. Under **Explore a local CSV
   corpus**, import [`fixtures/csv-extract.csv`](../fixtures/csv-extract.csv).
   Existing CSV intake uses the local MoonFind host.
2. Search `CLINIC` in column `segment` and click **Select all matching rows**.
   Source records 2 and 4 are selected.
3. Toggle output columns `segment` and `private` off, leaving `id` and `note`.
4. Under **Download a reusable CSV extract**, leave **Rows in CSV download**
   at **Selected rows, including hidden selections**. The preview shows two
   data rows and two output columns.
5. Change the search to `library`. The main table now shows record 5; the CSV
   preview still shows your selected records 2 and 4.
6. Click **Download CSV extract**. Open `moonfind-csv-extract.csv` with a text
   editor, or import it into a spreadsheet with every column set to text.
   The CSV contains only `id` and `note` for records 2 and 4. It has no `private`
   or `segment` column, original-file bytes, or source metadata attached.
7. Change the download scope to **Rows matching the current search** for record
   5, or **All source rows** for all four rows. Check the live preview before each
   download. Scope is separate from numeric-summary scope.

The supplied table is synthetic. Its observations and formula-like example do
not establish customer demand or scientific truth. No link in it is fetched.

## File semantics

- UTF-8 CSV, comma-delimited, no BOM, CRLF record separators, final CRLF.
- Every header and field is double-quoted; every embedded quote is doubled.
- Cell strings are preserved, including leading zeroes, spaces, empty cells,
  Unicode, and CR/LF line breaks inside cells. There is no numeric/date inference.
- Original row and column order is preserved, regardless of selection order.
  Duplicate selection IDs do not duplicate output rows. Distinct identical
  source rows are still separate rows.
- Selected scope includes selected rows hidden by search. Matching scope uses
  the current literal, case-insensitive search and its chosen search column.
- An empty scope downloads a header-only CSV. No output columns produces a
  repairable message and no download. Importing a new table resets scope to
  selected, clears row selection, and chooses all output columns.
- Preview source record numbers are inspection aids, not extra CSV columns.
- Import limits remain 32 KiB, 32 columns and 512 data rows. Quoting every field
  may make output larger than its input; reimport still requires meeting the
  existing 32 KiB intake limit.

CSV quoting does not stop spreadsheet formula execution or automatic type
conversion. Formula-like strings are preserved exactly. Import every column as
text, especially for unfamiliar evidence. The in-app preview escapes HTML and
does not run cell contents.

This download excludes unchosen cells, but it does not scrub sensitive text
inside chosen cells. Inspect the preview and downloaded file before sharing.
The file is a reserialized extract, not a byte-exact source snapshot, and carries
no origin/digest/provenance metadata. Keep the original when you need that trail.

## State and recovery

The explorer and download scope are session-only. Downloading neither adds the
extract to a brief nor saves the brief, and a browser click is not proof that a
file was saved to disk. On a download failure, the table, search, selections and
brief remain available for retry. Actions are ignored while intake/save is
pending; stale import replies cannot change a newer brief.

**Add selected evidence rows to brief** remains a separate operation: it adds
the selection JSON and the complete original source, including unselected cells.
See [CSV evidence tables](CSV_EVIDENCE_TABLES.md) for that retained-source path.

## Focused acceptance boundary

R291 validates compiled JavaScript through normal UI messages, rendered control
markup, exact real Blob contents and an independent CSV artifact parser. It does
not claim a fresh native intake run, a graphical browser picker/download test,
spreadsheet-app behavior, or a provider-backed research delivery. The import
response in the focused tests is a supplied local fixture. Cumulative product
qualification remains R50.
