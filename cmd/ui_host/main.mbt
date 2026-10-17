///|
struct ServiceOptions {
  config : @host.Config
  port : Int
  ui_root : String
}

///|
fn option_value(args : Array[String], name : String) -> String? {
  for index, value in args {
    if value == name && index + 1 < args.length() {
      return Some(args[index + 1])
    }
  }
  None
}

///|
fn environment_or_option(
  args : Array[String],
  option : String,
  environment : String,
) -> String? {
  match option_value(args, option) {
    Some(value) if !value.trim().is_blank() => Some(value.trim().to_owned())
    _ =>
      match @env.get_env_var(environment) {
        Some(value) if !value.trim().is_blank() => Some(value.trim().to_owned())
        _ => None
      }
  }
}

///|
fn service_options() -> ServiceOptions raise {
  let args = @env.args()
  let current = @env.current_dir().unwrap_or(".")
  let workspace = environment_or_option(
    args, "--workspace", "MOONFIND_WORKSPACE",
  ).unwrap_or(current)
  let run_id = environment_or_option(args, "--run-id", "MOONFIND_RUN_ID").unwrap_or(
    "",
  )
  let port_text = environment_or_option(args, "--port", "MOONFIND_UI_PORT").unwrap_or(
    "4313",
  )
  let port = @string.parse_int(port_text)
  guard port > 0 && port <= 65535 else {
    fail("MoonFind UI host port must be between 1 and 65535")
  }
  let book_workspace = environment_or_option(
    args, "--book-workspace", "MOONFIND_BOOK_WORKSPACE",
  ).unwrap_or(workspace)
  {
    config: {
      workspace,
      run_id,
      book_workspace,
      public_base_url: "http://127.0.0.1:\{port}",
      capability_catalog_path: environment_or_option(
        args, "--catalog", "MOONFIND_CAPABILITY_CATALOG",
      ),
      moonclaw_gateway_base: environment_or_option(
        args, "--moonclaw-gateway", "MOONCLAW_GATEWAY_BASE",
      ),
      moonclaw_gateway_token: match
        option_value(args, "--moonclaw-gateway-token") {
        Some(value) if !value.trim().is_blank() => Some(value.trim().to_owned())
        _ =>
          environment_or_option(
            args, "--moonclaw-token", "MOONCLAW_GATEWAY_TOKEN",
          )
      },
      moonclaw_submit_url: environment_or_option(
        args, "--moonclaw-submit", "MOONCLAW_CAPABILITY_SUBMIT_URL",
      ),
      moonclaw_reconcile_url: environment_or_option(
        args, "--moonclaw-reconcile", "MOONCLAW_CAPABILITY_RECONCILE_URL",
      ),
      moontown_base_url: environment_or_option(
        args, "--moontown-base", "MOONTOWN_BASE_URL",
      ),
    },
    port,
    ui_root: environment_or_option(args, "--ui-root", "MOONFIND_UI_ROOT").unwrap_or(
      current + "/ui/rabbita-moonfind/dist",
    ),
  }
}

///|
fn route_path(path : String) -> String {
  match path.find("?") {
    Some(index) => path[:index].to_owned()
    None => path
  }
}

///|
async fn send_text(
  conn : @http.ServerConnection,
  code : Int,
  reason : String,
  content_type : String,
  text : String,
) -> Unit {
  conn.send_response(code, reason, extra_headers={
    "Content-Type": content_type,
    "Cache-Control": "no-store",
  })
  conn.write(text)
  conn.end_response()
}

///|
async fn send_json(
  conn : @http.ServerConnection,
  code : Int,
  reason : String,
  value : Json,
) -> Unit {
  send_text(
    conn,
    code,
    reason,
    "application/json; charset=utf-8",
    value.stringify(indent=2),
  )
}

///|
async fn send_file(
  conn : @http.ServerConnection,
  data : Bytes,
  media_type : String,
) -> Unit {
  conn.send_response(200, "OK", extra_headers={
    "Content-Type": media_type,
    "Cache-Control": "no-store",
    "Content-Disposition": if media_type == "text/html" ||
      media_type == "image/svg+xml" {
      "attachment"
    } else {
      "inline"
    },
    "X-Content-Type-Options": "nosniff",
  })
  conn.write(data)
  conn.end_response()
}

