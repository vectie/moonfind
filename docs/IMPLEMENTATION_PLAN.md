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

## Phase 6 — cross-suite robotics composition (exact desired graph implemented)

- The humanoid-robotics file is a desired graph, not an executable graph.
  MoonMini, MoonStat, phantom MoonWiki, and phantom MoonCode product identities
  are removed. All 63 stages use canonical `product/tool@pack-version`
  identities and exact input/output, authority, and claim contracts.
- Catalog projection now emits suggestions from real installed operations and
  emits no importable MoonFlow graph until every stage conforms, including
  required-claim ceilings and short-lived health.
- The 48-stage MoonCast episode tail preserves separate brief, rights, bible,
  script, storyboard, animatic, provider routing, asset factory, QC, cut
  editor, preview, export, master, three-party review, delivery build, client
  decision, and immutable final-evidence operations. It has no publication
  stage.
- MoonDesk provides the infinite composition canvas and generic selection
  overlay; MoonFlow compiles a dependency-closed, digest-bound run.
- MoonFlow is the engine; MoonGate/MoonLib are support-only and MoonEdit/
  MoonLeaf are libraries. MoonClaw is the sole runtime. Physical authority is
  never inferred from canvas inclusion.
- The publisher parses the v2 desired-graph contract and derives target
  graph/book/digest identity from the current template; no historical v1
  literal replacement remains.
- The publisher requires and materializes a complete 63-request bundle. Each
  first artifact is the exact pack-owned request schema; dependency evidence is
  appended by MoonFlow rather than duplicated in graph inputs. The checked-in
  bundle is schema-valid fixture data and remains explicitly non-production.
- Exit gate: every node is derived from the capability registry, every edge
  passes schema/authority/claim/health conformance, and the full graph completes
  with production (non-fixture) attestations, restart, and evidence replay.

## Phase 7 — MoonClaw execution recovery (software implemented; host wiring pending)

- The exact installed-pack invocation, attempt, idempotency key, receipt, and
  subsequent Cowork session/run identities have an append-only MoonBit journal.
- Unknown capability outcomes reconcile through the same MoonClaw invocation;
  unknown Cowork outcomes poll the same persisted run. Neither path creates a
  replacement runtime.
- Rabbita consumes host-published generic submit/reconcile/checkpoint ports,
  executes the capability-produced command through MoonClaw Cowork, and keeps
  named-human review unavailable until the durable runtime result is
  `needs-review`.
- Exit gate: the deployment host must publish an active installed MoonFind
  pack, compiled capability catalog, short-lived healthy adapter attestation,
  and the three generic HTTP ports. Repository fixtures cannot claim this.

## External readiness boundary

Moonfind writes both the backward-compatible raw `moontown-scenario.json` and the preferred versioned `moontown-handoff.json`. An operator runs the handoff through Moontown and imports the resulting receipt with `moonfind record-moontown`. The normal `moonfind review` command fails closed until a completed, run-bound receipt exists. The receipt proves orchestration and durable materialization only; `review_status=pending` is mandatory and does not approve the synthesis. The self-contained `run-fixture` command bypasses this cross-repository prerequisite solely for deterministic pack-local tests.

The software paths now exist and fail closed. A live provider node remains
disabled until its actual contract, credentials, extractor isolation, retention
configuration, and adapter health are present. Those are external operational
facts, not code defaults.

## Release gates

The pack is feature-usable when a live or fixture watch produces a durable research run, a MoonClaw packet, a Moontown scenario, a reviewed model idea, and closed-loop handoffs visible in Rabbita. Production promotion still requires an operational demonstration with licensed full text, the real isolated extractor, real MoonClaw/Moontown execution, restart recovery under failure, reviewed provider terms, and prospective experiment outcomes. The software enforces these gates; a fixture cannot satisfy them.
