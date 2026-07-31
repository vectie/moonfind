///|
/// Human input captured by the MoonFind review screen. The decision is not
/// applied directly: it first becomes a portable MoonChat review bundle.
pub(all) struct CrossProductReviewDecision {
  review_id : String
  reviewer_id : String
  reviewer_name : String
  outcome : String
  accepted_idea_ids : Array[String]
  rejected_idea_ids : Array[String]
  rationale : String
  reviewed_at_utc : String
  reviewed_at_epoch : Int64
  information_gap_present : Bool
  information_gap_severity : Int
  information_gap_summary : String
  recognition_gap_present : Bool
  recognition_gap_severity : Int
  recognition_gap_summary : String
  decisiveness_gap_present : Bool
  decisiveness_gap_severity : Int
  decisiveness_gap_summary : String
} derive(Debug, Eq, ToJson, FromJson)

///|
fn review_safe_id(value : String) -> Bool {
  if value.is_blank() || value == "." || value == ".." {
    return false
  }
  value.all(fn(ch) {
    (ch >= 'a' && ch <= 'z') ||
    (ch >= 'A' && ch <= 'Z') ||
    (ch >= '0' && ch <= '9') ||
    ch == '-' ||
    ch == '_' ||
    ch == '.'
  })
}

///|
fn canonical_utc_timestamp(value : String) -> Bool {
  value.length() == 20 &&
  value[4] == '-' &&
  value[7] == '-' &&
  value[10] == 'T' &&
  value[13] == ':' &&
  value[16] == ':' &&
  value[19] == 'Z'
}

///|
fn validate_gap(
  present : Bool,
  severity : Int,
  summary : String,
  label : String,
) -> Unit raise {
  if summary.is_blank() {
    fail("\{label} summary is required")
  }
  if (present && (severity < 1 || severity > 5)) ||
    (!present && severity != 0) {
    fail("\{label} severity must be 1..5 when present and zero otherwise")
  }
}

///|
fn validate_review_decision(
  run : @research.ResearchRun,
  output : @moontown.TownSynthesisOutput,
  decision : CrossProductReviewDecision,
) -> Unit raise {
  if run.status != "human-review" ||
    output.scenario_id != "moonfind-\{run.run_id}" {
    fail("review input does not match a review-ready MoonFind run")
  }
  if !review_safe_id(decision.review_id) ||
    !review_safe_id(decision.reviewer_id) ||
    decision.reviewer_name.is_blank() ||
    decision.rationale.is_blank() ||
    !canonical_utc_timestamp(decision.reviewed_at_utc) ||
    decision.reviewed_at_epoch < run.started_at {
    fail("named-human review identity, rationale, or timestamp is invalid")
  }
  if !["approve", "defer", "reject"].contains(decision.outcome) {
    fail("review outcome must be approve, defer, or reject")
  }
  let known = output.ideas.map(idea => idea.id)
  if decision.accepted_idea_ids.any(id => {
      id.is_blank() || !known.contains(id)
    }) ||
    decision.rejected_idea_ids.any(id => {
      id.is_blank() || !known.contains(id)
    }) ||
    decision.accepted_idea_ids.any(id => {
      decision.rejected_idea_ids.contains(id)
    }) {
    fail("review decision contains unknown or conflicting idea ids")
  }
  if decision.outcome == "approve" && decision.accepted_idea_ids.is_empty() {
    fail("an approval must name at least one accepted idea")
  }
  validate_gap(
    decision.information_gap_present,
    decision.information_gap_severity,
    decision.information_gap_summary,
    "information gap",
  )
  validate_gap(
    decision.recognition_gap_present,
    decision.recognition_gap_severity,
    decision.recognition_gap_summary,
    "recognition gap",
  )
  validate_gap(
    decision.decisiveness_gap_present,
    decision.decisiveness_gap_severity,
    decision.decisiveness_gap_summary,
    "decisiveness gap",
  )
}

///|
fn moonchat_decision(decision : CrossProductReviewDecision) -> String {
  match decision.outcome {
    "approve" => "approve"
    "reject" => "reject"
    _ => "defer"
  }
}

