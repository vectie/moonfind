///|
fn decode_session(
  result : Result[CoworkSessionPayload, Error],
) -> Result[CoworkSessionDetail, String] {
  match result {
    Ok(payload) => Ok(payload.session)
    Err(error) => Err("\{error}")
  }
}

///|
fn decode_execution(
  result : Result[ResearchExecutionPayload, Error],
) -> Result[ResearchExecutionProjection, String] {
  match result {
    Ok(payload) => Ok(payload.execution)
    Err(error) => Err("\{error}")
  }
}

///|
fn load_workspace_snapshot(emit : @rabbita.Emit[Msg]) -> @rabbita.Cmd {
  @http.get("/moonfind-workspace.json").expect_json(
    emit.map(result => {
      WorkspaceLoaded(
        match result {
          Ok(snapshot) => Ok(snapshot)
          Err(error) => Err("\{error}")
        },
      )
    }),
  )
}

///|
fn invoke_research_capability(
  emit : @rabbita.Emit[Msg],
  url : String,
  execution : ResearchExecutionProjection,
) -> @rabbita.Cmd {
  @http.post(url)
  .with_json(execution.invocation)
  .expect_json(
    emit.map(result => CapabilitySubmitted(decode_execution(result))),
  )
}

///|
fn create_research_session(
  emit : @rabbita.Emit[Msg],
  gateway_base : String,
  book_dir : String,
) -> @rabbita.Cmd {
  @http.post("\{gateway_base}/v1/cowork/sessions")
  .with_json({ "cwd": book_dir, "title": "Moonfind DeepSeek research" })
  .expect_json(
    emit.map(result => ResearchSessionCreated(decode_session(result))),
  )
}

///|
fn submit_prepared_research_command(
  emit : @rabbita.Emit[Msg],
  gateway_base : String,
  session : CoworkSessionDetail,
  book_dir : String,
  execution : ResearchExecutionProjection,
) -> @rabbita.Cmd {
  guard execution.receipt is Some({ output: Some(command) }) else {
    return emit(
      ResearchCommandSubmitted(
        Err("capability receipt does not contain a MoonClaw command"),
      ),
    )
  }
  @http.post(
    "\{gateway_base}/v1/cowork/sessions/\{session.session.session_key}/messages",
  )
  .with_json({
    "content": command.stringify(),
    "cwd": book_dir,
    "source_contract": "moonclaw.capability-invocation-receipt.v1",
    "source_request_id": execution.request_id,
  })
  .expect_json(
    emit.map(result => ResearchCommandSubmitted(decode_session(result))),
  )
}

///|
fn checkpoint_research_execution(
  emit : @rabbita.Emit[Msg],
  url : String,
  session : CoworkSessionDetail,
) -> @rabbita.Cmd {
  let checkpoint : Json = {
    "contract_id": "moonfind.moonclaw-session-checkpoint-request.v1",
    "session_key": session.session.session_key,
    "session_status": session.session.state,
    "run": session.linked_run,
  }
  @http.post(url)
  .with_json(checkpoint)
  .expect_json(
    emit.map(result => ExecutionCheckpointed(decode_execution(result))),
  )
}

///|
fn configure_research_session(
  emit : @rabbita.Emit[Msg],
  gateway_base : String,
  session : CoworkSessionDetail,
  book_dir : String,
  model_name : String,
) -> @rabbita.Cmd {
  @http.post(
    "\{gateway_base}/v1/cowork/sessions/\{session.session.session_key}/config",
  )
  .with_json({
    "title": "Moonfind DeepSeek research",
    "cwd": book_dir,
    "model": model_name,
  })
  .expect_json(emit.map(result => ResearchConfigured(decode_session(result))))
}

///|
fn refresh_session(
  emit : @rabbita.Emit[Msg],
  gateway_base : String,
  session_key : String,
  qa : Bool,
) -> @rabbita.Cmd {
  @http.get("\{gateway_base}/v1/cowork/sessions/\{session_key}").expect_json(
    if qa {
      emit.map(result => QaAnswered(decode_session(result)))
    } else {
      emit.map(result => ResearchRefreshed(decode_session(result)))
    },
  )
}

///|
fn reconnect_qa_session(
  emit : @rabbita.Emit[Msg],
  gateway_base : String,
  session_key : String,
) -> @rabbita.Cmd {
  @http.get("\{gateway_base}/v1/cowork/sessions/\{session_key}").expect_json(
    emit.map(result => QaReconnected(decode_session(result))),
  )
}

///|
fn resume_review(
  emit : @rabbita.Emit[Msg],
  gateway_base : String,
  session : CoworkSessionDetail,
  run_id : String,
  reviewer_name : String,
  review_message : String,
) -> @rabbita.Cmd {
  @http.post(
    "\{gateway_base}/v1/cowork/sessions/\{session.session.session_key}/runs/\{run_id}/resume",
  )
  .with_json({
    "content": "Named-human reviewer: \{reviewer_name}\n\n\{review_message}",
  })
  .expect_json(emit.map(result => ReviewResumed(decode_session(result))))
}

///|
fn create_review_session(
  emit : @rabbita.Emit[Msg],
  gateway_base : String,
  book_dir : String,
) -> @rabbita.Cmd {
  @http.post("\{gateway_base}/v1/cowork/sessions")
  .with_json({ "cwd": book_dir, "title": "Moonfind MoonBook review" })
  .expect_json(emit.map(result => ReviewSessionCreated(decode_session(result))))
}

