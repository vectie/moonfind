# RIS intake verification — 2026-10-08

- Native `cmd/ui_host` product build: passed with the pinned MoonBit toolchain.
- Rabbita release JS product build and static packaging: passed.
- Root native and separate UI JS typechecks: passed.
- Native focused tests: 4 passed (existing brief contract, RIS parser, and RIS
  save/reopen/dossier storage). The storage test checks BOM/CRLF and exact bytes.
- Compiled UI tests: 2 passed, including the real localhost native host workflow.
- Three-record local fixture: Unicode titles/authors, repeated authors, date
  aliases, DOI/URL, and multiline abstract parsed. `GARCÍA` returned records 1
  and 3 in both UI filtering and the HTTP intake API.
- Selection, save, reopen and dossier download: passed. Exported original RIS
  matched the fixture byte for byte; the selection JSON contained only 1 and 3.
- `moon fmt`, regenerated public interfaces, and `git diff --check`: completed.

The UI test supplies file-picker completion to the real compiled reducer and
uses real HTTP commands to the built native host. No manual browser/file-picker
session, whole-suite test claim, remote citation provider, live research or
paid API is included. Existing compiler deprecation warnings remain.

See [usage and reproduction](RIS_BIBLIOGRAPHIES.md). The two small `.mbtx`
helpers package the built UI and exercise the host; they do not alter providers
or repository dependencies.
