///|
pub fn provider_policy_contract() -> String {
  "moonfind.provider-policy.v1"
}

///|
pub(all) struct ProviderPolicy {
  contract_id : String
  provider_id : String
  provider_kind : String
  license_class : String
  terms_ref : String
  status : String
  permitted_uses : Array[String]
  model_input_allowed : Bool
  commercial_use_allowed : Bool
  retention_days : Int
  redistribution : String
  deletion_supported : Bool
  audit_supported : Bool
  reviewed_by : String
  reviewed_at : Int64
  expires_at : Int64?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct ProviderUseRequest {
  provider_id : String
  use_case : String
  sends_to_model : Bool
  commercial : Bool
  requested_retention_days : Int
  redistribution : String
  requested_at : Int64
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct ProviderUseDecision {
  contract_id : String
  provider_id : String
  use_case : String
  decision : String
  reasons : Array[String]
  terms_ref : String
  reviewed_by : String
  decided_at : Int64
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn decide_provider_use(
  policy : ProviderPolicy,
  request : ProviderUseRequest,
) -> ProviderUseDecision {
  let reasons : Array[String] = []
  if policy.contract_id != provider_policy_contract() {
    reasons.push("unsupported provider policy contract")
  }
  if policy.provider_id != request.provider_id {
    reasons.push("provider identity mismatch")
  }
  if policy.status != "approved" || policy.terms_ref.is_blank() {
    reasons.push("provider terms are not approved and reviewable")
  }
  if !policy.permitted_uses.contains(request.use_case) {
    reasons.push("requested use is outside permitted uses")
  }
  if request.sends_to_model && !policy.model_input_allowed {
    reasons.push("provider content is not permitted as model input")
  }
  if request.commercial && !policy.commercial_use_allowed {
    reasons.push("commercial use is not permitted")
  }
  if request.requested_retention_days < 0 ||
    request.requested_retention_days > policy.retention_days {
    reasons.push("requested retention exceeds the approved period")
  }
  if request.redistribution != "none" &&
    request.redistribution != policy.redistribution {
    reasons.push("requested redistribution is not permitted")
  }
  match policy.expires_at {
    Some(expiry) =>
      if request.requested_at >= expiry {
        reasons.push("provider approval has expired")
      }
    None => ()
  }
  {
    contract_id: "moonfind.provider-use-decision.v1",
    provider_id: request.provider_id,
    use_case: request.use_case,
    decision: if reasons.is_empty() {
      "allow"
    } else {
      "deny"
    },
    reasons,
    terms_ref: policy.terms_ref,
    reviewed_by: policy.reviewed_by,
    decided_at: request.requested_at,
  }
}
