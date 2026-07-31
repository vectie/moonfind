///|
struct ResearchJourney {
  position : Int
  title : String
  detail : String
  action : String
  target : String
} derive(Debug, Eq)

///|
fn research_journey_state(
  workspace_ready : Bool,
  analysis_ready : Bool,
  town_state : String,
  execution_state : String,
  review_state : String,
  failed : Bool,
) -> ResearchJourney {
  if failed {
    return {
      position: if workspace_ready {
        1
      } else {
        0
      },
      title: "Recover the exact research run",
      detail: "Reload durable state, then reconcile the same attempt. Never start a duplicate run to hide an unknown result.",
      action: "Reload state",
      target: "reload",
    }
  }
  if !workspace_ready {
    return {
      position: 0,
      title: "Load the evidence workspace",
      detail: "MoonFind needs one durable question, permitted sources, and a run identity before analysis.",
      action: "Reload workspace",
      target: "reload",
    }
  }
  if !analysis_ready || execution_state != "needs-review" {
    return {
      position: 1,
      title: "Produce cited, falsifiable analysis",
      detail: "Run the exact installed capability through MoonClaw and reconcile its durable receipt.",
      action: "Continue analysis",
      target: "research",
    }
  }
  if town_state != "completed" && town_state != "ingested-pending-review" {
    return {
      position: 2,
      title: "Challenge the cross-paper bridge",
      detail: "Open the typed handoff in MoonTown, then return the correlated synthesis result.",
      action: "Open challenge",
      target: "moontown",
    }
  }
  if review_state == "ready-for-human-review" || review_state == "not-ready" {
    return {
      position: 3,
      title: "Make the named evidence decision",
      detail: "Choose exact idea IDs, explain the decision, and record all three gaps before preparing the portable review.",
      action: "Review evidence",
      target: "review",
    }
  }
  {
    position: 4,
    title: "Return reviewed learning to MoonBook",
    detail: "The portable bundle is durable. MoonBook Bookkeeper remains the only authority that can accept and learn from it.",
    action: "Inspect handoff",
    target: "review",
  }
}

///|
fn journey_for_model(model : Model) -> ResearchJourney {
  research_journey_state(
    model.workspace is Some(_),
    model.workspace
    .map(value => value.summary_count > 0 || value.idea_count > 0)
    .unwrap_or(false),
    model.moontown_handoff.map(value => value.state).unwrap_or("not-ready"),
    model.research_execution.map(value => value.state).unwrap_or("not-ready"),
    model.review_workflow.map(value => value.state).unwrap_or("not-ready"),
    model.error is Some(_),
  )
}

///|
fn journey_action_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
  journey : ResearchJourney,
) -> @rabbita.Html {
  match journey.target {
    "reload" =>
      button(
        class="research-next primary",
        on_click=emit(RefreshMoonTownStatus),
        attrs=@html.Attrs::build()
          .data_set("testid", "research-next-action")
          .aria_label(journey.action),
        [research_icon("refresh"), span(journey.action)],
      )
    "research" =>
      button(
        class="research-next primary",
        on_click=emit(StartResearch),
        attrs=@html.Attrs::build()
          .data_set("testid", "research-next-action")
          .aria_label(journey.action),
        [research_icon("synthesize"), span(journey.action)],
      )
    "moontown" =>
      match model.moontown_handoff.bind(value => value.open_url) {
        Some(url) =>
          a(
            class="research-next primary",
            href=url,
            target=Blank,
            title="Open the exact run-bound challenge in MoonTown",
            attrs=@html.Attrs::build()
              .data_set("testid", "research-next-action")
              .aria_label("Open run-bound MoonTown challenge"),
            [research_icon("challenge"), span(journey.action)],
          )
        None =>
          button(
            class="research-next",
            on_click=emit(RefreshMoonTownStatus),
            attrs=@html.Attrs::build().aria_label(
              "Reload MoonTown handoff state",
            ),
            [research_icon("refresh"), span("Reload challenge")],
          )
      }
    _ =>
      a(
        class="research-next primary",
        href="#named-review",
        attrs=@html.Attrs::build()
          .data_set("testid", "research-next-action")
          .aria_label(journey.action),
        [research_icon("decide"), span(journey.action)],
      )
  }
}

///|
fn render_research_compass(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let journey = journey_for_model(model)
  let steps = [
    ("evidence", "Evidence"),
    ("synthesize", "Synthesize"),
    ("challenge", "Challenge"),
    ("decide", "Decide"),
    ("learn", "Learn"),
  ]
  nav(
    class="research-compass",
    attrs=@html.Attrs::build()
      .aria_label("Research progress and next action")
      .data_set("testid", "research-compass"),
    [
      div(class="research-goal", [
        small("YOUR OUTCOME"),
        strong(journey.title),
        p(
          match model.error {
            Some(error) => "Blocked: " + error + " " + journey.detail
            None => journey.detail
          },
        ),
      ]),
      div(
        class="research-progress",
        attrs=@html.Attrs::build()
          .role("progressbar")
          .aria_valuemin("0")
          .aria_valuemax("5")
          .aria_valuenow(journey.position.to_string())
          .aria_valuetext("Research step \{journey.position + 1} of 5"),
        steps.mapi((index, item) => {
          let (icon, label) = item
          let state = if index < journey.position {
            "done"
          } else if index == journey.position {
            "current"
          } else {
            "pending"
          }
          span(
            class="research-step " + state,
            title="\{label} · \{state}",
            attrs=@html.Attrs::build().aria_label("\{label} \{state}"),
            [research_icon(icon), small(label)],
          )
        }),
      ),
      journey_action_view(emit, model, journey),
    ],
  )
}

///|
fn workflow_steps(model : Model) -> @rabbita.Html {
  let workspace_ready = model.workspace is Some(_)
  let analysis_ready = model.workspace
    .map(workspace => workspace.summary_count > 0 || workspace.idea_count > 0)
    .unwrap_or(false)
  let town_complete = model.moontown_handoff
    .map(handoff => {
      handoff.state == "completed" || handoff.state == "ingested-pending-review"
    })
    .unwrap_or(false)
  let review_state = model.review_workflow
    .map(workflow => workflow.state)
    .unwrap_or("not-ready")
  let steps = [
    ("01", "Load durable workspace", workspace_ready),
    ("02", "Produce cited analysis", analysis_ready),
    ("03", "Complete MoonTown challenge", town_complete),
    (
      "04",
      "Validate installed capability",
      model.research_execution
      .map(value => {
        value.state is ("command-ready" | "runtime-pending" | "needs-review")
      })
      .unwrap_or(false),
    ),
    (
      "05",
      "Execute in MoonClaw",
      model.research_execution
      .map(value => value.state is ("runtime-pending" | "needs-review"))
      .unwrap_or(false),
    ),
    (
      "06",
      "Prepare named review",
      review_state is ("awaiting-moonchat" | "ready-for-bookkeeper"),
    ),
    ("07", "Return to Bookkeeper", review_state == "ready-for-bookkeeper"),
    ("08", "Retain cited Q&A", model.qa_ready),
  ]
  let rows : Array[@rabbita.Html] = []
  for step in steps {
    let (number, title, done) = step
    rows.push(
      li(class=if done { "contract-step done" } else { "contract-step" }, [
        span(class="contract-number", number),
        span(title),
        small(if done { "Done" } else { "Pending" }),
      ]),
    )
  }
  details(class="contract-details", [
    summary([research_icon("series"), span("Detailed 8-stage contract")]),
    ul(class="contract-steps", rows),
  ])
}
