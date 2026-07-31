# MoonFind UI-to-UI qualification

Last reviewed: 2026-07-31

MoonFind's published application is the Rabbita research studio declared by
`pack.json`:

```text
entrypoint id: research-studio
service path:  /apps/moonfind/research
default port:  4313
```

MoonFind owns research evidence, the research decision form, and the portable
handoffs it produces. It does not execute models directly, accept MoonBook
records, or activate learned capabilities. MoonClaw is the only agent runtime;
MoonTown owns the research-salon reduction; MoonChat records the portable
conversation review; MoonBook owns final Bookkeeper review and Three-Gap
learning.

## Prerequisites

- MoonBit and Node/npm are installed.
- The MoonFind checkout is `/Users/kq/Workspace/moonfind`.
- A durable MoonFind run exists below one workspace root.
- The Rabbita bundle has been built.
- For the positive MoonTown path, MoonTown is reachable at
  `http://127.0.0.1:17842`.
- For a live analysis run, the trusted MoonClaw gateway and the generic
  capability submit/reconcile endpoints must be supplied to the host. Fixture
  data cannot satisfy that production acceptance condition.

Prepare an isolated qualification workspace:

```sh
export MF_REPO=/Users/kq/Workspace/moonfind
export MF_QUAL="${MF_QUAL:-$(mktemp -d /tmp/moonsuite-research-ui-qualification.XXXXXX)}"

cd "$MF_REPO"
moon run cmd/main -- prepare-fixture "$MF_QUAL/suite" "$MF_REPO/fixtures"

cd "$MF_REPO/ui/rabbita-moonfind"
npm ci
npm run build

cd "$MF_REPO"
moon run cmd/ui_host -- \
  --workspace "$MF_QUAL/suite" \
  --run-id humanoid-cross-paper-demo \
  --book-workspace "$MF_QUAL/book" \
  --moontown-base http://127.0.0.1:17842 \
  --port 4313
```

Keep `MF_QUAL` in the same shell for the MoonTown, MoonChat, and MoonBook
steps. The random disposable directory prevents one qualification run from
silently reusing another run's receipts.

Keep the host terminal open. Open:

```text
http://127.0.0.1:4313/apps/moonfind/research
```

The checked-in `prepare-fixture` path stops at the pre-review state so the
governed UI can be exercised. `run-fixture` remains the legacy terminal smoke
fixture. Neither is evidence that arXiv/full-text licensing, a live MoonClaw
model run, or a commercial provider has passed.

Because `prepare-fixture` materializes analysis without inventing a live
execution journal, **Research execution** truthfully reports that no prepared
execution exists. The typed MoonTown handoff remains `ready`; this fixture
blocker must not be misread as a failed handoff.

## MF-01 — inspect an evidence-backed research run

Purpose: prove that the published UI shows durable research truth rather than a
static demo.

1. Open the research-studio URL.
2. Confirm the title and run phase render.
3. In **Research execution**, confirm the operation, durable state, request,
   attempt, revision, and next action are visible when an execution record
   exists. For a terminal fixture, the UI must explicitly say that a live
   MoonClaw operator is not required.
4. In the evidence area, inspect the ranked papers, summaries, bridges,
   candidate ideas, counter-hypotheses, falsifiers, and open evidence gaps.
5. Confirm the page distinguishes reported evidence from synthesis and keeps
   review state visible.
6. Open **Humanoid robotics composition** and confirm it describes a desired
   63-stage graph as catalog-bound planning, not as proof of execution.

Expected visible result:

- product identity is `moonfind`;
- data comes from `GET /api/v1/workspace`;
- the durable run id is `humanoid-cross-paper-demo`;
- unavailable provider/runtime facts appear as blockers, never as success;
- the robotics graph says physical commands and publication are excluded.

Primary evidence:

```text
$MF_QUAL/suite/.moonsuite/products/moonfind/runs/humanoid-cross-paper-demo/run.json
$MF_QUAL/suite/.moonsuite/products/moonfind/runs/humanoid-cross-paper-demo/workspace.json
```

Recovery:

- If the page says that the durable workspace does not exist, verify
  `--workspace` and `--run-id`.
- If the browser shows an older UI, rebuild `ui/rabbita-moonfind` and restart
  `cmd/ui_host`; do not rely on a retained browser DOM.
