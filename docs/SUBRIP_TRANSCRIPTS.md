# SubRip interview evidence for research briefs

The **Time-coded interview quotations** panel now reads local SubRip (`.srt`)
interview and caption exports. Researchers can select time-anchored quotations,
keep the original beside a readable excerpt report, and reopen both with the
existing brief workflow. This closes a local source-intake gap in
MOONFIND-UC02/B02: the previous timed-transcript intake accepted WebVTT only.
It does not load media, transcribe audio, infer speakers or verify the supplied
statements. The example is synthetic research material, not customer evidence.

## A complete local workflow

1. Open the brief studio and choose **Import WebVTT / SRT transcript** in
   **Time-coded interview quotations**. Select
   [`fixtures/interview-transcript.srt`](../fixtures/interview-transcript.srt).
2. The complete original becomes `interview-transcript.srt.txt`. Its bytes,
   including UTF-8 BOM and CRLF, are untouched; its original filename is in the
   origin. The added `.txt` suffix allows existing text-dossier persistence.
   The content determines the parser, so retained `.srt.txt` and pasted SubRip
   in `.txt` sources can also be opened from **Reopen a loaded transcript**.
3. Inspect four cues with physical timing-line locators 2, 7, 11 and 15. The
   source identifiers are `007`, `42`, `42`, and `9007199254740993`. They remain
   literal text, including leading zeroes and repeats. The UI's **Cue 1–4**
   numbers identify source order independently of these supplied identifiers.
4. Search `CLINIC` and choose **Select matching cues**. Cues 1 and 3 are selected.
   Search `school`; the selected clinic quotations remain selected while hidden.
   Overlapping cues remain distinct. Search covers words, literal identifiers
   and timing, using the existing case-insensitive literal search.
5. Expand **Preview quotation report**. Choose **Download quotation report**
   to request `moonfind-transcript-excerpts.md`, or **Add quotations to brief**
   to append `transcript-excerpts.md` beside the original. Adding clears the
   selection, so repeating Add cannot duplicate the report without reselection.
6. Complete the brief and use its existing save action. Reopen the saved brief
   and select the retained `.srt.txt` source to explore it again. The Markdown
   report remains an ordinary source. Search and selection are transient.

## Openable report and provenance

The report's existing `moonfind.transcript-excerpts.v1` metadata now includes
`source_format`: `subrip` or `webvtt`. It contains brief ID, source slot/name,
origin, capture time, total and selected cue counts, and each cue's original
identifier, timing line, source-order number and integer start/end milliseconds.
For example, selected cue 3 has source line 11 and supplied identifier `42`:
`00:00:06,100 --> 00:00:09,050`, from 6100 to 9050 milliseconds.

An unchanged prepared host snapshot contributes its recorded digest and revision.
Both are explicitly null for an unprepared/edited draft. This preserves the
existing distinction between supplied source text and host-recorded byte identity;
a digest does not prove that the words were spoken or establish a research finding.

The selected payload is literal, indented Markdown. Line endings are normalized
only for parsing/display/report readability. Original capture bytes are retained
unchanged. HTML tags, subtitle styling, instructions, links and `<v ...>` remain
literal text. SubRip does not supply the WebVTT voice annotation contract, so no
speaker name is inferred from it. Plain speaker names remain searchable payload.

Selection does not redact the complete source dossier. Before sharing, inspect
both the original and the report for private interview information.

## Supported SubRip subset

- UTF-8, optional leading BOM; LF, CRLF and CR line endings.
- Each cue begins with a digits-only identifier, a timing line and nonblank text.
  Identifier values are not converted to numbers, deduplicated or reordered.
- Timing uses `hh:mm:ss,mmm`, with hours 00–99 and minutes/seconds 00–59. Spaces
  or tabs separate the arrow. Optional trailing spaces/tabs are retained.
  End must follow start, and start times must be nondecreasing. Overlap is allowed.
- Empty lines separate cues. Multiline payload is preserved for display; arrows
  within payload are rejected to avoid treating an unseparated timing block as text.
- No automatic conversion of dot-decimal timestamps, coordinate/settings suffixes,
  absent identifiers, other encodings or malformed blocks. An error leaves the
  previous draft and exploration unchanged; nothing is partially imported.
- Up to 32 KiB and 512 cues per source. The existing eight-source and 128 KiB
  total brief limits still apply. The mapped filename is at most 160 characters.
  A quotation report added to the brief also needs a slot and 32 KiB; a larger
  report can be downloaded separately, or narrowed to fewer cues.

WebVTT support is retained, including its literal voice annotation handling and
NOTE/STYLE/REGION behavior. See [WebVTT details](WEBVTT_TRANSCRIPTS.md).

## Verification boundary

Seven focused compiled-JavaScript tests cover exact original bytes, mixed
line endings, timing boundaries, repeated/large identifiers, incomplete intake,
search/selection, report provenance, browser-local draft retention, synthetic
host-shaped reopen, real File reads into the production reducer, real Blob output,
and actual Rabbita HTML rendering. The independent Node verifier compares report
locators, quotations, digests and actual downloaded Blob bytes to the retained
original. Existing ten transcript tests exercise WebVTT regressions.

These are local UI and controlled DOM checks. They do not qualify a graphical
browser, a native host save, real browser disk-save, media transcription, provider
research delivery or factual correctness. Cumulative qualification remains R50.
