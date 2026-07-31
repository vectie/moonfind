# DeepSeek Research Journey

This journal records the UI-first DeepSeek research run, defects encountered,
fixes applied, verification evidence, and unresolved risks. It intentionally
omits credentials and keeps the raw local corpus private.

## Scope

- Source folder: `/Users/kq/Downloads/deepseek`
- Observed corpus: 17 JPEG files, pages 2–18 of one alleged Chinese transcript
- Known missing input: page 1
- Destination MoonBook: `/Users/kq/Workspace/deepseek-research-book`
- Durable MoonClaw run: `run-20260724-002443-db4cfe`
- MoonClaw proposal:
  `20260724-002435-create-and-execute-a-durable-f727f6`
- Required runtime model: `codex/gpt-5.6-sol`
- Review state: not yet reviewed; no acceptance claim is authorized

## 2026-07-23 — Corpus and suite audit

The local corpus contains exactly 17 JPEGs, numbered 2 through 18. They appear
to be sequential screenshots of one Chinese Xiaohongshu transcript attributed
to a Liang Wenfeng investor interview, not 17 independent sources. Page 2 says
the alleged recording date was 2026-05-20 and the duration was about 3 hours
44 minutes. Authenticity, attribution, completeness, and reuse license are not
verified. The filenames expose a public account handle, and the text may
contain market-sensitive company, model, compute, pricing, staffing, and
roadmap claims. The raw corpus must therefore remain private and be treated as
untrusted attributed evidence.

Repository inspection found:

- Moonfind was hard-coded around arXiv/humanoid research and had no generic
  local-folder or image coverage contract.
- The Moonfind Rabbita UI was a read-only static projection with no folder
  import, run action, progress, report opening, or Q&A action.
- MoonBook already had durable workspace, ingest, report, query, review, and
  Three-Gap contracts, but its own UI could not launch research or install
  reviewer authority.
- MoonTown already had a four-stage research bootstrap worker and a
  MoonClaw-to-MoonBook persistence route, but MoonDesk's one-shot dispatch wrote
  request JSON that MoonTown did not consume.
- MoonDesk had the strongest existing folder-import UI, but selected entries
  were not preserved into a standing-goal Town context.
- Existing quality gates did not prove that every local file was accounted for.
- Existing MoonBook/job Q&A was lexical retrieval, not a retained
  citation-backed model agent.

## 2026-07-23 — MoonClaw Cowork UI decoder failure

**Observed through UI:** opening Cowork displayed:

`File import failed: Failed to parse local upload batch:
JsonDecodeError((/error, String::from_json: expected string))`

**Root cause:** successful browser FFI payloads encoded optional `error` fields
as explicit JSON `null`, while the derived MoonBit optional-string decoder
accepted an omitted field but rejected a present null.

**Fix:** in MoonClaw's MoonBit Rabbita client, omit `error` on successful
clipboard, picker, dropped-file, and download responses. Add targeted tests for
successful upload and clipboard payloads with omitted optional errors.

**Verification:** MoonBit JS check and targeted tests passed, the production UI
built successfully, and the Cowork UI no longer showed the decoder error.

## 2026-07-23 — Cowork session request storm

**Observed through UI and gateway:** selecting Cowork caused a continuous storm
of `GET /v1/workspace` and `GET /v1/cowork/sessions` requests, preventing the
conversation from loading.

**Root cause:** loading the first session pushed a Cowork URL. The URL change
reloaded sessions, which pushed the same URL again.

**Fix:** when no session is selected, select and fetch the first session
directly in MoonBit state instead of pushing a URL from the
`CoworkSessionsLoaded` branch.

**Verification:** after rebuilding and restarting the gateway, Cowork created
and loaded a conversation without repeated requests.

## 2026-07-23 — Cowork Run panel could not stay open

**Observed through UI:** clicking **Run** briefly marked the tab active and
changed the hash URL, but the context pane reverted to Preview, hiding model,
provider, and working-directory settings.

