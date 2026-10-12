///|
struct CoworkSessionSummary {
  session_key : String
  session_id : String
  title : String
  updated_at : Int
  state : String
  last_message_preview : String?
  channel : String?
  cwd : String?
  model_override : String?
  provider_override : String?
  has_plan_mode : Bool
  linked_proposal_id : String?
  linked_run_id : String?
} derive(Debug, FromJson)

///|
struct CoworkProposalRef {
  id : String
  title : String
  summary : String
  status : String
  request_text : String
  updated_at : Int
} derive(Debug, FromJson)

///|
struct CoworkRunRef {
  id : String
  job_id : String
  status : String
  summary : String?
  error : String?
  current_step_id : String?
  workspace_dir : String?
} derive(Debug, ToJson, FromJson)

///|
struct CoworkMessage {
  id : String
  role : String
  kind : String
  content : String
  timestamp : Int
  metadata : Json
} derive(Debug, FromJson)

///|
struct CoworkSessionDetail {
  session : CoworkSessionSummary
  messages : Array[CoworkMessage]
  plan_preview : String?
  linked_proposal : CoworkProposalRef?
  linked_run : CoworkRunRef?
} derive(Debug, FromJson)

///|
struct CoworkSessionPayload {
  session : CoworkSessionDetail
} derive(Debug, FromJson)

///|
struct CapabilityReceiptProjection {
  output : Json?
} derive(Debug, FromJson)

///|
struct ResearchExecutionProjection {
  contract_id : String
  revision : Int
  run_id : String
  operation_ref : String
  request_id : String
  attempt_id : String
  idempotency_key : String
  state : String
  invocation : Json
  receipt_ref : String?
  receipt : CapabilityReceiptProjection?
  result_ref : String?
  moonclaw_session_key : String?
  moonclaw_run_id : String?
  error_kind : String
  requires_review : Bool
  next_action : String
  updated_at : String
} derive(Debug, FromJson)

///|
struct CapabilityOperationReply {
  contract_id : String
  operation : String
  blocked : Bool
  message : String
  execution : ResearchExecutionProjection
} derive(Debug, FromJson)

///|
struct DurableResearchWorkspace {
  product_id : String
  title : String
  run_id : String
  status : String
  watch_title : String
  query : String
  paper_count : Int
  summary_count : Int
  idea_count : Int
  question_count : Int
  accepted_idea_count : Int
  papers : Array[EvidencePaper]?
  summaries : Array[EvidenceSummary]?
  ideas : Array[EvidenceIdea]?
  questions : Array[EvidenceQuestion]?
  active_stage : String
  validation_issues : Array[String]
  bookkeeper_route : String
  three_gap_state : String
} derive(Debug, FromJson)

///|
struct MoonTownHandoffStatus {
  contract_id : String
  run_id : String
  state : String
  handoff_contract : String
  handoff_id : String?
  handoff_url : String?
  open_url : String?
  receipt_contract : String?
  receipt_status : String?
  detail : String
} derive(Debug, FromJson)

///|
struct ReviewWorkflowStatus {
  contract_id : String
  run_id : String
  state : String
  prepare_url : String?
  moonchat_ingest_url : String?
  moonchat_operation_ref : String?
  bundle_ref : String?
  record_ref : String?
  bookkeeper_operation_ref : String?
  bookkeeper_submission_ref : String?
  detail : String
  decision_receipt : ReviewDecisionReceipt?
} derive(Debug, FromJson)

///|
struct ReviewPrepareReply {
  contract_id : String
  state : String
  run_id : String
  review_id : String
  source_ref : String
  source_digest : String
  bundle_ref : String
  operation_ref : String
  message : String
} derive(Debug, FromJson)

///|
struct MoonFlowHandoffBinding {
  handoff_token : String
  handoff_digest : String
  request_id : String
  attempt_id : String
  idempotency_key : String
  intake_path : String
  status_path : String
  receipt_path : String
  return_path : String
} derive(Debug, ToJson, FromJson)

///|
struct MoonFlowHandoffRun {
  run_id : String
  book_id : String
  work_item_id : String
  declaration_id : String
  product_id : String
  operation : String
  issued_projection_sequence : Int
  issued_work_item_status : String
  issued_run_outcome : String
} derive(Debug, ToJson, FromJson)

///|
struct MoonFlowHandoffAuthority {
  requested_authority : String
  status : String
  granted : Bool
} derive(Debug, ToJson, FromJson)

///|
struct MoonFlowHandoffContracts {
  capability_status : String
  input_contracts : Array[String]
  output_contracts : Array[String]
  required_claim : String
  claim_ceiling : String
} derive(Debug, ToJson, FromJson)

///|
struct MoonFlowHandoffInputs {
  digest : String
  artifacts : Array[String]
} derive(Debug, ToJson, FromJson)

///|
struct MoonFlowHandoffEvidence {
  source_digest : String
  refs : Array[Json]
} derive(Debug, ToJson, FromJson)

