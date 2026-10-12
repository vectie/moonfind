# Compare two JSON evidence snapshots

A new interview export may add observations, revise outcomes or drop records.
Use **Compare two JSON evidence snapshots** in the existing brief explorer to
inspect those differences without manually lining up reordered records. This is
an explicit keyed comparison of chosen fields across two loaded captures. The
existing value-pair breakdown still describes combinations within one capture.
No model, provider, new endpoint, package, CLI or source mutation is involved.

## Try the synthetic revision

1. Open `/apps/moonfind/briefs`. Use **Choose local files** to load
   [`fixtures/json-snapshot-before.json`](../fixtures/json-snapshot-before.json).
2. Use **Import JSONL / NDJSON file** in the JSON explorer to load
   [`fixtures/json-snapshot-after.jsonl`](../fixtures/json-snapshot-after.jsonl).
   The existing importer retains exact bytes under a `.jsonl.txt` source name.
   Both captures remain separate source slots in the brief.
3. Set **Loaded JSON source** to the before JSON source, set **JSON Pointer to
   array** to `/observations`, then choose **Explore JSON array**. This is the
   Before side. Both source roles are your choice; timestamps do not infer order.
4. Open **Compare two JSON evidence snapshots**. Set **After source** to the
   imported JSONL capture, and **After source format** to **JSONL physical lines**.
   The after array pointer is ignored in this mode. To compare another JSON
   array instead, choose **JSON array** and enter its own root/array pointer.
5. Set **Unique record key pointer (both sources)** to `/id` and **Comparison
   field pointers (JSON array)** to `["/interview/outcome","/metrics/count"]`.
6. The live summary shows **1 added, 1 removed, 2 changed, 1 unchanged requested
   fields**. Inspect the before/after report:
   - `clinic-1` changed from `planned` to `completed`, and the exact count token
     changed from `9007199254740993` to `9007199254740994`. Before is record 1 at
     `/observations/0`; After is record 2 on physical source line 3.
   - `clinic-2` moved to the first record in the second file. Its requested
     fields are unchanged. A private note did change, but is outside this
     comparison and does not appear in the report.
   - `retired` appears only Before; `new-site` appears only After.
   - `shape` changed from a missing outcome member to explicit null. The count
     remains explicit null on both sides. Missing is never filled with null.
   These are invented examples, not research findings.
7. Choose **Download snapshot comparison JSON**. Open
   `moonfind-json-snapshot-comparison.json` in a JSON/text viewer. The artifact
   contains selected exact values as strings, source descriptors, field/key
   pointers and original record/line/pointer locators. Download does not save it
   into the brief. Save the brief separately to retain original sources; keep
   the existing dossier when you need full source bytes and host manifests.

## Identity and comparison semantics

The key pointer is record-relative and must resolve in **every** record to a
nonempty string, number or boolean. The key must be unique within each side.
Missing, blocked, null, empty-string, array or object keys stop the comparison
with the source side and record number. Duplicate keys report both record
numbers. Nothing is dropped, paired by position or automatically deduplicated.
Choose a reliable source-provided ID; the comparison does not prove that two
same-key records describe the same real-world observation.

Key kinds are distinct: numeric `1`, string `"1"` and boolean `true` cannot join.
String keys use exact decoded text, preserving case, whitespace and Unicode
normalization differences. `"a\u0062"` joins `"ab"`, and both original key
spellings remain in the output. Numeric keys use exact source token spelling:
`1`, `1.0`, `1e0`, `-0` and `0` are separate. Large numeric IDs do not pass through
floating-point conversion. No approximate, fuzzy or compound-key join is used.

Select one to eight distinct, nonempty JSON Pointers as a JSON array. `/` selects
an empty member name; `~1` means `/`, `~0` means `~`. The same key pointer may also
be selected as a comparison field. Array positions follow the shared field-lens
rules without exploding records. Both sides use the same key and ordered field
pointers, but their containing-array pointers and formats may differ.

Every selected field compares **kind and exact original JSON token**. A numeric
spelling change, a string escape spelling change, or changed whitespace/member
order **inside** a selected object/array token counts as changed. Strings also
have decoded display text in the artifact. Missing, blocked, null, empty string,
string, number, boolean, array and object remain separate kinds. Two unresolved
paths of the same kind compare unchanged; that does not mean verified data.

