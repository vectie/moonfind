///|
test "reviewer offline same brief ID collision is explicit historical context not native match" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let first = offline_fixture_basis()
  let edited = offline_apply(
    offline_started(first),
    SetField("reasoning", "Same-origin prior comparison"),
  )
  let other_workspace = offline_fixture_basis(version='b')
  let reopened = offline_started(other_workspace)
  assert_eq(reopened.offline_choices.key, edited.offline_choices.key)
  assert_eq(
    reopened.offline_choices.sheet.unwrap().current.reasoning,
    "Same-origin prior comparison",
  )
  assert_false(
    offline_current(reopened, reopened.offline_choices.sheet.unwrap()),
  )
  assert_eq(
    reopened.offline_choices.sheet.unwrap().current.basis.revision_id,
    first.revision_id,
  )
}

///|
test "reviewer offline historical citations require exact earlier selected option and bytes" {
  let basis = offline_fixture_basis()
  let selected = offline_edit(
    new_offline_sheet(basis),
    SetOption("option-1", "source", "source-1"),
  )
  let next = offline_continue(selected, offline_fixture_basis(version='b')).unwrap()
  let citation = next.current.options[0].historical_source.unwrap()
  for
    bad in [
      { ..citation, capture: { ..citation.capture, content_hex: "78", }, },
      { ..citation, source: { ..citation.source, origin: "Forged origin", }, },
      { ..citation, revision_id: "revision-" + String::make(64, 'c'), },
    ] {
    let broken = {
      ..next,
      current: {
        ..next.current,
        options: next.current.options.mapi((i, item) => {
          if i == 0 {
            { ..item, historical_source: Some(bad), }
          } else {
            item
          }
        }),
      },
    }
    assert_true(
      offline_decode(broken.to_json().stringify(), basis.brief.brief_id)
      is Err(_),
    )
  }
  let no_selection = {
    ..next,
    history: [
      {
        ..next.history[0],
        options: next.history[0].options.map(item => {
          ..item,
          source_slot: "",
        }),
      },
    ],
  }
  assert_true(
    offline_decode(no_selection.to_json().stringify(), basis.brief.brief_id)
    is Err(_),
  )
}

///|
test "reviewer offline retained BOM CRLF Unicode bytes and zero assessment survive JSON" {
  let first = offline_fixture_basis()
  let hex = "efbbbf30e69c88f09f8c920d0a"
  let basis = {
    ..first,
    brief: {
      ..first.brief,
      sources: [{ ..first.brief.sources[0], content_hex: hex, }],
    },
    sources: [{ ..first.sources[0], byte_count: hex.length() / 2, }],
  }
  assert_eq(offline_basis_issue(basis), "")
  let sheet = offline_edit(
    new_offline_sheet(basis),
    SetAssessment("option-1", 0, "0"),
  )
  let restored = offline_decode(
    offline_export_json(sheet, false).stringify(),
    basis.brief.brief_id,
  ).unwrap()
  assert_eq(restored.current.basis.brief.sources[0].content_hex, hex)
  assert_eq(restored.current.options[0].assessments[0], "0")
  assert_true(offline_markdown(restored, false).contains("User assessment: 0"))
  assert_true(
    offline_markdown(restored, false).contains("Unknown / not recorded"),
  )
  for bad_hex in ["ff", "00", "0", "GG", "e08080"] {
    let bad = {
      ..basis,
      brief: {
        ..basis.brief,
        sources: [{ ..basis.brief.sources[0], content_hex: bad_hex, }],
      },
      sources: [{ ..basis.sources[0], byte_count: bad_hex.length() / 2, }],
    }
    assert_false(offline_basis_issue(bad) == "")
  }
}

///|
test "reviewer offline continuation preserves removed and repeatedly unresolved selected source" {
  let first = offline_fixture_basis()
  let two = {
    ..first,
    brief: {
      ..first.brief,
      sources: first.brief.sources + first.brief.sources,
    },
    sources: first.sources +
    [{ ..first.sources[0], slot: 2, archive_path: "sources/source-2.txt", }],
  }
  let selected = offline_edit(
    new_offline_sheet(two),
    SetOption("option-1", "source", "source-2"),
  )
  let next = offline_continue(selected, offline_fixture_basis(version='b')).unwrap()
  assert_eq(next.current.options[0].source_slot, "")
  assert_eq(next.current.options[0].historical_source.unwrap().source.slot, 2)
  let third = offline_continue(next, offline_fixture_basis(version='c')).unwrap()
  assert_eq(
    third.current.options[0].historical_source.unwrap().revision_id,
    first.revision_id,
  )
  assert_true(
    offline_decode(third.to_json().stringify(), first.brief.brief_id) is Ok(_),
  )
}

