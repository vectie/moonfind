# Completed synthesis and exact review scope

The existing `/api/v1/workspace` snapshot now has an optional
`moontown_result` field using `moonfind.moontown-result-view.v1`. The UI remains
compatible with snapshots that omit it and shows an unavailable-result message.

The read-only host projection uses the actual `TownSynthesisOutput` from
`moontown/handoff.mbt`, contract `civic.communication.output.v1`. Each idea has
`id`, `title`, `summary`, `participating_books`, `research_questions`,
`why_it_matters`, and `next_experiment`. It is distinct from `ResearchIdea` and
its candidate-analysis IDs, claim IDs, mechanism, and falsifier fields.

The trusted host reads the configured run's `moontown-handoff.json`,
`moontown-receipt.json`, `moontown-reducer-output.json`, and
`moontown-result-ingest-v1.json`. The ingest envelope is the existing digest/ref
envelope written by `host/moontown_result_ingest.mbt`, not a copy of the callback
request. The read reconstructs that callback with its exact stored source,
reuses the existing correlation validators, and compares both canonical digest
bindings. It never repairs, ingests, submits, or approves an artifact.

Only a complete, correlated result is exposed as `available`. Missing, malformed,
empty, mismatched, or changed artifacts leave the workspace readable and show no
selectable result. Artifact validation does not establish scientific validity.
Human acceptance continues through the existing review workflow and Bookkeeper.

The UI shows all returned content, exact IDs, the artifact reference, and the
exact-byte digest used by `host/review.mbt`. Ten ideas appear per page; paging
retains selection. Clicking an idea only toggles its ID in the existing decision
scope. It never chooses an outcome, fills a rationale, or submits a decision.
The existing safe-ID restriction remains unchanged; an unsupported ID can be
read but cannot be selected for the existing review API.

Review preparation includes optional `source_digest`. Old callers may omit it.
Result-aware callers must match the artifact's exact current byte digest before
any review artifact is written. Review outcomes, ID membership, human identity,
gap requirements, immutable decisions, and acceptance rules are unchanged.

Drafts are separated by exact Book directory, run ID, and result digest in the
current browser visit. Unchanged refreshes preserve the draft. Switching context
saves it in memory and shows an empty or previously retained context-specific
draft; returning to the exact context restores it with a notice. Drafts are not
persisted in browser storage. A fresh visit loads current result content and
durable workflow state without inventing prior input or repeating submission.
In-flight review replies are bound to both the result context and a monotonically
increasing preparation request generation. A reply from an earlier A request
cannot consume a newer request after switching A → B → A, even though its result
context is identical. Both success and error callbacks leave the newer draft and
request untouched; repeated preparation clicks do not repeat the POST.

All tests use local fixtures, temporary filesystem workspaces, mocked HTTP, or
SSR. No live model, MoonTown service, listener, deployment, or user computer is
needed to validate this feature.
