///|
test "review draft fresh model restores exact fields without authority or submission" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let mut model = synthesis_model()
  for
    message in [
      SetReviewOutcome("reject"),
      SetReviewScope("synthesis-0"),
      SetReviewMessage("Retain dissent 月面 🌒\r\n<script>"),
      SetInformationGapSeverity("5"),
      SetInformationGapSummary("Missing replication"),
      SetRecognitionGapSeverity("2"),
      SetRecognitionGapSummary("Conflicting sources"),
      SetDecisivenessGapSeverity("3"),
      SetDecisivenessGapSummary("Need next experiment"),
    ] {
    let (_, next) = update(_ => @rabbita.none, message, model)
    model = next
  }
  assert_true(model.review_storage.notice.contains("Saved"))
  let restored = synthesis_model()
  assert_eq(review_draft(restored).to_json(), review_draft(model).to_json())
  assert_eq(restored.review_phase, ReviewIdle)
  assert_true(restored.review_pending_context is None)
  assert_true(restored.review_prepare_reply is None)
  assert_eq(retained_requests().length(), 0)
  let html = qa_test_render(restored)
  assert_true(html.contains("&lt;script&gt;"))
  assert_false(html.contains("<script>"))
  assert_true(html.contains("No approval, receipt or submission was restored"))
}

///|
test "review draft persisted Book run digest scopes are independent and retain old bytes" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let (_, first) = update(
    _ => @rabbita.none,
    SetReviewMessage("First exact source"),
    synthesis_model(),
  )
  let old_key = first.review_storage.key
  let old_bytes = choice_storage_read(old_key)
  for
    snapshot in [
      synthesis_snapshot("run-1", "sha256:second"),
      synthesis_snapshot("run-2", "sha256:first"),
      {
        ..synthesis_snapshot("run-1", "sha256:first"),
        book_workspace: "/other/book",
      },
    ] {
    let (_, changed) = update(
      _ => @rabbita.none,
      WorkspaceLoaded(1, Ok(snapshot)),
      first,
    )
    assert_eq(changed.review_message, "")
    assert_eq(changed.review_scope, "")
    assert_eq(changed.review_outcome, "")
    assert_false(changed.review_storage.key == old_key)
    assert_eq(choice_storage_read(old_key), old_bytes)
  }
  assert_eq(synthesis_model().review_message, "First exact source")
}

///|
test "review draft corruption pauses writes and explicit valid restore recovers" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let basis = synthesis_model()
  let good = review_draft_json({
    ..basis,
    review_message: "Recovered rationale",
  })
  assert_eq(choice_storage_write(basis.review_storage.key, "{broken"), "")
  let broken = synthesis_model()
  assert_true(broken.review_storage.blocked)
  assert_eq(broken.review_storage.recovery, "{broken")
  let (_, edited) = update(
    _ => @rabbita.none,
    SetReviewMessage("Unsaved repair"),
    broken,
  )
  assert_eq(
    @json.parse(choice_storage_read(basis.review_storage.key)),
    ({ "value": "{broken" } : Json),
  )
  let context = review_result_context(edited)
  let invalid = update_review_draft(edited, context, "restore", "")
  assert_true(invalid.review_storage.blocked)
  let recovered = update_review_draft(
    update_review_draft(edited, context, "input", good),
    context,
    "restore",
    "",
  )
  assert_false(recovered.review_storage.blocked)
  assert_eq(synthesis_model().review_message, "Recovered rationale")
  assert_true(recovered.review_prepare_reply is None)
}

///|
test "review draft quota read failure retry and explicit clear preserve honest status" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = synthesis_model()
  set_choice_storage_mode("quota")
  let (_, unsaved) = update(
    _ => @rabbita.none,
    SetReviewMessage("Keep this edit"),
    model,
  )
  assert_true(unsaved.review_storage.notice.contains("save failed"))
  assert_eq(unsaved.review_message, "Keep this edit")
  let (_, switched) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(1, Ok(synthesis_snapshot("run-2", "sha256:second"))),
    unsaved,
  )
  let (_, back) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(1, Ok(synthesis_snapshot("run-1", "sha256:first"))),
    switched,
  )
  assert_eq(back.review_message, "Keep this edit")
  assert_true(back.review_storage.notice.contains("not verified saved"))
  set_choice_storage_mode("ok")
  let saved = update_review_draft(
    unsaved,
    review_result_context(unsaved),
    "save",
    "",
  )
  assert_eq(synthesis_model().review_message, "Keep this edit")
  set_choice_storage_mode("read-error")
  let unreadable = synthesis_model()
  assert_true(unreadable.review_storage.blocked)
  set_choice_storage_mode("ok")
  let cleared = update_review_draft(
    saved,
    review_result_context(saved),
    "clear",
    "",
  )
  assert_eq(cleared.review_message, "")
  assert_eq(synthesis_model().review_message, "")
  assert_false(cleared.review_storage.blocked)
}

