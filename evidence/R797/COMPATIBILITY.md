# R797 test environment and reproducible dependency overlay

Tested with official MoonBit toolchain `moon 0.1.20261016 (1af328f)` and `moonc v0.10.16+b1a0e846e`. The historical source toolchain pin was unavailable. This does not certify historical-toolchain compatibility.

The UI declares `moonbit-community/rabbita@0.12.4`. The official registry dependency was restored with `moon update` and the ordinary MoonBit dependency download. That unmodified dependency fails on this compiler because its HTTP JSON handler uses removed `try?` syntax. The retained `rabbita-http-original.mbt` is the exact original file; its SHA-256 is `de02a7e7b30513c49300ebdffaf95a1d07e21feeb776b88d60c649eefdfe0bcd`.

Apply `rabbita-0.12.4-compat.patch` from the MoonFind root after dependency restoration (`patch -p1 < evidence/R797/rabbita-0.12.4-compat.patch`). It changes only the one `try?` expression to equivalent explicit Result error handling. Patched SHA-256: `755e4e8e2c820405801fb3e505202fffae5012b6dec18f806c4a7e29773b7c82`.

Two existing project files also had removed syntax and include mechanical equivalent edits: `main/json_evidence_coverage.mbt` and `main/csv_comparison_wbtest.mbt` under `ui/rabbita-moonfind`. No dependency version was upgraded. Tests establish behavior with this explicit overlay, not the unmodified dependency.

Commands are run from `ui/rabbita-moonfind` with the toolchain bin on PATH and its directory as MOON_HOME. Use the common workspace native-build lock when sharing this workspace:

- `moon check --target js -j 2`
- `moon test --target js -j 2 --filter '*Atom*'`
- `moon test --target js -j 2 --filter '*RSS*'`

Only JavaScript UI tests are in scope. No native host, live provider, graphical browser interaction, subscription or publication is exercised. The saved-brief round trip is the existing host-shaped protocol fixture. Existing deprecation warnings are retained in logs, not hidden or treated as product feature work.
