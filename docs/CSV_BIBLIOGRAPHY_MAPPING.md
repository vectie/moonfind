# Explicit local CSV bibliography mapping

A researcher with a local bibliography CSV can now turn selected records into
ordinary CSL JSON without first exporting through a reference manager. This is
a small, dependency-free **Node 20+ CLI**, not a new native/browser intake panel.
The local conversion runs no provider, DOI lookup, URL fetch or citation service.

## Inspect, map, preview, convert

From this repository, inspect the included synthetic source:

```sh
node scripts/csv_bibliography.mjs inspect --csv fixtures/csv-bibliography.csv
```

Inspect prints exact header names and logical source record numbers. Header is
record 1; the first data row is record 2. A quoted multiline cell is one record.
Use `fixtures/csv-bibliography-plan.json` as an example and create your own plan:

```json
{
  "contract_id": "moonfind.csv-bibliography-plan.v1",
  "mapping": {
    "sourceID": "source_id",
    "title": "title",
    "type": "item_type",
    "literalAuthor": "author_text",
    "issuedText": "issued_text",
    "venue": "venue",
    "DOI": "doi",
    "URL": "url",
    "abstract": "abstract"
  },
  "record_numbers": [3, 2],
  "source": {
    "origin": "Describe where this local CSV came from",
    "captured_at": "Supply the source capture date/time without guessing",
    "restrictions": "Supply the applicable source-use restrictions"
  }
}
```

Every mapping choice is required. Map `sourceID`, `title` and `type` to distinct,
exact header names. For each remaining field, choose an exact header or explicitly
use JSON `null` to omit it. An absent column is an error, never an automatic guess.
One column cannot supply two mapped fields. `record_numbers` must explicitly list
unique data records. The output follows original source order even if selection
order differs. Source attribution, capture time and restrictions are supplied by
the researcher; the CLI does not verify them or infer a retrieval history.

```sh
node scripts/csv_bibliography.mjs preview \
  --csv fixtures/csv-bibliography.csv \
  --plan fixtures/csv-bibliography-plan.json

node scripts/csv_bibliography.mjs convert \
  --csv fixtures/csv-bibliography.csv \
  --plan fixtures/csv-bibliography-plan.json \
  --out-dir ./my-bibliography-bundle
```

Read the preview before converting. It contains every selected reference, the
original and CSL record numbers, missing/unmapped fields, availability labels,
unselected source record numbers, unmapped columns and output sizes. The example
selects source records 2 and 3; they become CSL records 1 and 2. The second record
has no abstract and is labelled `metadata-only`. Its 16-digit ID stays a string.

Use a new output directory each time. Existing files, directories and symlinks
are refused; there is no overwrite switch. All conversion validation happens
before creating it. If a filesystem failure interrupts writing, retain the
partial directory for inspection and retry into a different new directory.
Only a final `manifest.json` marks a fully written bundle. The CLI never cleans
up previous output or edits either input file.

## What the bundle retains

- `source.csv`: the byte-exact original, including BOM, line endings, unmapped
  columns and unselected rows. Its original filename is in provenance.
- `references.csl.json`: an ordinary nonempty array of CSL reference objects.
- `provenance.json`: source filename, origin, supplied capture time, restrictions,
  SHA-256 digest, byte count, full header list and source data-record count;
  explicit field-to-header/one-based-column mapping; requested selection order;
  each output reference's CSL record, original CSV record, string ID,
  availability and omission reasons; unselected records/unmapped columns; and
  the derived CSL file's digest and byte count.
- `manifest.json`: sizes and SHA-256 digests of those three files, plus limits
  on what this local conversion establishes. The manifest does not assert
  native intake, scientific validity or release readiness.

The complete original stays with the derived references. Projection is not
redaction. Unselected rows, private curator notes and other unmapped cells are
still in `source.csv`; review the complete bundle before sharing it. Spreadsheet
formulas, markup, DOI values and URLs remain literal data and are never executed
or fetched by the converter. Digest identity detects byte changes, not truth.

## Mapping behavior and deliberate limits

