///|
fn csv_join_fixture(
  name : String,
  columns : Array[String],
  values : Array[Array[String]],
) -> CsvIntake {
  {
    source: {
      name,
      origin: "Synthetic local evidence table " + name,
      captured_at: "2026-10-12T00:00:00Z",
      kind: "local-file",
      content_hex: brief_text_hex(
        csv_extract_record(columns) + values.map(csv_extract_record).join(""),
      ),
    },
    columns,
    rows: values.mapi((index, values) => { record_number: index + 2, values, }),
    total_count: values.length(),
  }
}

///|
fn csv_join_test_apply(view : BriefView, action : CsvJoinMsg) -> BriefView {
  update_csv_join(_ => @rabbita.none, action, view).1
}

///|
fn csv_join_ready() -> BriefView {
  let left = csv_join_fixture("observations.csv", ["id", "note"], [
    ["001", "Clinic, \"handoff\"\nTwo lines"],
    ["1", "<script>unmatched</script>"],
    ["001", "repeated observation"],
    ["", "empty key"],
  ])
  let right = csv_join_fixture("measurements.csv", ["foreign", "minutes"], [
    ["001", "10"],
    ["orphan", "20"],
    ["", "30"],
  ])
  let initial = {
    ..initial_brief_view(),
    draft: { ..brief_fixture_draft(), sources: [], },
    csv: { ..empty_csv_view(), intake: Some(left), },
  }
  let pinned = csv_join_test_apply(initial, PinLeft)
  let replaced = update_csv_view(
      _ => @rabbita.none,
      Imported(11, Ok(right.to_json())),
      { ..pinned, pending: true, generation: 11, },
    ).1
  let pinned = csv_join_test_apply(replaced, PinRight)
  let configured = csv_join_test_apply(
    csv_join_test_apply(pinned, LeftKey(1)),
    RightKey(1),
  )
  csv_join_test_apply(configured, Mode("left"))
}

///|
fn csv_join_reply(output : CsvJoinOutput) -> Json {
  {
    "source": ToJson::to_json(output.source),
    "columns": output.preview.columns.to_json(),
    "rows": output.preview.rows.to_json(),
    "total_count": output.preview.rows.length().to_json(),
  }
}

///|
fn csv_join_adopted() -> BriefView {
  let pending = csv_join_test_apply(csv_join_ready(), UseJoined)
  let output = pending.csv_join.pending_output.unwrap()
  csv_join_test_apply(
    pending,
    Joined(pending.generation, Ok(csv_join_reply(output))),
  )
}

