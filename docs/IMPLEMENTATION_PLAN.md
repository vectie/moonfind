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

## Phase 2 — real-provider operation

- Add PDF/full-text acquisition behind source-specific license and retention metadata.
- Add citation-location extraction from section/page spans rather than abstract-only locations.
- Let MoonDesk submit the versioned handoff to Moontown and invoke the existing MoonClaw host automatically; do not embed another runtime in MoonDesk, Moonfind, or Moontown.
- Import Moontown reducer output as a separately versioned critique/synthesis record before human review.
- Add research-watch scheduling through generic MoonFlow schedules.
- Add connectors for Semantic Scholar, Crossref, OpenAlex, licensed full-text feeds, and private corpora as pack-local providers, with an explicit permitted-use/retention/redistribution policy for each provider.

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

## Phase 5 — deferred hardening

- Source rate limits, retries, checkpointing, restart recovery, and stale-run handling.
- Strong content-addressed storage and canonical digests supplied by owning systems.
- Treat PDFs and retrieved documents as hostile input: isolate parsing, strip active content, constrain size/decompression, separate quoted evidence from instructions, and quarantine suspicious documents.
- Comprehensive schema validation, replay, negative, accessibility, and browser tests.
- Broader provider licensing and compliance review, including commercial reuse, model-input permission, retention, redistribution, provenance, deletion, and audit obligations.

## Current manual handoff boundary

Moonfind writes both the backward-compatible raw `moontown-scenario.json` and the preferred versioned `moontown-handoff.json`. An operator runs the handoff through Moontown and imports the resulting receipt with `moonfind record-moontown`. The normal `moonfind review` command fails closed until a completed, run-bound receipt exists. The receipt proves orchestration and durable materialization only; `review_status=pending` is mandatory and does not approve the synthesis. The self-contained `run-fixture` command bypasses this cross-repository prerequisite solely for deterministic pack-local tests.

Automatic submission from MoonDesk, full-text evidence, reducer-output ingestion, restart recovery, malicious-document isolation, and broader licensed-provider operation are deliberately not claimed by Phase 1.

## Release gates

The pack is feature-usable when a live or fixture watch produces a durable research run, a MoonClaw packet, a Moontown scenario, a reviewed model idea, and closed-loop handoffs visible in Rabbita. It is not production-research ready until full-text evidence, real MoonClaw/Moontown execution, restart recovery, source governance, and prospective experiment outcomes are demonstrated.
