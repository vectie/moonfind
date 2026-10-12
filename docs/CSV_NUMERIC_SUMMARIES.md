# Summarize a numeric evidence column

In the offline brief studio, import a CSV with **Explore a local CSV corpus**.
Open **Numeric column summary and source records** and explicitly choose the
column to summarize. For example, an observation table may contain elapsed
minutes alongside a customer segment and an observation. No numeric column is
guessed, and the supplied observations are not validated by summarizing them.

1. Choose **All imported rows**, **Current matching rows**, or **Selected rows,
   including hidden rows**. Matching scope uses the existing search text and
   search-column selector. Selected scope includes selected records hidden by
   search. Projected output columns do not affect this summary.
2. Inspect the scoped, numeric, blank and invalid counts. Minimum, maximum, sum
   and mean describe only numeric cells; a blank or invalid cell is never zero.
3. Use **Inspect contributing or excluded source records** to show numeric,
   blank, invalid, minimum or maximum records. All ties are shown. The table
   retains every original column and logical source-record number. Excluded
   cells additionally show their exact text and exclusion reason.
4. Change search, selection, column or scope to recalculate immediately. Looking
   at a summary or its drill-down does not change search, evidence selection or
   projected output columns. Existing selection/add-to-brief controls still work.
5. **Download numeric summary JSON** to keep an inspectable local result. The
   `moonfind.csv-numeric-summary.v1` file contains scope/search settings, the
   selected column, every scoped record and original cell string, parsed values,
   reasons for exclusions, statistics and the complete original source capture.
   It includes hidden/unselected data too. Review before sharing; it is not
   redaction. A requested browser download does not prove the file was saved.

Try [the synthetic measurement table](../fixtures/numeric-measurements.csv).
For the `value` column, all rows give 5 numeric, 1 blank and 3 invalid cells,
minimum -2, maximum 20.5, sum 38.5 and mean 7.7. Search `keep` in `group` and
choose matching scope: 3 numeric, 1 blank and 1 invalid, sum 8. Select source
record 3 and choose selected scope to inspect its value 20.5 even while hidden
by that search. These rows are invented examples, not empirical findings.

## Exact number semantics

Accepted tokens are ASCII decimal numbers with an optional sign, a decimal
point and an optional e/E exponent with an optional sign. At least one mantissa
digit is required, and an exponent needs digits. Examples: `+12`, `.5`, `1.`,
`-0.25`, `0010.00`, `1e3`. Outer ASCII space, tab, CR and LF padding is ignored
for parsing; exact original text is retained. All other characters are rejected.

- `1,000`, `1,5`, `12%`, `$12`, `12ms`, hex, digit separators, Unicode digits,
  non-ASCII minus signs, nonbreaking spaces, NaN and Infinity are not numbers.
- Empty and ASCII-whitespace-only cells are `blank`. Invalid grammar is
  `not_decimal`; overflow or parse-range failure is `out_of_range`; a nonzero
  mantissa rounded all the way to zero is `underflow_to_zero`.
- Finite values use IEEE-754 binary64. Decimal fractions, very large integers
  and very small numbers may round. This is approximate exploratory arithmetic,
  not exact decimal accounting. No unit conversion, units inference, weighting,
  scientific precision, financial correctness or locale coercion is promised.
- Sum uses Neumaier compensated addition in source order; mean is that sum
  divided by the numeric count. If the running sum/correction overflows, sum and
  mean are unavailable, even if later cancellation could make an exact sum
  finite. Min/max remain available. Min/max ties compare parsed binary64 values.
- With no numeric cells, all statistics are unavailable (`null` in JSON), never
  invented zeroes. Every statistic key is present; blank/invalid cells also retain
  an explicit `value: null`. Real zero values produce zero statistics normally. Arithmetic
  on representable values can still round or underflow; compensation is not a
  proof of exactness.

Record 1 is the header. Quoted multiline cells occupy one logical record. The
existing 32 KiB, 32-column, 512-data-row intake bounds apply without sampling or
truncating the summary. Blank and invalid values remain visible in every scope.

## Retention and qualification

The numeric summary is session-only. A new import resets the chosen numeric
column, scope and drill-down; adding a selection to the brief clears intake as
before. A new blank brief clears it. Saving the brief does not retain numeric
exploration state or silently add the summary as a source. Download first if
you want to keep the result. Pending host actions block numeric actions, and
old import replies cannot populate a newer brief.

The summary preserves exact imported bytes as `content_hex` and supplied
metadata; it does not freshly verify a digest or establish authenticity. It is
a reading artifact, not a retained native revision, representative sample,
statistical-significance claim, source-rights approval or research completion.
No provider, additional endpoint, dependency or remote service is involved.

Compiled JS tests exercise production intake replies/reducers, numeric parsing,
all scopes, drills, rendering, export and real Node Blob bytes with a controlled
DOM/URL boundary. This UI-only qualification does not requalify the unchanged
native CSV parser, browser file picker, native persistence, graphical usability,
provider research or scientific conclusions.

For side-by-side numeric results across exact text categories, see
[category comparisons](CSV_CATEGORY_COMPARISONS.md). It shares the explicit
numeric column and scope controls above and adds a separate category selector.
