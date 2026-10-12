///|
fn csv_numeric_fixture(
  values? : Array[String] = [
    "10", " 20.5 ", "", "unknown", "-2", "1e1", "0", "1,200", "<script>月</script>",
  ],
) -> BriefView {
  let original = "value,group\n" +
    values
    .mapi((i, value) => {
      "\"" +
      value.replace(old="\"", new="\"\"") +
      "\"," +
      (if i % 2 == 0 { "keep" } else { "omit" })
    })
    .join("\n") +
    "\n"
  let source : BriefInputSource = {
    name: "measurements.csv",
    origin: "Synthetic local measurement table",
    captured_at: "2026-10-10T00:00:00Z",
    kind: "local-file",
    content_hex: brief_text_hex(original),
  }
  let payload : Json = {
    "source": ToJson::to_json(source),
    "columns": ["value", "group"],
    "rows": values
    .mapi((i, value) => CsvRow::{
      record_number: i + 2,
      values: [value, if i % 2 == 0 { "keep" } else { "omit" }],
    })
    .to_json(),
    "total_count": values.length(),
  }
  update_csv_view(_ => @rabbita.none, Imported(12, Ok(payload)), {
    ..initial_brief_view(),
    generation: 12,
    pending: true,
  }).1
}

///|
fn csv_numeric_apply(view : BriefView, action : CsvMsg) -> BriefView {
  update_csv_view(_ => @rabbita.none, action, view).1
}

///|
fn csv_numeric_ready(
  values? : Array[String] = [
    "10", " 20.5 ", "", "unknown", "-2", "1e1", "0", "1,200", "<script>月</script>",
  ],
) -> BriefView {
  csv_numeric_apply(csv_numeric_fixture(values~), NumericColumn(1))
}

///|
extern "js" fn csv_numeric_evidence(name : String, content : String) -> Unit =
  #|(name,content) => {if(process.env.MOONFIND_NUMERIC_EVIDENCE) process.getBuiltinModule('fs').writeFileSync(process.env.MOONFIND_NUMERIC_EVIDENCE+'/'+name,content);}

///|
test "numeric decimal grammar is complete explicit locale independent and range checked" {
  for
    pair in [
      ("0", 0.0),
      ("-0", 0.0),
      ("+12", 12.0),
      (".5", 0.5),
      ("1.", 1.0),
      ("-.25", -0.25),
      ("0010.00", 10.0),
      ("1E+2", 100.0),
      ("-2e-1", -0.2),
      (" \t\r\n3.25\t ", 3.25),
    ] {
    let cell = csv_numeric_parse(pair.0, 17)
    assert_eq(cell.value, Some(pair.1))
    assert_eq(cell.original, pair.0)
    assert_eq(cell.record_number, 17)
    assert_eq(cell.issue, "")
  }
  for text in ["", " \t\r\n"] {
    assert_eq(csv_numeric_parse(text, 2).issue, "blank")
  }
  for
    text in [
      "NaN", "Infinity", "-Infinity", "0x10", "12px", "1,000", "1,5", "$12", "12%",
      "1 2", "1_000", "1e", ".", "+", "-", "1.2.3", "1e+", "１２", "−2", "\u{a0}2",
      "2\u{a0}", "1\n2", "<script>1</script>",
    ] {
    assert_eq(csv_numeric_parse(text, 2).issue, "not_decimal")
  }
  assert_eq(csv_numeric_parse("1e309", 2).issue, "out_of_range")
  assert_eq(csv_numeric_parse("1e-999", 2).issue, "underflow_to_zero")
  assert_eq(csv_numeric_parse("0e-999", 2).value, Some(0.0))
  assert_true(csv_numeric_parse("5e-324", 2).value is Some(_))
  assert_true(csv_numeric_parse("1.7976931348623157e308", 2).value is Some(_))
}

///|
test "numeric summary excludes blanks and invalid cells without zero filling" {
  let initial = csv_numeric_fixture()
  assert_eq(initial.csv.numeric_column, 0)
  let error = csv_numeric_export(initial.csv) catch { error => "\{error}" }
  assert_true(error.contains("Choose a numeric column"))
  let view = csv_numeric_apply(initial, NumericColumn(1))
  let result = csv_numeric_summary(view.csv)
  assert_eq(result.numeric_count, 5)
  assert_eq(result.blank_count, 1)
  assert_eq(result.invalid_count, 3)
  assert_eq(result.minimum, Some(-2.0))
  assert_eq(result.maximum, Some(20.5))
  assert_eq(result.sum, Some(38.5))
  assert_eq(result.mean, Some(7.7))
  assert_eq(csv_numeric_details(result, "numeric"), [2, 3, 6, 7, 8])
  assert_eq(csv_numeric_details(result, "blank"), [4])
  assert_eq(csv_numeric_details(result, "invalid"), [5, 9, 10])
  assert_eq(csv_numeric_details(result, "minimum"), [6])
  assert_eq(csv_numeric_details(result, "maximum"), [3])
  assert_eq(csv_numeric_apply(view, NumericColumn(3)).csv.numeric_column, 1)
  assert_eq(csv_numeric_apply(view, NumericColumn(-1)).csv.numeric_column, 1)
  assert_eq(
    csv_numeric_apply(view, NumericScope("bad")).csv.numeric_scope,
    "all",
  )
  assert_eq(
    csv_numeric_apply(view, NumericDetail("bad")).csv.numeric_detail,
    "numeric",
  )
}

