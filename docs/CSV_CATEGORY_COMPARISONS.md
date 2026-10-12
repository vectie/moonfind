# Compare numeric evidence across categories

Import a CSV in **Explore a local CSV corpus**. This is useful when an observation
table has a numeric measure and a segment, method, source type or other category.
The comparison describes supplied records; it does not validate observations.

1. In **Numeric column summary and source records**, explicitly choose the numeric
   column and **All imported rows**, **Current matching rows**, or **Selected rows,
   including hidden rows**. These controls are shared with the comparison.
2. Open **Compare numeric values by category** and explicitly choose the comparison
   category column. Both columns are identified in the controls; neither is inferred.
   The same column may be used for both if that is the comparison you intend.
3. Inspect each category's row/numeric/blank/invalid counts, minimum, maximum, sum
   and mean side by side. The Group number is presentation order, not a source
   record. Categories and member cells follow first source occurrence/source order.
4. Expand **Source records for ...** to see every original column and logical
   source-record number for that group, including excluded numeric cells/reasons.
   Changing category, scope or drill-down never changes selection/output columns.
5. **Download category comparison JSON** saves an inspectable local artifact using
   contract `moonfind.csv-category-comparison.v1`. It includes both column numbers
   and names, scope/search settings, scoped membership, all groups' original cell
   text and record numbers, statistics, and complete original bytes as content_hex.

For `fixtures/numeric-measurements.csv`, choose numeric `value`, category `group`
and all rows. `keep` has 5 rows: 3 numeric, 1 blank, 1 invalid; sum 8 and mean 8/3.
`omit` has 4 rows: 2 numeric and 2 invalid; sum 30.5 and mean 15.25. Searching
`keep` in `group` then selecting matching scope shows only `keep`. Selecting a
hidden `omit` record and using selected scope still includes that record.

## Semantics and boundaries

Categories compare as exact strings: empty, space, upper/lower case and composed/
decomposed Unicode are distinct. JSON-quoted labels expose whitespace. Empty
scopes show no groups, not fabricated zero-valued categories. No top-N truncation
or sampling occurs within existing intake bounds (32 KiB, 32 columns, 512 rows).

Numeric grammar, exclusions and approximate compensated binary64 arithmetic are
exactly those in [numeric summaries](CSV_NUMERIC_SUMMARIES.md). Each group is
calculated independently; overflow makes only that group's sum/mean unavailable.
No numeric cells means all statistics unavailable. JSON includes explicit null
keys for unavailable statistics and excluded values; actual zero remains zero.
Unequal group sizes are visible. There is no ranking, unit conversion, weighting,
normalization, statistical inference, significance or causal claim.

The download includes the entire original CSV, including hidden/unselected data.
Review before sharing: it is not redaction, source authentication, approval or
completed research. A requested download does not prove the browser saved it.
Downloads and drill-downs do not add evidence to the brief or save a revision.
Comparison state is session-only and resets on new import, New, or successful
Add selected evidence, following existing intake behavior. Pending actions block
comparison changes/downloads and stale import replies remain ignored.

Focused compiled UI/Node tests use host-shaped synthetic intake. Real Node Blob
bytes are checked with a controlled DOM/URL boundary. Native CSV parsing, file
picker, graphical usability, persistence, live providers and scientific outcomes
are not requalified here. No endpoint, package, provider or dependency was added.