///|
// Simulated native route responses with an independent strict quoted-CSV reader.
// Real production HTTP commands run; this is NOT real native host qualification.
extern "js" fn csv_join_install_simulated_transport() -> Unit =
  #|() => {
  #| globalThis.__csvJoinOldFetch=globalThis.fetch;globalThis.__csvJoinRequests=[];
  #| const chain=(value,error)=>({then(fn){if(error)return chain(null,error);try{return fn(value)||chain(null,null);}catch(e){return chain(null,e);}},catch(fn){if(error)fn(error);return chain(null,null);}});
  #| const parse=source=>{
  #|   const text=Buffer.from(source.content_hex,'hex').toString('utf8');let rows=[],row=[],cell='',quoted=false,closed=false;
  #|   for(let i=0;i<text.length;i++){const c=text[i];if(quoted){if(c==='"'){if(text[i+1]==='"'){cell+='"';i++;}else{quoted=false;closed=true;}}else cell+=c;}else if(c==='"'&&!closed&&cell===''){quoted=true;}else if(c===','&&closed){row.push(cell);cell='';closed=false;}else if(c==='\r'&&text[++i]==='\n'&&closed){row.push(cell);rows.push(row);row=[];cell='';closed=false;}else throw Error('Invalid quoted test CSV');}
  #|   if(quoted||closed||!rows.length)throw Error('Invalid test CSV');const columns=rows.shift();return {source,columns,rows:rows.map((values,i)=>({record_number:i+2,values})),total_count:rows.length};
  #| };
  #| globalThis.fetch=(path,options)=>{try{
  #|   const body=JSON.parse(options.body);globalThis.__csvJoinRequests.push({path,body});let result;
  #|   if(path==='/api/v1/briefs/csv/intake'){if(body.query!==''||body.column_number!==0)throw Error('Complete intake required');result=parse(body.source);}
  #|   else if(path==='/api/v1/briefs/csv/select'){
  #|     const table=parse(body.source),indexes=table.columns.map((_,i)=>i).filter(i=>body.column_numbers.includes(i+1));
  #|     const selection={contract_id:'moonfind.csv-selection.v1',source_name:body.source.name,source_digest:'sha256:'+process.getBuiltinModule('crypto').createHash('sha256').update(Buffer.from(body.source.content_hex,'hex')).digest('hex'),source_row_count:table.total_count,column_numbers:indexes.map(i=>i+1),columns:indexes.map(i=>table.columns[i]),rows:table.rows.filter(r=>body.record_numbers.includes(r.record_number)).map(r=>({...r,values:indexes.map(i=>r.values[i])}))};
  #|     result=[body.source,{name:'csv-selection.json',origin:'Selected CSV records from '+body.source.name,captured_at:body.source.captured_at,kind:'pasted-text',content_hex:Buffer.from(JSON.stringify(selection)).toString('hex')}];
  #|   }else throw Error('Unexpected route '+path);
  #|   return chain({text:()=>chain(JSON.stringify(result),null)},null);
  #| }catch(error){return chain(null,error);}};
  #|}

///|
extern "js" fn csv_join_restore_simulated_transport() -> Unit =
  #|() => {globalThis.fetch=globalThis.__csvJoinOldFetch;}

///|
extern "js" fn csv_join_simulated_requests() -> String =
  #|() => JSON.stringify(globalThis.__csvJoinRequests)

