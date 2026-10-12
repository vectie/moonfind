///|
fn job_textarea(
  value : String,
  rows : Int,
  on_input : @rabbita.Emit[String],
) -> @rabbita.Html {
  textarea(
    value~,
    rows~,
    on_input~,
    style=[
      "width:100%", "box-sizing:border-box", "resize:vertical", "background:#07101f",
      "color:#edf5ff", "border:1px solid #314563", "border-radius:10px", "padding:12px",
      "font:inherit",
    ],
    "",
  )
}

///|
fn job_file_row(
  emit : @rabbita.Emit[Msg],
  file : ResearchJobFile,
  can_revise : Bool,
) -> @rabbita.Html {
  li(
    style=[
      "display:flex", "justify-content:space-between", "gap:12px", "align-items:center",
      "flex-wrap:wrap", "padding:9px 0", "border-bottom:1px solid #263654",
    ],
    [
      div(style=["display:grid", "gap:3px"], [
        strong(file.name),
        small(
          style=["color:#91a8c7"],
          file.media_type + " · " + file.byte_length.to_string() + " bytes",
        ),
      ]),
      div(style=["display:flex", "gap:8px", "align-items:center"], [
        action_button("Preview", emit(PreviewJobFile(file.name))),
        if can_revise {
          action_button("Revise", emit(SelectJobRevisionFile(file.name)))
        } else {
          @html.nothing
        },
        a(
          href=product_api_url(file.open_url),
          target=Blank,
          style=["color:#76e0d1", "font-weight:700"],
          "Open",
        ),
      ]),
    ],
  )
}

