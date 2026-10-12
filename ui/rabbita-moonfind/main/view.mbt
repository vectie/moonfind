///|
using @html {
  a,
  article,
  button,
  code,
  details,
  div,
  h1,
  h2,
  h3,
  img,
  header,
  input,
  label,
  li,
  main_,
  nav,
  option,
  p,
  pre,
  select,
  section,
  small,
  span,
  strong,
  summary,
  textarea,
  ul,
}

///|
fn surface() -> Array[String] {
  [
    "background:#111a2c", "border:1px solid #263654", "border-radius:18px", "box-shadow:0 18px 50px rgba(0,0,0,.18)",
  ]
}

///|
fn eyebrow(text : String) -> @rabbita.Html {
  small(
    style=[
      "color:#82a2cd", "font-size:11px", "font-weight:800", "letter-spacing:.09em",
      "text-transform:uppercase",
    ],
    text,
  )
}

///|
fn field_label(text : String, child : @rabbita.Html) -> @rabbita.Html {
  label(style=["display:grid", "gap:7px", "font-size:12px", "color:#a9bad1"], [
    span(text),
    child,
  ])
}

///|
fn text_field(
  value : String,
  placeholder : String,
  on_input : @rabbita.Emit[String],
) -> @rabbita.Html {
  input(input_type=Text, value~, placeholder~, on_input~, style=[
    "width:100%", "box-sizing:border-box", "background:#07101f", "color:#edf5ff",
    "border:1px solid #314563", "border-radius:10px", "padding:11px 12px", "font:inherit",
  ])
}

///|
fn gap_severity_field(
  value : Int,
  on_change : @rabbita.Emit[String],
) -> @rabbita.Html {
  select(
    on_change~,
    style=[
      "width:100%", "min-height:44px", "box-sizing:border-box", "background:#07101f",
      "color:#edf5ff", "border:1px solid #314563", "border-radius:10px", "padding:10px 12px",
      "font:inherit",
    ],
    [0, 1, 2, 3, 4, 5].map(level => {
      option(
        value=level.to_string(),
        selected=value == level,
        if level == 0 {
          "0 · not present"
        } else {
          "\{level} · present"
        },
      )
    }),
  )
}

///|
fn action_button(
  text : String,
  on_click : @rabbita.Cmd,
  primary? : Bool = false,
) -> @rabbita.Html {
  button(
    on_click~,
    style=[
      "min-height:44px",
      "padding:10px 15px",
      if primary {
        "background:#67d5c4"
      } else {
        "background:#1c2c45"
      },
      if primary {
        "color:#07101f"
      } else {
        "color:#edf5ff"
      },
      if primary {
        "border:1px solid #67d5c4"
      } else {
        "border:1px solid #38506f"
      },
      "border-radius:11px",
      "font-weight:800",
      "cursor:pointer",
    ],
    text,
  )
}

///|
fn phase_text(phase : ResearchPhase) -> String {
  match phase {
    Ready => "Not started"
    CreatingSession => "Creating session"
    Confirming => "Confirming"
    Running => "Running"
    NeedsReview => "Needs review"
    Completed => "Completed"
    Failed => "Failed"
  }
}

///|
fn phase_color(phase : ResearchPhase) -> String {
  match phase {
    Completed => "#74e0a7"
    Failed => "#ff9e9e"
    NeedsReview => "#f4cb72"
    Ready => "#aabbd1"
    _ => "#67d5c4"
  }
}

///|
fn review_phase_text(phase : ReviewPhase) -> String {
  match phase {
    ReviewIdle => "Named-human decision not yet bundled"
    ReviewPreparing => "Persisting portable MoonChat review bundle"
    ReviewBundleReady => "Portable review bundle is durable"
    ReviewFailed => "Portable review preparation needs attention"
  }
}

///|
fn review_actions(emit : @rabbita.Emit[Msg], model : Model) -> @rabbita.Html {
  let actions : Array[@rabbita.Html] = []
  let workflow_ready = model.review_workflow
    .map(workflow => {
      workflow.state == "ready-for-human-review" &&
      workflow.prepare_url is Some(_)
    })
    .unwrap_or(false)
  match model.review_phase {
    ReviewIdle | ReviewFailed =>
      if workflow_ready && current_synthesis(model) is Some(_) {
        actions.push(
          action_button(
            "Prepare MoonChat review bundle",
            emit(PrepareReview),
            primary=true,
          ),
        )
      }
    _ => ()
  }
  div(style=["display:flex", "gap:9px", "flex-wrap:wrap"], actions)
}

