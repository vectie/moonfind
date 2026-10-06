# Retained research file delivery

The completed synthesis screen now offers **Prepare research files**, followed
by real **Preview**, **Download**, and **Download complete ZIP** links. It does
not call a model or add research. The package formats the retained question,
source records, analysis, contradictions, limitations, falsifiers and returned
synthesis into inspectable files.

## Files and identity

- `report.md`: readable Markdown projection, previewed as plain text
- `evidence.json`: typed retained source records, claims, questions, candidate
  ideas, missing evidence and source-scope fields
- `synthesis.json`: typed returned synthesis, excluding unrecognized fields
- `manifest.json`: file media types, UTF-8 byte counts and exact-byte SHA-256
  digests, plus the original run and returned-source digests
- `package.zip`: deterministic standard ZIP containing those four exact files

The package is content-addressed by `delivery-` and the SHA-256 of its canonical
manifest with an empty `delivery_id`. The original run and synthesis digests
use the existing `store.digest_text` semantics. The typed exported JSON is a
projection; it is not claimed to be a byte-for-byte copy of the original run
or source JSON. Gateway tokens, host configuration, arbitrary `domain_payload`
objects and unknown metadata fields are not exported. Content in retained
research fields is still user/source content, not executable instructions.

`deliveries/<delivery-id>/` lives beneath the existing run directory. Explicit
preparation writes immutable files, writes the manifest last, then updates the
latest pointer only for a complete current package. Repeated preparation of
unchanged inputs returns the same version. An interrupted pre-manifest write
can be completed using the same exact bytes. A version with a manifest is
never overwritten or silently repaired. GET requests never generate files.

## Read and revision behavior

Each read verifies the file's digest and size. The UI marks missing or changed
files incomplete, and the ZIP endpoint refuses incomplete packages. A malformed
or identity-mismatched manifest is unavailable. Revising retained research and
explicitly preparing produces a new version; the previous version remains
stored. Historical intact versions are readable even when current research has
changed or is unavailable. Reload restores the latest pointer and version list.

Named-human review remains the existing digest-bound synthesis-review path.
Preparing or downloading files neither approves claims nor records a company
decision. A complete package means the fixed files are intact and current;
it does not attest source rights, full-text availability, scientific truth,
commercial demand or subjective acceptance criteria.

## Local API

- `GET /api/v1/delivery`: latest saved version and available version IDs
- `GET /api/v1/delivery/<delivery-id>`: read-only version status
- `POST /api/v1/delivery/prepare`: `moonfind.delivery-prepare.v1` with exact
  `run_id` and currently displayed `source_digest`
- `GET /api/v1/delivery/<delivery-id>/<filename>`: exact stored UTF-8 bytes for
  one of the four filenames above
- `GET /api/v1/delivery/<delivery-id>/package.zip`: validated complete ZIP

The host uses its existing trusted localhost origin/write checks. File names
are fixed; the endpoint is not a general filesystem reader. Reports are served
as `text/plain` with `nosniff`; the UI's explicit Download anchor supplies the
filename. Pack-host URL prefixes are preserved.

## Bounded acceptance

Direct-handler temporary-workspace tests exercise a two-source deterministic
fixture through durable run/result ingestion, package preparation, exact-byte
readback, retained human-review preparation, corruption, missing files,
revisions, history, stale context, malformed manifests, Unicode and large/empty
ZIP contents. UI fixtures exercise the actual API callbacks and download links.
No listener, provider, configured Town transport, external delivery or customer
research is exercised. A general brief, arbitrary requested file sets, criteria
receipts, full child-run revisions, configured execution and Book receiver
qualification remain outside this slice.
