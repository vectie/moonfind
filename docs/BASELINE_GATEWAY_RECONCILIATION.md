# Published-main UI reconciliation

This repair is separate from the evidence-to-choice feature.

## Provenance

Published baseline: `83c724b09b8b2dcbd4f3abb7288b86d73ca3ee19`
(`Integrate preserved local host edits with reviewed source`).

The baseline's `ui/rabbita-moonfind/main/gateway.mbt` is preserved byte-for-byte
as [`PRESERVED_MAIN_GATEWAY.mbt.txt`](PRESERVED_MAIN_GATEWAY.mbt.txt).
SHA-256 of both files:
`920cc7b2229c4176c8e8401f29970d43e1c481151a3fd57fb2cfc0ebecd0b321`.
The `.txt` suffix deliberately keeps this historical source outside compilation.
It is not a runnable module or an available general-job API.

## Observed problem and missing dependencies

The published gateway added general-job request helpers, but the same source
contained none of their callers, host `/api/v1/jobs` routes, `RequestedJobOutput`
type, `Model.job_sources/job_objective/job_audience/job_outputs/job_criteria`
fields, or `JobsLoaded`, `JobCreated`, `JobRefreshed`, `JobStarted`, `JobResumed`,
`JobDeliveryVerified`, `JobSourceAdded`, `JobRevisionCreated`, and
`JobPreviewLoaded` message constructors. Building the untouched UI independently
reproduced 23 errors, including a stale one-argument `CapabilitySubmitted` test.

The orphaned block spans lines 129–433 of the preserved gateway. Its intent is
retained here for a later complete general-research-job feature. Implementing
that feature requires the typed brief/job/preview contracts, corresponding
model and reducer, visible UI and durable host routes; inventing no-op messages
or fictional endpoints solely to compile would not restore that workflow.

## Narrow active repair

Only the orphaned gateway block is removed from active compilation. The rest
of the gateway matches the previous coherent implementation byte-for-byte,
SHA-256 `1effe88ebe2c278d0962cf31c2efecf7cff17eaa4a91cd9fc9f5996ee3fe4530`.
Existing research, series, review, MoonFlow receiver and Q&A routes are intact.

The `command-ready research waits for an explicit model route` test now supplies
the current workspace and execution context, passes the current two-argument
callback, and tests a newer receipt revision. It asserts the existing truthful
`Failed`/repairable route-blocker state and verifies that explicit model selection
permits session creation. No runtime model-selection behavior was changed.

Repair files:

- `ui/rabbita-moonfind/main/gateway.mbt`
- `ui/rabbita-moonfind/main/model_wbtest.mbt`
- this provenance record and the exact archived baseline gateway

The full UI test suite passes on the repaired actual published baseline. This
does not qualify general-job execution or make it available in this release.
