# Source-bound experiment workflow

MoonFind's existing comparison worksheet now supports up to 12 separate test
cards per research run and Book workspace. This is browser-local work. MoonFind
does not run the experiment, contact a provider, verify an observation, record a
MoonBook review, or approve a MoonProj commitment.

## Use it

1. Load a research workspace and open **Compare choices and decide the next test**.
2. Name an existing option and select its strongest retained source. If you also
   select an analysis claim, that claim must cite the selected source.
3. Under **Plan a source-bound test**, choose **Start test card** for that option.
   The card captures its original question, full option, comparison criteria,
   source receipts and analysis. The old free-text experiment note seeds the
   procedure without altering the original note.
4. Enter the hypothesis, procedure, measurable outcome and units, disconfirming
   threshold, and constraints/stop conditions. Drafts autosave. An incomplete
   card can be downloaded but is clearly marked as a draft.
5. Choose **Freeze test plan**. Plan fields then become read-only. Start a new
   card to change the plan or run the test again.
6. Download the readable plan and perform the test outside MoonFind. Return to
   record your own observations. Choose **unknown**, **incomplete**, or
   **measured**; enter measurements and units where available, and describe gaps
   or limitations. Choose **Record my reported observations** explicitly.
7. Review the original snapshot and current alternatives. Propose a current
   option or Undecided, explain remaining uncertainty, and give a next action.
   **Apply my choice revision** is the only test-card action that changes the
   local worksheet's chosen option, reasoning, and next action. It retains the
   complete outgoing worksheet as an earlier version.

## Persistence and recovery

- **Download JSON brief / backup** includes every test card and retained
  worksheet version. The existing same-run JSON restore control restores it.
- Older `moonfind.choice-worksheet.v1` and `moonfind.decision-brief.v1` backups
  without experiment fields remain valid. New records use the nested contract
  `moonfind.choice-experiment.v1`.
- A test's original option and source never follow later edits, removal, evidence
  continuation or chosen-direction changes. Historical or unavailable current
  context is visibly marked. Source metadata and user reports remain unverified.
- Plans, reported observations and applied revisions are frozen independently.
  A second test card has its own plan and observations.
- No history is silently evicted. Limits are 12 test cards, 20 retained worksheet
  versions, 10,000 characters per experiment entry and a 2-million-character JSON
  backup. At a limit, download the complete existing backup; the blocked action
  leaves prior work intact.
- Browser save failure leaves edits in the current session and displays a
  warning. Download a backup or retry Save. Unreadable stored bytes are preserved
  until you explicitly restore a valid backup.
- Actions from an older rendering are rejected when the Book/run key, exact
  worksheet, revision, or loaded evidence preview has changed.

## What an observation means

An observation is explicitly what the user reports, including an unknown or
incomplete result. MoonFind does not compare free-text measurements to the
threshold, declare success or failure, rank alternatives, or turn an experiment
into established truth. A choice revision is a recorded user judgment and may
remain uncertain. Its earlier worksheet and original source are retained.