**Root cause:** MoonBit's URL parser separates a query appearing after a hash
route into `url.query`. The UI's `route_query_string` returned `None` whenever a
fragment existed without an embedded `?`, instead of falling back to
`url.query`. The subsequent URL change therefore reset the panel to Preview.

**Fix:** make `route_query_string` fall back to `url.query` and extend the
routing test to assert the session query and Run-panel decoding.

**Verification:** targeted MoonBit tests passed. In the rebuilt live UI, a
direct Cowork Run URL displayed **Session Settings**, and the operator saved
the title, `codex/gpt-5.6-sol`, and `/Users/kq/Workspace`.

## 2026-07-24 — Model route and plan fallback

The first research conversation used the MoonBook repository as MoonClaw's
runtime home. That home had no primary model or ACP target, so the planner
auto-detected a shell-agent route and failed with connection refused. MoonClaw
then generated a misleading single-step fallback proposal.

MoonGate was started and verified through its UI as healthy on
`127.0.0.1:15721`, with Codex OAuth and `gpt-5.6-sol` available. MoonClaw was
restarted against the configured global home, where the primary model is
`codex/gpt-5.6-sol`; its gateway then reported the MoonGate statistics bridge
enabled.

A new UI conversation generated an eight-step plan rather than the fallback:

1. preflight ownership and UI paths
2. local corpus accounting
3. transcript and claim extraction
4. external corroboration
5. MoonTown adversarial challenge
6. report synthesis and MoonBook review
7. book-bound cited Q&A and UI
8. independent verification and handover

The plan was promoted and confirmed through Cowork, creating durable run
`run-20260724-002443-db4cfe`.

## 2026-07-24 — Preflight retry

The first `preflight-governance` attempt completed several successful Codex
model and MoonClaw tool turns, then failed with
`vectie/moonclaw/internal/openai.HttpError.HttpError`. MoonGate recorded the
failed request as HTTP 400 with `upstream_error`, but its operator detail did
not expose a more specific safe explanation. MoonClaw automatically started
attempt 2; the UI now preserves the retry and branch-failure lineage.

This remains under investigation. A successful retry must still write the
preflight receipt; an exhausted retry must block later steps rather than being
reported as success.

## 2026-07-24 — Generic local-input accounting added to Moonfind

Moonfind now defines `moonfind.local-input-coverage.v1` in MoonBit:

- a typed terminal status per local input
- source-relative path, SHA-256 digest, byte length, media type, order, and
  provenance
- extraction artifact and page/region evidence anchors
- duplicate binding and failure reason
- explicit known-missing inputs
- separate `accounting_complete` and `research_ready` gates

An unsupported, failed, merely ingested, or merely extracted file is accounted
for but blocks research readiness. A duplicate is ready only when it references
a used original. Tests cover fully usable input, an accounted unsupported
input, and an invalid duplicate binding.

The pack manifest now declares MoonBook as a required runtime, exposes
`research.account-local-corpus`, and includes the JSON schema. A root
`pack.json` was added because MoonBook's installer requires it. MoonBook
`pack inspect` reports `ReadyToStage`, no validation issues, and the expected
Observe, WorkspaceMutation, and SandboxExecution authorities.

Validation completed:

- `moon check --target native`: passed
- `moon test research --target native`: 4 passed
- `moon fmt`: passed
- `moon info`: passed
- MoonBook pack inspection: ready to stage, zero issues

## 2026-07-24 — Generic local-corpus execution and Q&A contracts

Moonfind now prepares two ownership-safe MoonClaw commands in MoonBit:

- a coverage-gated local-corpus analysis packet that carries the ledger,
  evidence/cross-validation contract, and output bundle contract without
  calling a model provider directly
- a stable book-bound Q&A packet (`moonfind-<book>-qa`) that is read-only,
  distinguishes accepted from pending-review material, requires citations,
  and labels later web updates separately from reviewed book evidence

