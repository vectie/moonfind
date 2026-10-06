# Hosted three-choice artifact review

MoonFind's existing result screen and `/api/v1/review/prepare` capture one
named decision for the exact MoonTown synthesis bytes. The flow remains
Find preparation → MoonFlow/MoonChat recording → Find receipt return →
separately governed Bookkeeper submission. No second review role, runtime,
automatic Book acceptance or alternate policy was introduced.

## Choices and identity

- Approve a named subset: requires actual synthesis IDs and named rationale.
- Defer / request changes: the existing `request_changes` wire value maps to
  MoonChat `defer`, `pending_review`, and `research-evidence`. Selected IDs
  remain in the existing rejected/changes-requested scope field; this is an
  unresolved decision, not a rejection receipt or approval.
- Reject: MoonChat records `rejected` with `research-evidence`.

Reconsideration creates a new research revision. This slice never edits an
immutable decision or supersedes it in place. Historical rationale and
objection entries remain available in the producing result's readback.
Unsaved browser form drafts retain the existing visit-scoped behavior;
saved decisions survive a fresh model/reload through host storage.

New bundles use the actual pinned MoonChat conversation contract function,
which consumes MoonLib 0.1.19's `moonsuite-conversation.v2`. The unchanged
MoonChat review source and its upstream tests are pinned under
`vendor/moonchat/review`; see the provenance file. No MoonLib or async version
changes were made.

## Exact receipt return

New preparations persist `moonchat-review-prepared.json` with explicit
typed format, run/review/source identity, and exact decision/bundle digests.
The write order is decision → preparation binding → bundle publication.
Retry uses the retained decision timestamp, so interruption before bundle
publication can complete without changing the decision. Readback validates
this binding before displaying any pending decision scope; it does not need
the current source bytes to recreate historical evidence.
Existing immutable bundle bytes are preflighted before writing a new-format
binding, so an attempted retry of a historical v1 preparation cannot leave
a v2 marker beside it. Exact API retry after a crash before bundle publication
is tested. Fresh UI reconstruction of the saved form at that earlier boundary
is not qualified; until a bundle exists, the host still shows the review as
ready for human input. This slice does not claim that broader draft-recovery UX.

`/api/v1/review/moonchat-result` preserves the existing request shape. It
checks the exact byte digest, source and named decision, decodes the real
MoonChat typed record, compares its deterministic projection, and reads
every journal event through safe workspace-confined paths. All event bytes,
order, identity and body must match the real MoonChat projection.

The immutable `moonchat-review-return.json` binds the original decision,
bundle, source and returned record digests. Replaying the same return is
idempotent; changing the return identity, source bytes, decision scope,
reviewer, rationale or journal cannot reuse an approval. A saved bundle or
record without a producer link remains pending-return and keeps the
reviewer's reason visible. Restoring exact evidence permits the existing
MoonFlow return to be retried. The UI refreshes read-only; it does not run
the external operation or invent a delivery acknowledgement.

Operation `failed` can retain a fully validated rejecting/deferred record
(as MoonChat may fail an accepted-knowledge request with research-evidence).
It cannot promote an approving record. Rejection and deferral do not write
research acceptance or a Bookkeeper submission.

Approval stores `ResearchRun.reviewed_synthesis` with exact source identity
and selected synthesis IDs. Original analysis ideas and `accepted_idea_ids`
remain intact: analysis `candidate-a` and synthesis `idea-1` are distinct.
The workspace count can reflect that explicitly reviewed synthesis.

## Existing files and boundaries

Historical v1-conversation bundles and incomplete already accepted v1 records
are retained unchanged and labeled legacy/unverified. Replaying an identical
historical raw return with an already prepared submission is read-only; it
does not add a new qualifying receipt or reapply acceptance. A fresh review
revision is needed for the current typed contract. Only actual v1 evidence
without a new-format binding may use this historical path. A missing return
marker or a prepared Book submission never establishes legacy format.
Damaged new v2 journals remain invalid even if interruption occurs after
submission and before return linkage. Missing/extra human decision receipts
produce a recoverable invalid-evidence status rather than a native bounds
failure. New typed receipts with changed evidence fail readback rather than
being relabeled legacy.

The result screen shows saved reviewer, scope, rationale, dissent, exact
source/record identity, receipt return state, and MoonBook's separately
unknown `not-acknowledged` state. Find has no generic Book receiver readback
contract, so approval is never rendered as Book acceptance. An actual Book
decline round-trip, mounted browser/keyboard/assistive-technology review,
live MoonFlow adapter and provider-backed execution remain unqualified.

Local acceptance uses actual MoonChat event/projection functions and the
real Find handlers without listeners, providers, credentials or deployment.
