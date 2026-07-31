///|
/// Exact JSON binding embedded by MoonClaw in a pack-tool request.
pub(all) struct ToolBinding {
  pack_id : String
  product_id : String
  tool_id : String
  input_schema_id : String
  output_schema_id : String
  authority : @pack.AuthorityClass
  idempotent : Bool
  evidence_outputs : Array[String]
  review_required : Bool
} derive(Debug, ToJson, FromJson)

///|
/// Exact request accepted by MoonClaw's generic pack-owned HTTP transport.
pub(all) struct PackToolExecutionRequest {
  binding : ToolBinding
  config : Json
  initial_input : Json?
  outputs : Map[String, Json]
  request_id : String
  attempt_id : String
  idempotency_key : String
  operation_ref : String
  run_id : String
  step_id : String
  evidence_path : String
  attempt : Int
  estimated_cost_micros : Int
} derive(Debug, ToJson, FromJson)

///|
/// Exact result returned to MoonClaw after deterministic pack work settles.
pub(all) struct PackToolExecutionResult {
  status : String
  output : Json
  summary : String?
  metrics : Json
  logs : Array[String]
  output_artifacts : Array[String]
  external_job_id : String
  compensable : Bool
} derive(Debug, ToJson, FromJson)

///|
/// Exact response returned when MoonClaw reconciles an existing attempt.
pub(all) struct PackToolReconciliation {
  status : String
  result : PackToolExecutionResult?
  error_kind : String
} derive(Debug, ToJson, FromJson)

///|
/// Host-owned configuration. This process is a deterministic pack adapter,
/// never an agent or model runtime.
pub(all) struct AdapterConfig {
  workspace : String
} derive(Debug)

///|
pub fn AdapterConfig::new(workspace : String) -> AdapterConfig {
  { workspace, }
}

///|
struct PackToolAttemptRecord {
  contract_id : String
  request_digest : String
  request : PackToolExecutionRequest
  planned_output_digest : String
  planned_output : Json
  state : String
  result : PackToolExecutionResult?
  error_kind : String
} derive(Debug, ToJson, FromJson)
