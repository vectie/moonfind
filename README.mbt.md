# Moonfind

Moonfind is a MoonSuite domain pack for evidence-backed AutoResearch. It tracks research questions, acquires and normalizes papers, asks MoonClaw to create cited summaries and falsifiable ideas, uses Moontown to challenge bridges across paper-books, and routes reviewed outcomes to MoonBook Bookkeeper for Three-Gap learning.

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

See [Responsibility and testability](docs/RESPONSIBILITY_AND_TESTABILITY.md)
for the executable delegation boundary and layered test model.

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

## Use live arXiv intake

```bash
moon run cmd/main -- prepare-live ~/Research moonfind-2026-07-20
```

The pending run and `moonclaw-command.json` are durable. Execute that command through the existing MoonClaw host, save its JSON result, then:

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
moon run cmd/main -- publish-robotics-graph /path/to/moonbook
```

The infinite canvas shows MoonWiki → Moonfind → MoonTown/MoonChat → MoonProj,
parallel MoonCode/MoonMini/MoonMold work, MoonRobo integration, MoonMoon
simulation, MoonStat evaluation, MoonGate authority review, MoonVis/MoonCast
delivery, and MoonBook Bookkeeper closure. You can exclude declared nodes only when dependency closure
remains valid. Saving creates a source-bound selection overlay; starting the run
compiles a distinct digest-bound graph. MoonDesk, MoonFlow, and MoonClaw remain
the control plane and do not absorb robotics semantics.

The enforcement and dispatch paths for full-text evidence, reducer-output
ingestion, restart recovery, malicious-document isolation, provider licensing,
and MoonDesk-to-MoonFlow/MoonClaw execution are implemented. Production use
still requires real provider contracts, credentials, an isolated extractor,
healthy product adapters, and explicit authority grants; absent external facts
disable the relevant node rather than falling back silently.

## Rabbita UI

```bash
cd ui/rabbita-moonfind
npm install
npm run build
npm run dev
```

The workspace answers one primary question: _which cross-paper humanoid model idea is worth falsifying next, and why?_ Papers, bridges, counter-hypotheses, falsifiers, open evidence gaps, and the Bookkeeper state remain visible together.
