///|
fn email_fixture_capture() -> String {
  email_source_capture(
    "interview.eml",
    brief_text_hex(
      "From: supplied@example.invalid\r\nSubject: Research interview\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Transfer-Encoding: base64\r\n\r\nT2ZmbGluZSBmaW5kaW5nIDxzY3JpcHQ+IGluZXJ0\r\n",
    ),
    "2026-10-12T00:00:00Z",
  )
}

///|
test "email source actual decoder reducer searchable preview and browser draft retention" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = initial_model()
  let (_, captured) = update(
    _ => @rabbita.none,
    BriefAction(FilesLoaded(model.brief.generation, email_fixture_capture())),
    model,
  )
  assert_true(captured.brief.error is None)
  assert_eq(captured.brief.draft.sources.length(), 2)
  assert_eq(captured.brief.draft.sources[0].name, "interview.eml.txt")
  assert_eq(captured.brief.draft.sources[1].name, "interview.eml.readable.txt")
  let (_, searched) = update(
    _ => @rabbita.none,
    BriefAction(SearchQuery("Offline finding")),
    captured,
  )
  let hits = dossier_search(searched.brief).hits
  assert_eq(hits.length(), 1)
  assert_eq(hits[0].slot, 2)
  let html = qa_test_render(searched)
  assert_true(html.contains("Import local email (.eml)"))
  assert_true(html.contains("&lt;script&gt;"))
  assert_false(html.contains("<script>"))
  let restored = initial_model()
  assert_eq(restored.brief.draft.sources, captured.brief.draft.sources)
}

///|
test "email capture failures capacity stale callbacks and pending state preserve prior brief" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = initial_model()
  let (_, failed) = update(
    _ => @rabbita.none,
    BriefAction(
      FilesLoaded(
        model.brief.generation,
        email_source_capture(
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
    BriefAction(FilesLoaded(full.brief.generation, email_fixture_capture())),
    full,
  )
  assert_eq(blocked.brief.draft, full.brief.draft)
  assert_true(blocked.brief.error is Some(_))
  let (_, stale) = update(
    _ => @rabbita.none,
    BriefAction(
      FilesLoaded(model.brief.generation - 1, email_fixture_capture()),
    ),
    model,
  )
  assert_eq(stale.brief.draft, model.brief.draft)
  let pending = { ..model, brief: { ..model.brief, pending: true, }, }
  let (_, ignored) = update(
    _ => @rabbita.none,
    BriefAction(FilesLoaded(pending.brief.generation, email_fixture_capture())),
    pending,
  )
  assert_eq(ignored.brief.draft, pending.brief.draft)
  let (_, choosing) = update(
    _ => @rabbita.none,
    BriefAction(ChooseEmail),
    pending,
  )
  assert_eq(choosing.brief.draft, pending.brief.draft)
}

///|
test "email sources survive save and reopen protocol without asserting native host verification" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = initial_model()
  let (_, captured) = update(
    _ => @rabbita.none,
    BriefAction(FilesLoaded(model.brief.generation, email_fixture_capture())),
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