| CSV mapping | Emitted CSL field | Rule |
| --- | --- | --- |
| sourceID | id | Exact string; leading zeroes and long numeric-looking IDs stay intact |
| title | title | Nonblank selected title; no invented title |
| type | type | Exact supported type string; no inferred publication type |
| literalAuthor | author[0].literal | One literal value, including a whole supplied author list |
| issuedText | issued.literal | Exact supplied text, including uncertain dates |
| venue | container-title | Exact supplied text |
| DOI | DOI | Exact supplied text; not resolved or validated |
| URL | URL | Exact supplied text; not fetched |
| abstract | abstract | Blank or explicitly unmapped means metadata-only |

No author is split into family/given names and no date/year is parsed or guessed.
Nonblank optional values are preserved unchanged. Blank optional cells are
omitted with a recorded `blank-cell` reason; explicit null mappings use `unmapped`.
Abstract presence means `metadata-and-abstract`, never full text read or verified.

Supported exact type values are `article`, `article-journal`, `book`, `chapter`,
`dataset`, `manuscript`, `paper-conference`, `report`, `thesis` and `webpage`.
Other types require an explicit supported source value before this narrow bridge
can convert them. It is not a general Zotero CSV importer, a complete CSL schema
validator, a citation style engine, or a guarantee of third-party import behavior.

Input CSV must be UTF-8, at most 32 KiB, 32 columns and 512 data rows. Commas,
optional BOM, CRLF/LF/CR, quoted newlines and doubled quote escapes are supported.
Ragged rows, malformed quoting and invalid UTF-8 fail without partial references.
Blank or duplicate headers, including surrounding-whitespace and Unicode-NFC
collisions, are ambiguous and refused. Header lookup is otherwise exact.

All source IDs, including unselected rows, must be nonblank, have no surrounding
whitespace, and be unique after Unicode-NFC comparison. Original values are
never normalized in output. Case-distinct IDs remain distinct. Missing or
ambiguous IDs block the whole conversion; there is no row-number ID fallback.
Plans must be UTF-8 JSON up to 16 KiB with exactly the documented keys; duplicate
JSON keys (including escaped spellings) are refused.

Each derived CSL/provenance capture must fit 32 KiB. Select fewer records if an
output exceeds that limit. Native CSL selection creates another capture with
its own 32 KiB limit; a compact source can still expand into excessive card
metadata. Existing eight-source and 128 KiB total brief limits continue to apply.

## Use the result in the existing MoonFind brief workflow

The existing [CSL JSON workflow](CSL_JSON_BIBLIOGRAPHIES.md) remains the output
destination. In `/apps/moonfind/briefs`, use **Import CSL JSON bibliography** on
`references.csl.json`, inspect/select cards, then **Add selected references to
brief**. This adds the derived CSL file and the native `csl-selection.json`.
Use **Choose local files** to add `source.csv` and `provenance.json` alongside
those cards, and carry the supplied restrictions into the brief. These four
captures retain both source and mapping provenance. Keep the local manifest for
verification; importing it is optional and uses another source slot.

The CLI does not call a native endpoint or save a brief. Only importing the CSL
file would lose the original CSV/mapping trail from the saved dossier, so retain
both companions when following the workflow. Save/reopen/export are the existing
native pipeline, not behavior implemented or executed by this CLI.

## Reproduction and verification status

```sh
mkdir -p /your/private/csv-test-evidence
MOONFIND_CSV_TEST_DIR=/your/private/csv-test-evidence \
  node --test scripts/test_csv_bibliography.mjs
```

The Node tests exercise the production parser, converter and actual child-process
CLI, including exact bytes, provenance, omitted metadata, ambiguous IDs/columns,
limits, invalid plans and no-overwrite behavior. Test directories are retained.
The generated array is compared with an independently authored CSL fixture, whose
values also appear in `research/csv_bibliography_test.mbt`. The latter calls the
real `@research.parse_csl` and asserts literal names/dates and card availability.
The Node source/fixture correspondence check is static, not execution of MoonBit.

For this bounded development slice, the new native parser contract test, native
intake/select/save/reopen/export, installed browser workflow, complete native/UI
build and release suite, provider workflow and native interoperability are
**unrun and remain blocking qualification gates**. No native MoonFind binary was
retained in the constrained environment. These Node checks do not replace them.
