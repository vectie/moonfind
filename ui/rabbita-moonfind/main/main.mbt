///|
using @html {
  article,
  aside,
  button,
  code,
  div,
  h1,
  h2,
  h3,
  header,
  li,
  main_,
  p,
  section,
  small,
  span,
  ul,
}

///|
struct Paper {
  paper_id : String
  title : String
  authors : Array[String]
  categories : Array[String]
  published_at : String
  relevance_score : Int
  relevance_reasons : Array[String]
} derive(Debug, FromJson)

///|
struct Summary {
  paper_id : String
  one_sentence : String
  problem : String
  method : String
  evidence : String
  limitations : Array[String]
  open_questions : Array[String]
} derive(Debug, FromJson)

///|
struct Question {
  question_id : String
  question : String
  source_paper_ids : Array[String]
  missing_evidence : Array[String]
  next_check : String
} derive(Debug, FromJson)

///|
struct Idea {
  idea_id : String
  title : String
  thesis : String
  mechanism : String
  source_paper_ids : Array[String]
  cross_paper_bridge : String
  novelty_claim : String
  counter_hypothesis : String
  risks : Array[String]
  falsifier : String
  next_experiment : String
  domain_payload : Json
} derive(Debug, FromJson)

///|
struct Workspace {
  product_id : String
  title : String
  run_id : String
  status : String
  watch_title : String
  query : String
  paper_count : Int
  summary_count : Int
  idea_count : Int
  question_count : Int
  accepted_idea_count : Int
  pipeline : Array[String]
  active_stage : String
  papers : Array[Paper]
  summaries : Array[Summary]
  ideas : Array[Idea]
  questions : Array[Question]
  validation_issues : Array[String]
  bookkeeper_route : String
  three_gap_state : String
} derive(Debug, FromJson)

///|
struct Model {
  workspace : Workspace
  selected_idea : Int
  loading : Bool
  error : String?
}

///|
enum Msg {
  Loaded(Result[Workspace, Error])
  SelectIdea(Int)
  Refresh
}

///|
fn demo_workspace() -> Workspace {
  {
    product_id: "moonfind",
    title: "Moonfind Research Studio",
    run_id: "humanoid-cross-paper-demo",
    status: "accepted",
    watch_title: "Humanoid Robotics Model Research",
    query: "arXiv · humanoid + whole-body + vision-language-action",
    paper_count: 3,
    summary_count: 3,
    idea_count: 1,
    question_count: 2,
    accepted_idea_count: 1,
    pipeline: [
      "arXiv intake", "paper normalization", "MoonClaw analysis", "Moontown cross-paper salon",
      "named human review", "Bookkeeper Three-Gap learning",
    ],
    active_stage: "Bookkeeper outcome learning",
    papers: [
      {
        paper_id: "2607.00001",
        title: "Contact-Aware Whole-Body Policies for Humanoid Manipulation",
        authors: ["Lin Robot"],
        categories: ["cs.RO"],
        published_at: "2026-07-10",
        relevance_score: 63,
        relevance_reasons: ["humanoid", "whole-body", "contact"],
      },
      {
        paper_id: "2607.00002",
        title: "Memory World Models for Long-Horizon Humanoid Control",
        authors: ["Mira Control"],
        categories: ["cs.RO", "cs.LG"],
        published_at: "2026-07-11",
        relevance_score: 72,
        relevance_reasons: ["humanoid", "world model", "locomotion"],
      },
      {
        paper_id: "2607.00003",
        title: "Vision-Language-Action Transfer with Teleoperated Robot Data",
        authors: ["Ada Motion"],
        categories: ["cs.RO", "cs.AI"],
        published_at: "2026-07-12",
        relevance_score: 61,
        relevance_reasons: ["vision-language-action", "teleoperation"],
      },
    ],
    summaries: [],
    ideas: [
      {
        idea_id: "idea-contact-memory-vla",
        title: "Contact-memory VLA",
        thesis: "Preserve semantic task intent while recurrent contact memory stabilizes whole-body action chunks.",
        mechanism: "A frozen VLA planner emits subgoals; a recurrent world-state module compresses contact history; a whole-body decoder emits bounded action chunks.",
        source_paper_ids: ["2607.00001", "2607.00002", "2607.00003"],
        cross_paper_bridge: "Contact-aware control × recurrent world memory × cross-robot VLA transfer.",
        novelty_claim: "A proposed bridge, not a claimed experimental result.",
        counter_hypothesis: "A memoryless decoder performs equally well with less optimization complexity.",
        risks: [
          "infeasible semantic subgoals", "simulator contact overfit", "morphology mismatch",
        ],
        falsifier: "Reject if completion improves by less than 8 percentage points over matched-compute memoryless control.",
        next_experiment: "Three-task simulation benchmark with matched seeds, compute, and contact perturbations.",
        domain_payload: { "model_name": "LunaContact-VLA-1" },
      },
    ],
    questions: [
      {
        question_id: "q-memory-contact",
        question: "Does contact-history memory improve multi-stage mobile manipulation?",
        source_paper_ids: ["2607.00001", "2607.00002"],
        missing_evidence: ["matched-seed ablation", "hardware disturbances"],
        next_check: "Run controlled simulation ablation.",
      },
      {
        question_id: "q-vla-adapter",
        question: "Can semantic VLA plans become contact-safe whole-body chunks?",
        source_paper_ids: ["2607.00001", "2607.00003"],
        missing_evidence: ["common action ontology"],
        next_check: "Train a frozen-VLA adapter.",
      },
    ],
    validation_issues: [],
    bookkeeper_route: "moonbook.bookkeeper",
    three_gap_state: "ready-for-outcome-binding",
  }
}

