# Select a source-backed JSON evidence cohort

A research question often needs the observations for one site **and** one
outcome, rather than every record that happens to contain those words. In the
brief studio, a cohort preview applies one or two exact scalar conditions to
nested JSON fields, shows the evidence behind every result and feeds the
existing record selection. It works with both JSON arrays and JSONL captures.

This differs from the all-field substring search and the
[nested-field shape lens](JSON_NESTED_FIELD_LENS.md): it can distinguish
`/site = "school"` from a note mentioning a school, and combine that condition
with `/interview/outcome = "unresolved"`. The complete source remains unchanged.

## Walk through the synthetic interviews

1. Open `/apps/moonfind/briefs`, choose the local file
   [`fixtures/json-evidence-cohort.json`](../fixtures/json-evidence-cohort.json),
   select its source slot and enter `/observations` as **JSON Pointer to array**.
   Choose **Explore JSON array**.
2. Open **Select a JSON evidence cohort**. Enter `/site` as the first field
   pointer and `"school"` as its scalar JSON value, including the quotes.
   Keep **All conditions must match**. Enter `/interview/outcome` and
   `"unresolved"` for the second condition. Choose **Preview JSON cohort**.
3. The preview covers ten original records: matching 2, no-match 4 and
   unresolved 4. The matching source records are 1 and 8, `school-1` and
   `school-6`. Each preview row shows its original locator, result, individual
   condition outcomes, requested value pointers and exact source tokens.
4. Choose **Replace selection with matching cohort (2)**. This replaces the
   entire selection and clears search. Use **Preview selected JSON extract**
   and its download action when you need the existing source provenance
   envelope. Use **Preview selected raw NDJSON records** and its download action
   when another tool needs original objects, one per line. The numeric token
   `9007199254740993` in `school-6` remains exact.
5. To retain the subset in a brief, choose **Add selected JSON records to brief**
   and use the existing save/reopen controls. The original full capture and the
   added provenance extract remain separate sources. Adding consumes a source
   slot and clears selection; the existing eight-source, 32 KiB per source and
   128 KiB dossier limits still apply. Temporary cohort controls and preview do
   not persist across save/reopen. The added extract can itself be explored at
   `/records` with condition paths such as `/record/site`.
6. To inspect gaps instead, preview again and choose **Replace selection with
   unresolved records (4)**. These are records 4, 5, 7 and 10. Record 4 has no
   outcome member, record 5 has a null interview parent, record 7 lacks a site,
   and record 10 lacks both fields. Their original objects can be exported or
   added using the same controls; no values are inserted or rewritten.
7. Switch to **Any condition may match** and preview again. Eight records
   match, one is no-match, and record 10 is unresolved. A record that definitely
   meets one condition satisfies Any even when the other field is unavailable.

For JSONL use **Import JSONL / NDJSON file** or **Explore loaded JSONL lines**.
The preview retains one-based physical source lines, including gaps for blank
lines, and record-relative value pointers. JSON array locators retain original
zero-based indexes such as `/observations/7/interview/outcome`.

## Exact condition semantics

- One condition is required. The second is optional; leave both second inputs
  empty for a single condition. To remove a second condition, clear both inputs.
  A field value with no field pointer is an error, never a silently ignored rule.
- Each field uses the existing JSON Pointer rules: start with `/`, escape `/`
  as `~1` and `~` as `~0`, and use zero-based array indexes without leading
  zeroes. `/` means an empty member name. No dotted paths, wildcards or recursive
  descent are added.
- Values must be JSON scalars: a quoted string, number, `true`, `false` or `null`.
  Objects, arrays, bare words and empty input are repairable errors. Surrounding
  JSON whitespace is ignored. A value is limited to 1,024 UTF-16 units.
- Strings compare decoded text exactly. `"school"` and `"\u0073chool"` match
  the same text. Case, spaces inside the quotes and Unicode normalization remain
  significant. There is no substring, regular expression or case folding.
