///|
test "CSL JSON metadata preserves typed identity names dates and source positions" {
  let cards = @research.parse_csl(
    "\uFEFF" +
    (
      #|[
      #| {"id":"zotero/一","type":"article-journal","citation-key":"García2025",
      #| "title":"Moon <i>IMU</i> 🌒","author":[{"family":"García","given":"Ana"},
      #| {"literal":"Research and Development Group"},{"family":"Beethoven","given":"Ludwig","non-dropping-particle":"van","suffix":"Jr."}],
      #| "issued":{"date-parts":[[2025,6,1],[2025,7,2]]},"container-title":"Lunar Review",
      #| "abstract":"First line.\n第二行","keyword":"contact","DOI":"10.1234/example","URL":"javascript:alert(1)"},
      #| {"id":42,"type":"book","editor":[{"family":"王","given":"明"}],"issued":{"literal":"forthcoming"},"publisher":"Local Press"},
      #| {"id":"42","type":"report","issued":{"raw":"2024~"}}
      #|]
    ),
  )
  assert_eq(cards.length(), 3)
  assert_eq(cards[0].item_id, "zotero/一")
  assert_eq(cards[0].item_id_kind, "string")
  assert_eq(cards[1].item_id, "42")
  assert_eq(cards[1].item_id_kind, "number")
  assert_eq(cards[2].item_id, "42")
  assert_eq(cards[2].item_id_kind, "string")
  assert_eq(cards[0].authors, [
    "García, Ana", "Research and Development Group", "van Beethoven, Ludwig, Jr.",
  ])
  assert_eq(cards[0].issued, "2025-6-1 / 2025-7-2")
  assert_eq(cards[0].year, "2025")
  assert_eq(cards[0].title, "Moon <i>IMU</i> 🌒")
  assert_eq(cards[0].availability, "metadata-and-abstract")
  assert_eq(cards[1].title, "Untitled reference 42")
  assert_eq(cards[1].citation_key, "42")
  assert_eq(cards[1].editors, ["王, 明"])
  assert_eq(cards[1].issued, "forthcoming")
  assert_eq(cards[1].year, "")
  assert_eq(cards[1].venue, "Local Press")
  assert_eq(cards[1].availability, "metadata-only")
  assert_eq(cards[2].issued, "2024~")
  for
    query in [
      "GARCÍA", "2025", "contact", "Lunar Review", "10.1234", "zotero/一",
    ] {
    assert_eq(@research.filter_csl(cards, query).map(r => r.record_number), [1])
  }
  assert_eq(@research.filter_csl(cards, "王").map(r => r.record_number), [2])
  assert_eq(
    @research.filter_csl(cards, "forthcoming").map(r => r.record_number),
    [2],
  )
  assert_eq(@research.filter_csl(cards, "").length(), 3)
}

///|
test "CSL JSON rejects malformed exports without returning partial cards" {
  for
    broken in [
      "[]", "{}", "{\"items\":[]}", "[{\"id\":\"one\",\"type\":\"book\"},null]",
      "[{\"id\":\"one\"}]", "[{\"type\":\"book\"}]", "[{\"id\":\"one\",\"type\":\"book\"},{\"id\":\"one\",\"type\":\"book\"}]",
      "[{\"id\":{},\"type\":\"book\"}]", "[{\"id\":\" \",\"type\":\"book\"}]", "[{\"id\":1,\"type\":\"book\",\"title\":1}]",
      "[{\"id\":1,\"type\":\"book\",\"author\":[\"A Person\"]}]", "[{\"id\":1,\"type\":\"book\",\"editor\":[{}]}]",
      "[{\"id\":1,\"type\":\"book\",\"issued\":\"2025\"}]", "[{\"id\":1,\"type\":\"book\",\"issued\":{\"date-parts\":[]}}]",
      "[{\"id\":1,\"type\":\"book\",\"issued\":{\"date-parts\":[[2025,{}]]}}]",
    ] {
    assert_true((try? @research.parse_csl(broken)) is Err(_), msg=broken)
  }
  let error = try {
    ignore(@research.parse_csl("[{\"id\":1,\"type\":\"book\"}, {}]"))
    "unexpected success"
  } catch {
    error => "\{error}"
  }
  assert_true(error.contains("Record 2"))
}

///|
test "CSL numeric IDs retain their exact text beyond JavaScript safe integers" {
  let cards = @research.parse_csl(
    "[{\"id\":9007199254740993,\"type\":\"book\"}]",
  )
  assert_eq(cards[0].item_id, "9007199254740993")
  assert_eq(cards[0].citation_key, "9007199254740993")
  assert_eq(cards[0].item_id_kind, "number")
}
