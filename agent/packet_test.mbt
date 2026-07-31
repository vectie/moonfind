///|
fn responsibility_command() -> MoonClawResearchCommand {
  {
    protocol: "moonclaw.mooncode.v1",
    session_id: "moonfind-test",
    book_root: "/tmp/book",
    command: "prompt",
    model: "gpt-5.6-sol",
    capability_scope_id: "moonfind.humanoid.synthesis",
    capability_participant_id: "participant-1",
    text: "analyze evidence",
    packet: {
      "product_id": "moonfind",
      "required_review": "named-human",
      "owner_route": "moonfind.humanoid-models",
    },
  }
}

///|
test "research command delegates a bounded model loop without ownership transfer" {
  assert_true(
    research_command_responsibility_issues(responsibility_command()).is_empty(),
  )
  let wrong_model = { ..responsibility_command(), model: "gpt-5.4" }
  assert_false(research_command_responsibility_issues(wrong_model).is_empty())
  let self_approving = {
    ..responsibility_command(),
    packet: {
      "product_id": "moonfind",
      "required_review": "agent",
      "owner_route": "moonfind.humanoid-models",
      "capability_activation": "full",
    },
  }
  assert_false(
    research_command_responsibility_issues(self_approving).is_empty(),
  )
}

///|
fn ready_local_ledger() -> @research.LocalInputCoverageLedger {
  {
    contract_version: @research.local_input_coverage_contract_version(),
    ledger_id: "ledger-ready",
    source_label: "private-local-corpus",
    expected_input_count: 1,
    inputs: [
      {
        input_id: "page-2",
        relative_path: "pages/page-2.jpg",
        source_digest: "sha256:page-2",
        byte_length: 100L,
        media_type: "image/jpeg",
        sequence_number: 2,
        status: @research.LocalInputStatus::Used,
        extraction_artifact: Some("raw/extracted/page-2.md"),
        evidence_anchors: ["page:2"],
        provenance_ref: "local-import:page-2",
        duplicate_of: None,
        failure_reason: None,
      },
    ],
    known_missing_inputs: ["page-1"],
    created_at: 1L,
    updated_at: 2L,
  }
}

///|
test "local corpus command binds ready coverage without transferring review" {
  let command = prepare_local_corpus_analysis_command(
    ready_local_ledger(),
    "/tmp/book",
    "participant-1",
    "What claims survive cross-validation?",
    "iteration-1",
  )
  assert_true(local_corpus_command_responsibility_issues(command).is_empty())
  assert_eq(command.capability_scope_id, "moonfind.local-corpus.research")
  assert_true(command.packet.stringify().contains("\"known_missing_inputs\""))
  let blocked = {
    ..ready_local_ledger(),
    inputs: [
      {
        ..ready_local_ledger().inputs[0],
        status: @research.LocalInputStatus::Failed,
        extraction_artifact: None,
        evidence_anchors: [],
        failure_reason: Some("unreadable"),
      },
    ],
  }
  let rejected = try {
    ignore(
      prepare_local_corpus_analysis_command(
        blocked, "/tmp/book", "participant-1", "What claims survive cross-validation?",
        "iteration-1",
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "book Q&A is stable, cited and read-only by contract" {
  let command = prepare_book_qa_command(
    "deepseek-research",
    "/tmp/deepseek-research",
    "operator-1",
    "pending-review",
    ["wiki/synthesis/report.md", "records/local-input-coverage/ledger.json"],
    "Which technical claims are independently corroborated?",
  )
  assert_eq(command.session_id, "moonfind-deepseek-research-qa")
  assert_true(book_qa_command_responsibility_issues(command).is_empty())
  let mutating = {
    ..command,
    packet: {
      "product_id": "moonfind",
      "required_review": "named-human",
      "owner_route": "moonfind.reviewed-book-qa",
      "read_only": false,
      "web_update_policy": "merge-silently",
      "persistence_policy": "direct-write",
    },
  }
  assert_false(book_qa_command_responsibility_issues(mutating).is_empty())
}
