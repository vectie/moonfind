///|
test "BibTeX cards preserve citation identity nested groups authors macros and availability" {
  let cards = @research.parse_bibtex(
    (
      #|% A synthetic reference-manager export
      #|@string{venue = "Lunar " # "Review"}
      #|@preamble{"Do not execute this TeX"}
      #|@comment{Arbitrary {nested} comment}
      #|@Article{García2025,
      #|  title = {Moon {IMU} \{sensor\}},
      #|  author = {García, Ana and {Research and Development Group} and 王, 明},
      #|  year = 2025, journal = venue,
      #|  abstract = "A {quoted \"detail\"} result.",
      #|  keywords = {contact sensing}, doi={10.1234/example}, url={https://example.org/paper}
      #|}
      #|@book(otherKey, title="Other title", date={2024-08-03})
      #|
    ),
  )
  assert_eq(cards.length(), 2)
  assert_eq(cards[0].citation_key, "García2025")
  assert_eq(cards[0].title, "Moon {IMU} \\{sensor\\}")
  assert_eq(cards[0].authors, [
    "García, Ana", "{Research and Development Group}", "王, 明",
  ])
  assert_eq(cards[0].venue, "Lunar Review")
  assert_eq(cards[0].availability, "metadata-and-abstract")
  assert_eq(cards[1].year, "2024")
  assert_eq(cards[1].availability, "metadata-only")
  for query in ["gArCÍA", "IMU", "contact", "2025", "Lunar Review"] {
    assert_eq(@research.filter_bibtex(cards, query).map(r => r.citation_key), [
      "García2025",
    ])
  }
  assert_eq(
    @research.filter_bibtex(cards, "OTHERKEY").map(r => r.record_number),
    [2],
  )
  assert_eq(@research.filter_bibtex(cards, "").length(), 2)
}

///|
test "BibTeX incomplete input and unresolved macros never yield partial cards" {
  for
    broken in [
      "@article{ok,title={Valid}}\n@book{unfinished,title={Oops}", "@book{key,title=missingMacro}",
      "@book{key,title={One}}\n@book{key,title={Two}}", "@comment{No references}",
    ] {
    assert_true((try? @research.parse_bibtex(broken)) is Err(_))
  }
  let cards = @research.parse_bibtex(
    "@misc{empty}\n@book{second,month=jan,title={Second},}",
  )
  assert_eq(cards[0].title, "Untitled reference empty")
  assert_eq(cards[1].record_number, 2)
}
