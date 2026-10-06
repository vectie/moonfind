///|
fn retained_choice_fixture(outcome : String) -> ReviewDecisionReceipt {
  {
    review_id: "moonfind-review-run-1",
    reviewer_id: "reviewer-run-1",
    reviewer_name: "Avery <Chen>",
    outcome,
    rationale: "Retain dissent & uncertainty; do not omit B's lower error",
    accepted_idea_ids: if outcome == "approve" {
      ["synthesis-0"]
    } else {
      []
    },
    rejected_idea_ids: if outcome == "approve" {
      []
    } else {
      ["synthesis-0"]
    },
    objections: ["B reports <lower error>", "The next test is still required"],
    source_ref: "runs/run-1/moontown-reducer-output.json",
    source_digest: "sha256:first",
    source_revision_id: "moontown-run-1",
    source_current: true,
    review_status: match outcome {
      "approve" => "accepted"
      "reject" => "rejected"
      _ => "pending_review"
    },
    delivery_status: "linked",
    evidence_status: "typed-validated",
    record_ref: Some("runs/run-1/moonchat-review-record.raw.json"),
    record_digest: Some("sha256:record"),
    bookkeeper_state: "not-acknowledged",
    detail: "Exact decision retained; Book acceptance is separate",
  }
}

///|
fn receipt_snapshot(outcome : String, delivery : String) -> WorkspaceSnapshot {
  let snapshot = synthesis_snapshot("run-1", "sha256:first")
  let receipt = {
    ..retained_choice_fixture(outcome),
    delivery_status: delivery,
  }
  {
    ..snapshot,
    review_workflow: {
      ..snapshot.review_workflow,
      state: if delivery == "pending-return" {
        "awaiting-moonchat"
      } else {
        match outcome {
          "approve" => "ready-for-bookkeeper"
          "reject" => "review-rejected"
          _ => "review-deferred"
        }
      },
      prepare_url: None,
      decision_receipt: Some(receipt),
    },
  }
}

///|
test "three saved decisions restore exact identity dissent and separate receiver status on fresh model" {
  for outcome in ["approve", "reject", "defer"] {
    let (_, model) = update(
      _ => @rabbita.none,
      WorkspaceLoaded(1, Ok(receipt_snapshot(outcome, "linked"))),
      initial_model(),
    )
    let html = qa_test_render(model)
    for
      expected in [
        "Saved decision", "Avery &lt;Chen&gt;", "Retain dissent &amp; uncertainty",
        "B reports &lt;lower error&gt;", "The next test is still required", "sha256:first",
        "sha256:record", "reviewer-run-1", "not-acknowledged", "Refresh retained decision",
      ] {
      assert_true(html.contains(expected), msg=outcome + ": " + expected)
    }
    assert_false(html.contains("Avery <Chen>"))
    assert_eq(model.review_phase, ReviewBundleReady)
    assert_eq(model.review_outcome, "")
    assert_false(html.contains("Prepare MoonChat review bundle"))
    if outcome == "defer" {
      assert_true(html.contains("Deferred / unresolved"))
      assert_true(html.contains("pending_review"))
      assert_true(html.contains("Changes requested / not approved IDs"))
      assert_eq(
        research_journey_state(
          true, true, "completed", "needs-review", "review-deferred", false,
        ).title,
        "Revisit the deferred decision",
      )
    }
    if outcome == "reject" {
      assert_true(html.contains("Rejected version"))
    }
  }
}

///|
test "pending return remains visible after reload and refresh is read-only" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let (_, model) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(1, Ok(receipt_snapshot("defer", "pending-return"))),
    initial_model(),
  )
  assert_true(qa_test_render(model).contains("Receipt return: pending-return"))
  let (cell, dispatch) = retained_harness(model)
  ignore(dispatch(RefreshMoonTownStatus))
  assert_true(
    retained_requests()[0]
    is { "method": "GET", "url": "/api/v1/workspace", .. },
  )
  assert_eq(cell.val.review_outcome, "")
  assert_true(cell.val.review_prepare_reply is None)
}

///|
test "changed source digest revision or path cannot appear current and preserves history" {
  for
    receipt in [
      { ..retained_choice_fixture("approve"), source_digest: "sha256:old", },
      {
        ..retained_choice_fixture("approve"),
        source_revision_id: "moontown-other-run",
      },
      { ..retained_choice_fixture("approve"), source_ref: "other/source.json", },
      { ..retained_choice_fixture("approve"), source_current: false, },
    ] {
    let snapshot = receipt_snapshot("approve", "linked")
    let (_, model) = update(
      _ => @rabbita.none,
      WorkspaceLoaded(
        1,
        Ok({
          ..snapshot,
          review_workflow: {
            ..snapshot.review_workflow,
            decision_receipt: Some(receipt),
          },
        }),
      ),
      initial_model(),
    )
    let html = qa_test_render(model)
    assert_true(html.contains("Stale review"))
    assert_true(html.contains("role=\"alert\""))
    assert_true(html.contains("Retain dissent &amp; uncertainty"))
  }
}

///|
test "defer retains existing request changes wire and never sends approved IDs" {
  install_question_http_fixture()
  defer restore_question_http_fixture()
  let model = {
    ..synthesis_model(),
    reviewer_name: "Avery",
    review_outcome: "request_changes",
    review_scope: "synthesis-0",
    review_message: "Wait for the matched trial",
  }
  let (_, dispatch) = retained_harness(model)
  ignore(dispatch(PrepareReview))
  assert_true(
    retained_requests()[0]
    is {
      "method": "POST",
      "url": "/api/v1/review/prepare",
      "body": {
        "outcome": "request_changes",
        "accepted_idea_ids": [],
        "rejected_idea_ids": ["synthesis-0"],
        "source_digest": "sha256:first",
        ..
      },
      ..
    },
  )
  assert_true(qa_test_render(model).contains("Defer / request changes"))
}

///|
test "damaged or stale review never labels its retained Book submission ready" {
  for state in ["review-evidence-invalid", "review-stale"] {
    let snapshot = receipt_snapshot("approve", "pending-return")
    let (_, model) = update(
      _ => @rabbita.none,
      WorkspaceLoaded(
        1,
        Ok({
          ..snapshot,
          review_workflow: {
            ..snapshot.review_workflow,
            state,
            decision_receipt: None,
            bookkeeper_submission_ref: Some("retained/submission.json"),
          },
        }),
      ),
      initial_model(),
    )
    let html = qa_test_render(model)
    assert_true(html.contains("RETAINED MOONBOOK SUBMISSION"))
    assert_false(html.contains("READY FOR MOONBOOK"))
    assert_true(html.contains("not ready for a new handoff"))
  }
}
