///|
fn continued_fixture_sheet() -> ChoiceWorksheet {
  let mut sheet = new_choice_sheet(evidence_workspace("continuity"))
  for
    edit in [
      SetOption("option-1", "name", "Pilot 学习 🌒"),
      SetOption("option-2", "name", "Wait"),
      SetOption("option-1", "source", "continuity:paper"),
      SetOption("option-1", "claim", "continuity:claim"),
      SetAssessment("option-1", 0, "Promising, unverified in our segment"),
      SetField("chosen", "option-1"),
      SetField("reasoning", "Learn before committing"),
      SetField("next", "Interview three buyers"),
      SetOption("option-1", "unknowns", "Willingness to pay"),
      SetField("commitment", "commitment-review-17"),
    ] {
    sheet = choice_edit(sheet, edit)
  }
  sheet
}

///|
fn continued_fixture_workspace() -> DurableResearchWorkspace {
  let before = evidence_workspace("continuity")
  let source = before.papers.unwrap()[0]
  let summary = before.summaries.unwrap()[0]
  {
    ..before,
    papers: Some([
      {
        ..source,
        versioned_id: "continuity:paper-v3",
        source_digest: "sha256:revised",
        retrieved_at: Some(1800000000000L),
        abstract_text: "Revised source text",
      },
      {
        ..source,
        paper_id: "added",
        versioned_id: "added-v1",
        source_digest: "sha256:added",
      },
    ]),
    summaries: Some([
      {
        ..summary,
        claims: [
          {
            ..summary.claims[0],
            statement: "Changed conclusion using the same claim ID",
            counterevidence: "Larger replication failed",
          },
        ],
      },
    ]),
  }
}

///|
test "continuation previews exact receipts and keeps authored direction while clearing reused source and claim IDs" {
  let before = continued_fixture_sheet()
  let workspace = continued_fixture_workspace()
  let changes = choice_deltas(before, choice_evidence(workspace))
  assert_true(
    changes.any(value => {
      value.kind == "Source" && value.status == "Added" && value.id == "added"
    }),
  )
  assert_true(
    changes.any(value => {
      value.kind == "Source" &&
      value.status == "Changed" &&
      value.before.contains("sha256:continuity") &&
      value.after.contains("sha256:revised")
    }),
  )
  assert_true(
    changes.any(value => {
      value.kind == "Claim" &&
      value.status == "Changed" &&
      value.affected_options == ["option-1"]
    }),
  )
  guard choice_continue(before, Some(workspace)) is Ok(next) else {
    fail("valid continuation blocked")
  }
  assert_eq(next.options[0].source_id, "")
  assert_eq(next.options[0].claim_id, "")
  assert_eq(
    next.options[0].retained_source.unwrap().source_digest,
    "sha256:continuity",
  )
  assert_eq(next.options[0].retained_claim.unwrap().statement, "Evidence claim")
  assert_eq(next.options[0].assessments, before.options[0].assessments)
  assert_eq(next.options[0].unknowns, before.options[0].unknowns)
  assert_eq(next.chosen_option_id, before.chosen_option_id)
  assert_eq(next.reasoning, before.reasoning)
  assert_eq(next.next_action, before.next_action)
  assert_eq(
    choice_unarchive(next.history.unwrap()[0]).to_json(),
    before.to_json(),
  )
  assert_eq(next.evidence.to_json(), choice_evidence(workspace).to_json())
  guard choice_decode(
      choice_export_json(next, true).stringify(),
      "run-continuity",
    )
    is Ok(restored) else {
    fail("continued backup failed")
  }
  assert_eq(restored.to_json(), next.to_json())
  let html = qa_test_render({
    ..initial_model(),
    workspace: Some(workspace),
    choices: { ..empty_choices(), sheet: Some(next), },
  })
  for
    phrase in [
      "Historical source", "Historical claim", "unresolved for this revision", "Download revision",
      "added-v1", "not been revalidated",
    ] {
    assert_true(html.contains(phrase), msg=phrase)
  }
  assert_true(choice_markdown(next, true).contains("sha256:continuity"))
  assert_true(
    choice_export_json(next, true)
    .stringify()
    .contains("not revalidated findings"),
  )
  let later_workspace = {
    ..workspace,
    query: "A further bounded research question",
  }
  guard choice_continue(next, Some(later_workspace)) is Ok(later) else {
    fail("second continuation")
  }
  assert_eq(later.history.unwrap().length(), 2)
  assert_eq(
    choice_version(later, later.history.unwrap()[1]).to_json(),
    next.to_json(),
  )
  assert_eq(
    choice_version(later, later.history.unwrap()[0]).to_json(),
    before.to_json(),
  )
}

