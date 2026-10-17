///|
fn bookmark_test_html() -> String {
  let html =
    #|<!DOCTYPE NETSCAPE-Bookmark-file-1>
    #|<!-- Synthetic browser export; no real browsing history. -->
    #|<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
    #|<TITLE>Bookmarks</TITLE><H1>Bookmarks</H1>
    #|<DL><p>
    #| <DT><H3 ADD_DATE="9007199254740993">Research &amp; decisions 🌒</H3>
    #| <DL><p>
    #|  <DT><H3>Clinic / pilots</H3>
    #|  <DL><p>
    #|   <DT><A HREF="https://example.invalid/study?a=1&amp;b=2" ADD_DATE="1700000000" ICON="data:image/png;base64,not-loaded" TAGS="clinic, qualitative">Clinic &lt;img src=x onerror=boom()&gt;</A>
    #|   <DD>Positive pilot; destination still unread.
    #|   <DT><A HREF="https://example.invalid/study?a=1&amp;b=2" LAST_VISIT="unknown">=Conflicting clinic report</A>
    #|   <DD>No difference reported by the supplied bookmark description.
    #|  </DL><p>
    #|  <DT><H3>School</H3>
    #|  <DL><p><DT><A HREF="https://example.invalid/school">School interview</A></DL><p>
    #| </DL><p>
    #| <DT><A HREF="javascript:alert('inert')">Local bookmarklet</A>
    #|</DL><p>
  html + "\n"
}

///|
fn bookmark_test_raw(html? : String = bookmark_test_html()) -> String {
  bookmark_source_capture(
    "reading-queue.html",
    brief_text_hex(html),
    "2026-10-13T07:00:00Z",
  )
}

///|
fn bookmark_test_sources(
  html? : String = bookmark_test_html(),
) -> Array[BriefInputSource] raise {
  match @json.parse(bookmark_test_raw(html~)) {
    { "sources": sources, .. } => @json.from_json(sources)
    _ => fail(bookmark_test_raw(html~))
  }
}

///|
fn bookmark_test_model() -> Model {
  let model = initial_model()
  update(
    _ => @rabbita.none,
    BriefAction(BookmarksLoaded(model.brief.generation, bookmark_test_raw())),
    model,
  ).1
}

///|
test "bookmarks preserve exact original hierarchy duplicate URLs missing metadata and inert content" {
  let sources = bookmark_test_sources()
  assert_eq(sources.length(), 2)
  assert_eq(sources[0].name, "reading-queue.html.txt")
  assert_eq(sources[0].content_hex, brief_text_hex(bookmark_test_html()))
  let payload = @json.parse(brief_source_preview(sources[1].content_hex))
  guard payload
    is { "folders": Array(folders), "bookmarks": Array(records), .. } else {
    fail("Missing queue")
  }
  assert_eq(folders.length(), 3)
  assert_eq(records.length(), 4)
  assert_true(folders[0] is { "add_date": String("9007199254740993"), .. })
  assert_true(
    records[0]
    is {
      "source_bookmark": Number(1, ..),
      "source_line": Number(10, ..),
      "title": String("Clinic <img src=x onerror=boom()>"),
      "url": String("https://example.invalid/study?a=1&b=2"),
      "folder_path": Array(
        [String("Research & decisions 🌒"), String("Clinic / pilots")]
      ),
      "folder_ids": Array([Number(1, ..), Number(2, ..)]),
      "folder_source_lines": Array([Number(6, ..), Number(8, ..)]),
      "unprojected_attributes": Array([String("ICON")]),
      "description": String("Positive pilot; destination still unread."),
      ..
    },
  )
  assert_true(
    records[1]
    is {
      "url": String("https://example.invalid/study?a=1&b=2"),
      "add_date": Null,
      "last_visit": String("unknown"),
      ..
    },
  )
  assert_true(
    records[3]
    is {
      "url": String("javascript:alert('inert')"),
      "folder_path": Array([]),
      "description": Null,
      ..
    },
  )
}

