# MoonFind product contract

Class: general research domain pack
Maturity: evidence-backed research alpha
Product direction revised: 2026-09-26

## Outcome

MoonFind takes a research job with a stated objective, audience, source scope,
requested outputs, and acceptance criteria. It delivers a usable bundle of
files with evidence, verification records, explicit gaps, and review state.
Literature synthesis, local-corpus analysis, comparison, evidence briefs, and
experiment planning are job types. Humanoid robotics remains one specialization.

The primary user outcome is a file the user can open and use. A research run or
review candidate alone is not a completed delivery. The general
`moonfind.research-job.v1` and `moonfind.delivery-manifest.v1` contracts define
the brief and the required delivery evidence. The first runtime slice saves
jobs, plans and runs them through MoonClaw, and exposes real output files. The host can
issue a manifest after checking actual bytes, file references, and submitted
criterion receipts. That is ready for researcher review; the host does not
assert that the research claims themselves are true.

## Ownership

MoonFind owns job intake, output acceptance criteria, research evidence
admission, source-grounded synthesis, artifact assembly, delivery verification,
and research-review state. Domain specializations remain in their own packages.

MoonFind does not call providers directly, install capabilities or approve its
own ideas. MoonClaw is the sole agent runtime, MoonTown challenges
cross-paper bridges, MoonBook owns accepted learning and MoonFlow owns canary or
shadow activation.

## Capability status

| Capability | Status |
| --- | --- |
| Deterministic fixture and Rabbita workspace | available |
| General job and delivery contracts | validated contracts available |
| General job intake and MoonClaw plan/run | available when a MoonClaw gateway is configured |
| Paused run recovery | waiting reason and resume input available in the job screen |
| File delivery view | lists actual output bytes, SHA-256 digests, and missing filenames |
| Source intake | pasted text/structured files, arXiv metadata and abstracts, and public HTTPS snapshots with retrieval records |
| Preview and export | inline text/image preview plus complete ZIP of sources, outputs, evidence, and delivery records |
| File revision | child research job preserves prior output and source snapshots, then runs through MoonClaw and delivery verification |
| Delivery manifest | host-issued from current files and submitted check receipts; stale output detected |
| Independent scientific acceptance | named researcher review still required |
| arXiv metadata intake | conditional public research adapter |
| MoonClaw `gpt-5.6-sol` work packet | available when a MoonClaw host is configured |
| MoonTown cross-paper handoff | available locally |
| Exact 63-stage robotics desired graph | available; imports only against a complete healthy catalog |
| Synthetic 43-operation robotics catalog | fixture-only; never production evidence |
| Full-text hostile-PDF isolation and evidence record | available as governed path |
| Crossref/OpenAlex/Semantic Scholar/licensed full text | deny-by-default until terms approval |
| Automatic capability promotion | excluded |

## Evidence and document security

Full text enters an agent packet only after permitted-use review, digest-bound
isolation, disabled networking, active-content removal, size/page limits and
page/section locators. Abstract-only evidence must not be described as
full-text review.

## Closed-loop contract

```text
job brief → permitted evidence → MoonClaw work → cited draft
→ artifact verification → deliverable bundle → named review
→ MoonBook outcome binding → optional Bookkeeper Three-Gap learning
```

Every transition uses a versioned portable receipt; no sibling source checkout
is an integration contract.

## Verification

```sh
moon check --target native
moon test --target native
moon info
moon fmt
```

Provider acceptance additionally requires recorded terms, rate-limit behavior,
recovery and evidence-location quality.

The robotics composition stops at a named digital-deliverable authority
decision. It deliberately excludes physical robot commands, publication, and
the MoonFish finance domain. MoonFlow executes; MoonGate and MoonLib support;
MoonEdit and MoonLeaf remain libraries.

## Release gates and next milestones

1. Repeat the clean native build and installed-pack MoonDesk proxy smoke test
   for a release build. The current temporary installation verified and its
   source, preview, ZIP, revision, and resume routes were exercised.
2. Complete a general job through MoonClaw in a real workspace, persist
   its session, proposal and run identities, and reconcile after restart.
3. Complete the exact requested files, evidence links and acceptance-check
   receipts in live jobs; inspect the host-issued SHA-256 manifest and open path.
4. Continue live qualification on additional real research briefs. The four
   job shapes pass the shared multi-file delivery test. Live literature,
   local-corpus, comparison, and humanoid jobs have produced multi-file
   outputs through MoonClaw and passed host verification. A literature bundle
   retained ready state after host restart. The humanoid run paused on a
   missing schema request, resumed on the same run, and delivered both files.
5. Expand licensed evidence sources and full-text extraction for jobs that
   need them. Add editing, figures, team features, and compute according to
   observed user demand.

The robotics canary and Three-Gap loop remain valuable downstream work. They
are no longer the primary gate for a general research delivery release.