///|
test "continuation handles removal empty evidence unchanged refs order and changed support with stable claim text" {
  let before = continued_fixture_sheet()
  let original = evidence_workspace("continuity")
  let removed = { ..original, papers: Some([]), summaries: Some([]), }
  let deltas = choice_deltas(before, choice_evidence(removed))
  assert_true(
    deltas.any(value => value.kind == "Source" && value.status == "Removed"),
  )
  assert_true(
    deltas.any(value => value.kind == "Claim" && value.status == "Removed"),
  )
  guard choice_continue(before, Some(removed)) is Ok(empty) else {
    fail("explicit empty projection must remain a valid removal")
  }
  assert_eq(empty.options[0].source_id, "")
  assert_eq(empty.options[0].claim_id, "")
  assert_true(empty.evidence.papers.is_empty())
  let add = {
    ..original,
    papers: Some(
      original.papers.unwrap() +
      [
        {
          ..original.papers.unwrap()[0],
          paper_id: "new",
          versioned_id: "new-v1",
        },
      ],
    ),
  }
  guard choice_continue(before, Some(add)) is Ok(added) else {
    fail("added source blocked")
  }
  assert_eq(added.options[0].source_id, before.options[0].source_id)
  assert_eq(added.options[0].claim_id, before.options[0].claim_id)
  let reverse = {
    ..add,
    papers: Some([add.papers.unwrap()[1], add.papers.unwrap()[0]]),
  }
  assert_true(choice_deltas(added, choice_evidence(reverse)).is_empty())
  assert_true(choice_current(added, Some(reverse)))
  assert_true(
    choice_export_json(added, choice_current(added, Some(reverse)))
    .stringify()
    .contains("Matches the currently loaded research projection"),
  )
  guard choice_continue(added, Some(reverse)) is Ok(same) else {
    fail("reorder blocked")
  }
  assert_eq(same.to_json(), added.to_json())
  let support = {
    ..original,
    papers: Some([
      { ..original.papers.unwrap()[0], source_digest: "sha256:new-support", },
    ]),
  }
  guard choice_continue(before, Some(support)) is Ok(supported) else {
    fail("changed support blocked")
  }
  assert_eq(supported.options[0].claim_id, "")
  assert_eq(
    supported.options[0].retained_claim.unwrap().statement,
    "Evidence claim",
  )
  let dangling = choice_edit(
    choice_edit(before, SetOption("option-1", "source", "missing-source")),
    SetOption("option-1", "claim", "missing-claim"),
  )
  guard choice_continue(dangling, Some(add)) is Ok(repaired) else {
    fail("unresolved reference continuation")
  }
  assert_eq(repaired.options[0].source_id, "")
  assert_eq(repaired.options[0].claim_id, "")
  assert_true(
    repaired.options[0].evidence_review_note.unwrap().contains("missing-source"),
  )
  assert_true(
    repaired.options[0].evidence_review_note.unwrap().contains("missing-claim"),
  )
  assert_eq(repaired.history.unwrap()[0].options[0].source_id, "missing-source")
}

///|
test "continuation rejects unavailable invalid duplicate and cross-run evidence without modifying the worksheet" {
  let sheet = continued_fixture_sheet()
  let current = evidence_workspace("continuity")
  let first = current.papers.unwrap()[0]
  let summary = current.summaries.unwrap()[0]
  for
    workspace in [
      None,
      Some({ ..current, papers: None, }),
      Some({ ..current, summaries: None, }),
      Some(evidence_workspace("another")),
      Some({ ..current, validation_issues: ["incomplete"], }),
      Some({ ..current, papers: Some([first, first]), }),
      Some({ ..current, papers: Some([{ ..first, source_digest: "", }]), }),
      Some({
        ..current,
        summaries: Some([{ ..summary, paper_id: "missing", }]),
      }),
      Some({
        ..current,
        summaries: Some([
          {
            ..summary,
            claims: [
              summary.claims[0],
              { ..summary.claims[0], statement: "conflict", },
            ],
          },
        ]),
      }),
    ] {
    assert_true(choice_continue(sheet, workspace) is Err(_))
  }
  assert_true(sheet.history is None)
}

