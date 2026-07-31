# MoonFind series use cases

MoonFind now publishes curated, user-outcome-oriented cross-product scenarios
in addition to the large robotics capability fixture. A series use case is a
typed desired graph plus six or fewer user-visible phases. It is intent, not a
second orchestrator: MoonFlow still projects and advances exact operations,
MoonGate resolves authority and provider access, and MoonClaw remains the only
agent runtime.

## Operator API

The native CLI exposes the catalog:

```sh
moon run cmd/main -- series-catalog
moon run cmd/main -- series-show lunar-habitat-decision-series
```

The MoonFind UI host exposes the same typed records:

```text
GET /api/v1/series
GET /api/v1/series/lunar-habitat-decision-series
```

The response contract is `moonsuite.series-use-case.v1`, registered as
`moonfind/series-use-case@1.0.0`. A series remains non-executable until every
desired stage resolves against one current `moonflow.capability-catalog.v1`.
The graph's `source_digest` binds
`workflows/lunar-habitat-decision-series-source.v1.json`; it is not a freehand
digest copied from a previous composition.

## Lunar Habitat Decision Series

The first series turns an owner commission into:

- accepted requirements and explicit unknowns;
- cited, challenged research evidence;
- a budgeted project plan;
- a traceable habitat model, lunar simulation, and observed robot readiness;
- an evidence-bound three-minute internal animatic;
- a named review decision and Bookkeeper Three-Gap closure.

The visible phases are **Understand → Research → Plan → Model → Explain →
Decide & learn**. The exact desired graph contains 38 stages across MoonBook,
MoonChat, MoonClaw, MoonFind, MoonTown, MoonProj, MoonMold, MoonMoon, MoonRobo,
MoonVis, and MoonCast.

The MoonCast portion deliberately expands the production work instead of
hiding it behind one “generate video” step: approved needs intake, brief,
rights and IP bible, script and claims ledger and storyboard, three separate
reusable visual/voice/music asset paths, and animatic plan/render/approval.
The current creative-decision operation auto-advances ready G0–G2 gates, so the
series verifies those receipts instead of issuing stale duplicate advances.
The final owner decision uses MoonChat review rather than a client portal,
because this series produces an internal animatic and no delivery master.

One desired operation is intentionally unresolved:
`mooncast/needs-intake.approve-and-seed@0.3.0`. MoonCast already owns the
interactive import, decision, and seed service, but has not published that
sequence as one typed MoonFlow capability. Projection must therefore block at
this stage. MoonFlow also needs to preserve stage binding metadata and
materialize auxiliary QC/authority evidence before the later asset and render
steps can execute unattended.

MoonFish is intentionally absent because a securities recommendation would not
help the stated user outcome. Physical commands, publication, and a commercial
video-master claim are also excluded. The internal deterministic animatic does
not stand in for real-provider footage or customer acceptance.

Implementation lives in `series/catalog.mbt`; its validation requires unique,
ordered stages, exact versioned operations, valid visible-phase coverage, and
an explicit desired-graph contract. The JSON Schema is
`schemas/series-use-case.schema.json`.

See [the UI-to-UI qualification](qualification/LUNAR_HABITAT_DECISION_SERIES.md)
for the proportional browser procedure and honest completion boundary.
