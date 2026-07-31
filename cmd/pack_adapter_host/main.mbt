///|
struct ServiceOptions {
  config : @pack_adapter.AdapterConfig
  port : Int
}

///|
fn environment(name : String) -> String? {
  match @env.get_env_var(name) {
    Some(value) if !value.trim().is_blank() => Some(value.trim().to_owned())
    _ => None
  }
}

///|
fn service_options() -> ServiceOptions raise {
  let workspace = environment("MOONFIND_WORKSPACE").unwrap_or(
    @env.current_dir().unwrap_or("."),
  )
  let port = @string.parse_int(
    environment("MOONFIND_PACK_ADAPTER_PORT").unwrap_or("4314"),
  )
  guard port > 0 && port <= 65535 else {
    fail("MOONFIND_PACK_ADAPTER_PORT must be between 1 and 65535")
  }
  { config: @pack_adapter.AdapterConfig::new(workspace), port }
}

///|
async fn send_json(
  conn : @http.ServerConnection,
  code : Int,
  reason : String,
  value : Json,
) -> Unit {
  conn.send_response(code, reason, extra_headers={
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
  })
  conn.write(value.stringify(indent=2))
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
    "error": {
      "contract_id": "moonfind.pack-tool-http-error.v1",
      "message": message,
    },
  })
}

///|
fn route_path(path : String) -> String {
  match path.find("?") {
    Some(index) => path[:index].to_owned()
    None => path
  }
}

///|
fn request_header(request : @http.Request, name : String) -> String {
  request.headers.get(name).unwrap_or("").trim().to_owned()
}

///|
async fn reject_unsafe_write(
  request : @http.Request,
  options : ServiceOptions,
  conn : @http.ServerConnection,
) -> Bool {
  let host = request_header(request, "host").to_lower()
  if host != "127.0.0.1:\{options.port}" && host != "localhost:\{options.port}" {
    send_error(conn, 403, "Forbidden", "exact loopback Host is required")
    return true
  }
  let origin = request_header(request, "origin").to_lower()
  if !origin.is_blank() && origin != "http://" + host {
    send_error(conn, 403, "Forbidden", "cross-origin mutation is forbidden")
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
  let length = @string.parse_int(content_length) catch {
    _ => {
      send_error(conn, 400, "Bad Request", "invalid Content-Length")
      return true
    }
  }
  if length < 1 || length > 8 * 1024 * 1024 {
    send_error(
      conn, 413, "Content Too Large", "request exceeds the 8 MiB limit",
    )
    return true
  }
  false
}

///|
async fn decode_request(
  body : &@io.Reader,
) -> @pack_adapter.PackToolExecutionRequest {
  @json.from_json(@json.parse(body.read_all().text()))
}

///|
async fn handle_request(
  options : ServiceOptions,
  request : @http.Request,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Unit {
  match (request.meth, route_path(request.path)) {
    (Get, "/health") =>
      send_json(conn, 200, "OK", {
        "contract_id": "moonfind.pack-tool-health.v1",
        "product_id": "moonfind",
        "adapter_id": "moonfind-pack-local-v1",
        "status": "ready",
        "provider_calls": false,
        "submit_path": "/v1/pack-tool/submit",
        "reconcile_path": "/v1/pack-tool/reconcile",
      })
    (Post, "/v1/pack-tool/submit") => {
      if reject_unsafe_write(request, options, conn) {
        return
      }
      let execution = @pack_adapter.submit(options.config, decode_request(body))
      send_json(conn, 200, "OK", execution.to_json())
    }
    (Post, "/v1/pack-tool/reconcile") => {
      if reject_unsafe_write(request, options, conn) {
        return
      }
      let reconciliation = @pack_adapter.reconcile(
        options.config,
        decode_request(body),
      )
      send_json(conn, 200, "OK", reconciliation.to_json())
    }
    (Get, _) =>
      send_error(conn, 404, "Not Found", "MoonFind pack-tool route not found")
    _ =>
      send_error(
        conn, 405, "Method Not Allowed", "MoonFind pack-tool method not allowed",
      )
  }
}

///|
async fn main {
  let options = service_options()
  guard @fs.exists(options.config.workspace) else {
    fail("MOONFIND_WORKSPACE does not exist")
  }
  let server = @http.Server(
    @socket.Addr::parse("127.0.0.1:\{options.port}"),
    reuse_addr=true,
  )
  println("MoonFind pack adapter: http://127.0.0.1:\{options.port}/health")
  server.run_forever(
    (request, body, conn) => {
      handle_request(options, request, body, conn) catch {
        error =>
          send_error(
            conn,
            409,
            "Conflict",
            "MoonFind pack adapter rejected the request: \{error}",
          )
      }
    },
    max_connections=16,
  )
}
