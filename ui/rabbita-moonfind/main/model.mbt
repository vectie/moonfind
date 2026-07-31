///|
struct CoworkSessionSummary {
  session_key : String
  session_id : String
  title : String
  updated_at : Int
  state : String
  last_message_preview : String?
  channel : String?
  cwd : String?
  model_override : String?
  provider_override : String?
  has_plan_mode : Bool
  linked_proposal_id : String?
  linked_run_id : String?
} derive(Debug, FromJson)

///|
struct CoworkProposalRef {
  id : String
  title : String
  summary : String
  status : String
  request_text : String
  updated_at : Int
} derive(Debug, FromJson)

///|
struct CoworkRunRef {
  id : String
  job_id : String
  status : String
  summary : String?
  error : String?
  current_step_id : String?
  workspace_dir : String?
} derive(Debug, ToJson, FromJson)

///|
struct CoworkMessage {
  id : String
  role : String
  kind : String
  content : String
  timestamp : Int
  metadata : Json
} derive(Debug, FromJson)

///|
struct CoworkSessionDetail {
  session : CoworkSessionSummary
  messages : Array[CoworkMessage]
  plan_preview : String?
  linked_proposal : CoworkProposalRef?
  linked_run : CoworkRunRef?
} derive(Debug, FromJson)

///|
struct CoworkSessionPayload {
  session : CoworkSessionDetail
} derive(Debug, FromJson)

///|
struct CapabilityReceiptProjection {
  output : Json?
} derive(Debug, FromJson)

///|
struct ResearchExecutionProjection {
  contract_id : String
  revision : Int
  run_id : String
  operation_ref : String
  request_id : String
  attempt_id : String
  idempotency_key : String
  state : String
  invocation : Json
  receipt_ref : String?
  receipt : CapabilityReceiptProjection?
  result_ref : String?
  moonclaw_session_key : String?
  moonclaw_run_id : String?
  error_kind : String
  requires_review : Bool
  next_action : String
  updated_at : String
} derive(Debug, FromJson)

///|
struct ResearchExecutionPayload {
  execution : ResearchExecutionProjection
} derive(Debug, FromJson)

///|
struct WorkspaceSnapshot {
  product_id : String
  book_workspace : String
  research_cowork_session_key : String?
  qa_cowork_session_key : String?
  qa_agent_status : String
  research_execution : ResearchExecutionProjection?
  capability_submit_url : String?
  capability_reconcile_url : String?
  capability_checkpoint_url : String?
} derive(Debug, FromJson)

///|
enum ResearchPhase {
  Ready
  CreatingSession
  Confirming
  Running
  NeedsReview
  Completed
  Failed
} derive(Debug, Eq)

///|
enum ReviewPhase {
  ReviewIdle
  ReviewCreatingSession
  ReviewPlanning
  ReviewPlanReady
  ReviewPromoting
  ReviewProposalReady
  ReviewConfirming
  ReviewRunning
  ReviewCompleted
  ReviewFailed
} derive(Debug, Eq)

///|
struct Model {
  gateway_base : String
  source_dir : String
  book_dir : String
  model_name : String
  request_text : String
  phase : ResearchPhase
  research_session : CoworkSessionDetail?
  review_session : CoworkSessionDetail?
  qa_session : CoworkSessionDetail?
  review_phase : ReviewPhase
  qa_ready : Bool
  reviewer_name : String
  review_outcome : String
  review_scope : String
  review_message : String
  qa_question : String
  research_execution : ResearchExecutionProjection?
  capability_submit_url : String?
  capability_reconcile_url : String?
  capability_checkpoint_url : String?
  notice : String?
  error : String?
}