///|
async fn send_job_export(
  conn : @http.ServerConnection,
  data : Bytes,
  job_id : String,
) -> Unit {
  conn.send_response(200, "OK", extra_headers={
    "Content-Type": "application/zip",
    "Cache-Control": "no-store",
    "Content-Disposition": "attachment; filename=\"" + job_id + ".zip\"",
    "X-Content-Type-Options": "nosniff",
  })
  conn.write(data)
  conn.end_response()
}

///|
async fn send_error(
  conn : @http.ServerConnection,
  code : Int,
  reason : String,
  message : String,
) -> Unit {
  send_json(conn, code, reason, {
    "error": { "contract_id": "moonfind.ui-host-error.v1", "message": message },
  })
}

///|
fn request_header(request : @http.Request, name : String) -> String {
  request.headers.get(name).unwrap_or("").trim().to_owned()
}

///|
fn trusted_request_origin(host : String, origin : String, port : Int) -> Bool {
  (host == "127.0.0.1:\{port}" || host == "localhost:\{port}") &&
  (origin.is_blank() || origin == "http://" + host)
}

///|
async fn reject_unsafe_origin(
  request : @http.Request,
  port : Int,
  conn : @http.ServerConnection,
) -> Bool {
  if !trusted_request_origin(
      request_header(request, "host").to_lower(),
      request_header(request, "origin").to_lower(),
      port,
    ) {
    send_error(
      conn, 403, "Forbidden", "trusted localhost host and same-origin request are required",
    )
    true
  } else {
    false
  }
}

///|
async fn reject_unsafe_write(
  request : @http.Request,
  port : Int,
  conn : @http.ServerConnection,
) -> Bool {
  let host = request_header(request, "host").to_lower()
  let expected = "127.0.0.1:\{port}"
  let alternate = "localhost:\{port}"
  if host != expected && host != alternate {
    send_error(conn, 403, "Forbidden", "localhost host is required")
    return true
  }
  let origin = request_header(request, "origin").to_lower()
  if !origin.is_blank() && origin != "http://" + host {
    send_error(conn, 403, "Forbidden", "same-origin request is required")
    return true
  }
  let content_type = request_header(request, "content-type").to_lower()
  if !content_type.has_prefix("application/json") {
    send_error(
      conn, 415, "Unsupported Media Type", "application/json is required",
    )
    return true
  }
  let content_length = request_header(request, "content-length")
  let transfer_encoding = request_header(request, "transfer-encoding")
  if content_length.is_blank() || !transfer_encoding.is_blank() {
    send_error(
      conn, 411, "Length Required", "bounded Content-Length is required",
    )
    return true
  }
  let size = @string.parse_int(content_length) catch {
    _ => {
      send_error(conn, 400, "Bad Request", "invalid Content-Length")
      return true
    }
  }
  if size < 1 || size > 1024 * 1024 {
    send_error(
      conn, 413, "Content Too Large", "request body must be between 1 byte and 1 MiB",
    )
    return true
  }
  false
}

///|
fn content_type(path : String) -> String {
  if path.has_suffix(".html") {
    "text/html; charset=utf-8"
  } else if path.has_suffix(".js") || path.has_suffix(".mjs") {
    "text/javascript; charset=utf-8"
  } else if path.has_suffix(".css") {
    "text/css; charset=utf-8"
  } else if path.has_suffix(".json") {
    "application/json; charset=utf-8"
  } else {
    "application/octet-stream"
  }
}

///|
async fn serve_static(
  options : ServiceOptions,
  request_path : String,
  conn : @http.ServerConnection,
) -> Bool {
  let relative = if request_path
    is ("/"
    | "/index.html"
    | "/apps/moonfind/research"
    | "/apps/moonfind/briefs"
    | "/apps/moonfind/jobs") {
    "index.html"
  } else if request_path.has_prefix("/apps/moonfind/assets/") {
    request_path["/apps/moonfind/".length():].to_owned()
  } else if request_path.has_prefix("/") {
    request_path[1:].to_owned()
  } else {
    request_path
  }
  if relative.is_blank() || relative.contains("..") || relative.contains("\\") {
    return false
  }
  let path = options.ui_root + "/" + relative
  if !@fs.exists(path) {
    return false
  }
  let text = @fs.read_file(path).text()
  send_text(conn, 200, "OK", content_type(path), text)
  true
}

