///|
priv struct MoonFlowReviewReceiver {
  root : String
  run_id : String
  work_item_id : String
  declaration_id : String
  token : String
  digest : String
  request_id : String
  attempt_id : String
  idempotency_key : String
  requested_authority : String
  output_contracts : Array[String]
  acceptance_criteria : Array[String]
  input_artifacts : Array[String]
}

///|
fn review_receiver_strict_object(
  value : Json,
  label : String,
  allowed : Array[String],
) -> Map[String, Json] raise {
  guard value is Object(fields) else {
    fail("MoonFind MoonFlow receiver requires an object for \{label}")
  }
  for key, _ in fields {
    if !allowed.contains(key) {
      fail(
        "MoonFind MoonFlow receiver rejects unsupported \{label} field: \{key}",
      )
    }
  }
  fields
}

///|
fn review_receiver_string(
  fields : Map[String, Json],
  key : String,
) -> String raise {
  guard fields.get(key) is Some(String(value)) && !value.trim().is_blank() else {
    fail("MoonFind MoonFlow receiver requires text field \{key}")
  }
  value
}

///|
fn review_receiver_bool(fields : Map[String, Json], key : String) -> Bool raise {
  match fields.get(key) {
    Some(True) => true
    Some(False) => false
    _ => fail("MoonFind MoonFlow receiver requires boolean field \{key}")
  }
}

///|
fn review_receiver_strings(
  fields : Map[String, Json],
  key : String,
) -> Array[String] raise {
  guard fields.get(key) is Some(Array(values)) else {
    fail("MoonFind MoonFlow receiver requires text array \{key}")
  }
  let result : Array[String] = []
  for value in values {
    guard value is String(text) && !text.trim().is_blank() else {
      fail("MoonFind MoonFlow receiver requires non-empty text in \{key}")
    }
    if result.contains(text) {
      fail("MoonFind MoonFlow receiver rejects duplicate \{key} values")
    }
    result.push(text)
  }
  result
}

