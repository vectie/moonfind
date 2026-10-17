///|
fn transcript_panel(
  emit : @rabbita.Emit[Msg],
  view : BriefView,
) -> @rabbita.Html {
  let state = view.transcript
  section(
    id="transcript-excerpts",
    style=surface() + ["padding:16px", "display:grid", "gap:12px"],
    [
      h3("Time-coded interview quotations"),
      p(
        "Import a local WebVTT or SubRip (SRT) transcript, search speaker annotations or words, and collect time-anchored quotations for your research brief. No media is loaded, transcribed or verified.",
      ),
      action_button(
        "Import WebVTT / SRT transcript",
        emit(BriefAction(Transcript(Choose))),
      ),
      p(
        "UTF-8 .vtt, .srt or .txt, 32 KiB and 512 cues. A .vtt or .srt is retained with an added .txt extension with identical bytes and its original filename in the origin, so the text dossier can save/reopen it. Voice markup is displayed literally. Times are local to the transcript; media timestamp maps are unsupported.",
      ),
      field_label(
        "Reopen a loaded transcript",
        select(
          on_change=emit.map(value => {
            BriefAction(
              Transcript(Open(@string.parse_int(value) catch { _ => 0 })),
            )
          }),
          [
            option(
              value="0",
              selected=state.slot == 0,
              "Choose a loaded source",
            ),
          ] +
          view.draft.sources.mapi((index, source) => {
            option(
              value=(index + 1).to_string(),
              selected=state.slot == index + 1,
              "Source \{index + 1}: " + source.name,
            )
          }),
        ),
      ),
      match state.capture {
        None => div("")
        Some(capture) =>
          div(style=["display:grid", "gap:12px"], [
            p(
              state.source.unwrap().name +
              " · " +
              capture.format +
              " · \{capture.cues.length()} cues · \{transcript_matching(state).length()} matching · \{state.selected.length()} selected · \{capture.ignored_blocks} non-cue blocks retained only in original",
            ),
            field_label(
              "Search transcript",
              text_field(
                state.query,
                "Speaker, words, cue identifier or timestamp",
                emit.map(value => BriefAction(Transcript(Search(value)))),
              ),
            ),
            p(
              "Selections survive searches and export in original source order. Overlapping cues stay separate. Speaker labels are only the first leading WebVTT voice annotation; inspect raw cue text for any additional speakers. SubRip numeric identifiers and payload are literal; speaker names are not inferred.",
            ),
            transcript_revision_panel(emit, view),
            action_button(
              "Select matching cues",
              emit(BriefAction(Transcript(SelectMatching))),
            ),
            action_button(
              "Clear quotation selection",
              emit(BriefAction(Transcript(Clear))),
            ),
            div(
              style=["max-height:420px", "overflow:auto"],
              transcript_matching(state).map(cue => {
                article(
                  style=["padding:12px", "border-bottom:1px solid #314563"],
                  [
                    strong(
                      "Cue \{cue.number} · source line \{cue.line} · " +
                      cue.timing,
                    ),
                    p(
                      "Identifier: " +
                      (if cue.identifier.is_empty() {
                        "(none)"
                      } else {
                        cue.identifier
                      }) +
                      " · Speaker annotation: " +
                      (if cue.speaker.is_empty() {
                        "(not supplied)"
                      } else {
                        cue.speaker
                      }),
                    ),
                    pre(
                      style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
                      cue.text,
                    ),
                    action_button(
                      (if state.selected.contains(cue.number) {
                        "Deselect cue "
                      } else {
                        "Select cue "
                      }) +
                      cue.number.to_string(),
                      emit(BriefAction(Transcript(Toggle(cue.number)))),
                    ),
                    action_button(
                      "Correct cue \{cue.number}",
                      emit(BriefAction(Transcript(Revise(Begin(cue.number))))),
                    ),
                  ],
                )
              }),
            ),
            details([
              summary("Preview quotation report"),
              pre(
                style=[
                  "white-space:pre-wrap", "overflow-wrap:anywhere", "max-height:320px",
                  "overflow:auto",
                ],
                transcript_report(view) catch {
                  error => "\{error}"
                },
              ),
            ]),
            action_button(
              "Download quotation report",
              emit(BriefAction(Transcript(Download))),
            ),
            action_button(
              "Add quotations to brief",
              emit(BriefAction(Transcript(Add))),
              primary=true,
            ),
            p(
              "The Markdown report contains only selected cues and their source/time locators. Adding uses one source slot. Save the brief to retain the report beside the entire original. This is not redaction of the dossier; review private interview material before sharing.",
            ),
          ])
      },
    ],
  )
}