///|
fn render_general_jobs(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let selected = selected_general_job(model)
  section(style=surface() + ["padding:20px", "display:grid", "gap:18px"], [
    div(
      style=[
        "display:flex", "justify-content:space-between", "align-items:start", "gap:12px",
        "flex-wrap:wrap",
      ],
      [
        div([
          eyebrow("RESEARCH JOBS"),
          h2(style=["margin:5px 0", "font-size:24px"], "From question to files"),
          p(
            style=["color:#9cb0cd", "margin:0", "max-width:75ch"],
            "Describe the work and name the files you want. MoonClaw can explore freely; finished files appear here when the run completes.",
          ),
        ]),
        action_button("Refresh jobs", emit(RefreshJobs)),
      ],
    ),
    div(
      style=[
        "display:grid", "grid-template-columns:repeat(auto-fit,minmax(min(100%,350px),1fr))",
        "gap:18px",
      ],
      [
        div(style=["display:grid", "gap:11px", "align-content:start"], [
          field_label(
            "Research objective",
            job_textarea(
              model.job_objective,
              4,
              emit.map(value => SetJobObjective(value)),
            ),
          ),
          field_label(
            "Who will use the result?",
            text_field(
              model.job_audience,
              "Research team",
              emit.map(value => SetJobAudience(value)),
            ),
          ),
          field_label(
            "Sources or constraints (separate with semicolons)",
            text_field(
              model.job_sources,
              "Open sources; supplied files",
              emit.map(value => SetJobSources(value)),
            ),
          ),
          field_label(
            "Output filenames (separate with commas)",
            text_field(
              model.job_outputs,
              "report.md, evidence.csv, figure.png",
              emit.map(value => SetJobOutputs(value)),
            ),
          ),
          field_label(
            "Success criteria (semicolon separated; use filename => criterion for one file)",
            job_textarea(
              model.job_criteria,
              2,
              emit.map(value => SetJobCriteria(value)),
            ),
          ),
          field_label(
            "MoonClaw model",
            text_field(
              model.model_name,
              "Enter a model route configured in MoonClaw",
              emit.map(value => SetModelName(value)),
            ),
          ),
          small(
            style=["color:#91a8c7"],
            "Use any research question or output format. Requested filenames become the job brief; extra useful files may also be delivered.",
          ),
          action_button("Create research job", emit(CreateJob), primary=true),
        ]),
        div(style=["display:grid", "gap:12px", "align-content:start"], [
          h3(style=["margin:0"], "Jobs and outputs"),
          if model.jobs.is_empty() {
            small(
              style=["color:#91a8c7"],
              "No jobs yet. Create a brief to begin.",
            )
          } else {
            div(
              style=["display:flex", "gap:8px", "flex-wrap:wrap"],
              model.jobs.map(job => {
                button(
                  on_click=emit(SelectJob(job.job.job_id)),
                  style=[
                    "padding:8px 11px",
                    "border-radius:10px",
                    if job.job.job_id == model.selected_job_id {
                      "border:1px solid #67d5c4"
                    } else {
                      "border:1px solid #38506f"
                    },
                    "background:#17263d",
                    "color:#edf5ff",
                    "cursor:pointer",
                    "max-width:250px",
                    "overflow:hidden",
                    "text-overflow:ellipsis",
                    "white-space:nowrap",
                  ],
                  job.job.objective,
                )
              }),
            )
          },
          match selected {
            Some(job) =>
              div(style=["display:grid", "gap:10px"], [
                strong(job.job.objective),
                small(
                  style=["color:#91a8c7", "overflow-wrap:anywhere"],
                  "Workspace: " + job.job_root,
                ),
                small(
                  style=["color:#91a8c7"],
                  "Requested: " +
                  job.job.requested_outputs
                  .map(output => output.output_id)
                  .join(", "),
                ),
                match job.revision_of {
                  Some(parent) =>
                    small(
                      style=["color:#91a8c7"],
                      "Revision of " +
                      parent +
                      ". Previous file and sources are in input/.",
                    )
                  None => @html.nothing
                },
                if job.session_key is None {
                  div(
                    style=[
                      "display:grid", "gap:8px", "padding:12px", "border:1px solid #314563",
                      "border-radius:10px",
                    ],
                    [
                      strong("Add sources before starting"),
                      small(
                        style=["color:#91a8c7"],
                        "Paste a source or fetch arXiv metadata and abstracts. MoonClaw sees saved files in input/.",
                      ),
                      text_field(
                        model.job_source_name,
                        "notes.md",
                        emit.map(value => SetJobSourceName(value)),
                      ),
                      job_textarea(
                        model.job_source_content,
                        4,
                        emit.map(value => SetJobSourceContent(value)),
                      ),
                      action_button(
                        "Save supplied source",
                        emit(AddJobTextSource),
                      ),
                      text_field(
                        model.job_arxiv_query,
                        "arXiv topic or query, e.g. retrieval augmented generation",
                        emit.map(value => SetJobArxivQuery(value)),
                      ),
                      action_button(
                        "Fetch 10 arXiv records",
                        emit(AddJobArxivSource),
                      ),
                      text_field(
                        model.job_source_url,
                        "https://example.org/source",
                        emit.map(value => SetJobSourceUrl(value)),
                      ),
                      action_button("Capture public URL", emit(AddJobUrlSource)),
                    ],
                  )
                } else {
                  @html.nothing
                },
                if job.sources.is_empty() {
                  small(
                    style=["color:#91a8c7"],
                    "No source files attached yet.",
                  )
                } else {
                  div(style=["display:grid", "gap:5px"], [
                    strong("Source files"),
                    ul(
                      style=["list-style:none", "padding:0", "margin:0"],
                      job.sources.map(source => {
                        li([
                          a(
                            href=product_api_url(source.open_url),
                            target=Blank,
                            style=["color:#76e0d1"],
                            source.name,
                          ),
                          small(
                            style=["color:#91a8c7"],
                            " · " + source.byte_length.to_string() + " bytes",
                          ),
                        ])
                      }),
                    ),
                  ])
                },
                match job.session_key {
                  Some(key) =>
                    small(
                      style=["color:#91a8c7"],
                      "MoonClaw session: " +
                      key +
                      job.session_state
                      .map(state => " · " + state)
                      .unwrap_or(""),
                    )
                  None => @html.nothing
                },
                match job.session_preview {
                  Some(preview) if !preview.is_blank() =>
                    small(style=["color:#9cb0cd"], preview)
                  _ => @html.nothing
                },
                if job.session_state
                  .map(state => state.contains("WaitingForInput"))
                  .unwrap_or(false) {
                  div(
                    style=[
                      "display:grid", "gap:8px", "padding:12px", "border:1px solid #ad7e43",
                      "border-radius:10px",
                    ],
                    [
                      strong("MoonClaw needs information to continue"),
                      small(
                        style=["color:#f1c77b"],
                        job.run_summary.unwrap_or(
                          "The current run is waiting for input.",
                        ),
                      ),
                      job_textarea(
                        model.job_resume_content,
                        4,
                        emit.map(value => SetJobResumeContent(value)),
                      ),
                      action_button("Resume run", emit(ResumeJob), primary=true),
                    ],
                  )
                } else {
                  @html.nothing
                },
                if job.missing_outputs.is_empty() {
                  small(
                    style=["color:#8fe1b6"],
                    "All requested filenames are present.",
                  )
                } else {
                  small(
                    style=["color:#f1c77b"],
                    "Still missing: " + job.missing_outputs.join(", "),
                  )
                },
                div(style=["display:flex", "gap:8px", "flex-wrap:wrap"], [
                  if job.session_state
                    .map(state => {
                      state.contains("Succeeded") ||
                      state.contains("WaitingForInput")
                    })
                    .unwrap_or(false) {
                    @html.nothing
                  } else if job.moonclaw_gateway_base is Some(_) {
                    action_button(
                      if job.session_key is Some(_) {
                        "Check MoonClaw run"
                      } else {
                        "Start with MoonClaw"
                      },
                      emit(StartJob),
                      primary=true,
                    )
                  } else {
                    small(
                      style=["color:#f1c77b"],
                      "MoonClaw gateway unavailable. Connect it to run this brief.",
                    )
                  },
                  action_button(
                    "Refresh outputs",
                    emit(SelectJob(job.job.job_id)),
                  ),
                  if job.missing_outputs.is_empty() {
                    action_button("Verify delivery", emit(VerifyJobDelivery))
                  } else {
                    @html.nothing
                  },
                ]),
                if job.delivery_ready {
                  a(
                    href=product_api_url(
                      "/api/v1/jobs/" + job.job.job_id + "/delivery",
                    ),
                    target=Blank,
                    style=["color:#8fe1b6"],
                    "Verified manifest · ready for researcher review",
                  )
                } else if job.delivery_manifest is Some(_) {
                  small(
                    style=["color:#f1c77b"],
                    "Delivery needs another verification: " +
                    job.delivery_issues.join("; "),
                  )
                } else {
                  small(
                    style=["color:#91a8c7"],
                    "Delivery verification pending. MoonClaw should write delivery-evidence.json with source references and criterion checks.",
                  )
                },
                if job.files.is_empty() {
                  small(style=["color:#91a8c7"], "No files in outputs/ yet.")
                } else {
                  div(style=["display:grid", "gap:9px"], [
                    a(
                      href=product_api_url(
                        "/api/v1/jobs/" + job.job.job_id + "/export.zip",
                      ),
                      style=["color:#76e0d1", "font-weight:700"],
                      "Download complete ZIP bundle",
                    ),
                    ul(
                      style=["list-style:none", "padding:0", "margin:0"],
                      job.files.map(file => {
                        job_file_row(
                          emit,
                          file,
                          job.job.requested_outputs.any(output => {
                            output.output_id == file.name
                          }),
                        )
                      }),
                    ),
                  ])
                },
                match model.job_preview {
                  Some(preview) if job.files.any(file => {
                      file.name == preview.name
                    }) =>
                    div(style=["display:grid", "gap:7px"], [
                      strong("Preview · " + preview.name),
                      match preview.text {
                        Some(content) =>
                          pre(
                            style=[
                              "white-space:pre-wrap", "max-height:420px", "overflow:auto",
                              "background:#07101f", "border:1px solid #273a58", "border-radius:10px",
                              "padding:12px", "font-size:12px",
                            ],
                            content,
                          )
                        None if preview.media_type.has_prefix("image/") &&
                          preview.media_type != "image/svg+xml" =>
                          img(
                            src=product_api_url(
                              "/api/v1/jobs/" +
                              job.job.job_id +
                              "/files/" +
                              preview.name,
                            ),
                            alt=preview.name,
                            style=[
                              "max-width:100%", "max-height:420px", "object-fit:contain",
                            ],
                          )
                        None =>
                          small(
                            style=["color:#91a8c7"],
                            if preview.truncated {
                              "File exceeds the inline preview limit. Open or download it."
                            } else {
                              "Open this file in its native viewer."
                            },
                          )
                      },
                    ])
                  _ => @html.nothing
                },
                if model.job_revision_file.is_blank() {
                  @html.nothing
                } else {
                  div(
                    style=[
                      "display:grid", "gap:8px", "padding:12px", "border:1px solid #314563",
                      "border-radius:10px",
                    ],
                    [
                      strong("Revise " + model.job_revision_file),
                      job_textarea(
                        model.job_revision_instruction,
                        3,
                        emit.map(value => SetJobRevisionInstruction(value)),
                      ),
                      action_button(
                        "Create revision job",
                        emit(CreateJobRevision),
                      ),
                    ],
                  )
                },
              ])
            None => @html.nothing
          },
          if model.job_status.is_blank() {
            @html.nothing
          } else {
            span(
              attrs=@html.Attrs::build().role("status").aria_live("polite"),
              model.job_status,
            )
          },
          match model.job_error {
            Some(error) =>
              p(
                attrs=@html.Attrs::build().role("alert"),
                style=["color:#ffb0bd"],
                error,
              )
            None => @html.nothing
          },
        ]),
      ],
    ),
  ])
}
