///|
extern "js" fn install_choice_storage(mode : String) -> Unit =
  #| mode => {
  #|   globalThis.__choice_old_storage = Object.getOwnPropertyDescriptor(globalThis,"localStorage");
  #|   globalThis.__choice_values = new Map(); globalThis.__choice_mode = mode;
  #|   Object.defineProperty(globalThis,"localStorage",{configurable:true,value:{
  #|     getItem(key) { if (globalThis.__choice_mode === "read-error") throw new Error("read"); return globalThis.__choice_values.get(key) ?? null; },
  #|     setItem(key,value) { if (globalThis.__choice_mode === "quota") throw new Error("quota"); globalThis.__choice_values.set(key,value); }
  #|   }});
  #| }

///|
extern "js" fn restore_choice_storage() -> Unit =
  #| () => {
  #|   if (globalThis.__choice_old_storage) Object.defineProperty(globalThis,"localStorage",globalThis.__choice_old_storage);
  #|   else delete globalThis.localStorage;
  #|   delete globalThis.__choice_old_storage; delete globalThis.__choice_values; delete globalThis.__choice_mode;
  #| }

///|
extern "js" fn set_choice_storage_mode(mode : String) -> Unit =
  #| mode => { globalThis.__choice_mode = mode; }

///|
fn choices_model(topic : String) -> Model {
  sync_choices({
    ..initial_model(),
    workspace: Some(evidence_workspace(topic)),
    trusted_book_dir: "/choices-book",
  })
}

///|
test "choice worksheet retains option identity citations and criteria without ranking unknowns" {
  let initial = new_choice_sheet(evidence_workspace("topic"))
  assert_eq(initial.options.length(), 2)
  assert_eq(initial.chosen_option_id, "")
  let cited = choice_edit(
    choice_edit(initial, SetOption("option-1", "source", "topic:paper")),
    SetOption("option-1", "claim", "topic:claim"),
  )
  let renamed = choice_edit(
    choice_edit(cited, SetOption("option-1", "name", "Pilot 学习 🌒")),
    SetCriterion(0, "Can we learn within one week?"),
  )
  assert_eq(renamed.options[0].source_id, "topic:paper")
  assert_eq(renamed.options[0].claim_id, "topic:claim")
  assert_eq(renamed.options[0].assessments[0], "")
  assert_eq(renamed.chosen_option_id, "")
  let four = choice_edit(choice_edit(renamed, AddOption), AddOption)
  assert_eq(choice_edit(four, AddOption).options.length(), 4)
  let mut six = four
  for _ in 0..<8 {
    six = choice_edit(six, AddCriterion)
  }
  assert_eq(six.criteria.length(), 6)
  assert_true(six.options.all(value => value.assessments.length() == 6))
  let chosen = choice_edit(six, SetField("chosen", "option-3"))
  assert_eq(choice_edit(chosen, RemoveOption("option-3")).chosen_option_id, "")
}

///|
test "decision brief exports complete direction dated sources disagreements and own JSON restores exactly" {
  let workspace = evidence_workspace("topic")
  let paper = {
    ..workspace.papers.unwrap()[0],
    published_at: Some("2026-09-12"),
    updated_at: Some("2026-09-14"),
    retrieved_at: Some(1790000000000L),
  }
  let initial = new_choice_sheet({ ..workspace, papers: Some([paper]), })
  let edits = [
    SetOption("option-1", "name", "Test local demand"),
    SetOption("option-2", "name", "Wait for more evidence"),
    SetOption("option-1", "source", "topic:paper"),
    SetOption("option-1", "claim", "topic:claim"),
    SetAssessment("option-1", 0, "Promising but unsupported for our segment"),
    SetOption("option-1", "contradiction", "Customer interviews disagree"),
    SetOption("option-1", "unknowns", "Willingness to pay"),
    SetOption("option-1", "cost", "One day of founder time"),
    SetOption("option-1", "experiment", "Ask three buyers to commit to a pilot"),
    SetField("commitment", "proj-commitment-17"),
    SetField("chosen", "option-1"),
    SetField("reasoning", "Lower-cost way to reduce uncertainty"),
    SetField("next", "Prepare the interview brief"),
  ]
  let mut sheet = initial
  for action in edits {
    sheet = choice_edit(sheet, action)
  }
  let encoded = choice_export_json(sheet, true).stringify()
  assert_true(encoded.contains("\"retrieved_at\":\"1790000000000\""))
  guard choice_decode(encoded, sheet.evidence.run_id) is Ok(restored) else {
    fail("own exported brief did not restore")
  }
  assert_eq(restored.to_json(), sheet.to_json())
  let markdown = choice_markdown(sheet, true)
  for
    retained in [
      "Test local demand", "proj-commitment-17", "Lower-cost way", "Prepare the interview brief",
      "2026-09-12", "2026-09-14", "1790000000000", "topic:paper-v2", "sha256:topic",
      "Table 2", "Replication missing", "Small sample", "Customer interviews disagree",
      "Willingness to pay", "One day of founder time", "three buyers", "Unknown / not recorded",
    ] {
    assert_true(markdown.contains(retained), msg=retained)
  }
  assert_true(choice_decode(encoded, "wrong-run") is Err(_))
  assert_false(encoded.contains("/choices-book"))
}