MoonTown now provides a coverage-gated local-corpus challenge scenario. Its
four roles are provenance critic, technical verifier, economic skeptic, and
synthesis explorer. The scenario explicitly preserves source sequence and
page anchors, forbids reconstruction of missing page 1, and requires MoonBook
review before durable acceptance.

Verification completed:

- `moon test agent --target native`: 3 passed
- `moon test moontown --target native`: 4 passed
- `moon test suitepack --target native`: 1 passed

## 2026-07-24 — Cowork workspace and model propagation failure

**Observed in the durable run:** the Cowork UI saved
`/Users/kq/Workspace` and `codex/gpt-5.6-sol`, but the promoted job prompt said
`Workspace root: /Users/kq/moonsuite`. Its safe file tools consequently rejected
reads and writes under the selected workspace as outside the run boundary.

**Root cause:** Cowork called the default `plan_proposal` entrypoint and ignored
its computed `cwd`. Confirmation later called the default
`confirm_proposal`, compiling the saved proposal a second time against the
gateway's global workspace. The session model override was also omitted from
planning.

**Fix:** MoonClaw now plans Cowork proposals with
`plan_proposal_in_workspace`, passing the session folder as both working
directory and workspace root and retaining the session model. It now confirms
through a new `confirm_proposal_in_workspace` application method using the same
session folder. The default confirmation method remains a compatibility
wrapper for non-Cowork callers.

**Verification:**

- `moon check --target native --warn-list +73`: zero errors
- `moon test job/application_wbtest.mbt --target native`: 9 passed, including
  a new assertion that caller-selected workspace reaches the job definition
- `moon test gateway/server --target native`: 50 passed
- a broad `moon test job` run passed 267 of 268 tests; the sole failure was an
  unrelated timing-sensitive timeout-policy test and is retained as a separate
  verification warning

A clean rerun of the broad job suite later passed all 268 tests, confirming the
earlier timeout assertion was transient.

The original run remains evidence of the defect and must not be represented as
a valid research run. The gateway was stopped while its retry was active and
restarted from the fixed MoonBit source. After restart, the in-app browser
security policy blocked the existing local MoonClaw tab. No alternate browser
surface or raw control path was used to bypass that policy.

## 2026-07-24 — Three research iterations and draft book

All 17 available pages were inspected at original resolution. The research
output uses page-level analytic extraction rather than pretending an OCR
transcript exists. Every source image has an exact SHA-256, byte count, media
type, sequence number, extraction artifact, and evidence anchor in
`/Users/kq/Workspace/deepseek-research-book/state/local-input-coverage.json`.
Page 1 remains a known missing input.

Three iterations were completed:

1. **Source map:** page-by-page extraction and thematic grouping.
2. **External validation:** DeepSeek V3/R1/V4, API pricing, TileKernels,
   Engram, TileLang, Huawei Atlas 950, BIS policy, and the public Sina
   republication were checked. Primary sources were preferred.
3. **MoonTown-style challenge:** provenance critic, technical verifier,
   economic skeptic, and synthesis explorer views were incorporated into the
   final report and monitoring framework.

The resulting draft MoonBook workspace contains:

- `wiki/synthesis/deepseek-research-report.md`
- `wiki/synthesis/claim-matrix.md`
- `wiki/sources/local-transcript-source-map.md`
- `wiki/sources/external-validation.md`
- `wiki/queries/qa-agent-contract.md`
- `state/local-input-coverage.json`
- `state/review-status.json`

The report does not merely concatenate the source. Its central synthesis is
that DeepSeek is attempting to turn compute scarcity into a repeatable
efficiency rate, then use openness and restrained economics as distribution and
legitimacy mechanisms. It separately analyzes the failure modes of this
flywheel and distinguishes context, retrieval, memory, continual learning, and
self-iteration.

Validation completed:

- JSON ledgers parse; all 17 inputs are unique and marked Used
- source map contains exactly 17 page sections
- `moon check --target native`: zero errors
- `moon test research`: 4 passed
- `moon test agent`: 3 passed
- `moon test moontown`: 4 passed
- `moon test suitepack`: 1 passed
- `moon info --target native`: passed