///|
test "bookmarks root workflow selects a folder cohort previews CSV and retains extract on browser reload" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = bookmark_test_model()
  assert_eq(model.brief.error, None)
  assert_eq(model.brief.json_evidence.pointer, "/bookmarks")
  assert_eq(model.brief.json_evidence.table.unwrap().rows.length(), 4)
  let field = update(
      _ => @rabbita.none,
      BriefAction(JsonEvidence(CohortField(0, "/folder_path/1"))),
      model,
    ).1
  let value = update(
      _ => @rabbita.none,
      BriefAction(JsonEvidence(CohortField(1, "\"Clinic / pilots\""))),
      field,
    ).1
  let preview = update(
      _ => @rabbita.none,
      BriefAction(JsonEvidence(PreviewCohort)),
      value,
    ).1
  assert_eq(preview.brief.json_evidence.cohort.unwrap().matched, [1, 2])
  let selected = update(
      _ => @rabbita.none,
      BriefAction(JsonEvidence(SelectCohort("match"))),
      preview,
    ).1
  assert_eq(selected.brief.json_evidence.selected, [1, 2])
  let csv = json_evidence_csv(selected.brief)
  assert_eq(csv.record_count, 2)
  assert_true(csv.text.contains("Clinic / pilots"))
  assert_true(csv.text.contains("'=Conflicting clinic report"))
  assert_false(csv.text.contains("School interview"))
  let html = qa_test_render(selected)
  assert_true(html.contains("Import research bookmarks"))
  assert_true(html.contains("&lt;img"))
  assert_false(html.contains("<img src=x"))
  assert_false(html.contains("href=\"javascript:"))
  let added = update(
      _ => @rabbita.none,
      BriefAction(JsonEvidence(Add)),
      selected,
    ).1
  assert_eq(added.brief.error, None)
  assert_eq(added.brief.draft.sources.length(), 3)
  assert_eq(added.brief.draft.sources[0], model.brief.draft.sources[0])
  assert_eq(initial_model().brief.draft.sources, added.brief.draft.sources)
}

///|
test "bookmarks saved brief protocol reopens exact inputs and queue can be explored again" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = bookmark_test_model()
  let saving = update(_ => @rabbita.none, BriefAction(Save), model).1
  let revision = "revision-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  let reply = brief_fixture_reply(model.brief.draft, revision)
  let saved = update(
      _ => @rabbita.none,
      BriefAction(
        Loaded(
          saving.brief.generation,
          model.brief.draft.brief_id,
          "",
          Ok(reply),
        ),
      ),
      saving,
    ).1
  let opening = update(
      _ => @rabbita.none,
      BriefAction(Open(model.brief.draft.brief_id, revision)),
      saved,
    ).1
  let reopened = update(
      _ => @rabbita.none,
      BriefAction(
        Loaded(
          opening.brief.generation,
          model.brief.draft.brief_id,
          revision,
          Ok(reply),
        ),
      ),
      opening,
    ).1
  assert_eq(reopened.brief.draft.sources, model.brief.draft.sources)
  let source = update(
      _ => @rabbita.none,
      BriefAction(JsonEvidence(Source(2))),
      reopened,
    ).1
  let pointer = update(
      _ => @rabbita.none,
      BriefAction(JsonEvidence(Pointer("/bookmarks"))),
      source,
    ).1
  let explored = update(
      _ => @rabbita.none,
      BriefAction(JsonEvidence(Explore)),
      pointer,
    ).1
  assert_eq(explored.brief.json_evidence.table.unwrap().rows.length(), 4)
}

///|
test "bookmarks reject unsupported malformed ambiguous or unsafe HTML atomically" {
  let good = bookmark_test_html()
  let cases = [
    good.replace(old="NETSCAPE-Bookmark-file-1", new="html"),
    good.replace(old="<TITLE>", new="<SCRIPT>"),
    good.replace(old="</TITLE>", new="</H1>"),
    good.replace(old="charset=UTF-8", new="charset=windows-1252"),
    good.replace(old="&amp;", new="&external;"),
    good.replace(old="&amp;", new="&#0;"),
    good.replace(old="&amp;", new="&#xD800;"),
    good.replace(old="<H3>", new="<H3/><H3>"),
    good.replace(old="HREF=", new="HREF='duplicate' href="),
    good.replace(old="HREF=", new="NOT_HREF="),
    good.replace(old="<DL><p>", new="<DL><p>unexpected"),
    good.replace(old="<DT><H3", new="<DT><A"),
    good + "<DL></DL>",
    good.replace(old="</DL>", new=""),
    good.replace(
      old="<TITLE>Bookmarks",
      new="<TITLE><img src='https://example.invalid/tracker'>",
    ),
  ]
  for html in cases {
    assert_true(
      @json.parse(bookmark_test_raw(html~)) is { "error": String(_), .. },
      msg=html,
    )
  }
  assert_true(
    @json.parse(
      bookmark_source_capture("bad.json", brief_text_hex(good), "now"),
    )
    is { "error": String(_), .. },
  )
  for hex in ["ff", "0", "zz", "00"] {
    assert_true(
      @json.parse(bookmark_source_capture("bad.html", hex, "now"))
      is { "error": String(_), .. },
    )
  }
}

