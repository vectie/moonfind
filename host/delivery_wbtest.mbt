///|
fn delivery_fixture_run(run_id : String) -> @research.ResearchRun raise {
  let papers = ["source-a", "source-b"].map(id => @research.PaperRecord::{
    paper_id: id,
    versioned_id: id + "-v1",
    title: "Fixture " + id + " 比較 🌒",
    abstract_text: "Local permitted fixture text. Option A is faster; option B reports lower error.",
    authors: ["Fixture author"],
    categories: ["local"],
    published_at: "2026-10-04",
    updated_at: "2026-10-04",
    abs_url: "https://example.invalid/" + id,
    pdf_url: "https://example.invalid/" + id + ".pdf",
    source_digest: @store.digest_text(id),
    retrieved_at: 1L,
    relevance_score: 1,
    relevance_reasons: ["local test corpus"],
  })
  let initial = @research.start_research_run(
    run_id,
    {
      watch_id: "compare-options",
      title: "Fixture comparison 比較 🌒",
      query: "Which option merits the next test?",
      categories: ["local"],
      keywords: ["comparison"],
      negative_keywords: [],
      max_papers: 2,
      cadence: "once",
      domain_profile: "local-fixture",
    },
    papers,
    1L,
  )
  {
    ..initial,
    status: "human-review",
    summaries: [
      {
        paper_id: "source-a",
        one_sentence: "Option A reports faster execution.",
        problem: "Compare options",
        method: "Fixture only",
        evidence: "Local observation table",
        limitations: ["No customer evidence"],
        claims: [
          {
            claim_id: "claim-a",
            statement: "Option A was faster in the fixture.",
            paper_ids: ["source-a"],
            evidence_location: "row 2",
            confidence: "fixture-only",
            counterevidence: "Source B reports lower error.",
          },
        ],
        open_questions: ["Does it transfer?"],
      },
    ],
    questions: [
      {
        question_id: "q1",
        question: "What would change the recommendation?",
        source_paper_ids: ["source-a", "source-b"],
        missing_evidence: ["Matched real-world trial"],
        next_check: "Measure both on the same workload",
      },
    ],
    ideas: [
      {
        idea_id: "candidate-a",
        title: "Compare both",
        thesis: "Test A and B side by side.",
        mechanism: "Matched comparison",
        source_paper_ids: ["source-a", "source-b"],
        cross_paper_bridge: "Speed versus error",
        novelty_claim: "No novelty claim",
        counter_hypothesis: "The speed difference is workload-specific",
        risks: ["Wrong choice costs review time"],
        falsifier: "A loses its advantage on the matched trial",
        next_experiment: "Run one matched trial",
        domain_payload: { "api_key": "SHOULD-NOT-EXPORT-DOMAIN" },
      },
    ],
    synthesis_notes: ["Conflicting source reports remain unresolved."],
    validation_issues: ["No demand evidence"],
    completed_at: Some(2L),
  }
}