///|
fn run_detail(session : CoworkSessionDetail) -> @rabbita.Html {
  let run_rows : Array[@rabbita.Html] = []
  run_rows.push(
    p(style=["margin:4px 0", "overflow-wrap:anywhere"], [
      eyebrow("SESSION"),
      code(
        style=["display:block", "color:#8fdccc", "margin-top:4px"],
        session.session.session_key,
      ),
    ]),
  )
  match session.linked_proposal {
    Some(proposal) =>
      run_rows.push(
        div(style=["margin-top:12px"], [
          eyebrow("PROPOSAL"),
          h3(style=["margin:5px 0"], proposal.title),
          small(style=["color:#a7b8cf"], proposal.id),
        ]),
      )
    None => ()
  }
  match session.linked_run {
    Some(run) =>
      run_rows.push(
        div(style=["margin-top:12px", "display:grid", "gap:5px"], [
          eyebrow("DURABLE RUN"),
          code(style=["color:#8fdccc"], run.id),
          span(
            style=["color:#d9e5f4"],
            normalized_run_status(run.status) +
            run.current_step_id.map(step => " · " + step).unwrap_or(""),
          ),
          small(
            style=["color:#8399b7", "overflow-wrap:anywhere"],
            run.workspace_dir.unwrap_or("Workspace not allocated yet"),
          ),
        ]),
      )
    None => ()
  }
  div(run_rows)
}

///|
fn plan_panel(session : CoworkSessionDetail?) -> @rabbita.Html {
  let text = session
    .bind(item => item.plan_preview)
    .unwrap_or("The plan will appear here before any durable run is created.")
  pre(
    style=[
      "white-space:pre-wrap", "max-height:430px", "overflow:auto", "background:#07101f",
      "border:1px solid #273a58", "border-radius:12px", "padding:14px", "font-size:12px",
      "line-height:1.55", "color:#cbd8e8",
    ],
    text,
  )
}

///|
fn research_actions(emit : @rabbita.Emit[Msg], model : Model) -> @rabbita.Html {
  let actions : Array[@rabbita.Html] = []
  match model.research_execution {
    Some(execution) =>
      match execution.state {
        "prepared" =>
          actions.push(
            action_button(
              "Submit installed capability",
              emit(StartResearch),
              primary=true,
            ),
          )
        "submitting" | "pending" | "unknown" =>
          actions.push(
            action_button(
              "Reconcile same attempt",
              emit(StartResearch),
              primary=true,
            ),
          )
        "command-ready" =>
          if model.gateway_published {
            actions.push(
              action_button(
                "Run exact MoonClaw command",
                emit(StartResearch),
                primary=true,
              ),
            )
          }
        "runtime-submitting" | "runtime-pending" | "runtime-unknown" =>
          if model.gateway_published {
            actions.push(
              action_button(
                "Poll persisted MoonClaw run",
                emit(RefreshResearch),
                primary=true,
              ),
            )
          }
        "needs-review" => ()
        _ =>
          actions.push(
            action_button("Inspect blocked execution", emit(StartResearch)),
          )
      }
    None =>
      actions.push(
        action_button("Capability preparation unavailable", emit(StartResearch)),
      )
  }
  div(style=["display:flex", "gap:9px", "flex-wrap:wrap"], actions)
}

///|
fn research_execution_terminal(model : Model) -> Bool {
  model.research_execution
  .map(execution => execution.state == "needs-review")
  .unwrap_or(false)
}

///|
fn setup_panel(emit : @rabbita.Emit[Msg], model : Model) -> @rabbita.Html {
  section(
    id="research-run",
    style=surface() + ["padding:18px", "display:grid", "gap:13px"],
    [
      div([
        eyebrow("CATALOG-BOUND RUN SETUP"),
        h2(style=["margin:5px 0 3px", "font-size:20px"], "Research execution"),
        p(
          style=["margin:0", "color:#94a9c4", "line-height:1.5"],
          "The browser can submit only the immutable capability published from the current append-only run journal. The exact returned command runs in MoonClaw Cowork; MoonFind never calls a model provider directly.",
        ),
      ]),
      div(
        style=[
          "display:grid", "gap:7px", "padding:12px", "background:#07101f", "border:1px solid #273a58",
          "border-radius:10px",
        ],
        [
          eyebrow("PACK HOST"),
          span(
            style=[
              "color:" +
              (if model.host_status == "ready" { "#74e0a7" } else { "#f4cb72" }),
              "font-weight:800",
            ],
            model.host_status.to_upper(),
          ),
          if model.host_blockers.is_empty() {
            small(
              style=["color:#93a8c2"],
              "Current durable workspace and capability ports are published.",
            )
          } else {
            ul(
              style=["margin:0", "padding-left:18px", "color:#f4cb72"],
              model.host_blockers.map(blocker => li(blocker)),
            )
          },
        ],
      ),
      if research_execution_terminal(model) {
        div(
          style=[
            "display:grid", "gap:5px", "padding:12px", "background:#07101f", "border:1px solid #273a58",
            "border-radius:10px",
          ],
          [
            eyebrow("MOONCLAW RUNTIME"),
            strong(
              style=["color:#74e0a7"],
              "Execution complete · live session not required",
            ),
            small(
              style=["color:#93a8c2"],
              "This view is backed by the immutable MoonClaw receipt and run checkpoint. It will not contact or advertise an unavailable operator.",
            ),
          ],
        )
      } else if model.gateway_published {
        div(
          style=[
            "display:grid", "gap:5px", "padding:12px", "background:#07101f", "border:1px solid #273a58",
            "border-radius:10px",
          ],
          [
            eyebrow("REACHABLE MOONCLAW GATEWAY"),
            code(
              style=["color:#8fdccc", "overflow-wrap:anywhere"],
              model.gateway_base,
            ),
            small(
              style=["color:#93a8c2"],
              "The trusted host verified and published this endpoint.",
            ),
          ],
        )
      } else {
        small(
          style=["color:#f4cb72"],
          "No reachable MoonClaw gateway was published by the trusted host.",
        )
      },
      field_label(
        "MoonBook workspace",
        text_field(
          model.book_dir,
          "Load the trusted Book workspace",
          emit.map(value => SetBookDir(value)),
        ),
      ),
      if research_execution_terminal(model) {
        @html.nothing
      } else {
        model_picker(emit, model)
      },
      research_actions(emit, model),
      match model.research_execution {
        Some(execution) =>
          div(
            style=[
              "display:grid", "gap:6px", "padding:12px", "background:#07101f", "border:1px solid #273a58",
              "border-radius:10px",
            ],
            [
              eyebrow("DURABLE EXECUTION"),
              code(style=["color:#8fdccc"], execution.operation_ref),
              span(
                style=["color:#d9e5f4"],
                "state: \{execution.state} · revision \{execution.revision}",
              ),
              small(
                style=["color:#93a8c2", "overflow-wrap:anywhere"],
                "request \{execution.request_id} · attempt \{execution.attempt_id}",
              ),
              small(
                style=["color:#93a8c2", "overflow-wrap:anywhere"],
                "next: " + execution.next_action,
              ),
            ],
          )
        None =>
          small(
            style=["color:#f4cb72"],
            "Waiting for the MoonFind host to publish a prepared execution and generic MoonClaw ports.",
          )
      },
    ],
  )
}