///|
struct MoonFlowHandoffReview {
  required : Bool
  status : String
  acceptance_criteria : Array[String]
} derive(Debug, ToJson, FromJson)

///|
struct MoonFlowHandoffEntrypoint {
  kind : String
  pack_id : String
  entrypoint_id : String
  path : String
  fallback_path : String
} derive(Debug, ToJson, FromJson)

///|
struct MoonFlowHandoffPayload {
  action_kind : String
  run : MoonFlowHandoffRun
  authority : MoonFlowHandoffAuthority
  contracts : MoonFlowHandoffContracts
  inputs : MoonFlowHandoffInputs
  evidence : MoonFlowHandoffEvidence
  review : MoonFlowHandoffReview
  app_entrypoint : MoonFlowHandoffEntrypoint
} derive(Debug, ToJson, FromJson)

///|
struct MoonFlowReceiverHandoff {
  contract_id : String
  contract_version : String
  handoff_id : String
  handoff_ref : String
  binding : MoonFlowHandoffBinding
  payload : MoonFlowHandoffPayload
} derive(Debug, ToJson, FromJson)

///|
struct MoonFlowReviewReceiptReply {
  contract_id : String
  run_id : String
  handoff_token : String
  receipt_path : String
  receiver_receipt : Json
  message : String
} derive(Debug, FromJson)

///|
struct MoonFlowReceiverStatus {
  contract_id : String
  contract_version : String
  run_id : String
  handoff_token : String
  handoff_digest : String
  status : String
  stage : String
  work_item_status : String
  run_outcome : String
  projection_sequence : Int
  receipt_ref : String
  receipt_digest : String
  receipt_recorded_at : String
  intake_path : String
  status_path : String
  receipt_path : String
  return_path : String
} derive(Debug, FromJson)

///|
struct WorkspaceSnapshot {
  contract_id : String
  product_id : String
  generated_at : String
  book_workspace : String
  workspace : DurableResearchWorkspace
  research_cowork_session_key : String?
  qa_cowork_session_key : String?
  qa_agent_status : String
  research_execution : ResearchExecutionProjection?
  capability_submit_url : String?
  capability_reconcile_url : String?
  capability_checkpoint_url : String?
  moonclaw_gateway_base : String?
  host_status : String
  host_blockers : Array[String]
  moontown_handoff : MoonTownHandoffStatus
  moontown_result : CompletedResult?
  review_workflow : ReviewWorkflowStatus
} derive(Debug, FromJson)

///|
struct RequestedJobOutput {
  output_id : String
  title : String
  kind : String
  format : String
  acceptance_criteria : Array[String]
} derive(Debug, ToJson, FromJson)

///|
struct ResearchJobBrief {
  contract_id : String
  job_id : String
  objective : String
  audience : String
  source_scope : Array[String]
  requested_outputs : Array[RequestedJobOutput]
  created_at : Int64
} derive(Debug, FromJson)

///|
struct ResearchJobFile {
  name : String
  media_type : String
  byte_length : Int64
  digest : String
  open_url : String
} derive(Debug, FromJson)

///|
struct ResearchJobPreview {
  contract_id : String
  name : String
  media_type : String
  text : String?
  truncated : Bool
  byte_length : Int64
} derive(Debug, FromJson)

///|
struct ResearchJobView {
  contract_id : String
  job : ResearchJobBrief
  job_root : String
  files : Array[ResearchJobFile]
  sources : Array[ResearchJobFile]
  revision_of : String?
  missing_outputs : Array[String]
  session_key : String?
  run_id : String?
  session_state : String?
  session_preview : String?
  run_summary : String?
  moonclaw_gateway_base : String?
  delivery_manifest : Json?
  delivery_ready : Bool
  delivery_issues : Array[String]
} derive(Debug, FromJson)

///|
struct SeriesPhaseProjection {
  phase_id : String
  title : String
  outcome : String
  product_ids : Array[String]
  stage_ids : Array[String]
} derive(Debug, Eq, FromJson)

///|
struct SeriesStageProjection {
  stage_id : String
  product_id : String
  desired_operation_ref : String?
} derive(Debug, Eq, FromJson)

///|
struct SeriesExclusionProjection {
  product_id : String?
  capability : String?
  reason : String
} derive(Debug, Eq, FromJson)

///|
struct SeriesGraphProjection {
  graph_id : String
  stages : Array[SeriesStageProjection]
  intentional_exclusions : Array[SeriesExclusionProjection]?
} derive(Debug, Eq, FromJson)

///|
struct SeriesUseCaseProjection {
  contract_id : String
  use_case_id : String
  title : String
  summary : String
  primary_user : String
  primary_action : String
  completion_statement : String
  phases : Array[SeriesPhaseProjection]
  graph : SeriesGraphProjection
} derive(Debug, Eq, FromJson)

///|
enum ResearchPhase {
  Ready
  CreatingSession
  Confirming
  Running
  NeedsReview
  Completed
  Failed
} derive(Debug, Eq)