///|
enum Msg {
  WorkspaceLoaded(Result[WorkspaceSnapshot, String])
  SetGateway(String)
  SetSourceDir(String)
  SetBookDir(String)
  SetModelName(String)
  SetRequestText(String)
  SetReviewerName(String)
  SetReviewOutcome(String)
  SetReviewScope(String)
  SetReviewMessage(String)
  SetQaQuestion(String)
  StartResearch
  CapabilitySubmitted(Result[ResearchExecutionProjection, String])
  ResearchSessionCreated(Result[CoworkSessionDetail, String])
  ResearchConfigured(Result[CoworkSessionDetail, String])
  ResearchCommandSubmitted(Result[CoworkSessionDetail, String])
  ExecutionCheckpointed(Result[ResearchExecutionProjection, String])
  RefreshResearch
  ResearchRefreshed(Result[CoworkSessionDetail, String])
  ResumeReview
  ReviewResumed(Result[CoworkSessionDetail, String])
  PrepareReview
  ReviewSessionCreated(Result[CoworkSessionDetail, String])
  ReviewConfigured(Result[CoworkSessionDetail, String])
  ReviewPlanned(Result[CoworkSessionDetail, String])
  PromoteReview
  ReviewPromoted(Result[CoworkSessionDetail, String])
  ConfirmReview
  ReviewConfirmed(Result[CoworkSessionDetail, String])
  RefreshReview
  ReviewRefreshed(Result[CoworkSessionDetail, String])
  PrepareQa
  QaSessionCreated(Result[CoworkSessionDetail, String])
  QaConfigured(Result[CoworkSessionDetail, String])
  QaBootstrapped(Result[CoworkSessionDetail, String])
  QaReconnected(Result[CoworkSessionDetail, String])
  AskQa
  QaAnswered(Result[CoworkSessionDetail, String])
}

///|
fn default_request(source_dir : String, book_dir : String) -> String {
  (
    $|Use the Moonfind pack at /Users/kq/Workspace/moonfind to produce a reviewed DeepSeek research book.
    $|
    $|Private source folder: \{source_dir}
    $|MoonBook source workspace: \{book_dir}
    $|
    $|Requirements:
    $|1. Read the Moonfind and MoonBook AGENTS.md files and preserve ownership boundaries. MoonClaw is the only model runtime; MoonBook owns durable reviewed memory; MoonTown owns the adversarial idea salon.
    $|2. Verify the existing moonfind.local-input-coverage.v1 ledger against every available file. Keep page 1 explicitly missing and never reconstruct it.
    $|3. Inspect every page and refine the existing source map. Treat the alleged interview as private, incomplete, and unauthenticated attributed evidence.
    $|4. Run at least three iterations: source mapping; current primary-source web validation; MoonTown challenge with provenance critic, technical verifier, economic skeptic, and synthesis explorer.
    $|5. Refine wiki/synthesis/deepseek-research-report.md and claim-matrix.md. Do not merely concatenate or paraphrase the transcript.
    $|6. Initialize or repair the workspace as a MoonBook wiki without discarding the existing draft. Create a pending review candidate. Never self-approve or claim acceptance.
    $|7. Write report.md and result.json as handover outputs and preserve exact source citations, confidence, contradictions, and open gaps.
    $|8. Prepare a stable read-only Q&A grounding packet named moonfind-deepseek-research-book-qa. A later Cowork session will host the answering agent.
    $|9. Update the journey log with every problem, cause, fix, test, and remaining limitation. Use MoonBit for product code; do not add Python.
    $|
    $|Pause for named-human review when durable promotion requires authority.
  )
}

///|
fn initial_model() -> Model {
  let source_dir = "/Users/kq/Downloads/deepseek"
  let book_dir = "/Users/kq/Workspace/deepseek-research-book"
  {
    gateway_base: "http://127.0.0.1:18123",
    source_dir,
    book_dir,
    model_name: "codex/gpt-5.6-sol",
    request_text: default_request(source_dir, book_dir),
    phase: Ready,
    research_session: None,
    review_session: None,
    qa_session: None,
    review_phase: ReviewIdle,
    qa_ready: false,
    reviewer_name: "",
    review_outcome: "",
    review_scope: "",
    review_message: "Approve only claims supported by cited evidence. Keep unauthenticated transcript claims attributed and preserve page 1 as missing.",
    qa_question: "What is the strongest evidence for and against the transcript's central DeepSeek strategy thesis?",
    research_execution: None,
    capability_submit_url: None,
    capability_reconcile_url: None,
    capability_checkpoint_url: None,
    notice: Some(
      "17/17 available pages are staged in the draft book; named-human review is still pending.",
    ),
    error: None,
  }
}