///|
async fn delivery_fixture(config : Config) -> DeliveryPrepareV1 {
  let run = delivery_fixture_run(config.run_id)
  let handoff = @moontown.cross_paper_handoff(run)
  let participant_ids = handoff.scenario.participants.map(p => p.book_id)
  let output : @moontown.TownSynthesisOutput = {
    contract_id: "civic.communication.output.v1",
    scenario_id: handoff.scenario.id,
    participant_book_ids: participant_ids,
    ideas: [
      {
        id: "idea-1",
        title: "Compare A and B 比較 🌒",
        summary: "A reports speed; B reports accuracy. This is unresolved.",
        participating_books: participant_ids,
        research_questions: ["Does A remain faster at equal accuracy?"],
        why_it_matters: "Choose a falsifying experiment",
        next_experiment: "One matched trial before any commitment",
      },
    ],
  }
  let receipt : @moontown.TownExecutionReceipt = {
    contract_version: @moontown.town_receipt_contract_version(),
    handoff_id: handoff.handoff_id,
    producer: "moonfind",
    producer_run_id: config.run_id,
    consumer: "moontown",
    scenario_id: handoff.scenario.id,
    round_id: "fixture-round",
    round_number: 1,
    status: "completed",
    reducer_kind: "moonclaw",
    participant_count: 2,
    reviewable_output_count: 1,
    review_status: "pending",
    building_book_id: handoff.scenario.building_book_id,
    artifact_refs: ["fixture/result.json", "fixture/review.json"],
    summary: "Deterministic fixture, no runtime call",
  }
  let key = @moontown.town_result_idempotency_key(config.run_id)
  @store.write_run_artifact(
    config.workspace,
    config.run_id,
    "run.json",
    run.to_json(),
  )
  @store.write_run_artifact(
    config.workspace,
    config.run_id,
    "moontown-handoff.json",
    handoff.to_json(),
  )
  ignore(
    ingest_moontown_result(config, {
      contract_id: "moonfind.moontown-result-ingest.v1",
      idempotency_key: key,
      handoff_id: handoff.handoff_id,
      producer_run_id: config.run_id,
      receipt,
      output,
      source: {
        "contract_id": "moontown.research-handoff-result-source.v1",
        "operation_ref": "moontown/civic.communication.synthesize@0.1.0",
        "request_ref": "fixture/request.json",
        "result_ref": "fixture/result.json",
        "receipt_ref": "fixture/receipt.json",
        "adapter_result": {
          "request_id": "request-" + handoff.handoff_id,
          "attempt_id": "attempt-1",
          "idempotency_key": key,
          "product_id": "moontown",
          "status": "succeeded",
        },
      },
    }),
  )
  {
    contract_id: "moonfind.delivery-prepare.v1",
    run_id: config.run_id,
    source_digest: @store.digest_text(
      @fs.read_file(run_artifact(config, "moontown-reducer-output.json")).text(),
    ),
  }
}

///|
async test "delivery produces openable exact files ZIP and unchanged human review from retained evidence" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="find-delivery-complete"),
  )
  let request = delivery_fixture(config)
  assert_eq(delivery_status(config).state, "not-prepared")
  assert_false(@fs.exists(delivery_root(config)))
  let before = @fs.read_file(run_artifact(config, "run.json")).binary()
  let status = prepare_delivery(config, request)
  assert_eq(status.state, "complete")
  let manifest = status.manifest.unwrap()
  assert_eq(manifest.files.length(), 3)
  for file in manifest.files {
    let bytes = read_delivery_file(config, manifest.delivery_id, file.name)
    assert_eq(bytes.length(), file.byte_count)
    assert_eq(@store.digest_text(@utf8.decode(bytes)), file.digest)
    assert_false(@utf8.decode(bytes).contains("fixture-server-token"))
    assert_false(@utf8.decode(bytes).contains("SHOULD-NOT-EXPORT-DOMAIN"))
    assert_false(@utf8.decode(bytes).contains("/trusted/book"))
  }
  let report = @utf8.decode(
    read_delivery_file(config, manifest.delivery_id, "report.md"),
  )
  for
    expected in [
      "比較 🌒", "source-a", "row 2", "Source B reports lower error", "Matched real-world trial",
      "A loses its advantage", "not new research", "not full-text review",
    ] {
    assert_true(report.contains(expected), msg=expected)
  }
  let zip = read_delivery_file(config, manifest.delivery_id, "package.zip")
  assert_eq(zip[0:4], b"PK\x03\x04")
  let zip_path = config.workspace + "/package.zip"
  @fs.write_file(zip_path, zip, create_mode=CreateNew)
  println("ZIP acceptance fixture: " + zip_path)
  assert_eq(
    prepare_delivery(config, request).manifest.unwrap().delivery_id,
    manifest.delivery_id,
  )
  assert_eq(delivery_status(config).versions, [manifest.delivery_id])
  assert_eq(@fs.read_file(run_artifact(config, "run.json")).binary(), before)
  let review = prepare_cross_product_review(config, {
    contract_id: "moonfind.review-prepare-request.v1",
    source_digest: Some(manifest.source_digest),
    reviewer_name: "Fixture reviewer",
    outcome: "approve_subset",
    accepted_idea_ids: ["idea-1"],
    rejected_idea_ids: [],
    rationale: "Accept the next test, not the claims as facts",
    information_gap: {
      present: true,
      severity: 1,
      summary: "No customer evidence",
    },
    recognition_gap: {
      present: false,
      severity: 0,
      summary: "Limits recognized",
    },
    decisiveness_gap: {
      present: true,
      severity: 1,
      summary: "Matched trial remains necessary",
    },
  })
  assert_eq(review.state, "awaiting-moonchat")
  assert_eq(review.source_digest, manifest.source_digest)
  assert_eq(delivery_status(config).state, "complete")
}

