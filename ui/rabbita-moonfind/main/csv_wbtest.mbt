///|
extern "js" fn csv_native_fixture() -> String =
  #|() => process.getBuiltinModule('fs').readFileSync(process.env.MOONFIND_CSV_FIXTURE, 'utf8')

///|
test "CSV compiled UI imports explores projects rows and reopens a native dossier" {
  if !brief_install_native_transport() {
    return
  }
  defer brief_restore_native_transport()
  install_choice_storage("ok")
  defer restore_choice_storage()
  let scheduler = RouteTestScheduler::{
    hooks: { url_request: None, url_changed: None, },
  }
  let draft = {
    ..brief_fixture_draft(),
    brief_id: "csv-ui-fixture",
    question: "Which clinic handoff assumption needs a timing experiment?",
    sources: [],
  }
  let cell = Ref({
    ..initial_model(),
    brief: { ..initial_brief_view(), draft, },
  })
  fn dispatch(message : Msg) -> @rabbita.Cmd {
    let (command, next) = update(dispatch, message, cell.val)
    cell.val = next
    @cmd.Scheduler::add(scheduler, command)
    @rabbita.none
  }
  let original = csv_native_fixture()
  let source : BriefInputSource = {
    name: "local-evidence.csv",
    origin: "Synthetic local interview evidence",
    captured_at: "2026-10-08T21:00:00Z",
    kind: "local-file",
    content_hex: brief_text_hex(original),
  }
  let invalid = {
    ..source,
    content_hex: brief_text_hex("id,note\nwrong-shape"),
  }
  ignore(
    dispatch(
      BriefAction(
        Csv(
          FileLoaded(
            cell.val.brief.generation,
            ({ "sources": [invalid.to_json()] } : Json).stringify(),
          ),
        ),
      ),
    ),
  )
  assert_true(cell.val.brief.error is Some(_))
  assert_false(cell.val.brief.pending)
  assert_eq(cell.val.brief.draft.sources.length(), 0)
  ignore(
    dispatch(
      BriefAction(
        Csv(
          FileLoaded(
            cell.val.brief.generation,
            ({ "sources": [source.to_json()] } : Json).stringify(),
          ),
        ),
      ),
    ),
  )
  assert_eq(cell.val.brief.error, None)
  assert_eq(cell.val.brief.csv.intake.unwrap().total_count, 4)
  assert_eq(cell.val.brief.csv.columns, [1, 2, 3, 4, 5])
  let html = qa_test_render(cell.val)
  assert_true(html.contains("<table"))
  assert_true(html.contains("Needs timing check."))
  assert_true(html.contains("&lt;script&gt;"))
  assert_false(html.contains("<script>alert(1)</script>"))
  ignore(dispatch(BriefAction(Csv(Filter("CLINIC")))))
  assert_eq(csv_filtered(cell.val.brief.csv).map(row => row.record_number), [
    2, 3, 4,
  ])
  ignore(dispatch(BriefAction(Csv(SearchColumn(2)))))
  assert_eq(csv_filtered(cell.val.brief.csv).map(row => row.record_number), [
    2, 4,
  ])
  ignore(dispatch(BriefAction(Csv(SelectMatching))))
  ignore(dispatch(BriefAction(Csv(SelectMatching))))
  assert_eq(cell.val.brief.csv.selected, [2, 4])
  ignore(dispatch(BriefAction(Csv(ToggleColumn(2)))))
  ignore(dispatch(BriefAction(Csv(ToggleColumn(5)))))
  ignore(dispatch(BriefAction(Csv(Filter("library")))))
  assert_eq(csv_filtered(cell.val.brief.csv).map(row => row.record_number), [5])
  assert_eq(cell.val.brief.csv.selected, [2, 4])
  ignore(dispatch(BriefAction(Csv(AddSelected))))
  assert_eq(cell.val.brief.error, None)
  assert_eq(cell.val.brief.draft.sources.length(), 2)
  assert_eq(cell.val.brief.draft.sources[0], source)
  let selected : CsvSelection = @json.from_json(
    @json.parse(
      brief_source_preview(cell.val.brief.draft.sources[1].content_hex),
    ),
  )
  assert_eq(selected.columns, ["id", "observation", "confidence"])
  assert_eq(selected.column_numbers, [1, 3, 4])
  assert_eq(selected.rows.map(row => row.record_number), [2, 4])
  assert_eq(selected.rows[0].values[0], "001")
  assert_true(
    qa_test_render(cell.val).contains(
      "Selected evidence rows from local-evidence.csv",
    ),
  )
  ignore(dispatch(BriefAction(Save)))
  assert_eq(cell.val.brief.error, None)
  let saved = cell.val.brief.opened.unwrap()
  let saved_draft = cell.val.brief.draft
  cell.val = initial_model()
  ignore(dispatch(BriefAction(Open(saved.brief_id, saved.revision_id))))
  assert_eq(cell.val.brief.error, None)
  assert_eq(cell.val.brief.draft, saved_draft)
  assert_true(
    qa_test_render(cell.val).contains(
      "Selected evidence rows from local-evidence.csv",
    ),
  )
  let zip = brief_native_export(
    "/api/v1/briefs/" +
    saved.brief_id +
    "/" +
    saved.revision_id +
    "/dossier.zip",
  )
  assert_true(zip.has_prefix("504b0304"))
  println(
    "MOONFIND_CSV_NATIVE=" +
    (
      {
        "imported": 4,
        "selected_record_numbers": [2, 4],
        "selected_column_numbers": [1, 3, 4],
        "revision_id": saved.revision_id,
        "original_source_preserved": true,
        "reopened_rows": 2,
        "dossier_bytes": zip.length() / 2,
        "requests": @json.parse(brief_native_requests()),
        "provider_calls": 0,
      } : Json).stringify(),
  )
}

