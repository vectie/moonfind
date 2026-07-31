///|
using @html {
  a,
  article,
  button,
  code,
  div,
  h1,
  h2,
  h3,
  header,
  input,
  label,
  li,
  main_,
  option,
  p,
  pre,
  select,
  section,
  small,
  span,
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
    Ready => "Ready"
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
fn workflow_steps(model : Model) -> @rabbita.Html {
  let steps = [
    ("01", "Account 17/17 available pages", true),
    ("02", "Cross-validate primary sources", true),
    ("03", "MoonTown four-role challenge", true),
    (
      "04",
      "Validate and invoke installed pack capability",
      model.research_execution
      .map(execution => {
        execution.state
        is ("command-ready" | "runtime-pending" | "needs-review")
      })
      .unwrap_or(false),
    ),
    (
      "05",
      "Execute exact command in MoonClaw Cowork",
      model.research_execution
      .map(execution => execution.state is ("runtime-pending" | "needs-review"))
      .unwrap_or(false),
    ),
    ("06", "Named-human MoonBook review", model.review_phase == ReviewCompleted),
    ("07", "Retained cited Q&A agent", model.qa_ready),
  ]
  let rows : Array[@rabbita.Html] = []
  for step in steps {
    let (number, title, done) = step
    let status_color = if done { "#74e0a7" } else { "#8196b3" }
    rows.push(
      li(
        style=[
          "display:grid", "grid-template-columns:34px 1fr auto", "gap:9px", "align-items:center",
          "padding:9px 0", "border-bottom:1px solid #22334d",
        ],
        [
          code(style=["color:#6dd7c7"], number),
          span(style=["color:#d9e5f4"], title),
          small(
            style=["color:" + status_color, "font-weight:800"],
            if done {
              "DONE"
            } else {
              "NEXT"
            },
          ),
        ],
      ),
    )
  }
  ul(style=["list-style:none", "padding:0", "margin:8px 0 0"], rows)
}

///|
fn review_phase_text(phase : ReviewPhase) -> String {
  match phase {
    ReviewIdle => "Decision not started"
    ReviewCreatingSession => "Creating review session"
    ReviewPlanning => "Planning decision"
    ReviewPlanReady => "Review plan ready"
    ReviewPromoting => "Promoting review plan"
    ReviewProposalReady => "Review proposal ready"
    ReviewConfirming => "Confirming decision run"
    ReviewRunning => "Decision run active"
    ReviewCompleted => "Decision run completed"
    ReviewFailed => "Review workflow needs attention"
  }
}

///|
fn review_actions(emit : @rabbita.Emit[Msg], model : Model) -> @rabbita.Html {
  let actions : Array[@rabbita.Html] = []
  let execution_review_ready = model.research_execution
    .map(execution => execution.state == "needs-review")
    .unwrap_or(false)
  match model.review_phase {
    ReviewIdle | ReviewFailed =>
      if execution_review_ready {
        actions.push(
          action_button(
            "Prepare scoped review plan",
            emit(PrepareReview),
            primary=true,
          ),
        )
      }
    ReviewPlanReady =>
      actions.push(
        action_button(
          "Promote review proposal",
          emit(PromoteReview),
          primary=true,
        ),
      )
    ReviewProposalReady =>
      actions.push(
        action_button(
          "Confirm durable decision run",
          emit(ConfirmReview),
          primary=true,
        ),
      )
    ReviewRunning | ReviewCompleted =>
      actions.push(action_button("Refresh decision run", emit(RefreshReview)))
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
          actions.push(
            action_button(
              "Run exact MoonClaw command",
              emit(StartResearch),
              primary=true,
            ),
          )
        "runtime-submitting" | "runtime-pending" | "runtime-unknown" =>
          actions.push(
            action_button(
              "Poll persisted MoonClaw run",
              emit(RefreshResearch),
              primary=true,
            ),
          )
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
fn setup_panel(emit : @rabbita.Emit[Msg], model : Model) -> @rabbita.Html {
  section(style=surface() + ["padding:18px", "display:grid", "gap:13px"], [
    div([
      eyebrow("CATALOG-BOUND RUN SETUP"),
      h2(style=["margin:5px 0 3px", "font-size:20px"], "Research execution"),
      p(
        style=["margin:0", "color:#94a9c4", "line-height:1.5"],
        "The browser can submit only a host-prepared, catalog-validated capability. The resulting exact command runs in MoonClaw Cowork; no model provider is called directly.",
      ),
    ]),
    field_label(
      "MoonClaw gateway",
      text_field(
        model.gateway_base,
        "http://127.0.0.1:18123",
        emit.map(value => SetGateway(value)),
      ),
    ),
    field_label(
      "Private source folder",
      text_field(
        model.source_dir,
        "/Users/name/Downloads/deepseek",
        emit.map(value => SetSourceDir(value)),
      ),
    ),
    field_label(
      "MoonBook workspace",
      text_field(
        model.book_dir,
        "/Users/name/Workspace/deepseek-research-book",
        emit.map(value => SetBookDir(value)),
      ),
    ),
    field_label(
      "MoonClaw model route",
      text_field(
        model.model_name,
        "codex/gpt-5.6-sol",
        emit.map(value => SetModelName(value)),
      ),
    ),
    field_label(
      "Research contract",
      textarea(
        value=model.request_text,
        rows=16,
        on_input=emit.map(value => SetRequestText(value)),
        style=[
          "width:100%", "box-sizing:border-box", "resize:vertical", "background:#07101f",
          "color:#dbe8f7", "border:1px solid #314563", "border-radius:10px", "padding:12px",
          "font:12px/1.5 ui-monospace,SFMono-Regular,monospace",
        ],
        "",
      ),
    ),
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
  ])
}

///|
fn review_panel(emit : @rabbita.Emit[Msg], model : Model) -> @rabbita.Html {
  section(style=surface() + ["padding:18px", "display:grid", "gap:11px"], [
    div([
      eyebrow("MOONBOOK AUTHORITY"),
      h2(style=["margin:5px 0", "font-size:19px"], "Named-human review"),
      p(
        style=["margin:0", "color:#95aac5", "line-height:1.5"],
        "Review remains locked until the persisted MoonClaw run completes and MoonFind records a needs-review checkpoint.",
      ),
    ]),
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
            "Request changes",
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
      "Decision scope",
      text_field(
        model.review_scope,
        "Exact Cxx claim IDs or sections; required for approval",
        emit.map(value => SetReviewScope(value)),
      ),
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
    if model.phase == NeedsReview &&
      model.research_execution
      .map(execution => execution.state == "needs-review")
      .unwrap_or(false) {
      action_button(
        "Submit paused-run guidance",
        emit(ResumeReview),
        primary=true,
      )
    } else {
      small(
        style=["color:#8297b4"],
        if model.research_execution
          .map(execution => execution.state == "needs-review")
          .unwrap_or(false) {
          "The candidate is pending. Approval remains bounded to the explicit scope above."
        } else {
          "No review action is available before the durable MoonClaw result reaches needs-review."
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
    model.review_session
    .map(session => {
      div(
        style=[
          "display:grid", "gap:10px", "padding-top:10px", "border-top:1px solid #263654",
        ],
        [
          run_detail(session),
          div([eyebrow("REVIEW PLAN"), plan_panel(Some(session))]),
        ],
      )
    })
    .unwrap_or(div("")),
  ])
}

///|
fn qa_panel(emit : @rabbita.Emit[Msg], model : Model) -> @rabbita.Html {
  let answer = model.qa_session
    .bind(latest_assistant_message)
    .unwrap_or(
      "Prepare the retained session after the research workspace exists. The readiness receipt or latest cited answer will appear here.",
    )
  section(style=surface() + ["padding:18px", "display:grid", "gap:11px"], [
    div([
      eyebrow("RETAINED AGENT"),
      h2(style=["margin:5px 0", "font-size:19px"], "Ask the DeepSeek book"),
      p(
        style=["margin:0", "color:#95aac5", "line-height:1.5"],
        "Answers must cite the book, separate later web updates, and preserve pending-review labels.",
      ),
    ]),
    match model.qa_session {
      Some(session) =>
        code(
          style=["color:#79dccb", "font-size:11px", "overflow-wrap:anywhere"],
          session.session.session_key,
        )
      None => action_button("Prepare Q&A agent", emit(PrepareQa), primary=true)
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
    if model.qa_ready {
      action_button("Ask retained agent", emit(AskQa), primary=true)
    } else {
      small(
        style=["color:#8297b4"],
        "Ask becomes available after the grounding receipt returns.",
      )
    },
    article(
      style=[
        "background:#07101f", "border:1px solid #273a58", "border-radius:12px", "padding:14px",
      ],
      [
        eyebrow("LATEST RESPONSE"),
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
fn evidence_panel() -> @rabbita.Html {
  section(style=surface() + ["padding:18px"], [
    eyebrow("DRAFT BOOK"),
    h2(style=["margin:5px 0"], "Evidence before acceptance"),
    div(
      style=[
        "display:grid", "grid-template-columns:repeat(3,minmax(0,1fr))", "gap:9px",
        "margin:13px 0",
      ],
      [
        div(
          style=["background:#07101f", "padding:12px", "border-radius:10px"],
          [
            h3(style=["margin:0", "font-size:24px"], "17/17"),
            small(style=["color:#8fa4bf"], "available pages used"),
          ],
        ),
        div(
          style=["background:#07101f", "padding:12px", "border-radius:10px"],
          [
            h3(style=["margin:0", "font-size:24px"], "1"),
            small(style=["color:#8fa4bf"], "known missing page"),
          ],
        ),
        div(
          style=["background:#07101f", "padding:12px", "border-radius:10px"],
          [
            h3(style=["margin:0", "font-size:24px"], "3"),
            small(style=["color:#8fa4bf"], "research iterations"),
          ],
        ),
      ],
    ),
    p(
      style=["color:#a8b9cf", "line-height:1.55"],
      "Central synthesis: DeepSeek appears to convert compute scarcity into a repeatable efficiency rate, then use openness and restrained economics as distribution and legitimacy mechanisms. Internal fleet, finance, organization, AGI, and Huawei-parity claims remain attributed or speculative.",
    ),
    code(
      style=[
        "display:block", "color:#8fdccc", "font-size:11px", "overflow-wrap:anywhere",
        "margin-bottom:10px",
      ],
      "/Users/kq/Workspace/deepseek-research-book/wiki/synthesis/deepseek-research-report.md",
    ),
    a(
      href="http://127.0.0.1:18123/ui",
      target=Blank,
      style=["color:#70dccb", "font-weight:800"],
      "Open MoonClaw operator",
    ),
  ])
}

///|
fn robotics_graph_panel() -> @rabbita.Html {
  let executable_products = [
    "MoonBook", "MoonChat", "MoonClaw", "MoonFind", "MoonTown", "MoonProj", "MoonMold",
    "MoonRobo", "MoonMoon", "MoonVis", "MoonCast",
  ]
  section(style=surface() + ["padding:18px", "display:grid", "gap:11px"], [
    div([
      eyebrow("EXACT DESIRED GRAPH / FIXTURE ONLY"),
      h2(style=["margin:5px 0"], "Humanoid robotics composition"),
      p(
        style=["margin:0", "color:#95aac5", "line-height:1.5"],
        "63 exact stages resolve through 43 canonical operations. MoonFlow executes; MoonGate and MoonLib support policy and contracts. MoonEdit and MoonLeaf remain libraries.",
      ),
    ]),
    div(
      style=["display:flex", "gap:7px", "flex-wrap:wrap"],
      executable_products.map(product => {
        span(
          style=[
            "background:#132b30", "border:1px solid #2e6f71", "border-radius:999px",
            "padding:5px 8px", "color:#b9eee5", "font-size:11px", "font-weight:800",
          ],
          product,
        )
      }),
    ),
    code(
      style=["color:#8fdccc", "font-size:11px", "overflow-wrap:anywhere"],
      "workflows/humanoid-robotics-suite.v1.json",
    ),
    small(
      style=["color:#f4cb72", "line-height:1.45"],
      "Fail closed: one missing or expired operation yields no MoonFlow import. The bundled healthy catalog is synthetic test evidence only. Physical commands and publication are excluded.",
    ),
    small(
      style=["color:#9fb2ca", "line-height:1.45"],
      "Terminal authority = MoonRobo readiness observation + simulation evidence + immutable MoonCast delivery/client evidence + named MoonChat decision. MoonBook Bookkeeper then closes the Three-Gap loop.",
    ),
  ])
}

///|
fn view(emit : @rabbita.Emit[Msg], model : Model) -> @rabbita.Html {
  main_(
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
              eyebrow("MOONFIND / LOCAL CORPUS RESEARCH"),
              h1(
                style=["margin:5px 0 4px", "font-size:clamp(27px,4vw,44px)"],
                "DeepSeek evidence studio",
              ),
              p(
                style=["margin:0", "color:#9cb0cd", "max-width:72ch"],
                "From private screenshots to a cross-validated MoonBook report, an explicit review gate, and a retained cited Q&A agent.",
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
              small(style=["color:#7f95b3"], "MoonBook · pending review"),
            ]),
          ],
        ),
        match (model.notice, model.error) {
          (_, Some(error)) =>
            div(
              style=[
                "background:#3b1f2b", "border:1px solid #9a5366", "border-radius:12px",
                "padding:12px 15px", "color:#ffd5de",
              ],
              "Problem: " + error,
            )
          (Some(notice), None) =>
            div(
              style=[
                "background:#132b30", "border:1px solid #2e6f71", "border-radius:12px",
                "padding:12px 15px", "color:#b9eee5",
              ],
              notice,
            )
          _ => div("")
        },
        div(
          style=[
            "display:grid", "grid-template-columns:repeat(auto-fit,minmax(min(100%,520px),1fr))",
            "gap:16px", "align-items:start",
          ],
          [
            div(style=["display:grid", "gap:16px"], [
              section(style=surface() + ["padding:18px"], [
                eyebrow("END-TO-END CONTRACT"),
                workflow_steps(model),
              ]),
              evidence_panel(),
              robotics_graph_panel(),
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
        ),
      ],
    ),
  )
}