///|
fn surface() -> Array[String] {
  [
    "background:#111a2c", "border:1px solid #263654", "border-radius:18px", "box-shadow:0 18px 50px rgba(0,0,0,.18)",
  ]
}

///|
fn label(text : String) -> @rabbita.Html {
  small(
    style=[
      "color:#82a2cd", "font-size:11px", "font-weight:800", "letter-spacing:.09em",
      "text-transform:uppercase",
    ],
    text,
  )
}

///|
fn metric(value : Int, name : String) -> @rabbita.Html {
  div(style=surface() + ["padding:14px 16px", "min-width:110px"], [
    div(style=["font-size:26px", "font-weight:780"], value.to_string()),
    label(name),
  ])
}

///|
fn paper_list(workspace : Workspace) -> @rabbita.Html {
  let items : Array[@rabbita.Html] = []
  for paper in workspace.papers {
    items.push(
      article(style=surface() + ["padding:16px", "display:grid", "gap:8px"], [
        div(
          style=["display:flex", "justify-content:space-between", "gap:12px"],
          [
            code(style=["color:#72d8c7"], paper.paper_id),
            span(
              style=["color:#f5c96a", "font-weight:800"],
              paper.relevance_score.to_string(),
            ),
          ],
        ),
        h3(
          style=["margin:0", "font-size:15px", "line-height:1.35"],
          paper.title,
        ),
        small(
          style=["color:#8fa5c3"],
          paper.categories.join(" · ") + " · " + paper.authors.join(", "),
        ),
      ]),
    )
  }
  div(style=["display:grid", "gap:10px"], items)
}

///|
fn idea_selector(emit : @rabbita.Emit[Msg], model : Model) -> @rabbita.Html {
  let buttons : Array[@rabbita.Html] = []
  for index, idea in model.workspace.ideas {
    let selected = index == model.selected_idea
    buttons.push(
      button(
        on_click=emit(SelectIdea(index)),
        style=[
          "text-align:left",
          "padding:14px",
          "border-radius:14px",
          "cursor:pointer",
          if selected {
            "background:#254a63"
          } else {
            "background:#16243a"
          },
          if selected {
            "border:1px solid #69d5c4"
          } else {
            "border:1px solid #2a3c5d"
          },
          "color:#edf6ff",
        ],
        [
          label("MODEL IDEA " + (index + 1).to_string()),
          div(style=["font-weight:780", "margin-top:6px"], idea.title),
          small(
            style=["color:#91a7c6"],
            idea.source_paper_ids.length().to_string() + " papers bridged",
          ),
        ],
      ),
    )
  }
  div(style=["display:grid", "gap:10px"], buttons)
}