///|
enum ReviewPhase {
  ReviewIdle
  ReviewPreparing
  ReviewBundleReady
  ReviewFailed
} derive(Debug, Eq)

///|
struct Model {
  offline_choices : OfflineChoiceState
  offline_generation : Int
  offline_choice_sessions : Map[String, OfflineChoiceState]
  review_storage : ReviewStorage
  brief : BriefView
  choices : ChoiceState
  choice_sessions : Map[String, ChoiceState]
  gateway_base : String
  gateway_published : Bool
  book_dir : String
  trusted_book_dir : String
  model_name : String
  model_source : String
  saved_selection_key : String?
  saved_selection_error : String?
  native_route : NativeModelRoute?
  route_generation : Int
  route_loading : Bool
  route_error : String?
  workspace_generation : Int
  submission_generation : Int
  pending_research : ModelSubmission?
  research_message_sent : Bool
  pending_qa : ModelSubmission?
  qa_canonical_key : String?
  qa_agent_status : String
  pending_qa_restore : QaRestoreRequest?
  qa_readback_loading : Bool
  question_generation : Int
  pending_question : QaQuestionRequest?
  qa_error : String?
  qa_response_context : String?
  qa_answered_question : String?
  qa_answer_text : String?
  job_objective : String
  job_audience : String
  job_sources : String
  job_outputs : String
  job_criteria : String
  job_source_name : String
  job_source_content : String
  job_arxiv_query : String
  job_source_url : String
  job_revision_instruction : String
  job_revision_file : String
  job_preview : ResearchJobPreview?
  job_resume_content : String
  jobs : Array[ResearchJobView]
  selected_job_id : String
  job_status : String
  job_error : String?
  phase : ResearchPhase
  research_session : CoworkSessionDetail?
  qa_session : CoworkSessionDetail?
  review_phase : ReviewPhase
  review_prepare_reply : ReviewPrepareReply?
  review_pending_context : String?
  // Monotonic across result switches: A -> B -> A must not let the first
  // request consume a later preparation for the same result context.
  review_request_generation : Int
  review_drafts : Map[String, ReviewDraft]
  review_context_notice : String?
  delivery : DeliveryView
  result_page : Int
  qa_ready : Bool
  reviewer_name : String
  review_outcome : String
  review_scope : String
  review_message : String
  information_gap_severity : Int
  information_gap_summary : String
  recognition_gap_severity : Int
  recognition_gap_summary : String
  decisiveness_gap_severity : Int
  decisiveness_gap_summary : String
  qa_question : String
  workspace : DurableResearchWorkspace?
  research_execution : ResearchExecutionProjection?
  capability_submit_url : String?
  capability_reconcile_url : String?
  capability_checkpoint_url : String?
  host_status : String
  host_blockers : Array[String]
  moontown_handoff : MoonTownHandoffStatus?
  moontown_result : CompletedResult?
  review_workflow : ReviewWorkflowStatus?
  moonflow_run_id : String
  moonflow_handoff_token : String
  moonflow_intake : MoonFlowReceiverHandoff?
  moonflow_receiver_status : MoonFlowReceiverStatus?
  moonflow_receipt_reply : MoonFlowReviewReceiptReply?
  moonflow_receiver_error : String?
  series_catalog : Array[SeriesUseCaseProjection]
  selected_series_id : String
  selected_series_phase_id : String
  inspected_series : SeriesUseCaseProjection?
  series_action_loading : Bool
  series_action_status : String?
  series_error : String?
  notice : String?
  error : String?
}