///|
fn valid_review_outcome(outcome : String) -> Bool {
  outcome is ("approve_subset" | "request_changes" | "reject")
}

///|
fn review_request_issues(
  reviewer_name : String,
  outcome : String,
  scope : String,
  instruction : String,
) -> Array[String] {
  let issues : Array[String] = []
  if reviewer_name.trim().is_blank() {
    issues.push("Enter the named human reviewer.")
  }
  if !valid_review_outcome(outcome) {
    issues.push("Choose approve_subset, request_changes, or reject.")
  }
  if outcome == "approve_subset" && scope.trim().is_blank() {
    issues.push("List the exact claim IDs or sections approved.")
  }
  if instruction.trim().is_blank() {
    issues.push("Record the reviewer rationale or requested change.")
  }
  issues
}

///|
fn review_decision_request(
  book_dir : String,
  reviewer_name : String,
  outcome : String,
  scope : String,
  instruction : String,
) -> String {
  (
    $|Use the Moonfind pack at /Users/kq/Workspace/moonfind and MoonBook at /Users/kq/Workspace/moonbook to record a named-human review decision for the DeepSeek research candidate.
    $|
    $|MoonBook workspace: \{book_dir}
    $|Named reviewer: \{reviewer_name}
    $|Decision outcome: \{outcome}
    $|Decision scope: \{scope}
    $|Reviewer rationale or requested change:
    $|\{instruction}
    $|
    $|Requirements:
    $|1. Read AGENTS.md for Moonfind and MoonBook and preserve product ownership. MoonClaw is the only model runtime; MoonBook owns the review decision and durable memory.
    $|2. Verify the pending candidate, state/review-status.json, pending and approved queues, claim matrix, grounding manifest, and activation receipt before mutation.
    $|3. Accept only the exact named-human outcome above. Never broaden approve_subset beyond the explicit decision scope. Never infer approval from a successful research or Q&A run.
    $|4. For approve_subset, preserve all unlisted claims as pending or provisional. For request_changes or reject, keep accepted false and durable promotion not_promoted.
    $|5. Record a durable decision receipt with reviewer, outcome, scope, rationale, timestamp, affected paths, previous state, resulting state, and Three Gap outcome binding.
    $|6. Update MoonBook queues and review state consistently, without rewriting private source evidence or reconstructing missing page 1.
    $|7. Run MoonBook validation and report exact changed files, tests, and any unresolved gaps. Use MoonBit for product changes; do not add Python.
  )
}

///|
fn normalized_run_status(status : String) -> String {
  status.trim(chars=['"', ' ', '\n', '\r', '\t']).to_owned()
}

///|
fn phase_from_run_status(status : String) -> ResearchPhase {
  match normalized_run_status(status).to_lower() {
    "succeeded" | "completed" => Completed
    "failed" | "cancelled" | "canceled" => Failed
    "paused" | "waitingforinput" | "needsinput" | "blocked" => NeedsReview
    _ => Running
  }
}

///|
fn phase_from_session(session : CoworkSessionDetail) -> ResearchPhase {
  match session.linked_run {
    Some(run) => phase_from_run_status(run.status)
    None => Ready
  }
}

///|
fn review_phase_from_session(session : CoworkSessionDetail) -> ReviewPhase {
  match session.linked_run {
    Some(run) =>
      match phase_from_run_status(run.status) {
        Completed => ReviewCompleted
        Failed => ReviewFailed
        _ => ReviewRunning
      }
    None =>
      if session.linked_proposal is Some(_) {
        ReviewProposalReady
      } else if session.plan_preview is Some(_) {
        ReviewPlanReady
      } else {
        ReviewIdle
      }
  }
}

///|
fn latest_assistant_message(session : CoworkSessionDetail) -> String? {
  for i = session.messages.length() - 1; i >= 0; i = i - 1 {
    let message = session.messages[i]
    if message.role == "assistant" &&
      message.kind == "assistant" &&
      !message.content.is_blank() {
      return Some(message.content)
    }
  }
  None
}
