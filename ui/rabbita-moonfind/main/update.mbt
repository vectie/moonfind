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
    RefreshMoonTownStatus =>
      (
        load_workspace_snapshot(emit),
        {
          ..model,
          notice: Some("Refreshing the correlated MoonTown result state…"),
          error: None,
        },
      )
    WorkspaceLoaded(Ok(snapshot)) =>
      if !valid_workspace_snapshot(snapshot) {
        (
          @rabbita.none,
          with_sidecar_error(
            model, "MoonFind host returned an unsupported or cross-run workspace contract.",
          ),
        )
      } else {
        let gateway_base = gateway_base_from_snapshot(
          snapshot,
          model.gateway_base,
        )
        let gateway_published = has_published_gateway(snapshot)
        let phase = phase_from_durable_execution(snapshot.research_execution)
        let commands : Array[@rabbita.Cmd] = []
        match snapshot.research_cowork_session_key {
          Some(key) if !key.is_blank() &&
            gateway_published &&
            execution_needs_session_refresh(snapshot.research_execution) =>
            commands.push(refresh_session(emit, gateway_base, key, false))
          _ => ()
        }
        match snapshot.qa_cowork_session_key {
          Some(key) if !key.is_blank() &&
            gateway_published &&
            snapshot.qa_agent_status == "grounded_verified" =>
            commands.push(reconnect_qa_session(emit, gateway_base, key))
          _ => ()
        }
        (
          @rabbita.batch(commands),
          {
            ..model,
            gateway_base,
            gateway_published,
            book_dir: snapshot.book_workspace,
            phase,
            research_session: if phase == Completed || !gateway_published {
              None
            } else {
              model.research_session
            },
            qa_session: if gateway_published {
              model.qa_session
            } else {
              None
            },
            review_phase: review_phase_from_workflow(
              snapshot.review_workflow,
            ),
            qa_ready: gateway_published && model.qa_ready,
            workspace: Some(snapshot.workspace),
            research_execution: snapshot.research_execution,
            capability_submit_url: snapshot.capability_submit_url,
            capability_reconcile_url: snapshot.capability_reconcile_url,
            capability_checkpoint_url: snapshot.capability_checkpoint_url,
            host_status: snapshot.host_status,
            host_blockers: snapshot.host_blockers,
            moontown_handoff: Some(snapshot.moontown_handoff),
            review_workflow: Some(snapshot.review_workflow),
            notice: Some(
              if phase == Completed {
                "MoonClaw execution is durably complete and ready for named-human review."
              } else {
                "Loaded current durable MoonFind host state from \{snapshot.generated_at}."
              },
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
    SetBookDir(value) =>
      (@rabbita.none, { ..model, book_dir: value })
    SetModelName(value) => (@rabbita.none, { ..model, model_name: value })
    SetReviewerName(value) => (@rabbita.none, { ..model, reviewer_name: value })
    SetReviewOutcome(value) =>
      (@rabbita.none, { ..model, review_outcome: value })
    SetReviewScope(value) => (@rabbita.none, { ..model, review_scope: value })
    SetReviewMessage(value) =>
      (@rabbita.none, { ..model, review_message: value })
    SetInformationGapSeverity(value) =>
      (
        @rabbita.none,
        {
          ..model,
          information_gap_severity: review_gap_severity(
            value,
            model.information_gap_severity,
          ),
        },
      )
    SetInformationGapSummary(value) =>
      (@rabbita.none, { ..model, information_gap_summary: value })
    SetRecognitionGapSeverity(value) =>
      (
        @rabbita.none,
        {
          ..model,
          recognition_gap_severity: review_gap_severity(
            value,
            model.recognition_gap_severity,
          ),
        },
      )
    SetRecognitionGapSummary(value) =>
      (@rabbita.none, { ..model, recognition_gap_summary: value })
    SetDecisivenessGapSeverity(value) =>
      (
        @rabbita.none,
        {
          ..model,
          decisiveness_gap_severity: review_gap_severity(
            value,
            model.decisiveness_gap_severity,
          ),
        },
      )
    SetDecisivenessGapSummary(value) =>
      (@rabbita.none, { ..model, decisiveness_gap_summary: value })
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
              if !model.gateway_published {
                (
                  @rabbita.none,
                  with_error(
                    model, "The trusted host did not publish a reachable MoonClaw gateway.",
                  ),
                )
              } else {
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
              }
            "runtime-submitting" | "runtime-pending" | "runtime-unknown" =>
              if !model.gateway_published {
                (
                  @rabbita.none,
                  with_error(
                    model, "The persisted run requires MoonClaw, but no reachable gateway was published.",
                  ),
                )
              } else {
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
    CapabilitySubmitted(Ok(reply)) => {
      let execution = reply.execution
      let ready = execution.state == "command-ready"
      let gateway_missing = ready && !model.gateway_published
      let reply_notice = if ready {
        "Capability reconciled. Submitting its exact command through MoonClaw Cowork…"
      } else {
        reply.message +
        " State: \{execution.state}. Next: \{execution.next_action}."
      }
      (
        if ready && !reply.blocked && !gateway_missing {
          create_research_session(emit, model.gateway_base, model.book_dir)
        } else {
          @rabbita.none
        },
        {
          ..model,
          research_execution: Some(execution),
          phase: if gateway_missing || reply.blocked {
            Failed
          } else if ready {
            CreatingSession
          } else {
            Running
          },
          notice: if reply.blocked || gateway_missing {
            None
          } else {
            Some(reply_notice)
          },
          error: if gateway_missing {
            Some(
              "Capability succeeded, but the trusted host did not publish a reachable MoonClaw gateway.",
            )
          } else if reply.blocked {
            Some(reply.message)
          } else {
            None
          },
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
    ExecutionCheckpointed(Ok(reply)) =>
      (
        @rabbita.none,
        {
          ..model,
          research_execution: Some(reply.execution),
          phase: if reply.blocked {
            Failed
          } else if reply.execution.state == "needs-review" {
            Completed
          } else {
            Running
          },
          notice: if reply.blocked {
            None
          } else {
            Some(reply.message + " Next: \{reply.execution.next_action}.")
          },
          error: if reply.blocked {
            Some(reply.message)
          } else {
            None
          },
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
    PrepareReview => {
      let issues = review_request_issues(
        model.reviewer_name,
        model.review_outcome,
        model.review_scope,
        model.review_message,
      ) +
        review_gap_issues(model)
      match moonflow_review_binding_issue(model) {
        Some(issue) => issues.push(issue)
        None => ()
      }
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
        match model.review_workflow {
          Some({
            state: "ready-for-human-review",
            prepare_url: Some(url),
            ..
          }) if !url.is_blank() =>
            (
              prepare_portable_review(emit, url, model),
              {
                ..model,
                review_phase: ReviewPreparing,
                review_prepare_reply: None,
                notice: Some(
                  "Persisting the named-human decision and portable MoonChat review bundle…",
                ),
                error: None,
              },
            )
          Some(workflow) =>
            (
              @rabbita.none,
              with_review_error(
                model,
                "Portable review cannot start while the durable workflow is `\{workflow.state}`.",
              ),
            )
          None =>
            (
              @rabbita.none,
              with_review_error(
                model, "The trusted MoonFind host did not publish review workflow state.",
              ),
            )
        }
      }
    }
    ReviewPrepared(Ok(reply)) =>
      if reply.contract_id != "moonfind.review-prepare-reply.v1" ||
        reply.state != "awaiting-moonchat" ||
        reply.operation_ref != "moonchat/conversation.review.record@0.1.0" ||
        model.workspace.map(value => value.run_id != reply.run_id).unwrap_or(true) {
        (
          @rabbita.none,
          with_review_error(
            model, "MoonFind returned an unsupported or cross-run review bundle receipt.",
          ),
        )
      } else {
        (
          @rabbita.batch([
            load_workspace_snapshot(emit),
            load_moonflow_receiver(
              emit,
              model.moonflow_run_id,
              model.moonflow_handoff_token,
            ),
          ]),
          {
            ..model,
            review_phase: ReviewBundleReady,
            review_prepare_reply: Some(reply),
            notice: Some(
              "The portable review bundle is durable. MoonFlow may now execute MoonChat; MoonBook remains the only Bookkeeper authority.",
            ),
            error: None,
          },
        )
      }
    ReviewPrepared(Err(error)) =>
      (@rabbita.none, with_review_error(model, error))
    RefreshMoonFlowReceiver =>
      (
        load_moonflow_receiver(
          emit,
          model.moonflow_run_id,
          model.moonflow_handoff_token,
        ),
        {
          ..model,
          moonflow_receiver_error: None,
          notice: Some("Refreshing the exact MoonFlow receiver handoff…"),
        },
      )
    MoonFlowIntakeLoaded(Ok(handoff)) =>
      if !valid_moonflow_intake(
        handoff,
        model.moonflow_run_id,
        model.moonflow_handoff_token,
      ) {
        (
          @rabbita.none,
          {
            ..model,
            moonflow_intake: None,
            moonflow_receiver_error: Some(
              "MoonFlow returned an unsupported, cross-run, or cross-product handoff.",
            ),
          },
        )
      } else {
        (
          @rabbita.none,
          {
            ..model,
            moonflow_intake: Some(handoff),
          },
        )
      }
    MoonFlowIntakeLoaded(Err(error)) =>
      (
        @rabbita.none,
        {
          ..model,
          moonflow_intake: None,
          moonflow_receiver_error: Some(
            "MoonFlow receiver intake unavailable: " + error,
          ),
        },
      )
    MoonFlowStatusLoaded(Ok(status)) =>
      if !valid_moonflow_status(
        status,
        model.moonflow_run_id,
        model.moonflow_handoff_token,
      ) {
        (
          @rabbita.none,
          {
            ..model,
            moonflow_receiver_status: None,
            moonflow_receiver_error: Some(
              "MoonFlow returned an unsupported or cross-run receiver status.",
            ),
          },
        )
      } else {
        (
          @rabbita.none,
          {
            ..model,
            moonflow_receiver_status: Some(status),
          },
        )
      }
    MoonFlowStatusLoaded(Err(error)) =>
      (
        @rabbita.none,
        {
          ..model,
          moonflow_receiver_status: None,
          moonflow_receiver_error: Some(
            "MoonFlow receiver status unavailable: " + error,
          ),
        },
      )
    SettleMoonFlowReceipt =>
      match moonflow_review_binding_issue(model) {
        Some(issue) =>
          (
            @rabbita.none,
            {
              ..model,
              moonflow_receiver_error: Some(issue),
              notice: None,
            },
          )
        None =>
          match (model.moonflow_intake, model.review_workflow) {
            (
              Some(handoff),
              Some({
                state: "awaiting-moonchat" | "ready-for-bookkeeper",
                ..
              }),
            ) =>
              (
                prepare_moonflow_receiver_receipt(emit, handoff),
                {
                  ..model,
                  moonflow_receipt_reply: None,
                  moonflow_receiver_error: None,
                  notice: Some(
                    "Binding the durable review bundle, authority, digest, and acceptance evidence to this MoonFlow handoff…",
                  ),
                },
              )
            _ =>
              (
                @rabbita.none,
                {
                  ..model,
                  moonflow_receiver_error: Some(
                    "A durable portable review bundle is required before MoonFlow can be settled.",
                  ),
                  notice: None,
                },
              )
          }
      }
    MoonFlowReceiptPrepared(Ok(reply)) =>
      if !valid_moonflow_receipt_reply(
        reply,
        model.moonflow_run_id,
        model.moonflow_handoff_token,
      ) {
        (
          @rabbita.none,
          {
            ..model,
            moonflow_receipt_reply: None,
            moonflow_receiver_error: Some(
              "MoonFind returned an unsupported or cross-run MoonFlow receiver receipt.",
            ),
            notice: None,
          },
        )
      } else {
        (
          post_moonflow_receiver_receipt(emit, reply),
          {
            ..model,
            moonflow_receipt_reply: Some(reply),
            moonflow_receiver_error: None,
            notice: Some(
              "The immutable pack receipt is ready; returning it through MoonDesk for MoonFlow reconciliation…",
            ),
          },
        )
      }
    MoonFlowReceiptPrepared(Err(error)) =>
      (
        @rabbita.none,
        {
          ..model,
          moonflow_receipt_reply: None,
          moonflow_receiver_error: Some(
            "MoonFind could not prepare the handoff-bound receipt: " + error,
          ),
          notice: None,
        },
      )
    MoonFlowReceiptPosted(Ok(status)) =>
      if !valid_moonflow_status(
        status,
        model.moonflow_run_id,
        model.moonflow_handoff_token,
      ) ||
        status.status != "accepted" {
        (
          @rabbita.none,
          {
            ..model,
            moonflow_receiver_status: Some(status),
            moonflow_receiver_error: Some(
              "MoonFlow did not accept the exact MoonFind receiver receipt.",
            ),
            notice: None,
          },
        )
      } else {
        (
          load_workspace_snapshot(emit),
          {
            ..model,
            moonflow_receiver_status: Some(status),
            moonflow_receiver_error: None,
            notice: Some(
              "MoonFlow accepted the exact review-bundle receipt. Return to Flow to inspect the next ready Work item.",
            ),
          },
        )
      }
    MoonFlowReceiptPosted(Err(error)) =>
      (
        @rabbita.none,
        {
          ..model,
          moonflow_receiver_error: Some(
            "MoonFlow receiver reconciliation failed: " + error,
          ),
          notice: None,
        },
      )
    PrepareQa =>
      if !model.gateway_published {
        (
          @rabbita.none,
          with_sidecar_error(
            model, "The trusted host did not publish a reachable MoonClaw Q&A gateway.",
          ),
        )
      } else {
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
