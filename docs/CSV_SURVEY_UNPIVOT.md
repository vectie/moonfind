# Turn a wide survey into question-answer evidence

A local survey or experiment export often stores one respondent/trial per row
and one question/measurement per column. Reshape explicitly chosen cells into
an ordinary long-form CSV, so MoonFind's existing CSV explorer can search,
compare and select answers across questions without manually copying cells.
This dependency-free Node 20+ CLI runs offline. It prepares supplied data; it
does not assess research quality, customer demand or statistical significance.

## Inspect, choose, preview, convert

From the repository root:

```sh
node scripts/csv_unpivot.mjs inspect --csv fixtures/survey-wide.csv
node scripts/csv_unpivot.mjs preview \
  --csv fixtures/survey-wide.csv --plan fixtures/survey-unpivot-plan.json
node scripts/csv_unpivot.mjs convert \
  --csv fixtures/survey-wide.csv --plan fixtures/survey-unpivot-plan.json \
  --out-dir ./survey-evidence-bundle
```

Create your own plan using `fixtures/survey-unpivot-plan.json`:

```json
{
  "contract_id": "moonfind.csv-unpivot-plan.v1",
  "context_columns": ["respondent_id", "segment"],
  "question_columns": ["handoff_minutes", "handoff_notes"],
  "record_numbers": [2, 3],
  "empty_policy": "keep",
  "source": {
    "origin": "Describe the source of this local export",
    "captured_at": "Supply its actual capture time without guessing",
    "restrictions": "Describe applicable source-use restrictions",
    "access": "permitted"
  }
}
```

Each choice is explicit. Use exact header names and unique logical data record
numbers. Header is record 1; quoted multiline fields do not increment the record
number. Context may be empty. At least one question and one data record are
required; context/question selections cannot overlap. Missing columns, duplicate
selections, unknown keys/contract versions and duplicate JSON keys fail closed.
Source access must explicitly be `permitted`; denied or unavailable input is
rejected, and supplied restrictions are preserved rather than inferred.

The fixture selects records 2 and 3, each with two questions, producing four
rows. Both respondents have label `001`; they remain separate observations
because source record and question-column position identify the cell. The
blank `handoff_minutes` response remains blank. The quoted multilingual note
retains its embedded newline, comma and quotes. No formula is evaluated.

The plan may list records/columns in any order. Output always follows original
record order, then original question-column order; context columns likewise
follow source order. The preview displays every output row, omitted empty cells,
unselected records, unused columns, restrictions and byte sizes.

## Continue in the existing CSV explorer

1. Open `/apps/moonfind/briefs` and complete the brief's decision, objective,
   audience, source scope, requested files and acceptance criteria.
2. In **Explore a local CSV corpus**, choose **Import CSV table** and select
   `survey-evidence-bundle/answers.csv`.
3. Search `handoff_minutes` in column `question`. The fixture shows two responses:
   `12` and empty. Numeric summary on `answer` using **Current matching rows**
   counts one numeric and one blank value. Do not mix unrelated questions or
   units in a numeric summary. Category comparison on `context:segment` can
   compare the supplied responses with original locators visible in every row.
4. Select useful rows and choose **Add selected evidence rows to brief**. This
   retains `answers.csv` and the ordinary native `csv-selection.json`.
5. Use **Choose local files** to add the bundle's `source.csv` and
   `provenance.json`, and carry the restrictions into the brief. Save the brief.
   Those four captures preserve the original and conversion trail beside the
   selected evidence. Reopen/export use the existing native pipeline.
6. Keep `manifest.json` locally for byte verification. Importing it is optional
   and uses a fifth source slot. Inspect the complete original before sharing.

