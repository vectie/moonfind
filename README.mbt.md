# MoonFind

> **Domain pack · evidence-backed research alpha.** Read the
> [product contract](docs/PRODUCT_CONTRACT.md) for provider licensing,
> hostile-document isolation, the closed loop and release gates.

MoonFind is a MoonSuite domain pack for evidence-backed AutoResearch. It tracks research questions, acquires and normalizes papers, asks MoonClaw to create cited summaries and falsifiable ideas, uses MoonTown to challenge bridges across paper-books, and routes reviewed outcomes to MoonBook Bookkeeper for Three-Gap learning.

The first specialization is humanoid robotics model research over arXiv. Domain semantics stay in `humanoid/`; the reusable research graph stays in `research/`. The implementation is MoonBit-native and the application UI is Rabbita. There is no Python runtime or secondary agent runtime.

## Product loop

```text
Research watch
  → arXiv point-in-time paper records
  → deterministic domain relevance ranking
  → MoonClaw gpt-5.6-sol analysis packet
  → evidence-backed summaries, claims, questions, ideas
  → Moontown research salon across paper-books
  → named-human review
  → MoonBook outcome binding
  → Bookkeeper Three-Gap analysis
  → reviewed capability proposal
  → MoonFlow canary/shadow activation
  → next MoonClaw run resolves the assigned capability
  → observed experiment outcome returns to Bookkeeper
```

Moonfind never installs a capability or approves its own output. Model ideas are proposals until evidence and a named human review say otherwise.

MoonFind also exposes an optional [public listing search adapter](docs/PUBLIC_LISTING_SEARCH_ADAPTER.md)
for MoonTown's exact sanitized `moonsuite.public-listing.v1` cards. It performs
deterministic, explainable organic retrieval only; Town continues to own
publication, recommendations, sponsorship, notifications and messaging.

See [Responsibility and testability](docs/RESPONSIBILITY_AND_TESTABILITY.md)
for the executable delegation boundary and layered test model.
See [Execution and capability truth](docs/EXECUTION_AND_CAPABILITY_TRUTH.md)
for the restart-safe installed-pack → MoonClaw Cowork call chain.

## Run the complete fixture

```bash
moon run cmd/main -- run-fixture /tmp/moonfind-workspace fixtures
moon run cmd/main -- status /tmp/moonfind-workspace humanoid-cross-paper-demo
moon run cmd/main -- export-ui /tmp/moonfind-workspace humanoid-cross-paper-demo ui/rabbita-moonfind/public/moonfind-workspace.json
```

The run is written below `.moonsuite/products/moonfind/runs/<run-id>/` with:

- the normalized and ranked paper set;
- a MoonClaw command bound to `gpt-5.6-sol` and `moonfind.humanoid.synthesis`;
- the validated analysis and human-review state;
- a Moontown `research-salon` scenario;
- a versioned Moontown handoff bound to the Moonfind run;
- a MoonBook Bookkeeper deliverable candidate, ready for its own durable review before outcome binding;
- a MoonFlow capability observation;
- a Rabbita workspace projection.

For UI-to-UI qualification, stop before the legacy fixture applies its direct
terminal review:

```bash
MF_QUAL="$(mktemp -d /tmp/moonfind-ui-qualification.XXXXXX)"
moon run cmd/main -- prepare-fixture "$MF_QUAL/suite" fixtures
```

This leaves `humanoid-cross-paper-demo` at `human-review`, with a typed
MoonTown handoff and no `human-review.json`. Follow the
[UI-to-UI guide](docs/qualification/UI_TO_UI_USE_CASES.md) to exercise the
governed MoonTown, MoonChat, and MoonBook path.

## Use live arXiv intake

```bash
moon run cmd/main -- prepare-live ~/Research moonfind-2026-07-20
```

The pending run is durable. The production operator path first invokes
`moonfind/research.prepare-analysis@0.1.0` through MoonClaw's generic
installed-pack seam, appends every attempt/receipt revision, and only then
submits the exact resulting command through the existing MoonClaw Cowork
gateway. The Cowork session/run identity is appended before polling. Save its
durable JSON result, then:

```bash
moon run cmd/main -- complete ~/Research moonfind-2026-07-20 analysis-result.json
moon run cmd/main -- review ~/Research moonfind-2026-07-20 human-review.json
```

Before full text can enter the MoonClaw packet, record a
`moonfind.full-text-evidence.v1` artifact. The command fails closed unless the
provider-use decision allows the exact use, the hostile-PDF isolation receipt
is bound to the PDF digest, active content was removed with networking disabled,
the expansion/page limits pass, and page/section evidence locations exist:

```bash
moon run cmd/main -- record-fulltext ~/Research moonfind-2026-07-20 full-text-evidence.json
moon run cmd/main -- resume ~/Research moonfind-2026-07-20
```

`resume` rebuilds a missing MoonClaw packet from durable run/full-text records
and writes `recovery.json` with the next idempotent action. It never invents a
completed stage.

