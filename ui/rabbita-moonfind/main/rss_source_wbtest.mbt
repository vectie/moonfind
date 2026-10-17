///|
fn rss_test_xml() -> String {
  let xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<rss version="2.0" xmlns:content="https://example.invalid/extension">
    #|<channel><title>Synthetic research</title><link>https://example.invalid</link><description>Local feed</description>
    #|<item><title>Clinic &amp; field 🌒</title><link>https://example.invalid/?a=1&amp;b=2</link><description><![CDATA[<img src="https://example.invalid/private" onerror="boom()"> Clinic faster]]></description><pubDate>Mon, 12 Oct 2026 18:30:00 +0530</pubDate><author>person@example.invalid (Supplied)</author><guid isPermaLink="false">same-id</guid><category domain="setting">clinic</category><category>pilot</category><content:encoded>Not projected</content:encoded></item>
    #|<item><title>Clinic no difference</title><description/><guid isPermaLink="false">same-id</guid><category domain="setting">clinic</category><enclosure url="https://example.invalid/file" length="9007199254740993" type="audio/mpeg"/></item>
    #|<item><title>School interview</title><pubDate>unvalidated date</pubDate><source url="https://example.invalid/original">Supplied source</source></item>
    #|</channel></rss>
  xml
}

///|
fn rss_test_raw(xml? : String = rss_test_xml()) -> String {
  rss_source_capture(
    "bulletin.rss",
    brief_text_hex(xml),
    "2026-10-13T00:00:00Z",
  )
}

///|
fn rss_test_sources(
  xml? : String = rss_test_xml(),
) -> Array[BriefInputSource] raise {
  match @json.parse(rss_test_raw(xml~)) {
    { "sources": sources, .. } => @json.from_json(sources)
    _ => fail(rss_test_raw(xml~))
  }
}

///|
fn rss_test_model() -> Model {
  let model = initial_model()
  update(
    _ => @rabbita.none,
    BriefAction(RssLoaded(model.brief.generation, rss_test_raw())),
    model,
  ).1
}

///|
test "RSS preserves original XML and supplied metadata missing values duplicate IDs and inert markup" {
  let sources = rss_test_sources()
  assert_eq(sources.length(), 2)
  assert_eq(sources[0].name, "bulletin.rss.txt")
  assert_eq(sources[0].content_hex, brief_text_hex(rss_test_xml()))
  let json = @json.parse(brief_source_preview(sources[1].content_hex))
  guard json is { "items": Array(items), .. } else { fail("No feed items") }
  assert_eq(items.length(), 3)
  assert_true(
    items[0]
    is {
      "title": String("Clinic & field 🌒"),
      "pubDate": String("Mon, 12 Oct 2026 18:30:00 +0530"),
      "author": String("person@example.invalid (Supplied)"),
      "link": String("https://example.invalid/?a=1&b=2"),
      "guid_is_permalink": String("false"),
      "source_line": Number(4, ..),
      ..
    },
  )
  assert_true(
    items[0] is { "description": String(description), .. } &&
    description.contains("<img src="),
  )
  assert_true(
    items[0]
    is { "unprojected_elements": Array([String("content:encoded")]), .. },
  )
  assert_true(
    items[1]
    is {
      "guid": String("same-id"),
      "pubDate": Null,
      "author": Null,
      "description": String(""),
      "enclosure": { "length": String("9007199254740993"), .. },
      ..
    },
  )
  assert_true(
    items[2]
    is {
      "description": Null,
      "guid": Null,
      "guid_is_permalink": Null,
      "source": {
        "title": String("Supplied source"),
        "url": String("https://example.invalid/original"),
        ..
      },
      ..
    },
  )
}