///|
fn gap_editor(
  title : String,
  severity : Int,
  summary : String,
  on_severity : @rabbita.Emit[String],
  on_summary : @rabbita.Emit[String],
) -> @rabbita.Html {
  div(
    style=[
      "display:grid", "grid-template-columns:minmax(130px,.42fr) minmax(220px,1fr)",
      "gap:9px", "padding:11px", "background:#07101f", "border:1px solid #273a58",
      "border-radius:11px",
    ],
    [
      field_label(
        title + " severity",
        gap_severity_field(severity, on_severity),
      ),
      field_label(
        title + " evidence statement",
        text_field(
          summary, "What was missing, misrecognized, or undecided?", on_summary,
        ),
      ),
    ],
  )
}

///|
fn review_panel(emit : @rabbita.Emit[Msg], model : Model) -> @rabbita.Html {
  let workflow = model.review_workflow
  section(
    id="named-review",
    style=surface() + ["padding:18px", "display:grid", "gap:11px"],
    [
      completed_result_panel(emit, model),
      review_draft_panel(emit, model),
      delivery_panel(emit, model),
      retained_review_panel(emit, model),
      match model.review_context_notice {
        Some(message) => p(class="evidence-boundary", message)
        None => @html.nothing
      },
      div([
        eyebrow("PORTABLE REVIEW → BOOKKEEPER"),
        h2(
          style=["margin:5px 0", "font-size:19px"],
          "Named-human decision and Three-Gap record",
        ),
        p(
          style=["margin:0", "color:#95aac5", "line-height:1.5"],
          "MoonFind captures this bounded decision and produces a portable bundle. MoonChat records the versioned review through MoonFlow. MoonBook's existing Rabbita queue alone accepts the deliverable and owns Three-Gap learning.",
        ),
      ]),
      div(
        style=[
          "display:grid", "gap:5px", "padding:11px", "background:#07101f", "border:1px solid #273a58",
          "border-radius:11px",
        ],
        [
          eyebrow("DURABLE REVIEW WORKFLOW"),
          strong(
            style=[
              "color:" +
              workflow
              .map(value => {
                if value.state
                  is ("ready-for-human-review"
                  | "awaiting-moonchat"
                  | "ready-for-bookkeeper") {
                  "#74e0a7"
                } else {
                  "#f4cb72"
                }
              })
              .unwrap_or("#8297b4"),
            ],
            workflow
            .map(value => value.state.to_upper())
            .unwrap_or("NOT PUBLISHED"),
          ),
          small(
            style=["color:#a8b9cf", "line-height:1.5"],
            workflow
            .map(value => value.detail)
            .unwrap_or("The trusted host has not published a review workflow."),
          ),
        ],
      ),
      field_label(
        "Reviewer name",
        text_field(
          model.reviewer_name,
          "Required before approval",
          emit.map(value => SetReviewerName(value)),
        ),
      ),
      field_label(
        "Decision outcome",
        select(
          on_change=emit.map(value => SetReviewOutcome(value)),
          style=[
            "width:100%", "min-height:44px", "box-sizing:border-box", "background:#07101f",
            "color:#edf5ff", "border:1px solid #314563", "border-radius:10px", "padding:10px 12px",
            "font:inherit",
          ],
          [
            option(
              value="",
              selected=model.review_outcome == "",
              disabled=true,
              "Choose a review outcome",
            ),
            option(
              value="approve_subset",
              selected=model.review_outcome == "approve_subset",
              "Approve a named subset",
            ),
            option(
              value="request_changes",
              selected=model.review_outcome == "request_changes",
              "Defer / request changes",
            ),
            option(
              value="reject",
              selected=model.review_outcome == "reject",
              "Reject candidate",
            ),
          ],
        ),
      ),
      field_label(
        "Decision scope · exact synthesis IDs",
        text_field(
          model.review_scope,
          "Select result ideas above or enter exact IDs, separated by commas",
          emit.map(value => SetReviewScope(value)),
        ),
      ),
      p(
        class="evidence-boundary",
        "Defer keeps the named decision unresolved and preserves your reason for waiting or requesting changes. Reject closes this version's review. Neither choice approves ideas or prepares a MoonBook submission; reconsideration needs a new research revision.",
      ),
      field_label(
        "Reviewer rationale or requested change",
        textarea(
          value=model.review_message,
          rows=5,
          on_input=emit.map(value => SetReviewMessage(value)),
          style=[
            "width:100%", "box-sizing:border-box", "resize:vertical", "background:#07101f",
            "color:#dbe8f7", "border:1px solid #314563", "border-radius:10px", "padding:12px",
            "font:inherit",
          ],
          "",
        ),
      ),
      div(style=["display:grid", "gap:9px"], [
        eyebrow("THREE-GAP OBSERVATION"),
        gap_editor(
          "Information",
          model.information_gap_severity,
          model.information_gap_summary,
          emit.map(value => SetInformationGapSeverity(value)),
          emit.map(value => SetInformationGapSummary(value)),
        ),
        gap_editor(
          "Recognition",
          model.recognition_gap_severity,
          model.recognition_gap_summary,
          emit.map(value => SetRecognitionGapSeverity(value)),
          emit.map(value => SetRecognitionGapSummary(value)),
        ),
        gap_editor(
          "Decisiveness",
          model.decisiveness_gap_severity,
          model.decisiveness_gap_summary,
          emit.map(value => SetDecisivenessGapSeverity(value)),
          emit.map(value => SetDecisivenessGapSummary(value)),
        ),
        small(
          style=["color:#8297b4", "line-height:1.45"],
          "These are explicit observations for Bookkeeper review, not self-applied learning. Severity 0 means the gap is not present; any positive severity needs a concrete statement.",
        ),
      ]),
      match moonflow_review_binding_issue(model) {
        Some(issue) =>
          small(
            style=["color:#f4cb72", "line-height:1.45"],
            "MoonFlow binding: " + issue,
          )
        None =>
          small(
            style=["color:#8297b4"],
            if workflow
              .map(value => value.state == "ready-for-human-review")
              .unwrap_or(false) {
              "The candidate is ready. Approval remains bounded to the explicit scope and named reviewer above."
            } else {
              "This decision form is locked by the durable workflow state shown above."
            },
          )
      },
      div(
        style=[
          "display:flex", "justify-content:space-between", "gap:10px", "align-items:center",
          "flex-wrap:wrap", "padding-top:4px",
        ],
        [
          small(style=["color:#9fb2ca"], review_phase_text(model.review_phase)),
          review_actions(emit, model),
        ],
      ),
      match model.review_prepare_reply {
        Some(reply) =>
          div(
            style=[
              "display:grid", "gap:6px", "padding:11px", "background:#07101f", "border:1px solid #2e6f71",
              "border-radius:11px",
            ],
            [
              eyebrow("MOONCHAT BUNDLE"),
              code(
                style=["color:#8fdccc", "overflow-wrap:anywhere"],
                reply.bundle_ref,
              ),
              small(
                style=["color:#a8b9cf", "overflow-wrap:anywhere"],
                reply.operation_ref + " · review " + reply.review_id,
              ),
            ],
          )
        None =>
          match workflow.bind(value => value.bundle_ref) {
            Some(bundle_ref) =>
              div(
                style=[
                  "display:grid", "gap:6px", "padding:11px", "background:#07101f",
                  "border:1px solid #2e6f71", "border-radius:11px",
                ],
                [
                  eyebrow("DURABLE PORTABLE BUNDLE"),
                  code(
                    style=["color:#8fdccc", "overflow-wrap:anywhere"],
                    bundle_ref,
                  ),
                  small(
                    style=["color:#a8b9cf"],
                    workflow
                    .bind(value => value.moonchat_operation_ref)
                    .unwrap_or("Waiting for MoonChat operation binding"),
                  ),
                ],
              )
            None => @html.nothing
          }
      },
      match workflow.bind(value => value.bookkeeper_submission_ref) {
        Some(submission_ref) =>
          div(
            style=[
              "display:grid", "gap:6px", "padding:11px", "background:#07101f", "border:1px solid #2e6f71",
              "border-radius:11px",
            ],
            [
              eyebrow(
                if workflow
                  .map(value => value.state == "ready-for-bookkeeper")
                  .unwrap_or(false) {
                  "READY FOR MOONBOOK"
                } else {
                  "RETAINED MOONBOOK SUBMISSION"
                },
              ),
              code(
                style=["color:#8fdccc", "overflow-wrap:anywhere"],
                submission_ref,
              ),
              small(
                style=["color:#a8b9cf"],
                workflow
                .bind(value => value.bookkeeper_operation_ref)
                .unwrap_or("MoonBook operation not published"),
              ),
              small(
                style=["color:#f4cb72", "line-height:1.45"],
                if workflow
                  .map(value => value.state == "ready-for-bookkeeper")
                  .unwrap_or(false) {
                  "Open MoonBook's existing Rabbita Bookkeeper queue to review the deliverable. This MoonFind view cannot accept or activate it."
                } else {
                  "This saved submission is retained for inspection. The current review is not ready for a new handoff; restore the exact evidence or create a new research revision. MoonBook acceptance is unknown."
                },
              ),
            ],
          )
        None => @html.nothing
      },
    ],
  )
}

