///|
fn passage_role_picker(
  value : String,
  changed : @rabbita.Emit[String],
) -> @rabbita.Html {
  select(
    on_change=changed,
    ["question", "support", "contradiction", "context"].map(role => {
      option(value=role, selected=value == role, role)
    }),
  )
}

///|
extern "js" fn passage_numbered_text(text : String) -> String =
  #|text => text.split(/\r\n|\r|\n/).map((line,index)=>(index+1)+' | '+line).join('\n')

///|
fn passage_memo_panel(
  emit : @rabbita.Emit[Msg],
  view : BriefView,
) -> @rabbita.Html {
  let state = view.passage_memo
  let memo = state.memo
  fn message(action) {
    BriefAction(PassageMemo(state.key, state.token, action))
  }
  section(id="evidence-passage-memo", [
    h3("Collect passages into an evidence memo"),
    p(
      "Explore a question across local captures. Select a dossier search hit above or choose a source below, collect exact line ranges, then write your interpretation. Keep supporting and conflicting passages side by side; missing evidence remains an open question. No label is inferred from source text.",
    ),
    p(
      "The memo question and collected passages autosave in this browser for this brief ID. The passage composer stays session-only until Collect. It retains full original captures, even after a source is removed or replaced. Native brief Save and bibliography reading notes are separate. Use a distinct brief ID for independent workspaces on the same browser origin.",
    ),
    p(state.notice),
    if !state.saved {
      p(
        "NOT VERIFIED SAVED: keep this page open and download the collection or retry saving.",
      )
    } else {
      div("")
    },
    if state.blocked {
      div([
        action_button(
          "Retry reading passage collection",
          emit(message(RetryRead)),
        ),
        details([
          summary("Unreadable collection bytes retained unchanged"),
          pre(
            style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
            state.unreadable,
          ),
        ]),
      ])
    } else if view.pending {
      p(
        "Wait for the brief operation to finish. Your passage collection is unchanged.",
      )
    } else {
      div([
        field_label(
          "Question explored by this memo",
          textarea(
            value=memo.question,
            rows=2,
            on_input=emit.map(value => message(Question(value))),
            "",
          ),
        ),
        field_label(
          "Passage source",
          select(
            on_change=emit.map(value => {
              message(PassageSource(@string.parse_int(value) catch { _ => 0 }))
            }),
            [
              option(
                value="0",
                selected=state.source_slot == 0,
                "Choose a local capture",
              ),
            ] +
            view.draft.sources.mapi((i, source) => {
              option(
                value=(i + 1).to_string(),
                selected=state.source_slot == i + 1,
                "Source \{i + 1}: " + source.name,
              )
            }),
          ),
        ),
        field_label(
          "First line (inclusive)",
          text_field(
            state.first_line,
            "1",
            emit.map(value => message(FirstLine(value))),
          ),
        ),
        field_label(
          "Last line (inclusive)",
          text_field(
            state.last_line,
            "1",
            emit.map(value => message(LastLine(value))),
          ),
        ),
        field_label(
          "Your passage label",
          passage_role_picker(
            state.role,
            emit.map(value => message(Role(value))),
          ),
        ),
        field_label(
          "Your interpretation / open question",
          textarea(
            value=state.note,
            rows=3,
            on_input=emit.map(value => message(Note(value))),
            "",
          ),
        ),
        match view.draft.sources.get(state.source_slot - 1) {
          Some(source) =>
            div([
              details([
                summary("Read source with line numbers"),
                pre(
                  style=[
                    "white-space:pre-wrap", "overflow-wrap:anywhere", "max-height:320px",
                    "overflow:auto",
                  ],
                  passage_numbered_text(
                    brief_source_preview(source.content_hex),
                  ),
                ),
              ]),
              h3("Preview exact passage"),
              pre(
                style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
                passage_quote(
                  source,
                  @string.parse_int(state.first_line),
                  @string.parse_int(state.last_line),
                ) catch {
                  error => "\{error}"
                },
              ),
              action_button("Collect this passage", emit(message(Collect))),
            ])
          None =>
            p(
              "Choose a source or select a search hit before collecting a passage.",
            )
        },
        action_button("Retry saving passage collection", emit(message(Save))),
        action_button(
          "Download evidence memo Markdown",
          emit(message(ExportMarkdown)),
        ),
        action_button(
          "Download complete passage collection JSON",
          emit(message(ExportJson)),
        ),
        p(
          "Markdown includes every collected quote, interpretation and source locator. JSON additionally includes full original captures, including hidden or unselected private content. It is an inspectable source artifact; JSON import is not implemented. Downloads do not save the native brief or verify a browser disk save. Review before sharing.",
        ),
        details([
          summary("Preview evidence memo Markdown"),
          pre(
            style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
            passage_memo_markdown(view) catch {
              error => "\{error}"
            },
          ),
        ]),
      ])
    },
    p(
      "\{memo.passages.length()} collected passages, in collection order. Up to 24 passages and 1 MiB total retained JSON; no history is silently evicted.",
    ),
    ul(
      memo.passages.mapi((index, passage) => {
        li([
          h3("Passage \{index + 1}: " + passage.source.name),
          p(
            "Source slot \{passage.source_slot} · inclusive lines \{passage.first_line}–\{passage.last_line} · " +
            passage.role,
          ),
          p(
            if passage_current(view, passage) {
              "Exact capture still in this brief slot."
            } else {
              "Historical source snapshot. The current capture moved, changed or was removed; this passage was not retargeted."
            },
          ),
          p(
            "Origin as supplied: " +
            passage.source.origin +
            " · capture time as supplied: " +
            passage.source.captured_at,
          ),
          pre(
            style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
            passage.quote,
          ),
          if !state.blocked && !view.pending {
            div([
              action_button(
                "Remove passage from memo",
                emit(message(RemovePassage(passage.id))),
              ),
              field_label(
                "Label for passage \{index + 1}",
                passage_role_picker(
                  passage.role,
                  emit.map(role => {
                    message(Annotate(passage.id, role, passage.note))
                  }),
                ),
              ),
              field_label(
                "Interpretation for passage \{index + 1}",
                textarea(
                  value=passage.note,
                  rows=3,
                  on_input=emit.map(note => {
                    message(Annotate(passage.id, passage.role, note))
                  }),
                  "",
                ),
              ),
            ])
          } else {
            pre(style=["white-space:pre-wrap"], passage.note)
          },
        ])
      }),
    ),
  ])
}
