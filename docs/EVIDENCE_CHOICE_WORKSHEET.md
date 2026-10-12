# Evidence-to-choice worksheet

## Continue a decision after evidence changes

Open **Compare updated evidence** in the existing worksheet to see added,
changed and removed sources, claims and analysis, including exact before/after
version IDs, digests, retrieval records and claim text. A missing projection is
unavailable evidence, not a removal. Complete empty evidence is an explicit
removal. Duplicate or inconsistent source/claim identities block continuation.
Retrieval-time-only changes have their own **Retrieval refreshed** status:
continuing preserves the active source/claim selection while archiving the
earlier receipt. Other identity, content, version or digest changes remain
material changes requiring citation review.

**Continue with this evidence** is a single explicit local-draft action bound to
the displayed worksheet revision and loaded evidence. It keeps the complete
outgoing worksheet in history, adopts the current same-run evidence into the
source menus, and preserves user criteria, assessments, chosen option, reasoning
and next action. These remain user preferences, not revalidated findings.
Changed/removed or already-unresolved references become Unknown in the active
worksheet; exact earlier source/claim receipts and original IDs remain clearly
historical. Selecting a new citation is a subsequent user edit.

JSON backups contain all retained versions. Each earlier version also has its
own JSON and Markdown download. History is limited to 20 versions and the
portable formatted backup to two million characters. Continuing stops before
either limit; no original is silently dropped. Download the existing complete
backup at the limit. Restoring an older backup remains an explicit replacement
of the current browser-local draft, so first download the outgoing draft.

The unchanged v1 decision envelope and status strings remain importable by
MoonProj. The paired continuation-aware consumer retains optional historical
context; older consumers ignore those additive fields, so keep the complete
MoonFind JSON backup when using an older MoonProj version. No provider request,
company decision or evidence acceptance is created by continuation.

The research workspace includes **Compare choices and decide the next test**.
This is a provider-free, user-authored decision brief over retained research.
It implements the bounded comparison and falsifying-experiment part of
**MOONFIND-R02 / MOONFIND-F02**. It does not automatically recommend or rank an
option, record a MoonProj decision, or establish that a customer will buy.

## Daily workflow

1. Load an existing research workspace. The worksheet snapshots its question,
   source records and attributed analysis summaries. Publication/update dates,
   retrieval time, source version and digest travel with each source when the
   host provides them. Absent dates stay **Unknown**.
2. Name two to four alternatives and one to six shared criteria. Write each
   option's assessment against the same criteria. Empty assessments remain
   **Unknown / not recorded**; they are never converted into favorable scores.
3. Open **Sources, uncertainty and experiment** on an option. Select a strongest
   retained source and, optionally, an attributed analysis claim. Inspect the
   source link, dates, exact version/digest, claim location and counterevidence.
   Record disagreements, unknowns, cost of being wrong, and the smallest
   experiment that could distinguish the choices.
4. Optionally choose a direction, explain why, and record the next action.
   The choice is explicitly user-authored. Renaming an alternative or criterion
   preserves its source references and stable option identity.
5. Download the Markdown decision brief or its versioned JSON brief/backup.
   The files contain the question, audience, all criteria/assessments, option
   identities, selected direction, rationale, next action, retained evidence
   and limitations. An optional MoonProj commitment reference is portable text
   for attaching manually to existing work; no peer API is invoked.

## Local continuity and evidence freshness

Edits autosave under a browser-local key containing both the trusted workspace
and run identity. Save success is reported only after readback. It is not a
MoonBook or server persistence receipt. Keep a downloaded JSON backup when the
work matters or before changing browser/profile/device.

Failed writes leave edits in memory and show a backup/retry instruction. Moving
between runs or workspaces in the same session retains independent in-memory
drafts, including failed saves. A browser close after failed storage cannot be
recovered without a downloaded backup. Unreadable saved data pauses automatic
replacement and remains available in the recovery input.

To restore, download the outgoing draft if needed, open **Restore a worksheet
backup**, paste the complete JSON brief or worksheet, and explicitly restore.
Restore accepts this feature's own exported envelope, requires the same run and
bounded option/criterion shape, and does not alter research or review state.

Source changes do not silently replace the worksheet's source basis. Changed,
removed or unavailable source context produces a historical warning; retained
citations and direction remain inspectable and exportable with that warning.
This first slice does not automatically merge new research into an old brief.
Equality to a loaded projection is a continuity check, not an independent
attestation of source truth or provenance.

## Contracts and implementation

- `moonfind.choice-worksheet.v1`: local draft and retained evidence snapshot
- `moonfind.decision-brief.v1`: export envelope, continuity status, authority
  boundary, `company_decision_recorded: false`, and complete worksheet
- `schemas/choice-worksheet.schema.json`: portable shape
- `ui/rabbita-moonfind/main/choices*.mbt`: state, persistence, view, export,
  and focused tests

No new HTTP endpoint, model invocation, source fetch, provider spend, external
sharing, review authority or company-decision authority is introduced.

## Verification and limits

The actual published-main-based UI, with the separately documented baseline
repair, passes **98/98 JS tests**, `moon check --target js --frozen`, and a
release JS build. The seven new tests cover bounds/unknowns, stable citations,
complete exports and own-format restore, stale sources, real browser-storage
API stubs with quota/read failure, independent run/workspace retention, and
rendered accessible controls, and collision-free option identities after restoring
and extending a portable backup. Existing model-route, research/review, delivery
and Q&A tests remain in the same full UI suite.

`moon fmt` and `moon info --target js --frozen` were run. Unrelated formatting
changes to existing fixture files and package metadata were discarded.

Live browser interaction, physical download behavior, visual layout and screen
reader behavior remain unqualified. A prepared synthetic Chromium harness is
retained in the round-two verification deliverable for the user's testing.
It was not executed successfully; its browser launch was blocked, and no
alternative browser route was used. No native or provider behavior changed in
this slice.
