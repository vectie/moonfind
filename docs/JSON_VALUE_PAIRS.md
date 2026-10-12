# Discover observed value pairs in JSON evidence

In a local interview corpus, you may know which fields describe a site and an
outcome without knowing every value they contain. **Compare observed JSON value
pairs** counts the observed combinations and lets you inspect and retain each
combination's original records. It is part of the existing brief explorer,
including its JSONL intake and source-backed extract workflow.

The [cohort selector](JSON_EVIDENCE_COHORTS.md) asks for expected literal values.
This breakdown discovers combinations first. The [nested-field lens](JSON_NESTED_FIELD_LENS.md)
continues to inspect one path's source values and data shapes. No model, provider,
new endpoint or source mutation is involved.

## Walk through the synthetic interviews

1. Open `/apps/moonfind/briefs`. Load
   [`fixtures/json-value-pairs.json`](../fixtures/json-value-pairs.json) using
   **Choose local files**, or paste it using the existing source controls.
2. Under **Explore loaded JSON evidence**, select the source slot, enter
   `/observations` as the array pointer and choose **Explore JSON array**.
3. Open **Compare observed JSON value pairs**. Set the first comparison field
   pointer to `/site` and the second to `/interview/outcome`. Choose
   **Preview observed value pairs**. Do not enter expected values.
4. The preview contains 12 source records and 10 observed value/kind pairs.
   Seven records have two scalar/null values; five have an absent, blocked or
   non-scalar field. The `"school"` / `"unresolved"` pair has two records, while
   `"school"` / `"resolved"` has one. These invented examples are not findings.
5. Expand **Inspect exact source values and locators** for school/unresolved.
   The rows are original records 2 and 5, at `/observations/1` and
   `/observations/4`. The latter retains the original `"sch\u006fol"` source
   token even though both decode to the same site string.
6. Choose **Replace selection with pair 2 (2 records)**. This explicitly
   replaces the whole selection and clears search. Open **Preview selected
   JSON extract** for the existing provenance envelope, or **Preview selected
   raw NDJSON records** when a downstream tool needs one original object per
   line. The NDJSON includes only records 2 and 5, preserving the token
   `9007199254740993` and the original string escape in record 5.
7. To retain the pair in a brief, choose **Add selected JSON records to brief**
   and save using the existing controls. The original full capture stays as a
   separate source. Adding consumes a source slot and clears the selection;
   it does not save the temporary breakdown settings or a count report.
8. You can also select a missing, blocked or non-scalar group to retain records
   needing closer inspection. The clinic/array group contains records 10 and
   11 with different original arrays. Its label says that array contents were
   not compared; the drilldown shows both exact tokens.

For JSONL, use the existing import or **Explore loaded JSONL lines** action and
the same record-relative comparison pointers. Drilldown retains original
one-based physical source lines, including blank-line gaps. Array pointers are
ignored for JSONL; they still identify the source array for ordinary JSON.

## What the counts mean

- Every original object contributes exactly once, including repeated identical
  records. Search and current selection do not restrict the scope. Groups and
  their member records keep first-observed source order. Counts are not ranked.
- Scalar types do not coerce: string `"1"`, number `1`, boolean `true`, and
  explicit `null` remain separate. Strings group by decoded, case-sensitive,
  untrimmed Unicode text. Equivalent JSON escapes group together, but Unicode
  normalization is not performed. The display uses a quoted JSON string;
  drilldown keeps each original source token.
- Numbers group by exact token spelling. `1`, `1.0`, `1e0`, `0` and `-0` are
  distinct; very large integers and exponents never pass through floating-point
  conversion for grouping. These are token counts, not numeric equivalence or
  approximate statistical calculations.
- Missing means the requested member or array position is absent. Blocked means
  a parent shape or invalid array index prevents traversal. Each is separate
  from explicit null, an empty string, false and zero. Nothing is filled in.
- A terminal array or object is non-scalar. Such fields group by their kind,
  not their contents. These kind groups are clearly marked and preserve every
  original value in drilldown; matching a kind never claims equal observations.
- The summary separates records with two scalar/null values from those with
  at least one missing, blocked or non-scalar field. This is a description of
  shape only. Explicit null is a scalar category, not verified evidence.
- Only observed pairs are listed. No Cartesian grid of fabricated zeroes is
  generated, and no absent pair is evidence of impossibility. No percentages,
  significance test, correlation, causal interpretation or recommendation is
  computed. Counts describe this capture, not a representative population.

Choose two different, nonempty JSON Pointers relative to each record. `/` names
an empty object member. Escape `/` as `~1` and `~` as `~0`. Array indexing follows
the shared lens rules; arrays are never exploded into additional observations.
The existing bounds remain: 32 KiB UTF-8 capture, 512 object records, 32 distinct
top-level fields, 32 nesting levels and 1,024 UTF-16 units per pointer. Duplicate
object keys and invalid sources fail before a breakdown. No sample or truncation
is substituted. At most 512 observed groups are produced.

## Selection, retention and qualification

Changing a comparison pointer clears its preview while preserving selection.
Changing source or the source-array pointer clears the explorer table/selection;
re-exploring resets the breakdown. Removing/replacing a source invalidates its
state. Pending host requests pause actions. Unrelated source appends and brief
text changes keep the current breakdown. Save/reopen and a new brief reset the
temporary comparison state. There is no separate count-report download.

Existing selected JSON/NDJSON exports and add-to-brief actions retain every
field of the chosen original records, including private or hidden fields.
The JSON extract provides original locators and source metadata; raw NDJSON
adds no provenance. Host-issued digest/revision identity is retained only for
an unchanged prepared brief under the existing extract rules. No digest is
freshly verified here. A browser download request is not proof of a disk save.
The entire original source remains in the dossier. Review all contents before
sharing; this workflow is not redaction, source-rights approval, truth review,
research completion or proof of customer demand.

Run from a patched repository root:

```sh
node --test scripts/test_json_value_pairs.mjs scripts/test_json_evidence_cohort.mjs scripts/test_json_nested_field.mjs scripts/test_json_field_coverage.mjs scripts/test_json_evidence_ndjson.mjs
```

R519 executed 89 focused Node checks: 81 executable production-JavaScript checks
and 8 explicitly named source-wiring checks. The new file adds 15 executable
checks plus 2 source-wiring checks. Production externs are extracted directly
from the shipped MoonBit source. Pair projection, lossless selected NDJSON
output and reimport are executed; source-wiring checks only inspect that the
MoonBit controls and reducers call the feature and reset its state.

MoonBit wrappers, reducers and rendering were not compiled or executed. Native
host persistence, a graphical browser/file chooser, actual disk downloads,
configured provider execution and full-product acceptance remain unqualified.
No dependency install or substitution, network, Chromium retry or Moon command
was attempted. This result does not advance cumulative R50 qualification or the
separate R51–55 tracks.

PRD rationale: MOONFIND-UC02/B02 calls for inspectable local JSON evidence with
provenance. R02 keeps missing evidence explicit. This closes discovery of
observed combinations within a bounded local source and links them to existing
inspectable source outputs, without claiming the broader research or comparison
requirements are fully qualified.
