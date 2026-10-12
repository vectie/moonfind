///|
extend ChoiceExperiment with ToJson::{to_json}

///|
fn experiment_fixture() -> ChoiceWorksheet {
  let mut sheet = new_choice_sheet(evidence_workspace("experiment"))
  for
    edit in [
      SetOption("option-1", "name", "Pilot 学习 🌒"),
      SetOption("option-1", "source", "experiment:paper"),
      SetOption("option-1", "claim", "experiment:claim"),
      SetOption(
        "option-1", "experiment", "Ask three buyers for a pilot commitment",
      ),
      SetOption("option-2", "name", "Wait for evidence"),
      SetField("chosen", "option-1"),
      SetField("reasoning", "Reduce uncertainty"),
      SetField("next", "Plan a small pilot"),
    ] {
    sheet = choice_edit(sheet, edit)
  }
  sheet
}

///|
fn experiment_do(
  sheet : ChoiceWorksheet,
  action : ExperimentMsg,
) -> ChoiceWorksheet {
  match experiment_change(sheet, action) {
    Ok(next) => next
    Err(error) => abort(error)
  }
}

///|
fn experiment_prepared() -> ChoiceWorksheet {
  let mut sheet = experiment_do(experiment_fixture(), Start("option-1"))
  for
    (field, value) in [
      ("hypothesis", "At least two of three buyers will commit to a pilot"),
      ("procedure", "Ask the same three questions in three interviews"),
      (
        "outcome", "Number of explicit pilot commitments out of three interviews",
      ),
      ("threshold", "Fewer than two commitments contradicts this hypothesis"),
      (
        "constraints", "One day; no purchase; stop if anyone declines the interview",
      ),
    ] {
    sheet = experiment_do(sheet, Edit("test-1", field, value))
  }
  experiment_do(sheet, Prepare("test-1"))
}

///|
test "experiment start requires an existing named source-bound option and preserves exact original snapshot" {
  let empty = new_choice_sheet(evidence_workspace("experiment"))
  assert_true(experiment_change(empty, Start("option-1")) is Err(_))
  let original = experiment_fixture()
  let no_source = choice_edit(
    original,
    SetOption("option-1", "source", "missing"),
  )
  assert_true(experiment_change(no_source, Start("option-1")) is Err(_))
  assert_true(experiment_change(original, Start("missing")) is Err(_))
  let invalid_claim = choice_edit(
    original,
    SetOption("option-1", "claim", "missing"),
  )
  assert_true(experiment_change(invalid_claim, Start("option-1")) is Err(_))
  let started = experiment_do(original, Start("option-1"))
  let card = started.experiments.unwrap()[0]
  assert_eq(card.origin_option.to_json(), original.options[0].to_json())
  assert_eq(card.origin_evidence.to_json(), original.evidence.to_json())
  assert_eq(card.origin_criteria, original.criteria)
  assert_eq(card.procedure, original.options[0].experiment)
  assert_eq(started.chosen_option_id, original.chosen_option_id)
  assert_eq(started.options[0].to_json(), original.options[0].to_json())
  assert_true(experiment_markdown(card).contains("DRAFT / not ready"))
}

///|
test "experiment plan requires five fields freezes separately and never executes or overwrites original" {
  let draft = experiment_do(experiment_fixture(), Start("option-1"))
  assert_true(experiment_change(draft, Prepare("test-1")) is Err(_))
  assert_true(experiment_change(draft, Record("test-1")) is Err(_))
  let prepared = experiment_prepared()
  let card = prepared.experiments.unwrap()[0]
  assert_true(card.prepared_revision is Some(_))
  assert_true(card.observation is None)
  let frozen = experiment_do(
    prepared,
    Edit("test-1", "threshold", "Rewrite threshold after the fact"),
  )
  assert_eq(frozen.to_json(), prepared.to_json())
  assert_eq(
    prepared.options[0].to_json(),
    experiment_fixture().options[0].to_json(),
  )
  let text = experiment_markdown(card)
  for
    phrase in [
      "Hypothesis", "Procedure", "Measurable outcome and units", "Disconfirming threshold",
      "Constraints and stop conditions", "sha256:experiment", "experiment:paper-v2",
      "Table 2", "No test is executed",
    ] {
    assert_true(text.contains(phrase), msg=phrase)
  }
}