The book remains explicitly `pending_review`. The retained Q&A session is
specified but not started. These states prevent file creation from being
misreported as MoonBook acceptance or a ready agent.

## Open risks and next gates

- Page 1 is absent and must remain an explicit evidence gap.
- OCR/extraction for all 17 Chinese JPEGs is not yet proven.
- The corpus's authenticity and license remain unverified.
- The original durable run used the wrong workspace and was interrupted during
  retry; it has produced no acceptable MoonBook research artifact.
- A replacement run still must be created and confirmed through an allowed UI
  surface to prove the workspace/model fix end to end.
- The MoonDesk-to-MoonTown dispatch bridge and selected-entry propagation are
  still incomplete.
- Reviewer authority cannot yet be provisioned solely through the existing
  MoonBook/MoonDesk UI.
- A true book-bound model Q&A profile and retained UI session still need to be
  implemented and verified.
- No report is accepted, and no Q&A agent is ready for handover yet.

## 2026-07-24 — Stable read-only Q&A grounding handover

This entry covers job
`job.proposal.20260724-011200-use-the-moonfind-pack-at-fe7e76`, run
`run-20260724-011206-e43d09`, step `handover-and-grounding`.

### Problem 1 — The pending candidate had a Q&A specification but no frozen grounding packet

- **Cause:** `wiki/queries/qa-agent-contract.md` defined behavior and retrieval
  order, while the pending review candidate froze its own inputs, but there was
  no single machine-readable manifest binding the later Q&A session to exact
  artifact bytes.
- **Fix:** added the pointer-only packet
  `wiki/queries/moonfind-deepseek-research-book-qa/` with a human-readable
  `README.md` and machine-readable `manifest.json`. The manifest binds ten
  candidate, evidence, contract, audit, and state artifacts by book-relative
  path and full SHA-256 and requires fail-closed handling for mismatches.
- **Test:** recomputed all ten SHA-256 values before packet creation and matched
  them to the pending candidate and current review state.
- **Outcome:** the later Cowork owner can verify an exact snapshot without
  copying private images or treating mutable paths alone as identity.
- **Remaining limitation:** a path-plus-hash manifest does not make the source
  artifacts physically immutable. Any changed file must fail integrity
  validation and be re-candidated; no content-addressed object store was
  introduced.

### Problem 2 — The pack exposes no dedicated Q&A-grounding schema

- **Cause:** `pack.json` declares research, review, and deliverable schemas but
  no schema specifically for a read-only Q&A grounding manifest.
- **Fix:** retained the implemented MoonBit `prepare_book_qa_command` behavior
  and the existing Q&A contract as authoritative, and used an explicit
  `moonfind.read-only-qa-grounding.v1` packet contract rather than mislabeling
  the manifest as another pack schema. The final `result.json` uses the
  applicable `moonfind.bookkeeper-deliverable-candidate.v1` shape: contract
  version `moonbook.bookkeeper.store.v1`, stage `DeliverableAcceptance`, human
  review required, and no side effects applied.
- **Test:** inspected `pack.json`, `agent/packet.mbt`,
  `agent/packet_test.mbt`, and the relevant JSON Schemas; validation checks the
  manifest’s required policy and state fields directly.
- **Outcome:** the handover stays compatible with the current MoonBit contract
  without claiming an undeclared pack schema exists.
- **Remaining limitation:** the grounding manifest contract is workspace-local
  and is not yet registered in `pack.json` or enforced by a MoonBit decoder.

### Problem 3 — Exact citation coverage and source classes were implicit across artifacts

- **Cause:** evidence identifiers were complete in their canonical files but
  the Q&A contract did not enumerate exact domain counts or define claim-level
  citation precedence.