///|
test "CSV UI resets safely while selections survive filters and clearing is explicit" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let emit = _ => @rabbita.none
  let initial = { ..initial_brief_view(), draft: brief_fixture_draft(), }
  let (_, cancelled) = update_csv_view(
    emit,
    FileLoaded(0, "{\"sources\":[]}"),
    initial,
  )
  assert_eq(cancelled.draft, initial.draft)
  assert_false(cancelled.pending)
  let pending = { ..initial, pending: true, generation: 7, }
  let (_, repeated) = update_csv_view(emit, AddSelected, pending)
  assert_eq(repeated.generation, 7)
  assert_true(repeated.pending)
  let (_, bad) = update_csv_view(emit, Imported(7, Ok(Json::null())), pending)
  assert_false(bad.pending)
  assert_true(bad.error is Some(_))
  let model = { ..initial_model(), brief: pending, }
  let (_, fresh) = update(emit, BriefAction(New), model)
  let (_, stale) = update(
    emit,
    BriefAction(Csv(Imported(7, Ok(Json::null())))),
    fresh,
  )
  assert_false(stale.brief.pending)
  assert_true(stale.brief.csv.intake is None)
  let (_, stale_selection) = update(
    emit,
    BriefAction(Csv(Selected(7, Ok(Json::array([]))))),
    fresh,
  )
  assert_eq(stale_selection.brief.draft, fresh.brief.draft)
  let (_, empty) = update_csv_view(emit, AddSelected, initial)
  assert_true(empty.error.unwrap().contains("one data row"))
  let selected = {
    ..initial,
    csv: {
      intake: Some({
        source: initial.draft.sources[0],
        columns: ["id"],
        rows: [{ record_number: 2, values: ["001"], }],
        total_count: 1,
      }),
      query: "",
      column_number: 0,
      selected: [2],
      columns: [1],
      category_column: 1,
      category_filtered: false,
      numeric_column: 0,
      comparison_column: 0,
      numeric_scope: "all",
      numeric_detail: "numeric",
      extract_scope: "selected",
    },
  }
  let (_, cleared) = update_csv_view(emit, ClearRows, selected)
  assert_eq(cleared.csv.selected, [])
  let (_, no_columns) = update_csv_view(emit, ToggleColumn(1), selected)
  let (_, blocked) = update_csv_view(emit, AddSelected, no_columns)
  assert_true(blocked.error.unwrap().contains("one output column"))
  let full = {
    ..selected,
    draft: {
      ..initial.draft,
      sources: Array::make(7, initial.draft.sources[0]),
    },
  }
  let (_, capacity) = update_csv_view(emit, AddSelected, full)
  assert_false(capacity.pending)
  assert_true(capacity.error.unwrap().contains("two source slots"))
}