///|
test "unknown incomplete and measured reports are explicitly user-reported and never automatically revise the choice" {
  for status in ["unknown", "incomplete", "measured"] {
    let mut sheet = experiment_prepared()
    sheet = experiment_do(sheet, Edit("test-1", "status", status))
    assert_true(experiment_change(sheet, Record("test-1")) is Err(_))
    sheet = experiment_do(
      sheet,
      Edit(
        "test-1", "notes", "Only one buyer was available; no generalizable conclusion",
      ),
    )
    if status == "measured" {
      assert_true(experiment_change(sheet, Record("test-1")) is Err(_))
      sheet = experiment_do(
        sheet,
        Edit(
          "test-1", "measurement", "1 commitment / 1 interview; remaining two unknown",
        ),
      )
    }
    let reported = experiment_do(sheet, Record("test-1"))
    assert_eq(reported.chosen_option_id, sheet.chosen_option_id)
    assert_eq(reported.reasoning, sheet.reasoning)
    assert_eq(reported.next_action, sheet.next_action)
    let card = reported.experiments.unwrap()[0]
    assert_eq(card.observation.unwrap().status, status)
    assert_true(card.decision is None)
    assert_eq(
      experiment_do(reported, Edit("test-1", "notes", "rewritten")).to_json(),
      reported.to_json(),
    )
    assert_true(experiment_change(reported, Record("test-1")) is Err(_))
    assert_true(
      experiment_markdown(card).contains("not independently verified"),
    )
  }
}

///|
test "explicit revision retains prior worksheet and before values without changing the original card evidence" {
  let prepared = experiment_prepared()
  assert_true(experiment_change(prepared, Revise("test-1")) is Err(_))
  let reported = experiment_do(
    experiment_do(
      prepared,
      Edit("test-1", "notes", "Unknown: interviews were postponed"),
    ),
    Record("test-1"),
  )
  assert_true(experiment_change(reported, Revise("test-1")) is Err(_))
  let mut draft = reported
  for
    (field, value) in [
      ("chosen", "option-2"),
      ("reasoning", "Wait: the evidence is still unknown"),
      ("next", "Reschedule the interviews"),
    ] {
    draft = experiment_do(draft, Edit("test-1", field, value))
  }
  assert_eq(draft.chosen_option_id, "option-1")
  let before = draft.to_json()
  let applied = experiment_do(draft, Revise("test-1"))
  assert_eq(applied.chosen_option_id, "option-2")
  assert_eq(choice_unarchive(applied.history.unwrap()[0]).to_json(), before)
  let card = applied.experiments.unwrap()[0]
  assert_eq(card.origin_evidence.to_json(), prepared.evidence.to_json())
  assert_eq(card.decision.unwrap().before_option_id, "option-1")
  assert_eq(card.decision.unwrap().before_reasoning, "Reduce uncertainty")
  assert_true(experiment_change(applied, Revise("test-1")) is Err(_))
  let later = choice_edit(applied, SetField("chosen", "option-1"))
  assert_eq(later.experiments.unwrap()[0].to_json(), card.to_json())
  guard choice_decode(
      choice_export_json(later, true).stringify(),
      "run-experiment",
    )
    is Ok(restored) else {
    fail("versioned backup did not restore")
  }
  assert_eq(restored.to_json(), later.to_json())
}