///|
/// Create the exact MoonChat input contract. MoonFind owns the research
/// semantics; MoonChat owns validation, append-only review events, and the
/// accepted-knowledge projection.
pub fn moonchat_review_bundle(
  run : @research.ResearchRun,
  output : @moontown.TownSynthesisOutput,
  decision : CrossProductReviewDecision,
  source_artifact_ref : String,
  source_digest : String,
) -> Json raise {
  validate_review_decision(run, output, decision)
  if source_artifact_ref.is_blank() ||
    source_artifact_ref.has_prefix("/") ||
    source_artifact_ref.contains("..") ||
    source_digest.length() != 71 ||
    !source_digest.has_prefix("sha256:") {
    fail("MoonChat source evidence identity is invalid")
  }
  let selected = if decision.accepted_idea_ids.is_empty() {
    "none"
  } else {
    decision.accepted_idea_ids.join(", ")
  }
  {
    "contract_id": "moonchat.conversation-review-bundle.v1",
    "review_id": decision.review_id,
    "source_artifact_ref": source_artifact_ref,
    "source_digest": source_digest,
    "source_revision_id": "moontown-\{run.run_id}",
    "previous_bundle_ref": "",
    "previous_bundle_digest": "",
    "conversation": {
      "contract_id": "moonsuite-conversation.v1",
      "protocol": "moonfind.cross-paper-review.v1",
      "product_id": "moonfind",
      "conversation_id": "moonfind-\{run.run_id}-review",
    },
    "participants": [
      {
        "participant_id": "moontown-synthesis",
        "display_name": "MoonTown synthesis",
        "participant_kind": "agent",
      },
      {
        "participant_id": decision.reviewer_id,
        "display_name": decision.reviewer_name,
        "participant_kind": "human",
      },
    ],
    "entries": [
      {
        "entry_id": "synthesis-proposal",
        "entry_kind": "proposal",
        "author_participant_id": "moontown-synthesis",
        "turn": {
          "turn_id": "turn-synthesis",
          "client_turn_id": "client-turn-synthesis",
          "command_id": "command-synthesis",
        },
        "body": "Review \{output.ideas.length()} cross-paper idea(s); selected idea ids: \{selected}.",
        "evidence_refs": [source_artifact_ref],
      },
      {
        "entry_id": "human-review-boundary",
        "entry_kind": "objection",
        "author_participant_id": decision.reviewer_id,
        "turn": {
          "turn_id": "turn-human-decision",
          "client_turn_id": "client-turn-human-decision",
          "command_id": "command-human-decision",
        },
        "body": decision.rationale,
        "evidence_refs": [source_artifact_ref],
      },
    ],
    "required_decisions": [
      {
        "decision_id": "accept-cross-paper-synthesis",
        "subject_entry_id": "human-review-boundary",
        "reviewer_participant_id": decision.reviewer_id,
        "prompt": "Should the exact selected synthesis enter MoonBook as accepted knowledge evidence?",
      },
    ],
    "decision_receipts": [
      {
        "receipt_id": "receipt-\{decision.review_id}",
        "decision_id": "accept-cross-paper-synthesis",
        "reviewer_participant_id": decision.reviewer_id,
        "reviewer_name": decision.reviewer_name,
        "decision": moonchat_decision(decision),
        "rationale": decision.rationale,
        "source_digest": source_digest,
        "decided_at": decision.reviewed_at_utc,
        "evidence_refs": [source_artifact_ref],
      },
    ],
    "recorded_at": decision.reviewed_at_utc,
  }
}

///|
fn review_record_field(fields : Map[String, Json], key : String) -> String raise {
  match fields.get(key) {
    Some(String(value)) if !value.is_blank() => value
    _ => fail("MoonChat review record requires \{key}")
  }
}

///|
fn accepted_moonchat_record(
  value : Json,
  run : @research.ResearchRun,
  decision : CrossProductReviewDecision,
  source_digest : String,
) -> Unit raise {
  guard value is Object(fields) else {
    fail("MoonChat review record must be an object")
  }
  if review_record_field(fields, "contract_id") !=
    "moonchat.conversation-review-record.v1" ||
    review_record_field(fields, "review_id") != decision.review_id ||
    review_record_field(fields, "source_digest") != source_digest ||
    review_record_field(fields, "source_revision_id") !=
    "moontown-\{run.run_id}" ||
    review_record_field(fields, "review_status") != "accepted" ||
    review_record_field(fields, "claim_class") != "accepted-knowledge" ||
    !(fields["accepted"] is True) {
    fail("MoonChat did not return accepted knowledge for this exact synthesis")
  }
}