///|
enum Msg {
  OfflineChoices(OfflineChoiceMsg)
  ReviewDraftAction(String, String, String)
  BriefAction(BriefMsg)
  EditChoices(ChoiceMsg)
  RefreshDelivery
  PrepareDelivery
  SelectDelivery(String)
  DeliveryLoaded(DeliveryRequest, Result[DeliveryStatus, String])
  WorkspaceLoaded(Int, Result[WorkspaceSnapshot, String])
  NativeRouteLoaded(Int, Result[NativeModelRoute, String])
  RefreshModelRoutes
  SelectCatalogModel(Int, String)
  UseConfiguredDefault(Int)
  SavedSelectionRestored(String, String, Result[CoworkSessionDetail, String])
  SetJobObjective(String)
  SetJobAudience(String)
  SetJobSources(String)
  SetJobOutputs(String)
  SetJobCriteria(String)
  SetJobSourceName(String)
  SetJobSourceContent(String)
  AddJobTextSource
  SetJobArxivQuery(String)
  AddJobArxivSource
  SetJobSourceUrl(String)
  AddJobUrlSource
  JobSourceAdded(Result[ResearchJobView, String])
  SetJobRevisionInstruction(String)
  SelectJobRevisionFile(String)
  CreateJobRevision
  JobRevisionCreated(Result[ResearchJobView, String])
  PreviewJobFile(String)
  JobPreviewLoaded(Result[ResearchJobPreview, String])
  RefreshJobs
  JobsLoaded(Result[Array[ResearchJobView], String])
  CreateJob
  JobCreated(Result[ResearchJobView, String])
  SelectJob(String)
  StartJob
  JobStarted(Result[ResearchJobView, String])
  SetJobResumeContent(String)
  ResumeJob
  JobResumed(Result[ResearchJobView, String])
  JobRefreshed(Result[ResearchJobView, String])
  VerifyJobDelivery
  JobDeliveryVerified(Result[ResearchJobView, String])
  RefreshSeriesCatalog
  SeriesCatalogLoaded(Result[Array[SeriesUseCaseProjection], String])
  SelectSeries(String)
  SelectSeriesPhase(String)
  ValidateSeriesTemplate
  SeriesTemplateLoaded(Result[SeriesUseCaseProjection, String])
  RefreshMoonTownStatus
  SetBookDir(String)
  SetModelName(String)
  SetReviewerName(String)
  SetReviewOutcome(String)
  SetReviewScope(String)
  ToggleResultIdea(String, String)
  SetResultPage(Int)
  SetReviewMessage(String)
  SetInformationGapSeverity(String)
  SetInformationGapSummary(String)
  SetRecognitionGapSeverity(String)
  SetRecognitionGapSummary(String)
  SetDecisivenessGapSeverity(String)
  SetDecisivenessGapSummary(String)
  SetQaQuestion(String)
  StartResearch
  CapabilitySubmitted(
    ResearchExecutionProjection,
    Result[CapabilityOperationReply, String]
  )
  ResearchSessionCreated(ModelSubmission, Result[CoworkSessionDetail, String])
  ResearchConfigured(ModelSubmission, Result[CoworkSessionDetail, String])
  ResearchCommandSubmitted(ModelSubmission, Result[CoworkSessionDetail, String])
  ExecutionCheckpointed(
    ResearchExecutionProjection,
    Result[CapabilityOperationReply, String]
  )
  RefreshResearch
  ResearchRefreshed(String, Result[CoworkSessionDetail, String])
  PrepareReview
  ReviewPrepared(Int, String, Result[ReviewPrepareReply, String])
  RefreshMoonFlowReceiver
  MoonFlowIntakeLoaded(Result[MoonFlowReceiverHandoff, String])
  MoonFlowStatusLoaded(Result[MoonFlowReceiverStatus, String])
  SettleMoonFlowReceipt
  MoonFlowReceiptPrepared(Result[MoonFlowReviewReceiptReply, String])
  MoonFlowReceiptPosted(Result[MoonFlowReceiverStatus, String])
  PrepareQa
  FinishQaPreparation
  RefreshQa
  QaSessionCreated(ModelSubmission, Result[CoworkSessionDetail, String])
  QaConfigured(ModelSubmission, Result[CoworkSessionDetail, String])
  QaBootstrapped(ModelSubmission, Result[CoworkSessionDetail, String])
  QaReconnected(QaRestoreRequest, Result[CoworkSessionDetail, String])
  AskQa
  QaAnswered(QaQuestionRequest, Result[CoworkSessionDetail, String])
}

///|
#cfg(target="js")
extern "js" fn browser_gateway_base() -> String =
  #| () => {
  #|   const runtime =
  #|     globalThis.__MOONFIND_RUNTIME_CONFIG__ ??
  #|     globalThis.__MOONCLAW_RUNTIME_CONFIG__ ??
  #|     {};
  #|   const meta =
  #|     typeof document === "undefined"
  #|       ? null
  #|       : document.querySelector('meta[name="moonclaw-gateway-base"]');
  #|   const explicit =
  #|     typeof globalThis.location?.search === "string"
  #|       ? new URLSearchParams(globalThis.location.search).get("gateway_base")
  #|       : null;
  #|   const supplied = [
  #|     globalThis.__MOONFIND_GATEWAY_BASE__,
  #|     globalThis.__MOONCLAW_GATEWAY_BASE__,
  #|     runtime.gatewayBase,
  #|     runtime.gateway_base,
  #|     meta?.content,
  #|     explicit,
  #|   ].find((value) => typeof value === "string" && value.trim() !== "");
  #|   const origin = globalThis.location?.origin ?? "";
  #|   if (!supplied) return origin;
  #|   try {
  #|     const candidate = new URL(supplied, origin || undefined);
  #|     const current = origin ? new URL(origin) : null;
  #|     const loopback = (host) =>
  #|       host === "127.0.0.1" ||
  #|       host === "localhost" ||
  #|       host === "[::1]" ||
  #|       host === "::1";
  #|     const hostAllowed =
  #|       !current ||
  #|       candidate.hostname === current.hostname ||
  #|       (loopback(candidate.hostname) && loopback(current.hostname));
  #|     const protocolAllowed =
  #|       candidate.protocol === "https:" ||
  #|       (candidate.protocol === "http:" && current?.protocol !== "https:");
  #|     return hostAllowed && protocolAllowed
  #|       ? candidate.origin
  #|       : origin;
  #|   } catch (_) {
  #|     return origin;
  #|   }
  #| }

