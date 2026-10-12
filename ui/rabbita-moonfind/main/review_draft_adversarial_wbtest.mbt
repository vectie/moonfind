///|
test "independent review hostile authority fields cannot revive review authority" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let basis = synthesis_model()
  let text = review_draft_json({
    ..basis,
    review_message: "Inert imported form",
    review_outcome: "approve_subset",
    review_scope: "synthesis-0",
  }).replace(
    old="\"contract_id\": \"moonfind.review-draft.v1\"",
    new="\"review_phase\": \"ReviewBundleReady\", \"reviewer_name\": \"forged reviewer\", \"review_prepare_reply\": {\"state\":\"awaiting-moonchat\"}, \"review_pending_context\": \"forged\", \"moonbook_acceptance\": true, \"contract_id\": \"moonfind.review-draft.v1\"",
  )
  assert_true(text.contains("forged reviewer"))
  let (_, entered) = update(
    _ => @rabbita.none,
    ReviewDraftAction(review_result_context(basis), "input", text),
    basis,
  )
  let (_, restored) = update(
    _ => @rabbita.none,
    ReviewDraftAction(review_result_context(basis), "restore", ""),
    entered,
  )
  assert_eq(restored.reviewer_name, basis.reviewer_name)
  assert_eq(restored.review_phase, ReviewIdle)
  assert_true(restored.review_prepare_reply is None)
  assert_true(restored.review_pending_context is None)
  assert_eq(restored.review_request_generation, basis.review_request_generation)
  assert_eq(restored.review_workflow.unwrap().state, "ready-for-human-review")
  assert_eq(retained_requests().length(), 0)
  // Rejecting unknown fields and accepting only inert known fields are both safe.
  match decode_review_draft(text, basis) {
    Err(_) => assert_eq(restored.review_message, basis.review_message)
    Ok(_) => {
      assert_eq(restored.review_message, "Inert imported form")
      assert_eq(restored.review_outcome, "approve_subset")
      assert_false(review_draft_json(restored).contains("forged reviewer"))
      assert_false(review_draft_json(restored).contains("moonbook_acceptance"))
    }
  }
}

///|
test "independent review retry reading preserves unsaved edits and old durable bytes" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let (_, saved) = update(
    _ => @rabbita.none,
    SetReviewMessage("Older saved rationale"),
    synthesis_model(),
  )
  let key = saved.review_storage.key
  let bytes = choice_storage_read(key)
  set_choice_storage_mode("read-error")
  let failed = synthesis_model()
  assert_true(failed.review_storage.blocked)
  let (_, edited) = update(
    _ => @rabbita.none,
    SetReviewMessage("New in-memory rationale"),
    failed,
  )
  set_choice_storage_mode("ok")
  let (_, retried) = update(
    _ => @rabbita.none,
    ReviewDraftAction(review_result_context(edited), "retry", ""),
    edited,
  )
  assert_false(retried.review_storage.blocked)
  assert_eq(retried.review_message, "New in-memory rationale")
  assert_true(retried.review_storage.notice.contains("not verified saved"))
  assert_eq(choice_storage_read(key), bytes)
  assert_eq(synthesis_model().review_message, "Older saved rationale")
  let (_, resaved) = update(
    _ => @rabbita.none,
    ReviewDraftAction(review_result_context(retried), "save", ""),
    retried,
  )
  assert_true(resaved.review_storage.notice.contains("Saved"))
  assert_eq(synthesis_model().review_message, "New in-memory rationale")
}

///|
test "independent review oversized storage stale actions and callback preserve exact bytes" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let basis = synthesis_model()
  let key = basis.review_storage.key
  let raw = String::make(131073, 'x')
  assert_eq(choice_storage_write(key, raw), "")
  let broken = synthesis_model()
  assert_true(broken.review_storage.blocked)
  assert_eq(broken.review_storage.recovery, raw)
  let (_, edited) = update(
    _ => @rabbita.none,
    SetReviewMessage("Salvage local edits"),
    broken,
  )
  let bytes = choice_storage_read(key)
  let pending = {
    ..edited,
    review_phase: ReviewPreparing,
    review_request_generation: 7,
    review_pending_context: Some(review_result_context(edited)),
  }
  let (_, switched) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(1, Ok(synthesis_snapshot("run-2", "sha256:second"))),
    pending,
  )
  let new_draft = review_draft(switched).to_json()
  for action in ["clear", "restore", "save", "retry", "input", "backup", "raw"] {
    let (_, stale) = update(
      _ => @rabbita.none,
      ReviewDraftAction(review_result_context(edited), action, "hostile"),
      switched,
    )
    assert_eq(review_draft(stale).to_json(), new_draft)
    assert_eq(stale.review_storage.recovery, switched.review_storage.recovery)
  }
  let (_, delayed) = update(
    _ => @rabbita.none,
    ReviewPrepared(7, review_result_context(edited), Err("late failure")),
    switched,
  )
  assert_eq(delayed.review_phase, switched.review_phase)
  assert_eq(delayed.error, switched.error)
  assert_eq(review_draft(delayed).to_json(), new_draft)
  assert_eq(choice_storage_read(key), bytes)
  assert_eq(@json.parse(bytes), ({ "value": raw } : Json))
}