///|
test "CSV join actual controller HTTP workflow analyzes selects retains originals and restores draft" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  csv_join_install_simulated_transport()
  defer csv_join_restore_simulated_transport()
  let scheduler = RouteTestScheduler::{
    hooks: { url_request: None, url_changed: None, },
  }
  let cell = Ref({
    ..initial_model(),
    brief: {
      ..initial_brief_view(),
      draft: { ..brief_fixture_draft(), sources: [], },
    },
  })
  fn dispatch(message : Msg) -> @rabbita.Cmd {
    let (command, next) = update(dispatch, message, cell.val)
    cell.val = next
    @cmd.Scheduler::add(scheduler, command)
    @rabbita.none
  }
  let left = csv_join_ready().csv_join.left.unwrap()
  let right = csv_join_ready().csv_join.right.unwrap()
  for pair in [(left, true), (right, false)] {
    ignore(
      dispatch(
        BriefAction(
          Csv(
            FileLoaded(
              cell.val.brief.generation,
              ({ "sources": [ToJson::to_json(pair.0.source)] } : Json).stringify(),
            ),
          ),
        ),
      ),
    )
    assert_eq(cell.val.brief.error, None)
    ignore(dispatch(BriefAction(Csv(Filter("does not match any row")))))
    ignore(
      dispatch(BriefAction(CsvJoin(if pair.1 { PinLeft } else { PinRight }))),
    )
  }
  ignore(dispatch(BriefAction(CsvJoin(LeftKey(1)))))
  ignore(dispatch(BriefAction(CsvJoin(RightKey(1)))))
  ignore(dispatch(BriefAction(CsvJoin(Mode("left")))))
  let preview = csv_join_preview(cell.val.brief.csv_join)
  assert_eq(preview.matched, 2)
  assert_eq(preview.unmatched_left, 2)
  assert_eq(preview.unmatched_right, 2)
  assert_eq(preview.duplicate_left, 1)
  ignore(dispatch(BriefAction(CsvJoin(UseJoined))))
  assert_eq(cell.val.brief.error, None)
  assert_false(cell.val.brief.pending)
  assert_eq(cell.val.brief.csv.intake.unwrap().rows, preview.rows)
  assert_eq(cell.val.brief.csv.query, "")
  let html = qa_test_render(cell.val)
  assert_true(html.contains("Join two local evidence tables"))
  assert_true(html.contains("&lt;script&gt;unmatched&lt;/script&gt;"))
  assert_false(html.contains("<script>unmatched</script>"))
  ignore(dispatch(BriefAction(Csv(CategoryColumn(3)))))
  assert_eq(csv_categories(cell.val.brief.csv).length(), 3)
  ignore(dispatch(BriefAction(Csv(NumericColumn(6)))))
  let numeric = csv_numeric_summary(cell.val.brief.csv)
  assert_eq(numeric.numeric_count, 2)
  assert_eq(numeric.blank_count, 2)
  assert_eq(numeric.sum, Some(20.0))
  ignore(dispatch(BriefAction(Csv(SearchColumn(3)))))
  ignore(dispatch(BriefAction(Csv(Filter("001")))))
  ignore(dispatch(BriefAction(Csv(SelectMatching))))
  assert_eq(cell.val.brief.csv.selected, [2, 4])
  ignore(dispatch(BriefAction(Csv(AddSelected))))
  assert_eq(cell.val.brief.error, None)
  let draft = cell.val.brief.draft
  assert_eq(draft.sources.length(), 5)
  assert_eq(draft.sources[0], left.source)
  assert_eq(draft.sources[1], right.source)
  assert_eq(draft.sources[2].name, "csv-join-lineage.txt")
  let lineage = brief_source_preview(draft.sources[2].content_hex)
  assert_true(lineage.contains("Left original: source slot 1"))
  assert_true(lineage.contains("Right original: source slot 2"))
  assert_eq(draft.sources[3].name, "joined-evidence.csv")
  assert_eq(brief_source_preview(draft.sources[3].content_hex), preview.text)
  let selection : CsvSelection = @json.from_json(
    @json.parse(brief_source_preview(draft.sources[4].content_hex)),
  )
  assert_eq(selection.rows.map(row => row.record_number), [2, 4])
  assert_eq(selection.rows[0].values[0], "2")
  assert_eq(selection.rows[1].values[0], "4")
  assert_eq(initial_brief_view().draft, draft)
  let requests = csv_join_simulated_requests()
  assert_true(requests.contains("/api/v1/briefs/csv/intake"))
  assert_true(requests.contains("/api/v1/briefs/csv/select"))
  let parsed : Array[Json] = @json.from_json(@json.parse(requests))
  assert_eq(parsed.length(), 4)
  // Exercise save/reopen reducer protocol with an explicitly simulated reply.
  let saving = reduce_brief_view(_ => @rabbita.none, Save, cell.val.brief).1
  let revision = "revision-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  let saved = reduce_brief_view(
      _ => @rabbita.none,
      Loaded(
        saving.generation,
        draft.brief_id,
        "",
        Ok(brief_fixture_reply(draft, revision)),
      ),
      saving,
    ).1
  assert_eq(saved.error, None)
  let opening = reduce_brief_view(
      _ => @rabbita.none,
      Open(draft.brief_id, revision),
      initial_brief_view(),
    ).1
  let reopened = reduce_brief_view(
      _ => @rabbita.none,
      Loaded(
        opening.generation,
        draft.brief_id,
        revision,
        Ok(brief_fixture_reply(draft, revision)),
      ),
      opening,
    ).1
  assert_eq(reopened.error, None)
  assert_eq(reopened.draft, draft)
  assert_true(reopened.csv_join.left is None)
  assert_true(reopened.csv_join.adopted is None)
}

