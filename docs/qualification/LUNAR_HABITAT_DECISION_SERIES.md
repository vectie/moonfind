# Lunar Habitat Decision Series UI-to-UI qualification

Case ID: `SERIES-UI-001`

Retained 2026-07-31 result:
`LUNAR_HABITAT_DECISION_SERIES_RUN_2026-07-31.md`.

## User goal

A program owner wants one decision-ready package for a modular lunar habitat:
cited assumptions, plan, digital habitat, simulated site mission, robot
readiness observation, and a reviewable three-minute internal animatic. The
owner should not need to understand repository names or runtime internals to
see the current phase and next safe action.

## Honest test boundary

This case may use deterministic local fixtures for media, simulation, and
digital models. It must not claim physical movement, publication, commercial
provider quality, paid-customer acceptance, or financial recommendation.

The test passes the scenario-selection slice when the user can select the
series, understand its six phases, inspect its explicit exclusions, and start
or deliberately stop at the first capability/authority blocker. A complete
cross-product execution pass additionally requires one correlated receipt per
stage and is not inferred from a rendered graph.

## Setup

1. Build MoonFind once after the feature slice is complete.
2. Start the UI host over an isolated research root and retained fixture run.
3. Open `/apps/moonfind/research` through the published host.
4. Preserve the browser console and network log.

The host must return:

```text
GET /api/v1/series
GET /api/v1/series/lunar-habitat-decision-series
```

The selected record must declare `moonsuite.series-use-case.v1`, 6 phases, 38
ordered desired stages, exact operation versions, and the four exclusions.

## UI-to-UI journey

1. In the first viewport, select **Lunar Habitat Decision Series**.
2. Confirm the stated outcome and primary action are visible before evidence
   or diagnostics.
3. Move through the icon-led phase rail:
   **Understand → Research → Plan → Model → Explain → Decide & learn**.
4. Confirm every phase shows its user outcome, owning products, and stage
   count without opening raw JSON.
5. Open **Limits & evidence** and confirm MoonFish, physical command,
   publication, and commercial-master claims are explicitly excluded.
6. Confirm the series goal is **Review the commission and start evidence
   gathering**, then choose the actual read-only action **Validate template**.
7. Confirm the result says only that catalog shape is valid. It must also name
   unresolved capability/semantic projection, source-bundle, live-health,
   request-materialization, authority, and correlated-receipt requirements.
   The UI must not fabricate a run.
8. Reload the page. The selected series and phase remain visible.
9. Inspect the API response and correlate the selected use-case ID and graph
   ID with what the UI shows.
10. Open the MoonDesk context link and confirm it preserves `series`, `phase`,
    and `source` parameters. This is a navigation handoff only: until MoonDesk
    imports the template and MoonFlow projects it, no run may be shown.

## Required retained evidence

```text
_build/ui-to-ui/<run-id>/
  run.json
  browser-console.json
  failed-requests.json
  screenshots/01-series-catalog.png
  screenshots/02-series-selected.png
  screenshots/03-first-action-result.png
```

`run.json` records separate results for scenario visibility, ordinary goal
clarity, first-action behavior, reload recovery, and full execution. A safe
capability denial may pass first-action behavior while full execution remains
`EXPECTED BLOCKED`.