///|
fn review_receiver_safe_token(value : String) -> Bool {
  value.length() == 64 &&
  value.all(ch => (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f'))
}

///|
fn review_receiver_safe_ref(value : String) -> Bool {
  !value.is_blank() &&
  !value.has_prefix("/") &&
  !value.contains("\\") &&
  !value.contains("%") &&
  !value.split("/").any(part => part.is_blank() || part is ("." | ".."))
}

///|
fn review_receiver_base(run_id : String, token : String) -> String {
  ".moonsuite/products/moonfind/moonflow-receivers/\{run_id}/\{token}"
}

///|
fn review_receiver_endpoint(run_id : String, token : String) -> String {
  "/api/moonflow/runs/\{run_id}/handoffs/\{token}"
}

///|
fn review_receiver_supported_criterion(value : String) -> Bool {
  value ==
  "the exact named-human decision, Three-Gap statements, and portable MoonChat review bundle exist; no MoonBook acceptance is claimed"
}

///|
async fn review_receiver_root(config : Config) -> String {
  @fs.realpath(config.workspace)
}

///|
fn review_receiver_path(root : String, reference : String) -> String raise {
  guard review_receiver_safe_ref(reference) else {
    fail("MoonFind MoonFlow receiver artifact reference is unsafe")
  }
  root + "/" + reference
}

///|
async fn review_receiver_declared_digest(
  root : String,
  references : Array[String],
) -> String {
  let artifacts : Array[(String, Bytes)] = []
  for reference in references {
    artifacts.push(
      (reference, @fs.read_file(review_receiver_path(root, reference)).binary()),
    )
  }
  @store.digest_declared_artifact_bytes(artifacts)
}

///|
async fn review_receiver_write_immutable(
  root : String,
  reference : String,
  value : Json,
) -> Unit {
  let path = review_receiver_path(root, reference)
  let text = value.stringify(indent=2) + "\n"
  if @fs.exists(path) {
    if @fs.read_file(path).text() != text {
      fail(
        "MoonFind MoonFlow receiver artifact already exists with different bytes",
      )
    }
  } else {
    @fs.write_file(
      path,
      @utf8.encode(text),
      create_mode=OpenOrCreate,
      permission=0o600,
    )
  }
}

///|
async fn decode_moonflow_review_receiver(
  config : Config,
  intake : Json,
) -> MoonFlowReviewReceiver {
  let root = review_receiver_root(config)
  let top = review_receiver_strict_object(intake, "handoff", [
    "contract_id", "contract_version", "handoff_id", "handoff_ref", "binding", "payload",
  ])
  guard review_receiver_string(top, "contract_id") ==
    "moonflow.operator-handoff.v2" &&
    review_receiver_string(top, "contract_version") == "2.0.0" &&
    top.get("binding") is Some(binding_json) &&
    top.get("payload") is Some(payload_json) else {
    fail("MoonFind received an unsupported MoonFlow operator handoff")
  }
  ignore(review_receiver_string(top, "handoff_id"))
  let handoff_ref = review_receiver_string(top, "handoff_ref")
  guard review_receiver_safe_ref(handoff_ref) &&
    handoff_ref.has_prefix("operator-handoffs/") else {
    fail("MoonFind MoonFlow publication reference is unsafe")
  }
  let binding = review_receiver_strict_object(binding_json, "binding", [
    "handoff_token", "handoff_digest", "request_id", "attempt_id", "idempotency_key",
    "intake_path", "status_path", "receipt_path", "return_path",
  ])
  let payload = review_receiver_strict_object(payload_json, "payload", [
    "action_kind", "run", "authority", "contracts", "inputs", "evidence", "review",
    "app_entrypoint",
  ])
  guard review_receiver_string(payload, "action_kind") == "open-product" &&
    payload.get("run") is Some(run_json) &&
    payload.get("authority") is Some(authority_json) &&
    payload.get("contracts") is Some(contracts_json) &&
    payload.get("inputs") is Some(inputs_json) &&
    payload.get("evidence") is Some(evidence_json) &&
    payload.get("review") is Some(review_json) &&
    payload.get("app_entrypoint") is Some(entrypoint_json) else {
    fail("MoonFind MoonFlow payload is incomplete")
  }
  let run = review_receiver_strict_object(run_json, "run", [
    "run_id", "book_id", "work_item_id", "declaration_id", "product_id", "operation",
    "issued_projection_sequence", "issued_work_item_status", "issued_run_outcome",
  ])
  let run_id = review_receiver_string(run, "run_id")
  let work_item_id = review_receiver_string(run, "work_item_id")
  let declaration_id = review_receiver_string(run, "declaration_id")
  guard run_id == config.run_id &&
    review_safe_identifier(run_id) &&
    review_safe_identifier(work_item_id) &&
    review_safe_identifier(declaration_id) &&
    review_receiver_string(run, "product_id") == "moonfind" &&
    review_receiver_string(run, "operation") == "moonfind/research.review@0.1.0" &&
    review_receiver_string(run, "issued_work_item_status") == "ready" else {
    fail(
      "MoonFind MoonFlow run identity or issued state does not match this pack",
    )
  }
  let token = review_receiver_string(binding, "handoff_token")
  let digest = review_receiver_string(binding, "handoff_digest")
  let endpoint = review_receiver_endpoint(run_id, token)
  guard review_receiver_safe_token(token) &&
    digest == "sha256:\{token}" &&
    digest == @store.digest_json(payload_json) &&
    review_receiver_string(binding, "request_id") ==
    "receiver-request-\{token[0:24]}" &&
    review_receiver_string(binding, "attempt_id") ==
    "receiver-attempt-\{token[0:24]}" &&
    review_receiver_string(binding, "idempotency_key") == "receiver-\{token}" &&
    review_receiver_string(binding, "intake_path") == endpoint &&
    review_receiver_string(binding, "status_path") == endpoint + "/status" &&
    review_receiver_string(binding, "receipt_path") == endpoint + "/receipt" &&
    review_receiver_string(binding, "return_path") == "/?activity=flow" else {
    fail("MoonFind rejected a MoonFlow receiver binding whose identity drifted")
  }
  let authority = review_receiver_strict_object(authority_json, "authority", [
    "requested_authority", "status", "granted",
  ])
  let requested_authority = review_receiver_string(
    authority, "requested_authority",
  )
  guard requested_authority == "workspace-mutation" &&
    review_receiver_string(authority, "status") == "requested" &&
    !review_receiver_bool(authority, "granted") else {
    fail("MoonFind requires an ungranted workspace-mutation authority request")
  }
  let contracts = review_receiver_strict_object(contracts_json, "contracts", [
    "capability_status", "input_contracts", "output_contracts", "required_claim",
    "claim_ceiling",
  ])
  let input_contracts = review_receiver_strings(contracts, "input_contracts")
  let output_contracts = review_receiver_strings(contracts, "output_contracts")
  guard review_receiver_string(contracts, "capability_status") ==
    "catalog-bound" &&
    input_contracts == ["moontown/civic-synthesis-result@1.0.0"] &&
    output_contracts == ["moonchat/conversation-review-bundle@1.0.0"] &&
    review_receiver_string(contracts, "required_claim") == "research-evidence" &&
    review_receiver_string(contracts, "claim_ceiling") == "research-evidence" else {
    fail("MoonFind MoonFlow contracts exceed portable review preparation")
  }
  let inputs = review_receiver_strict_object(inputs_json, "inputs", [
    "digest", "artifacts",
  ])
  let input_artifacts = review_receiver_strings(inputs, "artifacts")
  guard !input_artifacts.is_empty() &&
    input_artifacts.all(review_receiver_safe_ref) &&
    review_receiver_declared_digest(root, input_artifacts) ==
    review_receiver_string(inputs, "digest") else {
    fail("MoonFind MoonFlow input evidence is missing, unsafe, or changed")
  }
  let evidence = review_receiver_strict_object(evidence_json, "evidence", [
    "source_digest", "refs",
  ])
  ignore(review_receiver_string(evidence, "source_digest"))
  guard evidence.get("refs") is Some(Array(evidence_refs)) &&
    !evidence_refs.is_empty() else {
    fail("MoonFind MoonFlow handoff has no evidence references")
  }
  let mut matched_input_evidence = false
  for evidence_ref in evidence_refs {
    let fields = review_receiver_strict_object(
      evidence_ref,
      "evidence reference",
      ["kind", "reference", "digest"],
    )
    let kind = review_receiver_string(fields, "kind")
    let reference = review_receiver_string(fields, "reference")
    let reference_digest = review_receiver_string(fields, "digest")
    if kind == "input-artifact" {
      guard input_artifacts.contains(reference) &&
        @store.digest_text(
          @fs.read_file(review_receiver_path(root, reference)).text(),
        ) ==
        reference_digest else {
        fail("MoonFind MoonFlow input evidence reference changed")
      }
      matched_input_evidence = true
    }
  }
  guard matched_input_evidence else {
    fail("MoonFind MoonFlow handoff did not bind its input artifact evidence")
  }
  let review = review_receiver_strict_object(review_json, "review", [
    "required", "status", "acceptance_criteria",
  ])
  let acceptance_criteria = review_receiver_strings(
    review, "acceptance_criteria",
  )
  guard review_receiver_bool(review, "required") &&
    review_receiver_string(review, "status") == "required" &&
    !acceptance_criteria.is_empty() &&
    acceptance_criteria.all(review_receiver_supported_criterion) else {
    fail(
      "MoonFind cannot truthfully satisfy the declared MoonFlow review criteria",
    )
  }
  let entrypoint = review_receiver_strict_object(
    entrypoint_json,
    "app entrypoint",
    ["kind", "pack_id", "entrypoint_id", "path", "fallback_path"],
  )
  guard review_receiver_string(entrypoint, "kind") == "pack-manifest" &&
    review_receiver_string(entrypoint, "pack_id") == "moonfind" &&
    review_receiver_string(entrypoint, "path") == "/pack-apps/moonfind/" else {
    fail("MoonFind MoonFlow handoff targets a different pack entrypoint")
  }
  let base = review_receiver_base(run_id, token)
  @fs.mkdir(review_receiver_path(root, base), permission=0o700, recursive=true)
  review_receiver_write_immutable(root, base + "/intake.v2.json", intake)
  {
    root,
    run_id,
    work_item_id,
    declaration_id,
    token,
    digest,
    request_id: review_receiver_string(binding, "request_id"),
    attempt_id: review_receiver_string(binding, "attempt_id"),
    idempotency_key: review_receiver_string(binding, "idempotency_key"),
    requested_authority,
    output_contracts,
    acceptance_criteria,
    input_artifacts,
  }
}

///|
async fn validate_existing_moonflow_review_receipt(
  receiver : MoonFlowReviewReceiver,
  receipt : Json,
) -> Unit {
  let fields = review_receiver_strict_object(receipt, "receiver receipt", [
    "contract_id", "contract_version", "receipt_id", "handoff_token", "handoff_digest",
    "run_id", "work_item_id", "declaration_id", "product_id", "operation", "request_id",
    "attempt_id", "idempotency_key", "decision", "output_contracts", "output_artifacts",
    "output_digest", "authority", "review", "owner_id", "recorded_at",
  ])
  let artifacts = review_receiver_strings(fields, "output_artifacts")
  guard review_receiver_string(fields, "contract_id") ==
    "moonflow.receiver-receipt.v1" &&
    review_receiver_string(fields, "contract_version") == "1.0.0" &&
    review_receiver_string(fields, "handoff_token") == receiver.token &&
    review_receiver_string(fields, "handoff_digest") == receiver.digest &&
    review_receiver_string(fields, "run_id") == receiver.run_id &&
    review_receiver_string(fields, "work_item_id") == receiver.work_item_id &&
    review_receiver_string(fields, "declaration_id") == receiver.declaration_id &&
    review_receiver_string(fields, "product_id") == "moonfind" &&
    review_receiver_string(fields, "operation") ==
    "moonfind/research.review@0.1.0" &&
    review_receiver_string(fields, "request_id") == receiver.request_id &&
    review_receiver_string(fields, "attempt_id") == receiver.attempt_id &&
    review_receiver_string(fields, "idempotency_key") ==
    receiver.idempotency_key &&
    review_receiver_string(fields, "decision") == "accepted" &&
    review_receiver_strings(fields, "output_contracts") ==
    receiver.output_contracts &&
    review_receiver_declared_digest(receiver.root, artifacts) ==
    review_receiver_string(fields, "output_digest") else {
    fail("MoonFind persisted receiver receipt no longer matches its handoff")
  }
}

///|
pub async fn prepare_moonflow_review_receipt(
  config : Config,
  request : ReviewMoonFlowReceiptRequestV1,
) -> ReviewMoonFlowReceiptReplyV1 {
  guard request.contract_id == "moonfind.moonflow-review-receipt-request.v1" else {
    fail("unsupported MoonFind MoonFlow receipt request")
  }
  let receiver = decode_moonflow_review_receiver(config, request.intake)
  let base = review_receiver_base(receiver.run_id, receiver.token)
  let receipt_ref = base + "/receiver-receipt.v1.json"
  let receipt_path = review_receiver_path(receiver.root, receipt_ref)
  if @fs.exists(receipt_path) {
    let existing = @store.read_json(receipt_path)
    validate_existing_moonflow_review_receipt(receiver, existing)
    return {
      contract_id: "moonfind.moonflow-review-receipt-reply.v1",
      run_id: receiver.run_id,
      handoff_token: receiver.token,
      receipt_path: review_receiver_endpoint(receiver.run_id, receiver.token) +
      "/receipt",
      receiver_receipt: existing,
      message: "The exact MoonFind receiver receipt already exists and was replayed without mutation.",
    }
  }
  let (run, _, output, source_ref, source_digest) = review_inputs(config)
  guard receiver.input_artifacts.contains(source_ref) else {
    fail("MoonFlow handoff does not bind the immutable MoonTown synthesis")
  }
  let decision_path = run_artifact(config, "cross-product-review-decision.json")
  let bundle_path = run_artifact(config, "moonchat-review-bundle.json")
  guard @fs.exists(decision_path) && @fs.exists(bundle_path) else {
    fail("MoonFind has no durable named-human decision and MoonChat bundle")
  }
  let decision : @closed_loop.CrossProductReviewDecision = @json.from_json(
    @store.read_json(decision_path),
  )
  let expected_bundle = @closed_loop.moonchat_review_bundle(
    run, output, decision, source_ref, source_digest,
  )
  guard @fs.read_file(bundle_path).text() ==
    expected_bundle.stringify(indent=2) + "\n" else {
    fail("MoonFind MoonChat review bundle no longer matches its exact inputs")
  }
  let decision_ref = review_relative_run_ref(
    config, "cross-product-review-decision.json",
  )
  let bundle_ref = review_relative_run_ref(
    config, "moonchat-review-bundle.json",
  )
  let authority_ref = base + "/authority-receipt.v1.json"
  let review_ref = base + "/review-receipt.v1.json"
  let authority : Json = {
    "contract_id": "moonfind.moonflow-authority-receipt.v1",
    "contract_version": "1.0.0",
    "run_id": receiver.run_id,
    "work_item_id": receiver.work_item_id,
    "handoff_token": receiver.token,
    "handoff_digest": receiver.digest,
    "requested_authority": receiver.requested_authority,
    "decision": "granted",
    "scope": "persist the exact named-human decision and portable MoonChat bundle only",
    "reviewer_id": decision.reviewer_id,
    "review_id": decision.review_id,
    "recorded_at": decision.reviewed_at_utc,
  }
  review_receiver_write_immutable(receiver.root, authority_ref, authority)
  let evidence_refs = [source_ref, decision_ref, bundle_ref, authority_ref]
  let criteria_json : Array[Json] = receiver.acceptance_criteria.map(criterion => {
    "criterion": criterion,
    "satisfied": true,
    "evidence_refs": evidence_refs.copy(),
    "note": "MoonFind persisted the immutable source binding, named-human decision, explicit Three-Gap statements, and exact MoonChat bundle. No MoonBook acceptance or learning activation is claimed.",
  })
  let review_receipt : Json = {
    "contract_id": "moonfind.moonflow-output-review.v1",
    "contract_version": "1.0.0",
    "review_id": "review-\{receiver.token[0:24]}",
    "decision": "accepted",
    "scope": "operational bundle acceptance only; knowledge acceptance remains with MoonChat and MoonBook",
    "reviewer_id": decision.reviewer_id,
    "criteria": Json::array(criteria_json),
    "recorded_at": decision.reviewed_at_utc,
  }
  review_receiver_write_immutable(receiver.root, review_ref, review_receipt)
  let output_refs = evidence_refs + [review_ref]
  let receipt : Json = {
    "contract_id": "moonflow.receiver-receipt.v1",
    "contract_version": "1.0.0",
    "receipt_id": "receipt-\{receiver.token[0:24]}",
    "handoff_token": receiver.token,
    "handoff_digest": receiver.digest,
    "run_id": receiver.run_id,
    "work_item_id": receiver.work_item_id,
    "declaration_id": receiver.declaration_id,
    "product_id": "moonfind",
    "operation": "moonfind/research.review@0.1.0",
    "request_id": receiver.request_id,
    "attempt_id": receiver.attempt_id,
    "idempotency_key": receiver.idempotency_key,
    "decision": "accepted",
    "output_contracts": receiver.output_contracts,
    "output_artifacts": output_refs,
    "output_digest": review_receiver_declared_digest(receiver.root, output_refs),
    "authority": {
      "requested_authority": receiver.requested_authority,
      "decision": "granted",
      "receipt_ref": authority_ref,
    },
    "review": {
      "review_id": "review-\{receiver.token[0:24]}",
      "decision": "accepted",
      "reviewer_id": decision.reviewer_id,
      "review_authority_id": "moonfind-named-human-review-v1",
      "criteria": Json::array(criteria_json),
    },
    "owner_id": decision.reviewer_id,
    "recorded_at": decision.reviewed_at_utc,
  }
  review_receiver_write_immutable(receiver.root, receipt_ref, receipt)
  validate_existing_moonflow_review_receipt(receiver, receipt)
  {
    contract_id: "moonfind.moonflow-review-receipt-reply.v1",
    run_id: receiver.run_id,
    handoff_token: receiver.token,
    receipt_path: review_receiver_endpoint(receiver.run_id, receiver.token) +
    "/receipt",
    receiver_receipt: receipt,
    message: "MoonFind prepared a handoff-bound authority receipt, exact aggregate output digest, and complete acceptance evidence. The browser may now return this immutable receipt to MoonFlow.",
  }
}
