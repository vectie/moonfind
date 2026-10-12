///|
fn csv_category_fixture() -> BriefView {
  let values = [
    "A", "a", "A", "", " ", "é", "é", "😀", "<script>\"x\"\n,y", "😀",
  ]
  let source : BriefInputSource = {
    name: "categories.csv",
    origin: "Synthetic category fixture",
    captured_at: "2026-10-09T04:00:00Z",
    kind: "local-file",
    content_hex: brief_text_hex(
      "category,note\nA,keep\na,omit\nA,keep\n,omit\n ,keep\né,omit\né,keep\n😀,omit\n\"<script>\"\"x\"\"\n,y\",keep\n😀,omit\n",
    ),
  }
  let rows = values.mapi((i, value) => CsvRow::{
    record_number: i + 2,
    values: [value, if i % 2 == 0 { "keep" } else { "omit" }],
  })
  let payload : Json = {
    "source": source.to_json(),
    "columns": ["category", "note"],
    "rows": rows.to_json(),
    "total_count": 10,
  }
  let (_, loaded) = update_csv_view(
    _ => @rabbita.none,
    Imported(7, Ok(payload)),
    { ..initial_brief_view(), generation: 7, pending: true, },
  )
  loaded
}

///|
fn csv_category_apply(view : BriefView, msg : CsvMsg) -> BriefView {
  update_csv_view(_ => @rabbita.none, msg, view).1
}

///|
test "categories exact blanks spaces case Unicode counts stable ties and membership" {
  let view = csv_category_fixture()
  assert_eq(view.csv.category_column, 1)
  assert_false(view.csv.category_filtered)
  let groups = csv_categories(view.csv)
  assert_eq(groups.map(g => g.value), [
    "A", "😀", "a", "", " ", "é", "é", "<script>\"x\"\n,y",
  ])
  assert_eq(groups[0].record_numbers, [2, 4])
  assert_eq(groups[1].record_numbers, [9, 11])
  assert_eq(groups.fold(init=0, (n, g) => n + g.record_numbers.length()), 10)
  assert_eq(groups, csv_categories(view.csv))
  let other = csv_category_apply(view, CategoryColumn(2))
  assert_eq(csv_categories(other.csv).map(g => g.value), ["keep", "omit"])
  assert_eq(csv_categories(other.csv)[0].record_numbers, [2, 4, 6, 8, 10])
  assert_eq(csv_category_apply(other, CategoryColumn(0)).csv.category_column, 2)
  assert_eq(csv_category_apply(other, CategoryColumn(3)).csv.category_column, 2)
}

///|
test "categories scope and replace selection preserve original records and projection" {
  let view = csv_category_apply(csv_category_fixture(), ToggleColumn(2))
  let view = csv_category_apply(view, Toggle(3))
  let view = csv_category_apply(view, SearchColumn(2))
  let view = csv_category_apply(view, Filter(" KEEP "))
  assert_eq(csv_categories(view.csv)[1].record_numbers, [9, 11])
  let selected = csv_category_apply(view, SelectCategory("😀"))
  assert_eq(selected.csv.selected, [9, 11])
  assert_eq(selected.csv.columns, [1])
  assert_eq(csv_filtered(selected.csv).map(r => r.record_number), [
    2, 4, 6, 8, 10,
  ])
  let matching = csv_category_apply(selected, CategoryScope(true))
  assert_eq(csv_categories(matching.csv).length(), 4)
  assert_eq(csv_category_apply(matching, SelectCategory("😀")).csv.selected, [
    9, 11,
  ])
  let matching = csv_category_apply(matching, SelectCategory("A"))
  assert_eq(matching.csv.selected, [2, 4])
  assert_eq(csv_category_apply(matching, SelectCategory("A")).csv.selected, [
    2, 4,
  ])
  let empty = csv_category_apply(matching, Filter("absent"))
  assert_eq(csv_categories(empty.csv), [])
  assert_eq(empty.csv.selected, [2, 4])
  assert_true(
    @json.parse(csv_categories_export(empty.csv))
    is { "counted_rows": Number(0), "groups": Array([]), .. },
  )
  assert_eq(csv_category_apply(empty, ClearRows).csv.selected, [])
}

///|
test "categories pending actions and stale callbacks cannot change imported groups" {
  let loaded = csv_category_fixture()
  let pending = { ..loaded, pending: true, generation: 8, }
  for
    action in [
      CategoryColumn(2),
      CategoryScope(true),
      SelectCategory("A"),
      DownloadCategories,
    ] {
    let after = csv_category_apply(pending, action)
    assert_eq(after.csv.category_column, 1)
    assert_false(after.csv.category_filtered)
    assert_eq(after.csv.selected, [])
    assert_true(after.pending)
  }
  let stale = csv_category_apply(pending, Imported(7, Ok(Json::null())))
  assert_eq(csv_categories(stale.csv), csv_categories(loaded.csv))
  assert_true(stale.pending)
  let (_, fresh) = update_brief_view(_ => @rabbita.none, New, pending)
  let stale = csv_category_apply(fresh, Imported(8, Ok(Json::null())))
  assert_true(stale.csv.intake is None)
  assert_eq(csv_categories(stale.csv), [])
}

