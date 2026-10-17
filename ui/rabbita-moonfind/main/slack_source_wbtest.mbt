///|
fn slack_fixture_capture() -> String {
  slack_source_capture(
    "channel.json",
    brief_text_hex(
      "[{\"type\":\"message\",\"ts\":\"1700000000.000001\",\"user\":\"U_SYNTHETIC\",\"text\":\"Offline finding <script> inert\"}]",
    ),
    "2026-10-12T00:00:00Z",
  )
}

///|
test "slack source actual decoder reducer searchable preview and browser draft retention" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = initial_model()
  let (_, captured) = update(
    _ => @rabbita.none,
    BriefAction(FilesLoaded(model.brief.generation, slack_fixture_capture())),
    model,
  )
  assert_true(captured.brief.error is None)
  assert_eq(captured.brief.draft.sources.length(), 2)
  assert_eq(captured.brief.draft.sources[0].name, "channel.json")
  assert_eq(captured.brief.draft.sources[1].name, "channel.json.conversation.txt")
  let (_, searched) = update(
    _ => @rabbita.none,
    BriefAction(SearchQuery("Offline finding")),
    captured,
  )
  let hits = dossier_search(searched.brief).hits
  assert_eq(hits.length(), 2)
  assert_eq(hits[1].slot, 2)
  let html = qa_test_render(searched)
  assert_true(html.contains("Import Slack channel export (.json)"))
  assert_true(html.contains("&lt;script&gt;"))
  assert_false(html.contains("<script>"))
  let restored = initial_model()
  assert_eq(restored.brief.draft.sources, captured.brief.draft.sources)
}

///|
test "slack capture failures capacity stale callbacks and pending state preserve prior brief" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = initial_model()
  let (_, failed) = update(
    _ => @rabbita.none,
    BriefAction(
      FilesLoaded(
        model.brief.generation,
        slack_source_capture(
          "only-html.eml",
          brief_text_hex("Content-Type: text/html\n\n<b>Not extracted</b>"),
          "now",
        ),
      ),
    ),
    model,
  )
  assert_true(failed.brief.error is Some(_))
  assert_eq(failed.brief.draft, model.brief.draft)
  let source = brief_fixture_draft().sources[0]
  let full = {
    ..model,
    brief: {
      ..model.brief,
      draft: { ..model.brief.draft, sources: Array::make(7, source), },
    },
  }
  let (_, blocked) = update(
    _ => @rabbita.none,
    BriefAction(FilesLoaded(full.brief.generation, slack_fixture_capture())),
    full,
  )
  assert_eq(blocked.brief.draft, full.brief.draft)
  assert_true(blocked.brief.error is Some(_))
  let (_, stale) = update(
    _ => @rabbita.none,
    BriefAction(
      FilesLoaded(model.brief.generation - 1, slack_fixture_capture()),
    ),
    model,
  )
  assert_eq(stale.brief.draft, model.brief.draft)
  let pending = { ..model, brief: { ..model.brief, pending: true, }, }
  let (_, ignored) = update(
    _ => @rabbita.none,
    BriefAction(FilesLoaded(pending.brief.generation, slack_fixture_capture())),
    pending,
  )
  assert_eq(ignored.brief.draft, pending.brief.draft)
  let (_, choosing) = update(
    _ => @rabbita.none,
    BriefAction(ChooseSlackExport),
    pending,
  )
  assert_eq(choosing.brief.draft, pending.brief.draft)
}

///|
test "slack sources survive save and reopen protocol without asserting native host verification" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = initial_model()
  let (_, captured) = update(
    _ => @rabbita.none,
    BriefAction(FilesLoaded(model.brief.generation, slack_fixture_capture())),
    model,
  )
  let (_, saving) = update(_ => @rabbita.none, BriefAction(Save), captured)
  assert_true(saving.brief.pending)
  let revision = "revision-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  let reply = brief_fixture_reply(captured.brief.draft, revision)
  let (_, saved) = update(
    _ => @rabbita.none,
    BriefAction(
      Loaded(
        saving.brief.generation,
        captured.brief.draft.brief_id,
        "",
        Ok(reply),
      ),
    ),
    saving,
  )
  assert_eq(saved.brief.draft.sources, captured.brief.draft.sources)
  let (_, opening) = update(
    _ => @rabbita.none,
    BriefAction(Open(captured.brief.draft.brief_id, revision)),
    saved,
  )
  let (_, reopened) = update(
    _ => @rabbita.none,
    BriefAction(
      Loaded(
        opening.brief.generation,
        captured.brief.draft.brief_id,
        revision,
        Ok(reply),
      ),
    ),
    opening,
  )
  assert_eq(reopened.brief.draft.sources, captured.brief.draft.sources)
}

///|
test "slack thread context remains searchable and source restrictions remain unchanged" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = initial_model()
  let restricted = {
    ..model,
    brief: {
      ..model.brief,
      draft: { ..model.brief.draft, source_restrictions: "Internal supplied export only; no network", },
    },
  }
  let raw = slack_source_capture(
    "synthetic.json",
    brief_text_hex(
      "[{\"type\":\"message\",\"ts\":\"1700000001.000001\",\"thread_ts\":\"1700000000.000001\",\"text\":\"orphan reply\"}]",
    ),
    "now",
  )
  let (_, captured) = update(
    _ => @rabbita.none,
    BriefAction(FilesLoaded(restricted.brief.generation, raw)),
    restricted,
  )
  assert_eq(captured.brief.draft.source_restrictions, restricted.brief.draft.source_restrictions)
  let (_, searched) = update(
    _ => @rabbita.none,
    BriefAction(SearchQuery("Parent missing")),
    captured,
  )
  let hits = dossier_search(searched.brief).hits
  assert_eq(hits.length(), 1)
  assert_eq(hits[0].slot, 2)
  let html = qa_test_render(searched)
  assert_true(html.contains("Parent missing"))
}

///|
test "slack two-source import enforces aggregate byte budget atomically" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = initial_model()
  let base = brief_fixture_draft().sources[0]
  let large = { ..base, content_hex: brief_text_hex("x".repeat(32768)), }
  let full = {
    ..model,
    brief: {
      ..model.brief,
      draft: { ..model.brief.draft, sources: Array::make(4, large), },
    },
  }
  let (_, blocked) = update(
    _ => @rabbita.none,
    BriefAction(FilesLoaded(full.brief.generation, slack_fixture_capture())),
    full,
  )
  assert_eq(blocked.brief.draft, full.brief.draft)
  assert_true(blocked.brief.error is Some(_))
}
