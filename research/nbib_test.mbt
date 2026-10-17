///|
test "NBIB tags continuation unicode authors DOI and citation projection" {
  let text = "\uFEFFPMID- 99900001\r\nSTAT- MEDLINE\r\nTI  - Moon habitat evidence:\r\n      a synthetic example 🌒.\r\nFAU - García, Ana\r\nAU  - Garcia A\r\nAD  - Unopened research institution\r\nAU  - Lee J\r\nFAU - 王, 明\r\nAU  - Wang M\r\nCN  - Lunar Research Group\r\nDP  - 2025 Jan 12\r\nPT  - Review\r\nPT  - Journal Article\r\nJT  - Example Journal\r\nTA  - Ex J\r\nAID - S123 [pii]\r\nLID - 10.1234/fallback [doi]\r\nAID - 10.1234/lunar.1 [doi]\r\nOT  - lunar habitat\r\nMH  - Robotics\r\nAB  - Supplied first line.\r\n      第二行.\r\nZZ  - unknown one\r\nZZ  - unknown two\r\n"
  let cards = @research.parse_nbib(text)
  assert_eq(cards.length(), 1)
  let card = cards[0]
  assert_eq(card.pmid, "99900001")
  assert_eq(card.title, "Moon habitat evidence: a synthetic example 🌒.")
  assert_eq(card.authors, [
    "García, Ana", "Lee J", "王, 明", "Lunar Research Group",
  ])
  assert_eq(card.year, "2025")
  assert_eq(card.reference_type, "Journal Article")
  assert_eq(card.doi, "10.1234/lunar.1")
  assert_eq(card.venue, "Example Journal")
  assert_eq(card.keywords, "lunar habitat; Robotics")
  assert_eq(card.abstract_text, "Supplied first line. 第二行.")
  assert_eq(card.fields.filter(f => f.tag == "ZZ").map(f => f.value), [
    "unknown one", "unknown two",
  ])
  assert_eq(card.fields.filter(f => f.tag == "AU").map(f => f.value), [
    "Garcia A", "Lee J", "Wang M",
  ])
  assert_eq(card.url, "https://pubmed.ncbi.nlm.nih.gov/99900001/")
}

///|
test "NBIB original record ordinals duplicate PMIDs and author filtering" {
  let cards = @research.parse_nbib(
    "PMID- 42\nTI  - First\nFAU - García, Ana\n\nPMID- 43\nTI  - Other\nAU  - Lee J\nPMID- 42\nTI  - Distinct supplied duplicate\nFAU - García, Ana\n",
  )
  assert_eq(cards.map(r => r.record_number), [1, 2, 3])
  assert_eq(cards.map(r => r.pmid), ["42", "43", "42"])
  assert_eq(
    @research.filter_nbib_author(cards, " GARCÍA ").map(r => r.record_number),
    [1, 3],
  )
  assert_eq(@research.filter_nbib_author(cards, ""), cards)
}

///|
test "NBIB metadata-only missing fields and fallback identifiers" {
  let cards = @research.parse_nbib(
    "PMID- 7\nBTI - A book\nPT  - Book\nFED - Rivera, Ana\nDP  - 2024-2025\nLID - 10.1234/book [doi]\n\nPMID- 8\nAU  - Lee J\nAID - 10.9999/not-tagged\n",
  )
  assert_eq(cards[0].title, "A book")
  assert_eq(cards[0].editors, ["Rivera, Ana"])
  assert_eq(cards[0].year, "2024-2025")
  assert_eq(cards[0].doi, "10.1234/book")
  assert_eq(cards[1].title, "Untitled citation 2")
  assert_eq(cards[1].doi, "")
  assert_eq(cards[1].abstract_text, "")
  for date in ["2024 Dec-2025 Jan", "2024/2025", "2025?", "2024 Dec 2025 Jan"] {
    assert_eq(
      @research.parse_nbib("PMID- 9\nDP  - " + date + "\n")[0].year,
      date,
    )
  }
}

///|
test "NBIB rejects malformed final records and orphan fields without partial result" {
  for
    bad in [
      "", "TI  - Missing PMID\n", "PMID- 0\nTI  - Invalid\n", "PMID- abc\nTI  - Invalid\n",
      "PMID- 1\n", "PMID- 1\n      continued id\nTI  - Bad\n", "PMID- 1\nTI - Bad spacing\n",
      "PMID- 1\nTI  - Good\n\nPMID- 2\ninvalid continuation\n", "PMID- 1\nTI  - Good\n\nTI  - Orphan after separator\n",
    ] {
    try @research.parse_nbib(bad) catch {
      _ => ()
    } noraise {
      _ => fail("Expected NBIB parse failure")
    }
  }
}
