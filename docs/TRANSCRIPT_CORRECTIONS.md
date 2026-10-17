# Correct interview transcript text and reuse the revised source

The time-coded quotation panel can prepare a user-edited working copy of a local
WebVTT or SubRip transcript. Correct supplied wording or a speaker annotation,
compare against the loaded original, and retain or download a usable revised
transcript. No media is loaded and no correction is asserted to match speech.

## Try the complete local workflow

1. Open `/apps/moonfind/briefs`. In **Time-coded interview quotations**, import
   `fixtures/interview-transcript.vtt` (synthetic), or reopen a loaded transcript.
2. Select cue 3 for quotation, then choose **Correct cue 3**. The editor shows
   its original text and unchanged timestamp. For this demonstration, replace
   `Five minutes.` with `Fifteen minutes.`. This is a synthetic user correction,
   not a verified finding. Leave the other text as supplied.
3. Choose **Apply cue correction**. Expand **Compare changed cue 3** to inspect
   both versions. **Cancel cue edit** abandons only current typing; previously
   applied corrections stay. **Restore original cue 3** removes that correction.
4. **Download revised VTT / SRT** requests a complete reusable caption file.
   It includes unselected cues and all original non-cue content, with only the
   corrected payload spans replaced. A download leaves the editor unchanged.
5. Choose **Retain revised transcript and use quotations**. One new ordinary
   `.vtt.txt` or `.srt.txt` capture appears beside the original. It opens in the
   quotation panel, preserving your cue selection. Search `fifteen` and preview
   the existing quotation report. Its source origin identifies user-edited text.
6. **Add quotations to brief** or download the Markdown quotation report using
   the existing controls. Save the brief normally. When reopening a saved brief,
   choose the revised source in **Reopen a loaded transcript**. The original,
   revised transcript and selected quote remain separate sources.

The same workflow accepts `fixtures/interview-transcript.srt`. Duplicate supplied
SRT numbers stay distinct because editing uses the one-based source cue ordinal.
Changing one cue numbered `42` does not alter another cue also numbered `42`.

## What changes, and what stays exact

- Only cue text can be edited. Cue order, identifiers, timing lines, settings,
  start/end times and overlap remain unchanged. The revised result is parsed
  again before application and must retain the same cue identities and timing.
- Original capture bytes are never replaced. The revised file retains its BOM,
  header, NOTE/STYLE/REGION blocks, separator lines, and all unchanged cue bytes.
- The editor normalizes entered CRLF/CR to LF. For a modified payload, its first
  original payload delimiter is used between the new lines (or the timing-line
  delimiter when the original last line was unterminated). The final payload
  delimiter retains its original spelling or absence. New line counts can move
  subsequent physical line locators; revised quotations use the reparsed lines.
- Nonempty text is required. Blank/whitespace-only lines, timing arrows and
  binary controls are refused because they can break the supported cue syntax.
  Unsupported or oversized changes remain in the editor for repair; no partial
  source is added.
- WebVTT speaker annotations can be edited as literal text. Search and the
  supplied speaker label update after retaining the revised capture. No identity
  is inferred, and SRT speaker labels remain literal payload text.

## Saving, limits and recovery

Corrections are session-only until retained or downloaded. Saving the prepared
brief alone saves its sources, not unretained editor work. Leaving the page,
starting a new brief or opening another saved brief clears the correction editor.
Same-draft Save replies, including incomplete or failed saves and retries, keep
the current applied corrections and uncommitted typing in this session. An
incomplete Open also keeps them until a saved brief is successfully opened.
The transcript source picker refuses to replace an active correction session;
retain or explicitly discard changes first. Apply or cancel current typing
before downloading, retaining, restoring a cue or editing another cue.

A revised source must stay within the existing 32 KiB input limit. Retaining
uses one of eight source slots and the dossier must remain within 128 KiB.
If there is no room, the editor remains available for a separate download.
The retained origin includes the prior attribution and must fit the existing
2,000-character origin limit; otherwise download remains available.
Retaining opens a fresh correction session on the new capture; it does not reuse
an earlier host digest or claim the revised wording was in the original source.
Repeated downloads do not append sources. A failed download leaves edits and
selection available for retry. A successful request alone does not prove a
browser saved a file to disk.

Until retention, ordinary quote search/export still refers to the loaded original.
The correction panel explicitly labels that boundary. After retention, quote
reports identify the revised source and its user-edited attribution.

## Privacy and qualification

A complete revised transcript preserves private unselected text and original
non-cue blocks. A selected quotation report is not redaction of the dossier.
MoonFind displays supplied markup literally; an external caption player may
interpret caption markup. Review files before sharing or opening in other apps.
This tool does not publish files, contact providers, run media transcription,
verify speech, grant review authority or complete a research delivery.

Ten focused `corrections*` tests run the compiled production root reducer,
Rabbita-rendered panel, existing capture and quote functions, browser-local
storage boundary and native-shaped save/open replies. They cover exact byte
splicing, multiline edits and locators, mixed line endings, duplicate SRT IDs,
cancel/restore/discard, invalid and oversized text, current-source and pending
state, dossier limits, and real Node Blob downloads reopened from disk.
A graphical browser, real browser persistence/download and actual native-host
lifecycle remain separate qualification gates.
