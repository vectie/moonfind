///|
fn with_error(model : Model, error : String) -> Model {
  { ..model, phase: Failed, error: Some(error), notice: None }
}

///|
fn with_sidecar_error(model : Model, error : String) -> Model {
  { ..model, error: Some(error), notice: None }
}

///|
fn with_review_error(model : Model, error : String) -> Model {
  { ..model, review_phase: ReviewFailed, error: Some(error), notice: None }
}

///|
fn update(
  emit : @rabbita.Emit[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    WorkspaceLoaded(Ok(snapshot)) => {
      let commands : Array[@rabbita.Cmd] = []
      match snapshot.research_cowork_session_key {
        Some(key) if !key.is_blank() =>
          commands.push(refresh_session(emit, model.gateway_base, key, false))
        _ => ()
      }
      match snapshot.qa_cowork_session_key {
        Some(key) if !key.is_blank() &&
          snapshot.qa_agent_status == "grounded_verified" =>
          commands.push(reconnect_qa_session(emit, model.gateway_base, key))
        _ => ()
      }
      (
        @rabbita.batch(commands),
        {
          ..model,
          book_dir: snapshot.book_workspace,
          research_execution: snapshot.research_execution,
          capability_submit_url: snapshot.capability_submit_url,
          capability_reconcile_url: snapshot.capability_reconcile_url,
          capability_checkpoint_url: snapshot.capability_checkpoint_url,
          notice: Some(
            "Restoring capability, MoonClaw run, and retained Q&A state…",
          ),
          error: None,
        },
      )
    }
    WorkspaceLoaded(Err(error)) =>
      (
        @rabbita.none,
        with_sidecar_error(model, "Workspace snapshot unavailable: " + error),
      )
    SetGateway(value) => (@rabbita.none, { ..model, gateway_base: value })
    SetSourceDir(value) =>
      (
        @rabbita.none,
        {
          ..model,
          source_dir: value,
          request_text: default_request(value, model.book_dir),
        },
      )
    SetBookDir(value) =>
      (
        @rabbita.none,
        {
          ..model,
          book_dir: value,
          request_text: default_request(model.source_dir, value),
        },
      )
    SetModelName(value) => (@rabbita.none, { ..model, model_name: value })
    SetRequestText(value) => (@rabbita.none, { ..model, request_text: value })
    SetReviewerName(value) => (@rabbita.none, { ..model, reviewer_name: value })
    SetReviewOutcome(value) =>
      (@rabbita.none, { ..model, review_outcome: value })
    SetReviewScope(value) => (@rabbita.none, { ..model, review_scope: value })
    SetReviewMessage(value) =>
      (@rabbita.none, { ..model, review_message: value })
    SetQaQuestion(value) => (@rabbita.none, { ..model, qa_question: value })
    StartResearch =>
      match model.research_execution {
        Some(execution) =>
          match execution.state {
            "prepared" | "submitting" | "pending" | "unknown" => {
              let endpoint = if execution.state == "prepared" {
                model.capability_submit_url
              } else {
                model.capability_reconcile_url
              }
              match endpoint {
                Some(url) if !url.is_blank() =>
                  (
                    invoke_research_capability(emit, url, execution),
                    {
                      ..model,
                      phase: Running,
                      notice: Some(
                        if execution.state == "prepared" {
                          "Submitting the exact installed-pack capability to MoonClaw…"
                        } else {
                          "Reconciling the same MoonClaw capability attempt without replay…"
                        },
                      ),
                      error: None,
                    },
                  )
                _ =>
                  (
                    @rabbita.none,
                    with_error(
                      model, "The MoonFind host did not publish the required capability submit/reconcile port.",
                    ),
                  )
              }
            }
            "command-ready" =>
              match model.research_session {
                Some(session) =>
                  (
                    refresh_session(
                      emit,
                      model.gateway_base,
                      session.session.session_key,
                      false,
                    ),
                    {
                      ..model,
                      phase: Running,
                      notice: Some(
                        "A Cowork session already exists; reconciling it instead of submitting again…",
                      ),
                      error: None,
                    },
                  )
                None =>
                  (
                    create_research_session(
                      emit,
                      model.gateway_base,
                      model.book_dir,
                    ),
                    {
                      ..model,
                      phase: CreatingSession,
                      research_session: None,
                      review_session: None,
                      qa_session: None,
                      review_phase: ReviewIdle,
                      qa_ready: false,
                      notice: Some(
                        "Creating the MoonClaw Cowork session for the exact prepared command…",
                      ),
                      error: None,
                    },
                  )
              }
            "runtime-submitting" | "runtime-pending" | "runtime-unknown" =>
              match execution.moonclaw_session_key {
                Some(key) if !key.is_blank() =>
                  (
                    refresh_session(emit, model.gateway_base, key, false),
                    {
                      ..model,
                      phase: Running,
                      notice: Some(
                        "Reconciling the persisted MoonClaw Cowork run…",
                      ),
                      error: None,
                    },
                  )
                _ =>
                  (
                    @rabbita.none,
                    with_error(
                      model, "Runtime state is pending but has no persisted MoonClaw session identity.",
                    ),
                  )
              }
            "needs-review" =>
              (
                @rabbita.none,
                {
                  ..model,
                  phase: Completed,
                  notice: Some(
                    "MoonClaw execution is complete and ready for named-human review.",
                  ),
                  error: None,
                },
              )
            _ =>
              (
                @rabbita.none,
                with_error(
                  model,
                  "Execution is blocked in state `\{execution.state}`; inspect its durable receipt.",
                ),
              )
          }
        None =>
          (
            @rabbita.none,
            with_error(
              model, "No prepared MoonFind capability execution was published by the host.",
            ),
          )
      }
    CapabilitySubmitted(Ok(execution)) => {
      let ready = execution.state == "command-ready"
      (
        if ready {
          create_research_session(emit, model.gateway_base, model.book_dir)
        } else {
          @rabbita.none
        },
        {
          ..model,
          research_execution: Some(execution),
          phase: if ready {
            CreatingSession
          } else {
            Running
          },
          notice: Some(
            if ready {
              "Capability reconciled. Submitting its exact command through MoonClaw Cowork…"
            } else {
              "Capability state: \{execution.state}. Next: \{execution.next_action}."
            },
          ),
          error: None,
        },
      )
    }
    CapabilitySubmitted(Err(error)) => (@rabbita.none, with_error(model, error))
    ResearchSessionCreated(Ok(session)) =>
      (
        configure_research_session(
          emit,
          model.gateway_base,
          session,
          model.book_dir,
          model.model_name,
        ),
        {
          ..model,
          phase: CreatingSession,
          research_session: Some(session),
          notice: Some("Applying the selected folder and model…"),
        },
      )
    ResearchSessionCreated(Err(error)) =>
      (@rabbita.none, with_error(model, error))
    ResearchConfigured(Ok(session)) =>
      match model.research_execution {
        Some(execution) if execution.state == "command-ready" =>
          (
            submit_prepared_research_command(
              emit,
              model.gateway_base,
              session,
              model.book_dir,
              execution,
            ),
            {
              ..model,
              phase: Confirming,
              research_session: Some(session),
              notice: Some(
                "Submitting the capability-produced command to the existing MoonClaw runtime…",
              ),
            },
          )
        _ =>
          (
            @rabbita.none,
            with_error(
              { ..model, research_session: Some(session) },
              "MoonClaw session created without a command-ready capability receipt.",
            ),
          )
      }
    ResearchConfigured(Err(error)) => (@rabbita.none, with_error(model, error))
    ResearchCommandSubmitted(Ok(session)) => {
      let checkpoint = match model.capability_checkpoint_url {
        Some(url) if !url.is_blank() =>
          checkpoint_research_execution(emit, url, session)
        _ => @rabbita.none
      }
      (
        checkpoint,
        {
          ..model,
          phase: phase_from_session(session),
          research_session: Some(session),
          notice: Some(
            "MoonClaw accepted the exact command; persisting its session before polling for the run…",
          ),
          error: None,
        },
      )
    }
    ResearchCommandSubmitted(Err(error)) =>
      (@rabbita.none, with_error(model, error))
    ExecutionCheckpointed(Ok(execution)) =>
      (
        @rabbita.none,
        {
          ..model,
          research_execution: Some(execution),
          phase: if execution.state == "needs-review" {
            Completed
          } else {
            Running
          },
          notice: Some(
            "Execution checkpoint persisted. Next: \{execution.next_action}.",
          ),
          error: None,
        },
      )
    ExecutionCheckpointed(Err(error)) =>
      (
        @rabbita.none,
        with_sidecar_error(
          model,
          "MoonClaw ran, but MoonFind could not persist its identity: " + error,
        ),
      )
    RefreshResearch =>
      match model.research_session {
        Some(session) =>
          (
            refresh_session(
              emit,
              model.gateway_base,
              session.session.session_key,
              false,
            ),
            {
              ..model,
              notice: Some("Refreshing the durable run…"),
              error: None,
            },
          )
        None =>
          (@rabbita.none, with_error(model, "No research session exists."))
      }
    ResearchRefreshed(Ok(session)) =>
      (
        match model.capability_checkpoint_url {
          Some(url) if !url.is_blank() =>
            checkpoint_research_execution(emit, url, session)
          _ => @rabbita.none
        },
        {
          ..model,
          phase: phase_from_session(session),
          research_session: Some(session),
          notice: Some("Research state refreshed."),
          error: session.linked_run.bind(run => run.error),
        },
      )
    ResearchRefreshed(Err(error)) => (@rabbita.none, with_error(model, error))
    ResumeReview =>
      match model.research_session {
        Some(session) =>
          match session.linked_run {
            Some(run) =>
              if model.reviewer_name.trim().is_blank() {
                (
                  @rabbita.none,
                  with_error(model, "Enter the named human reviewer first."),
                )
              } else {
                (
                  resume_review(
                    emit,
                    model.gateway_base,
                    session,
                    run.id,
                    model.reviewer_name,
                    model.review_message,
                  ),
                  {
                    ..model,
                    phase: Running,
                    notice: Some("Submitting explicit review guidance…"),
                    error: None,
                  },
                )
              }
            None => (@rabbita.none, with_error(model, "No durable run exists."))
          }
        None =>
          (@rabbita.none, with_error(model, "No research session exists."))
      }
    ReviewResumed(Ok(session)) =>
      (
        @rabbita.none,
        {
          ..model,
          phase: phase_from_session(session),
          research_session: Some(session),
          notice: Some("Review guidance submitted; refresh for the result."),
          error: None,
        },
      )
    ReviewResumed(Err(error)) => (@rabbita.none, with_error(model, error))
    PrepareReview => {
      let issues = review_request_issues(
        model.reviewer_name,
        model.review_outcome,
        model.review_scope,
        model.review_message,
      )
      if !issues.is_empty() {
        (
          @rabbita.none,
          {
            ..model,
            review_phase: ReviewIdle,
            notice: None,
            error: Some(issues.join(" ")),
          },
        )
      } else {
        (
          create_review_session(emit, model.gateway_base, model.book_dir),
          {
            ..model,
            review_session: None,
            review_phase: ReviewCreatingSession,
            notice: Some("Creating a dedicated MoonBook review session…"),
            error: None,
          },
        )
      }
    }
    ReviewSessionCreated(Ok(session)) =>
      (
        configure_review_session(
          emit,
          model.gateway_base,
          session,
          model.book_dir,
          model.model_name,
        ),
        {
          ..model,
          review_session: Some(session),
          review_phase: ReviewCreatingSession,
          notice: Some(
            "Binding the review session to MoonBook and the selected model…",
          ),
          error: None,
        },
      )
    ReviewSessionCreated(Err(error)) =>
      (@rabbita.none, with_review_error(model, error))
    ReviewConfigured(Ok(session)) =>
      (
        plan_review(
          emit,
          model.gateway_base,
          session,
          model.book_dir,
          review_decision_request(
            model.book_dir,
            model.reviewer_name,
            model.review_outcome,
            model.review_scope,
            model.review_message,
          ),
        ),
        {
          ..model,
          review_session: Some(session),
          review_phase: ReviewPlanning,
          notice: Some("MoonClaw is preparing the scoped review plan…"),
          error: None,
        },
      )
    ReviewConfigured(Err(error)) =>
      (@rabbita.none, with_review_error(model, error))
    ReviewPlanned(Ok(session)) =>
      (
        @rabbita.none,
        {
          ..model,
          review_session: Some(session),
          review_phase: ReviewPlanReady,
          notice: Some("Review plan ready. Inspect it before promotion."),
          error: None,
        },
      )
    ReviewPlanned(Err(error)) =>
      (@rabbita.none, with_review_error(model, error))
    PromoteReview =>
      match model.review_session {
        Some(session) =>
          (
            promote_review(emit, model.gateway_base, session, model.book_dir),
            {
              ..model,
              review_phase: ReviewPromoting,
              notice: Some(
                "Promoting the scoped review plan into a proposal…",
              ),
              error: None,
            },
          )
        None =>
          (
            @rabbita.none,
            with_review_error(model, "No MoonBook review session exists."),
          )
      }
    ReviewPromoted(Ok(session)) =>
      (
        @rabbita.none,
        {
          ..model,
          review_session: Some(session),
          review_phase: ReviewProposalReady,
          notice: Some(
            "Review proposal ready. Confirmation creates the durable decision run.",
          ),
          error: None,
        },
      )
    ReviewPromoted(Err(error)) =>
      (@rabbita.none, with_review_error(model, error))
    ConfirmReview =>
      match model.review_session {
        Some({ linked_proposal: Some(proposal), .. } as session) =>
          (
            confirm_review(emit, model.gateway_base, session, proposal.id),
            {
              ..model,
              review_phase: ReviewConfirming,
              notice: Some("Confirming the durable MoonBook decision run…"),
              error: None,
            },
          )
        Some(_) =>
          (
            @rabbita.none,
            with_review_error(model, "The review session has no proposal."),
          )
        None =>
          (
            @rabbita.none,
            with_review_error(model, "No MoonBook review session exists."),
          )
      }
    ReviewConfirmed(Ok(session)) =>
      (
        @rabbita.none,
        {
          ..model,
          review_session: Some(session),
          review_phase: review_phase_from_session(session),
          notice: Some(
            "Durable review run created. Refresh to verify the recorded decision.",
          ),
          error: None,
        },
      )
    ReviewConfirmed(Err(error)) =>
      (@rabbita.none, with_review_error(model, error))
    RefreshReview =>
      match model.review_session {
        Some(session) =>
          (
            refresh_review_session(
              emit,
              model.gateway_base,
              session.session.session_key,
            ),
            {
              ..model,
              notice: Some("Refreshing the MoonBook decision run…"),
              error: None,
            },
          )
        None =>
          (
            @rabbita.none,
            with_review_error(model, "No MoonBook review session exists."),
          )
      }
    ReviewRefreshed(Ok(session)) => {
      let review_phase = review_phase_from_session(session)
      (
        @rabbita.none,
        {
          ..model,
          review_session: Some(session),
          review_phase,
          notice: Some(
            if review_phase == ReviewCompleted {
              "MoonBook decision run completed. Inspect the decision receipt and resulting review state."
            } else {
              "MoonBook decision state refreshed."
            },
          ),
          error: session.linked_run.bind(run => run.error),
        },
      )
    }
    ReviewRefreshed(Err(error)) =>
      (@rabbita.none, with_review_error(model, error))
    PrepareQa => {
      let cwd = match model.research_session {
        Some({ linked_run: Some({ workspace_dir: Some(path), .. }), .. }) =>
          path
        _ => model.book_dir
      }
      (
        create_qa_session(emit, model.gateway_base, cwd),
        {
          ..model,
          notice: Some("Creating the retained book-grounded Q&A session…"),
          error: None,
        },
      )
    }
    QaSessionCreated(Ok(session)) => {
      let cwd = match model.research_session {
        Some({ linked_run: Some({ workspace_dir: Some(path), .. }), .. }) =>
          path
        _ => model.book_dir
      }
      (
        configure_qa_session(
          emit,
          model.gateway_base,
          session,
          cwd,
          model.model_name,
        ),
        {
          ..model,
          qa_session: Some(session),
          notice: Some("Binding Q&A to the research workspace and model…"),
        },
      )
    }
    QaSessionCreated(Err(error)) =>
      (@rabbita.none, with_sidecar_error(model, error))
    QaConfigured(Ok(session)) => {
      let cwd = match model.research_session {
        Some({ linked_run: Some({ workspace_dir: Some(path), .. }), .. }) =>
          path
        _ => model.book_dir
      }
      (
        bootstrap_qa_session(emit, model.gateway_base, session, cwd),
        {
          ..model,
          qa_session: Some(session),
          notice: Some("Loading the report, evidence, and Q&A contract…"),
        },
      )
    }
    QaConfigured(Err(error)) =>
      (@rabbita.none, with_sidecar_error(model, error))
    QaBootstrapped(Ok(session)) =>
      (
        @rabbita.none,
        {
          ..model,
          qa_session: Some(session),
          qa_ready: true,
          notice: Some("The retained Q&A agent returned a readiness receipt."),
          error: None,
        },
      )
    QaBootstrapped(Err(error)) =>
      (@rabbita.none, with_sidecar_error(model, error))
    QaReconnected(Ok(session)) =>
      (
        @rabbita.none,
        {
          ..model,
          qa_session: Some(session),
          qa_ready: true,
          notice: Some(
            "Completed research and the verified retained Q&A agent are restored.",
          ),
          error: None,
        },
      )
    QaReconnected(Err(error)) =>
      (
        @rabbita.none,
        with_sidecar_error(
          model,
          "Verified Q&A session could not be restored: " + error,
        ),
      )
    AskQa =>
      match model.qa_session {
        Some(session) => {
          let cwd = match model.research_session {
            Some({ linked_run: Some({ workspace_dir: Some(path), .. }), .. }) =>
              path
            _ => model.book_dir
          }
          if model.qa_question.trim().is_blank() {
            (
              @rabbita.none,
              with_sidecar_error(model, "Enter a question first."),
            )
          } else {
            (
              ask_qa_session(
                emit,
                model.gateway_base,
                session,
                cwd,
                model.qa_question,
              ),
              {
                ..model,
                notice: Some("The retained agent is answering from the book…"),
                error: None,
              },
            )
          }
        }
        None =>
          (
            @rabbita.none,
            with_sidecar_error(model, "Prepare the retained Q&A agent first."),
          )
      }
    QaAnswered(Ok(session)) =>
      (
        @rabbita.none,
        {
          ..model,
          qa_session: Some(session),
          notice: Some("Answer received with the session retained."),
          error: None,
        },
      )
    QaAnswered(Err(error)) => (@rabbita.none, with_sidecar_error(model, error))
  }
}
