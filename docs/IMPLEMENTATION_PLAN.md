# Moonfind implementation priorities

Revised 2026-09-26. The product target is a general research job that ends in
usable, inspectable files. Humanoid robotics is a specialization of the same
job path. MoonClaw remains the only agent runtime; MoonFlow owns generic
activation; MoonBook owns reviewed memory and Three-Gap records.

## P0 — make one general job deliver real files

1. **Prove installed-pack execution.** Native check and tests, a temporary
   pack install and verification, and MoonDesk proxy smoke tests pass. The
   proxy served source intake, preview, ZIP attachment, revision, and resume
   route handling. The general MoonClaw path completed live jobs and reloaded
   their delivery state after host restart. Repeat the smoke test for a
   release build.
2. **Persist a job brief before execution.** Accept an objective, audience,
   source scope, requested output kinds/formats, and acceptance criteria via
   Rabbita and a typed host endpoint. This first slice is implemented for
   prompt-driven jobs. Extend it to local corpus and research watch without
   requiring a fixed research recipe.
3. **Run the generic research path through MoonClaw.** The host opens a
   Cowork session, persists its key, plans the output-oriented brief, promotes
   it to a proposal and starts the writable MoonClaw job run. It records
   proposal and run IDs. A finished run's files are imported into the
   MoonFind delivery folder on refresh. A waiting run now exposes its reason
   and a response field in the job screen; add a richer progress timeline.
4. **Assemble the delivery bundle.** Create each requested file under a safe
   workspace-relative path, record its actual digest and byte length, link
   source or generation evidence, and run every declared acceptance check.
   The trusted host now issues `moonfind.delivery-manifest.v1` after checking
   current file bytes, referenced evidence files, and submitted criteria
   receipts. It detects changed outputs. Independent scientific review of
   those receipts remains necessary.
5. **Make delivery the UI endpoint.** The UI now shows actual files, open links,
   text/image previews, ZIP export, missing requested filenames, verification,
   and stale-manifest status. Citations and unresolved gaps remain visible in
   the artifact and manifest; richer checks are still useful. Review remains
   pending at handoff.

**P0 exit gate:** From a fresh install, complete one literature brief, one
local-corpus report, and one comparison job with different requested output
sets. Each returns actual files and a verified manifest through the UI. Kill
and restart the host during one run without duplicating work or losing files.

## P1 — improve research depth and output quality

1. Supplied text, public HTTPS snapshots, and arXiv metadata/abstracts now
   enter the generic job's `input/`. Add licensed source adapters in order of job demand. Keep source terms,
   model-input rights, retention, and full-text isolation fail-closed.
2. Add reusable deliverable recipes: cited report, evidence table, technical
   memo, experiment plan, and reproducible figure. A recipe supplies default
   files and checks; the user can adjust them in the job brief.
3. The first revision loop creates a child job for one requested file, copying
   prior sources and the file into `input/` and recording parent ID, base digest,
   and requested change. Extend the UI to compare versions, carry reviewed
   evidence links forward, and choose a final version.
4. Add job-level quality checks for unsupported claims, missing citations,
   unreported exclusions, broken file references, and incomplete requested
   outputs. Separate deterministic checks from model-based critique.
5. Show source coverage and limitations beside the final files. Do not call
   abstract-only intake a full-text review or an unreviewed draft accepted.

**P1 exit gate:** A user can request, inspect, revise, and export a multi-file
research package without navigating MoonSuite internals. Independent review
can trace every material claim to a permitted source and every final file to
its verification record.

## P2 — broaden the workspace where demand justifies it

- Add manuscript/LaTeX editing, figure editing, code execution, remote compute,
  team workspaces, and cross-device continuity according to observed use.
- Expand job types beyond literature: data analysis, technical assessment,
  due diligence, policy research, and competitive research, each with fitting
  output recipes and evidence rules.
- Keep MoonTown challenge, named review, MoonBook outcome binding, and
  Three-Gap learning available as explicit job stages or downstream work.
- Continue the humanoid robotics and lunar series graphs as specializations;
  their synthetic catalogs cannot serve as production readiness evidence.

## Current assets and boundaries

Moonfind already has arXiv metadata intake, local-input accounting, typed
research records, MoonClaw packet preparation, MoonTown handoffs, review
contracts, recovery journals, provider policy, full-text receipt validation,
and a Rabbita research workspace. These are inputs to the new primary journey.
The four literature, corpus, comparison, and humanoid brief shapes now pass
one shared multi-file verification and ZIP test. Separate live literature,
local-corpus, comparison, and humanoid jobs have produced files through
MoonClaw and passed host checks. The literature bundle reloaded after a host
restart. The humanoid run resumed from a waiting step and delivered a digital
plan and CSV risk register. This does not substitute for named scientific review.
The real isolated PDF extractor, licensed provider agreements, production
adapter health, document-native previews and editing remain operational or
implementation work. A local MoonClaw run has produced a report and CSV
through the generic host route; the host verified actual bytes and evidence
links, while scientific acceptance still needs review. The checked-in robotics catalogs
and complete-run fixtures are synthetic qualification data.

## Non-goals for the first general release

- Replacing MoonClaw with another model or agent runtime.
- Requiring a robotics experiment, MoonTown salon, or Three-Gap closure for
  every completed research job.
- Treating a generated draft, a manifest with unverified files, or an agent
  success receipt as a finished user deliverable.