The arXiv adapter remains a public development/research adapter. Provider
policy records for Crossref, OpenAlex, Semantic Scholar, and a licensed
full-text port are present, but are deny-by-default until a named review records
usable terms. Validate an intended use with:

```bash
moon run cmd/main -- validate-provider provider-policy.json use-request.json
```

## Run the current Moontown handoff

Moonfind and Moontown remain separate products. Moonfind writes a versioned handoff; Moontown consumes it through its existing civic runtime and writes a machine-readable receipt. MoonDesk now exposes the generic MoonFlow composition canvas and can invoke authority-bound actions published by MoonFlow. Moonfind still does not call a model provider directly: the installed MoonClaw host remains the only agent runtime. The equivalent operator path is:

```bash
RUN_DIR="$HOME/Research/.moonsuite/products/moonfind/runs/moonfind-2026-07-20"
RECEIPT="/tmp/moonfind-2026-07-20-moontown-receipt.json"

cd ../moontown
moon run src/cmd/main -- civic protocols pattern-handoff \
  "$RUN_DIR/moontown-handoff.json" "$RECEIPT" "$HOME/Research/.moontown"

cd ../moonfind
moon run cmd/main -- ingest-moontown \
  "$HOME/Research" moonfind-2026-07-20 "$RECEIPT" \
  "$HOME/Research/.moontown/books/wenyu-social-square/raw/bootstrap/civic-communication-results.json"
```

The production route uses Moontown's existing MoonClaw reducer. `pattern-handoff-fixture` exists only for deterministic integration testing. The normal `moonfind review` command refuses to proceed until both the run-bound receipt and typed reducer output have been ingested. A completed receipt must still say `review_status: pending`; Bookkeeper/human review is a separate authority gate. The self-contained `run-fixture` command bypasses the cross-repository prerequisite only as a pack-local fixture.

## Compose a cross-suite robotics job

Publish Moonfind's typed robotics graph into a MoonBook, open that book in
MoonDesk, and switch to MoonFlow:

```bash
moon run cmd/main -- publish-robotics-graph \
  /path/to/moonbook \
  fixtures/humanoid-robotics-requests \
  fixtures/humanoid-robotics-capability-catalog.fixture.v1.json \
  2026-07-31T12:00:00Z
```

The JSON is a 63-stage exact desired graph, never a runnable graph. Every stage
uses a canonical operation, schema, authority, and claim class. MoonBook owns
wiki requirements and Bookkeeper closure; MoonClaw is the only runtime and
runs the `wiki` and `mooncode` roles with `gpt-5.6-sol`. MoonChat owns the
owner, stakeholder, and final authority decisions. The MoonCast tail is a
complete staged production and cut-editor flow through immutable delivery,
client decision, and final evidence—not a monolithic video or publication
call.

`project_desired_graph` shows catalog-derived suggestions for every gap and
emits no `moonsuite.work-model.v1` object unless the entire selected graph is
exactly conformant, healthy, and within its claim ceiling. One missing or
expired operation blocks the entire import. MoonFlow executes; MoonGate and
MoonLib are support-only; MoonEdit and MoonLeaf remain libraries. MoonFish is
outside the robotics book. There is no physical command and no publication
stage.

The checked-in capability catalog beside the workflow is deterministic
fixture-only data. It is deliberately marked synthetic and is not packaged as
production health evidence.

Publication is fail-closed on request materialization. Every one of the 63
stages has exactly one first, pack-owned typed request; MoonFlow appends
dependency outputs later. The publisher requires a complete
`moonfind.robotics-request-materialization.v1` ledger, checks exact
stage/schema/path coverage, payload digests, required top-level fields, and
registered constants, then copies the requests and graph into the target
MoonBook. The bundled request set is schema-valid synthetic scenario data for
projection/adapter preflight only. Replace it with an equivalently complete
validated bundle for real work.

The catalog and evaluation timestamp are explicit. The publisher preserves
bound intent as `flow/desired-graph.json`, projects it against that exact
healthy catalog, writes the resulting `moonsuite.work-model.v1` to
`flow/work-graph.json`, and snapshots the exact evaluated catalog as
`flow/capability-catalog.json` for MoonDesk/MoonFlow validation and replay.
The timestamp above is valid only inside the short-lived synthetic fixture
health window.

The pack contains enforcement contracts and local paths for full-text evidence,
reducer-output ingestion, restart recovery, malicious-document isolation,
provider licensing, and MoonDesk-to-MoonFlow/MoonClaw execution. Production use
still requires real provider contracts, credentials, a deployed isolated
extractor, conformant product adapters and explicit authority grants. The
desired composition JSON is not itself proof of those external facts.

## Rabbita UI

```bash
cd ui/rabbita-moonfind
npm install
npm run build
npm run dev
```

The workspace answers one primary question: _which cross-paper humanoid model idea is worth falsifying next, and why?_ Papers, bridges, counter-hypotheses, falsifiers, open evidence gaps, and the Bookkeeper state remain visible together.