///|
test "experiment option edits source changes removals and repeated tests preserve separate original runs" {
  let original = experiment_prepared()
  let card = original.experiments.unwrap()[0]
  let edited = choice_edit(
    choice_edit(original, SetOption("option-1", "name", "Different pilot")),
    SetOption("option-1", "source", ""),
  )
  assert_eq(edited.experiments.unwrap()[0].to_json(), card.to_json())
  assert_true(
    experiment_context(card, edited, Some(evidence_workspace("experiment"))).contains(
      "Historical snapshot",
    ),
  )
  let workspace = evidence_workspace("experiment")
  let changed = {
    ..workspace,
    papers: Some([
      { ..workspace.papers.unwrap()[0], source_digest: "sha256:changed", },
    ]),
  }
  guard choice_continue(original, Some(changed)) is Ok(continued) else {
    fail("source continuation")
  }
  assert_eq(continued.experiments.unwrap()[0].to_json(), card.to_json())
  assert_true(
    experiment_context(card, continued, Some(changed)).contains(
      "Historical snapshot",
    ),
  )
  let second = experiment_do(original, Start("option-1"))
  assert_eq(second.experiments.unwrap().map(value => value.id), [
    "test-1", "test-2",
  ])
  assert_eq(second.experiments.unwrap()[0].to_json(), card.to_json())
  assert_true(second.experiments.unwrap()[1].prepared_revision is None)
  assert_true(second.experiments.unwrap()[1].observation is None)
}

///|
test "experiment legacy backups absent new fields restore and malformed versions or cross-run data fail closed" {
  let original = experiment_fixture()
  let legacy = original
    .to_json()
    .stringify()
    .replace(old="\"experiments\":null,", new="")
    .replace(old=",\"experiments\":null", new="")
  assert_false(legacy.contains("\"experiments\""))
  guard choice_decode(legacy, "run-experiment") is Ok(old) else {
    fail("old worksheet not restored")
  }
  assert_true(old.experiments is None)
  let current = experiment_prepared()
  let encoded = choice_export_json(current, true).stringify()
  assert_true(choice_decode(encoded, "other-run") is Err(_))
  assert_true(
    choice_decode(
      encoded.replace(
        old="moonfind.choice-experiment.v1",
        new="moonfind.choice-experiment.v99",
      ),
      "run-experiment",
    )
    is Err(_),
  )
  let card = current.experiments.unwrap()[0]
  let broken = {
    ..current,
    experiments: Some([
      {
        ..card,
        origin_evidence: { ..card.origin_evidence, run_id: "other-run", },
      },
    ]),
  }
  assert_true(
    choice_decode(broken.to_json().stringify(), "run-experiment") is Err(_),
  )
  let source_lost = {
    ..current,
    experiments: Some([
      { ..card, origin_evidence: { ..card.origin_evidence, papers: [], }, },
    ]),
  }
  assert_true(
    choice_decode(source_lost.to_json().stringify(), "run-experiment") is Err(_),
  )
}

///|
test "experiment bounded cards fields counters and history never silently discard work" {
  let mut sheet = experiment_fixture()
  for _ in 0..<12 {
    sheet = experiment_do(sheet, Start("option-1"))
  }
  assert_true(experiment_change(sheet, Start("option-1")) is Err(_))
  assert_eq(sheet.experiments.unwrap().length(), 12)
  assert_true(
    experiment_change(sheet, Edit("test-1", "hypothesis", "x".repeat(10001)))
    is Err(_),
  )
  assert_true(
    experiment_change({ ..sheet, revision: 2147483647, }, Start("option-1"))
    is Err(_),
  )
  let invalid = {
    ..sheet,
    experiments: Some(
      sheet.experiments.unwrap() + [sheet.experiments.unwrap()[0]],
    ),
  }
  assert_true(
    choice_decode(invalid.to_json().stringify(), "run-experiment") is Err(_),
  )
}

