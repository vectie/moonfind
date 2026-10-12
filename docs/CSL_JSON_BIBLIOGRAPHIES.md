# Use a CSL JSON bibliography in an offline research brief

The brief studio now reads a reference manager's **CSL JSON** export as
searchable reference cards. This is a local, provider-free source workflow.

## Try the complete workflow

1. Open `/apps/moonfind/briefs`. Fill the research question, audience, decision,
   source restrictions, requested filenames and acceptance criteria.
2. In Zotero or another reference manager, export the references in **CSL JSON**
   format. In MoonFind choose **Import CSL JSON bibliography** and select the
   `.json` file. Try `fixtures/local-bibliography.csl.json` for a synthetic example.
3. Search by item ID, citation key, title, author, editor, issued date, venue,
   keyword or DOI. The example's `GARCÍA` query finds a personal author and a book
   editor. Search is case-insensitive and does not renumber the source records.
4. Select records. Changing the search preserves the selection, including cards
   currently hidden by the filter. **Add selected references to brief** adds two
   captures: the exact original file and `csl-selection.json`.
5. Save the brief. Reopen it from the saved catalog to inspect the selected cards.
   Download `brief.md` or the complete dossier ZIP. The readable brief includes
   selected titles, citation keys, original IDs, authors/editors, issued dates,
   venue, DOI, URL, availability and supplied abstracts. The ZIP also retains
   the unchanged input and structured selection with its source digest.
6. Open the saved revision's offline comparison. Choose `csl-selection.json` as
   an option's strongest local capture. Cite its key or item ID in your notes,
   record unknowns and the next experiment, and export Markdown/restorable JSON.
   Both exports retain the exact source basis. An abstract is a lead for further
   review; it does not establish a verified result or a read full text.

The sample supports a user-authored comparison of contact sensing and tactile
mapping. It contains invented references and is not scientific evidence.

## Supported shape

Input is a nonempty JSON **array** of CSL item objects, not Zotero's native JSON
export or an API response with an `items` wrapper. Use UTF-8 `.json` (including
`.csl.json`), at most 32 KiB. A leading UTF-8 BOM, Unicode and CRLF are supported.
Each item needs a nonblank string or numeric `id` and a nonblank `type`.

Cards read:

- `citation-key` (optional; the ID is its display fallback), `title`, `type`
- `author` and `editor` arrays, with literal organization names or family/given
  names, name particles and suffixes
- `issued.date-parts` with one date or a two-date range, each with 1–3 string or
  numeric parts; otherwise `issued.literal` or `issued.raw`
- `container-title` (falling back to `publisher`), `keyword`, `DOI`, `URL`, `abstract`

The field mapping follows the [CSL input data schema](https://raw.githubusercontent.com/citation-style-language/schema/master/schemas/input/csl-data.json).
This importer is a useful subset, not a complete CSL schema validator or citation
style processor. Formatting markup is shown as source text in the cards. Unknown
fields, other contributor roles, attachments, date season/circa flags and all
original values stay in the unchanged source; they are not expanded into cards.
It never fetches the links or imports attachment contents. Generic JSON captures
remain available through the existing local-source chooser.

The selection stores one-based original record positions and lossless ID text
plus `item_id_kind` (`string` or `number`). This avoids JavaScript rounding of
large numeric IDs while preserving the original type. Citation keys need not be
unique; record positions identify the selection. Exact duplicate IDs, malformed
known-field shapes and incomplete JSON produce an error instead of partial cards.
Missing titles use an explicit untitled fallback. Missing abstracts are labelled
`metadata-only`; present abstracts are `metadata-and-abstract`.

Existing brief limits apply: eight source slots, 32 KiB per capture, 128 KiB total.
A bibliography uses two slots. If the normalized selection exceeds 32 KiB, select
fewer records. A cancelled chooser leaves the draft unchanged. New blank brief
clears an outstanding import, and late import/selection replies cannot replace it.

## Local HTTP API

- `POST /api/v1/briefs/csl/intake`: `{source, query}`. `source` is the existing
  `BriefSourceInputV1` with name, origin, capture time, capture kind and exact hex
  bytes. Returns source, filtered references and the unfiltered total count.
- `POST /api/v1/briefs/csl/select`: `{source, record_numbers}`. Re-parses the
  original bytes and returns the two ordinary brief captures. Order follows the
  original source, and repeated selected positions are included only once.

The existing native host's same-origin write checks also apply to these routes.
No provider, citation service, refresh/watch, acceptance decision or research
answer is created by the intake itself.

## Reproduce the checks

Run the root module's native tests in `research/csl_test.mbt` and
`host/csl_wbtest.mbt`, then build `cmd/ui_host`. Build the separate
`ui/rabbita-moonfind` module for JS. `scripts/stage_static_ui.mbtx` stages the
compiled JS with the existing styles and entry page. Then invoke
`scripts/test_csl_native_ui.mbtx` with five absolute arguments:

1. Repository root
2. Built native `ui_host.exe`
3. Staged static UI directory
4. External UI build directory
5. Existing evidence directory

The runner starts/stops a loopback host on port 4402, executes seven compiled
CSL/BibTeX/RIS UI tests against it, verifies byte-exact ZIP contents, and retains
actual brief, selection and comparison exports. It requires the native-workflow
completion marker, so an environment-skipped test cannot count as this proof.
