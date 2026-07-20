///|
pub(all) struct RecoverySnapshot {
  contract_id : String
  run_id : String
  run_status : String
  full_text_ready : Bool
  moonclaw_command_ready : Bool
  analysis_ready : Bool
  moontown_handoff_ready : Bool
  moontown_receipt_ready : Bool
  human_review_ready : Bool
  bookkeeper_handoff_ready : Bool
  next_action : String
  terminal : Bool
  recorded_at : Int64
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn recovery_snapshot(
  run_id : String,
  run_status : String,
  full_text_ready : Bool,
  moonclaw_command_ready : Bool,
  analysis_ready : Bool,
  moontown_handoff_ready : Bool,
  moontown_receipt_ready : Bool,
  human_review_ready : Bool,
  bookkeeper_handoff_ready : Bool,
  recorded_at : Int64,
) -> RecoverySnapshot raise {
  guard !run_id.is_blank() && recorded_at >= 0 else {
    fail("recovery requires a run identity and non-negative time")
  }
  let next_action = if run_status == "accepted" && bookkeeper_handoff_ready {
    "complete"
  } else if human_review_ready {
    "rebuild-bookkeeper-handoff"
  } else if moontown_receipt_ready {
    "await-named-human-review"
  } else if moontown_handoff_ready {
    "execute-moontown-handoff"
  } else if analysis_ready {
    "build-moontown-handoff"
  } else if moonclaw_command_ready {
    "execute-moonclaw-command"
  } else if full_text_ready {
    "rebuild-moonclaw-command"
  } else {
    "acquire-and-isolate-full-text"
  }
  {
    contract_id: "moonfind.recovery-snapshot.v1",
    run_id,
    run_status,
    full_text_ready,
    moonclaw_command_ready,
    analysis_ready,
    moontown_handoff_ready,
    moontown_receipt_ready,
    human_review_ready,
    bookkeeper_handoff_ready,
    next_action,
    terminal: next_action == "complete",
    recorded_at,
  }
}
