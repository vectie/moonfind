///|
fn qa_create_payload(config : Config) -> Json {
  {
    "moonfind_purpose": "qa",
    "moonfind_run_id": config.run_id,
    "cwd": config.book_workspace,
    "title": "MoonFind Q&A: exact topic",
  }
}

///|
fn qa_session_reply(key : String, cwd : String) -> Json {
  {
    "session": {
      "session": {
        "session_key": key,
        "cwd": cwd,
        "model_override": "moongate/chosen",
      },
    },
  }
}

///|
async fn qa_fixture_workspace(config : Config) -> Unit {
  let projection : @app.ResearchWorkspaceProjection = {
    product_id: "moonfind",
    title: "User-owned topic",
    run_id: config.run_id,
    status: "awaiting-agent-analysis",
    watch_title: "User-owned watch",
    query: "exact query",
    paper_count: 0,
    summary_count: 0,
    idea_count: 0,
    question_count: 0,
    accepted_idea_count: 0,
    pipeline: [],
    active_stage: "analysis",
    papers: [],
    summaries: [],
    ideas: [],
    questions: [],
    validation_issues: [],
    bookkeeper_route: "pending",
    three_gap_state: "pending",
  }
  @store.write_run_artifact(
    config.workspace,
    config.run_id,
    "workspace.json",
    projection.to_json(),
  )
  @store.write_run_artifact(config.workspace, config.run_id, "run.json", {
    "run_id": config.run_id,
    "user_metadata": { "do-not-overwrite": "mine" },
  })
}

///|
async fn qa_fixture_relay(
  config : Config,
  path : String,
  body : Json?,
  fetch~ : async (String, Json?) -> Json,
) -> Json {
  cowork_relay_with(
    config,
    path,
    body,
    load_keys=() => bound_cowork_keys(config),
    save_key=key => register_cowork_key(config, key),
    fetch~,
  )
}

///|
async test "Q&A canonical key survives temp-workspace host reload without touching run metadata" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="moonfind-qa-readback"),
  )
  qa_fixture_workspace(config)
  let run_before = @fs.read_file(run_artifact(config, "run.json")).text()
  let workspace_before = @fs.read_file(run_artifact(config, "workspace.json")).text()
  let calls : Array[(String, Json?)] = []
  async fn fetch(path : String, body : Json?) -> Json {
    calls.push((path, body))
    if path == "/v1/cowork/sessions" {
      assert_eq(
        body,
        Some({
          "cwd": config.book_workspace,
          "title": "MoonFind Q&A: exact topic",
        }),
      )
      assert_true(@fs.exists(run_artifact(config, "qa-session-intent.json")))
    } else {
      assert_eq(path, "/v1/cowork/sessions/cowork:canonical-qa")
      assert_true(body is None)
    }
    qa_session_reply("cowork:canonical-qa", config.book_workspace)
  }
  let first = qa_fixture_relay(
    config,
    "/v1/cowork/sessions",
    Some(qa_create_payload(config)),
    fetch~,
  )
  let snapshot = workspace_snapshot_with({ ..config, }, gateway_reachable=_ => {
    true
  })
  assert_eq(snapshot.qa_cowork_session_key, Some("cowork:canonical-qa"))
  assert_eq(snapshot.qa_agent_status, "retained")
  assert_eq(snapshot.moonclaw_gateway_base, Some("/api/v1/cowork-gateway"))
  assert_eq(calls.length(), 1)
  let readback = qa_fixture_relay(
    config,
    "/v1/cowork/sessions/cowork:canonical-qa",
    None,
    fetch~,
  )
  assert_eq(readback, first)
  let repeated = qa_fixture_relay(
    config,
    "/v1/cowork/sessions",
    Some(qa_create_payload(config)),
    fetch~,
  )
  assert_eq(repeated, first)
  assert_eq(calls.length(), 3)
  assert_eq(calls.filter(call => call.0 == "/v1/cowork/sessions").length(), 1)
  assert_eq(@fs.read_file(run_artifact(config, "run.json")).text(), run_before)
  assert_eq(
    @fs.read_file(run_artifact(config, "workspace.json")).text(),
    workspace_before,
  )
  for name in ["qa-session-intent.json", "qa-session.json"] {
    let text = @fs.read_file(run_artifact(config, name)).text()
    assert_false(text.contains("fixture-server-token"))
    assert_false(text.contains("exact query"))
  }
  assert_false(
    snapshot.to_json().stringify().contains("configured-cowork.invalid"),
  )
}

///|
async test "Q&A exact run Book workspace and gateway provenance isolate retained identifiers" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="moonfind-qa-scope"),
  )
  ignore(begin_qa_session_creation(config))
  retain_qa_session(config, "cowork:scope-qa")
  assert_eq(
    qa_session_retention({ ..config, run_id: "other-run", }),
    (None, "not-created"),
  )
  assert_eq(
    qa_session_retention({
      ..config,
      workspace: @fs.tmpdir(prefix="moonfind-qa-other-root"),
    }),
    (None, "not-created"),
  )
  for
    changed in [
      { ..config, book_workspace: "/other/book", },
      { ..config, moonclaw_gateway_base: Some("http://other-gateway.invalid"), },
      { ..config, moonclaw_gateway_base: None, },
    ] {
    assert_eq(qa_session_retention(changed), (None, "reconnect-required"))
    assert_false(bound_cowork_keys(changed).contains("cowork:scope-qa"))
    try begin_qa_session_creation(changed) catch {
      _ => ()
    } noraise {
      _ => fail("changed provenance was allowed to create")
    }
  }
  assert_eq(qa_session_retention(config), (Some("cowork:scope-qa"), "retained"))
}

