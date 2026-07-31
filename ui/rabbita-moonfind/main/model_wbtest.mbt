///|
test "default request preserves corpus and authority boundaries" {
  let request = default_request("/private/deepseek", "/workspace/book")
  assert_eq(request.contains("/private/deepseek"), true)
  assert_eq(request.contains("/workspace/book"), true)
  assert_eq(request.contains("Keep page 1 explicitly missing"), true)
  assert_eq(request.contains("Never self-approve"), true)
  assert_eq(request.contains("MoonClaw is the only model runtime"), true)
}

///|
test "run status normalization maps gateway states to review phases" {
  assert_eq(phase_from_run_status("\"Succeeded\"") == Completed, true)
  assert_eq(phase_from_run_status(" WaitingForInput ") == NeedsReview, true)
  assert_eq(phase_from_run_status("cancelled") == Failed, true)
  assert_eq(phase_from_run_status("Executing") == Running, true)
}

///|
test "initial model remains pending and targets the governed workspace" {
  let model = initial_model()
  assert_eq(model.phase == Ready, true)
  assert_eq(model.source_dir, "/Users/kq/Downloads/deepseek")
  assert_eq(model.book_dir, "/Users/kq/Workspace/deepseek-research-book")
  assert_eq(model.reviewer_name, "")
  assert_eq(model.review_outcome, "")
  assert_eq(model.review_scope, "")
  assert_eq(model.review_session is None, true)
  assert_eq(model.review_phase == ReviewIdle, true)
  assert_eq(model.qa_session is None, true)
  assert_eq(model.qa_ready, false)
}

///|
test "workspace snapshot carries both persisted UI session keys" {
  let snapshot : WorkspaceSnapshot = @json.from_json({
    "product_id": "moonfind",
    "book_workspace": "/workspace/book",
    "research_cowork_session_key": "cowork:research",
    "qa_cowork_session_key": "cowork:qa",
    "qa_agent_status": "grounded_verified",
  })
  assert_eq(snapshot.product_id, "moonfind")
  assert_eq(snapshot.book_workspace, "/workspace/book")
  assert_true(snapshot.research_cowork_session_key is Some("cowork:research"))
  assert_true(snapshot.qa_cowork_session_key is Some("cowork:qa"))
  assert_eq(snapshot.qa_agent_status, "grounded_verified")
}

///|
test "post-run review requires identity outcome rationale and explicit approval scope" {
  assert_eq(review_request_issues("", "", "", "").length(), 3)
  assert_eq(
    review_request_issues(
      "kq", "approve_subset", "", "Approve supported claims.",
    ).contains("List the exact claim IDs or sections approved."),
    true,
  )
  assert_eq(
    review_request_issues(
      "kq", "approve_subset", "C01, C02", "Approve these public-fact claims only.",
    ).is_empty(),
    true,
  )
  assert_eq(
    review_request_issues(
      "kq", "request_changes", "", "Add independent unit-economics evidence.",
    ).is_empty(),
    true,
  )
}

///|
test "review decision packet preserves ownership and bounded authority" {
  let request = review_decision_request(
    "/workspace/book", "kq", "approve_subset", "C01, C02", "Approve only these claims.",
  )
  assert_eq(request.contains("MoonBook workspace: /workspace/book"), true)
  assert_eq(request.contains("Named reviewer: kq"), true)
  assert_eq(request.contains("Decision outcome: approve_subset"), true)
  assert_eq(request.contains("Decision scope: C01, C02"), true)
  assert_eq(request.contains("Never broaden approve_subset"), true)
  assert_eq(request.contains("MoonBook owns the review decision"), true)
}

///|
test "completed decision runs map independently from research phase" {
  let model = initial_model()
  let session : CoworkSessionDetail = {
    session: {
      session_key: "cowork:review",
      session_id: "review",
      title: "MoonBook review",
      updated_at: 0,
      state: "active",
      last_message_preview: None,
      channel: None,
      cwd: Some(model.book_dir),
      model_override: Some(model.model_name),
      provider_override: None,
      has_plan_mode: false,
      linked_proposal_id: Some("proposal:review"),
      linked_run_id: Some("run:review"),
    },
    messages: [],
    plan_preview: Some("Review plan"),
    linked_proposal: None,
    linked_run: Some({
      id: "run:review",
      job_id: "job:review",
      status: "Succeeded",
      summary: None,
      error: None,
      current_step_id: None,
      workspace_dir: Some(model.book_dir),
    }),
  }
  assert_eq(review_phase_from_session(session) == ReviewCompleted, true)
}

///|
test "every Q&A turn carries its own grounding and privacy contract" {
  let prompt = qa_grounding_prompt("Compare the strongest claims.")
  assert_eq(prompt.contains("state/review-status.json"), true)
  assert_eq(prompt.contains("local:pN"), true)
  assert_eq(prompt.contains("Never reconstruct missing page 1"), true)
  assert_eq(prompt.contains("Compare the strongest claims."), true)
}