///|
fn qa_panel(emit : @rabbita.Emit[Msg], model : Model) -> @rabbita.Html {
  let answer = if model.qa_response_context ==
    Some(qa_projection_context(model)) {
    model.qa_answer_text.unwrap_or(
      "No cited response has been returned for this evidence yet.",
    )
  } else {
    "No response is bound to the current evidence yet. Prepare Q&A or ask a new question; a previous response is not evidence for this run."
  }
  section(style=surface() + ["padding:18px", "display:grid", "gap:11px"], [
    div([
      eyebrow("RETAINED AGENT"),
      h2(
        style=["margin:5px 0", "font-size:19px", "overflow-wrap:anywhere"],
        "Ask about " + research_context_title(model),
      ),
      p(
        style=["margin:0", "color:#95aac5", "line-height:1.5"],
        "Answers use this run's supplied evidence and citations. Missing sources stay missing; Q&A cannot accept ideas or change named review. Reloading restores the retained session with read-only requests. Ask explicitly to supply the current evidence.",
      ),
    ]),
    match model.qa_session {
      Some(session) =>
        code(
          style=["color:#79dccb", "font-size:11px", "overflow-wrap:anywhere"],
          session.session.session_key,
        )
      None => @html.nothing
    },
    if model.pending_qa is Some(_) {
      button(
        disabled=true,
        attrs=@html.Attrs::build().aria_busy("true"),
        "Preparing Q&A…",
      )
    } else if model.pending_qa_restore is Some(_) || model.qa_readback_loading {
      button(
        disabled=true,
        attrs=@html.Attrs::build().aria_busy("true"),
        "Checking retained Q&A…",
      )
    } else if qa_retained_issue(model) is Some(issue) {
      div([
        p(style=["color:#f4cb72"], issue),
        action_button(
          if model.book_dir != model.trusted_book_dir {
            "Restore trusted Book and reconnect"
          } else {
            "Check retained session"
          },
          emit(RefreshQa),
        ),
      ])
    } else if !model.gateway_published {
      div([
        small(
          style=["color:#f4cb72"],
          "No reachable MoonClaw gateway was published; check the host connection before reconnecting.",
        ),
        action_button("Check retained session", emit(RefreshQa)),
      ])
    } else if model.qa_canonical_key is Some(_) {
      if model.qa_session is None {
        action_button("Check retained session", emit(RefreshQa))
      } else if !model.qa_ready {
        div([
          small(
            style=["color:#f4cb72"],
            "This session is retained, but preparation is unfinished. Use the selected exact model to finish preparation.",
          ),
          action_button(
            "Finish Q&A preparation",
            emit(FinishQaPreparation),
            primary=true,
          ),
          action_button("Check retained session", emit(RefreshQa)),
        ])
      } else {
        @html.nothing
      }
    } else {
      action_button("Prepare Q&A agent", emit(PrepareQa), primary=true)
    },
    field_label(
      "Question",
      textarea(
        value=model.qa_question,
        rows=4,
        on_input=emit.map(value => SetQaQuestion(value)),
        style=[
          "width:100%", "box-sizing:border-box", "resize:vertical", "background:#07101f",
          "color:#dbe8f7", "border:1px solid #314563", "border-radius:10px", "padding:12px",
          "font:inherit",
        ],
        "",
      ),
    ),
    match model.qa_error {
      Some(error) =>
        p(
          attrs=@html.Attrs::build().role("alert"),
          style=["color:#f4cb72"],
          error,
        )
      None => @html.nothing
    },
    if model.pending_question is Some(_) {
      button(
        disabled=true,
        attrs=@html.Attrs::build().aria_busy("true"),
        "Answering…",
      )
    } else if model.qa_ready {
      action_button(
        if model.qa_error is Some(_) {
          "Retry question"
        } else {
          "Ask retained agent"
        },
        emit(AskQa),
        primary=true,
      )
    } else {
      small(
        style=["color:#8297b4"],
        "Ask becomes available after Q&A preparation finishes.",
      )
    },
    article(
      style=[
        "background:#07101f", "border:1px solid #273a58", "border-radius:12px", "padding:14px",
      ],
      [
        eyebrow("LATEST RESPONSE"),
        if model.qa_response_context == Some(qa_projection_context(model)) {
          match model.qa_answered_question {
            Some(question) => p([strong("Question answered: "), span(question)])
            None => @html.nothing
          }
        } else {
          @html.nothing
        },
        pre(
          style=[
            "white-space:pre-wrap", "overflow-wrap:anywhere", "font:12px/1.55 ui-monospace,SFMono-Regular,monospace",
            "color:#cbd8e8",
          ],
          answer,
        ),
      ],
    ),
  ])
}