///|
extern "js" fn browser_query_value(name : String) -> String =
  #| name => {
  #|   try {
  #|     return new URL(
  #|       globalThis.location?.href || "http://local/"
  #|     ).searchParams.get(name) || "";
  #|   } catch (_) {
  #|     return "";
  #|   }
  #| }

///|
extern "js" fn browser_series_selection(name : String) -> String =
  #| name => {
  #|   const key = `moonfind.${name}`;
  #|   const params = new URL(globalThis.location?.href || "http://local/")
  #|     .searchParams;
  #|   const query = params.get(name);
  #|   if (query) return query;
  #|   try { return globalThis.localStorage?.getItem(key) || ""; }
  #|   catch (_) { return ""; }
  #| }

///|
fn moonfind_template_launch_valid(
  template_id : String,
  template_version : String,
  catalog_id : String,
  catalog_version : String,
  catalog_digest : String,
  source_digest : String,
) -> Bool {
  template_id == "lunar-habitat-decision-series" &&
  template_version == "1.0.0" &&
  catalog_id == "moonfind.series-templates" &&
  catalog_version == "1.0.0" &&
  catalog_digest ==
  "sha256:0efa52d842fb6edaeda28994c15312e461d7c8487803b5340fd0a750c874f853" &&
  source_digest ==
  "sha256:3c95e516d9d47301a7312cccd69d2fa257a45d7a58fc949c41474508b1b2fab5"
}

///|
fn initial_series_selection() -> (String, String?) {
  let template_id = browser_query_value("template")
  if template_id == "" {
    return (browser_series_selection("series"), None)
  }
  if moonfind_template_launch_valid(
      template_id,
      browser_query_value("template_version"),
      browser_query_value("template_catalog"),
      browser_query_value("template_catalog_version"),
      browser_query_value("template_catalog_digest"),
      browser_query_value("template_source_digest"),
    ) {
    (template_id, None)
  } else {
    (
      "",
      Some(
        "Template preview rejected because its version or digest does not match MoonFind's installed catalog. Return to MoonDesk and refresh templates.",
      ),
    )
  }
}

///|
extern "js" fn persist_series_selection(
  series_id : String,
  phase_id : String,
) -> Unit =
  #| (seriesId, phaseId) => {
  #|   try {
  #|     globalThis.localStorage?.setItem("moonfind.series", seriesId);
  #|     globalThis.localStorage?.setItem("moonfind.phase", phaseId);
  #|     const url = new URL(globalThis.location.href);
  #|     url.searchParams.set("series", seriesId);
  #|     if (phaseId) url.searchParams.set("phase", phaseId);
  #|     globalThis.history?.replaceState(null, "", url);
  #|   } catch (_) {}
  #| }

///|
extern "js" fn moondesk_series_url(
  series_id : String,
  phase_id : String,
) -> String =
  #| (seriesId, phaseId) => {
  #|   const explicit = new URL(globalThis.location?.href || "http://local/")
  #|     .searchParams.get("moondesk_base");
  #|   let base = "http://127.0.0.1:4302/editor";
  #|   if (explicit) {
  #|     try {
  #|       const candidate = new URL(explicit);
  #|       if (["127.0.0.1", "localhost", "::1", "[::1]"].includes(candidate.hostname)) {
  #|         base = candidate.href;
  #|       }
  #|     } catch (_) {}
  #|   }
  #|   const url = new URL(base);
  #|   url.searchParams.set("series", seriesId);
  #|   if (phaseId) url.searchParams.set("phase", phaseId);
  #|   url.searchParams.set("source", "moonfind-series-catalog");
  #|   return url.href;
  #| }