///|
async test "old generic session records do not become Q&A records by guessing" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="moonfind-qa-legacy"),
  )
  register_cowork_key(config, "cowork:legacy")
  assert_eq(qa_session_retention(config), (None, "not-created"))
  assert_eq(bound_cowork_keys(config), ["cowork:legacy"])
  let calls = Ref(0)
  ignore(
    qa_fixture_relay(
      config,
      "/v1/cowork/sessions",
      Some({
        "cwd": config.book_workspace,
        "title": "MoonFind Q&A: legacy title",
      }),
      fetch=(_, _) => {
        calls.val += 1
        qa_session_reply("cowork:ordinary", config.book_workspace)
      },
    ),
  )
  assert_eq(calls.val, 1)
  assert_eq(qa_session_retention(config), (None, "not-created"))
  assert_false(@fs.exists(run_artifact(config, "qa-session-intent.json")))
}

///|
async test "failed or malformed creation remains uncertain across reload and repeated clicks" {
  for malformed in [false, true] {
    let config = model_route_config(
      workspace=@fs.tmpdir(prefix="moonfind-qa-uncertain"),
    )
    let calls = Ref(0)
    async fn fetch(_path : String, _body : Json?) -> Json {
      calls.val += 1
      if malformed {
        qa_session_reply("cowork:wrong-folder", "/other/book")
      } else {
        fail("lost response after upstream accepted creation")
      }
    }
    for _ in 0..<2 {
      try
        qa_fixture_relay(
          config,
          "/v1/cowork/sessions",
          Some(qa_create_payload(config)),
          fetch~,
        )
      catch {
        _ => ()
      } noraise {
        _ => fail("uncertain create unexpectedly succeeded")
      }
      assert_eq(
        qa_session_retention({ ..config, }),
        (None, "creation-uncertain"),
      )
    }
    assert_eq(calls.val, 1)
  }
}

///|
async test "pending Q&A creation rejects a simultaneous duplicate without another dispatch" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="moonfind-qa-duplicate"),
  )
  let calls = Ref(0)
  ignore(
    qa_fixture_relay(
      config,
      "/v1/cowork/sessions",
      Some(qa_create_payload(config)),
      fetch=(_, _) => {
        calls.val += 1
        try
          qa_fixture_relay(
            config,
            "/v1/cowork/sessions",
            Some(qa_create_payload(config)),
            fetch=(_, _) => {
              calls.val += 1
              fail("duplicate dispatched")
            },
          )
        catch {
          _ => ()
        } noraise {
          _ => fail("pending creation was not rejected")
        }
        qa_session_reply("cowork:only-once", config.book_workspace)
      },
    ),
  )
  assert_eq(calls.val, 1)
  assert_eq(
    qa_session_retention(config),
    (Some("cowork:only-once"), "retained"),
  )
}

///|
async test "concurrent Q&A create requests atomically claim one gateway dispatch" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="moonfind-qa-concurrent-create"),
  )
  let creates = Ref(0)
  let successful = Ref(0)
  @async.with_task_group(group => {
    for _ in 0..<3 {
      group.spawn_bg(() => {
        try
          qa_fixture_relay(
            config,
            "/v1/cowork/sessions",
            Some(qa_create_payload(config)),
            fetch=(path, _) => {
              if path == "/v1/cowork/sessions" {
                creates.val += 1
                @async.sleep(10)
              }
              qa_session_reply(
                "cowork:concurrent-canonical",
                config.book_workspace,
              )
            },
          )
        catch {
          _ => ()
        } noraise {
          _ => successful.val += 1
        }
      })
    }
  })
  assert_eq(creates.val, 1)
  assert_true(successful.val >= 1)
  assert_eq(
    qa_session_retention(config),
    (Some("cowork:concurrent-canonical"), "retained"),
  )
}

///|
async test "registration acknowledgement failure preserves canonical Q&A readback and safe retry" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="moonfind-qa-ack"),
  )
  let calls : Array[String] = []
  async fn fetch(path : String, _body : Json?) -> Json {
    calls.push(path)
    qa_session_reply("cowork:ack-lost", config.book_workspace)
  }
  try
    cowork_relay_with(
      config,
      "/v1/cowork/sessions",
      Some(qa_create_payload(config)),
      load_keys=() => bound_cowork_keys(config),
      save_key=_ => fail("registration write failed"),
      fetch~,
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("write failure should be visible")
  }
  assert_eq(qa_session_retention(config), (Some("cowork:ack-lost"), "retained"))
  assert_true(bound_cowork_keys(config).contains("cowork:ack-lost"))
  ignore(
    qa_fixture_relay(
      config,
      "/v1/cowork/sessions",
      Some(qa_create_payload(config)),
      fetch~,
    ),
  )
  assert_eq(calls, [
    "/v1/cowork/sessions", "/v1/cowork/sessions/cowork:ack-lost",
  ])
}