///|
fn configure_review_session(
  emit : @rabbita.Emit[Msg],
  gateway_base : String,
  session : CoworkSessionDetail,
  book_dir : String,
  model_name : String,
) -> @rabbita.Cmd {
  @http.post(
    "\{gateway_base}/v1/cowork/sessions/\{session.session.session_key}/config",
  )
  .with_json({
    "title": "Moonfind MoonBook review",
    "cwd": book_dir,
    "model": model_name,
  })
  .expect_json(emit.map(result => ReviewConfigured(decode_session(result))))
}

///|
fn plan_review(
  emit : @rabbita.Emit[Msg],
  gateway_base : String,
  session : CoworkSessionDetail,
  book_dir : String,
  request_text : String,
) -> @rabbita.Cmd {
  @http.post(
    "\{gateway_base}/v1/cowork/sessions/\{session.session.session_key}/plan",
  )
  .with_json({ "request_text": request_text, "cwd": book_dir })
  .expect_json(emit.map(result => ReviewPlanned(decode_session(result))))
}

///|
fn promote_review(
  emit : @rabbita.Emit[Msg],
  gateway_base : String,
  session : CoworkSessionDetail,
  book_dir : String,
) -> @rabbita.Cmd {
  @http.post(
    "\{gateway_base}/v1/cowork/sessions/\{session.session.session_key}/promote",
  )
  .with_json({ "guidance": "", "cwd": book_dir })
  .expect_json(emit.map(result => ReviewPromoted(decode_session(result))))
}

///|
fn confirm_review(
  emit : @rabbita.Emit[Msg],
  gateway_base : String,
  session : CoworkSessionDetail,
  proposal_id : String,
) -> @rabbita.Cmd {
  @http.post(
    "\{gateway_base}/v1/cowork/sessions/\{session.session.session_key}/proposals/\{proposal_id}/confirm",
  ).expect_json(emit.map(result => ReviewConfirmed(decode_session(result))))
}

///|
fn refresh_review_session(
  emit : @rabbita.Emit[Msg],
  gateway_base : String,
  session_key : String,
) -> @rabbita.Cmd {
  @http.get("\{gateway_base}/v1/cowork/sessions/\{session_key}").expect_json(
    emit.map(result => ReviewRefreshed(decode_session(result))),
  )
}

///|
fn create_qa_session(
  emit : @rabbita.Emit[Msg],
  gateway_base : String,
  cwd : String,
) -> @rabbita.Cmd {
  @http.post("\{gateway_base}/v1/cowork/sessions")
  .with_json({ "cwd": cwd, "title": "moonfind-deepseek-research-book-qa" })
  .expect_json(emit.map(result => QaSessionCreated(decode_session(result))))
}

///|
fn configure_qa_session(
  emit : @rabbita.Emit[Msg],
  gateway_base : String,
  session : CoworkSessionDetail,
  cwd : String,
  model_name : String,
) -> @rabbita.Cmd {
  @http.post(
    "\{gateway_base}/v1/cowork/sessions/\{session.session.session_key}/config",
  )
  .with_json({
    "title": "moonfind-deepseek-research-book-qa",
    "cwd": cwd,
    "model": model_name,
  })
  .expect_json(emit.map(result => QaConfigured(decode_session(result))))
}

///|
fn bootstrap_qa_session(
  emit : @rabbita.Emit[Msg],
  gateway_base : String,
  session : CoworkSessionDetail,
  cwd : String,
) -> @rabbita.Cmd {
  let content = qa_grounding_prompt(
    "Return a short readiness receipt listing the files loaded and the current review state.",
  )
  @http.post(
    "\{gateway_base}/v1/cowork/sessions/\{session.session.session_key}/messages",
  )
  .with_json({ "content": content, "cwd": cwd })
  .expect_json(emit.map(result => QaBootstrapped(decode_session(result))))
}

///|
fn qa_grounding_prompt(task : String) -> String {
  (
    $|Act as the retained DeepSeek research-book Q&A agent. For this turn, read wiki/queries/qa-agent-contract.md, wiki/synthesis/deepseek-research-report.md, wiki/synthesis/claim-matrix.md, wiki/sources/local-transcript-source-map.md, wiki/sources/external-validation.md, and state/review-status.json before answering.
    $|
    $|Cite private screenshot claims as local:pN and public evidence by exact URL. Label pending-review evidence, later web updates, and analysis separately. Never reconstruct missing page 1, authenticate the alleged transcript, expose private inputs, approve MoonBook changes, or imply that earlier conversation is evidence.
    $|
    $|Task:
    $|\{task}
  )
}

///|
fn ask_qa_session(
  emit : @rabbita.Emit[Msg],
  gateway_base : String,
  session : CoworkSessionDetail,
  cwd : String,
  question : String,
) -> @rabbita.Cmd {
  let content = qa_grounding_prompt(question)
  @http.post(
    "\{gateway_base}/v1/cowork/sessions/\{session.session.session_key}/messages",
  )
  .with_json({ "content": content, "cwd": cwd })
  .expect_json(emit.map(result => QaAnswered(decode_session(result))))
}
