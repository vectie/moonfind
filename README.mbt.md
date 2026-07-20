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

The arXiv adapter is a public development/research adapter. Any paid deployment must verify source terms, retention, redistribution, and downstream PDF licenses.

## Rabbita UI

```bash
cd ui/rabbita-moonfind
npm install
npm run build
npm run dev
```

The workspace answers one primary question: _which cross-paper humanoid model idea is worth falsifying next, and why?_ Papers, bridges, counter-hypotheses, falsifiers, open evidence gaps, and the Bookkeeper state remain visible together.
