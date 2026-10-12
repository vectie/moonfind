///|
fn brief_editor_field(
  emit : @rabbita.Emit[Msg],
  name : String,
  title : String,
  value : String,
  disabled : Bool,
) -> @rabbita.Html {
  field_label(
    title,
    textarea(
      id="brief-" + name,
      value~,
      rows=2,
      disabled~,
      on_input=emit.map(value => BriefAction(Edit(name, value))),
      style=[
        "width:100%", "box-sizing:border-box", "background:#07101f", "color:#edf5ff",
        "border:1px solid #314563", "border-radius:10px", "padding:10px", "font:inherit",
      ],
      "",
    ),
  )
}

///|
fn brief_panel(emit : @rabbita.Emit[Msg], view : BriefView) -> @rabbita.Html {
  let draft = view.draft
  section(
    id="offline-brief-studio",
    style=surface() + ["padding:22px", "display:grid", "gap:14px"],
    [
      eyebrow("OFFLINE PREPARATION / LOCAL SOURCE DOSSIER"),
      h2("New research brief"),
      view.storage_problem
      .map(problem => {
        div(
          attrs=@html.Attrs::build().role("alert"),
          style=["color:#ffd5de"],
          problem,
        )
      })
      .unwrap_or(div("")),
      if view.restored_draft {
        p(
          "Restored browser draft. To revise a brief already saved on the native host, reopen its saved revision below before editing. If a save was interrupted, retry Save unchanged to recover its confirmation. Unsaved drafts can still be edited.",
        )
      } else {
        div("")
      },
      p(
        "Prepare a general research question from one or more local sources. Save immutable revisions, reopen their exact basis, and export a readable brief plus every selected source. No provider, remote fetch or PDF extraction is used.",
      ),
      p(
        "Prepared brief only. Research, analysis, requested outputs and approval of acceptance criteria have not occurred.",
      ),
      div(style=["display:flex", "gap:12px", "flex-wrap:wrap"], [
        action_button("New blank brief", emit(BriefAction(New))),
        action_button("Refresh saved briefs", emit(BriefAction(Refresh))),
      ]),
      small(
        "Brief ID: " +
        draft.brief_id +
        draft.parent_revision
        .map(id => " · Revision of " + id)
        .unwrap_or(" · Initial capture"),
      ),
      div(
        style=[
          "display:grid", "grid-template-columns:repeat(auto-fit,minmax(min(100%,320px),1fr))",
          "gap:12px",
        ],
        [
          brief_editor_field(
            emit,
            "question",
            "Research question",
            draft.question,
            view.pending,
          ),
          brief_editor_field(
            emit,
            "objective",
            "Objective",
            draft.objective,
            view.pending,
          ),
          brief_editor_field(
            emit,
            "audience",
            "Audience",
            draft.audience,
            view.pending,
          ),
          brief_editor_field(
            emit,
            "decision",
            "Decision this research should inform",
            draft.decision,
            view.pending,
          ),
          brief_editor_field(
            emit,
            "restrictions",
            "Source restrictions",
            draft.source_restrictions,
            view.pending,
          ),
          brief_editor_field(
            emit,
            "filenames",
            "Requested output filenames (one per line; not generated)",
            draft.requested_filenames.join("\n"),
            view.pending,
          ),
          brief_editor_field(
            emit,
            "criteria",
            "Acceptance criteria (user supplied, not approved)",
            draft.acceptance_criteria,
            view.pending,
          ),
        ],
      ),
      ris_panel(emit, view),
      bibtex_panel(emit, view),
      csl_panel(emit, view),
      csv_panel(emit, view),
      json_evidence_panel(emit, view),
      transcript_panel(emit, view),
      reference_list_panel(emit, view),
      h3("Capture local sources"),
      dossier_panel(emit, view),
      p(
        "UTF-8 .txt, .md, .csv, .json, .bib or .ris. Up to 8 sources, 32 KiB each and 128 KiB total. Use the RIS, BibTeX or CSL JSON bibliography import above for reference cards and selection. Exact bytes, names, origin and capture time are retained. Duplicate names and content stay separate.",
      ),
      action_button("Choose local files", emit(BriefAction(ChooseFiles))),
      field_label(
        "Pasted source filename",
        text_field(
          view.paste_name,
          "notes.txt",
          emit.map(value => BriefAction(PasteField("name", value))),
        ),
      ),
      field_label(
        "Pasted source origin / attribution",
        text_field(
          view.paste_origin,
          "Where did this text come from?",
          emit.map(value => BriefAction(PasteField("origin", value))),
        ),
      ),
      field_label(
        "Paste source text",
        textarea(
          id="brief-paste",
          value=view.paste_text,
          rows=4,
          on_input=emit.map(value => BriefAction(PasteField("text", value))),
          style=[
            "width:100%", "box-sizing:border-box", "background:#07101f", "color:#edf5ff",
            "padding:10px",
          ],
          "",
        ),
      ),
      action_button("Capture pasted text", emit(BriefAction(AddPaste))),
      ul(
        draft.sources.mapi((index, source) => {
          li([
            strong("\{index + 1}. " + source.name),
            p(
              source.origin +
              " · " +
              source.captured_at +
              " · \{source.content_hex.length() / 2} bytes · retained capture",
            ),
            details([
              summary("Inspect captured text"),
              pre(
                style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
                brief_source_preview(source.content_hex),
              ),
            ]),
            ris_retained_selection(source),
            bibtex_retained_selection(source),
            csl_retained_selection(source),
            csv_retained_selection(source),
            action_button(
              "Remove source \{index + 1}",
              emit(BriefAction(RemoveSource(index))),
            ),
          ])
        }),
      ),
      action_button(
        if view.pending {
          "Waiting for native host…"
        } else {
          "Save prepared brief"
        },
        emit(BriefAction(Save)),
        primary=true,
      ),
      view.error
      .map(error => {
        div(
          attrs=@html.Attrs::build().role("alert"),
          style=["color:#ffd5de"],
          error,
        )
      })
      .unwrap_or(div("")),
      match view.opened {
        Some(status) =>
          div(id="brief-saved-status", [
            strong("Retained revision: " + status.state),
            p(status.revision_id),
            status.snapshot
            .map(snapshot => {
              div([
                p(snapshot.boundary),
                ul(
                  snapshot.sources.map(source => {
                    li(
                      "Source \{source.slot}: " +
                      source.name +
                      " · " +
                      source.availability +
                      " · " +
                      source.digest,
                    )
                  }),
                ),
              ])
            })
            .unwrap_or(div("")),
            if status.state == "prepared" {
              div(style=["display:flex", "gap:16px", "flex-wrap:wrap"], [
                a(
                  href=product_api_url(
                    "/api/v1/briefs/" +
                    status.brief_id +
                    "/" +
                    status.revision_id +
                    "/brief.md",
                  ),
                  download="brief.md",
                  "Download readable brief",
                ),
                a(
                  href=product_api_url(
                    "/api/v1/briefs/" +
                    status.brief_id +
                    "/" +
                    status.revision_id +
                    "/dossier.zip",
                  ),
                  download="dossier.zip",
                  "Download complete source dossier + manifest",
                ),
              ])
            } else {
              p(
                "Export and revision from this basis are unavailable until the original retained bytes are restored. An interrupted first save can be retried unchanged.",
              )
            },
          ])
        None =>
          p(
            "Editing a draft. Save confirms native-host retention; requested outputs remain unproduced.",
          )
      },
      details(open=true, [
        summary(
          "Saved briefs and immutable revisions (\{view.catalog.length()})",
        ),
        ul(
          view.catalog.map(item => {
            li([
              p(item.question + " · " + item.state),
              small(item.brief_id + " / " + item.revision_id),
              action_button(
                "Reopen " + item.revision_id[9:17].to_owned(),
                emit(BriefAction(Open(item.brief_id, item.revision_id))),
              ),
            ])
          }),
        ),
      ]),
    ],
  )
}