///|
fn initial_model() -> Model {
  let book_dir = ""
  let (selected_series_id, template_error) = initial_series_selection()
  {
    brief: initial_brief_view(),
    choices: empty_choices(),
    choice_sessions: {},
    gateway_base: browser_gateway_base(),
    gateway_published: false,
    book_dir,
    trusted_book_dir: "",
    model_name: "",
    model_source: "automatic",
    saved_selection_key: None,
    saved_selection_error: None,
    native_route: None,
    route_generation: 0,
    route_loading: false,
    route_error: None,
    workspace_generation: 1,
    submission_generation: 0,
    pending_research: None,
    research_message_sent: false,
    pending_qa: None,
    qa_canonical_key: None,
    qa_agent_status: "not-created",
    pending_qa_restore: None,
    qa_readback_loading: false,
    question_generation: 0,
    pending_question: None,
    qa_error: None,
    qa_response_context: None,
    qa_answered_question: None,
    qa_answer_text: None,
    job_objective: "",
    job_audience: "Research team",
    job_sources: "Open, permitted sources; supplied workspace files",
    job_outputs: "report.md, evidence.csv",
    job_criteria: "Answers the research objective; Includes evidence or method; States limitations",
    job_source_name: "notes.md",
    job_source_content: "",
    job_arxiv_query: "",
    job_source_url: "",
    job_revision_instruction: "",
    job_revision_file: "",
    job_preview: None,
    job_resume_content: "",
    jobs: [],
    selected_job_id: "",
    job_status: "",
    job_error: None,
    phase: Ready,
    research_session: None,
    qa_session: None,
    review_phase: ReviewIdle,
    review_prepare_reply: None,
    review_pending_context: None,
    review_request_generation: 0,
    review_drafts: Map([]),
    review_storage: empty_review_storage(),
    offline_choices: empty_offline_choices(),
    offline_generation: 0,
    offline_choice_sessions: Map([]),
    review_context_notice: None,
    delivery: empty_delivery(0),
    result_page: 0,
    qa_ready: false,
    reviewer_name: "",
    review_outcome: "",
    review_scope: "",
    review_message: "",
    information_gap_severity: 1,
    information_gap_summary: "Record what evidence was missing before the synthesis decision.",
    recognition_gap_severity: 0,
    recognition_gap_summary: "The named reviewer recognized the material evidence boundary.",
    decisiveness_gap_severity: 1,
    decisiveness_gap_summary: "Record what reviewed rule or experiment is still required before action.",
    qa_question: "",
    workspace: None,
    research_execution: None,
    capability_submit_url: None,
    capability_reconcile_url: None,
    capability_checkpoint_url: None,
    host_status: "loading",
    host_blockers: [],
    moontown_handoff: None,
    moontown_result: None,
    review_workflow: None,
    moonflow_run_id: browser_query_value("moonflow_run"),
    moonflow_handoff_token: browser_query_value("moonflow_handoff"),
    moonflow_intake: None,
    moonflow_receiver_status: None,
    moonflow_receipt_reply: None,
    moonflow_receiver_error: None,
    series_catalog: [],
    selected_series_id,
    selected_series_phase_id: browser_series_selection("phase"),
    inspected_series: None,
    series_action_loading: false,
    series_action_status: None,
    series_error: template_error,
    notice: Some("Waiting for the trusted MoonFind host workspace…"),
    error: None,
  }
}

///|
fn valid_workspace_snapshot(snapshot : WorkspaceSnapshot) -> Bool {
  snapshot.contract_id == "moonfind.ui-workspace.v1" &&
  snapshot.product_id == "moonfind" &&
  snapshot.workspace.product_id == "moonfind" &&
  !snapshot.workspace.run_id.is_blank() &&
  snapshot.moontown_handoff.contract_id == "moonfind.moontown-handoff-status.v1" &&
  snapshot.moontown_handoff.run_id == snapshot.workspace.run_id &&
  snapshot.review_workflow.contract_id == "moonfind.review-workflow-status.v1" &&
  snapshot.review_workflow.run_id == snapshot.workspace.run_id
}

///|
fn series_template_issues(series : SeriesUseCaseProjection) -> Array[String] {
  let issues : Array[String] = []
  if series.contract_id != "moonsuite.series-use-case.v1" {
    issues.push("unsupported series contract")
  }
  if series.use_case_id.is_blank() || series.graph.graph_id.is_blank() {
    issues.push("series and graph identities are required")
  }
  if series.phases.is_empty() || series.graph.stages.is_empty() {
    issues.push("series phases and desired stages are required")
  }
  let stage_ids : Map[String, Unit] = Map([])
  for stage in series.graph.stages {
    if stage_ids.contains(stage.stage_id) {
      issues.push("duplicate desired stage: " + stage.stage_id)
    } else {
      stage_ids[stage.stage_id] = ()
    }
    if !stage.desired_operation_ref
      .map(value => value.contains("/") && value.contains("@"))
      .unwrap_or(false) {
      issues.push("unversioned desired operation: " + stage.stage_id)
    }
  }
  let covered : Map[String, Unit] = Map([])
  for phase in series.phases {
    if phase.stage_ids.is_empty() {
      issues.push("phase has no desired stages: " + phase.phase_id)
    }
    for stage_id in phase.stage_ids {
      if !stage_ids.contains(stage_id) {
        issues.push("phase references an unknown desired stage: " + stage_id)
      } else if covered.contains(stage_id) {
        issues.push("desired stage appears in multiple phases: " + stage_id)
      } else {
        covered[stage_id] = ()
      }
    }
  }
  if covered.length() != stage_ids.length() {
    issues.push("every desired stage must belong to exactly one phase")
  }
  if series.use_case_id == "lunar-habitat-decision-series" {
    let exclusions = series.graph.intentional_exclusions.unwrap_or([])
    let labels = exclusions.map(item => {
      match item.product_id {
        Some(value) => value.to_lower()
        None => item.capability.unwrap_or("").to_lower()
      }
    })
    for
      required in [
        "moonfish", "physical robot command", "publication", "commercial master",
      ] {
      if !labels.any(label => label.contains(required)) {
        issues.push("missing explicit exclusion: " + required)
      }
    }
  }
  issues
}

