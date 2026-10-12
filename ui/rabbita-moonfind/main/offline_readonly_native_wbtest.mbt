///|
extern "js" fn reviewer_offline_revision(which : String) -> String =
  #|which => process.env['MOONFIND_REVIEW_OFFLINE_'+which] || ''

///|
test "reviewer offline saved native revisions GET only comparison continuation and reload" {
  if reviewer_offline_revision("FIRST") == "" {
    return
  }
  assert_true(brief_install_native_transport())
  defer brief_restore_native_transport()
  install_choice_storage("ok")
  defer restore_choice_storage()
  let (cell, dispatch) = retained_harness(initial_model())
  ignore(
    dispatch(
      BriefAction(Open("brief-ui-fixture", reviewer_offline_revision("FIRST"))),
    ),
  )
  let first = offline_open_basis(cell.val).unwrap()
  ignore(dispatch(OfflineChoices(OpenOffline(first.to_json().stringify()))))
  cell.val = offline_apply(
    cell.val,
    SetOption("option-1", "source", "source-1"),
  )
  cell.val = offline_apply(
    cell.val,
    SetField("reasoning", "Independent native read-only comparison"),
  )
  let retained = cell.val.offline_choices.sheet.unwrap()
  cell.val = initial_model()
  ignore(
    dispatch(
      BriefAction(Open("brief-ui-fixture", reviewer_offline_revision("FIRST"))),
    ),
  )
  ignore(dispatch(OfflineChoices(OpenOffline(first.to_json().stringify()))))
  assert_eq(
    cell.val.offline_choices.sheet.unwrap().to_json(),
    retained.to_json(),
  )
  ignore(
    dispatch(
      BriefAction(Open("brief-ui-fixture", reviewer_offline_revision("SECOND"))),
    ),
  )
  let second = offline_open_basis(cell.val).unwrap()
  assert_false(offline_current(cell.val, retained))
  let requests_before = brief_native_requests()
  ignore(
    dispatch(
      OfflineChoices(
        ContinueOffline(
          cell.val.offline_choices.key,
          retained.current.revision,
          cell.val.offline_generation,
          second.to_json().stringify(),
        ),
      ),
    ),
  )
  let continued = cell.val.offline_choices.sheet.unwrap()
  assert_eq(continued.history[0].to_json(), retained.current.to_json())
  assert_eq(continued.current.options[0].source_slot, "")
  assert_eq(
    continued.current.options[0].historical_source.unwrap().source.digest,
    first.sources[0].digest,
  )
  assert_true(offline_current(cell.val, continued))
  cell.val = offline_apply(cell.val, Export("json"))
  let exported = cell.val.offline_choices.recovery
  assert_eq(
    offline_decode(exported, "brief-ui-fixture").unwrap().to_json(),
    continued.to_json(),
  )
  cell.val = offline_apply(cell.val, Export("md"))
  assert_true(
    cell.val.offline_choices.recovery.contains("source 月面 🌒\r\n"),
  )
  assert_true(
    cell.val.offline_choices.recovery.contains("Changed source 月面 🌒\r\n"),
  )
  assert_eq(brief_native_requests(), requests_before)
  println(
    "MOONFIND_REVIEW_OFFLINE=" +
    (
      {
        "requests": @json.parse(brief_native_requests()),
        "first_revision": first.revision_id,
        "second_revision": second.revision_id,
        "first_digest": first.sources[0].digest,
        "second_digest": second.sources[0].digest,
        "worksheet_actions_native_requests": 0,
        "setup_posts": 0,
        "json": exported,
      } : Json).stringify(),
  )
}
