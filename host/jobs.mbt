///|
pub(all) struct CreateResearchJobRequestV1 {
  objective : String
  audience : String
  source_scope : Array[String]
  requested_outputs : Array[@research.RequestedOutput]
} derive(Debug, FromJson)

///|
pub(all) struct JobSessionRequestV1 {
  session_key : String
} derive(Debug, FromJson)

///|
pub(all) struct StartResearchJobRequestV1 {
  model_name : String
} derive(Debug, FromJson)

///|
pub(all) struct ResumeResearchJobRequestV1 {
  content : String
} derive(Debug, FromJson)

///|
pub(all) struct AddJobTextSourceRequestV1 {
  name : String
  content : String
} derive(Debug, FromJson)

///|
pub(all) struct AddJobArxivSourceRequestV1 {
  query : String
  max_results : Int
} derive(Debug, FromJson)

///|
pub(all) struct AddJobUrlSourceRequestV1 {
  url : String
} derive(Debug, FromJson)

///|
pub(all) struct ReviseResearchJobRequestV1 {
  file_name : String
  instruction : String
} derive(Debug, FromJson)

///|
pub(all) struct JobPreviewV1 {
  contract_id : String
  name : String
  media_type : String
  text : String?
  truncated : Bool
  byte_length : Int64
} derive(Debug, ToJson, FromJson)

///|
pub(all) struct JobFileV1 {
  name : String
  media_type : String
  byte_length : Int64
  digest : String
  open_url : String
} derive(Debug, ToJson, FromJson)

///|
pub(all) struct ResearchJobViewV1 {
  contract_id : String
  job : @research.ResearchJob
  job_root : String
  files : Array[JobFileV1]
  sources : Array[JobFileV1]
  revision_of : String?
  missing_outputs : Array[String]
  session_key : String?
  run_id : String?
  session_state : String?
  session_preview : String?
  run_summary : String?
  moonclaw_gateway_base : String?
  agent_prompt : String
  delivery_manifest : @research.DeliveryManifest?
  delivery_ready : Bool
  delivery_issues : Array[String]
} derive(Debug, ToJson, FromJson)

///|
fn jobs_root(config : Config) -> String {
  config.workspace + "/.moonsuite/products/moonfind/jobs"
}

///|
fn safe_job_id(job_id : String) -> Bool {
  job_id.has_prefix("job-") &&
  !job_id.contains("/") &&
  !job_id.contains("\\") &&
  !job_id.contains("..")
}

///|
fn safe_output_name(name : String) -> Bool {
  if name.is_blank() || name == "." || name == ".." {
    return false
  }
  for byte in @utf8.encode(name) {
    if !((byte >= b'A' && byte <= b'Z') ||
      (byte >= b'a' && byte <= b'z') ||
      (byte >= b'0' && byte <= b'9') ||
      byte is (b'-' | b'_' | b'.')) {
      return false
    }
  }
  true
}

///|
fn job_root(config : Config, job_id : String) -> String raise {
  guard safe_job_id(job_id) else { fail("invalid research job ID") }
  jobs_root(config) + "/" + job_id
}

