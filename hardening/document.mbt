///|
pub fn full_text_evidence_contract() -> String {
  "moonfind.full-text-evidence.v1"
}

///|
pub(all) struct DocumentIsolationReceipt {
  contract_id : String
  receipt_id : String
  document_digest : String
  extractor_id : String
  extractor_version : String
  isolation_profile : String
  network_disabled : Bool
  active_content_removed : Bool
  decompressed_bytes : Int64
  page_count : Int
  suspicious_signals : Array[String]
  disposition : String
  recorded_at : Int64
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct FullTextEvidence {
  contract_id : String
  evidence_id : String
  paper_id : String
  provider_id : String
  source_url : String
  pdf_digest : String
  extracted_text_digest : String
  extracted_text_artifact : String
  evidence_locations : Array[String]
  provider_decision : ProviderUseDecision
  isolation_receipt : DocumentIsolationReceipt
  retrieved_at : Int64
} derive(Debug, Eq, ToJson, FromJson)

///|
fn safe_artifact_ref(value : String) -> Bool {
  !value.is_blank() &&
  !value.has_prefix("/") &&
  !value.contains("\\") &&
  !value.split("/").contains("..")
}

///|
pub fn validate_full_text_evidence(
  evidence : FullTextEvidence,
) -> Array[String] {
  let issues : Array[String] = []
  if evidence.contract_id != full_text_evidence_contract() {
    issues.push("unsupported full-text evidence contract")
  }
  if evidence.evidence_id.is_blank() || evidence.paper_id.is_blank() {
    issues.push("evidence and paper identities are required")
  }
  if evidence.provider_id != evidence.provider_decision.provider_id ||
    evidence.provider_decision.decision != "allow" {
    issues.push("full text lacks a matching permitted-use decision")
  }
  let receipt = evidence.isolation_receipt
  if receipt.contract_id != "moonfind.document-isolation-receipt.v1" ||
    receipt.document_digest != evidence.pdf_digest {
    issues.push("isolation receipt is missing or bound to another document")
  }
  if receipt.isolation_profile != "hostile-pdf-v1" ||
    !receipt.network_disabled ||
    !receipt.active_content_removed {
    issues.push("PDF extraction did not use the required hostile-input profile")
  }
  if receipt.disposition != "accepted" || !receipt.suspicious_signals.is_empty() {
    issues.push("suspicious or quarantined documents cannot enter analysis")
  }
  if receipt.decompressed_bytes <= 0 ||
    receipt.decompressed_bytes > 200000000L ||
    receipt.page_count <= 0 ||
    receipt.page_count > 2000 {
    issues.push("document expansion or page count exceeds the intake limits")
  }
  if evidence.pdf_digest.is_blank() || evidence.extracted_text_digest.is_blank() {
    issues.push("PDF and extracted-text digests are required")
  }
  if !safe_artifact_ref(evidence.extracted_text_artifact) {
    issues.push(
      "extracted text must use a workspace-relative artifact reference",
    )
  }
  if evidence.evidence_locations.is_empty() ||
    evidence.evidence_locations.any(location => location.is_blank()) {
    issues.push("page or section evidence locations are required")
  }
  issues
}

///|
pub fn quarantine_document(
  receipt : DocumentIsolationReceipt,
  reason : String,
) -> DocumentIsolationReceipt {
  let signals = receipt.suspicious_signals.copy()
  if !reason.is_blank() && !signals.contains(reason) {
    signals.push(reason)
  }
  { ..receipt, suspicious_signals: signals, disposition: "quarantined" }
}