///|
test "reviewer offline twenty history and complete backup edit limits preserve prior value" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let first = offline_fixture_basis()
  let mut sheet = new_offline_sheet(first)
  assert_true(
    offline_continue(sheet, {
      ..first,
      brief: { ..first.brief, objective: "Conflicting immutable identity", },
    })
    is Err(_),
  )
  for i in 0..<20 {
    let number = i.to_string()
    let basis = {
      ..first,
      revision_id: "revision-" +
      String::make(64 - number.length(), '0') +
      number,
      brief: { ..first.brief, objective: "Saved objective \{i}", },
    }
    sheet = offline_continue(sheet, basis).unwrap()
  }
  assert_eq(sheet.history.length(), 20)
  assert_true(
    offline_continue(sheet, offline_fixture_basis(version='b')) is Err(_),
  )
  assert_true(
    offline_decode(sheet.to_json().stringify(), first.brief.brief_id) is Ok(_),
  )
  let started = offline_started(first)
  let oversized = offline_apply(
    started,
    SetField("reasoning", String::make(2000000, 'x')),
  )
  assert_eq(
    oversized.offline_choices.sheet.unwrap().to_json(),
    started.offline_choices.sheet.unwrap().to_json(),
  )
  assert_true(oversized.offline_choices.notice.contains("limit"))
}

///|
test "reviewer offline stale revision edits exports and restores are inert" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let basis = offline_fixture_basis()
  let first = offline_started(basis)
  let edited = offline_apply(first, SetField("reasoning", "Fresh value"))
  let revision = first.offline_choices.sheet.unwrap().current.revision
  for action in [SetField("reasoning", "Stale"), Export("json"), Restore, Save] {
    let stale = update_offline_choices(
      edited,
      EditOffline(
        first.offline_choices.key,
        revision,
        first.offline_generation,
        action,
      ),
    )
    assert_eq(
      stale.offline_choices.sheet.unwrap().to_json(),
      edited.offline_choices.sheet.unwrap().to_json(),
    )
    assert_eq(stale.offline_choices.recovery, edited.offline_choices.recovery)
  }
}

///|
test "reviewer offline same revision restore and switch away back invalidate captured events" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let basis = offline_fixture_basis()
  let first = offline_started(basis)
  let original = first.offline_choices.sheet.unwrap()
  let replacement = {
    ..original,
    current: { ..original.current, reasoning: "Replacement same revision", },
  }
  let restored = offline_apply(
    offline_apply(first, SetRecovery(replacement.to_json().stringify())),
    Restore,
  )
  assert_eq(
    restored.offline_choices.sheet.unwrap().current.revision,
    original.current.revision,
  )
  assert_true(restored.offline_generation != first.offline_generation)
  let other = offline_fixture_basis(id="reviewer-other-brief")
  let switched = update_offline_choices(
    { ..restored, brief: offline_fixture_model(other).brief, },
    OpenOffline(other.to_json().stringify()),
  )
  let returned = update_offline_choices(
    { ..switched, brief: offline_fixture_model(basis).brief, },
    OpenOffline(basis.to_json().stringify()),
  )
  assert_true(returned.offline_generation != restored.offline_generation)
  for current in [restored, returned] {
    for
      action in [
        SetField("reasoning", "Stale ABA"),
        Export("json"),
        Restore,
        Save,
      ] {
      let stale = update_offline_choices(
        current,
        EditOffline(
          first.offline_choices.key,
          original.current.revision,
          first.offline_generation,
          action,
        ),
      )
      assert_eq(
        stale.offline_choices.sheet.unwrap().to_json(),
        current.offline_choices.sheet.unwrap().to_json(),
      )
      assert_eq(
        stale.offline_choices.recovery,
        current.offline_choices.recovery,
      )
    }
    let next_basis = offline_fixture_basis(version='b')
    let stale_continue = update_offline_choices(
      { ..current, brief: offline_fixture_model(next_basis).brief, },
      ContinueOffline(
        first.offline_choices.key,
        original.current.revision,
        first.offline_generation,
        next_basis.to_json().stringify(),
      ),
    )
    assert_eq(
      stale_continue.offline_choices.sheet.unwrap().to_json(),
      current.offline_choices.sheet.unwrap().to_json(),
    )
  }
}
