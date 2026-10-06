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
fn load_workspace_snapshot(
  emit : @rabbita.Emit[Msg],
  generation : Int,
) -> @rabbita.Cmd {
  @http.get(product_api_url("/api/v1/workspace")).expect_json(
    emit.map(result => {
      WorkspaceLoaded(
        generation,
        match result {
          Ok(snapshot) => Ok(snapshot)
          Err(error) => Err("\{error}")
        },
      )
    }),
  )
}

///|
fn job_output_format(name : String) -> String {
  if name.has_suffix(".md") {
    "text/markdown"
  } else if name.has_suffix(".txt") {
    "text/plain"
  } else if name.has_suffix(".csv") {
    "text/csv"
  } else if name.has_suffix(".tsv") {
    "text/tab-separated-values"
  } else if name.has_suffix(".json") {
    "application/json"
  } else if name.has_suffix(".ipynb") {
    "application/x-ipynb+json"
  } else if name.has_suffix(".pdf") {
    "application/pdf"
  } else if name.has_suffix(".tex") {
    "text/x-tex"
  } else if name.has_suffix(".bib") {
    "text/x-bibtex"
  } else if name.has_suffix(".png") {
    "image/png"
  } else if name.has_suffix(".jpg") || name.has_suffix(".jpeg") {
    "image/jpeg"
  } else if name.has_suffix(".svg") {
    "image/svg+xml"
  } else if name.has_suffix(".html") {
    "text/html"
  } else if name.has_suffix(".docx") {
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
  } else if name.has_suffix(".xlsx") {
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  } else if name.has_suffix(".pptx") {
    "application/vnd.openxmlformats-officedocument.presentationml.presentation"
  } else if name.has_suffix(".zip") {
    "application/zip"
  } else {
    "application/octet-stream"
  }
}

///|
fn requested_job_criteria(text : String) -> Array[String] {
  text
  .split(";")
  .map(value => value.trim().to_owned())
  .filter(value => !value.is_blank())
  .collect()
}

///|
fn requested_job_outputs(
  text : String,
  criteria : String,
) -> Array[RequestedJobOutput] {
  let names : Array[String] = text
    .split(",")
    .map(value => value.trim().to_owned())
    .filter(value => !value.is_blank())
    .collect()
  let requirements = requested_job_criteria(criteria)
  names.map(name => {
    let checks : Array[String] = []
    for requirement in requirements {
      let parts : Array[StringView] = requirement.split("=>").collect()
      if parts.length() == 2 && names.contains(parts[0].trim().to_owned()) {
        if parts[0].trim() == name {
          checks.push(parts[1].trim().to_owned())
        }
      } else {
        checks.push(requirement)
      }
    }
    RequestedJobOutput::{
      output_id: name,
      title: name,
      kind: "research-output",
      format: job_output_format(name),
      acceptance_criteria: checks,
    }
  })
}

///|
fn load_research_jobs(emit : @rabbita.Emit[Msg]) -> @rabbita.Cmd {
  @http.get(product_api_url("/api/v1/jobs")).expect_json(
    emit.map(result => {
      JobsLoaded(
        match result {
          Ok(jobs) => Ok(jobs)
          Err(error) => Err("\{error}")
        },
      )
    }),
  )
}

///|
fn create_general_job(emit : @rabbita.Emit[Msg], model : Model) -> @rabbita.Cmd {
  let sources = model.job_sources
    .split(";")
    .map(value => value.trim().to_owned())
    .filter(value => !value.is_blank())
  let payload : Json = {
    "objective": model.job_objective.trim(),
    "audience": model.job_audience.trim(),
    "source_scope": sources,
    "requested_outputs": requested_job_outputs(
      model.job_outputs,
      model.job_criteria,
    ),
  }
  @http.post(product_api_url("/api/v1/jobs"))
  .with_json(payload)
  .expect_json(
    emit.map(result => {
      JobCreated(
        match result {
          Ok(job) => Ok(job)
          Err(error) => Err("\{error}")
        },
      )
    }),
  )
}

///|
fn refresh_general_job(
  emit : @rabbita.Emit[Msg],
  job_id : String,
) -> @rabbita.Cmd {
  @http.get(product_api_url("/api/v1/jobs/" + job_id)).expect_json(
    emit.map(result => {
      JobRefreshed(
        match result {
          Ok(job) => Ok(job)
          Err(error) => Err("\{error}")
        },
      )
    }),
  )
}

///|
fn start_general_job(
  emit : @rabbita.Emit[Msg],
  job_id : String,
  model_name : String,
) -> @rabbita.Cmd {
  @http.post(product_api_url("/api/v1/jobs/" + job_id + "/start"))
  .with_json({ "model_name": model_name })
  .expect_json(
    emit.map(result => {
      JobStarted(
        match result {
          Ok(job) => Ok(job)
          Err(error) => Err("\{error}")
        },
      )
    }),
  )
}