///|
test "bookmarks support lowercase tags quoted attributes separators folder descriptions and exact newline bytes" {
  let html = "\uFEFF<!doctype NETSCAPE-Bookmark-file-1>\r\n<dl><p>\r<dt><h3>Same/name</h3></dt><dd>Folder context\n<dl><p><dt><a href='https://example.invalid/?x=1&y=2' add_date='not a date'>A&#x1F312;&nbsp;B</a></dt><dd>Line one\nLine two</dd><hr></dl><p><dt><h3>Same/name</h3><dl><dt><a href='https://example.invalid/?x=1&y=2'>Again</a></dl></dl>"
  let sources = bookmark_test_sources(html~)
  assert_eq(sources[0].content_hex, brief_text_hex(html))
  let payload = @json.parse(brief_source_preview(sources[1].content_hex))
  assert_true(
    payload
    is {
      "folders": Array([{ "description": String("Folder context"), .. }, _]),
      "bookmarks": Array(
        [
          {
            "title": String("A🌒\u00a0B"),
            "add_date": String("not a date"),
            "description": String("Line one\nLine two"),
            "folder_ids": Array([Number(1, ..)]),
            ..
          },
          { "title": String("Again"), "folder_ids": Array([Number(2, ..)]), .. },
        ]
      ),
      ..
    },
  )
}

///|
test "bookmarks bound nesting counts expanded output source slots and dossier bytes without partial append" {
  let minimal = "<!DOCTYPE NETSCAPE-Bookmark-file-1><DL>"
  let many = StringBuilder()
  many.write_string(minimal)
  for _ in 0..<129 {
    many.write_string("<DT><A HREF='x'>x</A>")
  }
  many.write_string("</DL>")
  assert_true(
    @json.parse(bookmark_test_raw(html=many.to_string()))
    is { "error": String(message), .. } &&
    message.contains("128 bookmarks"),
  )
  let nested = StringBuilder()
  nested.write_string(minimal)
  for _ in 0..<17 {
    nested.write_string("<DT><H3>x</H3><DL>")
  }
  for _ in 0..<18 {
    nested.write_string("</DL>")
  }
  assert_true(
    @json.parse(bookmark_test_raw(html=nested.to_string()))
    is { "error": String(message), .. } &&
    message.contains("16 levels"),
  )
  let big = String::make(32769, 'x')
  assert_true(
    @json.parse(bookmark_test_raw(html=big)) is { "error": String(message), .. } &&
    message.contains("32 KiB"),
  )
  let source = bookmark_test_sources()[0]
  let view = initial_brief_view()
  for
    sources in [
      Array::make(7, source),
      Array::make(4, { ..source, content_hex: String::make(65536, '6'), }),
    ] {
    let loaded = { ..view, draft: { ..view.draft, sources, }, }
    let result = reduce_brief_view(
        _ => @rabbita.none,
        BookmarksLoaded(loaded.generation, bookmark_test_raw()),
        loaded,
      ).1
    assert_eq(result.draft.sources, sources)
    assert_true(result.error.unwrap().contains("two free source slots"))
  }
}