///|
test "CSV join newer keys selection import and New discard pending replies" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let ready = csv_join_ready()
  let pending = csv_join_test_apply(ready, UseJoined)
  let output = pending.csv_join.pending_output.unwrap()
  let reply = Joined(pending.generation, Ok(csv_join_reply(output)))
  let repeated = csv_join_test_apply(pending, UseJoined)
  assert_eq(repeated.generation, pending.generation)
  for
    action in [LeftKey(2), RightKey(2), Mode("inner"), Clear, PinLeft, PinRight] {
    let changed = csv_join_test_apply(pending, action)
    assert_false(changed.pending)
    assert_true(changed.csv_join.pending_output is None)
    let stale = csv_join_test_apply(changed, reply)
    assert_eq(
      stale.csv.intake.unwrap().source,
      ready.csv.intake.unwrap().source,
    )
    assert_false(stale.pending)
  }
  for action in [CsvMsg::Toggle(2), CsvMsg::Filter("new"), CsvMsg::Choose] {
    let changed = update_csv_view(_ => @rabbita.none, action, pending).1
    assert_false(changed.pending)
    let stale = csv_join_test_apply(changed, reply)
    assert_eq(
      stale.csv.intake.unwrap().source,
      ready.csv.intake.unwrap().source,
    )
  }
  let fresh = reduce_brief_view(_ => @rabbita.none, New, pending).1
  let stale = csv_join_test_apply(fresh, reply)
  assert_true(stale.csv.intake is None)
  assert_true(stale.csv_join.left is None)
  let bad = csv_join_test_apply(
    pending,
    Joined(pending.generation, Ok(ready.csv.intake.unwrap().to_json())),
  )
  assert_false(bad.pending)
  assert_true(bad.error.unwrap().contains("different joined table"))
  assert_eq(bad.csv.intake.unwrap().source, ready.csv.intake.unwrap().source)
  assert_true(bad.csv_join.left is Some(_))
  assert_true(csv_join_test_apply(bad, UseJoined).pending)
}

///|
test "CSV join immutable adopted lineage survives changed settings and clears on ordinary import" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let adopted = csv_join_adopted()
  let original = csv_join_retained(adopted)
  let changed = csv_join_test_apply(
    csv_join_test_apply(adopted, LeftKey(2)),
    Mode("inner"),
  )
  assert_eq(csv_join_retained(changed), original)
  assert_true(
    csv_join_test_apply(adopted, PinLeft).error.unwrap().contains("Chained"),
  )
  let cleared = csv_join_test_apply(adopted, Clear)
  assert_eq(csv_join_retained(cleared), original)
  let imported = update_csv_view(
      _ => @rabbita.none,
      Imported(100, Ok(csv_join_ready().csv.intake.unwrap().to_json())),
      { ..adopted, pending: true, generation: 100, },
    ).1
  assert_true(imported.csv_join.adopted is None)
  assert_eq(csv_join_retained(imported).length(), 0)
  let mismatched = { ..adopted, csv: csv_join_ready().csv, }
  let rejected = try {
    ignore(csv_join_retained(mismatched))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "CSV join source slot total byte limits and mismatched selection preserve repairable explorer" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let adopted = csv_join_adopted()
  let selected = { ..adopted, csv: { ..adopted.csv, selected: [2], }, }
  let full = {
    ..selected,
    draft: {
      ..selected.draft,
      sources: Array::make(4, brief_fixture_draft().sources[0]),
    },
  }
  let blocked = update_csv_view(_ => @rabbita.none, AddSelected, full).1
  assert_false(blocked.pending)
  assert_true(blocked.error.unwrap().contains("five free source slots"))
  let pending = update_csv_view(_ => @rabbita.none, AddSelected, selected).1
  let mismatch = update_csv_view(
      _ => @rabbita.none,
      Selected(pending.generation, Ok(Json::array([]))),
      pending,
    ).1
  assert_true(mismatch.error.unwrap().contains("does not match"))
  assert_eq(mismatch.csv.selected, [2])
  assert_true(mismatch.csv_join.adopted is Some(_))
  let large : BriefInputSource = {
    ..brief_fixture_draft().sources[0],
    content_hex: brief_text_hex(Array::make(32768, "x").join("")),
  }
  let large_draft = {
    ..selected,
    csv_join: {
      ..selected.csv_join,
      adopted: Some({
        ..selected.csv_join.adopted.unwrap(),
        right: {
          ..selected.csv_join.adopted.unwrap().right,
          content_hex: large.content_hex,
        },
      }),
    },
    draft: { ..selected.draft, sources: [large, large, large], },
  }
  let pending = update_csv_view(_ => @rabbita.none, AddSelected, large_draft).1
  let response = csv_join_test_selection(pending).to_json()
  let over = update_csv_view(
      _ => @rabbita.none,
      Selected(pending.generation, Ok(response)),
      pending,
    ).1
  assert_true(over.error.unwrap().contains("128 KiB"))
  assert_eq(over.draft.sources.length(), 3)
  assert_eq(over.csv.selected, [2])
}

