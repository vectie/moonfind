# Inspect a field inside each JSON evidence record

Interview exports and observations often put useful evidence inside an object
such as `interview.outcome` or the first item of a `visits` array. The brief
explorer now lets you inspect one exact nested field across the source records,
then use the existing record selection and export controls. You do not need to
flatten the data or rewrite it as CSV. This also works on JSONL/NDJSON captures.

The existing [top-level field coverage](JSON_FIELD_COVERAGE.md) remains useful
for discovering fields. The new lens accepts an explicit relative JSON Pointer,
including a field absent from every record. It reuses the same lossless source
parser as [JSON evidence exploration](JSON_EVIDENCE_EXPLORER.md).

## Try the synthetic interview observations

1. Open `/apps/moonfind/briefs` and use **Choose local files** to load
   [`fixtures/json-nested-field.json`](../fixtures/json-nested-field.json).
   Select its source slot, enter `/observations` in **JSON Pointer to array**,
   then choose **Explore JSON array**.
2. Open **Inspect a nested JSON field**. Enter `/interview/outcome` in
   **Field pointer relative to each record** and choose **Inspect nested field**.
   Seven rows show original record locators, requested value pointers, the
   resulting kinds and values. Each present value also exposes its exact JSON
   token, so decoded string text and original escape spelling can both be read.
3. The categories are missing 2, blocked 1, null 1, empty-string 1, string 1,
   boolean 1, and zero in number, array and object. Choose
   **Replace selection: missing · 2 / 7**. Records 4 and 7 are selected and the
   main search is cleared. They have no outcome member or no interview member.
   Record 5 is separately blocked because its interview is null.
4. Use **Preview selected JSON extract** and its existing download or
   **Add selected JSON records to brief** action to retain the original records
   with capture provenance. Use **Preview selected raw NDJSON records** when a
   line-oriented downstream tool needs plain objects instead. The selection
   contains complete records, including every other field.
5. Inspect `/interview/count` to see the exact `9007199254740993` and `-0` numeric
   tokens. Inspect `/visits/0/duration` to compare the first visit only: record 1
   has `1.2300`, record 3 has the string `not timed`, and the rest are missing.
   Inspecting a different pointer does not itself replace the existing selection.
6. Save/reopen through the existing brief controls after adding an extract when
   the chosen records need to persist. The original capture remains unchanged.
   The temporary lens and selections reset on save/reopen. The saved extract can
   itself be explored at `/records` with a field pointer such as
   `/record/interview/outcome`.

For JSONL, use **Import JSONL / NDJSON file** or **Explore loaded JSONL lines**
first. A lens row retains the original one-based physical source line and the
one-based record number. Its value pointer is relative to the object on that
line. For JSON arrays, the value pointer includes the selected array pointer and
zero-based source record index, such as `/observations/0/interview/outcome`.

## Exact pointer and category semantics

- Start a field pointer with `/`. Escape literal `/` in a member name as `~1`
  and literal `~` as `~0`. `/` selects an empty member name. Empty input asks you
  to provide a field; it does not inspect the whole record. URI-fragment
  notation, wildcards, recursive descent, dotted paths and schema inference are
  not supported.
- An object key is literal, including numeric-looking, empty, Unicode or
  prototype-like names. An array needs a zero-based index with no leading zeroes.
  Only the named position is inspected; arrays are not expanded into rows.
- **Missing** means an object member or valid array position along the requested
  path is absent. **Blocked** means traversal encountered a scalar/null parent
  or an array segment that is not a readable index, such as `-`, `01` or a word.
  The full requested pointer does not resolve in either category. It is labelled
  as requested, not asserted to be an existing evidence location.
- A resolved `null`, empty string, nonempty string, number, boolean, array or
  object is its own category. Whitespace-only strings are nonempty; zero, false,
  `[]` and `{}` are present values. Missing and blocked rows have no source token.
- Each record appears once in the lens and once in exactly one category. Counts
  cover all explored source records, even when the main table has a search.
  Repeated objects stay separate records in original order. Every category
  replaces selection; a zero-count category clears it. Individual row buttons
  use the same existing record selection as the main table.
- Original JSON tokens are displayed and exported without floating-point
  rewriting. Other JSON tools may still round large numbers or overflow
  exponents. Strings show decoded text and an expandable exact source token.

Editing the field pointer clears the old lens while keeping the existing record
selection. Switching source, changing the array pointer or exploring the source
again clears the lens through the existing explorer lifecycle. Replacing or
removing a source invalidates its explorer; pending host requests pause actions.
A malformed pointer is repairable and cannot show a partial lens. Source/array
selection and original bytes are never changed by inspection.

The existing 32 KiB source, 512 object-record, 32 top-level-field and 32-level
nesting limits still apply. The field pointer has its own 1,024-UTF-16-unit
limit. Empty arrays can be inspected and return nine zero-count categories.
Duplicate object keys are still rejected by the shared source parser. There is
no automatic path discovery, cross-source join, field redaction or exported
lens-summary file. For exact scalar conditions across one or two field paths,
use the separate [JSON evidence cohort](JSON_EVIDENCE_COHORTS.md) controls.

All original/private fields remain in selected records and the complete dossier.
Review before sharing. Source HTML, URLs and instructions remain inert text.
This is local evidence preparation, not truth review, a completeness score,
source-rights approval, accepted research or proof of customer demand. A browser
download request is not proof that a file reached disk.

## Focused qualification

Run from the repository root:

```sh
node --test scripts/test_json_nested_field.mjs scripts/test_json_field_coverage.mjs scripts/test_json_evidence_ndjson.mjs
```

R484 ran 60 focused Node checks: 16 nested-field checks and the 44 existing
coverage/NDJSON regressions. Executed code is extracted directly from the
production JavaScript externs, covering intake, nested projection, disjoint
categories, exact values/locators, selected-original NDJSON output and reimport.
Four separately named source-wiring checks across the three files inspect
MoonBit UI/reducer connections; they do not execute those connections. Existing
NDJSON tests exercise Blob bytes and a controlled DOM download boundary.

MoonBit wrappers, reducers and rendering were not compiled or executed. No
graphical browser, file chooser, real disk download, native host save/reopen,
provider or full-product qualification was run. Dependencies remain unavailable;
no install, substitution, network, Chromium retry or Moon command was attempted.
This focused result does not advance cumulative R50 qualification or the
separate R51–55 tracks.

PRD rationale: MOONFIND-UC02/B02 calls for inspectable JSON source intake and
provenance, and R02 keeps missing evidence explicit. This closes nested source
inspection within the existing brief workflow without claiming completion of
the broader configured-provider or scientific-comparison journeys.