///|
test "bookmarks delayed repeated cancelled failed and pending imports preserve the current brief" {
  let model = initial_model()
  let opened = update(_ => @rabbita.none, BriefAction(ChooseBookmarks), model).1
  assert_eq(opened.brief.generation, model.brief.generation + 1)
  let stale = update(
      _ => @rabbita.none,
      BriefAction(BookmarksLoaded(model.brief.generation, bookmark_test_raw())),
      opened,
    ).1
  assert_eq(stale.brief.draft, model.brief.draft)
  let loaded = update(
      _ => @rabbita.none,
      BriefAction(BookmarksLoaded(opened.brief.generation, bookmark_test_raw())),
      opened,
    ).1
  let repeated = update(
      _ => @rabbita.none,
      BriefAction(BookmarksLoaded(opened.brief.generation, bookmark_test_raw())),
      loaded,
    ).1
  assert_eq(repeated.brief.draft, loaded.brief.draft)
  let pending = { ..loaded, brief: { ..loaded.brief, pending: true, }, }
  assert_eq(
    update(
      _ => @rabbita.none,
      BriefAction(
        BookmarksLoaded(pending.brief.generation, bookmark_test_raw()),
      ),
      pending,
    ).1.brief.draft,
    pending.brief.draft,
  )
  for raw in ["{\"sources\":[]}", "{\"error\":\"read failed\"}", "not JSON"] {
    let result = update(
        _ => @rabbita.none,
        BriefAction(BookmarksLoaded(loaded.brief.generation, raw)),
        loaded,
      ).1
    assert_eq(result.brief.draft, loaded.brief.draft)
    assert_eq(result.brief.json_evidence, loaded.brief.json_evidence)
  }
}

///|
test "bookmarks valueless attributes before and after valued attributes preserve whitespace boundaries" {
  for separator in [" ", "\n", "\r\n", "\t"] {
    for before in [true, false] {
      let folder = if before {
        "PERSONAL_TOOLBAR_FOLDER" + separator + "ADD_DATE = '7'"
      } else {
        "ADD_DATE = '7'" + separator + "PERSONAL_TOOLBAR_FOLDER"
      }
      let anchor = if before {
        "PRIVATE" +
        separator +
        "FOLDED" +
        separator +
        "HREF = 'https://example.invalid'"
      } else {
        "HREF = 'https://example.invalid'" +
        separator +
        "PRIVATE" +
        separator +
        "FOLDED"
      }
      let html = "<!DOCTYPE NETSCAPE-Bookmark-file-1><DL><DT><H3 " +
        folder +
        ">Toolbar</H3><DL><DT><A " +
        anchor +
        ">Entry</A></DL></DL>"
      let sources = bookmark_test_sources(html~)
      let data = @json.parse(brief_source_preview(sources[1].content_hex))
      assert_true(
        data
        is {
          "folders": Array(
            [
              {
                "add_date": String("7"),
                "unprojected_attributes": Array(
                  [String("PERSONAL_TOOLBAR_FOLDER")]
                ),
                ..
              },
            ]
          ),
          "bookmarks": Array(
            [
              {
                "url": String("https://example.invalid"),
                "unprojected_attributes": Array(
                  [String("PRIVATE"), String("FOLDED")]
                ),
                ..
              },
            ]
          ),
          ..
        },
      )
      assert_eq(sources[0].content_hex, brief_text_hex(html))
    }
  }
}

///|
test "bookmarks valueless support still refuses duplicate attributes missing separators and unsupported syntax" {
  let before = bookmark_test_model().brief
  for
    attributes in [
      "PRIVATE private HREF='x'", "HREF='x' HREF", "PRIVATE HREF='x'PRIVATE", "HREF='x'PRIVATE",
      "PRIVATE HREF=x", "PRIVATE = HREF='x'", "PRIVATE $BAD HREF='x'", "HREF='x' PRIVATE/",
    ] {
    let html = "<!DOCTYPE NETSCAPE-Bookmark-file-1><DL><DT><A " +
      attributes +
      ">Entry</A></DL>"
    let raw = bookmark_test_raw(html~)
    assert_true(@json.parse(raw) is { "error": String(_), .. }, msg=attributes)
    let after = reduce_brief_view(
        _ => @rabbita.none,
        BookmarksLoaded(before.generation, raw),
        before,
      ).1
    assert_eq(after.draft, before.draft)
    assert_eq(after.json_evidence, before.json_evidence)
    assert_true(after.error is Some(_))
  }
}
