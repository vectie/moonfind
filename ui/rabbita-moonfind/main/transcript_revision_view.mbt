///|
fn transcript_revision_panel(
  emit : @rabbita.Emit[Msg],
  view : BriefView,
) -> @rabbita.Html {
  let state = view.transcript
  let revision = state.revision
  section(
    id="transcript-corrections",
    style=[
      "display:grid", "gap:12px", "padding:12px", "border:1px solid #314563", "border-radius:10px",
    ],
    [
      h3("Correct transcript text"),
      p(
        "Choose Correct cue below to fix transcription wording or supplied speaker markup. Compare your working copy with the original, then apply it. Times, cue identifiers, timing settings and non-cue blocks stay unchanged. No speech or speaker identity is verified.",
      ),
      p(
        "\{revision.corrections.length()} applied text corrections. Corrections are session-only until you retain a revised capture or download it. Save prepared brief does not save this editor. Switching briefs or leaving this page discards unretained corrections.",
      ),
      match
        state.capture.bind(capture => capture.cues.get(revision.editing - 1)) {
        None => div("")
        Some(cue) =>
          div(style=["display:grid", "gap:8px"], [
            strong(
              "Editing cue \{cue.number} · " +
              cue.timing +
              " · original source line \{cue.line}",
            ),
            p("Original cue text"),
            pre(
              style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
              cue.text,
            ),
            field_label(
              "Revised cue text",
              textarea(
                id="transcript-cue-edit",
                value=revision.text,
                rows=5,
                disabled=view.pending,
                on_input=emit.map(text => {
                  BriefAction(Transcript(Revise(Write(text))))
                }),
                style=[
                  "width:100%", "box-sizing:border-box", "background:#07101f", "color:#edf5ff",
                  "font:inherit", "padding:10px",
                ],
                "",
              ),
            ),
            p(
              "Keep at least one nonblank line. Blank lines and timing arrows would split cues and cannot be used inside a correction. Markup stays literal in MoonFind; an external caption player may interpret supported caption markup.",
            ),
            action_button(
              "Apply cue correction",
              emit(BriefAction(Transcript(Revise(Apply)))),
            ),
            action_button(
              "Cancel cue edit",
              emit(BriefAction(Transcript(Revise(Cancel)))),
            ),
          ])
      },
      div(
        revision.corrections.map(correction => {
          let cue = state.capture.unwrap().cues[correction.number - 1]
          details([
            summary("Compare changed cue \{correction.number} · " + cue.timing),
            p("Original text"),
            pre(
              style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
              cue.text,
            ),
            p("Revised working text"),
            pre(
              style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
              correction.text,
            ),
            action_button(
              "Restore original cue \{correction.number}",
              emit(BriefAction(Transcript(Revise(Restore(correction.number))))),
            ),
          ])
        }),
      ),
      if revision.corrections.is_empty() {
        div("")
      } else {
        div(style=["display:grid", "gap:8px"], [
          details([
            summary("Preview full revised transcript"),
            pre(
              style=[
                "white-space:pre-wrap", "overflow-wrap:anywhere", "max-height:320px",
                "overflow:auto",
              ],
              brief_source_preview(transcript_revision_source(view).content_hex) catch {
                error => "\{error}"
              },
            ),
          ]),
          action_button(
            "Download revised VTT / SRT",
            emit(BriefAction(Transcript(Revise(Download)))),
          ),
          action_button(
            "Retain revised transcript and use quotations",
            emit(BriefAction(Transcript(Revise(Retain)))),
            primary=true,
          ),
          p(
            "Retain adds one ordinary source beside the unchanged original and opens the revised copy for searching and quotations. Existing cue selection carries across. The full revised file includes every unselected cue and non-cue block. Selection is not redaction.",
          ),
        ])
      },
      if transcript_revision_pending(state) {
        action_button(
          "Discard all transcript corrections",
          emit(BriefAction(Transcript(Revise(Discard)))),
        )
      } else {
        div("")
      },
      if !revision.corrections.is_empty() {
        p(
          "Quotation controls below still use the original loaded capture until you retain the revised transcript. Downloading a revised file keeps your corrections here.",
        )
      } else {
        div("")
      },
    ],
  )
}
