# Compare choices from an offline brief

Use the normal `/apps/moonfind/briefs` entry. Save or reopen a complete prepared brief in the existing brief studio, then choose **Open saved comparison or start from this revision** below it. No research workspace, MoonClaw configuration or provider is required.

The comparison keeps a typed offline basis: the exact brief ID and immutable revision, all source slots, filenames, user-supplied origin and capture time, availability, native digest receipts, byte counts and original captured bytes. Duplicate filenames remain distinct by source slot. Local captures are not silently presented as papers, publication dates, extracted findings or model-authored claims.

Enter two to four alternatives and one to six shared criteria. For each alternative, record your assessment, strongest local capture, contradictions, unknowns, cost of error and smallest next experiment. A chosen direction, rationale, audience, optional commitment reference and next action are user-authored fields. Missing entries stay unknown; there is no ranking, inferred validation, executed experiment, company task, review or approval.

## Save, reopen and export

Edits autosave in this browser with visible verified-save or failure status. Reopen the saved native brief, then use the same comparison button to resume. Storage is scoped to this browser origin and brief ID, not a native workspace: the brief API supplies no workspace identity. If two workspaces served from the same origin reuse a brief ID, its existing local comparison can reappear with its original exact basis. It never silently rebinds; use distinct brief IDs or browser profiles for independent comparisons. Unsaved drafts are additionally retained when switching brief IDs during a visit. A quota failure leaves local edits available for retry or backup. Corrupt or unreadable browser data pauses overwriting and exposes recovery text for copying; a deliberate valid JSON restore is required to resume writes.

**Download complete offline brief · Markdown** includes every user field, the complete retained source dossier as readable text, and all earlier worksheet versions. **Download complete offline JSON / backup** preserves exact original source bytes as hexadecimal plus all identities and history. Both expose the exact export text for copying if a download is unavailable. Download confirmation means a browser download request, not an exercised OS save dialog.

The distinct contracts are `moonfind.offline-choice-worksheet.v1` and `moonfind.offline-decision-brief.v1`. They have no fabricated research run or claims. Existing research-run worksheet/decision-brief v1 files remain unchanged and cannot be imported into this offline editor; offline exports do not claim MoonProj import compatibility. The per-option next-experiment field is an unexecuted user plan; research-run-specific experiment cards and observed-results workflows remain separate.

Restore explicitly replaces only the local comparison for the same brief ID. Download the outgoing version first. Imported historical source copies are user-supplied and do not independently establish current native retention. The UI reports a native-basis match only when the entire current retained basis equals the currently opened complete native snapshot.

The browser validates shape, source/option/history consistency and UTF-8, but does not recompute source or revision digests. Displayed digests are recorded native receipts or user-supplied imported values. Conflicting basis data under an already-known immutable revision ID is rejected without replacing the retained worksheet.

Controls are bound to the active comparison and its session generation. Restoring even a same-revision backup or switching away and back invalidates old edit, export, restore and continuation actions; a cached worksheet cannot revive an earlier session generation.

## Continue with a changed saved revision

Unsaved brief edits cannot be a comparison basis. Save/reopen a new immutable revision, inspect the source comparison, and choose **Continue explicitly with this saved basis**. Merely opening a revision never replaces worksheet evidence or carries decisions silently.

Continuation retains the entire earlier worksheet and its source bytes. A changed or removed selected source becomes unresolved in the new version and its exact historical citation remains inspectable. Unchanged source content and provenance keep their selection. Assessments and the chosen direction are carried user entries, not revalidated findings; review them yourself. Earlier versions remain separately downloadable.

Retention is bounded to 20 earlier worksheet versions and a two-million-character complete JSON backup. Operations that would exceed a bound stop without discarding history. The underlying native dossier remains limited to eight local captures, 32 KiB each and 128 KiB total. Source text and user-provided provenance remain unverified evidence; digest agreement does not prove scientific or customer validity.

## Qualification boundary

Compiled controller/storage/render tests cover ordinary offline entry, exact source basis, duplicate names, Unicode/CRLF, full exports/restores, unsaved/incomplete/stale native state, changed-source continuation, cross-brief isolation, corrupt storage and quota failure. The opt-in native test exercises actual brief save/reopen/revision HTTP through compiled controllers and verifies that comparison/edit/export/continuation actions themselves make no native requests. Fixture brief POSTs are disclosed separately.

R46 review-draft source ancestry and regressions are preserved. No graphical browser, keyboard/assistive technology, OS file chooser/save dialog, provider execution, customer validation, deployment or company-import acceptance is implied.
