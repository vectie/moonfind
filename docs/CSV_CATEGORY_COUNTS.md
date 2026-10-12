# Count CSV categories and inspect their source records

1. Open the local brief UI and import a CSV using **Explore a local CSV corpus**.
2. Under **Category counts and source-row drill-down**, choose an imported column.
3. Choose **All imported rows** (the default) or **Current matching rows**. The
   latter uses the current search text and search-column selector. Counts do not
   depend on the selected rows or projected output columns.
4. Click a group's **Select group** button. This replaces the previous row
   selection with the group's original record numbers in the chosen scope.
   The selected-source table shows every selected record, including records
   hidden by the current search. Search and output columns remain unchanged.
5. Optionally change output columns and add selected evidence rows to the brief
   using the existing workflow; save the brief to retain that evidence.
6. Or download **category summary JSON** directly. It contains source metadata,
   exact original bytes as `content_hex`, chosen column number/name, scope,
   search settings, row totals and each group's exact value/count/member records.
   It includes the **entire original CSV**, even in matching-row scope. Keep it
   private and review the original before sharing. This is not redaction.

## Exact semantics

Values compare as exact strings. Empty strings form a group labeled `(empty
cell)`; spaces, `A` and `a`, composed `é` and decomposed `é` remain separate.
Nonempty labels use JSON quoting so tabs, quotes and newlines are distinguishable.
No numeric coercion, trimming, case folding or Unicode normalization is applied
when grouping. Search retains its existing trimmed, case-insensitive literal
substring semantics. Changing search affects matching scope immediately; all-row
scope ignores it. Empty matches produce zero groups and a valid zero-row summary.

Groups sort by count descending, then first source-record number ascending.
Membership preserves source order. Record 1 is the header, so the first data row
is record 2. Quoted multiline cells still occupy one logical record, not multiple
records. Repeated group selection is idempotent. Filtering or changing counted
columns/scope preserves selection until another group replaces it, a row is
manually toggled, or selection is explicitly cleared. A newly imported table
resets category column to the first and scope to all rows. Pending operations
block category actions; stale import replies remain ignored.

## Boundaries

This is a session-only projection of the existing bounded intake: 32 KiB CSV,
32 columns, 512 data rows. All groups and record memberships are exported with
no top-N sampling or omitted tail. The summary is compact relative to full row
objects but includes hex-encoded source bytes to identify its exact input without
relying on a filename. It is not digest-verified, authenticated, or a retained
brief revision. User-supplied origin/capture metadata does not establish truth.
Counts describe the supplied rows only; they imply no representative sampling,
statistical significance, completed research, approval or provider execution.
A download does not save the brief or add the summary as an evidence source.

The download is UTF-8 JSON in a Blob with a fixed safe filename; values are JSON
escaped and UI text is HTML escaped. Download failures leave intake/selection
intact for retry. No new host endpoint, dependency or provider call is added.
