# DeepSeek Moonfind completion audit

Audit date: 2026-07-24
Moonfind kind: `DomainPack`
Research session: `cowork:2d9040cb-17f3-4cc1-8832-2ef54f74286b`
Research run: `run-20260724-011206-e43d09`
Retained Q&A session: `cowork:e61c6c50-2385-4181-8eae-95075ce94f10`

This audit tests the original handoff requirements against current artifacts
and runtime state. A passing item has direct evidence; absence of a known
problem is not treated as proof.

## Requirement evidence

| Requirement | Authoritative evidence | Result |
|---|---|---|
| Use Moonfind as a pack system | `pack.json` declares `kind: DomainPack`, requires MoonClaw, MoonTown, and MoonBook, and registers the research and Q&A contracts. | Pass |
| Use agents through the UI, not a CLI research workflow | Persisted UI-created research session points at `codex/gpt-5.6-sol` and the selected MoonBook workspace. Its durable run status is `Succeeded`. The browser restores this session after reload. | Pass |
| Account for everything in `~/Downloads/deepseek` | Filesystem has 17 files. `state/local-input-coverage.json` expects 17, accounts for 17, marks all 17 `Used`, records zero failures, totals 10,090,281 bytes, and keeps page 1 explicitly missing. | Pass |
| Produce one research report rather than concatenate screenshots | `wiki/synthesis/deepseek-research-report.md` is a 367-line synthesis with an executive judgment, bounded thesis, alternatives, contradictions, scenarios, and open gaps. | Pass |
| Process information through MoonBook | The book workspace contains navigation, source records, synthesis, a 20-claim matrix, pending review candidate, explicit review state, Three Gap queues, and a retained Q&A packet. MoonBook projection now fails closed for pending unauthenticated sources. | Pass |
| Gather and cross-validate public information | `wiki/sources/external-validation.md` records 10 public-primary sources and one explicitly secondary source, with direct URLs, retrieval metadata, chronology, qualifications, and non-findings. | Pass |
| Use MoonTown to generate and challenge ideas | `wiki/synthesis/moontown-challenge-iteration-20260724.md` contains 16 provenance, technical, economic, and synthesis challenges that remain labeled analysis rather than source evidence. | Pass |
| Refine over several iterations | The durable run completed source mapping, primary-source validation, MoonTown challenge, claim-matrix refinement, report refinement, MoonBook candidate creation, and Q&A grounding across eight phases. | Pass |
| Build missing tools or contracts | Moonfind added typed local-input accounting and gates, a first-class `read-only-qa-grounding` schema, and the review-gated `book.prepare-read-only-qa-grounding` tool. MoonClaw Cowork gained an actual user turn plus bounded read-only file tools. | Pass |
| Use MoonBit for product code | Authored Moonfind and book sources contain zero `.py` files outside dependency/build caches. Product changes are MoonBit, JSON Schema, JSON state, and Markdown artifacts. | Pass |
| Document problems and solutions | `docs/DEEPSEEK_RESEARCH_JOURNEY.md` records each reproduced problem, cause, fix, test, outcome, and remaining limitation, including UI propagation, MoonBook status inference, grounding registration, and Cowork execution. | Pass |
| Hand over a report in MoonBook | The report, canonical claim matrix, review candidate, queues, review state, and handover outputs exist in `/Users/kq/Workspace/deepseek-research-book`. | Pass |
| Supply an agent ready to answer questions about the material and DeepSeek | The retained MoonClaw session is `grounded_verified`, hosted, and persisted. A fixed question produced a cited `pending-review-book` answer using book-relative local anchors and direct public URLs. The Moonfind UI reconnects the agent automatically after reload. | Pass |

## Integrity and validation evidence

- 10/10 Q&A grounding artifacts match their frozen SHA-256 values.
- The activated grounding manifest validates against
  `moonfind.read-only-qa-grounding.v1`.
- Citation domains are complete: `C01–C20`, `L01–L123`, `P1–P10`, `S1`, and
  `MC01–MC16`.
- Moonfind root tests pass 15/15 before the final UI slice; the final UI package
  tests pass 8/8.
- MoonClaw root package tests pass 5/5, including the read-only Cowork tool
  boundary.
- MoonBook targeted knowledge-bundle tests pass 3/3.
- MoonBook full `wiki` suite passes 182/183. The sole failure,
  `moonclaw jobs include role runtime metadata`, is pre-existing, independently
  reproducible, and unrelated to this research path.
- `moon check`, `moon info`, production UI build, JSON parsing, JSON Schema
  validation, and `git diff --check` pass for the changed scope.

## Review state and authority

The report is handed over as a completed research candidate, not as
self-approved memory:

- `moonbook_review_state`: `pending_review`
- `accepted`: `false`
- `durable_memory_promotion_state`: `not_promoted`
- approved queue: empty

This status is not a missing deliverable. It is the correct result of the
named-human authority boundary. The UI now supports a separate post-run
decision workflow with explicit outcome selection, exact subset scope for any
approval, plan inspection, proposal promotion, and durable-run confirmation.
No decision was fabricated during the audit.

## Completion judgment

Every original implementation and handoff requirement has direct evidence and
passes. The optional next action is the workspace owner's MoonBook decision;
it changes review status but is not required for the report and verified Q&A
handoff to exist.
