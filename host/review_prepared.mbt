///|
fn review_prepared_name() -> String {
  "moonchat-review-prepared.json"
}

///|
priv struct PreparedReviewBinding {
  contract_id : String
  format : String
  run_id : String
  review_id : String
  source_ref : String
  source_digest : String
  decision_digest : String
  bundle_digest : String
} derive(Eq, ToJson, FromJson)

///|
fn prepared_review_binding(
  config : Config,
  source_ref : String,
  source_digest : String,
  decision_text : String,
  bundle_text : String,
) -> PreparedReviewBinding {
  {
    contract_id: "moonfind.moonchat-review-prepared.v1",
    format: "moonfind.typed-moonchat-review.v1",
    run_id: config.run_id,
    review_id: review_id(config.run_id),
    source_ref,
    source_digest,
    decision_digest: @store.digest_text(decision_text),
    bundle_digest: @store.digest_text(bundle_text),
  }
}

///|
// Old v1 conversation evidence is readable history only. Every new-format
// bundle must match the durable preparation binding written before it. A
// Book submission or missing return marker never determines the format.
async fn validate_prepared_review_binding(
  config : Config,
  bundle : @review.ConversationReviewBundle,
  bundle_text : String,
) -> Unit {
  let path = run_artifact(config, review_prepared_name())
  if bundle.conversation.contract_id == "moonsuite-conversation.v1" &&
    !@fs.exists(path) {
    return
  }
  guard @fs.exists(path) &&
    bundle.conversation.contract_id == @review.conversation_contract_id() else {
    fail(
      "The typed review preparation binding is missing or incompatible; retry the original preparation or restore the exact retained files",
    )
  }
  let retained : PreparedReviewBinding = @json.from_json(@store.read_json(path))
  let expected = prepared_review_binding(
    config,
    bundle.source_artifact_ref,
    bundle.source_digest,
    @fs.read_file(run_artifact(config, "cross-product-review-decision.json")).text(),
    bundle_text,
  )
  guard retained == expected else {
    fail(
      "The retained decision or bundle changed after preparation; restore its exact original bytes",
    )
  }
}
