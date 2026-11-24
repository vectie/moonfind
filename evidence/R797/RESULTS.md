# R797 focused verification

2026-10-20 UTC, restored cloud source copy.

- `moon test --target js -j 2 --filter '*Atom*'`: 6 passed, 0 failed. Final rerun after UI copy and formatting: passed.
- `moon test --target js -j 2 --filter '*RSS*'`: 9 passed, 0 failed.
- `moon check --target js -j 2`: passed, 149 warnings, 0 errors.
- `moon info --target js`: passed, 79 warnings, 0 errors; generated public signature file unchanged.

Tests cover original-byte retention, entry metadata and inert HTML rendering, default/prefixed Atom namespaces, empty feed, explorer search and record selection, projected CSV, add-to-brief, browser-local draft restore, host-shaped saved-brief reopening, stale/cancelled/unsupported capture handling, and actual chooser behavior with mocked DOM boundary.

Fixture: `fixtures/local-research-feed.atom`. User guide: `docs/LOCAL_ATOM_RESEARCH.md`.

Toolchain and necessary explicit dependency/source compatibility edits are described in `COMPATIBILITY.md`. The unmodified Rabbita dependency failed before the documented patch. No native host, graphical browser, live-source or full-suite gate is represented as passed. Independent review and batch release/delivery remain the parent's responsibility.
