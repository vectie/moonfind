///|
// This literal is independently authored and matched byte-value-for-byte-value
// to fixtures/csv-bibliography.expected.csl.json by the Node contract check.
// The native parser test itself must still run during native qualification.
test "CSV bibliography output is ordinary literal-name literal-date CSL" {
  let input =
    #|[
    #| {"id":"001","type":"article-journal","title":"Contact, sensing 🌒",
    #|  "author":[{"literal":"García, Ana; 王 明"}],
    #|  "issued":{"literal":"2025-06 / forthcoming"},
    #|  "container-title":"Synthetic Review","DOI":"10.1234/example",
    #|  "URL":"https://example.org/one","abstract":"First line.\r\n第二行 with \"quotes\"."},
    #| {"id":"9007199254740993","type":"report","title":"Local research notes",
    #|  "author":[{"literal":"Research and Development Group"}],
    #|  "issued":{"literal":"circa 2024?"},"container-title":"Synthetic Lab",
    #|  "URL":"javascript:alert(1)"}
    #|]
  let cards = @research.parse_csl(input)
  assert_eq(cards.length(), 2)
  assert_eq(cards[0].record_number, 1)
  assert_eq(cards[0].item_id, "001")
  assert_eq(cards[0].item_id_kind, "string")
  assert_eq(cards[0].citation_key, "001")
  assert_eq(cards[0].authors, ["García, Ana; 王 明"])
  assert_eq(cards[0].issued, "2025-06 / forthcoming")
  assert_eq(cards[0].year, "")
  assert_eq(cards[0].venue, "Synthetic Review")
  assert_eq(cards[0].availability, "metadata-and-abstract")
  assert_eq(cards[0].abstract_text, "First line.\r\n第二行 with \"quotes\".")
  assert_eq(cards[1].record_number, 2)
  assert_eq(cards[1].item_id, "9007199254740993")
  assert_eq(cards[1].item_id_kind, "string")
  assert_eq(cards[1].issued, "circa 2024?")
  assert_eq(cards[1].year, "")
  assert_eq(cards[1].availability, "metadata-only")
  assert_eq(cards[1].url, "javascript:alert(1)")
}
