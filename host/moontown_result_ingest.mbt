///|
async fn ensure_immutable_run_json(
  config : Config,
  name : String,
  value : Json,
) -> String {
  ignore(@store.ensure_run_directory(config.workspace, config.run_id))
  let path = run_artifact(config, name)
  let text = value.stringify(indent=2) + "\n"
  if @fs.exists(path) {
    guard @fs.read_file(path).text() == text else {
      fail("MoonFind immutable MoonTown artifact conflicts: \{name}")
    }
    return name
  }
  @fs.write_file(
    path,
    text,
    create_mode=@fs.CreateNew,
    permission=0o600,
    sync=@fs.Full,
  ) catch {
    _ => {
      guard @fs.exists(path) else {
        fail("MoonFind could not create immutable MoonTown artifact: \{name}")
      }
      guard @fs.read_file(path).text() == text else {
        fail("MoonFind could not create immutable MoonTown artifact: \{name}")
      }
    }
  }
  name
}

///|
pub async fn ingest_moontown_result(
  config : Config,
  request : @moontown.TownResultIngestRequest,
) -> MoonTownResultIngestReplyV1 {
  let handoff_path = run_artifact(config, "moontown-handoff.json")
  guard @fs.exists(handoff_path) else {
    fail("MoonFind has no durable MoonTown handoff for this run")
  }
  let handoff : @moontown.TownResearchHandoff = @json.from_json(
    @store.read_json(handoff_path),
  )
  let issues = @moontown.validate_town_result_ingest(
    request,
    handoff,
    config.run_id,
  )
  guard issues.is_empty() else {
    fail("MoonTown result correlation failed: " + issues.join("; "))
  }
  let receipt_ref = "moontown-receipt.json"
  let output_ref = "moontown-reducer-output.json"
  let envelope_ref = "moontown-result-ingest-v1.json"
  let envelope : Json = {
    "contract_id": request.contract_id,
    "idempotency_key": request.idempotency_key,
    "run_id": config.run_id,
    "handoff_id": request.handoff_id,
    "receipt_ref": receipt_ref,
    "output_ref": output_ref,
    "receipt_digest": @store.digest_json(request.receipt.to_json()),
    "output_digest": @store.digest_json(request.output.to_json()),
    "review_status": request.receipt.review_status,
    "source": request.source,
  }
  // Preflight all existing files before creating any new artifact. This makes
  // replay idempotent and prevents a conflicting callback from partially
  // replacing the accepted execution identity.
  let receipt_path = run_artifact(config, receipt_ref)
  if @fs.exists(receipt_path) {
    if @fs.read_file(receipt_path).text() !=
      request.receipt.to_json().stringify(indent=2) + "\n" {
      fail("MoonFind immutable MoonTown artifact conflicts: \{receipt_ref}")
    }
  }
  let output_path = run_artifact(config, output_ref)
  if @fs.exists(output_path) {
    if @fs.read_file(output_path).text() !=
      request.output.to_json().stringify(indent=2) + "\n" {
      fail("MoonFind immutable MoonTown artifact conflicts: \{output_ref}")
    }
  }
  let envelope_path = run_artifact(config, envelope_ref)
  if @fs.exists(envelope_path) {
    if @fs.read_file(envelope_path).text() !=
      envelope.stringify(indent=2) + "\n" {
      fail("MoonFind immutable MoonTown artifact conflicts: \{envelope_ref}")
    }
  }
  ignore(
    ensure_immutable_run_json(config, receipt_ref, request.receipt.to_json()),
  )
  ignore(
    ensure_immutable_run_json(config, output_ref, request.output.to_json()),
  )
  ignore(ensure_immutable_run_json(config, envelope_ref, envelope))
  {
    contract_id: "moonfind.moontown-result-ingest.reply.v1",
    state: "ingested-pending-review",
    run_id: config.run_id,
    handoff_id: request.handoff_id,
    receipt_status: request.receipt.status,
    review_status: request.receipt.review_status,
    idea_count: request.output.ideas.length(),
    receipt_ref,
    output_ref,
    envelope_ref,
    message: "MoonTown result is durably correlated and remains pending named-human MoonBook review.",
  }
}
