///|
fn reviewed_policy() -> ProviderPolicy {
  {
    contract_id: provider_policy_contract(),
    provider_id: "licensed-fulltext",
    provider_kind: "full-text",
    license_class: "commercial-reviewed",
    terms_ref: "contracts/provider-2026.json",
    status: "approved",
    permitted_uses: ["research-synthesis"],
    model_input_allowed: true,
    commercial_use_allowed: true,
    retention_days: 30,
    redistribution: "none",
    deletion_supported: true,
    audit_supported: true,
    reviewed_by: "legal-reviewer",
    reviewed_at: 100L,
    expires_at: Some(1000L),
  }
}

///|
fn provider_request() -> ProviderUseRequest {
  {
    provider_id: "licensed-fulltext",
    use_case: "research-synthesis",
    sends_to_model: true,
    commercial: true,
    requested_retention_days: 14,
    redistribution: "none",
    requested_at: 500L,
  }
}

///|
test "provider responsibility fails closed on identity expiry and model use" {
  assert_eq(
    decide_provider_use(reviewed_policy(), provider_request()).decision,
    "allow",
  )
  let expired = { ..provider_request(), requested_at: 1000L }
  assert_eq(decide_provider_use(reviewed_policy(), expired).decision, "deny")
  let prohibited = { ..reviewed_policy(), model_input_allowed: false }
  let denied = decide_provider_use(prohibited, provider_request())
  assert_eq(denied.decision, "deny")
  assert_true(
    denied.reasons.contains("provider content is not permitted as model input"),
  )
}
