# Local WebVTT interview quotations

Use the brief studio’s **Time-coded interview quotations** panel to turn a
local caption/transcript export into readable, source-anchored quotations for a
bounded research question. This is local text preparation; no model, media file,
remote fetch, audio transcription, speaker identification or factual verification
runs. The synthetic example is `fixtures/interview-transcript.vtt`.

## Import, inspect and use

1. Choose **Import WebVTT / SRT transcript** and select the example, or your own UTF-8
   `.vtt` / `.txt` WebVTT file. The complete file is immediately added as one source.
2. A `.vtt` filename becomes `.vtt.txt` in the brief. Its exact original bytes
   (including BOM and CRLF) are unchanged, and the original filename is recorded
   in the source origin. This explicit text adapter lets the existing host’s text
   dossier save/reopen the capture without a new native media or parser graph.
3. Inspect each cue’s supplied timing, original timing-line number, identifier,
   first leading voice annotation and literal multiline payload. Overlapping
   cues remain separate. Missing speaker/identifier labels are explicit.
4. Search `GARCÍA` in the example and choose **Select matching cues**. Search is
   case-insensitive literal text across speaker, words, cue identifier and timing.
   Clear the search or search `school`: previously selected quotations remain
   selected, including when hidden. Individual cues can be toggled.
5. Expand **Preview quotation report**. Download `moonfind-transcript-excerpts.md`
   or choose **Add quotations to brief**, which adds `transcript-excerpts.md` beside
   the unchanged original and clears the selection. Repeated Add cannot create
   another report without selecting cues again.
6. Complete the existing brief fields and use **Save prepared brief**. On reopen,
   select the retained `.vtt.txt` in **Reopen a loaded transcript** to inspect it
   again. The saved Markdown remains an ordinary source. Search/selection itself
   is temporary; it is not a separate notebook or a saved research finding.

The report is readable Markdown with indented, literal quotation blocks. Each
quotation has one-based source cue and timing-line locators, integer start/end
milliseconds, the original timing line (including settings), cue identifier and
speaker annotation. It includes the brief/source slot, name, supplied origin and
capture time. A matching unchanged prepared host snapshot contributes its
recorded digest and revision; otherwise both are explicitly null. No digest is
invented or treated as proof that the words were spoken.

The original contains all supplied material; the report contains only chosen
cues. Choosing quotations is not redaction of the source dossier. Review private
interview material before sharing either file. Source text is never inserted as
HTML: tags, entities, embedded instructions and non-voice markup stay literal.
Only the first leading WebVTT `<v Speaker>` annotation is used as a speaker label;
additional speaker markup remains visible in the original cue payload.

## Supported text subset and limits

- A WEBVTT header, optional header metadata, and a blank separator are required.
- Cue identifiers are optional. Timing uses `mm:ss.mmm` or `hh:mm:ss.mmm`, with
  up to 99 hours and minute/second fields from 00 to 59. End must follow start.
- Cue start times must be nondecreasing; overlapping intervals are supported.
- Multiline cue payload is supported and displayed literally. Parsing normalizes
  line endings for display only; stored source bytes are untouched.
- NOTE, STYLE and REGION blocks are counted and skipped from quotations. Their
  complete bytes remain in the original. This is not a subtitle renderer.
- `X-TIMESTAMP-MAP` in the header is rejected. Locators are local transcript times,
  without media offsets. Binary files and automatic conversion are unsupported.
  SubRip now has a separate supported text subset in [SubRip intake](SUBRIP_TRANSCRIPTS.md).
- Each source is at most 32 KiB and the transcript has at most 512 cues. Existing
  dossier bounds remain eight sources and 128 KiB total. Source filenames remain
  safe, at most 160 characters after the explicit `.txt` mapping.
- Import requires one available slot; adding a report requires another slot and
  the report must itself fit 32 KiB. If it is too large, select fewer cues or
  download the report separately. The original/selection remains intact on error.

Import cancellation, stale file callbacks and callbacks arriving during host
save/open cannot replace a newer draft. New or a completed host reopen clears
transient transcript selection. Removing/replacing/reordering a source resets
an exploration whose exact source no longer occupies its slot. Appending an
unrelated source or editing the question preserves an unchanged exploration.
Download failure keeps quotations selected and can be retried. Browser-draft
storage errors use the existing visible unsaved-state path.

## Focused verification boundary

R348 adds ten unconditional compiled JavaScript tests. They exercise the parser,
reducer, existing draft-storage integration, host-shaped save/reopen replies,
Rabbita HTML rendering, actual File/Blob bytes with controlled DOM boundaries,
and twelve file-picker outcomes. Independent Node verification compares emitted
quotes and line/time locators back to the exact original bytes. Focused prior
brief, JSON and reading-note regressions are separate recorded checks.

No native host persistence or actual browser disk-save was executed in this
round; host replies are synthetic fixtures. No graphical browser, audio/video,
provider, scientific validation or cumulative runtime acceptance is claimed.
Cumulative qualification remains R50.