///|
test "experiment UI stale events from a prior revision run book or research snapshot cannot change current state" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let initial = {
    ..choices_model("experiment"),
    choices: {
      ..choices_model("experiment").choices,
      sheet: Some(experiment_fixture()),
    },
  }
  let start = experiment_action(
    initial,
    initial.choices.sheet.unwrap(),
    Start("option-1"),
  )
  let started = update_choices(initial, start)
  let replay = update_choices(started, start)
  assert_eq(
    replay.choices.sheet.unwrap().to_json(),
    started.choices.sheet.unwrap().to_json(),
  )
  assert_true(replay.choices.notice.contains("changed since this action"))
  let other = sync_choices({
    ..initial,
    workspace: Some(evidence_workspace("other")),
  })
  assert_eq(
    update_choices(other, start).choices.sheet.unwrap().to_json(),
    other.choices.sheet.unwrap().to_json(),
  )
  let book = sync_choices({ ..initial, trusted_book_dir: "/other-book", })
  assert_eq(
    update_choices(book, start).choices.sheet.unwrap().to_json(),
    book.choices.sheet.unwrap().to_json(),
  )
  let changed = {
    ..initial,
    workspace: Some({ ..evidence_workspace("experiment"), papers: Some([]), }),
  }
  assert_eq(
    update_choices(changed, start).choices.sheet.unwrap().to_json(),
    changed.choices.sheet.unwrap().to_json(),
  )
  let replaced = {
    ..initial,
    choices: {
      ..initial.choices,
      sheet: Some({
        ..initial.choices.sheet.unwrap(),
        reasoning: "Imported different worksheet with the same revision",
      }),
    },
  }
  assert_eq(
    update_choices(replaced, start).choices.sheet.unwrap().to_json(),
    replaced.choices.sheet.unwrap().to_json(),
  )
  let (_, stale_reply) = update(
    _ => @rabbita.none,
    WorkspaceLoaded(initial.workspace_generation - 1, Err("late reply")),
    started,
  )
  assert_eq(
    stale_reply.choices.sheet.unwrap().to_json(),
    started.choices.sheet.unwrap().to_json(),
  )
}

///|
test "experiment draft reload failures recovery and UI states are ordinary worksheet flows" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let initial = {
    ..choices_model("experiment"),
    choices: {
      ..choices_model("experiment").choices,
      sheet: Some(experiment_prepared()),
    },
  }
  let saved = update_choices(initial, Save)
  assert_eq(
    choices_model("experiment").choices.sheet.unwrap().to_json(),
    saved.choices.sheet.unwrap().to_json(),
  )
  set_choice_storage_mode("quota")
  let edited = update_choices(
    saved,
    experiment_action(
      saved,
      saved.choices.sheet.unwrap(),
      Edit("test-1", "notes", "Unsaved partial observation"),
    ),
  )
  assert_true(edited.choices.notice.contains("save failed"))
  let switched = sync_choices({
    ..edited,
    workspace: Some(evidence_workspace("other")),
  })
  let back = sync_choices({
    ..switched,
    workspace: Some(evidence_workspace("experiment")),
  })
  assert_eq(
    back.choices.sheet.unwrap().experiments.unwrap()[0].observation_notes,
    "Unsaved partial observation",
  )
  let bad_import = update_choices(
    update_choices(back, SetRecovery("{broken")),
    Restore,
  )
  assert_eq(
    bad_import.choices.sheet.unwrap().to_json(),
    back.choices.sheet.unwrap().to_json(),
  )
  let html = qa_test_render(edited)
  for
    phrase in [
      "source-bound-experiments", "Original option and source snapshot", "Frozen plan",
      "Measurement status", "Record my reported observations", "Download test plan",
      "MoonBook review", "MoonProj approval",
    ] {
    assert_true(html.contains(phrase), msg=phrase)
  }
  assert_false(html.contains("Apply my choice revision"))
}

///|
test "experiment revision and oversized edits stop at retention limits with the exact prior work intact" {
  let prepared = experiment_prepared()
  let reported = experiment_do(
    experiment_do(prepared, Edit("test-1", "notes", "Unknown: test postponed")),
    Record("test-1"),
  )
  let proposal = experiment_do(
    experiment_do(
      reported,
      Edit("test-1", "reasoning", "Wait for missing measurements"),
    ),
    Edit("test-1", "next", "Reschedule interviews"),
  )
  let archives = Array::makei(20, index => {
    ..choice_archive(experiment_fixture()),
    revision: index + 1,
  })
  let full = { ..proposal, revision: 100, history: Some(archives), }
  let before = full.to_json()
  assert_true(experiment_change(full, Revise("test-1")) is Err(_))
  assert_eq(full.to_json(), before)
  install_choice_storage("ok")
  defer restore_choice_storage()
  let initial = choices_model("experiment")
  let blocked = update_choices(initial, SetField("next", "x".repeat(2000001)))
  assert_eq(
    blocked.choices.sheet.unwrap().to_json(),
    initial.choices.sheet.unwrap().to_json(),
  )
  assert_true(blocked.choices.notice.contains("backup limit"))
}