///|
fn idea_detail(model : Model) -> @rabbita.Html {
  guard model.workspace.ideas.get(model.selected_idea) is Some(idea) else {
    return div(
      style=surface() + ["padding:24px"],
      "No synthesis idea selected.",
    )
  }
  article(style=surface() + ["padding:22px", "display:grid", "gap:18px"], [
    div([
      label("FALSIFIABLE MODEL PROPOSAL"),
      h2(style=["margin:6px 0 8px", "font-size:25px"], idea.title),
      p(style=["color:#c8d5e8", "line-height:1.6", "margin:0"], idea.thesis),
    ]),
    div(style=["border-left:3px solid #65d4c3", "padding-left:15px"], [
      label("CROSS-PAPER BRIDGE"),
      p(style=["margin:6px 0 0", "line-height:1.55"], idea.cross_paper_bridge),
      code(style=["color:#7fdccc"], idea.source_paper_ids.join("  ×  ")),
    ]),
    div(
      style=[
        "display:grid", "grid-template-columns:repeat(auto-fit,minmax(230px,1fr))",
        "gap:12px",
      ],
      [
        div(
          style=["background:#0b1424", "padding:14px", "border-radius:12px"],
          [label("MECHANISM"), p(style=["line-height:1.5"], idea.mechanism)],
        ),
        div(
          style=["background:#251b22", "padding:14px", "border-radius:12px"],
          [
            label("COUNTER-HYPOTHESIS"),
            p(style=["line-height:1.5"], idea.counter_hypothesis),
          ],
        ),
      ],
    ),
    div(
      style=[
        "background:#182317", "padding:15px", "border:1px solid #355f39", "border-radius:12px",
      ],
      [
        label("FALSIFIER"),
        p(style=["margin:6px 0 0", "line-height:1.55"], idea.falsifier),
      ],
    ),
    div(style=["background:#202036", "padding:15px", "border-radius:12px"], [
      label("NEXT EXPERIMENT"),
      p(style=["margin:6px 0 0", "line-height:1.55"], idea.next_experiment),
    ]),
  ])
}

///|
fn questions(workspace : Workspace) -> @rabbita.Html {
  let rows : Array[@rabbita.Html] = []
  for question in workspace.questions {
    rows.push(
      article(style=["border-top:1px solid #293a57", "padding:14px 0"], [
        p(style=["margin:0 0 6px", "font-weight:700"], question.question),
        small(
          style=["color:#8ea5c5"],
          question.source_paper_ids.join(" + ") +
          " · next: " +
          question.next_check,
        ),
      ]),
    )
  }
  section(style=surface() + ["padding:18px"], [
    label("OPEN QUESTIONS & MISSING EVIDENCE"),
    div(rows),
  ])
}

///|
fn pipeline(workspace : Workspace) -> @rabbita.Html {
  let stages : Array[@rabbita.Html] = []
  for index, stage in workspace.pipeline {
    stages.push(
      li(
        style=[
          "display:flex", "gap:10px", "align-items:flex-start", "padding:7px 0",
        ],
        [
          span(
            style=["color:#67d5c4", "font-family:monospace"],
            "0" + (index + 1).to_string(),
          ),
          span(
            style=[
              if stage == workspace.active_stage {
                "color:#fff"
              } else {
                "color:#9caec8"
              },
            ],
            stage,
          ),
        ],
      ),
    )
  }
  ul(style=["list-style:none", "padding:0", "margin:8px 0 0"], stages)
}