///|
fn evidence_panel(model : Model) -> @rabbita.Html {
  let workspace = model.workspace
  section(style=surface() + ["padding:18px"], [
    eyebrow("CURRENT DURABLE RUN"),
    h2(
      style=["margin:5px 0"],
      workspace
      .map(value => value.watch_title)
      .unwrap_or("Waiting for the MoonFind host"),
    ),
    div(
      style=[
        "display:grid", "grid-template-columns:repeat(3,minmax(0,1fr))", "gap:9px",
        "margin:13px 0",
      ],
      [
        div(
          style=["background:#07101f", "padding:12px", "border-radius:10px"],
          [
            h3(
              style=["margin:0", "font-size:24px"],
              workspace
              .map(value => value.paper_count.to_string())
              .unwrap_or("—"),
            ),
            small(style=["color:#8fa4bf"], "point-in-time papers"),
          ],
        ),
        div(
          style=["background:#07101f", "padding:12px", "border-radius:10px"],
          [
            h3(
              style=["margin:0", "font-size:24px"],
              workspace
              .map(value => value.summary_count.to_string())
              .unwrap_or("—"),
            ),
            small(style=["color:#8fa4bf"], "evidence summaries"),
          ],
        ),
        div(
          style=["background:#07101f", "padding:12px", "border-radius:10px"],
          [
            h3(
              style=["margin:0", "font-size:24px"],
              workspace
              .map(value => value.idea_count.to_string())
              .unwrap_or("—"),
            ),
            small(style=["color:#8fa4bf"], "falsifiable ideas"),
          ],
        ),
      ],
    ),
    p(
      style=["color:#a8b9cf", "line-height:1.55"],
      workspace
      .map(value => {
        "Status: \{value.status}. Active stage: \{value.active_stage}. Three-Gap state: \{value.three_gap_state}."
      })
      .unwrap_or(
        "The static demo projection has been retired. Start the MoonBit UI host with a durable run to inspect current evidence.",
      ),
    ),
    code(
      style=[
        "display:block", "color:#8fdccc", "font-size:11px", "overflow-wrap:anywhere",
        "margin-bottom:10px",
      ],
      workspace
      .map(value => "run \{value.run_id} · \{value.query}")
      .unwrap_or("no durable run loaded"),
    ),
    match workspace {
      Some(value) => evidence_detail_panel(value)
      None => @html.nothing
    },
    if model.gateway_published &&
      !research_execution_terminal(model) &&
      !model.gateway_base.contains("/api/v1/cowork-gateway") {
      a(
        href=model.gateway_base + "/ui",
        target=Blank,
        style=["color:#70dccb", "font-weight:800"],
        "Open MoonClaw operator",
      )
    } else {
      small(
        style=["color:#8297b4"],
        if model.gateway_base.contains("/api/v1/cowork-gateway") &&
          !research_execution_terminal(model) {
          "Cowork is connected through the trusted MoonFind host. Its separate operator interface is not published by this relay."
        } else if research_execution_terminal(model) {
          "The terminal run is projected from durable evidence; no live MoonClaw operator is required."
        } else {
          "No reachable MoonClaw operator was published."
        },
      )
    },
  ])
}

