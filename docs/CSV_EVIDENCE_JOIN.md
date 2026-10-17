# Join two local CSV evidence tables

A researcher can connect interview observations to a second lookup table without
retyping evidence or losing the originals. This extends the existing CSV corpus
explorer; local email and Slack intake from R571/R584 remain unchanged.

1. Import the first CSV using **Import CSV table**. Open **Join two local evidence
   tables** and **Pin current CSV as left**.
2. Import the second CSV and **Pin current CSV as right**. Pins retain the complete
   native parsed snapshot, including rows hidden by a current search. They remain
   independent of subsequent imports. Pinning either side resets that key choice.
3. Choose each key column explicitly and select the right fields to append.
   Appended fields retain their original source order; the right key itself need
   not be appended. Unselected wide/private fields remain only in the original.
   Choose **Inner** (matched left rows) or
   **Left** (all left rows). Preview counts and the joined records.
4. Choose **Use joined table in CSV explorer**. The generated ordinary CSV is
   submitted to the existing `/api/v1/briefs/csv/intake` route. Only an exactly
   matching native reply can replace the current explorer. Then search, inspect
   category/numeric summaries, project columns, and select records as usual.
5. **Add selected evidence rows to brief** uses the existing `/csv/select` route.
   It retains five sources: exact left original, exact right original, readable
   lineage, complete joined CSV, and the standard selected-row JSON companion.
   Save the brief through the existing revision flow to retain the dossier.

## Exact-text policy and provenance

Keys preserve decoded CSV text. `001`, `1`, `A`, `a`, and leading/trailing spaces
are distinct. Unicode is not normalized. Empty strings never match, including
when both sides contain empty keys. Whitespace-only keys are nonempty exact text.
Missing key choices and malformed/missing fields block the operation. Nonempty
right keys must be unique, even if duplicates would not match the left table.
Repeated left keys keep each source row distinct: this is bounded many-to-one,
never many-to-many. Duplicate counts count repeated rows beyond the first.

The preview reports matched left rows, unmatched left and right rows, empty-key
rows and duplicate-key rows. An inner join drops unmatched left rows; a left join
retains them with blank right cells. `left_source_record` and
`right_source_record` distinguish unmatched rows from matched rows with empty
values. Original record 1 is the header; multiline fields count as one record.
All left fields and only selected appended right fields remain exact text, with output headers prefixed by side and column
position to avoid collisions. The derived CSV retains source order on the left.
The lineage companion records policy, counts, chosen original key columns,
metadata, and source-slot locators into the retained dossier. The saved native
snapshot supplies digests for those slots. Removing or reordering sources makes
those locators stale; a revision never changes earlier saved bytes.

## Boundaries and recovery

- Input snapshots must be complete native intakes with unique nonblank headers,
  at most 32 columns and 512 data rows. Generated CSV must fit 32 KiB and 32
  columns, including two provenance columns. Header-only inner results can be
  explored/downloaded but have no rows to select.
- Selection replies must exactly match the current requested source-order
  projection, contract, source name/count, companion metadata and SHA-256 of
  original bytes. Extra fields, stale digests, wrong rows/columns or malformed
  companions are rejected without clearing the explorer.
- A joined selection requires five free source slots. The existing eight-source,
  32 KiB per-source and 128 KiB total limits still apply. Over-limit responses
  leave current explorer selections and originals available for repair.
- A second join click while pending does not issue another request. Changing a
  join input/key/mode/appended fields, clearing inputs, or making a new CSV selection/import
  cancels the pending join generation. Late replies cannot replace newer state.
  Held appended-field controls are generation-bound; clearing or re-pinning even
  identical sources invalidates them. New blank brief and opening a saved brief
  reset pins and transient join state.
- Pins and previews are temporary, not saved evidence. A generated table carries
  its own immutable provenance even if join settings change afterward. Importing
  an ordinary CSV clears its active derived lineage. Chained joins are blocked.
- Original captures retain all cells, including private/unselected data. A join
  does not redact, verify claims, prove source identity, or fetch URLs. There are
  no provider calls, new routes or contract versions.
- CSV quotes preserve field boundaries, not spreadsheet safety. Import all
  columns as text to preserve lexical numbers/dates and avoid formula evaluation.

## Verification

`scripts/test_csv_join.mjs [absolute-source-root]` runs production embedded JS
against lexical, quote/newline, empty/duplicate, shape and size cases. The compiled
`csv_join_wbtest.mbt` suite exercises production reducers, UI rendering, existing
HTTP commands and browser draft/reopen state. Simulated HTTP tests are explicitly
not native host integration. Real native intake/select compatibility remains a
qualification requirement when an exact executable is available; no native host
or provider success follows from the simulated tests.