///|
test "categories render hostile values safely and export exact source membership" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = csv_category_fixture()
  let html = qa_test_render({ ..initial_model(), brief: view, })
  assert_true(html.contains("Category counts and source-row drill-down"))
  assert_true(html.contains("&lt;script&gt;"))
  assert_false(html.contains("<script>"))
  assert_true(html.contains("(empty cell)"))
  let text = csv_categories_export(view.csv)
  let json = @json.parse(text)
  assert_true(
    json
    is {
      "contract_id": String("moonfind.csv-category-counts.v1"),
      "scope": String("all_rows"),
      "counted_rows": Number(10),
      ..
    },
  )
  guard json is { "source": source, .. } else { fail("missing source") }
  let source : BriefInputSource = @json.from_json(source)
  assert_eq(source, view.csv.intake.unwrap().source)
  csv_category_evidence("input.csv", brief_source_preview(source.content_hex))
  csv_category_evidence("all-rows.json", text)
  let filtered = csv_category_apply(
    csv_category_apply(view, Filter("keep")),
    CategoryScope(true),
  )
  csv_category_evidence(
    "matching-rows.json",
    csv_categories_export(filtered.csv),
  )
  csv_category_evidence("rendered.html", html)
}

///|
extern "js" fn csv_category_evidence(name : String, content : String) -> Unit =
  #|(name,content) => {if(process.env.MOONFIND_CATEGORY_EVIDENCE) process.getBuiltinModule('fs').writeFileSync(process.env.MOONFIND_CATEGORY_EVIDENCE+'/'+name,content);}

///|
test "categories download boundary exact bytes filename failure and retry" {
  for failed in [true, false] {
    experiment_download_fixture(failed)
    defer experiment_download_restore()
    let view = csv_category_fixture()
    let after = csv_category_apply(view, DownloadCategories)
    assert_eq(after.csv.intake.unwrap().source, view.csv.intake.unwrap().source)
    assert_eq(after.csv.selected, [])
    if failed {
      assert_true(after.error.unwrap().contains("download failed"))
    } else {
      assert_eq(after.error, None)
      guard @json.parse(experiment_download_readback())
        is {
          "name": String("moonfind-csv-category-counts.json"),
          "clicked": True,
          "content": String(content),
          ..
        } else {
        fail("download missing")
      }
      assert_eq(content, csv_categories_export(view.csv))
    }
  }
}

///|
test "categories all 512 imported rows and zero-row table" {
  let fixture = csv_category_fixture()
  let intake = fixture.csv.intake.unwrap()
  let large = {
    ..fixture.csv,
    intake: Some({
      ..intake,
      total_count: 512,
      rows: Array::makei(512, i => {
        record_number: i + 2,
        values: [if i % 2 == 0 { "even" } else { "odd" }, "keep"],
      }),
    }),
  }
  let groups = csv_categories(large)
  assert_eq(groups.length(), 2)
  assert_eq(groups[0].record_numbers.length(), 256)
  assert_eq(groups[1].record_numbers[255], 513)
  let empty = {
    ..large,
    intake: Some({ ..intake, total_count: 0, rows: [], }),
  }
  assert_eq(csv_categories(empty), [])
  assert_true(
    @json.parse(csv_categories_export(empty))
    is { "counted_rows": Number(0), .. },
  )
}

///|
test "categories selected source preview includes group hidden by current search" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let initial = csv_category_apply(csv_category_fixture(), Filter("keep"))
  let selected = csv_category_apply(initial, SelectCategory("😀"))
  let html = qa_test_render({ ..initial_model(), brief: selected, })
  assert_true(
    html.contains("Selected source rows, including rows hidden by search"),
  )
  assert_true(html.contains("<td>9</td>"))
  assert_true(html.contains("<td>11</td>"))
  assert_eq(selected.csv.selected, [9, 11])
  csv_category_evidence("drill-down.html", html)
  csv_category_evidence(
    "controller-result.json",
    (
      {
        "action": "SelectCategory(😀)",
        "scope": "all_rows",
        "search": "keep",
        "selected_record_numbers": selected.csv.selected.to_json(),
        "visible_matching_record_numbers": csv_filtered(selected.csv)
        .map(r => r.record_number)
        .to_json(),
        "projected_column_numbers": selected.csv.columns.to_json(),
      } : Json).stringify(indent=2),
  )
}
