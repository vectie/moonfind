///|
struct SynthesisIdea {
  id : String
  title : String
  summary : String
  participating_books : Array[String]
  research_questions : Array[String]
  why_it_matters : String
  next_experiment : String
} derive(Debug, FromJson)

///|
struct SynthesisOutput {
  contract_id : String
  scenario_id : String
  participant_book_ids : Array[String]
  ideas : Array[SynthesisIdea]
} derive(Debug, FromJson)

///|
struct CompletedResult {
  contract_id : String
  run_id : String
  state : String
  detail : String
  source_ref : String?
  source_digest : String?
  output : SynthesisOutput?
} derive(Debug, FromJson)

///|
fn current_synthesis(model : Model) -> SynthesisOutput? {
  guard model.moontown_result is Some(result) &&
    result.contract_id == "moonfind.moontown-result-view.v1" &&
    result.state == "available" &&
    model.workspace.map(workspace => workspace.run_id) == Some(result.run_id) &&
    result.source_digest.map(value => !value.is_blank()).unwrap_or(false) &&
    result.source_ref.map(value => !value.is_blank()).unwrap_or(false) &&
    result.output is Some(output) &&
    output.contract_id == "civic.communication.output.v1" &&
    output.scenario_id == "moonfind-" + result.run_id &&
    !output.ideas.is_empty() else {
    return None
  }
  Some(output)
}

///|
fn review_result_context(model : Model) -> String {
  [
    model.trusted_book_dir,
    model.workspace.map(ws => ws.run_id).unwrap_or(""),
    model.moontown_result.bind(result => result.source_digest).unwrap_or(""),
  ]
  .to_json()
  .stringify()
}

///|
struct ReviewDraft {
  outcome : String
  scope : String
  message : String
  information_severity : Int
  information_summary : String
  recognition_severity : Int
  recognition_summary : String
  decisiveness_severity : Int
  decisiveness_summary : String
} derive(ToJson, FromJson)

///|
extend ReviewDraft with ToJson::{to_json}

///|
fn review_draft(model : Model) -> ReviewDraft {
  {
    outcome: model.review_outcome,
    scope: model.review_scope,
    message: model.review_message,
    information_severity: model.information_gap_severity,
    information_summary: model.information_gap_summary,
    recognition_severity: model.recognition_gap_severity,
    recognition_summary: model.recognition_gap_summary,
    decisiveness_severity: model.decisiveness_gap_severity,
    decisiveness_summary: model.decisiveness_gap_summary,
  }
}

///|
fn apply_review_draft(model : Model, draft : ReviewDraft) -> Model {
  {
    ..model,
    review_outcome: draft.outcome,
    review_scope: draft.scope,
    review_message: draft.message,
    information_gap_severity: draft.information_severity,
    information_gap_summary: draft.information_summary,
    recognition_gap_severity: draft.recognition_severity,
    recognition_gap_summary: draft.recognition_summary,
    decisiveness_gap_severity: draft.decisiveness_severity,
    decisiveness_gap_summary: draft.decisiveness_summary,
  }
}

///|
fn adopt_review_context(model : Model, snapshot : WorkspaceSnapshot) -> Model {
  let next = {
    ..model,
    workspace: Some(snapshot.workspace),
    trusted_book_dir: snapshot.book_workspace,
    moontown_result: snapshot.moontown_result,
  }
  if review_result_context(next) == review_result_context(model) {
    return next
  }
  if model.workspace is None && current_synthesis(next) is None {
    return next
  }
  let drafts = model.review_drafts.copy()
  if model.workspace is Some(_) {
    drafts[review_result_context(model)] = review_draft(model)
  }
  let restored = drafts.get(review_result_context(next))
  let draft = restored.unwrap_or({
    outcome: "",
    scope: "",
    message: "",
    information_severity: 1,
    information_summary: "Record what evidence was missing before the synthesis decision.",
    recognition_severity: 0,
    recognition_summary: "The named reviewer recognized the material evidence boundary.",
    decisiveness_severity: 1,
    decisiveness_summary: "Record what reviewed rule or experiment is still required before action.",
  })
  let adopted = apply_review_draft(
    {
      ..next,
      review_drafts: drafts,
      review_prepare_reply: None,
      review_pending_context: None,
      result_page: 0,
      review_context_notice: Some(
        if restored is Some(_) {
          "Restored your draft for this exact run and synthesis. Restoring a draft does not submit it."
        } else {
          "The run or synthesis changed. Drafts remain separate for each exact result; check the browser save status below. This result never inherits another result's decision."
        },
      ),
    },
    draft,
  )
  restore_review_storage(adopted, restored)
}

///|
fn result_review_issues(model : Model) -> Array[String] {
  if model.trusted_book_dir.is_blank() {
    return [
      "Reload a trusted Book workspace before saving or preparing this review.",
    ]
  }
  guard current_synthesis(model) is Some(output) else {
    return [
      "Reload a readable, correlated MoonTown synthesis before preparing its review.",
    ]
  }
  review_scope_ids(model.review_scope)
  .filter(id => !output.ideas.any(idea => idea.id == id))
  .map(id => "This is not an exact ID in the displayed synthesis: " + id)
}

