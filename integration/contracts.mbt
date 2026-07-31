///|
/// Exact wire projection of one operation in
/// `moonflow.capability-catalog.v1`.
pub(all) struct CapabilityCatalogOperationV1 {
  operation_ref : String
  product_id : String
  pack_id : String
  pack_version : String
  tool_id : String
  adapter_id : String
  protocol : String
  authority : String
  input_schema_ref : String
  output_schema_ref : String
  claim_ceiling : String
  idempotent : Bool
  review_required : Bool
  supports_cancel : Bool
  supports_reconcile : Bool
  health_checked_at : String
  health_valid_until : String
  health_evidence_ref : String
  health_evidence_digest : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct CapabilityCatalogProductV1 {
  product_id : String
  pack_id : String
  pack_version : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct CapabilityCatalogIssueV1 {
  code : String
  subject : String
  detail : String
  suggestions : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct CapabilityCatalogV1 {
  contract_id : String
  catalog_id : String
  compiled_at : String
  conformant : Bool
  products : Array[CapabilityCatalogProductV1]
  operations : Array[CapabilityCatalogOperationV1]
  issues : Array[CapabilityCatalogIssueV1]
} derive(Debug, Eq, ToJson, FromJson)

///|
/// MoonFlow's immutable adapter request. Keeping the exact wire shape lets
/// MoonFind use MoonClaw without importing or recreating its runtime.
pub(all) struct MoonFlowAdapterRequestV2 {
  request_id : String
  run_id : String
  book_id : String
  work_item_id : String
  declaration_id : String
  attempt_id : String
  idempotency_key : String
  product_id : String
  operation : String
  requested_authority : String
  acceptance_criteria : Array[String]
  input_contracts : Array[String]
  output_contracts : Array[String]
  required_claim : String
  input_digest : String
  input_artifacts : Array[String]
  timeout_ms : Int
  created_at : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Exact input accepted by MoonClaw's generic installed-pack capability seam.
pub(all) struct MoonClawCapabilityInvocationV1 {
  contract_id : String
  adapter_id : String
  evaluated_at : String
  recorded_at : String
  attempt : Int
  request : MoonFlowAdapterRequestV2
  config : Json
  input : Json
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Exact restart/reconcile receipt returned by MoonClaw.
pub(all) struct MoonClawCapabilityReceiptV1 {
  contract_id : String
  result_id : String
  request_id : String
  attempt_id : String
  idempotency_key : String
  product_id : String
  external_job_id : String
  status : String
  output_digest : String
  output_artifacts : Array[String]
  error_kind : String
  compensable : Bool
  recorded_at : String
  catalog_id : String
  pack_id : String
  pack_version : String
  adapter_id : String
  operation_ref : String
  input_schema_ref : String
  output_schema_ref : String
  requested_authority : String
  input_digest : String
  health_evidence_ref : String
  health_evidence_digest : String
  output : Json?
  summary : String?
  metrics : Json
  logs : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Durable observation of the existing MoonClaw Cowork run that executes the
/// exact command produced by the pack capability.
pub(all) struct MoonClawRunObservationV1 {
  contract_id : String
  session_key : String
  run_id : String
  status : String
  result_ref : String?
  error : String
  observed_at : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Append-only MoonFind projection of one MoonClaw capability attempt.
/// `invocation` is immutable. Every transition increments `revision`.
pub(all) struct ResearchExecutionRecordV1 {
  contract_id : String
  revision : Int
  run_id : String
  operation_ref : String
  request_id : String
  attempt_id : String
  idempotency_key : String
  state : String
  invocation : MoonClawCapabilityInvocationV1
  receipt_ref : String?
  receipt : MoonClawCapabilityReceiptV1?
  result_ref : String?
  moonclaw_session_key : String?
  moonclaw_run_id : String?
  moonclaw_run : MoonClawRunObservationV1?
  error_kind : String
  requires_review : Bool
  next_action : String
  updated_at : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Desired stages are product intent, not executable truth. A missing
/// `desired_operation_ref` stays visible but can never enter MoonFlow.
pub(all) struct DesiredCapabilityStageV2 {
  stage_id : String
  declaration_id : String
  product_id : String
  desired_operation_ref : String?
  desired_tool_hint : String
  execution_role : String?
  execution_config : Json?
  requested_authority : String
  input_schema_ref : String?
  output_schema_ref : String?
  required_claim : String
  acceptance_criteria : Array[String]
  input_artifacts : Array[String]
  timeout_ms : Int
  depends_on : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct DesiredCapabilityGraphV2 {
  contract_id : String
  graph_id : String
  book_id : String
  declaration_revision : String
  source_digest : String
  support_topology : Json?
  intentional_exclusions : Array[Json]?
  stages : Array[DesiredCapabilityStageV2]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct CapabilityStageBindingV1 {
  stage_id : String
  operation_ref : String
  adapter_id : String
  input_schema_ref : String
  output_schema_ref : String
  authority : String
  claim_ceiling : String
  review_required : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct CapabilityGraphGapV1 {
  stage_id : String
  code : String
  detail : String
  suggestions : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
/// `importable_graph` is absent unless every desired stage resolves exactly.
pub(all) struct CapabilityGraphProjectionV1 {
  contract_id : String
  graph_id : String
  catalog_id : String
  evaluated_at : String
  fully_conformant : Bool
  bindings : Array[CapabilityStageBindingV1]
  gaps : Array[CapabilityGraphGapV1]
  importable_graph : Json?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct RoboticsRequestMaterializationEntryV1 {
  stage_id : String
  artifact_ref : String
  input_schema_ref : String
  schema_source_ref : String
  schema_digest : String
  payload_digest : String
  required_top_level_fields : Array[String]
  constant_top_level_fields : Json
  validation_scope : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct RoboticsRequestMaterializationV1 {
  contract_id : String
  graph_id : String
  graph_source_digest : String
  fixture_only : Bool
  fixture_notice : String
  generated_at : String
  validation_engine : String
  complete : Bool
  unresolved_fields : Array[String]
  entries : Array[RoboticsRequestMaterializationEntryV1]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct RoboticsRequestPayloadV1 {
  artifact_ref : String
  payload_digest : String
  payload : Json
} derive(Debug, Eq, ToJson, FromJson)
