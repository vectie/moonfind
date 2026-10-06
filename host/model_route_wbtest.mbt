///|
fn model_route_config(
  workspace? : String = "/fixture",
  run_id? : String = "run-1",
) -> Config {
  {
    workspace,
    run_id,
    book_workspace: "/trusted/book",
    public_base_url: "http://127.0.0.1:4313",
    capability_catalog_path: None,
    moonclaw_gateway_base: Some("http://configured-cowork.invalid"),
    moonclaw_gateway_token: Some("fixture-server-token"),
    moonclaw_submit_url: None,
    moonclaw_reconcile_url: None,
    moontown_base_url: None,
  }
}

///|
fn cowork_route_fixture() -> Json {
  {
    "contract_id": "moonclaw.cowork-model-route.v1",
    "cwd": "/trusted/book",
    "catalog_ready": true,
    "default_ready": true,
    "default_model": "moongate/chosen",
    "models": ["moongate/other", "moongate/chosen"],
    "blocker": "",
  }
}

///|
async test "trusted host calls actual Cowork projection with exact configured workspace and hides credential" {
  let calls : Array[Json] = []
  let config = model_route_config()
  let projected = native_model_route_with(config, fetch=(path, payload) => {
    calls.push({ "path": path, "body": payload })
    cowork_route_fixture()
  })
  assert_eq(calls, [
    { "path": "/v1/cowork/model-route", "body": { "cwd": "/trusted/book" } },
  ])
  assert_eq(projected.default_model, "moongate/chosen")
  assert_true(projected.default_ready)
  assert_false(projected.to_json().stringify().contains("fixture-server-token"))
  assert_false(projected.to_json().stringify().contains("configured-cowork"))
  assert_eq(
    cowork_headers(config).get("Authorization"),
    Some("Bearer fixture-server-token"),
  )
}

///|
async test "health alone missing route and mismatched root never authorize native default" {
  let config = model_route_config()
  let health = native_model_route_with(config, fetch=(_, _) => {
    ({ "status": "ok" } : Json)
  })
  assert_false(health.default_ready)
  let absent = native_model_route_with(config, fetch=(_, _) => fail("404"))
  assert_false(absent.default_ready)
  assert_eq(absent.default_model, "")
  assert_true(
    absent.blocker.contains("endpoint is unavailable or unauthorized"),
  )
  let different = project_model_route(
    { ..config, book_workspace: "/other/book", },
    cowork_route_fixture(),
  )
  assert_false(different.catalog_ready)
  assert_true(different.blocker.contains("context differs"))
}

///|
async test "host relay persists and reloads exact per-run session binding and preserves model config" {
  let directory = @fs.tmpdir(prefix="moonfind-native-route")
  let config = model_route_config(workspace=directory)
  let calls : Array[String] = []
  async fn transport(path : String, body : Json?) -> Json {
    calls.push(path)
    if path == "/v1/cowork/sessions" {
      assert_eq(body, Some({ "cwd": "/trusted/book", "title": "Fixture" }))
      return {
        "session": {
          "session": { "session_key": "cowork:fixture", "cwd": "/trusted/book" },
        },
      }
    }
    if path == "/v1/cowork/sessions/cowork:fixture" {
      assert_true(body is None)
      return {
        "session": {
          "session": { "session_key": "cowork:fixture", "cwd": "/trusted/book" },
        },
      }
    }
    assert_eq(path, "/v1/cowork/sessions/cowork:fixture/config")
    assert_eq(
      body,
      Some({ "cwd": "/trusted/book", "model": "moongate/chosen" }),
    )
    {
      "session": {
        "session": {
          "session_key": "cowork:fixture",
          "cwd": "/trusted/book",
          "model_override": "moongate/chosen",
        },
      },
    }
  }
  async fn relay(path : String, body : Json?) -> Json {
    cowork_relay_with(
      config,
      path,
      body,
      load_keys=() => bound_cowork_keys(config),
      save_key=key => register_cowork_key(config, key),
      fetch=transport,
    )
  }
  ignore(
    relay(
      "/v1/cowork/sessions",
      Some({ "cwd": "/trusted/book", "title": "Fixture" }),
    ),
  )
  assert_eq(bound_cowork_keys(config), ["cowork:fixture"])
  for _ in 0..<2 {
    let reply = relay(
      "/v1/cowork/sessions/cowork:fixture/config",
      Some({ "cwd": "/trusted/book", "model": "moongate/chosen" }),
    )
    assert_true(
      reply
      is {
        "session": {
          "session": { "model_override": String("moongate/chosen"), .. },
          ..
        },
        ..
      },
    )
  }
  assert_eq(bound_cowork_keys({ ..config, }), ["cowork:fixture"])
  assert_eq(bound_cowork_keys({ ..config, run_id: "new-run", }), [])
  assert_eq(calls.length(), 5)
  for name in @fs.readdir(run_artifact(config, "cowork-host-sessions")) {
    assert_false(
      @fs.read_file(run_artifact(config, "cowork-host-sessions") + "/" + name)
      .text()
      .contains("fixture-server-token"),
    )
  }
}