Unselected fields, record order and outer object formatting do not count as a
selected-field change. `unchanged_fields` is deliberately not a claim that the
whole record, source bytes, source identity or underlying evidence is unchanged.
The report is a token comparison, not semantic JSON equivalence, a JSON Patch,
statistical analysis, source authentication or an automatic conclusion.

## Report and scope

The contract is `moonfind.json-snapshot-comparison.v1`. It contains:

- Brief ID, chosen key pointer, ordered field pointers and explicit comparison
  semantics
- Before/After source slot, name, origin, capture timestamp, source kind,
  interpreted format, array pointer (null for JSONL) and full record count
- Added, removed, changed and unchanged-fields counts
- Every paired or unpaired record; Before-source order first, then new keys in
  After-source order. For each: status, changed field pointers, Before and
  After locators, typed exact key and chosen field kind/raw/display text
- Explicit null for an absent side and inapplicable line/pointer locators

All source records are compared, including records hidden by search or outside
current selection. No selection is changed. No sampling or top-N omission occurs.
A valid empty JSON array is a zero-record snapshot, so removal/addition of every
record is visible. An empty JSONL file remains rejected by the existing importer.

Selected containers include **all descendants**, which may be private. Key text,
source origins and selected values may also be sensitive. Full source bodies and
unselected fields are omitted, but projection does not redact the original brief
or its dossier. Review the artifact before sharing. Supplied source descriptors
are not authenticated; no digest is freshly calculated or verified and no saved
revision is claimed. Both original sources remain untouched.

## Lifecycle and bounds

The report is recomputed from current captures/settings for both preview and
download. No stale report is cached. Comparison settings are temporary, following
the JSON explorer lifecycle: changing the Before source, importing another JSONL
file into the explorer, saving/reopening or starting a new brief resets them.
Re-exploring the same Before source or editing its array pointer keeps comparison
settings but clears the existing explorer selection as usual. Editing comparison
settings does not edit sources or selection.

The After choice is bound to its source content/metadata as well as slot. Removing
or replacing it, or shifting source slots, produces a repairable error; reselect
the intended After source. An unrelated appended source does not invalidate it.
Pending host operations block reducer actions. A browser download request does
not prove a file was saved. A failed request leaves the inputs available to retry.

Each source retains the existing 32 KiB UTF-8, 512 object records, 32 distinct
top-level fields and 32 nesting-level limits. Pointers are at most 1,024 UTF-16
units. At most 1,024 union entries can result. Duplicate object keys, malformed
input/pointers or stale source projections return errors without partial output.
The pretty-printed JSON artifact has a separate 1 MiB UTF-8 bound. Maximum record
and field counts are not guaranteed to fit together; large or overlapping chosen
containers repeat data. Choose fewer fields or smaller captures when necessary.
Nothing is silently truncated. The original eight-source/128 KiB brief limit
also remains unchanged.

## Verification and PRD rationale

Run from the patched repository root:

```sh
node --test scripts/test_json_snapshot_comparison.mjs scripts/test_json_evidence_csv.mjs scripts/test_json_value_pairs.mjs scripts/test_json_evidence_cohort.mjs scripts/test_json_nested_field.mjs scripts/test_json_field_coverage.mjs scripts/test_json_evidence_ndjson.mjs
```

R553 ran 129 focused Node checks: 117 executable production-JavaScript checks and
12 explicitly named source-wiring checks. The new test file adds 20 executable
checks and two wiring checks. It executes the shipped extern bodies, shared
lossless intake and field configuration, keyed joins, exact token output, repair
cases, full bounded scopes, a real local file write/reopen and exact UTF-8 Blob
bytes with a controlled DOM download boundary. These do not compile or execute
the MoonBit wrappers, reducers or UI rendering.

The actual `prd_work/content/moonfind.json` UC02/B02 requires inspectable source
intake and retained source revisions; UC04/B04 requires openable output files.
This closes the local operator gap of inspecting chosen-field changes between
separate JSON captures. It does not create host snapshot/digest identities or
complete the source-provenance, delivery-manifest or provider acceptance gates.
Native host persistence, graphical browser/file picker, actual browser disk save,
MoonBit compilation/reducers/rendering, provider and full-product execution remain
unqualified. No dependency installation/substitution, network, Chromium retry or
Moon command was performed. R50 remains the last fully verified cumulative
checkpoint; R51–55 remain separate.
