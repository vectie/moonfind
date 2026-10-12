///|
test "CSV handles BOM Unicode quoted multiline escaped quotes and empty values" {
  let table = @research.parse_csv(
    "\uFEFFid,note,amount\r\n001,\"月面, \"\"trial\"\"\r\ncontinued\",10.00\r\n002,,\r\n",
  )
  assert_eq(table.columns, ["id", "note", "amount"])
  assert_eq(table.rows.map(row => row.record_number), [2, 3])
  assert_eq(table.rows[0].values, [
    "001", "月面, \"trial\"\r\ncontinued", "10.00",
  ])
  assert_eq(table.rows[1].values, ["002", "", ""])
  assert_eq(@research.parse_csv("a,b\rx,y\rz,").rows[1].values, ["z", ""])
  assert_eq(@research.parse_csv("only\n").rows.length(), 0)
}

///|
test "CSV filters one column and projects selected source records and columns" {
  let table = @research.parse_csv(
    "id,segment,note,cost\n001,clinic,García,10\n002,school,clinic discussion,20\n003,clinic,Other,30",
  )
  assert_eq(@research.filter_csv(table, "CLINIC", 0).length(), 3)
  assert_eq(
    @research.filter_csv(table, "CLINIC", 2).map(row => row.record_number),
    [2, 4],
  )
  assert_eq(
    @research.filter_csv(table, "GARCÍA", 3).map(row => row.record_number),
    [2],
  )
  let projected = @research.project_csv(table, [4, 2, 2], [3, 1, 3])
  assert_eq(projected.columns, ["id", "note"])
  assert_eq(projected.rows.map(row => row.record_number), [2, 4])
  assert_eq(projected.rows[0].values, ["001", "García"])
  for column in [-1, 5] {
    assert_true((try? @research.filter_csv(table, "", column)) is Err(_))
  }
  for rows in [[], [1], [5]] {
    assert_true((try? @research.project_csv(table, rows, [1])) is Err(_))
  }
  for columns in [[], [0], [5]] {
    assert_true((try? @research.project_csv(table, [2], columns)) is Err(_))
  }
}

///|
test "CSV rejects malformed or unsupported tables with actionable errors" {
  for
    text in [
      "", "\uFEFF", "a,a\nx,y", "a,\nx,y", "a,b\nx", "a\n\"unfinished", "a\n\"x\"junk",
      "a\nx\"y", "a,b\nx,y,z",
    ] {
    assert_true((try? @research.parse_csv(text)) is Err(_))
  }
  assert_true(
    (try? @research.parse_csv(Array::make(33, "header").join(","))) is Err(_),
  )
  assert_true(
    (try? @research.parse_csv("header\n" + Array::make(513, "row").join("\n")))
    is Err(_),
  )
}