- **Fix:** recorded citation and classification rules for `C01–C20`,
  `L01–L123`, `local:p2–local:p18`, `P1–P10`, `S1`, and `MC01–MC16`. Local
  claims require an `Lxx` locator plus page/region anchor; public claims require
  `Pxx` plus a direct URL; secondary and adversarial records must remain
  explicitly labeled. Page 1 has zero records and zero reconstruction.
- **Test:** deterministic identifier counts found 20 canonical claims, 123
  local records, 17 available page anchors, 10 primary records, one secondary
  record, and 16 challenge records.
- **Outcome:** citation-domain coverage is exact and machine-readable while
  retaining the distinction between coverage and truth.
- **Remaining limitation:** identifier presence does not prove that a future
  answer cites every material clause correctly. The later Cowork session must
  run a fixed answer-verification set.

### Problem 4 — Confidence and contradiction behavior needed fail-safe rules

- **Cause:** the claim matrix contained calibrated confidence and corrections,
  but a future answering session could otherwise transfer confidence from a
  public fact to private attribution or silently merge contradictory dates and
  values.
- **Fix:** required claim-specific `high`, `moderate`, `low`, or `not
  estimable` confidence; split mixed claims; cite both sides of conflicts;
  prefer primary evidence only for the bounded public proposition; retain local
  statements as attributed; never fabricate midpoint values; and add “What
  would change this answer?” for disputed forecasts.
- **Test:** packet policy checks require confidence levels, contradiction rules,
  separate later-web labeling, and pending-review answer labels.
- **Outcome:** the packet now preserves the V4 chronology correction and other
  tensions without converting later public evidence into transcript
  authentication.
- **Remaining limitation:** confidence remains analytical judgment, not a
  statistical posterior, and named-human review has not accepted any claim.

### Problem 5 — Privacy boundaries needed to survive later activation

- **Cause:** the source corpus is private, incomplete, unauthenticated, and its
  filenames contain a personal handle. A future Q&A runtime could otherwise
  expose paths, upload source material, or overquote local text.
- **Fix:** prohibited copying, embedding, uploading, publishing, or returning
  images; prohibited sending private OCR/transcript material or handle-bearing
  filenames to web services; required book-relative anchors and digests;
  limited private quotation; and retained market-sensitive claims as
  unverified.
- **Test:** workspace scans verify no source image is present in the book packet
  and no Python file was added. The private source directory was not opened or
  enumerated during this handover step.
- **Outcome:** the grounding packet is pointer-only and can be reviewed without
  moving private source data.
- **Remaining limitation:** policy text cannot itself prevent a later operator
  from violating the restriction; the Cowork session must enforce the same
  boundary operationally.

### Problem 6 — MoonBook projection remains unsafe for pending material

- **Cause:** the previous review-candidate step found that MoonBook’s
  knowledge-bundle normalizer inferred `review_status: accepted` for pending
  source pages.
- **Fix:** did not run `moonbook build`, `wiki bundle`, or retain a generated
  `book/` projection. Validation uses authored Markdown, JSON state, hashes,
  links, and the pack’s documented MoonBit checks.
- **Test:** state assertions require `moonbook_review_state: pending_review`,
  `accepted: false`, `durable_memory_promotion_state: not_promoted`, and an
  empty approved queue.
- **Outcome:** no false accepted projection was created during handover.
- **Remaining limitation:** MoonBook projection remains blocked until status
  inference is repaired or safely isolated.

### Problem 7 — The requested session must not be confused with a running agent

- **Cause:** the session has a stable ID and an implemented MoonBit command
  constructor, but file preparation alone cannot establish a launched, hosted,
  or verified answering agent.
- **Fix:** manifest runtime state is `specified_not_started`, with `launched:
  false`, `hosted: false`, and activation explicitly assigned to a later
  UI-created Cowork session. No provider, server, agent, or Cowork session was
  invoked in this step.
- **Test:** validation asserts those runtime flags and the unchanged
  `state/review-status.json` session state.
- **Outcome:** the packet is ready for human review and later operational
  verification, not represented as a live service.