///|
fn job_file_media_type(name : String) -> String {
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
  } else if name.has_suffix(".html") {
    "text/html"
  } else if name.has_suffix(".xml") {
    "application/xml"
  } else if name.has_suffix(".png") {
    "image/png"
  } else if name.has_suffix(".jpg") || name.has_suffix(".jpeg") {
    "image/jpeg"
  } else if name.has_suffix(".svg") {
    "image/svg+xml"
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
fn job_prompt(
  job : @research.ResearchJob,
  sources : Array[JobFileV1],
) -> String {
  let evidence_example : @research.DeliveryEvidence = {
    contract_id: "moonfind.delivery-evidence.v1",
    job_id: job.job_id,
    outputs: job.requested_outputs.map(fn(output) {
      @research.DeliveryEvidenceOutput::{
        output_id: output.output_id,
        evidence_refs: ["outputs/" + output.output_id],
        checks: output.acceptance_criteria.map(fn(criterion) {
          @research.DeliveryCheck::{
            criterion,
            status: "passed",
            evidence_ref: "outputs/" + output.output_id,
          }
        }),
      }
    }),
  }
  (
    $|You are working on a Moonfind research job. Work in the current job directory. The job brief is in job.json; the exact requested outputs are below.
    $|
    $|\{job.to_json().stringify(indent=2)}
    $|
    $|Available source files: \{sources.map(source => "input/" + source.name).join(", ")}. Read the relevant files before drawing conclusions, cite only sources actually used by exact path or URL in the deliverable, and state when a source only provides metadata or an abstract. If revision.json exists, use its parent record and input/previous-* file to address the requested change.
    $|
    $|Research flexibly. You may explore new hypotheses, create intermediate files, run analyses, and revise your approach. Put user-facing final files directly in outputs/ using the requested output IDs as filenames. You may add useful extra files there. Keep scratch work outside outputs/. For each final file, make its evidence, limitations, and methods clear in the file or a companion file. Do not invent sources or claim unperformed experiments.
    $|
    $|To request delivery verification, write delivery-evidence.json at the run workspace root. Its exact JSON shape is shown below. Do not substitute a verification object, delivered_outputs list, workflow IDs, or another schema. Every check repeats one exact acceptance criterion from job.json. Evidence refs are relative paths to real files here, such as input/notes.md, evidence/sources.md, or outputs/report.md. Add source refs when sources were used. Mark a criterion passed only if you actually checked it; if you cannot, explain the gap in your final response rather than invent evidence. MoonFind verifies paths and output bytes, while a researcher still reviews scientific claims.
    $|
    $|\{evidence_example.to_json().stringify(indent=2)}
    $|
    $|When finished, summarize which files are ready, which requests are still missing, and how to check the result.
  )
}

///|
fn safe_job_relative_ref(value : String) -> Bool {
  !value.is_blank() &&
  !value.has_prefix("/") &&
  !value.contains("\\") &&
  !value.split("/").contains("..")
}

///|
fn gateway_headers(config : Config) -> Map[String, String] {
  let headers : Map[String, String] = {
    "Content-Type": "application/json; charset=utf-8",
  }
  match config.moonclaw_gateway_token {
    Some(token) if !token.is_blank() =>
      headers["Authorization"] = "Bearer " + token
    _ => ()
  }
  headers
}

///|
async fn gateway_job_post(config : Config, url : String, value : Json) -> Json {
  let (response, body) = @http.post(url, value, headers=gateway_headers(config))
  guard response.code >= 200 && response.code < 300 else {
    fail("MoonClaw Cowork returned HTTP \{response.code}: " + body.text())
  }
  @json.parse(body.text())
}

///|
async fn gateway_job_session(
  config : Config,
  gateway : String,
  session_key : String,
) -> Json {
  let (response, body) = @http.get(
    gateway + "/v1/cowork/sessions/" + session_key,
    headers=gateway_headers(config),
  )
  guard response.code >= 200 && response.code < 300 else {
    fail("saved MoonClaw session is unavailable")
  }
  @json.parse(body.text())
}

///|
fn gateway_linked_proposal(value : Json) -> String? {
  match value {
    { "session": { "linked_proposal": { "id": String(id), .. }, .. }, .. } =>
      Some(id)
    _ => None
  }
}

///|
fn gateway_linked_run(value : Json) -> String? {
  match value {
    { "session": { "linked_run": { "id": String(id), .. }, .. }, .. } =>
      Some(id)
    _ => None
  }
}

///|
fn gateway_has_plan(value : Json) -> Bool {
  match value {
    { "session": { "plan_preview": String(preview), .. }, .. } =>
      !preview.is_blank()
    _ => false
  }
}

///|
fn clean_gateway_status(status : String) -> String {
  if status.has_prefix("\"") && status.has_suffix("\"") && status.length() > 1 {
    status[1:status.length() - 1].to_owned()
  } else {
    status
  }
}

///|
fn gateway_session_key(value : Json) -> String raise {
  match value {
    { "session": { "session": { "session_key": String(key), .. }, .. }, .. } =>
      key
    _ => fail("MoonClaw Cowork did not return a session key")
  }
}

///|
async fn gateway_session_observation(
  config : Config,
  gateway : String,
  session_key : String,
) -> (String?, String?, String?, String?) {
  let (response, body) = @http.get(
    gateway + "/v1/cowork/sessions/" + session_key,
    headers=gateway_headers(config),
  ) catch {
    _ => return (None, None, None, None)
  }
  if response.code < 200 || response.code >= 300 {
    return (None, None, None, None)
  }
  match @json.parse(body.text()) {
    {
      "session": {
        "session": { "state": String(state), .. },
        "linked_run": {
          "status": String(status),
          "workspace_dir": String(workspace),
          "summary": String(summary),
          ..
        },
        ..
      },
      ..
    } =>
      (
        Some(state + " · " + clean_gateway_status(status)),
        None,
        Some(workspace),
        Some(summary),
      )
    {
      "session": {
        "session": { "state": String(state), .. },
        "linked_run": {
          "status": String(status),
          "workspace_dir": String(workspace),
          ..
        },
        ..
      },
      ..
    } =>
      (
        Some(state + " · " + clean_gateway_status(status)),
        None,
        Some(workspace),
        None,
      )
    {
      "session": {
        "session": { "state": String(state), .. },
        "linked_run": { "status": String(status), .. },
        ..
      },
      ..
    } => (Some(state + " · " + clean_gateway_status(status)), None, None, None)
    {
      "session": {
        "session": {
          "state": String(state),
          "last_message_preview": String(preview),
          ..
        },
        ..
      },
      ..
    } => (Some(state), Some(preview), None, None)
    { "session": { "session": { "state": String(state), .. }, .. }, .. } =>
      (Some(state), None, None, None)
    _ => (None, None, None, None)
  }
}

///|
async fn import_run_evidence(
  source : String,
  destination : String,
  depth : Int,
) -> Unit {
  if depth > 5 {
    return
  }
  let directory = @fs.opendir(source) catch { _ => return }
  defer directory.close()
  let names = directory.read_all() catch { _ => return }
  for name in names {
    if !safe_output_name(name) {
      continue
    }
    let source_path = source + "/" + name
    let destination_path = destination + "/" + name
    let child = @fs.opendir(source_path) catch {
      _ => {
        if !@fs.exists(destination_path) {
          let data = @fs.read_file(source_path).binary() catch { _ => continue }
          @fs.write_file(destination_path, data, create=0o644, truncate=true)
        }
        continue
      }
    }
    child.close()
    @fs.mkdir(destination_path, permission=0o755, recursive=true)
    import_run_evidence(source_path, destination_path, depth + 1)
  }
}

///|
async fn import_finished_run(
  root : String,
  status : String?,
  workspace : String?,
  requested : Array[String],
) -> Unit {
  guard status is Some(state) && state.contains("Succeeded") else { return }
  guard workspace is Some(run_workspace) &&
    run_workspace.has_prefix(root + "/.moonsuite/products/moonclaw/jobs/") else {
    return
  }
  for name in job_file_names(run_workspace) {
    if (name.has_prefix("step-") && !requested.contains(name)) ||
      name == "delivery-evidence.json" ||
      @fs.exists(root + "/outputs/" + name) {
      continue
    }
    let data = @fs.read_file(run_workspace + "/outputs/" + name).binary() catch {
      _ => continue
    }
    @fs.write_file(root + "/outputs/" + name, data, create=0o644, truncate=true)
  }
  if @fs.exists(run_workspace + "/delivery-evidence.json") &&
    !@fs.exists(root + "/delivery-evidence.json") {
    let data = @fs.read_file(run_workspace + "/delivery-evidence.json").binary()
    @fs.write_file(
      root + "/delivery-evidence.json",
      data,
      create=0o644,
      truncate=true,
    )
  }
  if @fs.exists(run_workspace + "/evidence") {
    @fs.mkdir(root + "/evidence", permission=0o755, recursive=true)
    import_run_evidence(run_workspace + "/evidence", root + "/evidence", 0)
  }
}

///|
fn delivery_file_issues(
  files : Array[JobFileV1],
  manifest : @research.DeliveryManifest,
) -> Array[String] {
  let issues : Array[String] = []
  for output in manifest.outputs {
    let expected_ref = "outputs/" + output.output_id
    if output.artifact_ref != expected_ref ||
      !files.any(file => {
        file.name == output.output_id &&
        file.digest == output.artifact_digest &&
        file.byte_length == output.byte_length &&
        file.media_type == output.media_type
      }) {
      issues.push("Output changed or disappeared: " + output.output_id)
    }
  }
  issues
}

///|
async fn job_file_names(root : String) -> Array[String] {
  let directory = @fs.opendir(root + "/outputs") catch { _ => return [] }
  defer directory.close()
  let names = directory.read_all() catch { _ => return [] }
  names.sort()
  names.filter(name => safe_output_name(name))
}

///|
async fn input_file_names(root : String) -> Array[String] {
  let directory = @fs.opendir(root + "/input") catch { _ => return [] }
  defer directory.close()
  let names = directory.read_all() catch { _ => return [] }
  names.sort()
  names.filter(name => safe_output_name(name))
}

///|
pub async fn research_job_file(
  config : Config,
  job_id : String,
  name : String,
) -> (Bytes, String) {
  guard safe_output_name(name) else { fail("invalid output filename") }
  let root = job_root(config, job_id)
  guard @fs.exists(root + "/job.json") && job_file_names(root).contains(name) else {
    fail("research output does not exist")
  }
  let data = @fs.read_file(root + "/outputs/" + name).binary()
  (data, job_file_media_type(name))
}

///|
pub async fn research_job_source_file(
  config : Config,
  job_id : String,
  name : String,
) -> (Bytes, String) {
  guard safe_output_name(name) else { fail("invalid source filename") }
  let root = job_root(config, job_id)
  guard @fs.exists(root + "/job.json") && input_file_names(root).contains(name) else {
    fail("research source does not exist")
  }
  let data = @fs.read_file(root + "/input/" + name).binary()
  (data, job_file_media_type(name))
}

///|
pub async fn research_job_preview(
  config : Config,
  job_id : String,
  name : String,
) -> JobPreviewV1 {
  let (data, media_type) = research_job_file(config, job_id, name)
  let previewable = media_type.has_prefix("text/") ||
    media_type == "application/json" ||
    media_type == "application/x-ipynb+json"
  let truncated = data.length() > 128 * 1024
  let content : String? = if previewable && !truncated {
    Some(@fs.read_file(job_root(config, job_id) + "/outputs/" + name).text())
  } else {
    None
  }
  {
    contract_id: "moonfind.job-preview.v1",
    name,
    media_type,
    text: content,
    truncated,
    byte_length: data.length().to_int64(),
  }
}

///|
async fn append_archive_evidence(
  entries : Array[(String, FixedArray[Byte])],
  root : String,
  relative : String,
  depth : Int,
) -> Unit {
  if depth > 8 {
    return
  }
  let directory = @fs.opendir(root + "/" + relative) catch { _ => return }
  defer directory.close()
  let names = directory.read_all() catch { _ => return }
  names.sort()
  let evidence_root = @fs.realpath(root + "/evidence")
  for name in names {
    if !safe_output_name(name) {
      continue
    }
    let child = relative + "/" + name
    let resolved = @fs.realpath(root + "/" + child) catch { _ => continue }
    if !resolved.has_prefix(evidence_root + "/") {
      continue
    }
    let subdir = @fs.opendir(root + "/" + child) catch {
      _ => {
        let data = @fs.read_file(root + "/" + child).binary() catch {
          _ => continue
        }
        entries.push((child, data.to_fixedarray()))
        continue
      }
    }
    subdir.close()
    append_archive_evidence(entries, root, child, depth + 1)
  }
}

///|
pub async fn research_job_export(config : Config, job_id : String) -> Bytes {
  let root = job_root(config, job_id)
  guard @fs.exists(root + "/job.json") else {
    fail("research job does not exist")
  }
  let entries : Array[(String, FixedArray[Byte])] = []
  let records = [
    "job.json", "delivery-evidence.json", "delivery-manifest.json", "revision.json",
  ]
  for name in records {
    let path = root + "/" + name
    if @fs.exists(path) {
      entries.push((name, @fs.read_file(path).binary().to_fixedarray()))
    }
  }
  for name in input_file_names(root) {
    entries.push(
      (
        "input/" + name,
        @fs.read_file(root + "/input/" + name).binary().to_fixedarray(),
      ),
    )
  }
  for name in job_file_names(root) {
    entries.push(
      (
        "outputs/" + name,
        @fs.read_file(root + "/outputs/" + name).binary().to_fixedarray(),
      ),
    )
  }
  if @fs.exists(root + "/evidence") {
    append_archive_evidence(entries, root, "evidence", 0)
  }
  Bytes::from_fixedarray(@moonzip.zip_sync(entries))
}

///|
async fn job_files(config : Config, job_id : String) -> Array[JobFileV1] {
  let root = job_root(config, job_id)
  let files : Array[JobFileV1] = []
  for name in job_file_names(root) {
    let data = @fs.read_file(root + "/outputs/" + name).binary() catch {
      _ => continue
    }
    files.push({
      name,
      media_type: job_file_media_type(name),
      byte_length: data.length().to_int64(),
      digest: @store.digest_bytes(data),
      open_url: "/api/v1/jobs/" + job_id + "/files/" + name,
    })
  }
  files
}

///|
async fn job_sources(config : Config, job_id : String) -> Array[JobFileV1] {
  let root = job_root(config, job_id)
  let files : Array[JobFileV1] = []
  for name in input_file_names(root) {
    let data = @fs.read_file(root + "/input/" + name).binary() catch {
      _ => continue
    }
    files.push({
      name,
      media_type: job_file_media_type(name),
      byte_length: data.length().to_int64(),
      digest: @store.digest_bytes(data),
      open_url: "/api/v1/jobs/" + job_id + "/sources/" + name,
    })
  }
  files
}

///|
pub async fn research_job_view(
  config : Config,
  job_id : String,
) -> ResearchJobViewV1 {
  let root = job_root(config, job_id)
  guard @fs.exists(root + "/job.json") else {
    fail("research job does not exist")
  }
  let job : @research.ResearchJob = @json.from_json(
    @store.read_json(root + "/job.json"),
  )
  guard job.job_id == job_id && @research.validate_research_job(job).is_empty() else {
    fail("research job record is invalid")
  }
  let (session_key, run_id) : (String?, String?) = if @fs.exists(
      root + "/session.json",
    ) {
    let record = @store.read_json(root + "/session.json")
    match record {
      { "session_key": String(key), "run_id": String(run), .. } =>
        (Some(key), Some(run))
      { "session_key": String(key), .. } => (Some(key), None)
      _ => (None, None)
    }
  } else {
    (None, None)
  }
  let gateway = match config.moonclaw_gateway_base {
    Some(base) if !base.is_blank() && moonclaw_gateway_reachable(base) =>
      Some(trimmed_base(base))
    _ => None
  }
  let (session_state, session_preview, run_workspace, run_summary) = match
    (gateway, session_key) {
    (Some(base), Some(key)) => gateway_session_observation(config, base, key)
    _ => (None, None, None, None)
  }
  import_finished_run(
    root,
    session_state,
    run_workspace,
    job.requested_outputs.map(output => output.output_id),
  )
  let files = job_files(config, job_id)
  let sources = job_sources(config, job_id)
  let revision_of : String? = if @fs.exists(root + "/revision.json") {
    match @store.read_json(root + "/revision.json") {
      { "parent_job_id": String(parent), .. } => Some(parent)
      _ => None
    }
  } else {
    None
  }
  let manifest : @research.DeliveryManifest? = if @fs.exists(
      root + "/delivery-manifest.json",
    ) {
    Some(@json.from_json(@store.read_json(root + "/delivery-manifest.json")))
  } else {
    None
  }
  let delivery_issues = match manifest {
    Some(value) =>
      @research.delivery_manifest_issues(job, value) +
      delivery_file_issues(files, value)
    None => ["Delivery verification has not been requested"]
  }
  {
    contract_id: "moonfind.research-job-view.v1",
    job,
    job_root: root,
    files,
    sources,
    revision_of,
    missing_outputs: job.requested_outputs
    .filter(output => !files.any(file => file.name == output.output_id))
    .map(output => output.output_id),
    session_key,
    run_id,
    session_state,
    session_preview,
    run_summary,
    moonclaw_gateway_base: gateway,
    agent_prompt: job_prompt(job, sources),
    delivery_manifest: manifest,
    delivery_ready: delivery_issues.is_empty(),
    delivery_issues,
  }
}

///|
pub async fn start_research_job(
  config : Config,
  job_id : String,
  request : StartResearchJobRequestV1,
) -> ResearchJobViewV1 {
  guard !request.model_name.trim().is_blank() else {
    fail("a MoonClaw model is required")
  }
  let view = research_job_view(config, job_id)
  guard view.moonclaw_gateway_base is Some(gateway) else {
    fail("MoonClaw gateway is unavailable")
  }
  let root = job_root(config, job_id)
  let session_key = match view.session_key {
    Some(key) => key
    None => {
      let created = gateway_job_post(config, gateway + "/v1/cowork/sessions", {
        "cwd": view.job_root,
        "title": view.job.objective,
      })
      let key = gateway_session_key(created)
      @store.write_json(root + "/session.json", {
        "session_key": key,
        "model_name": request.model_name,
        "state": "created",
      })
      key
    }
  }
  ignore(
    gateway_job_post(
      config,
      gateway + "/v1/cowork/sessions/" + session_key + "/config",
      {
        "title": view.job.objective,
        "cwd": view.job_root,
        "model": request.model_name,
      },
    ),
  )
  let session_url = gateway + "/v1/cowork/sessions/" + session_key
  let mut detail = gateway_job_session(config, gateway, session_key)
  if gateway_linked_run(detail) is Some(existing_run) {
    if view.run_id is None {
      @store.write_json(root + "/session.json", {
        "session_key": session_key,
        "model_name": request.model_name,
        "run_id": existing_run,
        "state": "running",
      })
    }
    return research_job_view(config, job_id)
  }
  if gateway_linked_proposal(detail) is None {
    if !gateway_has_plan(detail) {
      @store.write_json(root + "/session.json", {
        "session_key": session_key,
        "model_name": request.model_name,
        "state": "planning",
      })
      detail = gateway_job_post(config, session_url + "/plan", {
        "request_text": view.agent_prompt,
        "cwd": view.job_root,
      })
    }
    if gateway_linked_proposal(detail) is None {
      @store.write_json(root + "/session.json", {
        "session_key": session_key,
        "model_name": request.model_name,
        "state": "promoting",
      })
      detail = gateway_job_post(config, session_url + "/promote", {})
    }
  }
  guard gateway_linked_proposal(detail) is Some(proposal_id) else {
    fail("MoonClaw did not create a research proposal")
  }
  @store.write_json(root + "/session.json", {
    "session_key": session_key,
    "model_name": request.model_name,
    "proposal_id": proposal_id,
    "state": "confirming",
  })
  detail = gateway_job_post(
    config,
    session_url + "/proposals/" + proposal_id + "/confirm",
    {},
  )
  guard gateway_linked_run(detail) is Some(run_id) else {
    fail("MoonClaw did not start the proposed research run")
  }
  @store.write_json(root + "/session.json", {
    "session_key": session_key,
    "model_name": request.model_name,
    "proposal_id": proposal_id,
    "run_id": run_id,
    "state": "running",
  })
  research_job_view(config, job_id)
}

///|
pub async fn resume_research_job(
  config : Config,
  job_id : String,
  request : ResumeResearchJobRequestV1,
) -> ResearchJobViewV1 {
  let view = research_job_view(config, job_id)
  guard view.session_state
    .map(state => state.contains("WaitingForInput"))
    .unwrap_or(false) &&
    !request.content.trim().is_blank() else {
    fail("a waiting MoonClaw run and response are required")
  }
  guard view.moonclaw_gateway_base is Some(gateway) &&
    view.session_key is Some(session_key) &&
    view.run_id is Some(run_id) else {
    fail("saved MoonClaw session and run are required to resume")
  }
  ignore(
    gateway_job_post(
      config,
      gateway +
      "/v1/cowork/sessions/" +
      session_key +
      "/runs/" +
      run_id +
      "/resume",
      { "content": request.content.trim() },
    ),
  )
  research_job_view(config, job_id)
}

///|
pub async fn verify_research_job_delivery(
  config : Config,
  job_id : String,
) -> ResearchJobViewV1 {
  let view = research_job_view(config, job_id)
  guard view.missing_outputs.is_empty() else {
    fail("requested output files are still missing")
  }
  let root = job_root(config, job_id)
  guard @fs.exists(root + "/delivery-evidence.json") else {
    fail("delivery-evidence.json is required before verification")
  }
  let evidence : @research.DeliveryEvidence = @json.from_json(
    @store.read_json(root + "/delivery-evidence.json"),
  )
  guard evidence.contract_id == "moonfind.delivery-evidence.v1" &&
    evidence.job_id == job_id &&
    evidence.outputs.length() == view.job.requested_outputs.length() else {
    fail("delivery evidence does not match this research job")
  }
  let outputs : Array[@research.DeliveredOutput] = []
  for spec in view.job.requested_outputs {
    let matches = evidence.outputs.filter(item => {
      item.output_id == spec.output_id
    })
    guard matches.length() == 1 else {
      fail("delivery evidence needs exactly one entry per requested output")
    }
    let item = matches[0]
    guard view.files.any(file => file.name == spec.output_id) else {
      fail("requested output file disappeared")
    }
    let file = view.files.filter(file => file.name == spec.output_id)[0]
    guard !item.evidence_refs.is_empty() else {
      fail("delivery evidence needs at least one file reference")
    }
    for reference in item.evidence_refs {
      guard safe_job_relative_ref(reference) &&
        @fs.exists(root + "/" + reference) else {
        fail("delivery evidence references a missing or unsafe file")
      }
    }
    for check in item.checks {
      guard safe_job_relative_ref(check.evidence_ref) &&
        @fs.exists(root + "/" + check.evidence_ref) else {
        fail("delivery check references a missing or unsafe file")
      }
    }
    outputs.push({
      output_id: spec.output_id,
      artifact_ref: "outputs/" + spec.output_id,
      media_type: file.media_type,
      artifact_digest: file.digest,
      byte_length: file.byte_length,
      evidence_refs: item.evidence_refs,
      checks: item.checks,
    })
  }
  let manifest : @research.DeliveryManifest = {
    contract_id: @research.delivery_manifest_contract_version(),
    job_id,
    outputs,
    open_gaps: [],
    review_status: "pending-review",
    delivered_at: @async.now(),
  }
  let issues = @research.delivery_manifest_issues(view.job, manifest)
  guard issues.is_empty() else {
    fail("delivery checks are incomplete: " + issues.join("; "))
  }
  @store.write_json(root + "/delivery-manifest.json", manifest.to_json())
  research_job_view(config, job_id)
}

///|
pub async fn list_research_jobs(config : Config) -> Array[ResearchJobViewV1] {
  let directory = @fs.opendir(jobs_root(config)) catch { _ => return [] }
  defer directory.close()
  let names = directory.read_all() catch { _ => return [] }
  names.sort()
  let jobs : Array[ResearchJobViewV1] = []
  for name in names {
    if safe_job_id(name) {
      let view = research_job_view(config, name) catch { _ => continue }
      jobs.push(view)
    }
  }
  jobs
}

///|
pub async fn create_research_job(
  config : Config,
  request : CreateResearchJobRequestV1,
) -> ResearchJobViewV1 {
  let now = @async.now()
  let mut job_id = "job-\{now}"
  let mut suffix = 1
  for ;; {
    if !@fs.exists(job_root(config, job_id)) {
      break
    }
    suffix += 1
    job_id = "job-\{now}-\{suffix}"
  }
  let job : @research.ResearchJob = {
    contract_id: @research.research_job_contract_version(),
    job_id,
    objective: request.objective.trim().to_owned(),
    audience: request.audience.trim().to_owned(),
    source_scope: request.source_scope,
    requested_outputs: request.requested_outputs,
    created_at: now,
  }
  let issues = @research.validate_research_job(job)
  guard issues.is_empty() &&
    job.requested_outputs.all(output => safe_output_name(output.output_id)) else {
    fail("invalid research job: " + issues.join("; "))
  }
  let root = job_root(config, job_id)
  @fs.mkdir(root + "/outputs", permission=0o755, recursive=true)
  @fs.mkdir(root + "/input", permission=0o755, recursive=true)
  @store.write_json(root + "/job.json", job.to_json())
  research_job_view(config, job_id)
}

///|
pub async fn add_research_job_text_source(
  config : Config,
  job_id : String,
  request : AddJobTextSourceRequestV1,
) -> ResearchJobViewV1 {
  let view = research_job_view(config, job_id)
  guard view.session_key is None else {
    fail(
      "sources are fixed after the MoonClaw run starts; create a revision to change them",
    )
  }
  let name = request.name.trim().to_owned()
  guard safe_output_name(name) &&
    (
      name.has_suffix(".md") ||
      name.has_suffix(".txt") ||
      name.has_suffix(".csv") ||
      name.has_suffix(".tsv") ||
      name.has_suffix(".json") ||
      name.has_suffix(".bib")
    ) &&
    !request.content.is_blank() else {
    fail(
      "source needs a safe text, Markdown, CSV, TSV, JSON, or BibTeX filename and content",
    )
  }
  let root = job_root(config, job_id)
  guard !@fs.exists(root + "/input/" + name) else {
    fail("source filename already exists")
  }
  @fs.write_file(
    root + "/input/" + name,
    @utf8.encode(request.content),
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  research_job_view(config, job_id)
}

///|
pub async fn add_research_job_arxiv_source(
  config : Config,
  job_id : String,
  request : AddJobArxivSourceRequestV1,
) -> ResearchJobViewV1 {
  let view = research_job_view(config, job_id)
  guard view.session_key is None else {
    fail(
      "sources are fixed after the MoonClaw run starts; create a revision to change them",
    )
  }
  let query = request.query.trim().to_owned()
  guard !query.is_blank() &&
    request.max_results > 0 &&
    request.max_results <= 30 else {
    fail("arXiv query and 1–30 results are required")
  }
  let now = @async.now()
  let search_query = normalized_arxiv_search(query)
  let papers = @arxiv.fetch_papers(search_query, request.max_results, now)
  let name = "arxiv-\{now}.json"
  let root = job_root(config, job_id)
  @store.write_json(root + "/input/" + name, {
    "source_type": "arxiv-metadata-and-abstracts",
    "query": query,
    "arxiv_query": search_query,
    "retrieved_at": now,
    "full_text_included": false,
    "papers": papers,
  })
  research_job_view(config, job_id)
}

///|
fn normalized_arxiv_search(query : String) -> String {
  let value = query.trim().to_owned()
  let simple = !value.contains("\"") &&
    !value.contains(" AND ") &&
    !value.contains(" OR ") &&
    !value.contains(" ANDNOT ")
  if simple && value.has_prefix("all:") && value.contains(" ") {
    "all:\"" + value["all:".length():].to_owned() + "\""
  } else if !value.contains(":") {
    "all:\"" + value + "\""
  } else {
    value
  }
}

///|
fn permitted_source_url(url : String) -> Bool {
  guard url.has_prefix("https://") && !url.contains("@") && !url.contains("#") else {
    return false
  }
  let authority = url["https://".length():]
    .split("/")
    .collect()
    .get(0)
    .unwrap_or("")
  let host = authority.split(":").collect().get(0).unwrap_or("").to_lower()
  !host.is_blank() &&
  host.contains(".") &&
  host != "localhost" &&
  !host.has_suffix(".localhost") &&
  !host.has_suffix(".local") &&
  !host.has_prefix("127.") &&
  !host.has_prefix("10.") &&
  !host.has_prefix("192.168.") &&
  !host.has_prefix("172.") &&
  !host.has_prefix("169.254.")
}

///|
pub async fn add_research_job_url_source(
  config : Config,
  job_id : String,
  request : AddJobUrlSourceRequestV1,
) -> ResearchJobViewV1 {
  let view = research_job_view(config, job_id)
  guard view.session_key is None else {
    fail(
      "sources are fixed after the MoonClaw run starts; create a revision to change them",
    )
  }
  let url = request.url.trim().to_owned()
  guard permitted_source_url(url) else { fail("use a public HTTPS source URL") }
  let (response, body) = @http.get(url, headers={
    "User-Agent": "Moonfind/0.1 research@vectie.com",
  })
  guard response.code == 200 else {
    fail("source URL returned HTTP \{response.code}")
  }
  let media_type = response.headers.get("content-type").unwrap_or("").to_lower()
  guard media_type.has_prefix("text/") ||
    media_type.has_prefix("application/json") ||
    media_type.has_prefix("application/pdf") ||
    media_type.has_prefix("application/xml") else {
    fail("source URL returned an unsupported content type")
  }
  let data = body.binary()
  guard data.length() > 0 && data.length() <= 10 * 1024 * 1024 else {
    fail("source URL must return 1 byte to 10 MiB")
  }
  let now = @async.now()
  let extension = if media_type.has_prefix("application/pdf") {
    ".pdf"
  } else if media_type.has_prefix("application/json") {
    ".json"
  } else if media_type.has_prefix("application/xml") ||
    media_type.has_prefix("text/xml") {
    ".xml"
  } else if media_type.has_prefix("text/plain") {
    ".txt"
  } else {
    ".html"
  }
  let name = "web-\{now}" + extension
  let root = job_root(config, job_id)
  @fs.write_file(
    root + "/input/" + name,
    data,
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  @store.write_json(root + "/input/" + name + ".source.json", {
    "source_type": "user-provided-url-snapshot",
    "url": url,
    "retrieved_at": now,
    "content_type": media_type,
    "digest": @store.digest_bytes(data),
  })
  research_job_view(config, job_id)
}

///|
pub async fn revise_research_job_file(
  config : Config,
  job_id : String,
  request : ReviseResearchJobRequestV1,
) -> ResearchJobViewV1 {
  let parent = research_job_view(config, job_id)
  let name = request.file_name.trim().to_owned()
  let instruction = request.instruction.trim().to_owned()
  guard safe_output_name(name) &&
    parent.files.any(file => file.name == name) &&
    !instruction.is_blank() else {
    fail("an existing output file and revision instruction are required")
  }
  let spec = parent.job.requested_outputs.filter(output => {
    output.output_id == name
  })
  guard spec.length() == 1 else {
    fail("only requested output files can be revised")
  }
  let child = create_research_job(config, {
    objective: parent.job.objective +
    "\n\nRevision of " +
    name +
    ": " +
    instruction,
    audience: parent.job.audience,
    source_scope: parent.job.source_scope +
    ["Previous version: input/previous-" + name],
    requested_outputs: spec,
  })
  let child_root = child.job_root
  for source in parent.sources {
    let data = @fs.read_file(parent.job_root + "/input/" + source.name).binary()
    @fs.write_file(
      child_root + "/input/" + source.name,
      data,
      create_mode=CreateOrTruncate,
      permission=0o644,
    )
  }
  let original = @fs.read_file(parent.job_root + "/outputs/" + name).binary()
  @fs.write_file(
    child_root + "/input/previous-" + name,
    original,
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  @store.write_json(child_root + "/revision.json", {
    "parent_job_id": job_id,
    "file_name": name,
    "base_digest": @store.digest_bytes(original),
    "instruction": instruction,
    "created_at": @async.now(),
  })
  research_job_view(config, child.job.job_id)
}

///|
pub async fn record_research_job_session(
  config : Config,
  job_id : String,
  request : JobSessionRequestV1,
) -> ResearchJobViewV1 {
  let root = job_root(config, job_id)
  guard @fs.exists(root + "/job.json") && !request.session_key.is_blank() else {
    fail("job and MoonClaw session key are required")
  }
  @store.write_json(root + "/session.json", {
    "session_key": request.session_key,
  })
  research_job_view(config, job_id)
}