///|
async test "relay rejects arbitrary paths other sessions folders and blank fallback before upstream call" {
  let config = model_route_config()
  let paths = [
    "/v1/runs", "/v1/cowork/sessions/other/config", "/v1/cowork/sessions/cowork:fixture/config",
    "/v1/cowork/sessions/cowork:fixture/messages",
  ]
  let payloads : Array[Json?] = [
    None,
    Some({ "model": "moongate/chosen" }),
    Some({ "cwd": "/other/book", "model": "moongate/chosen" }),
    Some({ "model": "", "content": "test" }),
  ]
  let calls = Ref(0)
  for index, path in paths {
    let blocked = try {
      ignore(
        cowork_relay_with(
          config,
          path,
          payloads[index],
          load_keys=() => ["cowork:fixture"],
          save_key=_ => (),
          fetch=(_, _) => {
            calls.val += 1
            Json::empty_object()
          },
        ),
      )
      false
    } catch {
      _ => true
    }
    assert_true(blocked)
  }
  assert_eq(calls.val, 0)
}

///|
test "checkpoint cannot adopt another session and validates legacy identity and workspace" {
  assert_false(
    checkpoint_session_authorized("cowork:foreign", None, ["cowork:owned"]),
  )
  assert_false(
    checkpoint_session_authorized("cowork:foreign", Some("cowork:old-owned"), []),
  )
  assert_true(
    checkpoint_session_authorized("cowork:owned", None, ["cowork:owned"]),
  )
  assert_true(
    checkpoint_session_authorized("cowork:legacy", Some("cowork:legacy"), []),
  )
  assert_false(
    checkpoint_session_authorized("../foreign", Some("../foreign"), []),
  )
  let correct : Json = {
    "session": {
      "session": { "session_key": "cowork:owned", "cwd": "/trusted/book" },
    },
  }
  assert_true(
    valid_checkpoint_session_binding(
      model_route_config(),
      "cowork:owned",
      correct,
    ),
  )
  assert_false(
    valid_checkpoint_session_binding(
      model_route_config(),
      "cowork:foreign",
      correct,
    ),
  )
  assert_false(
    valid_checkpoint_session_binding(
      { ..model_route_config(), book_workspace: "/other/book", },
      "cowork:owned",
      correct,
    ),
  )
}

///|
async test "concurrent independent session registrations survive atomic publication and reload" {
  let directory = @fs.tmpdir(prefix="moonfind-concurrent-sessions")
  let config = model_route_config(workspace=directory)
  ignore(
    @async.all([
      () => register_cowork_key(config, "cowork:a"),
      () => register_cowork_key(config, "cowork:b"),
    ]),
  )
  assert_eq(registered_cowork_keys({ ..config, }), ["cowork:a", "cowork:b"])
  register_cowork_key(config, "cowork:a")
  assert_eq(registered_cowork_keys(config), ["cowork:a", "cowork:b"])
  assert_eq(
    registered_cowork_keys({ ..config, book_workspace: "/another/root", }),
    [],
  )
  assert_eq(
    registered_cowork_keys({
      ..config,
      moonclaw_gateway_base: Some("http://other-service.invalid"),
    }),
    [],
  )
  assert_true(
    @fs.readdir(run_artifact(config, "cowork-host-sessions")).all(name => {
      name.has_suffix(".json")
    }),
  )
}