///|
test "numeric compensated sum ties zero rows and overflow remain honest" {
  let cancel = csv_numeric_summary(
    csv_numeric_ready(values=["1e16", "1", "-1e16"]).csv,
  )
  assert_eq(cancel.sum, Some(1.0))
  assert_eq(cancel.mean, Some(1.0 / 3.0))
  let ties = csv_numeric_summary(
    csv_numeric_ready(values=[".5", "0.50", "-0", "0e3"]).csv,
  )
  assert_eq(csv_numeric_details(ties, "maximum"), [2, 3])
  assert_eq(csv_numeric_details(ties, "minimum"), [4, 5])
  let overflow = csv_numeric_summary(
    csv_numeric_ready(values=["1e308", "1e308", "-1e308"]).csv,
  )
  assert_eq(overflow.numeric_count, 3)
  assert_eq(overflow.sum, None)
  assert_eq(overflow.mean, None)
  assert_eq(overflow.minimum, Some(-1.0e308))
  assert_true(overflow.arithmetic_issue.contains("overflowed"))
  for values in [[], ["", "unknown"]] {
    let empty = csv_numeric_summary(csv_numeric_ready(values~).csv)
    assert_eq(empty.numeric_count, 0)
    assert_eq(empty.sum, None)
    assert_eq(empty.mean, None)
    assert_eq(empty.minimum, None)
    assert_eq(empty.maximum, None)
    assert_true(empty.arithmetic_issue.contains("No numeric"))
  }
  let zero = csv_numeric_summary(csv_numeric_ready(values=["0", "-0"]).csv)
  assert_eq(zero.sum, Some(0.0))
  assert_eq(zero.mean, Some(0.0))
  assert_eq(zero.arithmetic_issue, "")
}

///|
test "numeric scopes respond to search selection and preserve projections" {
  let view = csv_numeric_apply(csv_numeric_ready(), SearchColumn(2))
  let view = csv_numeric_apply(view, Filter(" KEEP "))
  let view = csv_numeric_apply(view, ToggleColumn(1))
  let view = csv_numeric_apply(csv_numeric_apply(view, Toggle(3)), Toggle(6))
  let matching = csv_numeric_apply(view, NumericScope("matching"))
  assert_eq(csv_numeric_summary(matching.csv).cells.map(c => c.record_number), [
    2, 4, 6, 8, 10,
  ])
  assert_eq(csv_numeric_summary(matching.csv).sum, Some(8.0))
  let selected = csv_numeric_apply(matching, NumericScope("selected"))
  assert_eq(csv_numeric_summary(selected.csv).cells.map(c => c.record_number), [
    3, 6,
  ])
  assert_eq(csv_numeric_summary(selected.csv).sum, Some(18.5))
  let selected = csv_numeric_apply(selected, NumericDetail("maximum"))
  assert_eq(selected.csv.selected, [3, 6])
  assert_eq(selected.csv.columns, [2])
  assert_eq(selected.csv.query, " KEEP ")
  assert_eq(
    csv_numeric_summary(csv_numeric_apply(selected, Filter("absent")).csv).sum,
    Some(18.5),
  )
  let empty = csv_numeric_apply(
    csv_numeric_apply(matching, Filter("absent")),
    NumericScope("matching"),
  )
  assert_eq(csv_numeric_summary(empty.csv).cells, [])
  let all = csv_numeric_apply(empty, NumericScope("all"))
  assert_eq(csv_numeric_summary(all.csv).sum, Some(38.5))
  assert_eq(
    csv_numeric_summary(csv_numeric_apply(selected, ClearRows).csv).cells,
    [],
  )
  assert_eq(
    csv_numeric_summary(csv_numeric_apply(selected, NumericColumn(2)).csv).invalid_count,
    2,
  )
}

