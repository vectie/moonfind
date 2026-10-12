///|
test "offline choices compiled controller actual native brief source save reopen compare export" {
  if !brief_install_native_transport() {
    return
  }
  defer brief_restore_native_transport()
  install_choice_storage("ok")
  defer restore_choice_storage()
  offline_route_fixture()
  defer offline_restore_route()
  let initial = initial_model()
  let (cell, dispatch) = retained_harness({
    ..initial,
    brief: { ..initial.brief, draft: brief_fixture_draft(), },
  })
  ignore(dispatch(BriefAction(Save)))
  assert_eq(cell.val.brief.error, None)
  let first = offline_open_basis(cell.val).unwrap()
  let setup_requests = brief_native_requests()
  ignore(dispatch(OfflineChoices(OpenOffline(first.to_json().stringify()))))
  for
    action in [
      SetOption("option-1", "name", "Local pilot 月面 🌒"),
      SetOption("option-1", "source", "source-1"),
      SetField("chosen", "option-1"),
      SetField("reasoning", "Evidence is limited; prefer the smallest test"),
      SetOption("option-1", "experiment", "Ask three buyers before building"),
      SetOption("option-1", "contradiction", "Sources disagree"),
      SetField("next", "Prepare questions"),
      Export("json"),
    ] {
    ignore(
      dispatch(
        OfflineChoices(
          EditOffline(
            cell.val.offline_choices.key,
            cell.val.offline_choices.sheet.unwrap().current.revision,
            cell.val.offline_generation,
            action,
          ),
        ),
      ),
    )
  }
  assert_eq(brief_native_requests(), setup_requests)
  let first_sheet = cell.val.offline_choices.sheet.unwrap()
  let first_export = cell.val.offline_choices.recovery
  assert_true(offline_decode(first_export, first.brief.brief_id) is Ok(_))
  assert_false(first_export.contains("\"run_id\""))
  assert_true(first_export.contains(first.sources[0].digest))
  let first_html = qa_test_render(cell.val)
  assert_true(first_html.contains("moonfind-brief-workspace"))
  assert_true(first_html.contains("Local pilot 月面 🌒"))
  cell.val = initial_model()
  ignore(dispatch(BriefAction(Open(first.brief.brief_id, first.revision_id))))
  let reopened = offline_open_basis(cell.val).unwrap()
  ignore(dispatch(OfflineChoices(OpenOffline(reopened.to_json().stringify()))))
  assert_eq(
    cell.val.offline_choices.sheet.unwrap().to_json(),
    first_sheet.to_json(),
  )
  assert_true(cell.val.workspace is None)
  ignore(dispatch(BriefAction(Edit("objective", "Revised saved basis"))))
  assert_true(offline_open_basis(cell.val) is None)
  ignore(dispatch(BriefAction(RemoveSource(0))))
  ignore(dispatch(BriefAction(PasteField("name", "source.txt"))))
  ignore(
    dispatch(BriefAction(PasteField("origin", "Changed permitted capture"))),
  )
  ignore(
    dispatch(BriefAction(PasteField("text", "Changed source 月面 🌒\r\n"))),
  )
  ignore(dispatch(BriefAction(AddPaste)))
  ignore(dispatch(BriefAction(Save)))
  assert_eq(cell.val.brief.error, None)
  let second = offline_open_basis(cell.val).unwrap()
  assert_false(second.revision_id == first.revision_id)
  assert_false(
    offline_current(cell.val, cell.val.offline_choices.sheet.unwrap()),
  )
  assert_eq(
    cell.val.offline_choices.sheet.unwrap().current.basis.revision_id,
    first.revision_id,
  )
  let before_decision = brief_native_requests()
  ignore(
    dispatch(
      OfflineChoices(
        ContinueOffline(
          cell.val.offline_choices.key,
          cell.val.offline_choices.sheet.unwrap().current.revision,
          cell.val.offline_generation,
          second.to_json().stringify(),
        ),
      ),
    ),
  )
  let final_sheet = cell.val.offline_choices.sheet.unwrap()
  assert_eq(final_sheet.history.length(), 1)
  assert_eq(final_sheet.current.options[0].source_slot, "")
  assert_eq(
    final_sheet.current.options[0].historical_source.unwrap().source.digest,
    first.sources[0].digest,
  )
  assert_eq(final_sheet.current.chosen_option_id, "option-1")
  let exported = offline_export_json(
    final_sheet,
    offline_current(cell.val, final_sheet),
  ).stringify(indent=2)
  let markdown = offline_markdown(final_sheet, true)
  guard offline_decode(exported, first.brief.brief_id) is Ok(restored) else {
    fail("Native source export failed local restoration")
  }
  assert_eq(restored.to_json(), final_sheet.to_json())
  assert_true(markdown.contains("source 月面 🌒\r\n"))
  assert_true(markdown.contains("Changed source 月面 🌒\r\n"))
  assert_eq(brief_native_requests(), before_decision)
  println(
    "MOONFIND_OFFLINE_CHOICE_NATIVE=" +
    (
      {
        "first_revision": first.revision_id,
        "second_revision": second.revision_id,
        "first_source_digest": first.sources[0].digest,
        "second_source_digest": second.sources[0].digest,
        "requests": @json.parse(brief_native_requests()),
        "worksheet_actions_native_requests": 0,
        "provider_calls": 0,
        "json": exported,
        "markdown": markdown,
        "html": qa_test_render(cell.val),
      } : Json).stringify(),
  )
}
