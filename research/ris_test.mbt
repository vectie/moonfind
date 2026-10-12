///|
test "RIS repeated authors Unicode multiline abstracts and stable filtered record numbers" {
  let ris =
    #|TY  - JOUR
    #|TI  - 月面 robotics 🌒
    #|AU  - García, Ana
    #|AU  - 王, 明
    #|PY  - 2025/08/01
    #|DO  - 10.1234/lunar.1
    #|UR  - https://example.org/lunar
    #|AB  - First abstract line.
    #|      第二行 with Unicode.
    #|ER  -
    #|
    #|TY  - CONF
    #|T1  - Tactile mapping
    #|A1  - Smith, Jo
    #|Y1  - 2024/01/02
    #|N2  - Conference abstract.
    #|ER  -
    #|
    #|TY  - BOOK
    #|TI  - Références locales
    #|AU  - García, Ana
    #|AU  - Müller, Éva
    #|PY  - 2023
    #|AB  - Book abstract.
    #|ER  -
  let references = @research.parse_ris(
    "\uFEFF" + ris.replace_all(old="\n", new="\r\n"),
  )
  assert_eq(references.length(), 3)
  assert_eq(references[0].title, "月面 robotics 🌒")
  assert_eq(references[0].authors, ["García, Ana", "王, 明"])
  assert_eq(references[0].year, "2025")
  assert_eq(
    references[0].abstract_text,
    "First abstract line.\n第二行 with Unicode.",
  )
  assert_eq(references[0].doi, "10.1234/lunar.1")
  assert_eq(references[0].url, "https://example.org/lunar")
  assert_eq(references[1].year, "2024")
  assert_eq(references[1].title, "Tactile mapping")
  assert_eq(references[1].abstract_text, "Conference abstract.")
  assert_eq(
    @research.filter_ris_author(references, "gArCÍa").map(r => r.record_number),
    [1, 3],
  )
  assert_eq(@research.filter_ris_author(references, "王").length(), 1)
  assert_eq(@research.filter_ris_author(references, "missing").length(), 0)
}

///|
test "RIS requires a complete bibliography and supplies a readable missing title" {
  assert_true((try? @research.parse_ris("TY  - JOUR\nTI  - Partial")) is Err(_))
  assert_true((try? @research.parse_ris("")) is Err(_))
  let cards = @research.parse_ris("TY  - JOUR\nER  -")
  assert_eq(cards[0].title, "Untitled reference 1")
  assert_eq(cards[0].authors, [])
}