///|
fn toggle_result_idea(model : Model, context : String, id : String) -> Model {
  guard !model.trusted_book_dir.is_blank() &&
    context == review_result_context(model) &&
    model.review_phase != ReviewPreparing &&
    model.review_workflow
    .map(value => value.state == "ready-for-human-review")
    .unwrap_or(false) &&
    current_synthesis(model) is Some(output) &&
    output.ideas.any(idea => idea.id == id) &&
    safe_review_scope_id(id) else {
    return model
  }
  let ids = review_scope_ids(model.review_scope)
  let next = if ids.contains(id) {
    ids.filter(value => value != id)
  } else {
    ids + [id]
  }
  { ..model, review_scope: next.join(", "), }
}

///|
fn result_page_ideas(
  model : Model,
  output : SynthesisOutput,
) -> Array[SynthesisIdea] {
  let last_page = (output.ideas.length() - 1).max(0) / 10
  let start = model.result_page.clamp(min=0, max=last_page) * 10
  output.ideas[start:(start + 10).min(output.ideas.length())].to_owned()
}

///|
fn completed_result_panel(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  div(
    class="completed-synthesis",
    attrs=@html.Attrs::build().data_set("testid", "completed-synthesis"),
    [
      h3("Completed MoonTown synthesis"),
      p(
        "These are the returned synthesis ideas used by the review host. Analysis candidates appear separately. Selecting an ID only edits the decision scope; it does not approve or submit anything.",
      ),
      match current_synthesis(model) {
        None =>
          div(class="evidence-boundary", [
            strong("Completed result unavailable"),
            p(
              model.moontown_result
              .map(result => result.detail)
              .unwrap_or(
                "The host has not published a readable completed result. Reload to check the correlated artifacts.",
              ),
            ),
            button(
              class="research-next",
              on_click=emit(RefreshMoonTownStatus),
              "Reload result",
            ),
          ])
        Some(output) => {
          let selected = review_scope_ids(model.review_scope)
          let page = model.result_page.clamp(
            min=0,
            max=(output.ideas.length() - 1) / 10,
          )
          let editable = !model.trusted_book_dir.is_blank() &&
            model.review_phase != ReviewPreparing &&
            model.review_workflow
            .map(value => value.state == "ready-for-human-review")
            .unwrap_or(false)
          div([
            p(
              "\{output.ideas.length()} synthesis ideas · \{selected.length()} selected in decision scope",
            ),
            div(
              result_page_ideas(model, output).map(idea => {
                details(class="evidence-record", [
                  summary([code(idea.id), strong(idea.title)]),
                  div(class="evidence-record-body", [
                    evidence_fact("Exact synthesis ID", idea.id),
                    p(idea.summary),
                    evidence_fact(
                      "Participating Books",
                      idea.participating_books.join(", "),
                    ),
                    strong("Research questions"),
                    ul(idea.research_questions.map(question => li(question))),
                    evidence_fact("Why it matters", idea.why_it_matters),
                    evidence_fact("Next experiment", idea.next_experiment),
                    button(
                      class="research-next",
                      disabled=!editable || !safe_review_scope_id(idea.id),
                      on_click=emit(
                        ToggleResultIdea(review_result_context(model), idea.id),
                      ),
                      attrs=@html.Attrs::build().aria_label(
                        (if selected.contains(idea.id) {
                          "Remove "
                        } else {
                          "Select "
                        }) +
                        idea.id +
                        " in decision scope",
                      ),
                      if selected.contains(idea.id) {
                        "Remove from decision scope"
                      } else {
                        "Select for decision scope"
                      },
                    ),
                    if !safe_review_scope_id(idea.id) {
                      small(
                        "The existing review contract does not accept this ID format. The result remains readable.",
                      )
                    } else {
                      @html.nothing
                    },
                  ]),
                ])
              }),
            ),
            if output.ideas.length() > 10 {
              div(class="synthesis-pagination", [
                button(
                  class="research-next",
                  disabled=page == 0,
                  on_click=emit(SetResultPage(page - 1)),
                  "Previous ideas",
                ),
                span("Page \{page + 1} of \{(output.ideas.length() + 9) / 10}"),
                button(
                  class="research-next",
                  disabled=(page + 1) * 10 >= output.ideas.length(),
                  on_click=emit(SetResultPage(page + 1)),
                  "Next ideas",
                ),
              ])
            } else {
              @html.nothing
            },
            details(class="evidence-record", [
              summary("Result provenance"),
              div(class="evidence-record-body", [
                evidence_fact(
                  "Run",
                  model.workspace.map(ws => ws.run_id).unwrap_or(""),
                ),
                evidence_fact("Scenario", output.scenario_id),
                evidence_fact(
                  "Artifact",
                  model.moontown_result
                  .bind(result => result.source_ref)
                  .unwrap_or(""),
                ),
                evidence_fact(
                  "Exact byte digest",
                  model.moontown_result
                  .bind(result => result.source_digest)
                  .unwrap_or(""),
                ),
                p(
                  "Artifact correlation is verified. Scientific validity and acceptance still require a named-human decision.",
                ),
              ]),
            ]),
          ])
        }
      },
    ],
  )
}