- If a nonterminal run reports no MoonClaw gateway, restart the trusted host
  with the verified gateway and capability endpoints. Do not enter a provider
  URL in the browser.

## MF-02 — governed MoonTown handoff

Purpose: prove that MoonFind can expose an exact typed handoff without claiming
that synthesis already happened.

1. Complete MF-01 and start MoonTown using its qualification guide.
2. In **Challenge in MoonTown**, confirm the handoff state is `ready`.
3. Click **Open typed handoff in MoonTown**.
4. The new MoonTown surface must show the same handoff id, producer run,
   participant books, review owner, and `PENDING · NOT EXECUTED`.
5. Follow MoonTown use case MT-02.
6. Return to MoonFind and reload the research studio.

Expected visible result after MoonTown returns:

- the handoff state becomes `ingested-pending-review`;
- a completed MoonTown receipt and correlated reducer output are visible;
- MoonFind still says named-human review is pending.

Primary evidence:

```text
$MF_QUAL/suite/.moonsuite/products/moonfind/runs/humanoid-cross-paper-demo/moontown-handoff.json
$MF_QUAL/suite/.moonsuite/products/moonfind/runs/humanoid-cross-paper-demo/moontown-receipt.json
$MF_QUAL/suite/.moonsuite/products/moonfind/runs/humanoid-cross-paper-demo/moontown-reducer-output.json
$MF_QUAL/suite/.moonsuite/products/moonfind/runs/humanoid-cross-paper-demo/moontown-result-ingest-v1.json
```

## MF-03 — prepare a bounded named-human review

Purpose: prove that MoonFind captures the human decision but does not apply it
as accepted knowledge.

1. Complete MF-02.
2. Enter a real reviewer name.
3. Choose **Approve a named subset**.
4. Enter only exact visible idea/claim ids in **Decision scope**, separated by
   commas.
5. Enter a concrete rationale.
6. For every Three-Gap severity greater than zero, enter an evidence statement.
7. Click **Prepare MoonChat review bundle**.

Expected visible result:

- the durable review state changes from `ready-for-human-review` to
  `awaiting-moonchat`;
- the page shows a **MOONCHAT BUNDLE** reference;
- the operation is exactly
  `moonchat/conversation.review.record@0.1.0`;
- the page does not show MoonBook acceptance or capability activation.

Primary evidence:

```text
$MF_QUAL/suite/.moonsuite/products/moonfind/runs/humanoid-cross-paper-demo/cross-product-review-decision.json
$MF_QUAL/suite/.moonsuite/products/moonfind/runs/humanoid-cross-paper-demo/moonchat-review-bundle.json
```

Continue with
[`CROSS_PRODUCT_RESEARCH_LOOP.md`](CROSS_PRODUCT_RESEARCH_LOOP.md).

## MF-N1 — reject an unbounded approval

Purpose: confirm that browser validation fails before mutation.

1. Reload a run in `ready-for-human-review`.
2. Enter a reviewer and choose **Approve a named subset**.
3. Leave **Decision scope** empty.
4. Click the prepare action.

Expected visible result:

- the UI reports that exact idea/claim ids are required;
- no portable review bundle is written;
- review phase remains idle.

Repeat with a positive gap severity and an empty gap statement. The UI must
reject that request too.

## MF-N2 — fail closed on unavailable or mismatched products

Use one failure at a time:

- stop MoonTown before loading the research studio;
- change the MoonTown link's `handoff_id`;
- point `handoff_url` to a non-loopback host;
- open a nonterminal run without a verified MoonClaw gateway.

Expected visible result:

- the action is disabled or the receiving UI shows a specific blocked state;
- no synthesis, review, or accepted outcome is claimed;
- retry requires restoring the exact endpoint/identity and reloading or
  reconciling the same durable attempt.

## Qualification record

Record each run with:

```text
date:
operator:
MoonFind commit:
workspace:
run id:
browser URL:
MF-01: PASS | FAIL | BLOCKED
MF-02: PASS | FAIL | BLOCKED
MF-03: PASS | FAIL | BLOCKED
MF-N1: PASS | FAIL | BLOCKED
MF-N2: PASS | FAIL | BLOCKED
receipt refs:
screenshots:
notes:
```

Do not mark live-adapter acceptance from the deterministic fixture.