///|
test "review draft wrong version context severity and oversize backups fail closed" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = synthesis_model()
  let text = review_draft_json(model)
  let missing_book = { ..model, trusted_book_dir: "  ", }
  assert_true(current_synthesis(missing_book) is Some(_))
  assert_false(result_review_issues(missing_book).is_empty())
  assert_eq(
    toggle_result_idea(
      missing_book,
      review_result_context(missing_book),
      "synthesis-0",
    ).review_scope,
    "",
  )
  assert_true(
    decode_review_draft(review_draft_json(missing_book), missing_book) is Err(_),
  )
  assert_eq(restore_review_storage(missing_book, None).review_storage.key, "")
  let missing_key = "moonfind.review-draft.v1:" +
    review_result_context(missing_book)
  let guarded = {
    ..missing_book,
    review_message: "Keep inert form",
    review_storage: {
      ..missing_book.review_storage,
      key: missing_key,
      recovery: "retained text",
    },
  }
  assert_eq(choice_storage_write(missing_key, "sentinel original bytes"), "")
  assert_eq(save_review_draft(guarded).review_message, "Keep inert form")
  for action in ["clear", "restore", "save", "retry", "input", "backup", "raw"] {
    let unchanged = update_review_draft(
      guarded,
      review_result_context(guarded),
      action,
      "hostile",
    )
    assert_eq(
      review_draft(unchanged).to_json(),
      review_draft(guarded).to_json(),
    )
    assert_eq(unchanged.review_storage.recovery, "retained text")
  }
  assert_eq(
    @json.parse(choice_storage_read(missing_key)),
    ({ "value": "sentinel original bytes" } : Json),
  )
  assert_true(
    qa_test_render(guarded).contains("Trusted Book context is missing"),
  )
  assert_true(decode_review_draft(text, model) is Ok(_))
  for
    bad in [
      text.replace(
        old="moonfind.review-draft.v1",
        new="moonfind.review-draft.v999",
      ),
      text.replace(old="sha256:first", new="sha256:changed"),
      review_draft_json({ ..model, information_gap_severity: 6, }),
      review_draft_json({ ..model, review_scope: "not-an-exact-id", }),
      String::make(131073, 'x'),
    ] {
    assert_true(decode_review_draft(bad, model) is Err(_))
  }
}

///|
test "review draft pending preparation and stale context cannot restore or clear" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = {
    ..synthesis_model(),
    review_message: "Current",
    review_phase: ReviewPreparing,
  }
  let text = review_draft_json({ ..model, review_message: "Imported", })
  let entered = update_review_draft(
    model,
    review_result_context(model),
    "input",
    text,
  )
  for action in ["restore", "clear", "save", "retry"] {
    let next = update_review_draft(
      entered,
      review_result_context(model),
      action,
      "",
    )
    assert_eq(next.review_message, "Current")
    assert_eq(next.review_phase, ReviewPreparing)
  }
  assert_eq(
    update_review_draft(entered, "stale", "clear", "").review_message,
    "Current",
  )
}

///|
test "review draft restored form cannot override native prepared workflow" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let (_, drafted) = update(
    _ => @rabbita.none,
    SetReviewMessage("Draft before native preparation"),
    synthesis_model(),
  )
  assert_true(drafted.review_storage.notice.contains("Saved"))
  let snapshot = synthesis_snapshot("run-1", "sha256:first")
  let (_, returned) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(
      1,
      Ok({
        ..snapshot,
        review_workflow: {
          ..snapshot.review_workflow,
          state: "awaiting-moonchat",
          prepare_url: None,
          bundle_ref: Some("native-retained-bundle"),
        },
      }),
    ),
    initial_model(),
  )
  assert_eq(returned.review_phase, ReviewBundleReady)
  assert_eq(
    returned.review_workflow.unwrap().bundle_ref,
    Some("native-retained-bundle"),
  )
  assert_true(returned.review_prepare_reply is None)
  assert_true(returned.review_pending_context is None)
}
