# Moonfind phase plan

## Phase 1 — usable feature path (implemented)

- Generic research watch, paper, claim, summary, question, idea, run, and human-review contracts.
- Live arXiv Atom acquisition plus deterministic humanoid relevance ranking.
- `gpt-5.6-sol` MoonClaw command packet with strict evidence and humanoid-model output contracts.
- Moontown `research-salon` projection where each paper is a participant book and every proposed idea bridges at least two books.
- Versioned `moontown.civic.communication.handoff.v1` envelope binding the scenario to the exact Moonfind producer run.
- Durable `moontown.civic.communication.receipt.v1` import that proves which reducer ran, how many participant books and reviewable outputs were materialized, and which synthesis/review artifacts were written.
- Typed humanoid model specification covering tokens, memory, actions, objectives, training, datasets, simulation, hardware, benchmarks, ablations, safety, and falsification.
- Durable MoonBit CLI run bundle.
- Rabbita research workspace.
- Named-human reviewed deliverable intake into MoonBook Bookkeeper, followed by Bookkeeper-owned outcome binding, plus an assignment-bound MoonFlow observation.

## Phase 2 — governed provider operation (implemented contracts and ports)

- Full-text evidence is admitted only with provider-use and hostile-PDF isolation receipts; page/section locations are mandatory.
- MoonDesk composes and imports the typed graph, then invokes only authority-bound MoonFlow actions backed by the existing MoonClaw host; no secondary runtime exists.
- Moontown reducer output is imported and validated separately from its execution receipt before human review.
- Add research-watch scheduling through generic MoonFlow schedules.
- Crossref, OpenAlex, Semantic Scholar, and licensed-fulltext policy ports are present and deny by default until reviewed terms permit the requested use.

## Phase 3 — experiment execution

- Project accepted humanoid model ideas into MoonCode work orders for dataset adapters, training code, and evaluation harnesses.
- Attach experiment plans to exact paper claims, code commits, datasets, seeds, metrics, and compute receipts.
- Ingest experiment results as positive, negative, or inconclusive evidence; never discard failed ideas.
- Compare baseline and challenger capabilities through MoonFlow assignment records and Moontown longitudinal observations.

## Phase 4 — governed reinforcement loop

- Let MoonBook Bookkeeper classify each accepted outcome with exactly one Three-Gap class.
- Aggregate only named-human accepted findings into a capability proposal.
- Let MoonCode implement reviewed work orders; evaluate before adoption.
- Let MoonFlow activate only reviewed capability versions in shadow/canary/full modes.
- Resolve the assigned capability at MoonClaw run start and record the exact outcome/reward evidence afterward.
- Promote, hold, or roll back only through a named-human settlement.

## Phase 5 — hardening foundation (implemented)

- Durable recovery projection and missing-command reconstruction are implemented; source-specific retry/rate-limit adapters remain provider work.
- Strong content-addressed storage and canonical digests supplied by owning systems.
- Hostile-document admission requires isolated parsing, disabled networking, active-content removal, bounded expansion/pages, instruction/evidence separation by artifact contract, and quarantine on any suspicious signal.
- Comprehensive schema validation, replay, negative, accessibility, and browser tests.
- Provider decisions enforce commercial use, model-input permission, retention, redistribution, expiry, deletion, audit, provenance, and named review.

## Phase 6 — cross-suite robotics composition (implemented)

- A typed humanoid-robotics graph connects MoonWiki, Moonfind, MoonTown,
  MoonChat, MoonProj, MoonCode, MoonMini, MoonMold, MoonRobo, MoonMoon, MoonStat,
  MoonGate, MoonVis, MoonCast, and MoonBook.
- MoonDesk provides the infinite composition canvas and generic selection
  overlay; MoonFlow compiles a dependency-closed, digest-bound run.
- MoonDesk, MoonFlow, and MoonClaw remain the control plane. Physical authority
  is never inferred from canvas inclusion.

## External readiness boundary

Moonfind writes both the backward-compatible raw `moontown-scenario.json` and the preferred versioned `moontown-handoff.json`. An operator runs the handoff through Moontown and imports the resulting receipt with `moonfind record-moontown`. The normal `moonfind review` command fails closed until a completed, run-bound receipt exists. The receipt proves orchestration and durable materialization only; `review_status=pending` is mandatory and does not approve the synthesis. The self-contained `run-fixture` command bypasses this cross-repository prerequisite solely for deterministic pack-local tests.

The software paths now exist and fail closed. A live provider node remains
disabled until its actual contract, credentials, extractor isolation, retention
configuration, and adapter health are present. Those are external operational
facts, not code defaults.

## Release gates

The pack is feature-usable when a live or fixture watch produces a durable research run, a MoonClaw packet, a Moontown scenario, a reviewed model idea, and closed-loop handoffs visible in Rabbita. Production promotion still requires an operational demonstration with licensed full text, the real isolated extractor, real MoonClaw/Moontown execution, restart recovery under failure, reviewed provider terms, and prospective experiment outcomes. The software enforces these gates; a fixture cannot satisfy them.
