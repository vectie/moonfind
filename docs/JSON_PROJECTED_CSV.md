# Take selected JSON fields into a spreadsheet

The local brief explorer can export a selected set of JSON or JSONL records as
CSV with explicitly chosen nested fields. This closes a different output need
from the existing JSON/NDJSON exports, which include every original field. It
uses the same source intake, record selection and nested JSON Pointer lens.
No model, endpoint, provider, source edit or standalone CLI is introduced.

## Try the synthetic observations

1. Open `/apps/moonfind/briefs`. Load
   [`fixtures/json-projected-fields.json`](../fixtures/json-projected-fields.json)
   through **Choose local files**, select its source slot, enter `/observations`
   and choose **Explore JSON array**.
2. Search `clinic` and choose **Select matching JSON records**. This selects
   records 1, 3, 4, 5 and 6. The school record is omitted. Existing cohort, field
   coverage or value-pair selection works too.
3. Open **Project selected JSON fields to CSV**. Set **CSV field pointers (JSON
   array)** to `["/site","/interview/outcome","/metrics/count"]`.
4. Inspect the live CSV preview: five records and three projected fields, with
   two explicitly prefixed cells. The original record numbers and pointers are
   retained. Record 1's numeric token is exactly `9007199254740993`. Record 3's
   formula-like outcome and negative-zero token have reversible apostrophe
   prefixes. These observations are invented examples, not findings.
5. Inspect kinds: record 4's outcome is `blocked` because its parent is null,
   while its count is explicitly `null`. Record 5 has two `missing` paths.
   Record 6 has an `empty-string` outcome and a `string` count, `0012`.
6. Choose **Download selected projected CSV** for
   `moonfind-selected-fields.csv`. The `private_note` sibling field and school
   record do not appear. Use your spreadsheet's CSV import flow and explicitly
   import value columns **as text** to preserve IDs, dates and number spellings.
   Opening by double-click can change values through automatic type detection.
7. Keep the original dossier, or separately download the existing provenance
   JSON extract, when you need source name, origin, capture time or recorded
   digest. This CSV contains locators, not a provenance envelope or saved brief
   artifact. Downloading does not add the CSV as a source or save it to the host.

For JSONL, use the existing import or **Explore loaded JSONL lines** controls,
then the same record-relative pointers. The CSV retains physical source-line
numbers including gaps from blank lines. The array pointer is not used for JSONL.

## Columns and exact value semantics

The first columns are `source_record`, `source_line`, `source_pointer`.
`source_record` is always one-based. For JSON arrays, `source_pointer` identifies
the original record and `source_line` is empty. For JSONL, `source_line` is the
one-based physical line and `source_pointer` is empty. All selected rows are
included in original order, including selections hidden by search. Repeated
identical source records remain separate; the original source is never edited.

Every requested pointer adds three columns in the specified order:

- `<pointer> value`: decoded text for strings; the exact original JSON token for
  number, boolean, null, array or object; empty text for absent or blocked paths
- `<pointer> kind`: `missing`, `blocked`, `null`, `empty-string`, `string`,
  `number`, `boolean`, `array` or `object`
- `<pointer> encoding`: `literal` or `apostrophe-prefix`

A missing path, blocked traversal, explicit null and empty string cannot be
conflated when the kind column is retained. Empty objects and arrays are present
values. No coercion, inferred units, flattening or statistical calculation occurs.
Strings lose their original JSON escape spelling because CSV contains their
decoded text; nested container cells retain original inner JSON tokens and
whitespace, including large numbers and string escapes.

CSV bytes are UTF-8 without a BOM. Every cell is double-quoted, embedded double
quotes are doubled, and record separators are CRLF with a final CRLF. Commas,
Unicode and embedded line breaks remain within the quoted cell. Some spreadsheet
importers need an explicit UTF-8 setting. CSV quoting does not control numeric or
date interpretation: import value columns as text, and retain the original JSON
when another application needs exact source tokens.

### Reversible spreadsheet-sensitive text encoding