Only importing `answers.csv` would omit the original and mapping trail from the
saved dossier. Companion files are not automatically attached by this CLI. The
existing native pipeline has eight source slots, 32 KiB per capture and 128 KiB
total. Native selection JSON has its own size bound; select fewer rows if needed.
The CLI itself does not call native endpoints, save a brief or claim UI delivery.
See [CSV evidence tables](CSV_EVIDENCE_TABLES.md),
[numeric category comparisons](CSV_CATEGORY_COMPARISONS.md) and the existing
[CSV joins](CSV_EVIDENCE_JOIN.md) for subsequent exploration.

## Exact output and omission semantics

- `source.csv`: byte-exact original, including BOM, line endings, all unselected
  records and unused/private columns. Original filename is retained in metadata.
- `answers.csv`: fully quoted CRLF CSV. Columns are `source_record`,
  `source_column`, each selected `context:<original header>`, `question`, `answer`.
  Context values and answer strings are copied exactly. Question is the exact
  original header. Logical source locators are decimal one-based positions.
- `provenance.json`: source origin, capture time, restrictions, supplied access,
  digest/size/header list; exact validated plan; source-to-context header mapping;
  digest/size/columns for the derived CSV; and compact row-map tuples. The
  `row_map_columns` array labels each tuple as output record, source record,
  source question column. Explicit arrays record omitted empty cells, unselected
  source records and unused source columns.
- `manifest.json`: exact sizes and SHA-256 identities of the three files above.
  It is written last; `complete` describes local bundle construction only.

`keep` retains every chosen cell, including exactly empty and whitespace-only
answers. `omit-empty` removes only the exact empty string and records its source
cell position; spaces, tabs, newlines and literal `0` remain. Missing/ragged cells
are rejected, never filled. An entirely empty result is rejected with advice to
retain empties or choose other cells. No answer splitting, ID uniqueness rule,
normalization, imputation, scoring, date/number conversion or inference occurs.
Blank and repeated respondent labels are allowed because they are not identities.

The original includes all hidden/private cells; this bundle is not redaction.
Formulas, HTML and URLs are inert text here. Spreadsheet software may execute
formula-looking text on opening a CSV; import all columns as text when using
other tools. No URL, API, provider, gateway or remote source is contacted.
Metadata and byte identity do not prove access rights, authenticity or truth.

## Bounds and interruption behavior

Input must be a local regular `.csv` file, UTF-8, 1–32 KiB, at most 32 columns
and 512 data rows. Commas, optional BOM, CRLF/LF/CR, quoted newlines and escaped
double quotes are supported. Invalid UTF-8/quoting, blank headers and duplicate
or ambiguous headers (including whitespace/NFC collisions) are refused rather
than renamed or merged. Input bytes are never edited. Plans are at most 16 KiB.

Selected records × selected question columns must be at most 512, even when
omitting empty cells would produce fewer rows. The expanded column count
(context plus four) must be at most 32. Expanded CSV UTF-8 size is counted before
allocating the output table/string; each generated capture must fit 32 KiB.
Reduce the selected records, questions or repeated context fields if over limit.

Conversion validates all input/output bounds before creating a new private
output directory. Existing files/directories/symlinks are refused; no overwrite
or cleanup option exists. If writing is interrupted, keep the partial directory
for inspection and retry into a different new directory. Missing final manifest
means incomplete output. A manifest is not a filesystem durability guarantee;
verify file digests after transferring/copying the bundle.

## Verification boundary

```sh
MOONFIND_CSV_TEST_DIR=/your/private/evidence \
  node --test scripts/test_csv_unpivot.mjs
```

Tests execute the actual Node converter/CLI, independent CSV decoding, exact
fixture comparison, 60 deterministic multiline/Unicode corpus roundtrips,
cell lineage, size limits, denied input, immutable inputs, no-overwrite and
nonblocking FIFO rejection. A downstream test feeds the result through the
actual production CSV-join JavaScript FFI and checks retained locators. This is
a connected JavaScript contract test, not a native parser/UI execution claim.

Native intake/select/save/reopen/dossier export, installed browser/OS picker,
complete native/UI builds and full release/provider gates remain unrun and
blocking. This bounded development workflow does not close those qualification
gates or assert a completed research answer.
