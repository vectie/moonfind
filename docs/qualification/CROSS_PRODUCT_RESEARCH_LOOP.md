# Cross-product research loop qualification

Last reviewed: 2026-07-31

This guide qualifies the visible and durable call chain:

```text
MoonFind evidence UI
  → MoonTown governed research salon UI
  → MoonFind named-human decision UI
  → MoonChat portable append-only review
  → MoonFind verified result
  → MoonBook existing Rabbita Bookkeeper UI
  → Three-Gap review gates
```

MoonClaw is the only agent runtime. MoonFlow owns generic orchestration and
handoff state. MoonChat intentionally has no standalone UI. MoonBook's existing
Rabbita application is the only Bookkeeper review surface.

## 1. Start isolated services

Use the per-product guides:

- [MoonFind](UI_TO_UI_USE_CASES.md)
- [MoonTown](../../../moontown/docs/qualification/UI_TO_UI_USE_CASES.md)
- [MoonChat](../../../moonchat/docs/qualification/UI_TO_UI_USE_CASES.md)
- [MoonBook](../../../moonbook/docs/qualification/UI_TO_UI_USE_CASES.md)

Expected local URLs:

```text
MoonFind  http://127.0.0.1:4313/apps/moonfind/research
MoonTown  http://127.0.0.1:17842/index.html?seed=20260727
MoonBook  http://127.0.0.1:4321/apps/moonbook/
```

## 2. MoonFind → MoonTown

1. In MoonFind, inspect the evidence and open **Challenge in MoonTown**.
2. Click **Open typed handoff in MoonTown**.
3. In MoonTown, verify the exact producer run, handoff id, participant books,
   topic, review owner, and pending state.
4. Click **Start governed salon** once.
5. Wait for **RETURNED · REVIEW PENDING**.
6. Return to MoonFind and reload.

Pass criteria:

- MoonTown used its existing civic runtime and MoonClaw reducer;
- MoonFind received a completed receipt plus typed non-empty reducer output;
- the synthesis is still pending review;
- retry/reconcile reuses the same attempt.

## 3. MoonFind → MoonChat

When MoonDesk launches this work item, MoonFind opens through the installed
pack route with two opaque correlation values:

```text
/pack-apps/moonfind/?moonflow_run=<run-id>&moonflow_handoff=<opaque-token>
```

The MoonFlow receiver panel must show the exact work item, declaration,
operation, requested authority, contracts, evidence, review requirement, and
acceptance criterion before the operator continues. The token is correlation,
not authority; never copy one between runs or construct one manually.

1. In MoonFind, enter the named reviewer, bounded decision, exact ids,
   rationale, and explicit Three-Gap observations.
2. Click **Prepare MoonChat review bundle**.
3. Confirm state `awaiting-moonchat`.
4. For a MoonDesk-launched work item, click **Return reviewed bundle to
   Flow**, confirm the immutable receiver receipt, then use **Return to Flow**.
5. Confirm MoonFlow accepted the MoonFind work item and exposed the declared
   MoonChat work item; it must not show MoonBook acceptance.

The receiver receipt contains the local-workspace authority, review, and
output evidence plus the aggregate bundle digest. It proves only that the exact
named-human decision, Three-Gap statements, and portable bundle exist. It does
not execute MoonChat and does not claim MoonBook acceptance.

In a normal installed run MoonFlow invokes MoonChat's declared operation. The
following pack-local command is the exact manual equivalent for qualification
when the generic MoonFlow operator is not running.