///|
fn review_gap_severity(value : String, fallback : Int) -> Int {
  let parsed = @string.parse_int(value) catch { _ => fallback }
  parsed.clamp(min=0, max=5)
}

///|
fn review_scope_ids(value : String) -> Array[String] {
  let ids : Array[String] = []
  for raw in value.replace_all(old="\n", new=",").split(",") {
    let id = raw.trim().to_owned()
    if !id.is_blank() && !ids.contains(id) {
      ids.push(id)
    }
  }
  ids
}

///|
fn safe_review_scope_id(value : String) -> Bool {
  !value.is_blank() &&
  value != "." &&
  value != ".." &&
  value.all(ch => {
    (ch >= 'a' && ch <= 'z') ||
    (ch >= 'A' && ch <= 'Z') ||
    (ch >= '0' && ch <= '9') ||
    ch == '-' ||
    ch == '_' ||
    ch == '.'
  })
}

///|
fn review_gap_issues(model : Model) -> Array[String] {
  let issues : Array[String] = []
  let gaps = [
    (
      "Information",
      model.information_gap_severity,
      model.information_gap_summary,
    ),
    (
      "Recognition",
      model.recognition_gap_severity,
      model.recognition_gap_summary,
    ),
    (
      "Decisiveness",
      model.decisiveness_gap_severity,
      model.decisiveness_gap_summary,
    ),
  ]
  for gap in gaps {
    let (name, severity, summary) = gap
    if severity < 0 || severity > 5 {
      issues.push("\{name} gap severity must be between 0 and 5.")
    }
    if severity > 0 && summary.trim().is_blank() {
      issues.push("\{name} gap needs a concrete summary when present.")
    }
  }
  for idea_id in review_scope_ids(model.review_scope) {
    if !safe_review_scope_id(idea_id) {
      issues.push("Review scope contains an unsafe idea ID: \{idea_id}.")
    }
  }
  issues
}

///|
fn review_phase_from_workflow(workflow : ReviewWorkflowStatus) -> ReviewPhase {
  match workflow.state {
    "awaiting-moonchat"
    | "ready-for-bookkeeper"
    | "review-rejected"
    | "review-deferred" => ReviewBundleReady
    "ready-for-human-review" | "not-ready" => ReviewIdle
    _ => ReviewFailed
  }
}

///|
fn safe_moonflow_run_id(value : String) -> Bool {
  !value.is_blank() &&
  value.length() <= 160 &&
  value.all(ch => {
    (ch >= 'a' && ch <= 'z') ||
    (ch >= 'A' && ch <= 'Z') ||
    (ch >= '0' && ch <= '9') ||
    ch == '-' ||
    ch == '_' ||
    ch == '.' ||
    ch == ':'
  })
}