- **Remaining limitation:** replacement UI workspace/model propagation and the
  fixed Q&A answer set remain unverified end to end.

### Review and acceptance outcome

The handover stops at the named-human gate. `kq (workspace owner)` remains the
only decision authority. The candidate and packet remain pending review;
`accepted` is false, durable-memory promotion is `not_promoted`, and the
approved queue remains empty. No answering agent was launched or hosted.

### Validation-process problems encountered during handover

#### Apparent missing MoonBit module root

- **Problem:** filesystem inspection found no visible `moon.mod.json` in
  Moonfind or an ancestor and initially suggested the documented Moon commands
  could not run.
- **Cause:** this checkout uses the current Moon toolchain's repository/package
  discovery despite not exposing a conventional manifest at the inspected
  paths.
- **Fix:** ran the documented commands from `/Users/kq/Workspace/moonfind`
  rather than treating the manifest inspection as decisive.
- **Test/outcome:** `moon check --target native`, all four targeted suites, and
  `moon info --target native` exited zero. The tests passed 4/4 research, 3/3
  agent, 4/4 moontown, and 1/1 suitepack.
- **Remaining limitation:** the nonstandard/implicit project-root discovery is
  not documented in this checkout and may be less portable than a visible
  module manifest.

#### POSIX-shell validator incompatibility

- **Problem:** the first hash and link validators failed with shell syntax
  errors around process substitution.
- **Cause:** the command runner invoked POSIX `sh`, while the initial commands
  used Bash-only `< <(...)` syntax. A second hash attempt used `IFS='\t'`,
  which POSIX `sh` interpreted as the literal characters backslash and `t`,
  splitting valid paths incorrectly.
- **Fix:** replaced process substitution with `mktemp` files and used a literal
  pipe delimiter for the hash stream.
- **Test/outcome:** all ten manifest hashes matched and all local Markdown links
  resolved. The failed attempts changed no workspace files.
- **Remaining limitation:** these were ad hoc deterministic checks rather than
  a committed reusable validator.

#### Dependency-cache and Markdown-hard-break false positives

- **Problem:** the first no-Python/whitespace audit reported one Python file and
  seven whitespace lines.
- **Cause:** the Python file belongs to `.mooncakes` dependency cache rather
  than Moonfind source, and all seven whitespace lines were intentional
  two-space Markdown hard breaks in the existing contract and packet header.
- **Fix:** excluded dependency/build caches from the source audit and treated
  exactly two terminal spaces as Markdown syntax while still rejecting other
  trailing whitespace.
- **Test/outcome:** zero Python files in Moonfind/book source, zero source images
  in the book, and zero non-hard-break trailing-whitespace findings.
- **Remaining limitation:** dependency caches can contain Python even though no
  Python was added to product or book source; the no-Python result is correctly
  scoped to authored source.

#### Pre-existing MoonBit warning

- **Problem:** `moon check` and `moon info` reported warning 0035 at
  `research/types.mbt:59` because field name `method` is reserved for possible
  future use.
- **Cause:** pre-existing Moonfind API naming, unrelated to the grounding
  packet; no MoonBit source was changed in this handover.
- **Fix:** none applied to avoid an unrelated public-API change and generated
  interface churn.
- **Test/outcome:** all commands exited zero and all targeted tests passed;
  `git diff --check` also passed.
- **Remaining limitation:** the warning remains and should be addressed in a
  separately scoped MoonBit compatibility change.

#### Manifest validation from the wrong root

- **Problem:** the first final manifest-hash pass reported
  `state/local-input-coverage.json` missing.
- **Cause:** packet paths are explicitly relative to the MoonBook root, but the
  validator was run from the MoonClaw run-output root whose partial `state/`
  projection does not include the coverage ledger.
- **Fix:** reran the unchanged manifest validator from
  `/Users/kq/Workspace/deepseek-research-book`, the declared book root.