///|
test "RSS actual root dispatch opens searchable JSON feeds selects contradictions projects CSV and retains draft" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = rss_test_model()
  assert_eq(model.brief.error, None)
  assert_eq(model.brief.json_evidence.slot, 2)
  assert_eq(model.brief.json_evidence.pointer, "/items")
  assert_eq(model.brief.json_evidence.table.unwrap().rows.length(), 3)
  let searched = update(
      _ => @rabbita.none,
      BriefAction(JsonEvidence(Search("clinic"))),
      model,
    ).1
  let selected = update(
      _ => @rabbita.none,
      BriefAction(JsonEvidence(SelectMatching)),
      searched,
    ).1
  assert_eq(selected.brief.json_evidence.selected, [1, 2])
  let csv = json_evidence_csv(selected.brief)
  assert_eq(csv.record_count, 2)
  assert_true(csv.text.contains("Clinic & field 🌒"))
  assert_true(csv.text.contains("Clinic no difference"))
  assert_false(csv.text.contains("School interview"))
  assert_true(csv.text.contains("+0530"))
  assert_true(csv.text.contains("\"null\""))
  let extract = json_evidence_export(selected.brief)
  assert_true(extract.contains("/items/0"))
  assert_true(extract.contains("/items/1"))
  let html = qa_test_render(selected)
  assert_true(html.contains("Import saved RSS feed"))
  assert_true(html.contains("&lt;img"))
  assert_false(html.contains("<img src=\"https://example.invalid/private"))
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
test "RSS saved brief protocol reopens both captures and explorer can select imported items again" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = rss_test_model()
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
  assert_eq(saved.brief.error, None)
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
  let chosen = update(
      _ => @rabbita.none,
      BriefAction(JsonEvidence(Source(2))),
      reopened,
    ).1
  let pointed = update(
      _ => @rabbita.none,
      BriefAction(JsonEvidence(Pointer("/items"))),
      chosen,
    ).1
  let explored = update(
      _ => @rabbita.none,
      BriefAction(JsonEvidence(Explore)),
      pointed,
    ).1
  assert_eq(explored.brief.json_evidence.table.unwrap().rows.length(), 3)
}

///|
test "RSS parser rejects unsafe ambiguous malformed XML and unsupported feeds atomically" {
  let good = rss_test_xml()
  let cases = [
    "<!DOCTYPE rss SYSTEM 'https://example.invalid/secret'>" + good,
    "<?xml-stylesheet href='https://example.invalid/style'?>" + good,
    good.replace(old="&amp;", new="&external;"),
    good.replace(old="&amp;", new="&#0;"),
    good.replace(old="&amp;", new="&#xD800;"),
    good.replace(old="</channel>", new="</other>"),
    good + "<rss/>",
    good.replace(
      old="<title>School interview</title>",
      new="<title>School</title><title>duplicate</title>",
    ),
    good.replace(
      old="<title>School interview</title>",
      new="<title><b>nested</b></title>",
    ),
    good.replace(
      old="<rss version=\"2.0\"",
      new="<rss version=\"2.0\" version=\"2.0\"",
    ),
    good.replace(
      old="<rss version=\"2.0\"",
      new="<rss xmlns=\"urn:other\" version=\"2.0\"",
    ),
    good.replace(old="content:encoded", new="unknown:encoded"),
    good.replace(old="isPermaLink=\"false\"", new="isPermaLink=\"yes\""),
    good.replace(
      old="<description/>",
      new="<description>bad ]]> text</description>",
    ),
    good.replace(
      old="<description/>",
      new="<!-- bad -- comment --><description/>",
    ),
    "<feed xmlns='http://www.w3.org/2005/Atom'/>",
    "<rss version='0.91'><channel/></rss>",
    "<rss version='2.0'><channel><item><link>x</link></item></channel></rss>",
    good.replace(old="<description/>", new="<?do something?><description/>"),
  ]
  for xml in cases {
    assert_true(@json.parse(rss_test_raw(xml~)) is { "error": String(_), .. })
  }
  for hex in ["ff", "c0af", "00", "f", "xx", "61".repeat(32769)] {
    assert_true(
      @json.parse(rss_source_capture("input.xml", hex, "now"))
      is { "error": String(_), .. },
    )
  }
  for name in ["../feed.xml", "feed.atom", "x".repeat(141) + ".rss"] {
    assert_true(
      @json.parse(rss_source_capture(name, brief_text_hex(good), "now"))
      is { "error": String(_), .. },
    )
  }
}