///|
fn moontown_handoff_panel(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let handoff = model.moontown_handoff
  section(style=surface() + ["padding:18px", "display:grid", "gap:10px"], [
    div([
      eyebrow("TYPED CROSS-PRODUCT HANDOFF"),
      h2(style=["margin:5px 0"], "Challenge in MoonTown"),
      p(
        style=["margin:0", "color:#95aac5", "line-height:1.5"],
        "MoonFind exposes only the versioned run-bound handoff artifact. MoonTown remains a separate product and MoonClaw remains its agent runtime.",
      ),
    ]),
    span(
      style=[
        "color:" +
        handoff
        .map(value => {
          if value.state == "ready" ||
            value.state == "completed" ||
            value.state == "ingested-pending-review" {
            "#74e0a7"
          } else {
            "#f4cb72"
          }
        })
        .unwrap_or("#8297b4"),
        "font-weight:800",
      ],
      handoff.map(value => value.state.to_upper()).unwrap_or("NOT PUBLISHED"),
    ),
    small(
      style=["color:#a8b9cf", "line-height:1.5"],
      handoff
      .map(value => value.detail)
      .unwrap_or(
        "The MoonFind host has not published a MoonTown handoff status.",
      ),
    ),
    handoff
    .bind(value => value.handoff_id)
    .map(id => {
      code(
        style=["color:#8fdccc", "font-size:11px", "overflow-wrap:anywhere"],
        id,
      )
    })
    .unwrap_or(div("")),
    match handoff.bind(value => value.open_url) {
      Some(url) =>
        a(
          href=url,
          target=Blank,
          style=[
            "display:inline-flex", "align-items:center", "justify-content:center",
            "min-height:44px", "padding:10px 15px", "background:#67d5c4", "color:#07101f",
            "border-radius:11px", "font-weight:800", "text-decoration:none",
          ],
          "Open typed handoff in MoonTown",
        )
      None =>
        small(
          style=["color:#f4cb72"],
          "Open remains unavailable until the handoff validates and the configured MoonTown host responds.",
        )
    },
    if handoff
      .map(value => {
        value.state != "not-ready" && value.state != "awaiting-materialization"
      })
      .unwrap_or(false) {
      action_button(
        "Refresh returned result",
        emit(RefreshMoonTownStatus),
        primary=false,
      )
    } else {
      @html.nothing
    },
  ])
}