///|
test "numeric pending reset and stale callback behavior" {
  let view = csv_numeric_ready()
  let pending = { ..view, pending: true, generation: 13, }
  for
    action in [
      NumericColumn(2),
      NumericScope("selected"),
      NumericDetail("invalid"),
      DownloadNumeric,
    ] {
    let after = csv_numeric_apply(pending, action)
    assert_eq(after.csv.numeric_column, 1)
    assert_eq(after.csv.numeric_scope, "all")
    assert_eq(after.csv.numeric_detail, "numeric")
    assert_eq(after.error, pending.error)
  }
  let stale = csv_numeric_apply(pending, Imported(12, Ok(Json::null())))
  assert_eq(csv_numeric_summary(stale.csv), csv_numeric_summary(view.csv))
  let (_, fresh) = update_brief_view(_ => @rabbita.none, New, pending)
  let stale = csv_numeric_apply(fresh, Imported(13, Ok(Json::null())))
  assert_eq(stale.csv.numeric_column, 0)
  assert_true(stale.csv.intake is None)
  let reset = csv_numeric_fixture()
  assert_eq(reset.csv.numeric_column, 0)
  assert_eq(reset.csv.numeric_scope, "all")
}

///|
test "numeric full bounded corpus has complete source membership" {
  let view = csv_numeric_ready(values=Array::makei(512, i => i.to_string()))
  let result = csv_numeric_summary(view.csv)
  assert_eq(result.numeric_count, 512)
  assert_eq(result.sum, Some(130816.0))
  assert_eq(result.mean, Some(255.5))
  assert_eq(result.cells[511].record_number, 513)
  assert_eq(csv_numeric_details(result, "numeric").length(), 512)
  assert_eq(csv_numeric_details(result, "maximum"), [513])
}

///|
test "numeric export and escaped render expose original records and unavailable values" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = csv_numeric_apply(csv_numeric_ready(), NumericDetail("invalid"))
  let text = csv_numeric_export(view.csv)
  let json = @json.parse(text)
  assert_true(
    json
    is {
      "contract_id": String("moonfind.csv-numeric-summary.v1"),
      "scope": String("all"),
      ..
    },
  )
  guard json
    is { "source": source, "summary": { "sum": Number(38.5, ..), .. }, .. } else {
    fail("Missing exact summary")
  }
  let source : BriefInputSource = @json.from_json(source)
  assert_eq(source, view.csv.intake.unwrap().source)
  let html = qa_test_render({ ..initial_model(), brief: view, })
  assert_true(html.contains("Numeric column summary and source records"))
  assert_true(html.contains("9 scoped rows"))
  assert_true(html.contains("&lt;script&gt;月&lt;/script&gt;"))
  assert_false(html.contains("<script>月</script>"))
  assert_true(html.contains("<td>10</td>"))
  assert_true(html.contains("not_decimal"))
  let blank = qa_test_render({
    ..initial_model(),
    brief: csv_numeric_ready(values=[]),
  })
  assert_true(blank.contains("Sum: unavailable"))
  assert_true(blank.contains("No numeric values"))
  csv_numeric_evidence(
    "measurements.csv",
    brief_source_preview(source.content_hex),
  )
  csv_numeric_evidence("all-rows.json", text)
  csv_numeric_evidence("rendered-invalid.html", html)
  let selected = csv_numeric_apply(
    csv_numeric_apply(view, Toggle(3)),
    NumericScope("selected"),
  )
  csv_numeric_evidence("selected-rows.json", csv_numeric_export(selected.csv))
  let selected = csv_numeric_apply(
    csv_numeric_apply(selected, SearchColumn(2)),
    Filter("keep"),
  )
  assert_true(
    qa_test_render({
      ..initial_model(),
      brief: csv_numeric_apply(selected, NumericDetail("numeric")),
    }).contains("<td>3</td>"),
  )
  let filtered = csv_numeric_apply(selected, NumericScope("matching"))
  csv_numeric_evidence("matching-rows.json", csv_numeric_export(filtered.csv))
}

///|
extern "js" fn csv_numeric_blob_fixture(mode : String) -> Unit =
  #|mode => {
  #| const saved={document:Object.getOwnPropertyDescriptor(globalThis,'document'),create:URL.createObjectURL,revoke:URL.revokeObjectURL};
  #| globalThis.__numericSaved=saved; globalThis.__numericDownload={name:'',clicked:false};
  #| URL.createObjectURL=blob=>{if(mode==='create') throw Error('fixture create'); globalThis.__numericDownload.blob=blob; return 'blob:numeric';};
  #| URL.revokeObjectURL=()=>{};
  #| Object.defineProperty(globalThis,'document',{configurable:true,value:{body:{appendChild(){}},createElement(){return {href:'',download:'',remove(){},click(){if(mode==='click') throw Error('fixture click'); globalThis.__numericDownload.name=this.download;globalThis.__numericDownload.clicked=true;}}}}});
  #|}

