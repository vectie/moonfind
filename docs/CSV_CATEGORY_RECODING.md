# Recode local evidence categories without losing original values

MoonFind's comparison and category tools can compare exact strings. When a
local corpus uses several labels for a category, explicitly map those labels
into a new column before exploring them. This is an operator-authored edit;
MoonFind does not infer meanings or claim that different labels are equivalent.

Requires Node 20+, no dependencies. From the repository root:

```sh
node scripts/csv_recode.mjs inspect --csv fixtures/category-recode.csv
node scripts/csv_recode.mjs preview --csv fixtures/category-recode.csv --plan fixtures/category-recode-plan.json
node scripts/csv_recode.mjs convert --csv fixtures/category-recode.csv --plan fixtures/category-recode-plan.json --out-dir ./category-bundle
```

Copy the sample plan and choose an exact input header, a new output header,
explicit string pairs, and an unmatched policy: `keep` copies unmatched
values into the new column; `empty` writes an empty new value; `error` refuses
conversion until every value has a mapping. Empty-string mappings are allowed.
Matching is case-sensitive and whitespace-sensitive. Mapping `yes` does not
change ` yes`. Duplicate mapping inputs and existing output headers are refused.
Every original column and the row order remain unchanged.

Review the preview's per-record changes and matched/unmatched counts. Convert
to a new directory; existing destinations are refused. In the research brief
studio, use **Import CSV table** to import `category-bundle/recoded.csv`.
Choose `response_group` in the column search, filter for `unanswered`, and select
matching records for the existing extract workflow. Keep `source.csv` and
`provenance.json` beside derived evidence: they retain exact originals, the
mapping plan, row-level decisions, and hashes. The bundle retains all input
data and is not a redaction tool.
The existing text filter uses substring matching: `agree` also matches
`disagree`. Use the existing category tools for category comparisons, or
inspect the matching rows before selecting them.

The sample produces `agree, agree, disagree, unknown, unanswered,  yes`.
Input and output each fit the existing 32 KiB / 512-row / 32-column contract;
the appended column requires at most 31 original columns. Large results are
refused rather than truncated. Formula-like text is never executed here, but
spreadsheet applications may interpret it. No network or provider is contacted.

Tests exercise the real CLI and the retained production explorer reducers
and extract function. Host intake is supplied as JSON in that test; browser
mounting, native host intake, persistence and installed lifecycle remain unrun.
