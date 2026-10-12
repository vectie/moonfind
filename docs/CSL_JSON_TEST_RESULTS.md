# CSL JSON workflow verification

Qualified locally on 8 October 2026 with the pinned recovery compiler and real
private frozen dependency copies.

- Native root and JS UI aggregate typechecks passed.
- Native aggregate: 106 tests passed. Five CSL parser/host tests cover Unicode,
  BOM/CRLF, personal/literal/editor names, date ranges/literal dates, typed and
  large numeric IDs, malformed exports, size limits, source selection and exact
  saved/reopened ZIP contents. Existing RIS/BibTeX tests also passed.
- Compiled UI aggregate: 160 tests passed. Environment-dependent tests may skip
  their native portion without a configured fixture host.
- The separate real-host runner passed seven compiled UI tests: three CSL tests
  plus four RIS/BibTeX regressions. Its required completion marker proves the
  actual HTTP path ran. CSL includes malformed-export recovery, ID/key/author/
  editor/date/keyword/DOI search, persistent filtered selection, save/reopen,
  readable cards, HTML text escaping, native dossier download, cancellation,
  repeated pending actions, stale responses and source-slot limits.
- Actual brief Markdown, dossier ZIP, selected-reference JSON and downstream
  comparison Markdown/restorable JSON were exported. The ZIP's original JSON
  was compared byte for byte with the fixture. The comparison remains editable
  and source-bound after a JSON round-trip.
- Native host and release JS UI builds passed. The staged UI entry was served by
  the native loopback host. Interfaces were regenerated; focused formatting and
  Git whitespace checks passed.

This is compiled UI/controller/render and local HTTP qualification, not a
pixel-based browser/file-picker or Mac test. Existing compiler deprecation
warnings remain. No provider, reference-manager account, URL retrieval, external
publication, scientific verification or provider-backed research was exercised.
The fixture contains synthetic references. Supported CSL fields and remaining
format limits are documented in [the user guide](CSL_JSON_BIBLIOGRAPHIES.md).
