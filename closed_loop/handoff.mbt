///|
pub(all) struct VersionedRecordRef {
  record_id : String
  record_version : String
  record_digest : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct VersionedEvidenceRef {
  reference_id : String
  reference_version : String
  digest : String
  provenance_ref : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct BookkeeperDeliverableCandidate {
  contract_version : String
  record : VersionedRecordRef
  stage : String
  subject : VersionedRecordRef?
  links : Array[VersionedRecordRef]
  title : String
  summary : String
  owner_route : String
  status : String
  evidence_refs : Array[VersionedEvidenceRef]
  issue_refs : Array[String]
  requires_human_review : Bool
  next_action : String
  source_product : String
  recorded_at : Int
  payload : Json
  side_effects_applied : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct CapabilityObservation {
  observation_id : String
  scope_id : String
  participant_id : String
  assignment : String
  capability : VersionedRecordRef
  outcome : VersionedRecordRef
  reward_evidence : VersionedRecordRef
  accepted : Bool
  recorded_at : Int64
} derive(Debug, Eq, ToJson, FromJson)

///|
fn record_ref(id : String, digest : String) -> VersionedRecordRef {
  { record_id: id, record_version: "1", record_digest: digest }
}

///|
fn digest_json(value : Json) -> String {
  let bytes = @crypto.sha256(@utf8.encode(value.stringify()))
  let builder = StringBuilder::new()
  for byte in bytes {
    let number = byte.to_int()
    let high = number / 16
    let low = number % 16
    builder.write_char(
      if high < 10 {
        (high + 48).unsafe_to_char()
      } else {
        (high + 87).unsafe_to_char()
      },
    )
    builder.write_char(
      if low < 10 {
        (low + 48).unsafe_to_char()
      } else {
        (low + 87).unsafe_to_char()
      },
    )
  }
  "sha256:" + builder.to_string()
}

///|
fn accepted_ids(
  run : @research.ResearchRun,
  review : @research.HumanResearchReview,
) -> Array[String] raise {
  guard run.run_id == review.run_id && review.disposition == "accept" else {
    fail("closed-loop handoff requires an accepted matching review")
  }
  guard !review.accepted_idea_ids.is_empty() else {
    fail("closed-loop handoff requires at least one accepted idea")
  }
  review.accepted_idea_ids.copy()
}

///|
pub fn bookkeeper_deliverable_candidate(
  run : @research.ResearchRun,
  review : @research.HumanResearchReview,
  run_digest : String,
  review_digest : String,
) -> BookkeeperDeliverableCandidate raise {
  let ideas = accepted_ids(run, review)
  guard run.status == "accepted" &&
    !run_digest.is_blank() &&
    !review_digest.is_blank() else {
    fail("only a durable accepted research run can enter Bookkeeper")
  }
  let payload : Json = {
    "contract_version": "moonbook.bookkeeper.v1",
    "candidate_schema": "moonfind.research-deliverable.v1",
    "run_id": run.run_id,
    "watch_id": run.watch.watch_id,
    "accepted_idea_ids": ideas,
    "paper_count": run.papers.length(),
    "question_count": run.questions.length(),
    "human_review_id": review.review_id,
    "learning_scope": "moonfind.humanoid.synthesis",
    "three_gap_required_after_outcome": true,
  }
  {
    contract_version: "moonbook.bookkeeper.store.v1",
    record: record_ref(
      "moonfind-deliverable-" + run.run_id,
      digest_json(payload),
    ),
    stage: "DeliverableAcceptance",
    subject: None,
    links: [],
    title: "Moonfind reviewed research deliverable",
    summary: "Human review accepted " +
    ideas.length().to_string() +
    " cross-paper humanoid model idea(s).",
    owner_route: "moonfind.humanoid-models",
    status: "candidate",
    evidence_refs: [
      {
        reference_id: "moonfind-run-" + run.run_id,
        reference_version: "1",
        digest: run_digest,
        provenance_ref: ".moonsuite/products/moonfind/runs/" +
        run.run_id +
        "/run.json",
      },
      {
        reference_id: review.review_id,
        reference_version: "1",
        digest: review_digest,
        provenance_ref: ".moonsuite/products/moonfind/runs/" +
        run.run_id +
        "/human-review.json",
      },
    ],
    issue_refs: [],
    requires_human_review: true,
    next_action: "MoonBook records and reviews this deliverable; outcome binding and Three-Gap analysis follow only after acceptance and observed results.",
    source_product: "moonfind",
    recorded_at: review.reviewed_at.to_int(),
    payload,
    side_effects_applied: false,
  }
}

///|
pub fn capability_observation(
  run : @research.ResearchRun,
  review : @research.HumanResearchReview,
  participant_id : String,
  assignment : String,
  capability : VersionedRecordRef,
  run_digest : String,
  review_digest : String,
) -> CapabilityObservation raise {
  let _ = accepted_ids(run, review)
  guard run.status == "accepted" &&
    !participant_id.is_blank() &&
    (assignment == "baseline" || assignment == "challenger") &&
    !capability.record_id.is_blank() &&
    !run_digest.is_blank() &&
    !review_digest.is_blank() else {
    fail("invalid capability observation inputs")
  }
  {
    observation_id: "moonfind-observation-" + run.run_id,
    scope_id: "moonfind.humanoid.synthesis",
    participant_id,
    assignment,
    capability,
    outcome: record_ref("moonfind-run-" + run.run_id, run_digest),
    reward_evidence: record_ref(
      "moonfind-review-" + review.review_id,
      review_digest,
    ),
    accepted: true,
    recorded_at: review.reviewed_at,
  }
}
