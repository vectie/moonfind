///|
struct CompletedResultEnvelope {
  contract_id : String
  idempotency_key : String
  run_id : String
  handoff_id : String
  receipt_ref : String
  output_ref : String
  receipt_digest : String
  output_digest : String
  review_status : String
  source : Json
} derive(FromJson)

///|
async fn completed_result_view(
  config : Config,
  town : MoonTownHandoffStatusV1,
) -> MoonTownResultViewV1 {
  let unavailable : MoonTownResultViewV1 = {
    contract_id: "moonfind.moontown-result-view.v1",
    run_id: config.run_id,
    state: "unavailable",
    detail: town.detail,
    source_ref: None,
    source_digest: None,
    output: None,
  }
  guard town.state == "ingested-pending-review" else { return unavailable }
  try {
    let handoff : @moontown.TownResearchHandoff = @json.from_json(
      @store.read_json(run_artifact(config, "moontown-handoff.json")),
    )
    let envelope : CompletedResultEnvelope = @json.from_json(
      @store.read_json(run_artifact(config, "moontown-result-ingest-v1.json")),
    )
    let receipt : @moontown.TownExecutionReceipt = @json.from_json(
      @store.read_json(run_artifact(config, "moontown-receipt.json")),
    )
    let text = @fs.read_file(
      run_artifact(config, "moontown-reducer-output.json"),
    ).text()
    let output : @moontown.TownSynthesisOutput = @json.from_json(
      @json.parse(text),
    )
    let request : @moontown.TownResultIngestRequest = {
      contract_id: envelope.contract_id,
      idempotency_key: envelope.idempotency_key,
      handoff_id: envelope.handoff_id,
      producer_run_id: envelope.run_id,
      receipt,
      output,
      source: envelope.source,
    }
    let issues = @moontown.validate_town_result_ingest(
      request,
      handoff,
      config.run_id,
    )
    guard issues.is_empty() &&
      envelope.run_id == config.run_id &&
      envelope.receipt_ref == "moontown-receipt.json" &&
      envelope.output_ref == "moontown-reducer-output.json" &&
      envelope.review_status == "pending" &&
      envelope.receipt_digest == @store.digest_json(receipt.to_json()) &&
      envelope.output_digest == @store.digest_json(output.to_json()) else {
      return {
        ..unavailable,
        detail: "The reducer output, receipt, and immutable ingest envelope no longer agree. Reload after restoring the exact correlated result; no result IDs are available for selection.",
      }
    }
    {
      ..unavailable,
      state: "available",
      detail: "Correlated MoonTown synthesis. Validation confirms the artifact binding, not its scientific claims or human acceptance.",
      source_ref: Some(
        review_relative_run_ref(config, "moontown-reducer-output.json"),
      ),
      source_digest: Some(@store.digest_text(text)),
      output: Some(output),
    }
  } catch {
    _ =>
      {
        ..unavailable,
        detail: "The completed synthesis is missing or malformed. Restore its correlated output, receipt, and ingest envelope, then reload.",
      }
  }
}