///|
extern "js" fn csv_numeric_blob_verify(expected : String) -> String =
  #|expected => {
  #| const got=globalThis.__numericDownload;
  #| if(!got.clicked || got.name!=='moonfind-csv-numeric-summary.json' || !(got.blob instanceof Blob) || got.blob.type!=='application/json;charset=utf-8') return 'download metadata mismatch';
  #| const pending=got.blob.text().then(text=>{
  #|   if(text!==expected) throw Error('actual Blob bytes differ');
  #|   if(process.env.MOONFIND_NUMERIC_EVIDENCE){const fs=process.getBuiltinModule('fs');const out=process.env.MOONFIND_NUMERIC_EVIDENCE;fs.writeFileSync(out+'/'+got.name,text);fs.writeFileSync(out+'/download-receipt.json',JSON.stringify({filename:got.name,mime:got.blob.type,bytes:got.blob.size,sha256:process.getBuiltinModule('crypto').createHash('sha256').update(text).digest('hex'),real_blob:true},null,2));}
  #| });
  #| pending.catch(e=>{console.error(e);process.exitCode=1;}); return '';
  #|}

///|
extern "js" fn csv_numeric_blob_restore() -> Unit =
  #|() => {const old=globalThis.__numericSaved;if(old.document)Object.defineProperty(globalThis,'document',old.document);else delete globalThis.document;URL.createObjectURL=old.create;URL.revokeObjectURL=old.revoke;delete globalThis.__numericSaved;delete globalThis.__numericDownload;}

///|
test "numeric actual Blob download metadata bytes failure and retry" {
  let view = csv_numeric_apply(
    csv_numeric_apply(csv_numeric_ready(), Toggle(3)),
    NumericScope("selected"),
  )
  for mode in ["create", "click", "ok"] {
    csv_numeric_blob_fixture(mode)
    let after = csv_numeric_apply(view, DownloadNumeric)
    assert_eq(after.csv.selected, view.csv.selected)
    assert_eq(after.csv.intake.unwrap().source, view.csv.intake.unwrap().source)
    assert_eq(csv_numeric_summary(after.csv), csv_numeric_summary(view.csv))
    if mode == "ok" {
      assert_eq(after.error, None)
      assert_eq(csv_numeric_blob_verify(csv_numeric_export(view.csv)), "")
    } else {
      assert_true(
        after.error.unwrap().contains("Numeric summary download failed"),
      )
    }
    csv_numeric_blob_restore()
  }
}

///|
test "numeric export keeps explicit null fields for empty excluded and overflow cases" {
  let empty_text = csv_numeric_export(csv_numeric_ready(values=[]).csv)
  let empty = @json.parse(empty_text)
  assert_true(
    empty
    is {
      "summary": {
        "cells": Array([]),
        "minimum": Null,
        "maximum": Null,
        "sum": Null,
        "mean": Null,
        ..
      },
      ..
    },
  )
  let excluded_text = csv_numeric_export(
    csv_numeric_ready(values=["", "unknown", "1e309", "1e-999"]).csv,
  )
  let excluded = @json.parse(excluded_text)
  guard excluded
    is {
      "summary": {
        "cells": Array(cells),
        "minimum": Null,
        "maximum": Null,
        "sum": Null,
        "mean": Null,
        ..
      },
      ..
    } else {
    fail("Unavailable stats must be present as null")
  }
  assert_eq(cells.length(), 4)
  for cell in cells {
    assert_true(cell is { "value": Null, .. })
  }
  let overflow_text = csv_numeric_export(
    csv_numeric_ready(values=["1e308", "1e308"]).csv,
  )
  let overflow = @json.parse(overflow_text)
  assert_true(
    overflow
    is {
      "summary": {
        "numeric_count": Number(2, ..),
        "minimum": Number(1.0e308, ..),
        "maximum": Number(1.0e308, ..),
        "sum": Null,
        "mean": Null,
        ..
      },
      ..
    },
  )
  let zero = @json.parse(
    csv_numeric_export(csv_numeric_ready(values=["0", ""]).csv),
  )
  assert_true(
    zero
    is {
      "summary": {
        "minimum": Number(0, ..),
        "maximum": Number(0, ..),
        "sum": Number(0, ..),
        "mean": Number(0, ..),
        ..
      },
      ..
    },
  )
  csv_numeric_evidence("empty-rows.json", empty_text)
  csv_numeric_evidence("excluded-rows.json", excluded_text)
  csv_numeric_evidence("overflow-rows.json", overflow_text)
}
