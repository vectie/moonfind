///|
fn comparison_ready() -> BriefView {
  csv_numeric_apply(csv_numeric_ready(), ComparisonColumn(2))
}

///|
test "comparison explicit columns and ordered source membership" {
  let initial = csv_numeric_fixture()
  assert_eq(initial.csv.comparison_column, 0)
  assert_true((Ok(csv_comparison(initial.csv)) catch { e => Err(e) }) is Err(_))
  assert_true(
    (Ok(csv_comparison(csv_numeric_ready().csv)) catch { e => Err(e) })
    is Err(_),
  )
  let view = comparison_ready()
  let groups = csv_comparison(view.csv)
  assert_eq(groups.length(), 2)
  assert_eq(groups[0].category, "keep")
  assert_eq(groups[0].summary.sum, Some(8.0))
  assert_eq(groups[0].summary.mean, Some(8.0 / 3.0))
  assert_eq(groups[0].summary.numeric_count, 3)
  assert_eq(groups[0].summary.blank_count, 1)
  assert_eq(groups[0].summary.invalid_count, 1)
  assert_eq(groups[0].summary.cells.map(c => c.record_number), [2, 4, 6, 8, 10])
  assert_eq(groups[1].summary.sum, Some(30.5))
  assert_eq(groups[1].summary.invalid_count, 2)
  assert_eq(
    csv_numeric_apply(view, ComparisonColumn(-1)).csv.comparison_column,
    2,
  )
  assert_eq(
    csv_numeric_apply(view, ComparisonColumn(3)).csv.comparison_column,
    2,
  )
  assert_true(
    (Ok(csv_comparison(csv_numeric_apply(view, ComparisonColumn(0)).csv)) catch {
      e => Err(e)
    })
    is Err(_),
  )
}

///|
test "comparison all matching selected scopes preserve exploration and hidden membership" {
  let view = csv_numeric_apply(
    csv_numeric_apply(comparison_ready(), SearchColumn(2)),
    Filter("keep"),
  )
  let view = csv_numeric_apply(csv_numeric_apply(view, Toggle(3)), Toggle(6))
  let view = csv_numeric_apply(view, ToggleColumn(1))
  assert_eq(csv_comparison(view.csv).length(), 2)
  let matching = csv_numeric_apply(view, NumericScope("matching"))
  assert_eq(csv_comparison(matching.csv).length(), 1)
  assert_eq(csv_comparison(matching.csv)[0].summary.sum, Some(8.0))
  let selected = csv_numeric_apply(view, NumericScope("selected"))
  let groups = csv_comparison(selected.csv)
  assert_eq(groups.map(g => g.category), ["omit", "keep"])
  assert_eq(groups[0].summary.cells[0].record_number, 3)
  assert_eq(groups[0].summary.mean, Some(20.5))
  assert_eq(groups[1].summary.sum, Some(-2.0))
  assert_eq(selected.csv.selected, [3, 6])
  assert_eq(selected.csv.columns, [2])
  assert_eq(selected.csv.query, "keep")
  assert_eq(csv_comparison(csv_numeric_apply(matching, Filter("absent")).csv), [])
  assert_eq(csv_comparison(csv_numeric_apply(selected, ClearRows).csv), [])
  csv_numeric_evidence(
    "comparison-selected.json",
    csv_comparison_export(selected.csv),
  )
  csv_numeric_evidence(
    "comparison-matching.json",
    csv_comparison_export(matching.csv),
  )
}

///|
test "comparison category identity keeps empty whitespace case unicode and script strings" {
  let categories = ["", " ", "A", "a", "é", "é", "<script>月</script>", "a"]
  let view = csv_numeric_apply(
    csv_numeric_ready(values=categories),
    ComparisonColumn(1),
  )
  let groups = csv_comparison(view.csv)
  assert_eq(groups.map(g => g.category), [
    "", " ", "A", "a", "é", "é", "<script>月</script>",
  ])
  assert_eq(groups[3].summary.cells.map(c => c.record_number), [5, 9])
  assert_eq(groups[0].summary.blank_count, 1)
  assert_eq(groups[1].summary.blank_count, 1)
  assert_eq(groups[3].summary.invalid_count, 2)
  install_choice_storage("ok")
  defer restore_choice_storage()
  let html = qa_test_render({ ..initial_model(), brief: view, })
  assert_true(html.contains("Compare numeric values by category"))
  assert_true(html.contains("&lt;script&gt;月&lt;/script&gt;"))
  assert_false(html.contains("<script>月</script>"))
  assert_true(html.contains("<th>Group</th>"))
  assert_true(html.contains("Source records for"))
  csv_numeric_evidence("comparison-escaped.html", html)
}