///|
fn moonflow_receiver_panel(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  if !moonflow_launch_present(
      model.moonflow_run_id,
      model.moonflow_handoff_token,
    ) {
    return @html.nothing
  }
  let intake = model.moonflow_intake
  let status = model.moonflow_receiver_status
  section(style=surface() + ["padding:18px", "display:grid", "gap:10px"], [
    div([
      eyebrow("MOONFLOW RECEIVER"),
      h2(style=["margin:5px 0"], "Run-bound product handoff"),
      p(
        style=["margin:0", "color:#95aac5", "line-height:1.5"],
        "This view reads the exact generic MoonFlow intake and status from the MoonDesk origin. The token is correlation, never authority.",
      ),
    ]),
    code(
      style=["color:#8fdccc", "font-size:11px", "overflow-wrap:anywhere"],
      "run \{model.moonflow_run_id} · handoff \{model.moonflow_handoff_token}",
    ),
    match model.moonflow_receiver_error {
      Some(error) =>
        small(
          style=["color:#ff9e9e", "line-height:1.45"],
          "Receiver problem: " + error,
        )
      None => @html.nothing
    },
    match intake {
      Some(handoff) =>
        div(
          style=[
            "display:grid", "gap:6px", "padding:11px", "background:#07101f", "border:1px solid #273a58",
            "border-radius:11px",
          ],
          [
            eyebrow("VERIFIED INTAKE"),
            strong(style=["color:#74e0a7"], handoff.payload.run.operation),
            small(
              style=["color:#a8b9cf", "overflow-wrap:anywhere"],
              "work item \{handoff.payload.run.work_item_id} · declaration \{handoff.payload.run.declaration_id}",
            ),
            small(
              style=["color:#a8b9cf"],
              "authority requested: " +
              handoff.payload.authority.requested_authority,
            ),
            small(
              style=["color:#a8b9cf"],
              "outputs: " +
              handoff.payload.contracts.output_contracts.join(", "),
            ),
            if handoff.payload.review.acceptance_criteria.is_empty() {
              small(style=["color:#8297b4"], "No acceptance criteria declared.")
            } else {
              ul(
                style=["margin:0", "padding-left:18px", "color:#a8b9cf"],
                handoff.payload.review.acceptance_criteria.map(criterion => {
                  li(criterion)
                }),
              )
            },
          ],
        )
      None =>
        small(
          style=["color:#f4cb72"],
          "Waiting for MoonDesk to return the verified handoff payload.",
        )
    },
    match status {
      Some(receiver) =>
        div(
          style=[
            "display:flex", "gap:9px", "align-items:center", "justify-content:space-between",
            "flex-wrap:wrap",
          ],
          [
            span(
              style=[
                "color:" +
                (if receiver.status == "accepted" {
                  "#74e0a7"
                } else if receiver.status == "denied" {
                  "#ff9e9e"
                } else {
                  "#f4cb72"
                }),
                "font-weight:800",
              ],
              "RECEIVER " +
              receiver.status.to_upper() +
              " · WORK " +
              receiver.work_item_status.to_upper(),
            ),
            a(
              href=receiver.return_path,
              style=["color:#70dccb", "font-weight:800"],
              "Return to Flow",
            ),
          ],
        )
      None => small(style=["color:#8297b4"], "Receiver status has not loaded.")
    },
    if status.map(receiver => receiver.status == "pending").unwrap_or(false) &&
      model.review_workflow
      .map(workflow => {
        workflow.state is ("awaiting-moonchat" | "ready-for-bookkeeper")
      })
      .unwrap_or(false) {
      div(
        style=[
          "padding:11px", "background:#2b2516", "border:1px solid #7e6931", "border-radius:11px",
          "display:grid", "gap:5px",
        ],
        [
          strong(style=["color:#74e0a7"], "Review bundle is ready to return"),
          small(
            style=["color:#ddcfaa", "line-height:1.5"],
            "The trusted MoonFind host will revalidate this exact intake, bind a durable local-workspace authority receipt, compute the aggregate digest from persisted bytes, and cover every declared acceptance criterion. MoonBook acceptance remains a later, separate human gate.",
          ),
          action_button(
            "Return reviewed bundle to Flow",
            emit(SettleMoonFlowReceipt),
            primary=true,
          ),
        ],
      )
    } else {
      @html.nothing
    },
    match model.moonflow_receipt_reply {
      Some(reply) =>
        small(
          style=["color:#8fdccc", "overflow-wrap:anywhere"],
          "Prepared immutable receiver receipt · " + reply.receipt_path,
        )
      None => @html.nothing
    },
    action_button(
      "Refresh MoonFlow receiver",
      emit(RefreshMoonFlowReceiver),
      primary=false,
    ),
  ])
}

