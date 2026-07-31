///|
/// Host-published status for the typed MoonFind -> MoonTown boundary.
/// A browser may open `open_url` only when `state == "ready"` and the host
/// has verified both the durable handoff and the configured MoonTown service.
pub(all) struct MoonTownHandoffStatusV1 {
  contract_id : String
  run_id : String
  state : String
  handoff_contract : String
  handoff_id : String?
  handoff_url : String?
  open_url : String?
  receipt_contract : String?
  receipt_status : String?
  detail : String
} derive(Debug, ToJson, FromJson)

///|
/// Current durable MoonFind state projected by the trusted local host.
/// Endpoint fields are same-origin pack-host ports, never provider URLs.
pub(all) struct UiWorkspaceSnapshotV1 {
  contract_id : String
  product_id : String
  generated_at : String
  book_workspace : String
  workspace : @app.ResearchWorkspaceProjection
  research_cowork_session_key : String?
  qa_cowork_session_key : String?
  qa_agent_status : String
  research_execution : @integration.ResearchExecutionRecordV1?
  capability_submit_url : String?
  capability_reconcile_url : String?
  capability_checkpoint_url : String?
  moonclaw_gateway_base : String?
  host_status : String
  host_blockers : Array[String]
  moontown_handoff : MoonTownHandoffStatusV1
  review_workflow : ReviewWorkflowStatusV1
} derive(Debug, ToJson, FromJson)

///|
/// Result of one local capability-host operation. `blocked` means no
/// external success is claimed; `execution` remains the latest durable
/// append-only MoonFind checkpoint.
pub(all) struct CapabilityOperationReplyV1 {
  contract_id : String
  operation : String
  blocked : Bool
  message : String
  execution : @integration.ResearchExecutionRecordV1
} derive(Debug, ToJson, FromJson)

///|
/// Browser request for a trusted-host checkpoint. The host re-reads the
/// session from MoonClaw and never trusts browser-supplied run status.
pub(all) struct MoonClawSessionCheckpointRequestV1 {
  contract_id : String
  session_key : String
} derive(Debug, ToJson, FromJson)

///|
/// Idempotent acknowledgement for a strictly correlated MoonTown result.
/// A successful ingest still means `review_status == "pending"`; it is never
/// a MoonBook review decision.
pub(all) struct MoonTownResultIngestReplyV1 {
  contract_id : String
  state : String
  run_id : String
  handoff_id : String
  receipt_status : String
  review_status : String
  idea_count : Int
  receipt_ref : String
  output_ref : String
  envelope_ref : String
  message : String
} derive(Debug, ToJson, FromJson)

///|
pub(all) struct ReviewGapInputV1 {
  present : Bool
  severity : Int
  summary : String
} derive(Debug, ToJson, FromJson)

///|
/// Named-human input captured by MoonFind. The trusted host adds the durable
/// run identity and timestamp before producing a MoonChat bundle.
pub(all) struct ReviewPrepareRequestV1 {
  contract_id : String
  reviewer_name : String
  outcome : String
  accepted_idea_ids : Array[String]
  rejected_idea_ids : Array[String]
  rationale : String
  information_gap : ReviewGapInputV1
  recognition_gap : ReviewGapInputV1
  decisiveness_gap : ReviewGapInputV1
} derive(Debug, ToJson, FromJson)

///|
pub(all) struct ReviewPrepareReplyV1 {
  contract_id : String
  state : String
  run_id : String
  review_id : String
  source_ref : String
  source_digest : String
  bundle_ref : String
  operation_ref : String
  message : String
} derive(Debug, ToJson, FromJson)

///|
/// The browser returns the exact verified MoonFlow intake to the trusted
/// pack host. The host revalidates every binding and produces the immutable
/// generic receiver receipt; the browser never invents authority or digests.
pub(all) struct ReviewMoonFlowReceiptRequestV1 {
  contract_id : String
  intake : Json
} derive(Debug, ToJson, FromJson)

///|
pub(all) struct ReviewMoonFlowReceiptReplyV1 {
  contract_id : String
  run_id : String
  handoff_token : String
  receipt_path : String
  receiver_receipt : Json
  message : String
} derive(Debug, ToJson, FromJson)

///|
/// A MoonFlow-correlated MoonChat result is transported as exact text so the
/// host can verify the adapter's byte digest before parsing it.
pub(all) struct MoonChatResultIngestRequestV1 {
  contract_id : String
  product_id : String
  status : String
  output_digest : String
  output_artifact_ref : String
  record_text : String
} derive(Debug, ToJson, FromJson)

///|
pub(all) struct MoonChatResultIngestReplyV1 {
  contract_id : String
  state : String
  run_id : String
  review_id : String
  record_ref : String
  record_digest : String
  submission_ref : String?
  next_operation_ref : String?
  message : String
} derive(Debug, ToJson, FromJson)

///|
pub(all) struct ReviewWorkflowStatusV1 {
  contract_id : String
  run_id : String
  state : String
  prepare_url : String?
  moonchat_ingest_url : String?
  moonchat_operation_ref : String?
  bundle_ref : String?
  record_ref : String?
  bookkeeper_operation_ref : String?
  bookkeeper_submission_ref : String?
  detail : String
} derive(Debug, ToJson, FromJson)

///|
struct CoworkCheckpointRun {
  id : String
  status : String
  summary : String?
  error : String?
  workspace_dir : String?
} derive(Debug, ToJson, FromJson)

///|
struct CoworkCheckpointDetail {
  linked_run : CoworkCheckpointRun?
} derive(Debug, FromJson)

///|
struct CoworkCheckpointPayload {
  session : CoworkCheckpointDetail
} derive(Debug, FromJson)