///|
test "CSV join duplicate right keys and explicit key choices block adoption with visible counts" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let ready = csv_join_ready()
  let none = csv_join_test_apply(ready, LeftKey(0))
  assert_true(
    csv_join_test_apply(none, UseJoined).error.unwrap().contains("explicit"),
  )
  let right = csv_join_fixture("duplicates.csv", ["id"], [
    ["001"],
    ["001"],
    [""],
    [""],
  ])
  let duplicate = {
    ..ready,
    csv_join: { ..ready.csv_join, right: Some(right), },
  }
  let duplicate = {
    ..duplicate,
    csv_join: { ..duplicate.csv_join, right_fields: [1], },
  }
  let preview = csv_join_preview(duplicate.csv_join)
  assert_eq(preview.duplicate_right, 1)
  assert_eq(preview.empty_right, 2)
  let blocked = csv_join_test_apply(duplicate, UseJoined)
  assert_false(blocked.pending)
  assert_true(blocked.error.unwrap().contains("duplicate"))
  assert_true(
    qa_test_render({ ..initial_model(), brief: duplicate, }).contains("1 right"),
  )
}

///|
fn csv_join_test_selection(view : BriefView) -> Array[BriefInputSource] {
  let intake = view.csv.intake.unwrap()
  let positions = Array::makei(intake.columns.length(), i => i).filter(i => {
    view.csv.columns.contains(i + 1)
  })
  let selection : Json = {
    "contract_id": "moonfind.csv-selection.v1",
    "source_name": intake.source.name.to_json(),
    "source_digest": csv_source_digest(intake.source.content_hex).to_json(),
    "source_row_count": intake.total_count.to_json(),
    "column_numbers": positions.map(i => i + 1).to_json(),
    "columns": positions.map(i => intake.columns[i]).to_json(),
    "rows": intake.rows
    .filter(row => view.csv.selected.contains(row.record_number))
    .map(row => CsvRow::{
      record_number: row.record_number,
      values: positions.map(i => row.values[i]),
    })
    .to_json(),
  }
  [
    intake.source,
    {
      name: "csv-selection.json",
      origin: "Selected CSV records from " + intake.source.name,
      captured_at: intake.source.captured_at,
      kind: "pasted-text",
      content_hex: brief_text_hex(selection.stringify()),
    },
  ]
}

