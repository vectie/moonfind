# Lunar Habitat Decision Series retained qualification

Date: 2026-07-31
Case: `SERIES-UI-001`
Result: **scenario UX PASS; full execution EXPECTED BLOCKED**

## Tested build and fixture

- UI: `http://127.0.0.1:4313/apps/moonfind/research`
- Fixture root: `/tmp/moonsuite-lunar-series-ui.5rOtSD`
- Retained research run: `humanoid-cross-paper-demo`
- Series: `lunar-habitat-decision-series`
- Graph: `moonfind-lunar-habitat-decision-series-v1`
- Source SHA-256:
  `3c95e516d9d47301a7312cccd69d2fa257a45d7a58fc949c41474508b1b2fab5`
- Evidence directory:
  `_build/ui-to-ui/lunar-habitat-decision-series-2026-07-31/`

The evidence directory contains `run.json`, `browser-console.json`,
`failed-requests.json`, and three screenshots covering catalog visibility,
phase selection, and the first-action result.

## Rendered journey result

| Check | Result | Retained observation |
| --- | --- | --- |
| Scenario visibility | PASS | The first series viewport shows one outcome, primary user, six phases, and 38 desired stages. |
| Ordinary goal clarity | PASS | The primary action is `Validate template`; it is explicitly described as read-only catalog-shape validation. |
| Phase navigation | PASS | `Explain` becomes the current step and the URL records `phase=explain`. |
| Reload recovery | PASS | After reload, `Explain` still reports `aria-current="step"`; `Understand` reports `false`. |
| Limits and evidence | PASS | The UI exposes the contract and graph IDs and excludes MoonFish, physical robot command, publication, and commercial-master authority. |
| First action | PASS | Exactly one `Validate template` action was present. Its result says execution has not started and names capability/semantic projection, source bundle, live health, request materialization, authority, and receipt requirements. |
| MoonDesk context | PASS | The generated link preserves `series=lunar-habitat-decision-series`, `phase=explain`, and `source=moonfind-series-catalog`. The adjacent copy says MoonDesk does not yet import it as a run. |
| Browser diagnostics | PASS | No warning or error console entries were observed during the bounded journey. |
| Full cross-product execution | EXPECTED BLOCKED | No execution claim or synthetic receipt was produced. |

The UI host was also made tolerant of a client disconnect while writing a
response: a failed fallback response can no longer terminate the long-running
host process.

## Independent graph audit

The 38 desired stages request 21 unique versioned operations. Twenty are
published with an exact matching contract. The deliberate missing seam is:

```text
mooncast/needs-intake.approve-and-seed@0.3.0
```

This is the correct first denial for the current iteration. The graph is a
reviewable catalog and UI scenario, not an executable series run.

The remaining execution blockers are:

1. MoonFlow does not yet preserve the graph's `execution_role` and
   `execution_config` bindings through projection and dispatch.
2. The executor has no generic late-bound input mechanism for IDs created by
   earlier stages.
3. A series run needs auxiliary evidence and authority grants in addition to
   one predecessor artifact.
4. MoonCast handlers require concrete project, resource, variant, and reviewer
   bindings that the desired graph cannot yet materialize.
5. MoonCast asset review must distinguish a generated variant from a QC
   finding instead of treating the predecessor artifact as both.
6. Series request bundles, fresh adapter health, driver mapping, correlated
   receipts, and MoonDesk import/run controls are not yet implemented.

## Focused verification

```text
MoonFind series package: 2 tests passed
MoonFind Rabbita UI: 12 tests passed
MoonFind Rabbita production build: passed
MoonFind native UI host check: passed
Rendered SERIES-UI-001 journey: passed with expected execution denial
```

This result qualifies the second-iteration scenario catalog, ordinary user
journey, truthful denial, and navigation handoff. It does not qualify live
providers, external effects, commercial delivery, or complete 38-stage
execution.