A value beginning with `=`, `+`, `-`, `@` or an apostrophe, including after ASCII
spaces/control characters, gets one leading apostrophe. A value beginning with
an ASCII/C1 control character also gets one. Its encoding column says
`apostrophe-prefix`; other values say `literal`. Negative numeric tokens therefore
also receive a prefix. This avoids silently changing which source value was
exported: a programmatic consumer can remove exactly one first apostrophe only
when the encoding column says so. A naturally leading apostrophe is preserved
behind the added one.

Removing the prefix can restore an active spreadsheet formula. Do not remove
prefixes and then open untrusted values as formulas. Spreadsheet behavior varies;
this bounded mitigation is not qualification of Excel, Numbers or Google Sheets,
or a universal formula-execution guarantee. Quoting alone is insufficient. The
preview is inert text; source strings and URLs are never followed or executed.

## Scope, limits and retention

Choose one to eight distinct nonempty JSON Pointers as a JSON array, not one
pointer per line. This permits literal whitespace/newline field names using JSON
escapes. `/` selects an empty member name; `~1` encodes `/`, and `~0` encodes `~`.
Pointers are relative to each record; the empty root pointer is excluded to avoid
implicitly exporting the entire record. Field order is explicit. Arrays use
normal shared-lens index rules and are not exploded into additional rows.

Existing 32 KiB capture, 512-object-record, 32-top-level-field and 32-level nesting
limits apply. Each pointer is at most 1,024 UTF-16 units. Duplicate object keys,
invalid pointers/configuration, no selected records, stale selection or mismatched
source projections return a repairable error without partial CSV. The generated
file is limited to 1 MiB with no sampling or truncation. Eight fields produce
27 columns, including the three locators and eight value/kind/encoding triples.

Selection and source changes update the preview directly; no old preview can be
downloaded. Editing field settings preserves selection. Switching source,
reopening/saving a brief or starting a new brief resets temporary settings through
the existing explorer lifecycle. Re-exploring the same source or changing the
array pointer clears selection but keeps the field settings. Pending host actions
block edits/downloads. A browser download request does not prove a disk save.

Only chosen fields appear in this file, but selecting a container includes **all
its descendants**, including private fields. Locators and chosen text can also be
sensitive. The complete original source remains in the brief and its dossier;
projection is not redaction of that dossier. Review the preview and actual file
before sharing. This does not establish source rights, scientific truth, accepted
research, native persistence or customer demand.

## Verification and PRD relationship

Run from the patched repository root:

```sh
node --test scripts/test_json_evidence_csv.mjs scripts/test_json_value_pairs.mjs scripts/test_json_evidence_cohort.mjs scripts/test_json_nested_field.mjs scripts/test_json_field_coverage.mjs scripts/test_json_evidence_ndjson.mjs
```

R534 ran 107 focused Node checks: 97 executable production-JavaScript checks and
10 explicitly named source-wiring checks. The new file contributes 16 executable
checks and two source-wiring checks. Tests extract the real extern bodies from the
shipped MoonBit files. They execute existing JSON/JSONL intake, nested projection,
selection-to-CSV serialization, real local file write/reopen with an independent
CSV parser, exact UTF-8 Blob bytes and a controlled DOM download boundary.

Source-wiring checks inspect the MoonBit controls and reducer calls. They do not
compile or execute MoonBit wrappers, reducers or rendering. Native host
save/reopen, the graphical browser and file picker, actual browser disk download,
spreadsheet application import, configured provider execution and full-product
acceptance remain unqualified. No dependency install/substitution, network,
Chromium retry or Moon command was attempted. R50 remains the last fully verified
cumulative checkpoint; R51–55 remain separate.

PRD rationale: the actual `MoonFind_PRD.docx` UC02/B02 calls for inspectable local
JSON evidence and provenance; UC04/B04 calls for openable files. This bounded
output connects selected nested source values to a useful spreadsheet workflow,
with explicit unavailable-value kinds and source locators. It neither completes
the broader delivery-manifest acceptance gate nor claims a provider research run.
