///|
extern "js" fn product_api_url(path : String) -> String =
  #| (path) => {
  #|   const route = String(path || "").startsWith("/")
  #|     ? String(path)
  #|     : `/${String(path || "")}`;
  #|   const match = globalThis.location?.pathname?.match(
  #|     /^\/pack-apps\/([^/]+)\//
  #|   );
  #|   return match ? `/pack-apps/${match[1]}${route}` : route;
  #| }

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
  result : Result[CapabilityOperationReply, Error],
) -> Result[CapabilityOperationReply, String] {
  match result {
    Ok(payload) => Ok(payload)
    Err(error) => Err("\{error}")
  }
}

///|
fn decode_review_prepare(
  result : Result[Json, Error],
) -> Result[ReviewPrepareReply, String] {
  match result {
    Ok(payload) => {
      if payload
        is {
          "error": {
            "contract_id": String("moonfind.ui-host-error.v1"),
            "message": String(message),
            ..
          },
          ..
        } {
        return Err(message)
      }
      let reply : ReviewPrepareReply = @json.from_json(payload) catch {
        error =>
          return Err("MoonFind returned an invalid review response: \{error}")
      }
      Ok(reply)
    }
    Err(error) => Err("\{error}")
  }
}

///|
fn decode_moonflow_intake(
  result : Result[MoonFlowReceiverHandoff, Error],
) -> Result[MoonFlowReceiverHandoff, String] {
  match result {
    Ok(payload) => Ok(payload)
    Err(error) => Err("\{error}")
  }
}

///|
fn decode_moonflow_status(
  result : Result[MoonFlowReceiverStatus, Error],
) -> Result[MoonFlowReceiverStatus, String] {
  match result {
    Ok(payload) => Ok(payload)
    Err(error) => Err("\{error}")
  }
}

///|
fn decode_moonflow_receipt_reply(
  result : Result[MoonFlowReviewReceiptReply, Error],
) -> Result[MoonFlowReviewReceiptReply, String] {
  match result {
    Ok(payload) => Ok(payload)
    Err(error) => Err("\{error}")
  }
}

///|
fn decode_series_catalog(
  result : Result[Array[SeriesUseCaseProjection], Error],
) -> Result[Array[SeriesUseCaseProjection], String] {
  match result {
    Ok(payload) => Ok(payload)
    Err(error) => Err("\{error}")
  }
}

///|
fn decode_series_detail(
  result : Result[SeriesUseCaseProjection, Error],
) -> Result[SeriesUseCaseProjection, String] {
  match result {
    Ok(payload) => Ok(payload)
    Err(error) => Err("\{error}")
  }
}

///|
fn load_workspace_snapshot(emit : @rabbita.Emit[Msg]) -> @rabbita.Cmd {
  @http.get(product_api_url("/api/v1/workspace")).expect_json(
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
fn load_series_catalog(emit : @rabbita.Emit[Msg]) -> @rabbita.Cmd {
  @http.get(product_api_url("/api/v1/series")).expect_json(
    emit.map(result => SeriesCatalogLoaded(decode_series_catalog(result))),
  )
}

///|
fn validate_series_template(
  emit : @rabbita.Emit[Msg],
  use_case_id : String,
) -> @rabbita.Cmd {
  @http.get(product_api_url("/api/v1/series/" + use_case_id)).expect_json(
    emit.map(result => SeriesTemplateLoaded(decode_series_detail(result))),
  )
}

///|
fn prepare_portable_review(
  emit : @rabbita.Emit[Msg],
  url : String,
  model : Model,
) -> @rabbita.Cmd {
  let scope_ids = review_scope_ids(model.review_scope)
  let accepted_idea_ids = if model.review_outcome == "approve_subset" {
    scope_ids
  } else {
    []
  }
  let rejected_idea_ids = if model.review_outcome == "approve_subset" {
    []
  } else {
    scope_ids
  }
  let payload : Json = {
    "contract_id": "moonfind.review-prepare-request.v1",
    "reviewer_name": model.reviewer_name.trim(),
    "outcome": model.review_outcome,
    "accepted_idea_ids": accepted_idea_ids,
    "rejected_idea_ids": rejected_idea_ids,
    "rationale": model.review_message.trim(),
    "information_gap": {
      "present": model.information_gap_severity > 0,
      "severity": model.information_gap_severity,
      "summary": model.information_gap_summary.trim(),
    },
    "recognition_gap": {
      "present": model.recognition_gap_severity > 0,
      "severity": model.recognition_gap_severity,
      "summary": model.recognition_gap_summary.trim(),
    },
    "decisiveness_gap": {
      "present": model.decisiveness_gap_severity > 0,
      "severity": model.decisiveness_gap_severity,
      "summary": model.decisiveness_gap_summary.trim(),
    },
  }
  @http.post(product_api_url(url))
  .with_json(payload)
  .expect_json(
    emit.map(result => ReviewPrepared(decode_review_prepare(result))),
  )
}

///|
fn load_moonflow_receiver(
  emit : @rabbita.Emit[Msg],
  run_id : String,
  token : String,
) -> @rabbita.Cmd {
  if !moonflow_launch_present(run_id, token) {
    return @rabbita.none
  }
  if !valid_moonflow_launch(run_id, token) {
    return emit(
      MoonFlowIntakeLoaded(
        Err(
          "MoonFlow launch requires one safe run ID and a 64-character lowercase hexadecimal handoff token.",
        ),
      ),
    )
  }
  let endpoint = moonflow_receiver_base(run_id, token)
  @rabbita.batch([
    @http.get(endpoint).expect_json(
      emit.map(result => MoonFlowIntakeLoaded(decode_moonflow_intake(result))),
    ),
    @http.get(endpoint + "/status").expect_json(
      emit.map(result => MoonFlowStatusLoaded(decode_moonflow_status(result))),
    ),
  ])
}

///|
fn prepare_moonflow_receiver_receipt(
  emit : @rabbita.Emit[Msg],
  handoff : MoonFlowReceiverHandoff,
) -> @rabbita.Cmd {
  let payload : Json = {
    "contract_id": "moonfind.moonflow-review-receipt-request.v1",
    "intake": handoff.to_json(),
  }
  @http.post(product_api_url("/api/v1/review/moonflow-receipt"))
  .with_json(payload)
  .expect_json(
    emit.map(result => {
      MoonFlowReceiptPrepared(decode_moonflow_receipt_reply(result))
    }),
  )
}

///|
fn post_moonflow_receiver_receipt(
  emit : @rabbita.Emit[Msg],
  reply : MoonFlowReviewReceiptReply,
) -> @rabbita.Cmd {
  @http.post(reply.receipt_path)
  .with_json(reply.receiver_receipt)
  .expect_json(
    emit.map(result => MoonFlowReceiptPosted(decode_moonflow_status(result))),
  )
}

///|
fn invoke_research_capability(
  emit : @rabbita.Emit[Msg],
  url : String,
  execution : ResearchExecutionProjection,
) -> @rabbita.Cmd {
  @http.post(product_api_url(url))
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
  }
  @http.post(product_api_url(url))
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
