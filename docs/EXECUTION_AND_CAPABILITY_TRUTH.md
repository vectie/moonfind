# Execution and capability truth

MoonFind has no agent runtime. It prepares domain packets, validates research
evidence, and projects durable state. MoonClaw remains the only model/agent
runtime, MoonFlow remains the only graph activation engine, MoonTown owns civic
deliberation, and MoonBook owns reviewed memory and Three-Gap closure.

## Operator call chain

The Rabbita operator path is intentionally two-part:

1. The host builds a `moonflow.capability-catalog.v1` from the active installed
   packs, version-matched `moonflow.adapter.v2` declarations, and unexpired
   health evidence.
2. MoonFind prepares
   `moonfind/research.prepare-analysis@0.1.0` with the exact
   `moonfind/research-run@1.0.0` input,
   `moonfind/moonclaw-research-command@1.0.0` output, authority, evidence
   digest, request ID, attempt ID, and idempotency key.
3. Before submission, the host appends the `prepared` and `submitting`
   revisions to
   `.moonsuite/products/moonfind/runs/<run-id>/capability-execution.jsonl`.
4. The Rabbita client sends the immutable invocation through MoonClaw's generic
   installed-pack capability port. It never calls a model provider.
5. `submitted`, `pending`, `failed`, `unknown`, and successful receipts are
   identity-checked and appended. Restart recovery repeats the same invocation
   only to reconcile the same idempotency key.
6. A successful capability receipt must contain the exact
   `moonclaw.mooncode.v1` command. Rabbita creates/configures a MoonClaw Cowork
   session and submits that command through the existing `/messages` path.
7. The returned Cowork session and run IDs are appended before polling.
   Restart recovery reloads those IDs; it does not create a replacement run.
   The browser posts only a
   `moonfind.moonclaw-session-checkpoint-request.v1`; the trusted host appends
   the session immediately, reads the runtime receipt when a run appears, adds
   its own observation time and durable result reference, and appends the typed
   run observation.
8. Only a completed Cowork run with a durable result reference moves the
   MoonFind execution to `needs-review`.
9. MoonTown challenge, named-human research review, and
   `moonbook/bookkeeper.outcome.close@0.1.0` remain later, independently
   receipted stages. Successful execution is never self-acceptance.

The browser discovers submit, reconcile, and checkpoint URLs from the
MoonFind workspace snapshot. Absence of any required port is an explicit UI
blocker, not a fallback to a direct model call.

## Restart states

| Persisted state | Only safe next action |
|---|---|
| `prepared` | submit once |
| `submitting`, `pending` | reconcile the same capability attempt |
| `unknown` | investigate and reconcile; never blind retry |
| `command-ready` | submit the exact receipt command through Cowork |
| `runtime-submitting` | poll the persisted Cowork session for its run ID |
| `runtime-pending` | poll the persisted Cowork session/run |
| `runtime-unknown` | investigate/reconcile the same Cowork run |
| `runtime-failed` | named operator decision |
| `needs-review` | named-human review |

The append-only journal uses fully synced JSON lines. Recovery ignores a torn
last line and returns the latest complete revision. Request, operation,
attempt, idempotency, and invocation identities cannot change between rows.

## Cross-product graph

[`humanoid-robotics-suite.v1.json`](../workflows/humanoid-robotics-suite.v1.json)
is an exact desired graph, not a runnable MoonFlow graph. Version 3 declares 63
stages over 43 canonical operations and contains no null operation reference.
It binds MoonBook requirements and Bookkeeper closure, three independent
MoonChat decision stages, MoonClaw `wiki` and `mooncode` roles on
`gpt-5.6-sol`, MoonFind research, MoonTown challenge, MoonProj planning,
MoonMold spatial work, MoonRobo integration/readiness observation, MoonMoon
simulation, MoonVis evidence composition, and MoonCast's complete gated
production/edit/review/delivery chain.