///|
async test "changed and missing files remain incomplete and explicit preparation cannot overwrite history" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="find-delivery-corruption"),
  )
  let request = delivery_fixture(config)
  let manifest = prepare_delivery(config, request).manifest.unwrap()
  let directory = delivery_directory(config, manifest.delivery_id)
  let original_report = read_delivery_file(
    config,
    manifest.delivery_id,
    "report.md",
  )
  @fs.write_file(
    directory + "/report.md",
    "changed",
    create_mode=TruncateExisting,
  )
  @fs.remove(directory + "/evidence.json")
  let status = delivery_status(config)
  assert_eq(status.state, "incomplete")
  assert_eq(status.issues.length(), 2)
  assert_true(
    try {
      ignore(read_delivery_file(config, manifest.delivery_id, "package.zip"))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(read_delivery_file(config, manifest.delivery_id, "report.md"))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    read_delivery_file(config, manifest.delivery_id, "synthesis.json").length() >
    0,
  )
  assert_eq(prepare_delivery(config, request).state, "incomplete")
  assert_eq(@fs.read_file(directory + "/report.md").text(), "changed")
  assert_false(@fs.exists(directory + "/evidence.json"))
  // A revised retained run produces a new immutable package without repairing
  // or replacing any bytes of the earlier version.
  let revised = {
    ..delivery_fixture_run(config.run_id),
    synthesis_notes: ["Revision: keep the contradiction and add a second trial"],
  }
  @store.write_run_artifact(
    config.workspace,
    config.run_id,
    "run.json",
    revised.to_json(),
  )
  let next = prepare_delivery(config, request)
  assert_eq(next.state, "complete")
  assert_true(next.manifest.unwrap().delivery_id != manifest.delivery_id)
  assert_eq(next.versions.length(), 2)
  assert_eq(
    delivery_status(config, delivery_id=manifest.delivery_id).state,
    "incomplete",
  )
  assert_true(original_report.length() > 0)
}

