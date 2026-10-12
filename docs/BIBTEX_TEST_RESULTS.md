# BibTeX workflow verification

Verified locally on Linux with the pinned MoonBit toolchain, without providers,
remote citation lookups, publication or user-computer access.

- Native root check and JavaScript UI check passed
- Native host build and release Rabbita JavaScript build passed
- Native and UI interface generation passed
- Six focused native tests passed: two BibTeX parser tests, one complete BibTeX
  host intake/save/reopen/dossier test, and three existing RIS regression tests
- Four compiled UI tests passed through the real local native HTTP host: BibTeX
  import/search/select/save/reopen/export, its interrupted-import check, and the
  corresponding two existing RIS tests
- The BibTeX UI proof searches by Unicode author, citation key, year and keyword;
  preserves selection across filters; and reopens two selected cards from three
  original records. Exported `.bib` bytes match the input exactly
- The saved selection is used as the strongest local capture in an editable
  offline comparison. Markdown and restorable JSON contain the cited keys,
  user's uncertainty and proposed next experiment

The native API proof also checks case-insensitive filtering independently of the
UI, while the dossier contains the original `.bib`, structured selection, readable
brief and manifest. Relevant source files were formatted; unrelated baseline
format/interface noise was restored. Private dependency inventories remain
unchanged.

These are focused compiled UI, API and native tests, not a whole-suite test run,
manual browser/file-picker qualification, TeX-rendering test or provider-backed
research delivery. Existing compiler deprecation warnings remain. See
`docs/BIBTEX_BIBLIOGRAPHIES.md` for supported syntax and explicit parser limits.
