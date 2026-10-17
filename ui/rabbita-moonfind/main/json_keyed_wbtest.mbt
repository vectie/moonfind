///|
test "keyed observations retain member pointers through selection extract and restored draft" {
  let source = json_records_source(
    "{\"observations\":{\"10\":{\"site\":\"clinic\",\"n\":9007199254740993},\"a/b~\":{\"site\":\"school\"}}}",
  )
  let view = {
    ..initial_brief_view(),
    draft: { ..brief_fixture_draft(), sources: [source], },
  }
  let view = json_records_apply(view, Source(1))
  let view = json_records_apply(view, Pointer("/observations"))
  let view = json_records_apply(view, Explore)
  assert_eq(view.json_evidence.table.unwrap().format, "json-object")
  let view = json_records_apply(view, Search("school"))
  let view = json_records_apply(view, SelectMatching)
  assert_eq(view.json_evidence.selected, [2])
  let extract = json_evidence_export(view)
  assert_true(extract.contains("/observations/a~1b~0"))
  let view = json_records_apply(view, Add)
  assert_eq(view.draft.sources.length(), 2)
  assert_eq(view.draft.sources[0], source)
  let restored : BriefDraft = @json.from_json(@json.parse(view.draft.to_json().stringify()))
  let view = { ..initial_brief_view(), draft: restored, }
  let view = json_records_apply(view, Source(1))
  let view = json_records_apply(view, Pointer("/observations"))
  let view = json_records_apply(view, Explore)
  assert_eq(view.json_evidence.table.unwrap().rows[0].pointer, "/observations/10")
  assert_true(view.json_evidence.table.unwrap().rows[0].raw.contains("9007199254740993"))
}