///|
async test "historical intact files remain readable after source change unavailable current source and reload" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="find-delivery-history"),
  )
  let request = delivery_fixture(config)
  let manifest = prepare_delivery(config, request).manifest.unwrap()
  let bytes = read_delivery_file(config, manifest.delivery_id, "evidence.json")
  let revised = {
    ..delivery_fixture_run(config.run_id),
    synthesis_notes: ["Revised retained note"],
  }
  @store.write_run_artifact(
    config.workspace,
    config.run_id,
    "run.json",
    revised.to_json(),
  )
  assert_eq(delivery_status(config).state, "stale")
  assert_eq(
    read_delivery_file(config, manifest.delivery_id, "evidence.json"),
    bytes,
  )
  let next = prepare_delivery(config, request).manifest.unwrap()
  assert_true(next.delivery_id != manifest.delivery_id)
  assert_eq(
    delivery_status(config).manifest.unwrap().delivery_id,
    next.delivery_id,
  )
  assert_eq(
    delivery_status(config, delivery_id=manifest.delivery_id).state,
    "stale",
  )
  @fs.write_file(
    run_artifact(config, "moontown-reducer-output.json"),
    "malformed",
    create_mode=TruncateExisting,
  )
  assert_eq(delivery_status(config).state, "stale")
  assert_true(
    read_delivery_file(config, manifest.delivery_id, "package.zip").length() > 0,
  )
  assert_true(
    try {
      ignore(prepare_delivery(config, request))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(
    read_delivery_file(config, manifest.delivery_id, "evidence.json"),
    bytes,
  )
}

///|
async test "delivery rejects stale context malformed manifests names and does not export unknown metadata" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="find-delivery-invalid"),
  )
  let request = delivery_fixture(config)
  assert_true(
    try {
      ignore(prepare_delivery(config, { ..request, run_id: "other-run", }))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(
        prepare_delivery(config, { ..request, source_digest: "sha256:stale", }),
      )
      false
    } catch {
      _ => true
    },
  )
  assert_false(@fs.exists(delivery_root(config)))
  let run_path = run_artifact(config, "run.json")
  guard @store.read_json(run_path) is Object(raw) else { fail("fixture") }
  raw["credentials"] = { "token": "UNKNOWN-SECRET" }
  @store.write_json(run_path, raw.to_json())
  let output_path = run_artifact(config, "moontown-reducer-output.json")
  guard @store.read_json(output_path) is Object(raw_output) else {
    fail("fixture")
  }
  raw_output["runtime_credentials"] = { "token": "UNKNOWN-SYNTHESIS-SECRET" }
  @store.write_json(output_path, raw_output.to_json())
  let manifest = prepare_delivery(config, {
    ..request,
    source_digest: @store.digest_text(@fs.read_file(output_path).text()),
  }).manifest.unwrap()
  assert_false(
    @utf8.decode(
      read_delivery_file(config, manifest.delivery_id, "evidence.json"),
    ).contains("UNKNOWN-SECRET"),
  )
  assert_false(
    @utf8.decode(
      read_delivery_file(config, manifest.delivery_id, "synthesis.json"),
    ).contains("UNKNOWN-SYNTHESIS-SECRET"),
  )
  for
    bad in [
      "../run.json", "report.md/../run.json", "", "秘密.json", "run.json", "report.md%00",
    ] {
    assert_true(
      try {
        ignore(read_delivery_file(config, manifest.delivery_id, bad))
        false
      } catch {
        _ => true
      },
      msg=bad,
    )
  }
  assert_eq(
    delivery_status(config, delivery_id="../run.json").state,
    "unavailable",
  )
  let path = delivery_directory(config, manifest.delivery_id) + "/manifest.json"
  guard @store.read_json(path) is Object(raw_manifest) else { fail("fixture") }
  raw_manifest["credentials"] = { "token": "MANIFEST-SECRET" }
  @store.write_json(path, raw_manifest.to_json())
  assert_eq(delivery_status(config).state, "unavailable")
  assert_true(
    try {
      ignore(read_delivery_file(config, manifest.delivery_id, "manifest.json"))
      false
    } catch {
      _ => true
    },
  )
  @fs.write_file(path, "{", create_mode=TruncateExisting)
  assert_eq(delivery_status(config).state, "unavailable")
  assert_true(
    try {
      ignore(read_delivery_file(config, manifest.delivery_id, "manifest.json"))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "stored ZIP handles Unicode contents empty entries and large data with standard CRC" {
  assert_eq(delivery_crc32(b"123456789"), 0xcbf43926U)
  assert_eq(delivery_crc32(b""), 0U)
  let text = "比較 🌒\n".repeat(20000)
  let bytes = @utf8.encode(text)
  let zip = delivery_zip([("report.md", bytes), ("empty.json", b"")])
  assert_true(zip.length() > bytes.length())
  assert_eq(zip[30 + 9:30 + 9 + bytes.length()], bytes[:])
  assert_eq(zip[zip.length() - 22:zip.length() - 18], b"PK\x05\x06")
}
