///|
test "review preparation surfaces typed host errors without weakening success decoding" {
  let error_payload : Json = {
    "error": {
      "contract_id": "moonfind.ui-host-error.v1",
      "message": "immutable bundle could not be created",
    },
  }
  match decode_review_prepare(Ok(error_payload)) {
    Err(message) => assert_eq(message, "immutable bundle could not be created")
    Ok(_) => fail("typed host error must not decode as a review receipt")
  }
  let malformed : Json = {
    "contract_id": "moonfind.review-prepare-reply.v1",
    "run_id": "run-1",
  }
  assert_true(decode_review_prepare(Ok(malformed)) is Err(_))
  let reply : Json = {
    "contract_id": "moonfind.review-prepare-reply.v1",
    "state": "awaiting-moonchat",
    "run_id": "run-1",
    "review_id": "review-1",
    "source_ref": "runs/run-1/source.json",
    "source_digest": "sha256:0000000000000000000000000000000000000000000000000000000000000000",
    "bundle_ref": "runs/run-1/bundle.json",
    "operation_ref": "moonchat/conversation.review.record@0.1.0",
    "message": "ready",
  }
  match decode_review_prepare(Ok(reply)) {
    Ok(decoded) => {
      assert_eq(decoded.state, "awaiting-moonchat")
      assert_eq(decoded.run_id, "run-1")
    }
    Err(error) => fail("valid review receipt was rejected: \{error}")
  }
}
