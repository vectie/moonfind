# Explore a literature window by publication year

In the brief studio, add selections from BibTeX, RIS or CSL JSON, or reopen a
brief that already contains them. In **Unified bibliography reading list**, use
**Explore publication years** to inspect the chronology without editing any
reference or source capture.

1. Choose **Recognized publication years** in **Publication date scope**.
2. Set **From year (inclusive)** and/or **Through year (inclusive)**. For example,
   2020 through 2025 includes both endpoints. Blank bounds are open-ended. Leave
   both blank to see every reference with a recognized year.
3. Choose **Newest publication year first** or **Oldest publication year first**.
   Same-year ties retain source-slot and retained-record order. These are year
   sorts, not month/day sorts. **Original source order** restores the prior order.
4. Combine this window with the existing text search and DOI-candidates filter.
   The count above the date controls reports recognized and unclassified dates
   among the current text/DOI matches, before the date filter.
5. Choose **Unclassified dates only** to inspect blank, literal, uncertain,
   unsupported or range dates separately. Choose **All retained dates** to see
   all dates again. Bounds are retained while another scope is selected, but are
   inactive there. Returning to recognized years restores that window.
6. Download current-match JSON, RIS or CSL JSON. Each contains the exact visible
   records in the chosen order. Current JSON additionally records the active
   date scope, bounds and order. An empty valid window exports a zero-record JSON
   list; RIS and CSL retain their existing refusal for empty libraries.

## What counts as a recognized year

The projection uses the current CSL export calendar interpreter, accepting one
numeric `YYYY`, `YYYY-M` or `YYYY-M-D` date with year 0001–9999. Month and day
must be valid; leap years are checked. Outer whitespace is ignored. For example,
`2024-2-29` supplies 2024, while `2025-2-29` stays unclassified.

Date ranges (including two dates in the same year), seasons, slash dates,
uncertainty markers, free text such as `forthcoming`, and missing dates do not
get an inferred year. Full-width digits are not converted. Original text remains
visible and unchanged on the card and in exports. These are supplied metadata,
not independently verified publication dates. Existing importer projections may
already reduce source metadata; this feature does not re-read the source files.

In year order, unclassified records follow dated records and keep source order.
In unclassified-only scope, year sorting therefore has no effect. A malformed
bound or reversed interval shows an editable explanation and blocks current-match
downloads; it never silently becomes an empty successful date window.

## State, DOI inspection and shortlist

- **Clear reading-list filters** resets text, DOI and date filters and returns
  to original source order. It keeps the shortlist and source captures.
- **Inspect N same-DOI candidates** resets text and date filters/order to reveal
  the complete group; then a date window can narrow it. The candidates-only
  toggle keeps the date window. DOI counts still describe the entire catalog.
- Date filters/order are temporary UI state. They survive source edits and a
  successful reopen in the same session, matching the existing reading filters.
  Results are recomputed from current captures. They are not saved in the brief;
  page reload and **New blank brief** reset them. Pending host work blocks changes.
- The explicit shortlist keeps user selection order, including choices hidden
  by dates. Its selected downloads ignore these filters and ordering. An invalid
  current date window does not prevent downloading a valid explicit shortlist.

No gateway, provider, new dependency or source mutation is required. The fixture
tests qualify the compiled UI projection, reducers, rendered HTML and controlled
download boundary with actual Node Blobs. Native import/persistence, graphical
browser behavior, external reference managers and scientific truth are outside
this focused qualification.