`project_desired_graph` resolves stages exclusively from a supplied
`moonflow.capability-catalog.v1`. Its gap suggestions come only from catalog
operations for the requested product. `importable_graph` is `None` unless all
stages match exact product, version, schema, authority, required-claim ceiling,
and health identities; `require_importable_graph` fails closed on any gap. A
single missing or expired operation produces diagnostics but no partial
MoonFlow work model.

MoonBook supplies wiki functionality, so `understand-needs` is not a phantom
MoonWiki product. MoonClaw supplies the only agent runtime; both the wiki check
and software construction use its exact generic goal operation, with roles
`wiki` and `mooncode`, rather than phantom runtimes.

MoonFlow is the execution engine. MoonGate supplies policy/catalog support and
MoonLib supplies shared contracts; neither is a domain work item. MoonEdit and
MoonLeaf are libraries. MoonFish is intentionally excluded from this robotics
book. The graph issues no physical command and no publication request. Its
terminal boundary is MoonRobo readiness observation plus MoonMoon simulation,
immutable MoonCast build/client/final evidence, and a named MoonChat authority
decision; only then may MoonBook Bookkeeper close the outcome.

The template `source_digest` is the SHA-256 of the canonical desired graph with
that self-referential field omitted. `publish-robotics-graph` parses the current
v2 contract and rebinds a target digest from the template graph ID, template
book ID, template digest, declaration revision, and requested MoonBook ID. It
does not search for or replace an old version literal.

Every desired stage owns exactly one initial request artifact named
`requests/<stage-id>.<input-schema>.json`. Predecessor outputs are not listed
there: MoonFlow appends accepted dependency artifacts after registration. The
publisher now requires a complete
`moonfind.robotics-request-materialization.v1` bundle and validates exact
stage/schema/path cardinality, payload digests, registered required fields, and
constant contract fields before writing anything to the MoonBook. The
pack-specific template registry pins all 39 input-schema digests and 21
declared `contract`/`contract_id` constants. Missing or drifted requests reject
the whole publication before the target `flow/` directory is created.

Publication also requires an explicit compiled capability catalog and canonical
evaluation timestamp. The bound v2 intent is preserved as
`flow/desired-graph.json`; `flow/work-graph.json` is the projected
`moonsuite.work-model.v1` (`items`, not desired `stages`). Missing, expired,
authority-drifted, schema-drifted, or claim-exceeding operations therefore fail
before any target file is created. The publisher also snapshots the exact
catalog used for projection at `flow/capability-catalog.json`; MoonDesk passes
that snapshot and a new server-generated evaluation timestamp back to
MoonFlow's conformant validator before import. A synthetic or expired snapshot
remains non-production evidence and fails according to its own health window.

[`humanoid-robotics-requests`](../fixtures/humanoid-robotics-requests)
contains 63 JSON-Schema-valid synthetic requests plus their completeness
ledger. It is an adapter-preflight scenario fixture, not evidence that provider
jobs, customers, publication, or a physical robot are ready.

[`humanoid-robotics-capability-catalog.fixture.v1.json`](../fixtures/humanoid-robotics-capability-catalog.fixture.v1.json)
contains deterministic, short-lived synthetic health attestations for every
operation solely to test projection. Its catalog ID, notice, evidence paths,
and every attestation identify it as fixture-only. It is not packaged as a
production catalog and cannot prove providers, licensing, publication, or
physical readiness.

MoonCast's two `external-effect` stages are bounded provider-generation calls
(`asset-factory.generate` and `production-coordinator.run-pending`). Each
requires an explicit provider grant and records `publication: false`; neither
authorizes distribution or a physical effect.

## Installation health

[`adapter-declaration.v1.json`](../adapters/moonflow/adapter-declaration.v1.json)
publishes the real MoonFind manifest tools under `moonflow.adapter.v2`.
[`adapter-health.template.v1.json`](../adapters/moonflow/adapter-health.template.v1.json)
is deliberately `unavailable`: only the installed host can observe credentials,
provider reachability, and executable adapter wiring and issue a short-lived
healthy attestation. A repository fixture cannot satisfy that operational gate.