///|
test "experiment reports on a removed alternative remain historical and revisions require a current option" {
  let original = choice_edit(experiment_fixture(), AddOption)
  let mut sheet = original
  for
    edit in [
      SetOption("option-3", "name", "Temporary pilot"),
      SetOption("option-3", "source", "experiment:paper"),
    ] {
    sheet = choice_edit(sheet, edit)
  }
  sheet = experiment_do(sheet, Start("option-3"))
  for
    field in ["hypothesis", "procedure", "outcome", "threshold", "constraints"] {
    sheet = experiment_do(sheet, Edit("test-1", field, "Recorded user plan"))
  }
  sheet = experiment_do(sheet, Prepare("test-1"))
  let origin = sheet.experiments.unwrap()[0].origin_option.to_json()
  sheet = choice_edit(sheet, RemoveOption("option-3"))
  sheet = experiment_do(
    experiment_do(
      sheet,
      Edit("test-1", "notes", "No observation; option was removed"),
    ),
    Record("test-1"),
  )
  for
    (field, value) in [
      ("chosen", "option-3"),
      ("reasoning", "Would choose removed option"),
      ("next", "Review current alternatives"),
    ] {
    sheet = experiment_do(sheet, Edit("test-1", field, value))
  }
  assert_true(experiment_change(sheet, Revise("test-1")) is Err(_))
  sheet = experiment_do(sheet, Edit("test-1", "chosen", ""))
  let revised = experiment_do(sheet, Revise("test-1"))
  assert_eq(revised.chosen_option_id, "")
  assert_eq(revised.experiments.unwrap()[0].origin_option.to_json(), origin)
  assert_true(
    choice_decode(revised.to_json().stringify(), "run-experiment") is Ok(_),
  )
}

///|
extern "js" fn experiment_fixture_requested() -> Bool =
  #| () => typeof process !== "undefined" && process.env.MOONFIND_EXPERIMENT_FIXTURE === "1"

///|
test "experiment production view and export fixtures retain explicit states and HTML escapes" {
  let prepared = experiment_prepared()
  let reported = experiment_do(
    experiment_do(
      prepared,
      Edit(
        "test-1", "notes", "Unknown: <script>alert(1)</script> interviews postponed",
      ),
    ),
    Record("test-1"),
  )
  let proposed = experiment_do(
    experiment_do(
      experiment_do(reported, Edit("test-1", "chosen", "option-2")),
      Edit(
        "test-1", "reasoning", "Wait for measurements rather than infer success",
      ),
    ),
    Edit("test-1", "next", "Reschedule the pilot"),
  )
  let revised = experiment_do(proposed, Revise("test-1"))
  let model = {
    ..initial_model(),
    workspace: Some(evidence_workspace("experiment")),
    choices: { ..empty_choices(), key: "fixture-only", sheet: Some(revised), },
  }
  let html = qa_test_render(model)
  assert_true(html.contains("Explicit choice revision retained"))
  assert_true(html.contains("unknown"))
  assert_true(html.contains("&lt;script&gt;"))
  assert_false(html.contains("<script>alert(1)</script>"))
  assert_false(html.contains("Apply my choice revision"))
  if experiment_fixture_requested() {
    let fixture : Json = {
      "contract_id": "moonfind.experiment-verification-fixture.v1",
      "worksheet": choice_export_json(revised, true),
      "markdown": experiment_markdown(revised.experiments.unwrap()[0]),
      "html": html,
      "prepared_html": qa_test_render({
        ..model,
        choices: { ..model.choices, sheet: Some(prepared), },
      }),
      "draft_html": qa_test_render({
        ..model,
        choices: {
          ..model.choices,
          sheet: Some(experiment_do(experiment_fixture(), Start("option-1"))),
        },
      }),
    }
    println("MOONFIND_EXPERIMENT_FIXTURE=" + fixture.stringify())
  }
}

