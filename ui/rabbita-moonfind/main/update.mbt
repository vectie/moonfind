///|
fn with_error(model : Model, error : String) -> Model {
  { ..model, phase: Failed, error: Some(error), notice: None, }
}

///|
fn with_sidecar_error(model : Model, error : String) -> Model {
  { ..model, error: Some(error), notice: None, }
}

///|
fn with_review_error(model : Model, error : String) -> Model {
  {
    ..model,
    review_phase: ReviewFailed,
    review_pending_context: None,
    error: Some(error),
    notice: None,
  }
}

///|
fn update(
  emit : @rabbita.Emit[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  let (command, next) = update_message(emit, msg, model)
  // Every workspace reload hides the previous package immediately, including
  // refreshes initiated by other panels. Old asynchronous replies stay inert.
  if next.workspace_generation != model.workspace_generation {
    (
      command,
      { ..next, delivery: empty_delivery(next.delivery.generation + 1), },
    )
  } else {
    (command, next)
  }
}

///|
fn update_message(
  emit : @rabbita.Emit[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    RefreshDelivery
    | PrepareDelivery
    | SelectDelivery(_)
    | DeliveryLoaded(_, _) => update_delivery(emit, msg, model)
    RefreshSeriesCatalog =>
      (load_series_catalog(emit), { ..model, series_error: None, })
    SeriesCatalogLoaded(Ok(catalog)) => {
      let valid = catalog.filter(item => series_template_issues(item).is_empty())
      let selected = if valid.any(item => {
          item.use_case_id == model.selected_series_id
        }) {
        model.selected_series_id
      } else {
        valid.get(0).map(item => item.use_case_id).unwrap_or("")
      }
      let selected_phase = valid
        .filter(item => item.use_case_id == selected)
        .get(0)
        .bind(item => {
          if item.phases.any(phase => {
              phase.phase_id == model.selected_series_phase_id
            }) {
            Some(model.selected_series_phase_id)
          } else {
            item.phases.get(0).map(phase => phase.phase_id)
          }
        })
        .unwrap_or("")
      if !selected.is_blank() {
        persist_series_selection(selected, selected_phase)
      }
      (
        @rabbita.none,
        {
          ..model,
          series_catalog: valid,
          selected_series_id: selected,
          selected_series_phase_id: selected_phase,
          series_error: if valid.is_empty() {
            Some(
              "No structurally valid series template is currently published.",
            )
          } else {
            None
          },
        },
      )
    }
    SeriesCatalogLoaded(Err(error)) =>
      (
        @rabbita.none,
        { ..model, series_error: Some("Series catalog unavailable: " + error), },
      )
    SelectSeries(use_case_id) =>
      if model.series_catalog.any(item => item.use_case_id == use_case_id) {
        let phase_id = model.series_catalog
          .filter(item => item.use_case_id == use_case_id)
          .get(0)
          .bind(item => item.phases.get(0))
          .map(phase => phase.phase_id)
          .unwrap_or("")
        persist_series_selection(use_case_id, phase_id)
        (
          @rabbita.none,
          {
            ..model,
            selected_series_id: use_case_id,
            selected_series_phase_id: phase_id,
            inspected_series: None,
            series_action_status: None,
            series_error: None,
          },
        )
      } else {
        (
          @rabbita.none,
          {
            ..model,
            series_error: Some(
              "The selected series is not in the validated catalog.",
            ),
          },
        )
      }
    SelectSeriesPhase(phase_id) =>
      match
        model.series_catalog
        .filter(item => item.use_case_id == model.selected_series_id)
        .get(0) {
        Some(series) if series.phases.any(phase => phase.phase_id == phase_id) => {
          persist_series_selection(series.use_case_id, phase_id)
          (@rabbita.none, { ..model, selected_series_phase_id: phase_id, })
        }
        _ =>
          (
            @rabbita.none,
            {
              ..model,
              series_error: Some(
                "The selected phase is not part of this series.",
              ),
            },
          )
      }
    ValidateSeriesTemplate =>
      if model.selected_series_id.is_blank() {
        (
          @rabbita.none,
          {
            ..model,
            series_error: Some(
              "Select a published series before validating its template.",
            ),
          },
        )
      } else {
        (
          validate_series_template(emit, model.selected_series_id),
          {
            ..model,
            series_action_loading: true,
            series_action_status: Some(
              "Validating the catalog contract and desired-graph shape…",
            ),
            series_error: None,
          },
        )
      }
    SeriesTemplateLoaded(Ok(series)) => {
      let issues = series_template_issues(series)
      if series.use_case_id != model.selected_series_id {
        issues.push("template result belongs to another series")
      }
      if issues.is_empty() {
        (
          @rabbita.none,
          {
            ..model,
            inspected_series: Some(series),
            series_action_loading: false,
            series_action_status: Some(
              "Catalog shape validated only. Execution has not started: capability and semantic projection, source bundles, live health, request materialization, authority, and receipts are still pending in MoonDesk and MoonFlow.",
            ),
            series_error: None,
          },
        )
      } else {
        (
          @rabbita.none,
          {
            ..model,
            inspected_series: None,
            series_action_loading: false,
            series_action_status: None,
            series_error: Some(
              "Series template validation failed: " + issues.join("; "),
            ),
          },
        )
      }
    }
    SeriesTemplateLoaded(Err(error)) =>
      (
        @rabbita.none,
        {
          ..model,
          inspected_series: None,
          series_action_loading: false,
          series_action_status: None,
          series_error: Some("Series template unavailable: " + error),
        },
      )
    RefreshMoonTownStatus =>
      (
        load_workspace_snapshot(emit, model.workspace_generation + 1),
        {
          ..model,
          workspace_generation: model.workspace_generation + 1,
          notice: Some("Refreshing the correlated MoonTown result state…"),
          error: None,
        },
      )
    WorkspaceLoaded(generation, _) if generation != model.workspace_generation =>
      (@rabbita.none, model)
    WorkspaceLoaded(_, Ok(snapshot)) =>
      if !valid_workspace_snapshot(snapshot) {
        (
          @rabbita.none,
          with_sidecar_error(
            { ..model, qa_readback_loading: false, },
            "MoonFind host returned an unsupported or cross-run workspace contract.",
          ),
        )
      } else {
        let gateway_base = gateway_base_from_snapshot(
          snapshot,
          model.gateway_base,
        )
        let gateway_published = has_published_gateway(snapshot)
        let review_model = adopt_review_context(model, snapshot)
        let (delivery_command, review_model) = if current_synthesis(
            review_model,
          )
          is Some(_) {
          begin_delivery(emit, review_model, None, false)
        } else {
          (
            @rabbita.none,
            {
              ..review_model,
              delivery: {
                ..empty_delivery(model.delivery.generation + 1),
                workspace_ready: true,
              },
            },
          )
        }
        let phase = phase_from_durable_execution(snapshot.research_execution)
        let commands : Array[@rabbita.Cmd] = []
        let new_run = model.workspace.map(ws => ws.run_id) !=
          Some(snapshot.workspace.run_id)
        let snapshot_qa_key = snapshot.qa_cowork_session_key.filter(key => {
          !key.is_blank()
        })
        // An older in-flight snapshot must not erase an acknowledged key and
        // reopen creation within the same immutable run/Book/gateway scope.
        let keep_known_key = snapshot_qa_key is None &&
          model.qa_canonical_key is Some(_) &&
          !new_run &&
          gateway_published &&
          gateway_base == model.gateway_base &&
          snapshot.book_workspace == model.trusted_book_dir
        let qa_key = if keep_known_key {
          model.qa_canonical_key
        } else {
          snapshot_qa_key
        }
        let qa_state = if keep_known_key &&
          snapshot_qa_state(snapshot) == "not-created" {
          "retained"
        } else {
          snapshot_qa_state(snapshot)
        }
        let book_dir = if new_run || model.book_dir == model.trusted_book_dir {
          snapshot.book_workspace
        } else {
          model.book_dir
        }
        let qa_context_changed = new_run ||
          !gateway_published ||
          gateway_base != model.gateway_base ||
          snapshot.book_workspace != model.trusted_book_dir ||
          qa_key != model.qa_canonical_key ||
          qa_state == "reconnect-required" ||
          qa_state == "creation-uncertain"
        let evidence_changed = qa_projection_context({
            ..model,
            workspace: Some(snapshot.workspace),
            moontown_handoff: Some(snapshot.moontown_handoff),
            review_workflow: Some(snapshot.review_workflow),
          }) !=
          qa_projection_context(model)
        let next_route_generation = model.route_generation + 1
        commands.push(load_native_route(emit, next_route_generation))
        // Q&A restores its selection only after the full retained binding is
        // verified. The research selection lookup cannot authorize Q&A.
        let saved_key = snapshot.research_cowork_session_key
        if saved_key is Some(key) && !key.is_blank() && gateway_published {
          commands.push(
            load_saved_selection(
              emit,
              gateway_base,
              key,
              snapshot.workspace.run_id,
            ),
          )
        }
        match snapshot.research_cowork_session_key {
          Some(key) if !key.is_blank() &&
            gateway_published &&
            execution_needs_session_refresh(snapshot.research_execution) =>
            commands.push(
              refresh_session(
                emit,
                gateway_base,
                key,
                false,
                snapshot.workspace.run_id,
              ),
            )
          _ => ()
        }
        let pending_qa = if qa_context_changed ||
          evidence_changed ||
          model.pending_qa
          .map(request => {
            request.workspace_generation != model.workspace_generation
          })
          .unwrap_or(false) {
          None
        } else {
          model.pending_qa
        }
        let pending_question = if qa_context_changed || evidence_changed {
          None
        } else {
          model.pending_question
        }
        let restore_request = match qa_key {
          Some(key) if !key.is_blank() &&
            gateway_published &&
            qa_state == "retained" &&
            book_dir == snapshot.book_workspace &&
            pending_qa is None &&
            pending_question is None &&
            (
              qa_context_changed ||
              model.qa_session is None ||
              model.qa_readback_loading
            ) =>
            Some(QaRestoreRequest::{
              workspace_generation: model.workspace_generation,
              run_id: snapshot.workspace.run_id,
              gateway: gateway_base,
              cwd: snapshot.book_workspace,
              session_key: key,
            })
          _ => None
        }
        if restore_request is Some(request) {
          commands.push(reconnect_qa_session(emit, request))
        }
        commands.push(delivery_command)
        (
          @rabbita.batch(commands),
          {
            ..review_model,
            gateway_base,
            gateway_published,
            native_route: None,
            route_generation: next_route_generation,
            route_loading: true,
            route_error: None,
            saved_selection_key: if gateway_published {
              saved_key
            } else {
              None
            },
            saved_selection_error: if saved_key is Some(_) && !gateway_published {
              Some(
                "The saved model selection cannot be restored because Cowork is unavailable.",
              )
            } else {
              None
            },
            model_name: if new_run && model.model_source != "user" {
              ""
            } else {
              model.model_name
            },
            model_source: if new_run && model.model_source != "user" {
              "automatic"
            } else {
              model.model_source
            },
            pending_research: if new_run {
              None
            } else {
              model.pending_research
            },
            research_message_sent: if new_run {
              false
            } else {
              model.research_message_sent
            },
            pending_qa,
            pending_question,
            qa_canonical_key: qa_key,
            qa_agent_status: qa_state,
            pending_qa_restore: restore_request,
            qa_readback_loading: false,
            qa_error: if new_run || restore_request is Some(_) {
              None
            } else if evidence_changed && model.pending_question is Some(_) {
              Some(
                "The run evidence changed while answering. The old response will be ignored. Your draft is kept; retry with the current evidence.",
              )
            } else {
              model.qa_error
            },
            qa_response_context: if qa_context_changed || evidence_changed {
              None
            } else {
              model.qa_response_context
            },
            qa_answered_question: if qa_context_changed || evidence_changed {
              None
            } else {
              model.qa_answered_question
            },
            book_dir,
            trusted_book_dir: snapshot.book_workspace,
            phase,
            research_session: if new_run ||
              phase == Completed ||
              !gateway_published {
              None
            } else {
              model.research_session
            },
            qa_session: if !qa_context_changed &&
              restore_request is None &&
              !(evidence_changed && model.pending_qa is Some(_)) {
              model.qa_session
            } else {
              None
            },
            review_phase: if review_model.review_pending_context ==
              Some(review_result_context(review_model)) {
              ReviewPreparing
            } else {
              review_phase_from_workflow(snapshot.review_workflow)
            },
            qa_ready: !qa_context_changed &&
            restore_request is None &&
            model.qa_ready,
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
    WorkspaceLoaded(_, Err(error)) =>
      (
        @rabbita.none,
        with_sidecar_error(
          { ..model, qa_readback_loading: false, },
          "Workspace snapshot unavailable: " + error,
        ),
      )
    RefreshModelRoutes =>
      if model.route_loading ||
        !model.gateway_published ||
        model.workspace is None ||
        model.book_dir != model.trusted_book_dir {
        (@rabbita.none, model)
      } else {
        (
          load_native_route(emit, model.route_generation + 1),
          {
            ..model,
            route_generation: model.route_generation + 1,
            route_loading: true,
            route_error: None,
            native_route: None,
          },
        )
      }
    SelectCatalogModel(generation, selector) =>
      (@rabbita.none, select_catalog_model(model, generation, selector))
    UseConfiguredDefault(generation) =>
      match current_model_catalog(model).bind(verified_default) {
        Some(selector) =>
          (@rabbita.none, select_catalog_model(model, generation, selector))
        None => (@rabbita.none, model)
      }
    NativeRouteLoaded(generation, Ok(route)) =>
      if generation != model.route_generation {
        (@rabbita.none, model)
      } else if !route_matches_workspace(model, route) {
        (
          @rabbita.none,
          {
            ..model,
            native_route: None,
            route_loading: false,
            route_error: Some(
              "The model catalog did not match this research workspace. Refresh models to retry.",
            ),
          },
        )
      } else {
        (@rabbita.none, apply_native_route(model, generation, route))
      }
    NativeRouteLoaded(generation, Err(_)) =>
      if generation == model.route_generation {
        (
          @rabbita.none,
          {
            ..model,
            native_route: None,
            route_loading: false,
            route_error: Some(
              "Model discovery failed. Check the MoonClaw and MoonGate connection, then refresh models.",
            ),
          },
        )
      } else {
        (@rabbita.none, model)
      }
    SavedSelectionRestored(run_id, key, _) if model.workspace.map(ws => {
        ws.run_id
      }) !=
      Some(run_id) ||
      model.saved_selection_key != Some(key) => (@rabbita.none, model)
    SavedSelectionRestored(_, _, Ok(session)) => {
      let restored = restore_model_selection(model, session)
      let restored = match restored.native_route {
        Some(route) =>
          apply_native_route(restored, restored.route_generation, route)
        None => restored
      }
      (@rabbita.none, restored)
    }
    SavedSelectionRestored(_, _, Err(_)) =>
      (
        @rabbita.none,
        {
          ..model,
          saved_selection_key: None,
          saved_selection_error: Some(
            "The saved model selection could not be restored. Retry workspace refresh or explicitly choose a model.",
          ),
        },
      )
    SetBookDir(value) =>
      (
        if value == model.trusted_book_dir {
          load_native_route(emit, model.route_generation + 1)
        } else {
          @rabbita.none
        },
        {
          ..invalidate_unsubmitted_selection(model),
          book_dir: value,
          native_route: None,
          route_loading: value == model.trusted_book_dir,
          route_error: None,
          qa_session: if value != model.book_dir {
            None
          } else {
            model.qa_session
          },
          qa_ready: value == model.book_dir && model.qa_ready,
          pending_qa_restore: None,
          route_generation: model.route_generation + 1,
        },
      )
    SetModelName(value) =>
      (
        @rabbita.none,
        {
          ..invalidate_unsubmitted_selection(model),
          model_name: value,
          model_source: "user",
        },
      )
    SetReviewerName(value) =>
      (@rabbita.none, { ..model, reviewer_name: value, })
    SetReviewOutcome(value) =>
      (@rabbita.none, { ..model, review_outcome: value, })
    SetReviewScope(value) => (@rabbita.none, { ..model, review_scope: value, })
    ToggleResultIdea(context, id) =>
      (@rabbita.none, toggle_result_idea(model, context, id))
    SetResultPage(page) =>
      (@rabbita.none, { ..model, result_page: page.max(0), })
    SetReviewMessage(value) =>
      (@rabbita.none, { ..model, review_message: value, })
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
      (@rabbita.none, { ..model, information_gap_summary: value, })
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
      (@rabbita.none, { ..model, recognition_gap_summary: value, })
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
      (@rabbita.none, { ..model, decisiveness_gap_summary: value, })
    SetQaQuestion(value) => (@rabbita.none, { ..model, qa_question: value, })
    StartResearch if model.pending_research is Some(_) => (@rabbita.none, model)
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
              if model_route_issue(model, model.book_dir) is Some(issue) &&
                model.research_session is None {
                (@rabbita.none, with_error(model, issue))
              } else if !model.gateway_published {
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
                        execution.run_id,
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
                        submission_context(
                          model,
                          model.submission_generation + 1,
                        ),
                      ),
                      {
                        ..model,
                        submission_generation: model.submission_generation + 1,
                        pending_research: Some(
                          submission_context(
                            model,
                            model.submission_generation + 1,
                          ),
                        ),
                        phase: CreatingSession,
                        research_message_sent: false,
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
                      refresh_session(
                        emit,
                        model.gateway_base,
                        key,
                        false,
                        execution.run_id,
                      ),
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
    CapabilitySubmitted(context, _) if !execution_context_current(
        model, context,
      ) => (@rabbita.none, model)
    CapabilitySubmitted(_, Ok(reply)) if !execution_reply_current(
        model,
        reply.execution,
      ) => (@rabbita.none, model)
    CapabilitySubmitted(_, Ok(reply)) if model.research_execution
      .map(current => {
        current.state == "command-ready" &&
        reply.execution.state == "command-ready" &&
        reply.execution.revision <= current.revision
      })
      .unwrap_or(false) => (@rabbita.none, model)
    CapabilitySubmitted(_, Ok(reply)) => {
      let execution = reply.execution
      let ready = execution.state == "command-ready"
      let gateway_missing = ready && !model.gateway_published
      let route_issue = if ready {
        model_route_issue(model, model.book_dir)
      } else {
        None
      }
      let reply_notice = if ready {
        "Capability reconciled. Submitting its exact command through MoonClaw Cowork…"
      } else {
        reply.message +
        " State: \{execution.state}. Next: \{execution.next_action}."
      }
      (
        if ready && !reply.blocked && !gateway_missing && route_issue is None {
          create_research_session(
            emit,
            submission_context(model, model.submission_generation + 1),
          )
        } else {
          @rabbita.none
        },
        {
          ..model,
          research_execution: Some(execution),
          research_message_sent: false,
          submission_generation: model.submission_generation + 1,
          pending_research: if ready &&
            !reply.blocked &&
            !gateway_missing &&
            route_issue is None {
            Some(submission_context(model, model.submission_generation + 1))
          } else {
            None
          },
          phase: if gateway_missing || reply.blocked || route_issue is Some(_) {
            Failed
          } else if ready {
            CreatingSession
          } else {
            Running
          },
          notice: if reply.blocked || gateway_missing || route_issue is Some(_) {
            None
          } else {
            Some(reply_notice)
          },
          error: if route_issue is Some(_) {
            route_issue
          } else if gateway_missing {
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
    CapabilitySubmitted(_, Err(error)) =>
      (@rabbita.none, with_error(model, error))
    ResearchSessionCreated(request, _) if !submission_current(
        model,
        request,
        model.pending_research,
      ) => (@rabbita.none, model)
    ResearchSessionCreated(request, Ok(session)) =>
      (
        configure_research_session(emit, session, request),
        {
          ..model,
          phase: CreatingSession,
          research_session: Some(session),
          notice: Some("Applying the selected folder and model…"),
        },
      )
    ResearchSessionCreated(_, Err(error)) =>
      (
        @rabbita.none,
        with_error(
          { ..model, pending_research: None, research_session: None, },
          error,
        ),
      )
    ResearchConfigured(request, _) if !submission_current(
        model,
        request,
        model.pending_research,
      ) => (@rabbita.none, model)
    ResearchConfigured(request, Ok(session)) if configured_selection_issue(
        request, session,
      )
      is Some(issue) =>
      (
        @rabbita.none,
        with_error(
          { ..model, pending_research: None, research_session: None, },
          issue,
        ),
      )
    ResearchConfigured(request, Ok(session)) =>
      match model.research_execution {
        Some(execution) if execution.state == "command-ready" =>
          (
            submit_prepared_research_command(
              emit,
              model.gateway_base,
              session,
              model.book_dir,
              execution,
              request,
            ),
            {
              ..model,
              phase: Confirming,
              research_message_sent: true,
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
              {
                ..model,
                research_session: None,
                pending_research: None,
                research_message_sent: false,
              },
              "MoonClaw session created without a command-ready capability receipt.",
            ),
          )
      }
    ResearchConfigured(_, Err(error)) =>
      (
        @rabbita.none,
        with_error(
          { ..model, pending_research: None, research_session: None, },
          error,
        ),
      )
    ResearchCommandSubmitted(request, _) if model.workspace.map(ws => ws.run_id) !=
      Some(request.run_id) ||
      model.gateway_base != request.gateway => (@rabbita.none, model)
    ResearchCommandSubmitted(_, Ok(session)) => {
      let checkpoint = match model.capability_checkpoint_url {
        Some(url) if !url.is_blank() =>
          checkpoint_research_execution(
            emit,
            url,
            session,
            model.research_execution,
          )
        _ => @rabbita.none
      }
      (
        checkpoint,
        {
          ..model,
          pending_research: None,
          phase: phase_from_session(session),
          research_session: Some(session),
          notice: Some(
            "MoonClaw accepted the exact command; persisting its session before polling for the run…",
          ),
          error: None,
        },
      )
    }
    ResearchCommandSubmitted(_, Err(error)) =>
      (@rabbita.none, with_error({ ..model, pending_research: None, }, error))
    ExecutionCheckpointed(context, _) if !execution_context_current(
        model, context,
      ) => (@rabbita.none, model)
    ExecutionCheckpointed(_, Ok(reply)) if !execution_reply_current(
        model,
        reply.execution,
      ) => (@rabbita.none, model)
    ExecutionCheckpointed(_, Ok(reply)) =>
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
    ExecutionCheckpointed(_, Err(error)) =>
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
              model.workspace.map(ws => ws.run_id).unwrap_or(""),
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
    ResearchRefreshed(run_id, _) if model.workspace.map(ws => ws.run_id) !=
      Some(run_id) => (@rabbita.none, model)
    ResearchRefreshed(_, Ok(session)) =>
      (
        match model.capability_checkpoint_url {
          Some(url) if !url.is_blank() =>
            checkpoint_research_execution(
              emit,
              url,
              session,
              model.research_execution,
            )
          _ => @rabbita.none
        },
        {
          ..restore_model_selection(model, session),
          phase: phase_from_session(session),
          research_session: Some(session),
          notice: Some("Research state refreshed."),
          error: session.linked_run.bind(run => run.error),
        },
      )
    ResearchRefreshed(_, Err(error)) =>
      (@rabbita.none, with_error(model, error))
    PrepareReview if model.review_phase == ReviewPreparing =>
      (@rabbita.none, model)
    PrepareReview => {
      let issues = review_request_issues(
          model.reviewer_name,
          model.review_outcome,
          model.review_scope,
          model.review_message,
        ) +
        review_gap_issues(model) +
        result_review_issues(model)
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
          Some({ state: "ready-for-human-review", prepare_url: Some(url), .. }) if !url.is_blank() =>
            (
              prepare_portable_review(
                emit,
                url,
                model,
                model.review_request_generation + 1,
              ),
              {
                ..model,
                review_phase: ReviewPreparing,
                review_request_generation: model.review_request_generation + 1,
                review_pending_context: Some(review_result_context(model)),
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
    ReviewPrepared(generation, context, _) if generation !=
      model.review_request_generation ||
      model.review_pending_context != Some(context) ||
      review_result_context(model) != context => (@rabbita.none, model)
    ReviewPrepared(_, _, Ok(reply)) =>
      if reply.contract_id != "moonfind.review-prepare-reply.v1" ||
        reply.state != "awaiting-moonchat" ||
        reply.operation_ref != "moonchat/conversation.review.record@0.1.0" ||
        model.moontown_result.bind(result => result.source_digest) !=
        Some(reply.source_digest) ||
        model.workspace
        .map(value => value.run_id != reply.run_id)
        .unwrap_or(true) {
        (
          @rabbita.none,
          with_review_error(
            model, "MoonFind returned an unsupported or cross-run review bundle receipt.",
          ),
        )
      } else {
        (
          @rabbita.batch([
            load_workspace_snapshot(emit, model.workspace_generation + 1),
            load_moonflow_receiver(
              emit,
              model.moonflow_run_id,
              model.moonflow_handoff_token,
            ),
          ]),
          {
            ..model,
            review_phase: ReviewBundleReady,
            review_pending_context: None,
            workspace_generation: model.workspace_generation + 1,
            review_prepare_reply: Some(reply),
            notice: Some(
              "The portable review bundle is durable. MoonFlow may now execute MoonChat; MoonBook remains the only Bookkeeper authority.",
            ),
            error: None,
          },
        )
      }
    ReviewPrepared(_, _, Err(error)) =>
      (
        @rabbita.none,
        with_review_error({ ..model, review_pending_context: None, }, error),
      )
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
        (@rabbita.none, { ..model, moonflow_intake: Some(handoff), })
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
        (@rabbita.none, { ..model, moonflow_receiver_status: Some(status), })
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
            { ..model, moonflow_receiver_error: Some(issue), notice: None, },
          )
        None =>
          match (model.moonflow_intake, model.review_workflow) {
            (
              Some(handoff),
              Some({ state: "awaiting-moonchat" | "ready-for-bookkeeper", .. }),
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
          load_workspace_snapshot(emit, model.workspace_generation + 1),
          {
            ..model,
            moonflow_receiver_status: Some(status),
            moonflow_receiver_error: None,
            notice: Some(
              "MoonFlow accepted the exact review-bundle receipt. Return to Flow to inspect the next ready Work item.",
            ),
            workspace_generation: model.workspace_generation + 1,
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
    RefreshQa if model.qa_readback_loading => (@rabbita.none, model)
    RefreshQa =>
      (
        load_workspace_snapshot(emit, model.workspace_generation + 1),
        {
          ..model,
          workspace_generation: model.workspace_generation + 1,
          book_dir: model.trusted_book_dir,
          pending_qa: None,
          pending_question: None,
          qa_agent_status: if model.pending_qa is Some(_) &&
            model.qa_canonical_key is None {
            "creation-uncertain"
          } else {
            model.qa_agent_status
          },
          qa_ready: false,
          pending_qa_restore: None,
          qa_readback_loading: true,
          qa_response_context: None,
          qa_answered_question: None,
          qa_answer_text: None,
          notice: Some(
            "Checking the durable Q&A identity without creating or messaging a session…",
          ),
          error: None,
        },
      )
    PrepareQa | FinishQaPreparation if model.pending_qa is Some(_) ||
      model.pending_question is Some(_) ||
      model.pending_qa_restore is Some(_) ||
      model.qa_readback_loading => (@rabbita.none, model)
    PrepareQa if model.qa_canonical_key is Some(_) ||
      model.qa_session is Some(_) ||
      model.qa_agent_status != "not-created" =>
      (
        @rabbita.none,
        {
          ..model,
          qa_error: Some(
            qa_retained_issue(model).unwrap_or(
              "A retained Q&A session already exists. Finish its preparation or check its state; do not create a replacement.",
            ),
          ),
        },
      )
    FinishQaPreparation => {
      if qa_retained_issue(model) is Some(issue) {
        return (@rabbita.none, { ..model, qa_error: Some(issue), })
      }
      if !model.gateway_published || model.qa_agent_status != "retained" {
        return (
          @rabbita.none,
          {
            ..model,
            qa_error: Some(
              "Check the retained Q&A session before finishing preparation.",
            ),
          },
        )
      }
      if model.qa_ready {
        return (@rabbita.none, model)
      }
      if model_route_issue(model, qa_workspace(model)) is Some(issue) {
        return (@rabbita.none, with_sidecar_error(model, issue))
      }
      match model.qa_session {
        Some(session) if qa_session_key_matches(model, session) &&
          session.session.cwd == Some(model.book_dir) => {
          let request = submission_context(
            model,
            model.submission_generation + 1,
          )
          (
            configure_qa_session(emit, session, request),
            {
              ..model,
              submission_generation: request.generation,
              pending_qa: Some(request),
              qa_error: None,
              error: None,
              notice: Some(
                "Finishing preparation of the existing Q&A session…",
              ),
            },
          )
        }
        _ =>
          (
            @rabbita.none,
            {
              ..model,
              qa_error: Some(
                "Check the retained Q&A session before finishing preparation.",
              ),
            },
          )
      }
    }
    PrepareQa =>
      if !model.gateway_published {
        (
          @rabbita.none,
          with_sidecar_error(
            model, "The trusted host did not publish a reachable MoonClaw Q&A gateway.",
          ),
        )
      } else {
        let cwd = qa_workspace(model)
        if model_route_issue(model, cwd) is Some(issue) {
          return (@rabbita.none, with_sidecar_error(model, issue))
        }
        (
          create_qa_session(emit, {
            ..submission_context(model, model.submission_generation + 1),
            cwd,
          }),
          {
            ..model,
            submission_generation: model.submission_generation + 1,
            pending_qa: Some({
              ..submission_context(model, model.submission_generation + 1),
              cwd,
            }),
            qa_agent_status: "creating",
            notice: Some("Creating Q&A for the current research evidence…"),
            qa_ready: false,
            qa_session: None,
            pending_question: None,
            qa_error: None,
            qa_response_context: None,
            qa_answered_question: None,
            error: None,
          },
        )
      }
    QaSessionCreated(request, _) if !qa_submission_current(model, request) =>
      (@rabbita.none, model)
    QaSessionCreated(_, Ok(session)) if session.session.session_key.is_blank() ||
      session.session.cwd != Some(model.book_dir) =>
      (
        load_workspace_snapshot(emit, model.workspace_generation + 1),
        {
          ..model,
          workspace_generation: model.workspace_generation + 1,
          pending_qa: None,
          qa_session: None,
          qa_ready: false,
          qa_agent_status: "creation-uncertain",
          qa_readback_loading: true,
          qa_error: Some(
            "The creation reply did not confirm the selected Book and a canonical key. Reading durable state before any retry.",
          ),
        },
      )
    QaSessionCreated(request, Ok(session)) =>
      (
        configure_qa_session(emit, session, request),
        {
          ..model,
          qa_session: Some(session),
          qa_canonical_key: Some(session.session.session_key),
          qa_agent_status: "retained",
          notice: Some("Binding Q&A to the research workspace and model…"),
        },
      )
    QaSessionCreated(_, Err(error)) =>
      (
        load_workspace_snapshot(emit, model.workspace_generation + 1),
        {
          ..model,
          workspace_generation: model.workspace_generation + 1,
          pending_qa: None,
          qa_session: None,
          qa_ready: false,
          qa_agent_status: "creation-uncertain",
          qa_readback_loading: true,
          qa_error: Some(
            "Creation reply unavailable: " +
            error +
            ". Checking durable state before any explicit retry.",
          ),
          notice: None,
        },
      )
    QaConfigured(request, _) if !qa_submission_current(model, request) =>
      (@rabbita.none, model)
    QaConfigured(_, Ok(session)) if !qa_session_key_matches(model, session) =>
      (
        @rabbita.none,
        qa_preparation_failed(
          model, "The configuration reply belongs to another Q&A session.",
        ),
      )
    QaConfigured(request, Ok(session)) if configured_selection_issue(
        request, session,
      )
      is Some(issue) => (@rabbita.none, qa_preparation_failed(model, issue))
    QaConfigured(request, Ok(session)) =>
      (
        bootstrap_qa_session(
          emit,
          request.gateway,
          session,
          request.cwd,
          request,
        ),
        {
          ..model,
          qa_session: Some(session),
          notice: Some(
            "Grounding Q&A in the selected run's projected evidence…",
          ),
        },
      )
    QaConfigured(_, Err(error)) =>
      (@rabbita.none, qa_preparation_failed(model, error))
    QaBootstrapped(request, _) if !qa_submission_current(model, request) =>
      (@rabbita.none, model)
    QaBootstrapped(request, Ok(session)) if !qa_session_key_matches(
        model, session,
      ) ||
      configured_selection_issue(request, session) is Some(_) =>
      (
        @rabbita.none,
        qa_preparation_failed(
          model, "The preparation reply did not match the retained session, Book and exact model.",
        ),
      )
    QaBootstrapped(_, Ok(session)) => {
      let response = new_assistant_reply(
        model.qa_session
        .map(previous => previous.messages.map(message => message.id))
        .unwrap_or([]),
        session,
      )
      (
        @rabbita.none,
        {
          ..model,
          pending_qa: None,
          qa_session: Some(session),
          qa_ready: true,
          qa_response_context: response.map(_ => qa_projection_context(model)),
          qa_answered_question: None,
          qa_answer_text: response,
          notice: Some(
            "Q&A preparation finished with this run's evidence supplied.",
          ),
          error: None,
        },
      )
    }
    QaBootstrapped(_, Err(error)) =>
      (@rabbita.none, qa_preparation_failed(model, error))
    QaReconnected(request, _) if !qa_restore_current(model, request) =>
      (@rabbita.none, model)
    QaReconnected(request, Ok(session)) if session.session.session_key !=
      request.session_key ||
      session.session.cwd != Some(request.cwd) =>
      (
        @rabbita.none,
        {
          ..model,
          pending_qa_restore: None,
          qa_session: None,
          qa_ready: false,
          qa_agent_status: "reconnect-required",
          qa_error: Some(
            "The retained-session reply did not match its canonical key and trusted Book. Restore the original host configuration and check again.",
          ),
          notice: None,
        },
      )
    QaReconnected(_, Ok(session)) => {
      let configured = session.session.model_override
        .map(value => !value.trim().is_blank())
        .unwrap_or(false)
      let restored = restore_model_selection(
        { ..model, pending_qa_restore: None, },
        session,
      )
      let restored = match restored.native_route {
        Some(route) =>
          apply_native_route(restored, restored.route_generation, route)
        None => restored
      }
      (
        @rabbita.none,
        {
          ..restored,
          qa_session: Some(session),
          qa_ready: configured,
          qa_response_context: None,
          qa_answered_question: None,
          qa_answer_text: None,
          qa_error: None,
          notice: Some(
            if configured {
              "Retained Q&A restored. Ask explicitly to supply the current evidence; no message was sent during restoration."
            } else {
              "Retained Q&A restored without a configured model. Finish preparation explicitly before asking."
            },
          ),
          error: None,
        },
      )
    }
    QaReconnected(_, Err(error)) =>
      (
        @rabbita.none,
        {
          ..model,
          pending_qa_restore: None,
          qa_ready: false,
          qa_error: Some(
            "Retained Q&A could not be read: " +
            error +
            ". Check again to reconnect the same session; no replacement will be created.",
          ),
          notice: None,
        },
      )
    AskQa if model.pending_question is Some(_) => (@rabbita.none, model)
    AskQa if !model.qa_ready =>
      (
        @rabbita.none,
        with_sidecar_error(
          model, "Wait for the current Q&A preparation to complete.",
        ),
      )
    AskQa =>
      match model.qa_session {
        Some(session) => {
          let cwd = qa_workspace(model)
          if session.session.cwd != Some(cwd) {
            return (
              @rabbita.none,
              {
                ..model,
                qa_error: Some(
                  "The Q&A session belongs to a different workspace. Restore the trusted Book folder and reconnect the retained session.",
                ),
              },
            )
          }
          if session.session.model_override
            .map(value => value.trim().is_blank())
            .unwrap_or(true) {
            (
              @rabbita.none,
              with_sidecar_error(
                model, "The retained Q&A session has no exact model override; configure it before asking.",
              ),
            )
          } else if model_route_issue(
              {
                ..model,
                model_name: session.session.model_override.unwrap_or(""),
                model_source: "saved",
              },
              cwd,
            )
            is Some(issue) {
            (@rabbita.none, with_sidecar_error(model, issue))
          } else if model.qa_question.trim().is_blank() {
            (
              @rabbita.none,
              with_sidecar_error(model, "Enter a question first."),
            )
          } else {
            let request : QaQuestionRequest = {
              run_id: model.workspace.map(ws => ws.run_id).unwrap_or(""),
              session_key: session.session.session_key,
              generation: model.question_generation + 1,
              gateway: model.gateway_base,
              cwd,
              selector: session.session.model_override.unwrap_or(""),
              question: model.qa_question,
              grounding_context: qa_projection_context(model),
              previous_message_ids: session.messages.map(message => message.id),
            }
            (
              ask_qa_session(emit, request),
              {
                ..model,
                question_generation: request.generation,
                pending_question: Some(request),
                qa_error: None,
                notice: Some("Answering from the selected run's evidence…"),
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
    QaAnswered(request, _) if !qa_question_current(model, request) =>
      (@rabbita.none, model)
    QaAnswered(request, Ok(session)) if session.session.session_key !=
      request.session_key ||
      session.session.cwd != Some(request.cwd) ||
      session.session.model_override != Some(request.selector) =>
      (
        @rabbita.none,
        {
          ..model,
          pending_question: None,
          qa_error: Some(
            "The Q&A reply did not match this session, workspace and model. Your question is kept; retry when the session is available.",
          ),
          notice: None,
        },
      )
    QaAnswered(request, Ok(session)) if new_question_answer(request, session)
      is None =>
      (
        @rabbita.none,
        {
          ..model,
          pending_question: None,
          qa_session: Some(session),
          qa_response_context: None,
          qa_answered_question: None,
          qa_answer_text: None,
          qa_error: Some(
            "No new answer was returned for this question. Your draft is kept. Retry explicitly; the session may still be processing the earlier question.",
          ),
          notice: None,
        },
      )
    QaAnswered(request, Ok(session)) =>
      (
        @rabbita.none,
        {
          ..model,
          qa_session: Some(session),
          pending_question: None,
          qa_error: None,
          qa_response_context: Some(request.grounding_context),
          qa_answered_question: Some(request.question),
          qa_answer_text: new_question_answer(request, session),
          notice: Some("Answer received with the session retained."),
          error: None,
        },
      )
    QaAnswered(_, Err(error)) =>
      (
        @rabbita.none,
        {
          ..model,
          pending_question: None,
          qa_error: Some(
            "Answer unavailable: " +
            error +
            ". Your draft is kept. Retry explicitly; a lost reply may mean the prior request reached the session.",
          ),
          notice: None,
        },
      )
  }
}