///|
test "CSV join wrong projection stale digest malformed companion and changed metadata never clear selection" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let adopted = csv_join_adopted()
  let selected = {
    ..adopted,
    csv: { ..adopted.csv, selected: [2], columns: [6], },
  }
  let pending = update_csv_view(_ => @rabbita.none, AddSelected, selected).1
  let valid = csv_join_test_selection(pending)
  let wrong_selection = csv_join_test_selection({
    ..pending,
    csv: { ..pending.csv, selected: [3], columns: [3], },
  })
  let wrong_columns = csv_join_test_selection({
    ..pending,
    csv: { ..pending.csv, columns: [3], },
  })
  let content = brief_source_preview(valid[1].content_hex)
  let digest = csv_source_digest(valid[0].content_hex)
  let cases = [
    wrong_selection[1],
    wrong_columns[1],
    {
      ..valid[1],
      content_hex: brief_text_hex(
        "{\"unexpected\":\"hidden\"," + content[1:].to_owned(),
      ),
    },
    { ..valid[1], content_hex: brief_text_hex("{bad"), },
    {
      ..valid[1],
      content_hex: brief_text_hex(
        content.replace(
          old=digest,
          new="sha256:" + Array::make(64, "0").join(""),
        ),
      ),
    },
    {
      ..valid[1],
      content_hex: brief_text_hex(
        content.replace(
          old="moonfind.csv-selection.v1",
          new="moonfind.csv-selection.v2",
        ),
      ),
    },
    {
      ..valid[1],
      content_hex: brief_text_hex(
        content.replace(old="minutes", new="wrong header"),
      ),
    },
    {
      ..valid[1],
      content_hex: brief_text_hex(content.replace(old="10", new="99")),
    },
    { ..valid[1], name: "wrong.json", },
    { ..valid[1], origin: "wrong source", },
    { ..valid[1], captured_at: "different capture", },
    { ..valid[1], kind: "local-file", },
  ]
  for companion in cases {
    let rejected = update_csv_view(
        _ => @rabbita.none,
        Selected(pending.generation, Ok([valid[0], companion].to_json())),
        pending,
      ).1
    assert_true(rejected.error is Some(_))
    assert_false(rejected.pending)
    assert_eq(rejected.csv.selected, [2])
    assert_eq(rejected.csv.columns, [6])
    assert_eq(rejected.draft.sources.length(), 0)
    assert_true(rejected.csv_join.adopted is Some(_))
  }
  let accepted = update_csv_view(
      _ => @rabbita.none,
      Selected(pending.generation, Ok(valid.to_json())),
      pending,
    ).1
  assert_eq(accepted.error, None)
  assert_eq(accepted.draft.sources.length(), 5)
}

///|
test "CSV join selected right fields narrow wide tables and held field controls cannot cross new pins" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let left = csv_join_fixture(
    "wide-left.csv",
    Array::makei(15, i => "left\{i}"),
    [Array::makei(15, i => if i == 0 { "key" } else { "left value" })],
  )
  let right = csv_join_fixture(
    "wide-right.csv",
    Array::makei(16, i => "right\{i}"),
    [Array::makei(16, i => if i == 0 { "key" } else { "right value \{i}" })],
  )
  let ready = {
    ..csv_join_ready(),
    csv_join: {
      ..empty_csv_join(),
      left: Some(left),
      right: Some(right),
      left_key: 1,
      right_key: 1,
      right_fields: [2],
    },
  }
  assert_eq(csv_join_preview(ready.csv_join).columns.length(), 18)
  let two = csv_join_test_apply(ready, ToggleRightField(ready.generation, 16))
  assert_eq(csv_join_preview(two.csv_join).columns.length(), 19)
  let output = csv_join_output(two.csv_join)
  assert_true(output.provenance.contains("[2,16]"))
  let held = ToggleRightField(two.generation, 2)
  let cleared = csv_join_test_apply(two, Clear)
  let reset = { ..cleared, csv: { ..cleared.csv, intake: Some(right), }, }
  let repinned = csv_join_test_apply(reset, PinRight)
  let repeated = csv_join_test_apply(repinned, PinRight)
  for current in [repinned, repeated] {
    let stale = csv_join_test_apply(current, held)
    assert_eq(stale.csv_join.right_fields, current.csv_join.right_fields)
    assert_eq(stale.generation, current.generation)
  }
  let pending = csv_join_test_apply(two, UseJoined)
  let output = pending.csv_join.pending_output.unwrap()
  let changed = csv_join_test_apply(
    pending,
    ToggleRightField(pending.generation, 2),
  )
  assert_false(changed.pending)
  assert_eq(changed.csv_join.right_fields, [16])
  let stale = csv_join_test_apply(
    changed,
    Joined(pending.generation, Ok(csv_join_reply(output))),
  )
  assert_eq(stale.csv_join.right_fields, [16])
  assert_true(stale.csv_join.adopted is None)
}