- **Test/outcome:** all ten frozen artifact hashes matched. No artifact was
  missing from the book and no file was modified to make the check pass.
- **Remaining limitation:** later Cowork validation must resolve manifest paths
  against the declared book root, never its run-output directory.

## 2026-07-24 — Pack registration, MoonBook correction, and retained Q&A activation

This follow-up closes the operational limitations recorded above without
changing the pending human-review decision.

### Problem 1 — Pending sources were unsafe to project through MoonBook

- **Cause:** `wiki/knowledge_bundle.mbt` treated a missing review marker as
  accepted, and converted `@async.now()` to `Int`, producing an overflowing
  negative timestamp.
- **Fix:** MoonBook now accepts only an explicit `review_status: accepted`,
  preserves explicit rejection, recognizes pending spellings, otherwise fails
  closed to `pending-review`, classifies unauthenticated or unverified material
  as `provisional`, and records the timestamp as a string.
- **Test:** MoonBook `moon check` passes. Targeted knowledge-bundle tests cover
  unauthenticated pending sources, explicit review state, and the existing
  graph projection. A temporary copy of this research book projected as
  `review_status: pending-review`, `source_quality: provisional`, with a
  positive timestamp.
- **Outcome:** the earlier statement that MoonBook projection remained unsafe
  is superseded by a tested fail-closed implementation.
- **Remaining limitation:** the full MoonBook `wiki` suite passes 182/183; the
  independently reproducible remaining failure is the unrelated pre-existing
  `moonclaw jobs include role runtime metadata` test.

### Problem 2 — Q&A grounding was not a first-class pack capability

- **Cause:** the workspace-local manifest used
  `moonfind.read-only-qa-grounding.v1`, but `pack.json` and the typed suitepack
  manifest did not register that schema or a tool declaration.
- **Fix:** added `schemas/read-only-qa-grounding.schema.json`, registered it in
  both manifests, and declared the review-gated
  `book.prepare-read-only-qa-grounding` sandbox tool. The MoonClaw Q&A command
  now names the verified grounding contract.
- **Test:** the actual DeepSeek grounding manifest validates against the new
  JSON Schema. Moonfind formatting, checking, all 15 tests, and `moon info`
  pass.
- **Outcome:** the retained Q&A handoff is now discoverable and enforceable as
  a Moonfind DomainPack capability rather than an undeclared convention.
- **Remaining limitation:** JSON Schema validates structure and policy flags;
  artifact digest matching remains a separate deterministic integrity check.

### Problem 3 — Cowork messages were installed as system prompts

- **Cause:** MoonClaw gateway `execute_cowork_agent_message` passed incoming
  `content` as `system_message`, queued no user message, and supplied no file
  tools. Each turn emitted `PreConversation` and `PostConversation` without an
  answer.
- **Fix:** incoming content is now an actual `user_message`. Cowork receives
  only the read-only `list_files`, `read_file`, and `search_files` tools for
  workspace grounding; shell, write, patch, and web tools are absent.
- **Test:** MoonClaw checks and `moon info` pass, and the focused root package
  suite passes 5/5 including a new exact read-only-tool test. Gateway logs for
  the UI turn show a `UserMessage`, six requested book reads, no mutation
  tools, and a final assistant response.
- **Outcome:** retained Cowork Q&A can inspect the selected MoonBook workspace
  and answer while respecting the authority boundary.
- **Remaining limitation:** each retained turn creates a fresh internal model
  conversation under the stable Cowork session. Moonfind therefore repeats
  the full grounding contract on every question and does not treat earlier
  assistant text as evidence.

### Problem 4 — The file-only Q&A packet was not a running, verified agent

- **Cause:** the handover packet intentionally stopped at
  `specified_not_started`; runtime flags and review state still required a UI
  activation receipt.
- **Fix:** the rebuilt Moonfind browser UI created Cowork session
  `cowork:e61c6c50-2385-4181-8eae-95075ce94f10` on
  `codex/gpt-5.6-sol`, grounded it in the MoonBook workspace, and submitted the
  fixed strongest-evidence-for/against question. Activation is recorded in the
  book receipt and review state.