///|
fn resume_general_job(
  emit : @rabbita.Emit[Msg],
  job_id : String,
  content : String,
) -> @rabbita.Cmd {
  @http.post(product_api_url("/api/v1/jobs/" + job_id + "/resume"))
  .with_json({ "content": content })
  .expect_json(
    emit.map(result => {
      JobResumed(
        match result {
          Ok(job) => Ok(job)
          Err(error) => Err("\{error}")
        },
      )
    }),
  )
}

///|
fn verify_general_job_delivery(
  emit : @rabbita.Emit[Msg],
  job_id : String,
) -> @rabbita.Cmd {
  @http.post(product_api_url("/api/v1/jobs/" + job_id + "/delivery"))
  .with_json({ "verify": true })
  .expect_json(
    emit.map(result => {
      JobDeliveryVerified(
        match result {
          Ok(job) => Ok(job)
          Err(error) => Err("\{error}")
        },
      )
    }),
  )
}

///|
fn add_general_job_text_source(
  emit : @rabbita.Emit[Msg],
  job_id : String,
  name : String,
  content : String,
) -> @rabbita.Cmd {
  @http.post(product_api_url("/api/v1/jobs/" + job_id + "/sources/text"))
  .with_json({ "name": name, "content": content })
  .expect_json(
    emit.map(result => {
      JobSourceAdded(
        match result {
          Ok(job) => Ok(job)
          Err(error) => Err("\{error}")
        },
      )
    }),
  )
}

///|
fn add_general_job_arxiv_source(
  emit : @rabbita.Emit[Msg],
  job_id : String,
  query : String,
) -> @rabbita.Cmd {
  let payload : Json = { "query": query, "max_results": 10 }
  @http.post(product_api_url("/api/v1/jobs/" + job_id + "/sources/arxiv"))
  .with_json(payload)
  .expect_json(
    emit.map(result => {
      JobSourceAdded(
        match result {
          Ok(job) => Ok(job)
          Err(error) => Err("\{error}")
        },
      )
    }),
  )
}

///|
fn add_general_job_url_source(
  emit : @rabbita.Emit[Msg],
  job_id : String,
  url : String,
) -> @rabbita.Cmd {
  @http.post(product_api_url("/api/v1/jobs/" + job_id + "/sources/url"))
  .with_json({ "url": url })
  .expect_json(
    emit.map(result => {
      JobSourceAdded(
        match result {
          Ok(job) => Ok(job)
          Err(error) => Err("\{error}")
        },
      )
    }),
  )
}

///|
fn create_general_job_revision(
  emit : @rabbita.Emit[Msg],
  job_id : String,
  name : String,
  instruction : String,
) -> @rabbita.Cmd {
  @http.post(product_api_url("/api/v1/jobs/" + job_id + "/revisions"))
  .with_json({ "file_name": name, "instruction": instruction })
  .expect_json(
    emit.map(result => {
      JobRevisionCreated(
        match result {
          Ok(job) => Ok(job)
          Err(error) => Err("\{error}")
        },
      )
    }),
  )
}

