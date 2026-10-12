# Search retained local-source dossiers

Open the offline brief studio at `/apps/moonfind/briefs`, capture local text or
reopen a saved brief, then use **Search loaded source dossier**. This is a local
reading aid across captures already loaded into that brief, including retained
bibliography selections and CSV extracts. It neither acquires nor refreshes
sources and makes no inferred claims.

1. Enter a literal phrase, such as `delay`.
2. Optionally turn **ASCII case folding** on to include `DELAY`.
3. Results identify the original filename, one-based source slot and one-based
   physical line. Duplicate filenames remain separate slots.
4. Click **Open source … line …**. The capture opens beginning at that line;
   expand **Earlier capture lines** to inspect the preceding portion.
5. Save or reopen a complete unchanged revision, then **Download search reading
   artifact**. The JSON records the query, mode, result limits, matching-line
   count, omitted count, revision and every saved source's digest/provenance.

The downloadable `moonfind-dossier-search.json` is a reading artifact, not a
requested research output, evidence validation or acceptance receipt. Digests
are the native host's saved source identities. The UI requires the loaded draft
to equal the confirmed saved snapshot; editing, removing a source, an incomplete
revision or a pending save/open blocks export. It does not recontact the host
to detect damage that happens after the snapshot was loaded. Reopen to recheck
host retention. Download failures are visible and can be retried.

## Exact semantics and limits

- Literal substring, never a regular expression, one result per matching line
  even when a line contains several occurrences. Source order then line order.
- Case-sensitive by default. The optional fold changes only ASCII A–Z to a–z.
  `STRASSE` does not match `Straße`; `é` does not match `É` or decomposed `é`.
  No Unicode normalization, locale mapping or full Unicode case folding.
- CRLF is one line break. LF and standalone CR also delimit lines. UTF-8 BOMs
  remain searchable text. Empty query has no results; newline-containing queries
  and queries over 256 UTF-16 code units show an issue.
- First 200 matching lines are shown/exported; the total and omitted count remain
  visible. Context begins up to 60 Unicode code points before the first match and
  contains at most 240 code points plus clipping ellipses. Long matches can be
  clipped; open the capture to read the full line.
- Search strictly decodes UTF-8 hexadecimal captures. Invalid hex, malformed
  UTF-8 or sources above 32 KiB are skipped with their slots visible, never
  replaced with a searchable error string. Skipped captures block export.
  The existing eight-source/128 KiB intake limits still apply.
- Capture display normalizes line endings only; retained bytes never change.
  Names, query results and capture text render as escaped text, not HTML.
- Zero matches in a valid complete revision may be exported. This reports only
  a literal search result, not absence of evidence or a factual conclusion.
- Search settings and open-hit navigation are session-only; source edits clear
  open navigation. The existing browser draft and native retention are unchanged.

## Synthetic example and qualification

The compiled tests search this synthetic capture with ASCII folding enabled:

```text
Earlier
Reported <script>delay</script> 月面 🌒
Conflicting DELAY report
```

Expected matching lines: 2 and 3; both are kept without resolving the conflict.
Tests exercise duplicate slots, CRLF/CR/LF, emoji, BOM, combining characters,
literal metacharacters, result/context bounds, bad encoding, repeated queries,
compiled reducers, escaped Rabbita render, stale/incomplete export denial and
the production download function with a simulated DOM/Blob boundary.
No graphical browser, file-picker, native-host integration, provider or Mac
qualification is claimed for this UI-only change.
