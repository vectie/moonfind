///|
fn screening_panel(
  emit : @rabbita.Emit[Msg],
  view : BriefView,
) -> @rabbita.Html {
  let state = view.screening
  let references = reference_catalog(view).references
  let matches = screening_matches(view)
  fn message(action) {
    BriefAction(Screening(state.key, state.log.revision, action))
  }
  section(id="reference-screening", [
    h3("Screen literature for this question"),
    p(
      "Decide Include, Exclude or Undecided for each exact citation and record your reason. This is a human screening judgment from supplied metadata/abstracts, not a scientific acceptance or full-text review. Same-DOI citations remain independent.",
    ),
    p(
      "Confirmed decisions autosave in this browser per brief ID. Native brief Save does not include screening decisions. Reopening the same brief here restores them; a new brief starts separately. Download history before changing browsers or clearing browser data. Editor changes need Save decision.",
    ),
    p(state.notice),
    if state.saved {
      div("")
    } else {
      p(
        "NOT VERIFIED SAVED: keep this page open, retry saving or download the in-memory history before leaving.",
      )
    },
    if state.blocked {
      div([
        action_button(
          "Retry reading screening history",
          emit(message(RetryRead)),
        ),
        details([
          summary("Unreadable saved bytes retained unchanged"),
          pre(
            style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
            state.unreadable,
          ),
        ]),
      ])
    } else if view.pending {
      p("Wait for the current brief operation before screening citations.")
    } else {
      div([
        ul(
          ["unscreened", "include", "exclude", "undecided"].map(status => {
            li(
              status +
              ": \{references.filter(r => screening_status(view, r) == status).length()}",
            )
          }),
        ),
        p(
          "Counts cover every current citation, including those hidden by filters. Unscreened means no current decision; Undecided means you explicitly recorded uncertainty. Removed/replaced sources detach prior decisions permanently, keeping their history without applying it to a new citation.",
        ),
        field_label(
          "Screening status",
          select(
            on_change=emit.map(value => message(Scope(value))),
            ["all", "unscreened", "include", "exclude", "undecided"].map(status => {
              option(value=status, selected=state.scope == status, status)
            }),
          ),
        ),
        p(
          "\{matches.length()} screening rows. Rows and CSV use the reading-list text, DOI and year filters above, plus this status filter. Other bibliography downloads and the shortlist are unchanged.",
        ),
        match state.editor {
          None => p("Choose Screen citation below to begin.")
          Some(choice) => {
            let reference = choice.reference
            div([
              h3("Screening: " + reference.title),
              p(
                "Source slot \{reference.source_slot} · original record \{reference.record_number} · " +
                reference.source_name,
              ),
              p(
                reference.authors.join("; ") +
                " · " +
                reference.issued +
                " · " +
                reference.availability,
              ),
              p("DOI (supplied): " + reference.doi),
              pre(
                style=["white-space:pre-wrap", "font:inherit"],
                reference.abstract_text,
              ),
              if reference_choice_current(view, reference_catalog(view), choice) {
                div("")
              } else {
                p(
                  "SOURCE CHANGED: this editor cannot save. Copy your rationale before choosing the current citation.",
                )
              },
              field_label(
                "Screening decision",
                select(
                  on_change=emit.map(value => message(Decision(value))),
                  ["include", "exclude", "undecided"].map(status => {
                    option(
                      value=status,
                      selected=state.decision == status,
                      status,
                    )
                  }),
                ),
              ),
              field_label(
                "Reason for this screening decision (required)",
                textarea(
                  value=state.rationale,
                  rows=4,
                  attrs=@html.Attrs::build().aria_label("Screening rationale"),
                  on_input=emit.map(value => message(Rationale(value))),
                  style=["width:100%", "box-sizing:border-box"],
                  "",
                ),
              ),
              action_button("Save decision", emit(message(SaveDecision(false)))),
              action_button(
                "Save and next unscreened",
                emit(message(SaveDecision(true))),
              ),
              action_button("Cancel editor changes", emit(message(Cancel))),
              p(
                "Saving a changed decision appends a revision. Next opens the first unscreened citation within the reading-list filters, regardless of the screening-status filter.",
              ),
            ])
          }
        },
        ul(
          matches.map(reference => {
            let latest = screening_latest(view, reference)
            li([
              strong(
                if reference.title.is_blank() {
                  "(Untitled reference)"
                } else {
                  reference.title
                },
              ),
              p(
                "Source slot \{reference.source_slot} · record \{reference.record_number} · " +
                reference.source_name +
                " · " +
                screening_status(view, reference),
              ),
              pre(
                style=["white-space:pre-wrap", "font:inherit"],
                latest
                .map(x => x.rationale)
                .unwrap_or("No screening decision recorded."),
              ),
              action_button(
                "Screen citation",
                emit(message(Screen(reference_choice(view, reference)))),
              ),
            ])
          }),
        ),
        action_button(
          "Retry saving screening history",
          emit(message(RetrySave)),
        ),
        action_button(
          "Download visible screening CSV",
          emit(message(ExportCsv)),
        ),
        action_button(
          "Download complete screening history JSON",
          emit(message(ExportJson)),
        ),
        p(
          "CSV contains visible current citations and latest reasons only; formula-like cells gain a leading apostrophe for spreadsheet safety. JSON includes ALL decisions, previous revisions and detached captures, even hidden by filters, with full selection-capture bodies and private rationales. Neither export contains unsaved editor changes. JSON is inspectable history, with no import/restore button. Review before sharing.",
        ),
      ])
    },
    details([
      summary(
        "Complete decision history (\{state.log.decisions.length()} revisions, including detached sources)",
      ),
      p(
        "At most 200 confirmed revisions and 1 MiB of history per brief. Nothing is silently evicted. Source digest and identity are recorded claims, not external verification.",
      ),
      ul(
        state.log.decisions.map(entry => {
          li([
            strong(
              "#\{entry.sequence} · " +
              entry.decision +
              " · " +
              entry.reference.title,
            ),
            p(
              "Source slot \{entry.reference.source_slot} · record \{entry.reference.record_number} · " +
              (if entry.attached {
                "attached capture"
              } else {
                "detached retained capture"
              }),
            ),
            pre(style=["white-space:pre-wrap", "font:inherit"], entry.rationale),
          ])
        }),
      ),
    ]),
  ])
}
