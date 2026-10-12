# Offline research briefs and retained local-source dossiers

This workflow prepares a research brief. It does not execute research, analyze
sources, produce requested research outputs, approve acceptance criteria, or
make provider calls. A saved byte digest verifies the captured representation,
not a source's truth, authorship, quality, or permission to use it.

## Open the studio

Build the native `cmd/ui_host` executable and the Rabbita JS module using the
repository's pinned dependencies. Serve the normal compiled UI assets through
the native host, passing `--workspace /absolute/local/workspace` and
`--ui-root /absolute/compiled-ui-directory`. A `--run-id` is optional for this
workflow. With no run selected, the host prints the offline studio URL:

`http://127.0.0.1:4313/apps/moonfind/briefs`

The existing `/apps/moonfind/research` path and its research, choices,
experiments, delivery and review workflows retain their original run semantics.
The offline studio initializes only the brief catalog; it does not initialize
Cowork, capability submission, remote search or model discovery.

## Capture and reopen

1. Fill in the question, objective, audience, decision to inform, source
   restrictions, requested output filenames and acceptance criteria
2. Paste text with a filename and attribution, or choose local files
3. Inspect the selected captures and click **Save prepared brief**
4. Reopen any saved revision from the catalog; refresh reloads the native store
5. Edit a reopened complete revision to create a new immutable child revision

Pasted text is encoded as UTF-8. Local files retain their exact selected bytes,
including Unicode, UTF-8 BOMs and line endings. Only UTF-8 `.txt`, `.md`, `.csv`,
`.json`, `.bib` and `.ris` files are supported. JSON/CSV/BibTeX syntax is not analyzed.
The **Import RIS bibliography** panel parses local RIS metadata into reference
cards. Filter by author, select cards, and add them to the brief. Each selection
retains the original RIS plus a structured selection JSON, using two source
slots. Saved briefs reopen the selected cards and readable exports include them.
See [RIS bibliography intake](RIS_BIBLIOGRAPHIES.md) for the example and API.
PDFs, binary controls, malformed UTF-8 and unsupported extensions are rejected.
Limits: 8 sources, 32 KiB per source, 128 KiB total, 12 requested filenames,
8000 characters per brief field, 1 MiB HTTP body, 200 catalog revisions.

Each capture records its original name, user/browser-supplied origin and capture
time, capture kind, retained availability, byte count and SHA-256 digest. Browser
file selection provides a filename, not a trustworthy absolute local path.
Origins are descriptive text and never trigger a fetch or filesystem read.
Duplicate names and duplicate content are retained in separate numbered slots
with their own provenance. Captures are snapshots; later changes to the original
file do not update them. Remove and recapture to prepare a new basis.

The editor attempts a browser-local draft save after changes so an interrupted
request can be retried with the exact original content. Only the native-host
prepared confirmation proves durable retention. Browser storage failures are
visible. “New blank brief” starts a new identity; it never deletes saved briefs.
An unreadable or corrupt browser draft is never overwritten by editing a blank
fallback. Its key remains untouched until the explicit “New blank brief” choice.
After restoring a browser copy, the studio asks you to reopen a saved native
revision before revising it; an interrupted save can instead be retried unchanged.
No data is transmitted beyond the same-origin local native host by this workflow.

## Immutable retention and recovery

The native store uses `.moonsuite/products/moonfind/briefs/<brief-id>/<revision>`
inside the chosen workspace. A revision ID covers every brief field, parent
revision, source provenance and exact bytes. Source filenames inside storage and
ZIPs are numbered safe paths, so duplicate original names cannot overwrite one
another. `snapshot.json` is the final immutable commit marker.

Writes use a workspace lock, synced temporary files and atomic final renames.
Repeating the same save returns the same revision. An interrupted uncommitted
save can fill missing files or replace only its incomplete staging files.
Conflicting final bytes and committed snapshots are never overwritten. A new
initial request with an already-used brief ID but different content is rejected;
reopen a valid parent or start a new brief instead.

Missing or changed committed files show **incomplete**. Complete export is
withheld, and retry does not silently repair corrupted committed history.
Restore the original bytes from a trusted backup. The catalog still exposes
incomplete captures. Reopening a complete historical revision remains valid
after newer revisions are saved.

## Export

Use **Search loaded source dossier** to find literal text across the currently
loaded captures and open a result at its original source slot and line. Complete
unchanged saved revisions can export a digest-bound JSON reading artifact. See
[Dossier search](DOSSIER_SEARCH.md) for case, Unicode, line-ending and limit rules.

**Download readable brief** returns `brief.md` with the requested scope,
unapproved criteria and source provenance. **Download complete source dossier +
manifest** returns `dossier.zip` containing:

- `brief.md`: readable preparation instructions and source inventory
- `brief.json`: exact typed brief snapshot, including the captured byte encoding
- `manifest.json`: revision identity, boundary, all file lengths and SHA-256
  digests, plus each source's original name and provenance
- `sources/source-N.<extension>`: every selected source's original bytes

The requested research filenames remain requests. The exporter does not create
placeholder research outputs under those names. An export requires all selected
source bytes to match the immutable snapshot. Sources are not omitted merely
because their names or content duplicate another capture.

## API

- `GET /api/v1/briefs`: list saved revisions without changing storage
- `POST /api/v1/briefs`: save `moonfind.research-brief.v1`
- `GET /api/v1/briefs/<id>/<revision>`: read validated status and snapshot
- `GET /api/v1/briefs/<id>/<revision>/brief.md`: readable brief
- `GET /api/v1/briefs/<id>/<revision>/dossier.zip`: complete retained dossier

The routes require a trusted localhost Host and same-origin request. Writes
require bounded JSON bodies. IDs and filenames are validated before storage.
There are no remote-fetch, PDF-extraction, provider-execution or approval routes.

## Interface reconciliation

The historical `research/pkg.generated.mbti` still advertised `ResearchJob`,
requested/delivered output structures and delivery-validation helpers that had
no implementation in the R35 source tree. Regenerating the interface with the
pinned compiler removes those stale declarations and adds the implemented brief
contracts. No implementation of those historical declarations was removed.
This release closes the offline preparation gap described in
`BASELINE_GATEWAY_RECONCILIATION.md`; it does not claim to restore general-job
execution or deliver research outputs.

For a reference manager's CSL JSON array, use **Import CSL JSON bibliography**
instead of adding it as an opaque generic JSON capture. It provides searchable
cards, preserved item IDs and selected-reference exports. See the
[CSL JSON workflow](CSL_JSON_BIBLIOGRAPHIES.md).