///|
async test "Q&A temporary acknowledgement can recover failed rename without inventing an identifier" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="moonfind-qa-temp-ack"),
  )
  ignore(begin_qa_session_creation(config))
  let value = qa_session_binding(config, "cowork:exact-recovered")
  @fs.write_file(
    run_artifact(config, "qa-session.json.pending"),
    value.stringify(),
    create_mode=CreateNew,
    sync=Full,
  )
  assert_eq(
    qa_session_retention(config),
    (Some("cowork:exact-recovered"), "retained"),
  )
  retain_qa_session(config, "cowork:exact-recovered")
  assert_false(@fs.exists(run_artifact(config, "qa-session.json.pending")))
  assert_eq(@store.read_json(run_artifact(config, "qa-session.json")), value)
  try retain_qa_session(config, "cowork:different") catch {
    _ => ()
  } noraise {
    _ => fail("existing session was overwritten")
  }
}

///|
async test "actual failed acknowledgement write leaves an uncertain intent without retrying creation" {
  // This simulates a write obstruction appearing only once dispatch begins.
  // The initial read must see no acknowledgement file at the creation claim.
  let calls = Ref(0)
  let clean = model_route_config(
    workspace=@fs.tmpdir(prefix="moonfind-qa-failed-ack-live"),
  )
  async fn fetch(_path : String, _body : Json?) -> Json {
    calls.val += 1
    @fs.mkdir(run_artifact(clean, "qa-session.json.pending"))
    qa_session_reply("cowork:created-but-write-failed", clean.book_workspace)
  }
  for _ in 0..<2 {
    try
      qa_fixture_relay(
        clean,
        "/v1/cowork/sessions",
        Some(qa_create_payload(clean)),
        fetch~,
      )
    catch {
      _ => ()
    } noraise {
      _ => fail("failed acknowledgement was accepted")
    }
  }
  assert_eq(calls.val, 1)
  assert_eq(qa_session_retention(clean), (None, "creation-uncertain"))
  assert_true(@fs.exists(run_artifact(clean, "qa-session-intent.json")))
  assert_false(@fs.exists(run_artifact(clean, "qa-session.json")))
}

///|
async test "unwritable or corrupt Q&A state does not dispatch or erase user files" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="moonfind-qa-bad-write"),
  )
  ensure_cowork_binding_directory(
    @store.run_directory(config.workspace, config.run_id),
  )
  let intent = run_artifact(config, "qa-session-intent.json")
  @fs.mkdir(intent)
  let calls = Ref(0)
  try
    qa_fixture_relay(
      config,
      "/v1/cowork/sessions",
      Some(qa_create_payload(config)),
      fetch=(_, _) => {
        calls.val += 1
        fail("should not dispatch")
      },
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("invalid state was ignored")
  }
  assert_eq(calls.val, 0)
  assert_eq(qa_session_retention(config), (None, "creation-uncertain"))
  let corrupt = model_route_config(
    workspace=@fs.tmpdir(prefix="moonfind-qa-corrupt"),
  )
  ensure_cowork_binding_directory(
    @store.run_directory(corrupt.workspace, corrupt.run_id),
  )
  @fs.write_file(
    run_artifact(corrupt, "qa-session-intent.json"),
    "{partial",
    create_mode=CreateNew,
  )
  assert_eq(qa_session_retention(corrupt), (None, "creation-uncertain"))
}

///|
async test "Q&A markers and credential-bearing provenance are rejected before durable writes or network" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="moonfind-qa-bad-scope"),
  )
  let payloads : Array[Json] = [
    {
      "moonfind_purpose": "qa",
      "moonfind_run_id": "other-run",
      "cwd": config.book_workspace,
    },
    {
      "moonfind_purpose": "qa",
      "moonfind_run_id": config.run_id,
      "cwd": "/other/book",
    },
    { "moonfind_run_id": config.run_id, "cwd": config.book_workspace },
  ]
  for payload in payloads {
    try
      qa_fixture_relay(config, "/v1/cowork/sessions", Some(payload), fetch=(
        _,
        _,
      ) => fail("must not dispatch"))
    catch {
      _ => ()
    } noraise {
      _ => fail("invalid marker accepted")
    }
  }
  assert_false(@fs.exists(run_artifact(config, "qa-session-intent.json")))
  for
    base in [
      "https://user:password@example.invalid", "https://example.invalid?token=secret",
      "https://example.invalid#secret",
    ] {
    let changed = { ..config, moonclaw_gateway_base: Some(base), }
    try begin_qa_session_creation(changed) catch {
      _ => ()
    } noraise {
      _ => fail("credential-bearing URL accepted")
    }
  }
  assert_false(@fs.exists(run_artifact(config, "qa-session-intent.json")))
}