///|
test "RSS entities CDATA BOM CRLF defaults and empty feeds have precise subset semantics" {
  let xml = "\u{feff}<rss version='2.0'>\r\n<channel><title>T</title><link>L</link><description>D</description>\r\n<item><title>&lt;&gt;&quot;&apos;&#65;&#x1F312;</title><description><![CDATA[&amp; <b>literal</b>]]></description><guid>not-verified-url</guid></item></channel></rss>"
  let sources = rss_test_sources(xml~)
  assert_eq(sources[0].content_hex, brief_text_hex(xml))
  let parsed = @json.parse(brief_source_preview(sources[1].content_hex))
  assert_true(
    parsed
    is {
      "items": Array(
        [
          {
            "title": String("<>\"'A🌒"),
            "description": String("&amp; <b>literal</b>"),
            "guid_is_permalink": String("true"),
            "source_line": Number(3, ..),
            ..
          },
        ]
      ),
      ..
    },
  )
  let empty = rss_test_sources(
    xml="<rss version='2.0'><channel><title/><link/><description/></channel></rss>",
  )
  assert_eq(json_evidence_table(empty[1], "/items").rows.length(), 0)
}

///|
test "RSS stale repeated pending cancelled and capacity failures do not change the prior source set" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let original = rss_test_model()
  let first = update(_ => @rabbita.none, BriefAction(ChooseRss), original).1
  let second = update(_ => @rabbita.none, BriefAction(ChooseRss), first).1
  let stale = update(
      _ => @rabbita.none,
      BriefAction(RssLoaded(first.brief.generation, rss_test_raw())),
      second,
    ).1
  assert_eq(stale.brief.draft, original.brief.draft)
  let cancelled = update(
      _ => @rabbita.none,
      BriefAction(RssLoaded(second.brief.generation, "{\"sources\":[]}")),
      second,
    ).1
  assert_eq(cancelled.brief.draft, original.brief.draft)
  let fresh = update(_ => @rabbita.none, BriefAction(New), second).1
  let old_reply = update(
      _ => @rabbita.none,
      BriefAction(RssLoaded(second.brief.generation, rss_test_raw())),
      fresh,
    ).1
  assert_eq(old_reply.brief.draft.sources.length(), 0)
  let pending = { ..original, brief: { ..original.brief, pending: true, }, }
  assert_eq(
    update(_ => @rabbita.none, BriefAction(ChooseRss), pending).1.brief.generation,
    pending.brief.generation,
  )
  assert_eq(
    update(
      _ => @rabbita.none,
      BriefAction(RssLoaded(pending.brief.generation, rss_test_raw())),
      pending,
    ).1.brief.draft,
    pending.brief.draft,
  )
  let full = {
    ..original,
    brief: {
      ..original.brief,
      draft: {
        ..original.brief.draft,
        sources: Array::make(7, original.brief.draft.sources[0]),
      },
    },
  }
  let blocked = update(
      _ => @rabbita.none,
      BriefAction(RssLoaded(full.brief.generation, rss_test_raw())),
      full,
    ).1
  assert_true(blocked.brief.error.unwrap().contains("two free source slots"))
  assert_eq(blocked.brief.draft, full.brief.draft)
  let large = {
    ..original.brief.draft.sources[0],
    content_hex: "61".repeat(32768),
  }
  let full_bytes = {
    ..original,
    brief: {
      ..original.brief,
      draft: { ..original.brief.draft, sources: Array::make(4, large), },
    },
  }
  let blocked = update(
      _ => @rabbita.none,
      BriefAction(RssLoaded(full_bytes.brief.generation, rss_test_raw())),
      full_bytes,
    ).1
  assert_true(blocked.brief.error is Some(_))
  assert_eq(blocked.brief.draft, full_bytes.brief.draft)
  let malformed = update(
      _ => @rabbita.none,
      BriefAction(
        RssLoaded(original.brief.generation, rss_test_raw(xml="not RSS")),
      ),
      original,
    ).1
  assert_true(malformed.brief.error is Some(_))
  assert_eq(malformed.brief.draft, original.brief.draft)
}

///|
test "RSS item node depth and structured output limits reject without truncation" {
  let wrap = fn(items : String) {
    "<rss version='2.0'><channel><title>T</title><link>L</link><description>D</description>" +
    items +
    "</channel></rss>"
  }
  for
    xml in [
      wrap("<item><title>T</title></item>".repeat(129)),
      wrap(
        "<item><title>" +
        "x".repeat(16000) +
        "</title><description>" +
        "y".repeat(16000) +
        "</description></item>",
      ),
      wrap(
        "<item><title>T</title><ext>".repeat(17) + "</ext></item>".repeat(17),
      ),
      wrap("<item><title>T</title>" + "<x/>".repeat(4096) + "</item>"),
    ] {
    assert_true(@json.parse(rss_test_raw(xml~)) is { "error": String(_), .. })
  }
}