///|
test "actual experiment UI command sequence produces no host provider Book or Proj request" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  install_route_http_fixture(false)
  defer restore_route_http_fixture()
  let initial = {
    ..choices_model("experiment"),
    choices: {
      ..choices_model("experiment").choices,
      sheet: Some(experiment_fixture()),
    },
  }
  let (cell, dispatch) = retained_harness(initial)
  for
    action in [
      Start("option-1"),
      Edit("test-1", "hypothesis", "Two of three buyers commit"),
      Edit("test-1", "procedure", "Interview three buyers"),
      Edit("test-1", "outcome", "Pilot commitments / 3 interviews"),
      Edit("test-1", "threshold", "Fewer than two commitments"),
      Edit("test-1", "constraints", "One day, stop on refusal"),
      Prepare("test-1"),
      Edit("test-1", "notes", "Unknown: buyers postponed"),
      Record("test-1"),
      Edit("test-1", "chosen", "option-2"),
      Edit("test-1", "reasoning", "Wait because measurements are missing"),
      Edit("test-1", "next", "Reschedule interviews"),
      Revise("test-1"),
    ] {
    let model = cell.val
    ignore(
      dispatch(
        EditChoices(
          experiment_action(model, model.choices.sheet.unwrap(), action),
        ),
      ),
    )
  }
  assert_eq(cell.val.choices.sheet.unwrap().chosen_option_id, "option-2")
  assert_eq(route_http_requests(), "[]")
  assert_eq(cell.val.workspace.unwrap().three_gap_state, "pending")
  assert_true(
    cell.val.choices.sheet.unwrap().experiments.unwrap()[0].decision is Some(_),
  )
}

///|
extern "js" fn experiment_download_fixture(fail_ : Bool) -> Unit =
  #| fail => {
  #|   const saved = {document:Object.getOwnPropertyDescriptor(globalThis,"document"),Blob:globalThis.Blob,create:URL.createObjectURL,revoke:URL.revokeObjectURL};
  #|   globalThis.__experimentDownloadSaved = saved;
  #|   globalThis.__experimentDownload = {name:"",content:"",clicked:false};
  #|   globalThis.Blob = class { constructor(parts) { this.content=parts.join(""); } };
  #|   URL.createObjectURL = blob => { if(fail) throw new Error("fixture-download-failure"); globalThis.__experimentDownload.content=blob.content; return "blob:fixture"; };
  #|   URL.revokeObjectURL = () => {};
  #|   Object.defineProperty(globalThis,"document",{configurable:true,value:{body:{appendChild(){}},createElement(){return {href:"",download:"",remove(){},click(){globalThis.__experimentDownload.name=this.download; globalThis.__experimentDownload.clicked=true;}};}}});
  #| }

///|
extern "js" fn experiment_download_readback() -> String =
  #| () => JSON.stringify(globalThis.__experimentDownload)

///|
extern "js" fn experiment_download_restore() -> Unit =
  #| () => { const old=globalThis.__experimentDownloadSaved; if(old.document) Object.defineProperty(globalThis,"document",old.document); else delete globalThis.document; globalThis.Blob=old.Blob; URL.createObjectURL=old.create; URL.revokeObjectURL=old.revoke; delete globalThis.__experimentDownloadSaved; delete globalThis.__experimentDownload; }

///|
test "experiment download invokes the production browser boundary with exact readable bytes and reports failure without mutation" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  for fail_ in [false, true] {
    let initial = {
      ..choices_model("experiment"),
      choices: {
        ..choices_model("experiment").choices,
        sheet: Some(experiment_prepared()),
      },
    }
    experiment_download_fixture(fail_)
    defer experiment_download_restore()
    let sheet = initial.choices.sheet.unwrap()
    let downloaded = update_choices(
      initial,
      experiment_action(initial, sheet, Download("test-1")),
    )
    assert_eq(downloaded.choices.sheet.unwrap().to_json(), sheet.to_json())
    if fail_ {
      assert_true(downloaded.choices.notice.contains("Download failed"))
    } else {
      guard @json.parse(experiment_download_readback())
        is {
          "name": String("moonfind-experiment-plan.md"),
          "content": String(content),
          "clicked": True,
          ..
        } else {
        fail("download boundary did not receive the plan")
      }
      assert_eq(
        content,
        experiment_markdown(sheet.experiments.unwrap()[0]) +
        "\nCurrent context: " +
        experiment_context(
          sheet.experiments.unwrap()[0],
          sheet,
          initial.workspace,
        ) +
        "\n",
      )
    }
  }
}
