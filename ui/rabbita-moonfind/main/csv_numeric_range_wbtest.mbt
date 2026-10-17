///|
fn test_numeric_range_workflow() -> Unit raise {
  let initial = csv_numeric_ready()
  let lower = csv_numeric_apply(initial, NumericLower(" 0 "))
  let bounded = csv_numeric_apply(lower, NumericUpper("1e1"))
  assert_eq(csv_numeric_range(bounded.csv).map(row => row.record_number), [
    2, 7, 8,
  ])
  assert_eq(csv_numeric_range(bounded.csv)[0].values, ["10", "keep"])
  assert_eq(bounded.csv.selected, [])
  let selected = csv_numeric_apply(bounded, SelectNumericRange)
  assert_eq(selected.csv.selected, [2, 7, 8])
  assert_eq(csv_numeric_apply(selected, SelectNumericRange).csv.selected, [
    2, 7, 8,
  ])
  let hidden = csv_numeric_apply(selected, Filter("unknown"))
  assert_eq(hidden.csv.selected, [2, 7, 8])
  let matching = csv_numeric_apply(hidden, NumericScope("matching"))
  assert_eq(csv_numeric_range(matching.csv), [])
  let selected_scope = csv_numeric_apply(matching, NumericScope("selected"))
  assert_eq(csv_numeric_range(selected_scope.csv).length(), 3)
  assert_eq(
    csv_numeric_range(csv_numeric_apply(initial, NumericUpper("-2")).csv).map(row => {
      row.record_number
    }),
    [6],
  )
  assert_eq(
    csv_numeric_range(csv_numeric_apply(initial, NumericLower("20.5")).csv).map(row => {
        row.record_number
      },
    ),
    [3],
  )
  for
    pair in [
      ("", ""),
      ("12", "10"),
      ("NaN", ""),
      ("Infinity", ""),
      ("1e999", ""),
      ("1e-999", ""),
      ("1,200", ""),
      ("3px", ""),
      ("", "oops"),
    ] {
    let invalid = csv_numeric_apply(
      csv_numeric_apply(selected, NumericLower(pair.0)),
      NumericUpper(pair.1),
    )
    let rejected = csv_numeric_apply(invalid, SelectNumericRange)
    assert_true(rejected.error is Some(_))
    assert_eq(rejected.csv.selected, selected.csv.selected)
  }
  let pending = { ..bounded, pending: true, }
  for action in [NumericLower("5"), NumericUpper("20"), SelectNumericRange] {
    let blocked = csv_numeric_apply(pending, action)
    assert_eq(blocked.csv.numeric_lower, " 0 ")
    assert_eq(blocked.csv.numeric_upper, "1e1")
    assert_eq(blocked.csv.selected, [])
  }
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(csv_numeric_range_panel(_ => @rabbita.none, bounded)),
  )
  assert_true(html.contains("Lower bound (inclusive)"))
  assert_true(html.contains("3 matching source records"))
  assert_true(html.contains("Select all range rows"))
  let invalid_html = @rabbita.render_to_string(
    @rabbita.static_cell(csv_numeric_range_panel(_ => @rabbita.none, initial)),
  )
  assert_true(invalid_html.contains("Enter at least one bound"))
  assert_false(invalid_html.contains("Select all range rows"))
  // Exercise actual existing Add and reply validation; response is a local fixture,
  // not a host/server/storage qualification.
  let adding = csv_numeric_apply(selected, AddSelected)
  assert_true(adding.pending)
  let intake = selected.csv.intake.unwrap()
  let payload : Json = {
    "contract_id": "moonfind.csv-selection.v1",
    "source_name": intake.source.name,
    "source_digest": csv_source_digest(intake.source.content_hex),
    "source_row_count": intake.total_count,
    "column_numbers": [1, 2],
    "columns": intake.columns.to_json(),
    "rows": csv_numeric_range(selected.csv).to_json(),
  }
  let companion : BriefInputSource = {
    name: "csv-selection.json",
    origin: "Selected CSV records from " + intake.source.name,
    captured_at: intake.source.captured_at,
    kind: "pasted-text",
    content_hex: brief_text_hex(payload.stringify()),
  }
  let sources = [intake.source, companion].to_json()
  let stale = csv_numeric_apply(
    adding,
    Selected(adding.generation - 1, Ok(sources)),
  )
  assert_true(stale.pending)
  assert_eq(stale.draft.sources.length(), 0)
  let added = csv_numeric_apply(
    adding,
    Selected(adding.generation, Ok(sources)),
  )
  assert_eq(added.error, None)
  assert_eq(added.draft.sources, [intake.source, companion])
  assert_eq(added.csv.numeric_lower, "")
  assert_eq(added.csv.numeric_upper, "")
  let restored : BriefDraft = @json.from_json(
    @json.parse(added.draft.to_json().stringify()),
  )
  assert_eq(restored.sources, added.draft.sources)
  println(
    "PASS numeric range: inclusive/open bounds, strict refusal, source rows, scopes, idempotent selection, pending/stale guards, rendered controls, existing Add reply validation and draft roundtrip",
  )
}

///|
test "numeric range to existing brief selection" {
  test_numeric_range_workflow()
}