- **Test:** the rendered answer began `pending-review-book`, cited
  `local:pN` and direct primary URLs, separated public facts, attribution, and
  analysis, used no later web update, preserved missing page 1, exposed no
  private path or handle, and made no acceptance or promotion claim.
- **Outcome:** the retained agent is operational and grounded. The manifest
  runtime is `grounded_verified`, and its updated review-state digest is
  `9362e9ebbaa933f4120de576c71d4fe72c2cbc4c7ffdb4c1f6086da15db9cb28`.
- **Remaining limitation:** Q&A readiness does not decide the MoonBook review.
  The candidate remains pending until the named workspace owner records
  `approve_subset`, `request_changes`, or `reject`.

### Final authority state

The research run and Q&A activation are complete. The research candidate is
still `pending_review`, `accepted` is `false`, durable-memory promotion is
`not_promoted`, and no approved-queue entry exists. This is intentional:
MoonClaw and Moonfind cannot exercise the named human’s MoonBook authority.

## 2026-07-24 — Reload-safe handoff and post-run review workflow

### Problem 1 — A completed pending candidate could not be reviewed in the UI

- **Cause:** the original review control only called the durable-run `resume`
  endpoint and appeared when the research run was paused. This run completed
  successfully while correctly leaving a separate MoonBook candidate pending.
- **Fix:** added an independent review state machine in the MoonBit UI:
  reviewer identity and outcome selection, exact subset scope, review-plan
  creation, plan inspection, proposal promotion, explicit durable-run
  confirmation, and status refresh. `approve_subset` is rejected before any
  session is created unless exact claim IDs or sections are supplied.
- **Test:** pure tests cover allowed outcomes, required identity/rationale,
  approval scoping, bounded decision-packet content, and completed-run mapping.
  Rendered browser validation confirmed empty-form errors and the exact-scope
  approval error. No review session or decision was created during validation.
- **Outcome:** a named human can record the eventual decision through the UI
  even though the original research run is already complete.
- **Remaining limitation:** the workflow intentionally does not choose a human
  outcome. The workspace owner must still supply and confirm it.

### Problem 2 — Browser reload forgot the verified Q&A agent

- **Cause:** MoonClaw persisted the Cowork session, but the UI's in-memory model
  started empty and offered to prepare another agent after reload.
- **Fix:** the UI now loads `moonfind-workspace.json` during initialization and
  reconnects both the completed research session and the grounded Q&A session
  by their persisted keys.
- **Test:** after a production rebuild and full reload, the rendered UI showed
  research `Completed`, steps 4, 5, and 7 as `DONE`, the original durable run,
  Q&A session `cowork:e61c6c50-2385-4181-8eae-95075ce94f10`, and the full
  verified cited answer.
- **Outcome:** the handed-off agent is visibly ready after reload instead of
  merely existing in gateway storage.
- **Remaining limitation:** recovery depends on the local MoonClaw gateway and
  its persisted session being available. A missing gateway fails visibly
  rather than silently creating a replacement.

### Problem 3 — The two-column shell compressed the decision surface on narrow screens

- **Cause:** the main grid used a fixed two-column track definition whose
  second column could become too narrow.
- **Fix:** replaced it with an auto-fit grid that stacks when a usable
  520-pixel content track cannot fit.
- **Test:** production build and rendered inspection show no overlap or clipped
  fields; controls retain a minimum 44-pixel action height and visible
  labels/focus.
- **Outcome:** review and Q&A remain usable as complete vertical surfaces at
  narrow widths while preserving the established visual system.
- **Remaining limitation:** physical-device screen-reader testing was not
  performed; the controls use native labels, select, inputs, textareas, and
  buttons to retain platform semantics.

The requirement-by-requirement proof is recorded in
`docs/DEEPSEEK_COMPLETION_AUDIT.md`.
