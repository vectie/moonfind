///|
test "EndNote tagged records retain authors abstract unknown tags BOM CRLF and stable ordinals" {
  let text = "\uFEFF%0 Journal Article\r\n%T 月面 robotics 🌒\r\n%A García, Ana\r\n%A 王, 明\r\n%E Doe, Pat\r\n%D 2025\r\n%J Robotics Letters\r\n%R 10.1234/lunar.1\r\n%U https://example.org/lunar\r\n%X First line.\r\n  第二行.\r\n%K robotics\r\n%K local evidence\r\n%~ Supplied database\r\n%> file:///unopened.pdf\r\n\r\n%0 Book\r\n%T Local references\r\n%A Smith, Jo\r\n%D 2023\r\n\r\n%0 Report\r\n%T Field notes\r\n%A García, Ana\r\n%D 2024"
  let records = @research.parse_endnote(text)
  assert_eq(records.length(), 3)
  assert_eq(records[0].authors, ["García, Ana", "王, 明"])
  assert_eq(records[0].editors, ["Doe, Pat"])
  assert_eq(records[0].abstract_text, "First line.\n第二行.")
  assert_eq(records[0].keywords, "robotics; local evidence")
  assert_eq(records[0].venue, "Robotics Letters")
  assert_eq(records[0].fields[12], { tag: "~", value: "Supplied database", })
  assert_eq(records[0].fields[13], { tag: ">", value: "file:///unopened.pdf", })
  assert_eq(
    @research.filter_endnote_author(records, "GARCÍA").map(r => r.record_number),
    [1, 3],
  )
  assert_eq(@research.filter_endnote_author(records, " ").length(), 3)
}

///|
test "EndNote malformed late record and missing separator fail the complete parse" {
  for
    input in [
      "%0 Book\n%T Good\n\n%0 Book\n%Title Bad\n", "%0 Book\n%T Good\n%0 Book\n%T Missing separator\n",
      "%0 Book\n%T Good\n\n%A No type\n", "%0 \n%T No type value\n", "%0 Book\n\n",
    ] {
    try @research.parse_endnote(input) catch {
      _ => ()
    } noraise {
      _ => fail("Expected whole-file failure")
    }
  }
}

///|
test "EndNote repeated unknown tags empty values and optional metadata stay literal" {
  let cards = @research.parse_endnote(
    "%0 Custom local type\n%T <script>literal</script>\n%Z \n%q opaque one\n%q opaque two\n",
  )
  assert_eq(cards[0].reference_type, "Custom local type")
  assert_eq(cards[0].title, "<script>literal</script>")
  assert_eq(cards[0].authors, [])
  assert_eq(cards[0].fields[2].value, "")
  assert_eq(cards[0].fields[3].value, "opaque one")
  assert_eq(cards[0].fields[4].value, "opaque two")
}