```sh
: "${MF_QUAL:?Run the MoonFind qualification launch steps and preserve MF_QUAL}"
export RUN=humanoid-cross-paper-demo
export RUN_BASE=".moonsuite/products/moonfind/runs/$RUN"
export BUNDLE_REF="$RUN_BASE/moonchat-review-bundle.json"
export BUNDLE="$MF_QUAL/suite/$BUNDLE_REF"
export SOURCE_REF="$(jq -r '.source_artifact_ref' "$BUNDLE")"
export SOURCE="$MF_QUAL/suite/$SOURCE_REF"
export BUNDLE_SHA="sha256:$(shasum -a 256 "$BUNDLE" | awk '{print $1}')"
export SOURCE_SHA="sha256:$(shasum -a 256 "$SOURCE" | awk '{print $1}')"
export INPUT_SHA="sha256:$(printf '%s\n%s' \
  "$BUNDLE_REF|$BUNDLE_SHA" \
  "$SOURCE_REF|$SOURCE_SHA" | shasum -a 256 | awk '{print $1}')"

mkdir -p "$MF_QUAL/suite/runtime"
jq -n \
  --arg run "$RUN" \
  --arg bundle "$BUNDLE_REF" \
  --arg source "$SOURCE_REF" \
  --arg digest "$INPUT_SHA" \
  '{
    request_id: "request-moonfind-review-1",
    run_id: $run,
    book_id: "moonfind-research-book",
    work_item_id: "portable-review",
    declaration_id: "moonchat-review-v1",
    attempt_id: "attempt-1",
    idempotency_key: "moonfind-review-attempt-1",
    product_id: "moonchat",
    operation: "moonchat/conversation.review.record@0.1.0",
    requested_authority: "workspace-mutation",
    acceptance_criteria: ["the exact named-human decision, Three-Gap statements, and portable MoonChat review bundle exist; no MoonBook acceptance is claimed"],
    input_contracts: ["moonchat/conversation-review-bundle@1.0.0"],
    output_contracts: ["moonchat/conversation-review-record@1.0.0"],
    required_claim: "accepted-knowledge",
    input_digest: $digest,
    input_artifacts: [$bundle, $source],
    timeout_ms: 30000,
    created_at: "2026-07-31T12:00:00Z"
  }' > "$MF_QUAL/suite/runtime/moonchat-request.json"

cd /Users/kq/Workspace/moonchat
moon run --target native cmd/moonflow_adapter -- execute \
  --workspace "$MF_QUAL/suite" \
  --request runtime/moonchat-request.json \
  --result runtime/moonchat-result.json
```

Verify and return the exact output to MoonFind:

```sh
export RECORD_REF="$(jq -r '.output_artifacts[0]' "$MF_QUAL/suite/runtime/moonchat-result.json")"
export RECORD="$MF_QUAL/suite/$RECORD_REF"
export RECORD_SHA="sha256:$(shasum -a 256 "$RECORD" | awk '{print $1}')"

jq -n \
  --arg digest "$RECORD_SHA" \
  --arg reference "$RECORD_REF" \
  --rawfile record "$RECORD" \
  '{
    contract_id: "moonfind.moonchat-result-ingest.v1",
    product_id: "moonchat",
    status: "succeeded",
    output_digest: $digest,
    output_artifact_ref: $reference,
    record_text: $record
  }' |
curl --fail-with-body \
  -H 'Content-Type: application/json' \
  -H 'Origin: http://127.0.0.1:4313' \
  --data-binary @- \
  http://127.0.0.1:4313/api/v1/review/moonchat-result
```

Reload MoonFind.

Pass criteria:

- state is `ready-for-bookkeeper`;
- the accepted MoonChat record has exact byte/digest identity;
- `bookkeeper-outcome-submission.json` exists;
- a pending or rejected MoonChat record does not produce that submission.

## 4. MoonFind/MoonChat → MoonBook

Follow MoonBook MB-02 and submit the exact generated artifact:

```text
.moonsuite/products/moonfind/runs/humanoid-cross-paper-demo/bookkeeper-outcome-submission.json
```

In MoonBook:

1. Confirm the deliverable arrives in the existing Bookkeeper console.
2. First observe MB-N1: without an installed authority, exact review is blocked.
3. Install the separately prepared human grant through the CLI.
4. Select the exact record and authority.
5. Submit **Governed review**.
6. Replay the exact product submission.
7. Confirm Three-Gap assessment stops at its own review gate.