///|
test "source changes keep historical references and chosen direction across save reload" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let initial = choices_model("first")
  let edited = update_choices(
    update_choices(initial, SetOption("option-1", "source", "first:paper")),
    SetField("chosen", "option-2"),
  )
  let reloaded = choices_model("first")
  assert_eq(
    reloaded.choices.sheet.unwrap().to_json(),
    edited.choices.sheet.unwrap().to_json(),
  )
  let workspace = evidence_workspace("first")
  let changed = sync_choices({
    ..reloaded,
    workspace: Some({ ..workspace, papers: Some([]), }),
  })
  assert_false(
    choice_current(changed.choices.sheet.unwrap(), changed.workspace),
  )
  assert_eq(changed.choices.sheet.unwrap().options[0].source_id, "first:paper")
  assert_eq(changed.choices.sheet.unwrap().chosen_option_id, "option-2")
  let html = qa_test_render(changed)
  assert_true(html.contains("changed, removed or unavailable"))
  assert_true(html.contains("first:paper-v2"))
  assert_true(
    choice_markdown(changed.choices.sheet.unwrap(), false).contains(
      "Historical or unavailable",
    ),
  )
}

///|
test "failed autosave and read errors retain independent drafts when runs or books change" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let initial = choices_model("first")
  set_choice_storage_mode("quota")
  let edited = update_choices(initial, SetField("next", "Unsaved next action"))
  assert_true(edited.choices.notice.contains("save failed"))
  let other = sync_choices({
    ..edited,
    workspace: Some(evidence_workspace("second")),
  })
  let back = sync_choices({
    ..other,
    workspace: Some(evidence_workspace("first")),
  })
  assert_eq(back.choices.sheet.unwrap().next_action, "Unsaved next action")
  let other_book = sync_choices({ ..back, trusted_book_dir: "/another-book", })
  assert_eq(other_book.choices.sheet.unwrap().next_action, "")
  let original_book = sync_choices({
    ..other_book,
    trusted_book_dir: "/choices-book",
  })
  assert_eq(
    original_book.choices.sheet.unwrap().next_action,
    "Unsaved next action",
  )
  set_choice_storage_mode("ok")
  let saved = update_choices(original_book, Save)
  assert_true(saved.choices.notice.contains("Saved revision"))
  assert_eq(
    choices_model("first").choices.sheet.unwrap().next_action,
    "Unsaved next action",
  )
  set_choice_storage_mode("read-error")
  let held = choices_model("blocked")
  assert_true(held.choices.save_blocked)
  let edit = update_choices(
    held,
    SetField("reasoning", "Retain despite unreadable storage"),
  )
  let switched = sync_choices({
    ..edit,
    workspace: Some(evidence_workspace("other")),
  })
  let retained = sync_choices({
    ..switched,
    workspace: Some(evidence_workspace("blocked")),
  })
  assert_eq(
    retained.choices.sheet.unwrap().reasoning,
    "Retain despite unreadable storage",
  )
  assert_true(retained.choices.save_blocked)
}

///|
test "restore validates shape preserves failed input and uses exported envelope" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let initial = choices_model("topic")
  let edited = update_choices(initial, SetField("next", "Keep this action"))
  let broken = update_choices(
    update_choices(edited, SetRecovery("{broken")),
    Restore,
  )
  assert_eq(broken.choices.sheet.unwrap().next_action, "Keep this action")
  assert_eq(broken.choices.recovery_input, "{broken")
  let backup = choice_export_json(
    choice_edit(
      initial.choices.sheet.unwrap(),
      SetField("next", "Restored action"),
    ),
    true,
  ).stringify()
  let restored = update_choices(
    update_choices(broken, SetRecovery(backup)),
    Restore,
  )
  assert_eq(restored.choices.sheet.unwrap().next_action, "Restored action")
  assert_eq(
    choices_model("topic").choices.sheet.unwrap().next_action,
    "Restored action",
  )
}

///|
test "comparison controls render accessible source uncertainty choice and export actions" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = choices_model("topic")
  let html = qa_test_render(model)
  for
    label in [
      "evidence-choice-worksheet", "Decision question", "Option name", "Criterion 1",
      "Assessment", "Strongest source", "Retained analysis claim", "Contradiction",
      "Unknowns", "Cost of being wrong", "Smallest falsifying experiment", "Chosen option (optional)",
      "Why this option?", "Next action", "Download decision brief", "Download JSON brief",
      "No automatic ranking",
    ] {
    assert_true(html.contains(label), msg=label)
  }
  let dangerous = update_choices(
    model,
    SetOption("option-1", "name", "<script>alert(1)</script>"),
  )
  assert_false(qa_test_render(dangerous).contains("<script>alert(1)</script>"))
  assert_true(qa_test_render(dangerous).contains("&lt;script&gt;"))
}

///|
test "restored option allocation cannot produce future collisions or an unreadable own export" {
  let original = new_choice_sheet(evidence_workspace("ids"))
  let invalid = {
    ..original,
    options: [original.options[0], { ..original.options[1], id: "option-4", }],
    next_option: 3,
  }
  assert_true(choice_decode(invalid.to_json().stringify(), "run-ids") is Err(_))
  let valid = { ..invalid, next_option: 5, }
  guard choice_decode(valid.to_json().stringify(), "run-ids") is Ok(restored) else {
    fail("valid restored ID allocation rejected")
  }
  let added = choice_edit(choice_edit(restored, AddOption), AddOption)
  assert_eq(added.options.map(value => value.id), [
    "option-1", "option-4", "option-5", "option-6",
  ])
  guard choice_decode(choice_export_json(added, true).stringify(), "run-ids")
    is Ok(reloaded) else {
    fail("newly exported imported worksheet became unreadable")
  }
  assert_eq(added.to_json(), reloaded.to_json())
  let exhausted = { ..original, next_option: 1000000, }
  assert_eq(choice_edit(exhausted, AddOption).to_json(), exhausted.to_json())
  assert_true(
    choice_decode(exhausted.to_json().stringify(), "run-ids") is Ok(_),
  )
}