///|
fn preview_general_job_file(
  emit : @rabbita.Emit[Msg],
  job_id : String,
  name : String,
) -> @rabbita.Cmd {
  @http.get(
    product_api_url("/api/v1/jobs/" + job_id + "/files/" + name + "/preview"),
  ).expect_json(
    emit.map(result => {
      JobPreviewLoaded(
        match result {
          Ok(preview) => Ok(preview)
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
  request_generation : Int,
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
    "source_digest": model.moontown_result
    .bind(result => result.source_digest)
    .unwrap_or(""),
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
    emit.map(result => {
      ReviewPrepared(
        request_generation,
        review_result_context(model),
        decode_review_prepare(result),
      )
    }),
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
    emit.map(result => CapabilitySubmitted(execution, decode_execution(result))),
  )
}

///|
fn create_research_session(
  emit : @rabbita.Emit[Msg],
  request : ModelSubmission,
) -> @rabbita.Cmd {
  @http.post("\{request.gateway}/v1/cowork/sessions")
  .with_json({
    "cwd": request.cwd,
    "title": "MoonFind research: " + request.title,
  })
  .expect_json(
    emit.map(result => ResearchSessionCreated(request, decode_session(result))),
  )
}

///|
fn submit_prepared_research_command(
  emit : @rabbita.Emit[Msg],
  gateway_base : String,
  session : CoworkSessionDetail,
  book_dir : String,
  execution : ResearchExecutionProjection,
  request : ModelSubmission,
) -> @rabbita.Cmd {
  guard execution.receipt is Some({ output: Some(command), }) else {
    return emit(
      ResearchCommandSubmitted(
        request,
        Err("capability receipt does not contain a MoonClaw command"),
      ),
    )
  }
  @http.post(
    "\{gateway_base}/v1/cowork/sessions/\{session.session.session_key}/messages",
  )
  .with_json({
    "content": command.stringify(),
    "model": request.selector,
    "cwd": book_dir,
    "source_contract": "moonclaw.capability-invocation-receipt.v1",
    "source_request_id": execution.request_id,
  })
  .expect_json(
    emit.map(result => ResearchCommandSubmitted(request, decode_session(result))),
  )
}

///|
fn checkpoint_research_execution(
  emit : @rabbita.Emit[Msg],
  url : String,
  session : CoworkSessionDetail,
  execution : ResearchExecutionProjection?,
) -> @rabbita.Cmd {
  guard execution is Some(execution) else { return @rabbita.none }
  let checkpoint : Json = {
    "contract_id": "moonfind.moonclaw-session-checkpoint-request.v1",
    "session_key": session.session.session_key,
  }
  @http.post(product_api_url(url))
  .with_json(checkpoint)
  .expect_json(
    emit.map(result => {
      ExecutionCheckpointed(execution, decode_execution(result))
    }),
  )
}

///|
fn configure_research_session(
  emit : @rabbita.Emit[Msg],
  session : CoworkSessionDetail,
  request : ModelSubmission,
) -> @rabbita.Cmd {
  @http.post(
    "\{request.gateway}/v1/cowork/sessions/\{session.session.session_key}/config",
  )
  .with_json({
    "title": "MoonFind research: " + request.title,
    "cwd": request.cwd,
    "model": request.selector,
  })
  .expect_json(
    emit.map(result => ResearchConfigured(request, decode_session(result))),
  )
}

///|
fn refresh_session(
  emit : @rabbita.Emit[Msg],
  gateway_base : String,
  session_key : String,
  _qa : Bool,
  run_id : String,
) -> @rabbita.Cmd {
  @http.get("\{gateway_base}/v1/cowork/sessions/\{session_key}").expect_json(
    emit.map(result => ResearchRefreshed(run_id, decode_session(result))),
  )
}

///|
fn reconnect_qa_session(
  emit : @rabbita.Emit[Msg],
  request : QaRestoreRequest,
) -> @rabbita.Cmd {
  @http.get("\{request.gateway}/v1/cowork/sessions/\{request.session_key}").expect_json(
    emit.map(result => QaReconnected(request, decode_session(result))),
  )
}

///|
fn create_qa_session(
  emit : @rabbita.Emit[Msg],
  request : ModelSubmission,
) -> @rabbita.Cmd {
  @http.post("\{request.gateway}/v1/cowork/sessions")
  .with_json({
    "cwd": request.cwd,
    "title": "MoonFind Q&A: " + request.title,
    "moonfind_purpose": "qa",
    "moonfind_run_id": request.run_id,
  })
  .expect_json(
    emit.map(result => QaSessionCreated(request, decode_session(result))),
  )
}

///|
fn configure_qa_session(
  emit : @rabbita.Emit[Msg],
  session : CoworkSessionDetail,
  request : ModelSubmission,
) -> @rabbita.Cmd {
  @http.post(
    "\{request.gateway}/v1/cowork/sessions/\{session.session.session_key}/config",
  )
  .with_json({
    "title": "MoonFind Q&A: " + request.title,
    "cwd": request.cwd,
    "model": request.selector,
  })
  .expect_json(
    emit.map(result => QaConfigured(request, decode_session(result))),
  )
}

///|
fn bootstrap_qa_session(
  emit : @rabbita.Emit[Msg],
  gateway_base : String,
  session : CoworkSessionDetail,
  cwd : String,
  request : ModelSubmission,
) -> @rabbita.Cmd {
  let content = qa_grounding_prompt(
    request.grounding_context,
    "Return a short readiness receipt naming this run, the supplied evidence and its limits, and the current review state. Do not claim that files were loaded.",
  )
  @http.post(
    "\{gateway_base}/v1/cowork/sessions/\{session.session.session_key}/messages",
  )
  .with_json({
    "content": content,
    "cwd": cwd,
    "model": session.session.model_override.unwrap_or(""),
  })
  .expect_json(
    emit.map(result => QaBootstrapped(request, decode_session(result))),
  )
}

///|
fn ask_qa_session(
  emit : @rabbita.Emit[Msg],
  request : QaQuestionRequest,
) -> @rabbita.Cmd {
  let content = qa_grounding_prompt(request.grounding_context, request.question)
  @http.post(
    "\{request.gateway}/v1/cowork/sessions/\{request.session_key}/messages",
  )
  .with_json({
    "content": content,
    "cwd": request.cwd,
    "model": request.selector,
  })
  .expect_json(emit.map(result => QaAnswered(request, decode_session(result))))
}
