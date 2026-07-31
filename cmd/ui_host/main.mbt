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
  guard !run_id.is_blank() else {
    fail("MoonFind UI host requires --run-id or MOONFIND_RUN_ID")
  }
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
    is ("/" | "/index.html" | "/apps/moonfind/research") {
    "index.html"
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
    (Get, "/api/v1/workspace") => {
      let snapshot = @host.workspace_snapshot(options.config)
      send_json(conn, 200, "OK", snapshot.to_json())
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
  let server = @http.Server(
    @socket.Addr::parse("127.0.0.1:\{options.port}"),
    reuse_addr=true,
  )
  println(
    "MoonFind UI host: http://127.0.0.1:\{options.port}/apps/moonfind/research",
  )
  server.run_forever(
    (request, body, conn) => {
      handle_request(options, request, body, conn) catch {
        error =>
          send_error(
            conn,
            409,
            "Conflict",
            "MoonFind host rejected the request: \{error}",
          )
      }
    },
    max_connections=32,
  )
}