///|
async fn handle_request(
  options : ServiceOptions,
  request : @http.Request,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Unit {
  let path = route_path(request.path)
  match (request.meth, path) {
    (Post, "/api/v1/briefs/csv/intake") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let intake : @host.CsvIntakeRequestV1 = @json.from_json(
        @json.parse(body.read_all().text()),
      )
      send_json(conn, 200, "OK", @host.intake_csv(intake).to_json())
    }
    (Post, "/api/v1/briefs/csv/select") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let selection : @host.CsvSelectRequestV1 = @json.from_json(
        @json.parse(body.read_all().text()),
      )
      send_json(conn, 200, "OK", @host.select_csv(selection).to_json())
    }
    (Post, "/api/v1/briefs/csl/intake") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let intake : @host.CslIntakeRequestV1 = @json.from_json(
        @json.parse(body.read_all().text()),
      )
      send_json(conn, 200, "OK", @host.intake_csl(intake).to_json())
    }
    (Post, "/api/v1/briefs/csl/select") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let selection : @host.CslSelectRequestV1 = @json.from_json(
        @json.parse(body.read_all().text()),
      )
      send_json(conn, 200, "OK", @host.select_csl(selection).to_json())
    }
    (Post, "/api/v1/briefs/bibtex/intake") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let intake : @host.BibtexIntakeRequestV1 = @json.from_json(
        @json.parse(body.read_all().text()),
      )
      send_json(conn, 200, "OK", @host.intake_bibtex(intake).to_json())
    }
    (Post, "/api/v1/briefs/bibtex/select") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let selection : @host.BibtexSelectRequestV1 = @json.from_json(
        @json.parse(body.read_all().text()),
      )
      send_json(conn, 200, "OK", @host.select_bibtex(selection).to_json())
    }
    (Post, "/api/v1/briefs/ris/intake") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let intake : @host.RisIntakeRequestV1 = @json.from_json(
        @json.parse(body.read_all().text()),
      )
      send_json(conn, 200, "OK", @host.intake_ris(intake).to_json())
    }
    (Post, "/api/v1/briefs/ris/select") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let selection : @host.RisSelectRequestV1 = @json.from_json(
        @json.parse(body.read_all().text()),
      )
      send_json(conn, 200, "OK", @host.select_ris(selection).to_json())
    }
    (Post, "/api/v1/briefs/endnote/intake") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let intake : @host.EndnoteIntakeRequestV1 = @json.from_json(
        @json.parse(body.read_all().text()),
      )
      send_json(conn, 200, "OK", @host.intake_endnote(intake).to_json())
    }
    (Post, "/api/v1/briefs/endnote/select") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let selection : @host.EndnoteSelectRequestV1 = @json.from_json(
        @json.parse(body.read_all().text()),
      )
      send_json(conn, 200, "OK", @host.select_endnote(selection).to_json())
    }
    (Post, "/api/v1/briefs/nbib/intake") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let intake : @host.NbibIntakeRequestV1 = @json.from_json(
        @json.parse(body.read_all().text()),
      )
      send_json(conn, 200, "OK", @host.intake_nbib(intake).to_json())
    }
    (Post, "/api/v1/briefs/nbib/select") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let selection : @host.NbibSelectRequestV1 = @json.from_json(
        @json.parse(body.read_all().text()),
      )
      send_json(conn, 200, "OK", @host.select_nbib(selection).to_json())
    }
    (Get, "/api/v1/briefs") => {
      if reject_unsafe_origin(request, options.port, conn) {
        return
      }
      send_json(conn, 200, "OK", @host.list_briefs(options.config).to_json())
    }
    (Post, "/api/v1/briefs") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let brief : @research.ResearchBriefV1 = @json.from_json(
        @json.parse(body.read_all().text()),
      )
      send_json(
        conn,
        200,
        "OK",
        @host.save_brief(options.config, brief).to_json(),
      )
    }
    (Get, brief_path) if brief_path.has_prefix("/api/v1/briefs/") => {
      if reject_unsafe_origin(request, options.port, conn) {
        return
      }
      let parts = brief_path["/api/v1/briefs/".length():]
        .split("/")
        .map(StringView::to_owned)
        .collect()
      match parts {
        [id, revision] =>
          send_json(
            conn,
            200,
            "OK",
            @host.brief_status(options.config, id, revision).to_json(),
          )
        [id, revision, name] => {
          let bytes = @host.export_brief(options.config, id, revision, name)
          conn.send_response(200, "OK", extra_headers={
            "Content-Type": if name == "dossier.zip" {
              "application/zip"
            } else {
              "text/plain; charset=utf-8"
            },
            "Content-Length": bytes.length().to_string(),
            "Content-Disposition": "attachment; filename=\"" + name + "\"",
            "Cache-Control": "no-store",
            "X-Content-Type-Options": "nosniff",
          })
          conn.write(bytes)
          conn.end_response()
        }
        _ => send_error(conn, 400, "Bad Request", "Invalid brief route")
      }
    }
    (Get, "/api/v1/jobs") => {
      if reject_unsafe_origin(request, options.port, conn) {
        return
      }
      let jobs = @host.list_research_jobs(options.config)
      send_json(conn, 200, "OK", jobs.to_json())
    }
    (Post, "/api/v1/jobs") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let job_request : @host.CreateResearchJobRequestV1 = @json.from_json(
        @json.parse(body.read_all().text()),
      )
      let created = @host.create_research_job(options.config, job_request)
      send_json(conn, 201, "Created", created.to_json())
    }
    (Get, job_path) if job_path.has_prefix("/api/v1/jobs/") => {
      if reject_unsafe_origin(request, options.port, conn) {
        return
      }
      let tail = job_path["/api/v1/jobs/".length():].to_owned()
      let parts = tail.split("/").collect()
      match parts {
        [job_id, "delivery"] => {
          let job = @host.research_job_view(options.config, job_id.to_owned())
          match job.delivery_manifest {
            Some(manifest) => send_json(conn, 200, "OK", manifest.to_json())
            None =>
              send_error(
                conn, 404, "Not Found", "delivery has not been verified",
              )
          }
        }
        [job_id, "files", name] => {
          let (data, media_type) = @host.research_job_file(
            options.config,
            job_id.to_owned(),
            name.to_owned(),
          )
          send_file(conn, data, media_type)
        }
        [job_id, "files", name, "preview"] => {
          let preview = @host.research_job_preview(
            options.config,
            job_id.to_owned(),
            name.to_owned(),
          )
          send_json(conn, 200, "OK", preview.to_json())
        }
        [job_id, "sources", name] => {
          let (data, media_type) = @host.research_job_source_file(
            options.config,
            job_id.to_owned(),
            name.to_owned(),
          )
          send_file(conn, data, media_type)
        }
        [job_id, "export.zip"] => {
          let data = @host.research_job_export(
            options.config,
            job_id.to_owned(),
          )
          send_job_export(conn, data, job_id.to_owned())
        }
        [job_id] => {
          let job = @host.research_job_view(options.config, job_id.to_owned())
          send_json(conn, 200, "OK", job.to_json())
        }
        _ => send_error(conn, 404, "Not Found", "research job route not found")
      }
    }
    (Post, job_path) if job_path.has_prefix("/api/v1/jobs/") &&
      job_path.has_suffix("/sources/text") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let tail = job_path["/api/v1/jobs/".length():].to_owned()
      match tail.split("/").collect() {
        [job_id, "sources", "text"] => {
          let source : @host.AddJobTextSourceRequestV1 = @json.from_json(
            @json.parse(body.read_all().text()),
          )
          let job = @host.add_research_job_text_source(
            options.config,
            job_id.to_owned(),
            source,
          )
          send_json(conn, 200, "OK", job.to_json())
        }
        _ =>
          send_error(conn, 404, "Not Found", "research source route not found")
      }
    }
    (Post, job_path) if job_path.has_prefix("/api/v1/jobs/") &&
      job_path.has_suffix("/sources/arxiv") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let tail = job_path["/api/v1/jobs/".length():].to_owned()
      match tail.split("/").collect() {
        [job_id, "sources", "arxiv"] => {
          let source : @host.AddJobArxivSourceRequestV1 = @json.from_json(
            @json.parse(body.read_all().text()),
          )
          let job = @host.add_research_job_arxiv_source(
            options.config,
            job_id.to_owned(),
            source,
          )
          send_json(conn, 200, "OK", job.to_json())
        }
        _ =>
          send_error(conn, 404, "Not Found", "research source route not found")
      }
    }
    (Post, job_path) if job_path.has_prefix("/api/v1/jobs/") &&
      job_path.has_suffix("/sources/url") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let tail = job_path["/api/v1/jobs/".length():].to_owned()
      match tail.split("/").collect() {
        [job_id, "sources", "url"] => {
          let source : @host.AddJobUrlSourceRequestV1 = @json.from_json(
            @json.parse(body.read_all().text()),
          )
          let job = @host.add_research_job_url_source(
            options.config,
            job_id.to_owned(),
            source,
          )
          send_json(conn, 200, "OK", job.to_json())
        }
        _ =>
          send_error(conn, 404, "Not Found", "research source route not found")
      }
    }
    (Post, job_path) if job_path.has_prefix("/api/v1/jobs/") &&
      job_path.has_suffix("/revisions") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let tail = job_path["/api/v1/jobs/".length():].to_owned()
      match tail.split("/").collect() {
        [job_id, "revisions"] => {
          let revision : @host.ReviseResearchJobRequestV1 = @json.from_json(
            @json.parse(body.read_all().text()),
          )
          let job = @host.revise_research_job_file(
            options.config,
            job_id.to_owned(),
            revision,
          )
          send_json(conn, 201, "Created", job.to_json())
        }
        _ =>
          send_error(
            conn, 404, "Not Found", "research revision route not found",
          )
      }
    }
    (Post, job_path) if job_path.has_prefix("/api/v1/jobs/") &&
      job_path.has_suffix("/resume") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let tail = job_path["/api/v1/jobs/".length():].to_owned()
      match tail.split("/").collect() {
        [job_id, "resume"] => {
          let response : @host.ResumeResearchJobRequestV1 = @json.from_json(
            @json.parse(body.read_all().text()),
          )
          let job = @host.resume_research_job(
            options.config,
            job_id.to_owned(),
            response,
          )
          send_json(conn, 200, "OK", job.to_json())
        }
        _ =>
          send_error(conn, 404, "Not Found", "research resume route not found")
      }
    }
    (Post, job_path) if job_path.has_prefix("/api/v1/jobs/") &&
      job_path.has_suffix("/start") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let tail = job_path["/api/v1/jobs/".length():].to_owned()
      match tail.split("/").collect() {
        [job_id, "start"] => {
          let start : @host.StartResearchJobRequestV1 = @json.from_json(
            @json.parse(body.read_all().text()),
          )
          let job = @host.start_research_job(
            options.config,
            job_id.to_owned(),
            start,
          )
          send_json(conn, 200, "OK", job.to_json())
        }
        _ => send_error(conn, 404, "Not Found", "research job route not found")
      }
    }
    (Post, job_path) if job_path.has_prefix("/api/v1/jobs/") &&
      job_path.has_suffix("/session") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let tail = job_path["/api/v1/jobs/".length():].to_owned()
      let parts = tail.split("/").collect()
      match parts {
        [job_id, "session"] => {
          let session : @host.JobSessionRequestV1 = @json.from_json(
            @json.parse(body.read_all().text()),
          )
          let job = @host.record_research_job_session(
            options.config,
            job_id.to_owned(),
            session,
          )
          send_json(conn, 200, "OK", job.to_json())
        }
        _ => send_error(conn, 404, "Not Found", "research job route not found")
      }
    }
    (Post, job_path) if job_path.has_prefix("/api/v1/jobs/") &&
      job_path.has_suffix("/delivery") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let tail = job_path["/api/v1/jobs/".length():].to_owned()
      match tail.split("/").collect() {
        [job_id, "delivery"] => {
          let job = @host.verify_research_job_delivery(
            options.config,
            job_id.to_owned(),
          )
          send_json(conn, 200, "OK", job.to_json())
        }
        _ => send_error(conn, 404, "Not Found", "research job route not found")
      }
    }
    (Get, "/api/v1/series") =>
      send_json(conn, 200, "OK", @series.catalog().to_json())
    (Get, series_path) if series_path.has_prefix("/api/v1/series/") => {
      let use_case_id = series_path["/api/v1/series/".length():].to_owned()
      guard !use_case_id.is_blank() &&
        !use_case_id.contains("/") &&
        !use_case_id.contains("..") else {
        send_error(conn, 400, "Bad Request", "invalid series use-case id")
        return
      }
      match @series.find(use_case_id) {
        Some(use_case) => {
          let issues = @series.validate(use_case)
          guard issues.is_empty() else {
            send_error(
              conn,
              409,
              "Conflict",
              "series use case is invalid: " + issues.join("; "),
            )
            return
          }
          send_json(conn, 200, "OK", use_case.to_json())
        }
        None => send_error(conn, 404, "Not Found", "series use case not found")
      }
    }
    (Get, "/api/v1/workspace") => {
      if options.config.run_id.is_blank() {
        send_error(
          conn, 404, "Not Found", "no specialized research run is selected",
        )
        return
      }
      let snapshot = @host.workspace_snapshot(options.config)
      send_json(conn, 200, "OK", snapshot.to_json())
    }
    (Get, "/api/v1/delivery") => {
      if reject_unsafe_origin(request, options.port, conn) {
        return
      }
      send_json(
        conn,
        200,
        "OK",
        @host.delivery_status(options.config).to_json(),
      )
    }
    (Post, "/api/v1/delivery/prepare") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let preparation : @host.DeliveryPrepareV1 = @json.from_json(
        @json.parse(body.read_all().text()),
      )
      send_json(
        conn,
        200,
        "OK",
        @host.prepare_delivery(options.config, preparation).to_json(),
      )
    }
    (Get, delivery_path) if delivery_path.has_prefix("/api/v1/delivery/") => {
      if reject_unsafe_origin(request, options.port, conn) {
        return
      }
      let parts = delivery_path["/api/v1/delivery/".length():]
        .split("/")
        .map(part => part.to_owned())
        .collect()
      match parts {
        [id] =>
          send_json(
            conn,
            200,
            "OK",
            @host.delivery_status(options.config, delivery_id=id).to_json(),
          )
        [id, name] => {
          let bytes = @host.read_delivery_file(options.config, id, name)
          let media = if name == "package.zip" {
            "application/zip"
          } else if name == "report.md" {
            "text/plain; charset=utf-8"
          } else {
            "application/json; charset=utf-8"
          }
          conn.send_response(200, "OK", extra_headers={
            "Content-Type": media,
            "Content-Length": bytes.length().to_string(),
            "Cache-Control": "no-store",
            "X-Content-Type-Options": "nosniff",
          })
          conn.write(bytes)
          conn.end_response()
        }
        _ => send_error(conn, 400, "Bad Request", "Invalid delivery route")
      }
    }
    (Get, "/api/v1/model-route") => {
      if reject_unsafe_origin(request, options.port, conn) {
        return
      }
      send_json(
        conn,
        200,
        "OK",
        @host.native_model_route(options.config).to_json(),
      )
    }
    (Get | Post, relay) if relay.has_prefix("/api/v1/cowork-gateway/v1/cowork/") => {
      if reject_unsafe_origin(request, options.port, conn) {
        return
      }
      if request.meth == Post &&
        reject_unsafe_write(request, options.port, conn) {
        return
      }
      let payload = if request.meth == Post {
        Some(@json.parse(body.read_all().text()))
      } else {
        None
      }
      let value = @host.cowork_relay(
        options.config,
        relay["/api/v1/cowork-gateway".length():].to_owned(),
        payload,
      )
      send_json(conn, 200, "OK", value)
    }
    (Get, "/api/v1/moontown/handoff") => {
      let handoff = @host.typed_moontown_handoff(options.config)
      send_json(conn, 200, "OK", handoff)
    }
    (Post, "/api/v1/moontown/result") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let result : @moontown.TownResultIngestRequest = @json.from_json(
        @json.parse(body.read_all().text()),
      )
      let reply = @host.ingest_moontown_result(options.config, result)
      send_json(conn, 200, "OK", reply.to_json())
    }
    (Post, "/api/v1/review/prepare") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let review : @host.ReviewPrepareRequestV1 = @json.from_json(
        @json.parse(body.read_all().text()),
      )
      let reply = @host.prepare_cross_product_review(options.config, review)
      send_json(conn, 200, "OK", reply.to_json())
    }
    (Post, "/api/v1/review/moonflow-receipt") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let receipt_request : @host.ReviewMoonFlowReceiptRequestV1 = @json.from_json(
        @json.parse(body.read_all().text()),
      )
      let reply = @host.prepare_moonflow_review_receipt(
        options.config,
        receipt_request,
      )
      send_json(conn, 200, "OK", reply.to_json())
    }
    (Post, "/api/v1/review/moonchat-result") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let result : @host.MoonChatResultIngestRequestV1 = @json.from_json(
        @json.parse(body.read_all().text()),
      )
      let reply = @host.ingest_moonchat_result(options.config, result)
      send_json(conn, 200, "OK", reply.to_json())
    }
    (Post, "/api/v1/capability/submit") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let invocation = @json.parse(body.read_all().text())
      let reply = @host.submit_execution(options.config, invocation)
      send_json(conn, 200, "OK", reply.to_json())
    }
    (Post, "/api/v1/capability/reconcile") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let invocation = @json.parse(body.read_all().text())
      let reply = @host.reconcile_execution(options.config, invocation)
      send_json(conn, 200, "OK", reply.to_json())
    }
    (Post, "/api/v1/capability/checkpoint") => {
      if reject_unsafe_write(request, options.port, conn) {
        return
      }
      let checkpoint : @host.MoonClawSessionCheckpointRequestV1 = @json.from_json(
        @json.parse(body.read_all().text()),
      )
      let reply = @host.checkpoint_execution(options.config, checkpoint)
      send_json(conn, 200, "OK", reply.to_json())
    }
    (Get, _) =>
      if !serve_static(options, path, conn) {
        send_error(conn, 404, "Not Found", "MoonFind route not found")
      }
    _ =>
      send_error(conn, 405, "Method Not Allowed", "MoonFind method not allowed")
  }
}