///|
/// Apply research acceptance only after MoonChat has projected an accepted
/// portable record for the immutable MoonTown source.
pub fn apply_moonchat_review(
  run : @research.ResearchRun,
  output : @moontown.TownSynthesisOutput,
  decision : CrossProductReviewDecision,
  moonchat_record : Json,
  source_digest : String,
) -> @research.ResearchRun raise {
  validate_review_decision(run, output, decision)
  accepted_moonchat_record(
    moonchat_record,
    run,
    decision,
    source_digest,
  )
  run.apply_human_review({
    review_id: decision.review_id,
    run_id: run.run_id,
    reviewer_id: decision.reviewer_id,
    authority_ref: "moonchat://" +
    decision.review_id +
    "/" +
    decision.reviewer_id,
    disposition: "accept",
    accepted_idea_ids: decision.accepted_idea_ids,
    rejected_idea_ids: decision.rejected_idea_ids,
    notes: decision.rationale,
    reviewed_at: decision.reviewed_at_epoch,
  })
}

///|
fn submission_gap(
  present : Bool,
  severity : Int,
  summary : String,
  town_evidence_id : String,
  review_evidence_id : String,
) -> Json {
  {
    "present": present,
    "severity": severity,
    "summary": summary,
    "evidence_refs": [town_evidence_id, review_evidence_id],
  }
}

///|
/// Prepare the generic MoonBook submission consumed through MoonFlow. The
/// external MoonChat acceptance remains evidence; MoonBook still requires its
/// own named-human deliverable, Three-Gap, and capability-proposal gates.
pub fn moonbook_product_outcome_submission(
  run : @research.ResearchRun,
  output : @moontown.TownSynthesisOutput,
  decision : CrossProductReviewDecision,
  moonchat_record : Json,
  town_artifact_ref : String,
  town_digest : String,
  review_artifact_ref : String,
  review_digest : String,
) -> Json raise {
  let reviewed = apply_moonchat_review(
    run,
    output,
    decision,
    moonchat_record,
    town_digest,
  )
  let town_evidence_id = "moontown-synthesis-" + run.run_id
  let review_evidence_id = "moonchat-review-" + decision.review_id
  let capability_payload : Json = {
    "run_id": run.run_id,
    "accepted_idea_ids": reviewed.accepted_idea_ids,
    "information_gap": decision.information_gap_summary,
    "recognition_gap": decision.recognition_gap_summary,
    "decisiveness_gap": decision.decisiveness_gap_summary,
  }
  {
    "contract_version": "moonbook.bookkeeper.product_outcome_submission.v1",
    "submission": {
      "record_id": "moonfind-outcome-" + run.run_id,
      "record_version": "1",
      "record_digest": digest_json(capability_payload),
    },
    "source_product": "moonfind",
    "deliverable_title": "MoonFind reviewed cross-paper synthesis",
    "deliverable_summary": "MoonChat recorded named-human acceptance of \{reviewed.accepted_idea_ids.length()} exact idea(s).",
    "outcome_summary": decision.rationale,
    "owner_route": "moonfind://runs/\{run.run_id}/review",
    "evidence_refs": [
      {
        "reference_id": town_evidence_id,
        "reference_version": "1",
        "digest": town_digest,
        "provenance_ref": town_artifact_ref,
      },
      {
        "reference_id": review_evidence_id,
        "reference_version": "1",
        "digest": review_digest,
        "provenance_ref": review_artifact_ref,
      },
    ],
    "decision_evidence_id": review_evidence_id,
    "observed_at": (decision.reviewed_at_epoch / 1000L).to_int(),
    "recorded_at": (decision.reviewed_at_epoch / 1000L).to_int(),
    "information_gap": submission_gap(
      decision.information_gap_present,
      decision.information_gap_severity,
      decision.information_gap_summary,
      town_evidence_id,
      review_evidence_id,
    ),
    "recognition_gap": submission_gap(
      decision.recognition_gap_present,
      decision.recognition_gap_severity,
      decision.recognition_gap_summary,
      town_evidence_id,
      review_evidence_id,
    ),
    "decisiveness_gap": submission_gap(
      decision.decisiveness_gap_present,
      decision.decisiveness_gap_severity,
      decision.decisiveness_gap_summary,
      town_evidence_id,
      review_evidence_id,
    ),
    "capability_id": "moonfind.cross-paper-synthesis",
    "capability_version": "2",
    "capability_change_digest": digest_json(capability_payload),
    "capability_summary": "Propose only the evidence-backed MoonFind synthesis change identified by the reviewed Three-Gap statements.",
  }
}