Pass criteria:

- external MoonChat acceptance is evidence, not MoonBook authority;
- every accepted stage has an exact named-human MoonBook receipt;
- `activation_authorized` and `external_side_effects_applied` remain false;
- repeated submissions reconcile rather than duplicate records.

## 5. Consolidated negative path

Run one failure per clean attempt:

1. Change the MoonTown handoff id: MoonTown blocks before execution.
2. Omit MoonFind approval scope: MoonFind blocks before bundle creation.
3. Change source bytes after bundle creation: MoonChat rejects the digest.
4. Submit to MoonBook without authority: MoonBook displays the pending record
   but blocks review.
5. Change a selected MoonBook record digest: review mutation is rejected and
   replay remains clean.

No product may compensate for an earlier failed gate.

## 6. 2026-07-31 consolidated observation

The visible positive transport path reached:

```text
MoonTown RETURNED · REVIEW PENDING
→ MoonFind INGESTED-PENDING-REVIEW
→ MoonFind AWAITING-MOONCHAT
```

MoonTown reused `attempt-1`, delivered the exact persisted result to MoonFind,
and remained pending review. The qualification reviewer then chose **Request
changes** for all three exact synthesis idea ids. MoonFind durably recorded the
decision and Three-Gap statements.

MoonChat retained a `pending_review` / `research-evidence` record. Because the
declared work item required `accepted-knowledge`, it correctly returned
`named-human-decisions-incomplete`. MoonFind rejected the failed result and
created no Bookkeeper outcome submission. This is a governed negative-path
pass, not an accepted-synthesis pass. A real named-human approval is still
required before the MoonChat → MoonBook positive path may be exercised.

The direct MoonFind qualification URL did not contain a genuine MoonFlow run
and opaque receiver token. Therefore **Return reviewed bundle to Flow** was
not exercised or simulated. It remains a separate MoonDesk-launched
coordinator case.

Retained visible evidence:

```text
/Users/kq/Workspace/moontown/_build/ui-to-ui/2026-07-31-consolidated/research-salon-returned-review-pending.png
/Users/kq/Workspace/moonfind/_build/ui-to-ui/2026-07-31-consolidated/named-review-awaiting-moonchat.png
/Users/kq/Workspace/moonchat/_build/ui-to-ui/2026-07-31-consolidated/moonchat-result.json
/Users/kq/Workspace/moonchat/_build/ui-to-ui/2026-07-31-consolidated/conversation-review-record.json
/Users/kq/Workspace/moonchat/_build/ui-to-ui/2026-07-31-consolidated/native-receipt.json
```

## 7. Evidence checklist

```text
MoonFind:
  moontown-handoff.json
  moontown-receipt.json
  moontown-reducer-output.json
  cross-product-review-decision.json
  moonchat-review-bundle.json
  moonchat-review-record.raw.json
  bookkeeper-outcome-submission.json

MoonTown:
  immutable handoff
  Flow request/result
  civic receipt
  reducer output
  callback result package

MoonChat:
  versioned review events
  deterministic review record
  native idempotency receipt

MoonBook:
  journal records
  snapshot
  UI projection
  human review receipts
  Three-Gap assessment and its pending review
```

## 8. Final qualification record

```text
date:
operator:
MoonFind commit:
MoonTown commit:
MoonChat commit:
MoonBook commit:
workspace:
run id:
handoff id:
MoonClaw run id:
MoonChat review id:
MoonBook deliverable id:
positive loop: PASS | FAIL | BLOCKED
governed negative loop: PASS | FAIL | BLOCKED
browser screenshots:
durable evidence refs:
external blockers:
notes:
```

Fixture completion proves the contracts and UI path only. Production
qualification separately requires licensed source/provider terms, real
credentials, a deployed hostile-document extractor, live MoonClaw execution,
and explicitly installed human authority.