///|
test "comparison group overflow excludes unavailable values without affecting other groups" {
  let view = csv_numeric_apply(
    csv_numeric_ready(values=["1e308", "0", "1e308", "", "bad", "3"]),
    ComparisonColumn(2),
  )
  let groups = csv_comparison(view.csv)
  assert_eq(groups[0].summary.minimum, Some(1.0e308))
  assert_eq(groups[0].summary.sum, None)
  assert_eq(groups[0].summary.invalid_count, 1)
  assert_eq(groups[1].summary.sum, Some(3.0))
  assert_eq(groups[1].summary.mean, Some(1.5))
  let exported = csv_comparison_export(view.csv)
  guard @json.parse(exported) is { "groups": Array(groups), .. } else {
    fail("missing groups")
  }
  assert_true(groups[0] is { "summary": { "sum": Null, "mean": Null, .. }, .. })
  csv_numeric_evidence("comparison-overflow.json", exported)
  let excluded = csv_numeric_apply(
    csv_numeric_ready(values=["", "bad"]),
    ComparisonColumn(2),
  )
  csv_numeric_evidence(
    "comparison-excluded.json",
    csv_comparison_export(excluded.csv),
  )
  let zero = csv_numeric_apply(
    csv_numeric_ready(values=["0", "0"]),
    ComparisonColumn(2),
  )
  csv_numeric_evidence("comparison-zero.json", csv_comparison_export(zero.csv))
}

///|
test "comparison pending stale new and reimport actions retain generation boundaries" {
  let view = comparison_ready()
  let pending = { ..view, pending: true, generation: 13, }
  for action in [ComparisonColumn(1), DownloadComparison] {
    let after = csv_numeric_apply(pending, action)
    assert_eq(after.csv.comparison_column, 2)
    assert_eq(after.error, pending.error)
    assert_eq(csv_comparison(after.csv), csv_comparison(view.csv))
  }
  let stale = csv_numeric_apply(pending, Imported(12, Ok(Json::null())))
  assert_eq(stale.csv.comparison_column, 2)
  let (_, fresh) = update_brief_view(_ => @rabbita.none, New, pending)
  assert_eq(fresh.csv.comparison_column, 0)
  assert_true(
    csv_numeric_apply(fresh, Imported(13, Ok(Json::null()))).csv.intake is None,
  )
  assert_eq(csv_numeric_fixture().csv.comparison_column, 0)
}

///|
test "comparison bounded corpus retains all groups and source cells" {
  let view = csv_numeric_apply(
    csv_numeric_ready(values=Array::makei(512, i => i.to_string())),
    ComparisonColumn(1),
  )
  let groups = csv_comparison(view.csv)
  assert_eq(groups.length(), 512)
  assert_eq(groups[511].category, "511")
  assert_eq(groups[511].summary.cells[0].record_number, 513)
  assert_eq(groups[511].summary.mean, Some(511.0))
  csv_numeric_evidence(
    "comparison-bounded.json",
    csv_comparison_export(view.csv),
  )
}

///|
extern "js" fn comparison_blob_verify(expected : String) -> String =
  #|expected => {
  #| const got=globalThis.__numericDownload;
  #| if(!got.clicked || got.name!=='moonfind-csv-category-comparison.json' || !(got.blob instanceof Blob) || got.blob.type!=='application/json;charset=utf-8') return 'download metadata mismatch';
  #| got.blob.text().then(text=>{
  #|   if(text!==expected) throw Error('Blob bytes differ');
  #|   if(process.env.MOONFIND_NUMERIC_EVIDENCE) process.getBuiltinModule('fs').writeFileSync(process.env.MOONFIND_NUMERIC_EVIDENCE+'/'+got.name,text);
  #| }).catch(e=>{console.error(e);process.exitCode=1;}); return '';
  #| }

///|
test "comparison export real blob exact source metadata and retryable failure" {
  let view = comparison_ready()
  let text = csv_comparison_export(view.csv)
  guard @json.parse(text)
    is {
      "source": source,
      "category_column_number": Number(2, ..),
      "numeric_column_number": Number(1, ..),
      "scope": String("all"),
      ..
    } else {
    fail("export metadata")
  }
  let source : BriefInputSource = @json.from_json(source)
  assert_eq(source, view.csv.intake.unwrap().source)
  csv_numeric_blob_fixture("ok")
  assert_eq(csv_numeric_apply(view, DownloadComparison).error, None)
  assert_eq(comparison_blob_verify(text), "")
  csv_numeric_blob_restore()
  for mode in ["create", "click"] {
    csv_numeric_blob_fixture(mode)
    let after = csv_numeric_apply(view, DownloadComparison)
    assert_true(after.error is Some(_))
    assert_eq(csv_comparison(after.csv), csv_comparison(view.csv))
    csv_numeric_blob_restore()
  }
}
