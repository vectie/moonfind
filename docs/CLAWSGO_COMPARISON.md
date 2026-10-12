# MoonFind and ClawsGO Science: product comparison

Reviewed 2026-09-26 against the public [ClawsGO China site](https://clawsgo.cn/)
and [English site](https://clawsgo.ai/), this MoonFind checkout, and the latest
local MoonDesk checkout (`fd80e8ea`, plus uncommitted work). ClawsGO's site is
a product presentation, so examples of hours-long runs, full-text screening,
model accuracy, and host reliability are claims rather than independently
verified operating evidence. This comparison concerns ClawsGO Science, not the
unrelated similarly named OpenClaw device.

## The customer promise

ClawsGO presents a single research question that turns into an unattended,
traceable task and a reviewable set of files. Its examples include a cited PDF,
LaTeX draft, evidence CSV, plots, and reproducible figure packages. It shows
tool steps, progress, revising a figure, cloud/desktop continuity, selectable
models, and remote lab GPU use. Its public example treats the *files* as the
finish line. See its [question-to-deliverable walkthrough](https://clawsgo.cn/)
and [English feature overview](https://clawsgo.ai/).

MoonFind's previous visible journey was narrower: arXiv and local evidence
intake, humanoid research synthesis, MoonTown challenge, named review, MoonBook
learning, and capability activation. Those are valuable research controls,
but a general researcher could not simply request a report or figure and
retrieve it from the primary UI. The new job path closes the first part of
that gap while keeping the specialized path available.

| Dimension | ClawsGO public presentation | MoonFind now | Next decision |
| --- | --- | --- | --- |
| Starting point | One prompt or task, with project and file context | General objective, audience, source scope, requested filenames; durable job folder | Attach local corpus and research watch without forcing a preset workflow |
| Execution | Unattended agent; visible search, code, writing and checks | Host-owned Cowork session, plan, proposal and writable MoonClaw run | Progress timeline and restart reconciliation |
| Deliverables | PDF, manuscript, CSV, figures and code shown together | Any final file in `outputs/` is listed with bytes, SHA-256 and an open link; host-issued manifest checks current bytes and submitted evidence receipts | Preview, versioning and bundle export |
| Evidence | Citations and citation review shown in examples | Governed research records and full-text admission exist in specialist path | Link general-job claims and files to admitted evidence; verify citations |
| Revision | Figure annotations and version history shown | Researchers can revise files in the job folder; no UI revision loop | File-targeted feedback, revision history and comparison |
| Reproducibility | Command/environment replay and figure package claimed | Durable run journal for specialist path; general job files and session key | Capture general-job commands, environment, input and output lineage |
| Source breadth | Several literature sources shown in example | arXiv metadata and controlled local-input path; other policies deny by default | Add sources according to research demand and usable terms |
| Compute | Cloud resident jobs and remote lab GPU shown | Local MoonClaw gateway path | First make local jobs recoverable; add remote compute when a real job needs it |
| Cross-device | Web, phone and desktop sync claimed | MoonDesk pack app and Rabbita UI; installed proxy path exercised | Follow MoonSuite host continuity later |
| Models | Model menu on public site | MoonClaw only runtime; job UI accepts a MoonClaw model | Discover supported models without adding provider calls |
| Review and learning | Reviewable files and correction loop | Named review, MoonTown, MoonBook Three Gap in specialist workflow | Offer them as optional stages after delivery, not compulsory gates |
| Specialization | Broad science examples | Strong typed humanoid and lunar scenario knowledge | Keep specializations as recipes and evidence policies on a general job base |

## What MoonFind can differentiate on

1. **Truth about evidence and completion.** A task run, file presence, source
   admission, scientific acceptance, and named review are different states.
   MoonFind can show these clearly rather than imply a finished paper from an
   agent success response. The new file list checks the bytes; the delivery
   manifest is host-issued from actual bytes and submitted check receipts;
   scientific truth still needs researcher review.
2. **Domain depth without a domain lock.** `research/` defines general jobs,
   `arxiv/` handles that transport, and `humanoid/` retains its own semantics.
   A cited literature review, data analysis, comparison memo, or experiment
   plan should share the same intake and delivery path.
3. **A workspace-first result.** Files sit in a clear MoonSuite job directory,
   where MoonDesk can inspect and edit them. The agent may try new approaches,
   create scratch files, and add useful outputs; only the requested results and
   their checks control the delivery claim.
4. **Portable authority boundaries.** MoonClaw runs agents, MoonFlow owns
   activation, and MoonBook owns durable reviewed learning. MoonFind can keep
   research evidence, method, and review portable across those services.

## MoonDesk integration findings

The latest local MoonDesk has a generic pack-app binding, so MoonFind can
expose `/apps/moonfind/jobs` through `pack.json` without domain code in
MoonDesk. MoonDesk's [template system](../../moondesk/docs/TEMPLATE_SYSTEM.md)
currently opens a pinned owner preview; it explicitly does not create a
MoonFind template instance or launch its workflow. The current catalog entry
is the specialized Lunar Habitat Decision Series, which is blocked on named
cross-product seams. Therefore the immediate general-job route should be a
normal MoonFind pack app. A template can later prefill the same job brief and
let MoonFind persist its instance after owner confirmation.

MoonDesk's recent work also emphasizes the workspace as a place to inspect
and revise files. MoonFind should hand back a job directory and finished
artifacts that MoonDesk can open, rather than duplicate MoonDesk's editor.
The app entrypoint and job root are now present. An installed-pack MoonDesk
proxy smoke test opened the UI and served a Markdown output with its original
content type; a richer file handoff remains open.

## Reprioritized sequence

**Now:** Local question-to-files journeys have completed through MoonClaw,
including a fresh brief, source input, Markdown report, CSV table, evidence
receipt and host-issued multi-file manifest. The session, proposal and run
IDs persist; the UI shows progress and missing outputs. Keep arbitrary
research objectives and file formats.

**Next:** Add artifact preview/export, stronger citation provenance, and
researcher review of submitted criteria receipts. Test three unrelated live
jobs with different outputs. Add revision requests against a specific file.

**Later:** Expand licensed sources, cloud/remote compute, team workspaces,
mobile continuity, and recipe catalogs in response to observed job demand.
These should not hold up the basic research delivery path.