///|
fn view(emit : @rabbita.Emit[Msg], model : Model) -> @rabbita.Html {
  if browser_brief_mode() {
    return main_(
      id="moonfind-brief-workspace",
      style=[
        "min-height:100vh", "background:#07101f", "color:#edf5ff", "font-family:Inter,system-ui,sans-serif",
        "padding:clamp(14px,3vw,34px)",
      ],
      div(style=["max-width:1180px", "margin:0 auto"], [
        brief_panel(emit, model.brief),
        offline_choices_panel(emit, model),
      ]),
    )
  }
  main_(
    id="moonfind-primary-workspace",
    style=[
      "min-height:100vh", "background:#07101f", "color:#edf5ff", "font-family:Inter,'Avenir Next',system-ui,sans-serif",
      "padding:clamp(14px,3vw,34px)", "box-sizing:border-box",
    ],
    div(
      style=["max-width:1480px", "margin:0 auto", "display:grid", "gap:16px"],
      [
        header(
          style=surface() +
            [
              "padding:22px", "display:flex", "justify-content:space-between", "gap:18px",
              "flex-wrap:wrap", "align-items:flex-start",
            ],
          [
            div([
              eyebrow("MOONFIND / RESEARCH JOBS"),
              h1(
                style=["margin:5px 0 4px", "font-size:clamp(27px,4vw,44px)"],
                model.workspace
                .map(workspace => workspace.title)
                .unwrap_or("Moonfind research studio"),
              ),
              p(
                style=["margin:0", "color:#9cb0cd", "max-width:72ch"],
                "Start a research job, follow the MoonClaw work, and open the files it delivers. Specialized evidence and review tools remain available for saved runs.",
              ),
            ]),
            div(style=["display:grid", "gap:8px", "justify-items:end"], [
              span(
                style=[
                  "color:" + phase_color(model.phase),
                  "border:1px solid " + phase_color(model.phase),
                  "border-radius:999px",
                  "padding:7px 11px",
                  "font-size:12px",
                  "font-weight:800",
                ],
                phase_text(model.phase),
              ),
              small(
                style=["color:#7f95b3"],
                if model.workspace is Some(_) {
                  "MoonBook · pending review"
                } else {
                  "Local research workspace"
                },
              ),
            ]),
          ],
        ),
        brief_panel(emit, model.brief),
        offline_choices_panel(emit, model),
        choices_panel(emit, model),
        render_general_jobs(emit, model),
        if model.workspace is Some(_) {
          render_research_compass(emit, model)
        } else {
          @html.nothing
        },
        if model.workspace is Some(_) {
          render_series_catalog(emit, model)
        } else {
          @html.nothing
        },
        match (model.notice, model.error) {
          (_, Some(error)) =>
            div(
              attrs=@html.Attrs::build().role("alert").aria_live("assertive"),
              style=[
                "background:#3b1f2b", "border:1px solid #9a5366", "border-radius:12px",
                "padding:12px 15px", "color:#ffd5de",
              ],
              "Problem: " + error,
            )
          (Some(notice), None) =>
            div(
              attrs=@html.Attrs::build().role("status").aria_live("polite"),
              style=[
                "background:#132b30", "border:1px solid #2e6f71", "border-radius:12px",
                "padding:12px 15px", "color:#b9eee5",
              ],
              notice,
            )
          _ => div("")
        },
        if model.workspace is Some(_) {
          div(
            style=[
              "display:grid", "grid-template-columns:repeat(auto-fit,minmax(min(100%,520px),1fr))",
              "gap:16px", "align-items:start",
            ],
            [
              div(style=["display:grid", "gap:16px"], [
                workflow_steps(model),
                evidence_panel(model),
                moontown_handoff_panel(emit, model),
                moonflow_receiver_panel(emit, model),
                model.research_session
                .map(session => {
                  section(style=surface() + ["padding:18px"], [
                    eyebrow("LIVE RUN"),
                    run_detail(session),
                  ])
                })
                .unwrap_or(div("")),
              ]),
              div(style=["display:grid", "gap:16px"], [
                setup_panel(emit, model),
                section(style=surface() + ["padding:18px"], [
                  eyebrow("PLAN PREVIEW"),
                  plan_panel(model.research_session),
                ]),
                review_panel(emit, model),
                qa_panel(emit, model),
              ]),
            ],
          )
        } else {
          @html.nothing
        },
      ],
    ),
  )
}