///|
test "continuation bounds retained history without evicting older versions and legacy JSON restores" {
  let legacy = "{\"contract_id\":\"moonfind.choice-worksheet.v1\",\"revision\":1,\"next_option\":3,\"evidence\":{\"run_id\":\"legacy\",\"question\":\"Q\",\"papers\":[],\"summaries\":[]},\"question\":\"Q\",\"audience\":\"\",\"commitment_ref\":\"\",\"criteria\":[\"C\"],\"options\":[{\"id\":\"option-1\",\"name\":\"A\",\"assessments\":[\"\"],\"source_id\":\"\",\"claim_id\":\"\",\"contradiction\":\"\",\"unknowns\":\"\",\"cost_of_error\":\"\",\"experiment\":\"\"},{\"id\":\"option-2\",\"name\":\"B\",\"assessments\":[\"\"],\"source_id\":\"\",\"claim_id\":\"\",\"contradiction\":\"\",\"unknowns\":\"\",\"cost_of_error\":\"\",\"experiment\":\"\"}],\"chosen_option_id\":\"option-1\",\"reasoning\":\"R\",\"next_action\":\"N\"}"
  guard choice_decode(legacy, "legacy") is Ok(old) else {
    fail("pre-continuation backup rejected")
  }
  assert_true(old.history is None)
  assert_true(old.options[0].retained_source is None)
  let original = continued_fixture_sheet()
  let full = {
    ..original,
    revision: 100,
    history: Some(
      Array::make(20, choice_archive(original)).mapi((index, value) => {
        ..value,
        revision: index + 1,
      }),
    ),
  }
  assert_true(
    choice_continue(full, Some(continued_fixture_workspace())) is Err(error) &&
    error.contains("20 earlier versions"),
  )
  assert_eq(full.history.unwrap().length(), 20)
}

///|
test "continuation blocks overflow ambiguous history and an oversized portable envelope without discarding data" {
  let original = continued_fixture_sheet()
  let exhausted = { ..original, revision: 2147483647, }
  assert_true(
    choice_continue(exhausted, Some(continued_fixture_workspace()))
    is Err(error) &&
    error.contains("counter is exhausted"),
  )
  assert_eq(
    choice_edit(exhausted, SetField("next", "Overflow attempt")).to_json(),
    exhausted.to_json(),
  )
  let archive = choice_archive(original)
  for
    history in [
      [archive, archive],
      [{ ..archive, revision: archive.revision + 1, }, archive],
    ] {
    let invalid = { ..original, revision: 100, history: Some(history), }
    assert_true(
      choice_decode(invalid.to_json().stringify(), "run-continuity") is Err(_),
    )
  }
  guard choice_continue(original, Some(continued_fixture_workspace()))
    is Ok(base) else {
    fail("base continuation")
  }
  let padding = (2000000 - base.to_json().stringify().length()) / 2 +
    original.reasoning.length() -
    32
  let large = { ..original, reasoning: "x".repeat(padding), }
  let trial = {
    ..base,
    reasoning: large.reasoning,
    history: Some([choice_archive(large)]),
  }
  assert_true(trial.to_json().stringify().length() < 2000000)
  assert_true(
    choice_export_json(trial, false).stringify(indent=2).length() > 2000000,
  )
  assert_true(
    choice_decode(
      choice_export_json(large, false).stringify(indent=2),
      "run-continuity",
    )
    is Ok(_),
  )
  assert_true(
    choice_continue(large, Some(continued_fixture_workspace())) is Err(error) &&
    error.contains("backup size limit"),
  )
  assert_eq(large.reasoning.length(), padding)
  assert_true(large.history is None)
}

///|
fn continue_action(model : Model) -> ChoiceMsg {
  ContinueEvidence(
    model.choices.sheet.unwrap().revision,
    choice_evidence(model.workspace.unwrap()).to_json().stringify(),
  )
}