///|
fn view(emit : @rabbita.Emit[Msg], model : Model) -> @rabbita.Html {
  let workspace = model.workspace
  main_(
    style=[
      "min-height:100vh", "background:#07101f", "color:#edf5ff", "font-family:Inter,'Avenir Next',system-ui,sans-serif",
      "padding:clamp(14px,3vw,34px)", "box-sizing:border-box",
    ],
    [
      div(
        style=["max-width:1500px", "margin:0 auto", "display:grid", "gap:18px"],
        [
          header(
            style=surface() +
              [
                "padding:22px", "display:flex", "justify-content:space-between",
                "gap:18px", "flex-wrap:wrap",
              ],
            [
              div([
                label("MOONSUITE / AUTOResearch"),
                h1(
                  style=["margin:5px 0 4px", "font-size:clamp(26px,4vw,42px)"],
                  "Moonfind · Humanoid Model Lab",
                ),
                p(
                  style=["margin:0", "color:#9cb0cd", "max-width:75ch"],
                  "From arXiv evidence to cross-paper hypotheses, falsifiable model specifications, and governed learning.",
                ),
              ]),
              div(
                style=[
                  "display:flex", "gap:10px", "align-items:flex-start", "flex-wrap:wrap",
                ],
                [
                  metric(workspace.paper_count, "papers"),
                  metric(workspace.idea_count, "ideas"),
                  metric(workspace.question_count, "gaps"),
                  button(
                    on_click=emit(Refresh),
                    style=[
                      "padding:14px", "background:#67d5c4", "color:#07101f", "border:0",
                      "border-radius:12px", "font-weight:800", "cursor:pointer",
                    ],
                    "Refresh run",
                  ),
                ],
              ),
            ],
          ),
          div(
            style=[
              "display:grid", "grid-template-columns:minmax(250px,0.72fr) minmax(0,2fr) minmax(260px,.8fr)",
              "gap:18px", "align-items:start",
            ],
            [
              aside(style=["display:grid", "gap:14px"], [
                section(style=surface() + ["padding:18px"], [
                  label("RESEARCH WATCH"),
                  h2(
                    style=["font-size:17px", "margin:7px 0"],
                    workspace.watch_title,
                  ),
                  code(
                    style=[
                      "font-size:11px", "color:#8ea5c5", "overflow-wrap:anywhere",
                    ],
                    workspace.query,
                  ),
                ]),
                section(style=surface() + ["padding:18px"], [
                  label("PIPELINE"),
                  pipeline(workspace),
                ]),
                div([label("SELECTED PAPERS"), paper_list(workspace)]),
              ]),
              div(style=["display:grid", "gap:14px", "min-width:0"], [
                idea_detail(model),
                questions(workspace),
              ]),
              aside(style=["display:grid", "gap:14px"], [
                section(style=surface() + ["padding:18px"], [
                  label("MOONTOWN SYNTHESIS"),
                  idea_selector(emit, model),
                ]),
                section(
                  style=surface() + ["padding:18px", "display:grid", "gap:10px"],
                  [
                    label("CLOSED LOOP"),
                    h3(style=["margin:0"], "Named human → Bookkeeper"),
                    p(
                      style=["margin:0", "color:#aebfd5", "line-height:1.5"],
                      "Accepted outcomes enter MoonBook as evidence. Three-Gap analysis may propose a capability change; it cannot apply one.",
                    ),
                    code(style=["color:#69d5c4"], workspace.three_gap_state),
                    small(
                      style=["color:#8498b7"],
                      "route · " + workspace.bookkeeper_route,
                    ),
                  ],
                ),
                match model.error {
                  Some(error) =>
                    p(style=["color:#ffb4b4"], "Using demo snapshot: " + error)
                  None =>
                    small(
                      style=["color:#7890b1"],
                      if model.loading {
                        "Loading durable run…"
                      } else {
                        "Durable run loaded"
                      },
                    )
                },
              ]),
            ],
          ),
        ],
      ),
    ],
  )
}

///|
fn load(emit : @rabbita.Emit[Msg]) -> @rabbita.Cmd {
  @http.get("./moonfind-workspace.json").expect_json(
    emit.map(result => Loaded(result)),
  )
}

///|
fn update(
  emit : @rabbita.Emit[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    Loaded(Ok(workspace)) =>
      (
        @rabbita.none,
        { workspace, selected_idea: 0, loading: false, error: None },
      )
    Loaded(Err(error)) =>
      (@rabbita.none, { ..model, loading: false, error: Some("\{error}") })
    SelectIdea(index) => (@rabbita.none, { ..model, selected_idea: index })
    Refresh => (load(emit), { ..model, loading: true, error: None })
  }
}

///|
fn main {
  let (emit, cell) = @rabbita.cell_with_emit(
    model={
      workspace: demo_workspace(),
      selected_idea: 0,
      loading: true,
      error: None,
    },
    update~,
    view~,
  )
  @rabbita.new(cell)..with_init(load(emit)).mount("app")
}