- Numbers compare **exact source token spelling**. `1`, `1.0` and `1e0` are
  distinct, as are `0` and `-0`, or `1e0` and `1E0`. Large integers and exponent
  spellings never pass through a floating-point comparison. This is not numeric
  equivalence, arithmetic, a range filter or unit conversion. The numeric
  condition `1` never matches the string `"1"`.
- An existing value of a different type is a definite no-match. An existing
  object or array is therefore no-match for every supported scalar condition.
  Empty strings, false, zero and explicit null remain meaningful values.
- A missing member/array position or blocked parent path is unknown, not null.
  The row retains `missing` versus `blocked` for each condition. **All** is
  no-match if any condition definitely fails, otherwise unresolved if any
  condition is unknown, otherwise match. **Any** is match if any condition
  definitely succeeds, otherwise unresolved if any is unknown, otherwise
  no-match. For one condition the two modes agree.
- The three result groups partition all source records once. Counts ignore the
  main search and existing selection. Repeated objects remain separate records
  in source order. A zero-count replacement deliberately clears selection;
  unresolved selection is separate from the matching cohort.

Editing either condition or its combination mode clears the preview, while
preserving the existing selection until explicitly replaced. Changing array
pointer, exploring again, switching sources or replacing/removing the selected
source invalidates the preview through the explorer's existing lifecycle.
Pending host requests pause actions. A condition error never yields a partial
cohort. The original 32 KiB capture, 512-record, 32 top-level-field, 32-level
nesting and 1,024-unit pointer limits remain in force.

The cohort criteria and preview are temporary inspection state. They are not
embedded as a new filter receipt in the existing extract or NDJSON, and saving
an extract does not save the conditions. Keep a record of your selection method
when it matters to a later reviewer. The extract retains existing source name,
origin, capture time and record locators; unchanged prepared revisions can also
supply their existing host-recorded digest/revision identity. Raw NDJSON has no
provenance envelope.

All fields of selected records, including private sibling fields, are retained.
The original full dossier still includes unselected records. Selection is not
redaction. Review before sharing. Source text is inert. This is local evidence
preparation, not scientific judgment, permission to use a source, accepted
research, verified customer demand or a provider-backed answer. Browser download
requests do not prove that a file reached disk.

## Focused qualification

From the repository root:

```sh
node --test scripts/test_json_evidence_cohort.mjs scripts/test_json_nested_field.mjs scripts/test_json_field_coverage.mjs scripts/test_json_evidence_ndjson.mjs
```

R500 ran 72 focused Node checks: 12 cohort checks and 60 existing regressions.
Ten new checks execute production JavaScript extern bodies extracted directly
from MoonBit source: shared lossless intake, condition comparison, source-ordered
cohort projections, existing NDJSON output and reopening. Two additional new
checks inspect source wiring only. Across all four files, six checks are
source-wiring inspection, not executed MoonBit behavior. The retained run log and
sample output identify the exact source snapshot and fixture used.

MoonBit wrappers, reducers and Rabbita rendering were **not compiled or
executed**. Graphical browser interactions, file chooser, native-host
save/reopen, actual disk download and provider/full-product execution remain
unqualified. No Moon invocation, dependency install, substitution, network or
Chromium retry was attempted. R50 remains the last fully verified cumulative
qualification; R51–55 remain separate.

PRD rationale: MOONFIND-UC02/B02 calls for inspectable local JSON evidence and
provenance. MOONFIND-R02 keeps missing evidence unknown instead of favorable.
The new workflow prepares an explicitly defined subset for the existing brief
and evidence export without claiming that the broader research/provider or
scientific-comparison journeys are complete.

If you do not yet know which scalar values occur together, use the separate
[observed-pair breakdown](JSON_VALUE_PAIRS.md) to discover two-field combinations
and select their source records before defining a more specific cohort.