///|
test "continuation preview binding repeated clicks quota reload and workspace switching preserve exact history" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let start = choices_model("continuity")
  let original = continued_fixture_sheet()
  let initial = {
    ..start,
    choices: { ..start.choices, sheet: Some(original), },
    workspace: Some(continued_fixture_workspace()),
  }
  let click = continue_action(initial)
  let stale = update_choices(
    update_choices(initial, SetField("next", "New next action")),
    click,
  )
  assert_true(stale.choices.notice.contains("changed since this preview"))
  assert_true(stale.choices.sheet.unwrap().history is None)
  let changed_projection = update_choices(
    { ..initial, workspace: Some(evidence_workspace("continuity")), },
    click,
  )
  assert_true(changed_projection.choices.sheet.unwrap().history is None)
  let next = update_choices(initial, click)
  assert_eq(next.choices.sheet.unwrap().history.unwrap().length(), 1)
  let twice = update_choices(next, click)
  assert_eq(
    twice.choices.sheet.unwrap().to_json(),
    next.choices.sheet.unwrap().to_json(),
  )
  assert_eq(
    choices_model("continuity").choices.sheet.unwrap().to_json(),
    next.choices.sheet.unwrap().to_json(),
  )
  let away = sync_choices({
    ..next,
    workspace: Some(evidence_workspace("elsewhere")),
  })
  let back = sync_choices({
    ..away,
    workspace: Some(continued_fixture_workspace()),
  })
  assert_eq(
    back.choices.sheet.unwrap().to_json(),
    next.choices.sheet.unwrap().to_json(),
  )
  let another_book = sync_choices({ ..back, trusted_book_dir: "/another-book", })
  assert_true(another_book.choices.sheet.unwrap().history is None)
  set_choice_storage_mode("quota")
  let unsaved = update_choices(initial, click)
  assert_true(unsaved.choices.notice.contains("save failed"))
  assert_eq(
    unsaved.choices.sheet.unwrap().history.unwrap()[0].evidence.to_json(),
    original.evidence.to_json(),
  )
  let blocked = update_choices(
    { ..initial, choices: { ..initial.choices, save_blocked: true, }, },
    click,
  )
  assert_true(blocked.choices.sheet.unwrap().history is None)
}

///|
extern "js" fn continuation_fixture_requested() -> Bool =
  #| () => typeof process !== "undefined" && process.env.MOONFIND_CONTINUATION_FIXTURE === "1"

///|
fn refreshed_fixture_workspace() -> DurableResearchWorkspace {
  let current = evidence_workspace("continuity")
  {
    ..current,
    papers: Some([
      { ..current.papers.unwrap()[0], retrieved_at: Some(1800000000000L), },
    ]),
  }
}

///|
test "retrieval-only refresh archives exact receipts without forcing source or claim reselection" {
  let before = continued_fixture_sheet()
  let workspace = refreshed_fixture_workspace()
  let deltas = choice_deltas(before, choice_evidence(workspace))
  assert_eq(deltas.length(), 1)
  assert_eq(deltas[0].status, "Retrieval refreshed")
  guard choice_continue(before, Some(workspace)) is Ok(next) else {
    fail("receipt refresh")
  }
  assert_eq(next.options[0].source_id, before.options[0].source_id)
  assert_eq(next.options[0].claim_id, before.options[0].claim_id)
  assert_true(next.options[0].retained_source is None)
  assert_true(next.options[0].retained_claim is None)
  assert_eq(next.evidence.papers[0].retrieved_at, Some(1800000000000L))
  assert_eq(
    choice_version(next, next.history.unwrap()[0]).to_json(),
    before.to_json(),
  )
  assert_true(choice_current(next, Some(workspace)))
}

///|
test "actual continuation producer exports current changed and removed evidence for Proj" {
  let current = continued_fixture_sheet()
  guard choice_continue(current, Some(refreshed_fixture_workspace()))
    is Ok(refreshed) else {
    fail("refreshed fixture")
  }
  guard choice_continue(current, Some(continued_fixture_workspace()))
    is Ok(changed) else {
    fail("changed fixture")
  }
  guard choice_continue(
      current,
      Some({
        ..evidence_workspace("continuity"),
        papers: Some([]),
        summaries: Some([]),
      }),
    )
    is Ok(removed) else {
    fail("removed fixture")
  }
  for
    (name, sheet) in [
      ("current", current),
      ("changed", changed),
      ("removed", removed),
      ("refreshed", refreshed),
    ] {
    let json = choice_export_json(sheet, true).stringify()
    assert_true(choice_decode(json, "run-continuity") is Ok(_))
    if continuation_fixture_requested() {
      println("MOONFIND_CONTINUATION_" + name + "=" + json)
    }
  }
}
