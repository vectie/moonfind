///|
struct ReviewDecisionReceipt {
  review_id : String
  reviewer_id : String
  reviewer_name : String
  outcome : String
  rationale : String
  accepted_idea_ids : Array[String]
  rejected_idea_ids : Array[String]
  objections : Array[String]
  source_ref : String
  source_digest : String
  source_revision_id : String
  source_current : Bool
  review_status : String
  delivery_status : String
  evidence_status : String
  record_ref : String?
  record_digest : String?
  bookkeeper_state : String
  detail : String
} derive(Debug, FromJson)

///|
fn retained_review_panel(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  guard model.review_workflow.bind(value => value.decision_receipt)
    is Some(receipt) else {
    return @html.nothing
  }
  let current = receipt.source_current &&
    model.moontown_result.bind(result => result.source_digest) ==
    Some(receipt.source_digest) &&
    model.moontown_result.bind(result => result.source_ref) ==
    Some(receipt.source_ref) &&
    model.workspace.map(workspace => "moontown-" + workspace.run_id) ==
    Some(receipt.source_revision_id)
  let outcome_label = match receipt.outcome {
    "approve" => "Approved subset"
    "reject" => "Rejected version"
    _ => "Deferred / unresolved"
  }
  section(
    id="retained-review",
    attrs=@html.Attrs::build().aria_label("Retained decision and objections"),
    style=surface() + ["padding:16px", "display:grid", "gap:9px"],
    [
      h3("Saved decision · " + outcome_label),
      p(
        "Named reviewer: " +
        receipt.reviewer_name +
        " · " +
        receipt.reviewer_id,
      ),
      p(
        attrs=@html.Attrs::build()
          .role(if current { "status" } else { "alert" })
          .aria_live(if current { "polite" } else { "assertive" }),
        if current {
          receipt.detail
        } else {
          "Stale review: these saved reasons concern another source version. They cannot approve the currently displayed result. Restore the original or create a new research revision."
        },
      ),
      strong("Retained rationale"),
      p(style=["white-space:pre-wrap"], receipt.rationale),
      strong("Retained objections and dissent"),
      ul(
        receipt.objections.map(objection => {
          li(style=["white-space:pre-wrap"], objection)
        }),
      ),
      p(
        "Approved synthesis IDs: " +
        (if receipt.accepted_idea_ids.is_empty() {
          "none"
        } else {
          receipt.accepted_idea_ids.join(", ")
        }),
      ),
      p(
        (if receipt.outcome == "defer" {
          "Changes requested / not approved IDs: "
        } else {
          "Rejected synthesis IDs: "
        }) +
        (if receipt.rejected_idea_ids.is_empty() {
          "none"
        } else {
          receipt.rejected_idea_ids.join(", ")
        }),
      ),
      p(
        "Review projection: " +
        receipt.review_status +
        " · Receipt return: " +
        receipt.delivery_status,
      ),
      p(
        "MoonBook receiver: " +
        receipt.bookkeeper_state +
        ". Review approval, prepared submission, and MoonBook acceptance are separate.",
      ),
      details([
        summary("Exact review evidence"),
        p("Review: " + receipt.review_id + " · " + receipt.evidence_status),
        p("Source version: " + receipt.source_revision_id),
        code(style=["overflow-wrap:anywhere"], receipt.source_ref),
        p(style=["overflow-wrap:anywhere"], receipt.source_digest),
        p(
          style=["overflow-wrap:anywhere"],
          receipt.record_ref.unwrap_or("Return record pending"),
        ),
        p(
          style=["overflow-wrap:anywhere"],
          receipt.record_digest.unwrap_or("Return digest pending"),
        ),
      ]),
      button(
        type_="button",
        on_click=emit(RefreshMoonTownStatus),
        "Refresh retained decision",
      ),
    ],
  )
}