///|
fn safe_moonflow_token(value : String) -> Bool {
  value.length() == 64 &&
  value.all(ch => (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f'))
}

///|
fn moonflow_launch_present(run_id : String, token : String) -> Bool {
  !run_id.is_blank() || !token.is_blank()
}

///|
fn valid_moonflow_launch(run_id : String, token : String) -> Bool {
  safe_moonflow_run_id(run_id) && safe_moonflow_token(token)
}

///|
fn moonflow_receiver_base(run_id : String, token : String) -> String {
  "/api/moonflow/runs/\{run_id}/handoffs/\{token}"
}

///|
fn valid_moonflow_intake(
  handoff : MoonFlowReceiverHandoff,
  run_id : String,
  token : String,
) -> Bool {
  let endpoint = moonflow_receiver_base(run_id, token)
  handoff.contract_id == "moonflow.operator-handoff.v2" &&
  handoff.contract_version == "2.0.0" &&
  handoff.binding.handoff_token == token &&
  handoff.binding.handoff_digest == "sha256:" + token &&
  handoff.binding.intake_path == endpoint &&
  handoff.binding.status_path == endpoint + "/status" &&
  handoff.binding.receipt_path == endpoint + "/receipt" &&
  handoff.payload.action_kind == "open-product" &&
  handoff.payload.run.run_id == run_id &&
  handoff.payload.run.product_id == "moonfind" &&
  handoff.payload.app_entrypoint.kind == "pack-manifest" &&
  handoff.payload.app_entrypoint.pack_id == "moonfind"
}

///|
fn valid_moonflow_status(
  status : MoonFlowReceiverStatus,
  run_id : String,
  token : String,
) -> Bool {
  let endpoint = moonflow_receiver_base(run_id, token)
  status.contract_id == "moonflow.receiver-status.v1" &&
  status.contract_version == "1.0.0" &&
  status.run_id == run_id &&
  status.handoff_token == token &&
  status.handoff_digest == "sha256:" + token &&
  status.intake_path == endpoint &&
  status.status_path == endpoint + "/status" &&
  status.receipt_path == endpoint + "/receipt" &&
  status.status is ("pending" | "accepted" | "denied")
}

///|
fn valid_moonflow_receipt_reply(
  reply : MoonFlowReviewReceiptReply,
  run_id : String,
  token : String,
) -> Bool {
  reply.contract_id == "moonfind.moonflow-review-receipt-reply.v1" &&
  reply.run_id == run_id &&
  reply.handoff_token == token &&
  reply.receipt_path == moonflow_receiver_base(run_id, token) + "/receipt"
}

///|
fn moonflow_review_binding_issue(model : Model) -> String? {
  if !moonflow_launch_present(
      model.moonflow_run_id,
      model.moonflow_handoff_token,
    ) {
    return None
  }
  if !valid_moonflow_launch(model.moonflow_run_id, model.moonflow_handoff_token) {
    return Some("The MoonFlow launch identity is malformed.")
  }
  guard model.moonflow_intake is Some(handoff) else {
    return Some("The MoonFlow handoff has not been verified yet.")
  }
  if handoff.payload.run.operation != "moonfind/research.review@0.1.0" {
    return Some(
      "This MoonFlow handoff does not declare MoonFind's portable review operation.",
    )
  }
  if handoff.payload.authority.requested_authority != "workspace-mutation" ||
    !handoff.payload.review.required ||
    !handoff.payload.contracts.output_contracts.contains(
      "moonchat/conversation-review-bundle@1.0.0",
    ) {
    return Some(
      "The MoonFlow handoff does not bind the required workspace authority, human review, and MoonChat bundle output contract.",
    )
  }
  match model.workspace {
    Some(workspace) if workspace.run_id != handoff.payload.run.run_id =>
      Some("The MoonFlow handoff is bound to a different MoonFind run.")
    _ =>
      match model.moonflow_receiver_status {
        Some(status) if status.status != "pending" =>
          Some("This MoonFlow receiver handoff is already \{status.status}.")
        Some(_) => None
        None => Some("The MoonFlow receiver status has not been verified yet.")
      }
  }
}

///|
fn execution_needs_session_refresh(
  execution : ResearchExecutionProjection?,
) -> Bool {
  execution
  .map(record => {
    record.state
    is ("command-ready"
    | "runtime-submitting"
    | "runtime-pending"
    | "runtime-unknown")
  })
  .unwrap_or(false)
}

///|
fn phase_from_durable_execution(
  execution : ResearchExecutionProjection?,
) -> ResearchPhase {
  match execution {
    Some(record) =>
      match record.state {
        "needs-review" => Completed
        "failed" | "runtime-failed" => Failed
        "submitting"
        | "pending"
        | "unknown"
        | "runtime-submitting"
        | "runtime-pending"
        | "runtime-unknown" => Running
        "command-ready" => Ready
        _ => Ready
      }
    None => Ready
  }
}

///|
fn has_published_gateway(snapshot : WorkspaceSnapshot) -> Bool {
  snapshot.moonclaw_gateway_base
  .map(value => !value.trim().is_blank())
  .unwrap_or(false)
}

///|
fn gateway_base_from_snapshot(
  snapshot : WorkspaceSnapshot,
  fallback : String,
) -> String {
  let base = snapshot.moonclaw_gateway_base.unwrap_or(fallback)
  if base.has_prefix("/") {
    product_api_url(base)
  } else {
    base
  }
}

///|
fn valid_review_outcome(outcome : String) -> Bool {
  outcome is ("approve_subset" | "request_changes" | "reject")
}

///|
fn review_request_issues(
  reviewer_name : String,
  outcome : String,
  scope : String,
  instruction : String,
) -> Array[String] {
  let issues : Array[String] = []
  if reviewer_name.trim().is_blank() {
    issues.push("Enter the named human reviewer.")
  }
  if !valid_review_outcome(outcome) {
    issues.push("Choose approve_subset, request_changes, or reject.")
  }
  if outcome == "approve_subset" && scope.trim().is_blank() {
    issues.push("List the exact synthesis idea IDs approved.")
  }
  if instruction.trim().is_blank() {
    issues.push("Record the reviewer rationale or requested change.")
  }
  issues
}

///|
fn normalized_run_status(status : String) -> String {
  status.trim(chars=['"', ' ', '\n', '\r', '\t']).to_owned()
}

///|
fn phase_from_run_status(status : String) -> ResearchPhase {
  match normalized_run_status(status).to_lower() {
    "succeeded" | "completed" => Completed
    "failed" | "cancelled" | "canceled" => Failed
    "paused" | "waitingforinput" | "needsinput" | "blocked" => NeedsReview
    _ => Running
  }
}

///|
fn phase_from_session(session : CoworkSessionDetail) -> ResearchPhase {
  match session.linked_run {
    Some(run) => phase_from_run_status(run.status)
    None => Ready
  }
}