///|
async fn main {
  let options = service_options()
  if options.config.run_id.is_blank() {
    println(
      "MoonFind offline brief studio: no execution run selected; brief capture is available without providers.",
    )
  } else {
    match @host.ensure_prepared_execution(options.config) {
      Some(record) =>
        println(
          "MoonFind durable execution: \{record.state} revision \{record.revision}",
        )
      None =>
        println(
          "MoonFind UI host started without a prepared execution; the UI will fail closed.",
        )
    }
  }
  let server = @http.Server(
    @socket.Addr::parse("127.0.0.1:\{options.port}"),
    reuse_addr=true,
  )
  println(
    "MoonFind UI host: http://127.0.0.1:\{options.port}/apps/moonfind/" +
    (if options.config.run_id.is_blank() { "briefs" } else { "research" }),
  )
  println(
    "MoonFind research jobs: http://127.0.0.1:\{options.port}/apps/moonfind/jobs",
  )
  server.run_forever(
    (request, body, conn) => {
      handle_request(options, request, body, conn) catch {
        error =>
          // A client may disconnect after the response headers or a partial
          // body. The original write error is already terminal for that
          // connection; attempting to serialize a second error must not stop
          // the host for every other operator.
          send_error(
            conn,
            409,
            "Conflict",
            "MoonFind host rejected the request: \{error}",
          ) catch {
            _ => ()
          }
      }
    },
    max_connections=32,
  )
}
