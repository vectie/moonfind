# Local RIS bibliography intake

Open the native host's `/apps/moonfind/briefs` page and use **Import RIS
bibliography**. Choose `fixtures/local-bibliography.ris` to try three references
with Unicode, repeated authors and a multiline abstract.

1. Browse each card's title, authors, year, DOI, URL and abstract.
2. Type `GARCÍA` in **Filter by author**. Records 1 and 3 remain visible.
3. Select those records. Filtering to another author keeps the selection.
4. Click **Add selected references to brief** and fill in the brief fields.
5. **Save prepared brief**, then reopen its saved revision from the catalog.
6. Download the complete dossier. It contains the original `.ris` unchanged,
   `ris-selection.json` metadata for only the chosen records, the readable brief,
   snapshot and manifest. Selected cards appear again when reopening.

Importing previews metadata; adding selected cards captures the selection into
the draft. Saving confirms native-host retention. A selection uses two of the
existing eight source slots. Original and selection each have the existing
32 KiB bound; the complete dossier remains bounded at 128 KiB of source bytes.
The raw original includes unselected records, while the structured selection
and readable brief list only the selected references. Removing a capture is an
explicit draft edit; earlier saved revisions stay unchanged.

## Supported RIS fields

- Records begin with `TY  -` and end with `ER  -`
- Title: `TI`, then `T1`, then `CT`
- Authors: every `AU` and `A1`, in source order, including repeated names
- Year: first four digits of `PY`, `Y1` or `DA`; non-year values stay as text
- DOI: `DO`; URL: `UR`, falling back to `L1`
- Abstract: `AB`, falling back to `N2`; continuation lines become newlines

UTF-8 BOMs and CRLF input are accepted. Unknown fields remain in the original
file. Missing metadata is shown blank; an absent title gets a numbered label.
An unfinished record is reported so the user can fix the local file. This is
metadata extraction, not citation verification, source analysis or research.
DOIs and URLs are displayed as text. No provider, remote lookup, or remote fetch
is called.

## Native API

Both routes accept JSON and the same localhost/same-origin rules as brief save:

- `POST /api/v1/briefs/ris/intake`: `{source, author_filter}`. `source` is an
  existing `BriefSourceInputV1` with `.ris` name, origin, capture time, capture
  kind and canonical UTF-8 `content_hex`. Returns `source`, `references` and
  `total_count`. An empty author filter returns all cards. A case-insensitive
  substring filter does not renumber the original records.
- `POST /api/v1/briefs/ris/select`: `{source, record_numbers}`. One-based record
  numbers are resolved against the original source. Returns two ordinary brief
  sources: the unchanged original and the `moonfind.ris-selection.v1` JSON
  companion. The companion includes original filename, source digest and cards.

Append the returned sources to `ResearchBriefV1.sources`, then use the existing
brief POST, GET and dossier routes. Existing v1 briefs require no migration.

## Build and focused proof

Use the pinned project dependencies. Build `cmd/ui_host` for native and the
separate `ui/rabbita-moonfind` module for release JS. For a no-bundler static
package, `scripts/stage_static_ui.mbtx` takes the repository root, the compiled
`js/release/build/main/main.js`, and the destination static directory. Start the
native host with `--workspace <local-directory> --ui-root <static-directory>`.

Focused tests:

- `moon test research/ris_test.mbt --target native`
- `moon test host/ris_wbtest.mbt --target native`
- From the UI module: `moon test main/ris_wbtest.mbt --target js`

The native UI test requires `MOONFIND_BRIEF_NATIVE_URL` pointing to the running
localhost host and `MOONFIND_RIS_FIXTURE` pointing to the absolute fixture path.
It executes the real compiled reducer, rendered HTML and Rabbita HTTP commands
through import, author filtering, selection, save, reopen and ZIP download.
The chooser completion is supplied by the test; it does not claim a manual
browser or OS file-picker test. Without the native URL that single integration
test skips its body, so set it for the full proof. The native storage test also
unzips the dossier and compares original bytes and selected metadata exactly.

`scripts/test_ris_native_ui.mbtx` starts and stops a local host, runs that UI
test, checks the author-filter API, downloads a dossier, and compares the
retained original to the fixture. Arguments are repository root, built host
executable, staged static UI directory, external JS target directory, and
evidence directory. Put the pinned `moon`, Node.js 24+, `curl` and `unzip` on
the process PATH. The helper uses a fresh temporary workspace and localhost
port 4357, with no remote calls.
