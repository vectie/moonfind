///|
fn dossier_fixture(text : String) -> BriefView {
  let draft = brief_fixture_draft()
  {
    ..initial_brief_view(),
    draft: {
      ..draft,
      sources: [{ ..draft.sources[0], content_hex: brief_text_hex(text), }],
    },
  }
}

///|
extern "js" fn dossier_test_digest(hex : String) -> String =
  #|hex => 'sha256:' + process.getBuiltinModule('crypto').createHash('sha256').update(Buffer.from(hex,'hex')).digest('hex')

///|
fn dossier_saved_fixture() -> BriefView {
  let view = {
    ..dossier_fixture(
      "Earlier\r\nReported <script>delay</script> 月面 🌒\r\nConflicting DELAY report\n",
    ),
    search_query: "delay",
    search_fold: true,
  }
  let source = view.draft.sources[0]
  let snapshot : BriefSnapshot = {
    contract_id: "moonfind.brief-snapshot.v1",
    revision_id: "revision-synthetic-reading-fixture",
    state: "prepared",
    brief: view.draft,
    sources: [
      {
        slot: 1,
        name: source.name,
        origin: source.origin,
        captured_at: source.captured_at,
        kind: source.kind,
        availability: "retained-local-capture",
        archive_path: "sources/source-1.txt",
        byte_count: source.content_hex.length() / 2,
        digest: dossier_test_digest(source.content_hex),
      },
    ],
    boundary: "Synthetic saved-state fixture; no native host retention exercised.",
  }
  {
    ..view,
    opened: Some({
      contract_id: "moonfind.brief-status.v1",
      brief_id: view.draft.brief_id,
      revision_id: snapshot.revision_id,
      state: "prepared",
      snapshot: Some(snapshot),
      issues: [],
    }),
  }
}

///|
extern "js" fn dossier_record_evidence(
  artifact : String,
  html : String,
  hex : String,
) -> Unit =
  #|(artifact,html,hex) => {
  #| const dir=process.env.MOONFIND_DOSSIER_TEST_EVIDENCE; if(!dir) return;
  #| const fs=process.getBuiltinModule('fs'), path=process.getBuiltinModule('path');
  #| fs.writeFileSync(path.join(dir,'synthetic-search.json'),artifact);
  #| fs.writeFileSync(path.join(dir,'synthetic-search.html'),html);
  #| fs.writeFileSync(path.join(dir,'synthetic-source.txt'),Buffer.from(hex,'hex'));
  #|}

///|
test "dossier literal matching CRLF Unicode ASCII fold and duplicate source slots" {
  let base = dossier_fixture(
    "a.* A.*\r\n月面 🌒\rStraße STRASSE\né é\n",
  )
  let view = {
    ..base,
    draft: { ..base.draft, sources: base.draft.sources + base.draft.sources, },
    search_query: ".*",
  }
  let results = dossier_search(view)
  assert_eq(results.hits.length(), 2)
  assert_eq(results.hits[0].slot, 1)
  assert_eq(results.hits[1].slot, 2)
  assert_eq(results.hits[0].name, results.hits[1].name)
  assert_eq(results.hits[0].line, 1)
  assert_eq(dossier_search({ ..base, search_query: "🌒", }).hits[0].line, 2)
  assert_eq(
    dossier_search({ ..base, search_query: "strasse", }).matching_lines,
    0,
  )
  assert_eq(
    dossier_search({ ..base, search_query: "strasse", search_fold: true, }).hits[0].context,
    "Straße STRASSE",
  )
  assert_eq(
    dossier_search({
      ..dossier_fixture("Straße É é"),
      search_query: "STRASSE",
      search_fold: true,
    }).matching_lines,
    0,
  )
  assert_eq(
    dossier_search({
      ..dossier_fixture("É é"),
      search_query: "é",
      search_fold: true,
    }).matching_lines,
    0,
  )
  assert_eq(dossier_search({ ..base, search_query: "", }).matching_lines, 0)
  assert_false(
    dossier_search({ ..base, search_query: "a\nb", }).issue.is_empty(),
  )
  assert_false(
    dossier_search({ ..base, search_query: "x".repeat(257), }).issue.is_empty(),
  )
  assert_eq(
    dossier_capture_section("first\r\nsecond\rthird\n", 2, false),
    "second\nthird\n",
  )
  assert_eq(dossier_capture_section("first\r\nsecond", 2, true), "first")
}

///|
test "dossier bounds clipping invalid bytes and deterministic repeated queries" {
  let view = {
    ..dossier_fixture(
      "🌒".repeat(300) +
      "needle" +
      "x".repeat(300) +
      "\n" +
      "needle\n".repeat(250),
    ),
    search_query: "needle",
  }
  let result = dossier_search(view)
  assert_eq(result.matching_lines, 251)
  assert_eq(result.hits.length(), 200)
  assert_eq(result.omitted, 51)
  assert_true(result.hits[0].context.has_prefix("…🌒"))
  assert_true(result.hits[0].context.contains("needle"))
  for _ in 0..<5 {
    assert_eq(dossier_search(view), result)
  }
  for hex in ["zz", "f", "c0af", "ff"] {
    let bad = {
      ..view,
      draft: {
        ..view.draft,
        sources: [{ ..view.draft.sources[0], content_hex: hex, }],
      },
    }
    assert_eq(dossier_search(bad).skipped_slots, [1])
    assert_eq(dossier_search(bad).matching_lines, 0)
  }
  assert_eq(
    dossier_search({
      ..dossier_fixture("\u{feff}needle"),
      search_query: "\u{feff}",
    }).matching_lines,
    1,
  )
}

///|
test "dossier compiled reducer navigation render escaping and edit invalidation" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = dossier_saved_fixture()
  let (_, opened) = update_brief_view(
    _ => @rabbita.none,
    SearchOpen(1, 2),
    view,
  )
  assert_eq(opened.search_open, Some((1, 2)))
  let html = qa_test_render({ ..initial_model(), brief: opened, })
  assert_true(html.contains("opened at line 2"))
  assert_true(html.contains("&lt;script&gt;delay&lt;/script&gt;"))
  assert_false(html.contains("<script>delay"))
  assert_true(html.contains("Download search reading artifact"))
  dossier_record_evidence(
    dossier_export(opened),
    html,
    view.draft.sources[0].content_hex,
  )
  let (_, stale) = update_brief_view(_ => @rabbita.none, SearchOpen(9, 2), view)
  assert_eq(stale.search_open, None)
  let (_, queried) = update_brief_view(
    _ => @rabbita.none,
    SearchQuery("missing"),
    opened,
  )
  assert_eq(queried.search_open, None)
  let (_, folded) = update_brief_view(_ => @rabbita.none, SearchFold, queried)
  assert_false(folded.search_fold)
  let (_, edited) = update_brief_view(
    _ => @rabbita.none,
    Edit("objective", "changed"),
    opened,
  )
  assert_eq(edited.search_open, None)
  assert_true(edited.opened is None)
  let (_, removed) = update_brief_view(
    _ => @rabbita.none,
    RemoveSource(0),
    opened,
  )
  assert_eq(removed.search_open, None)
  assert_eq(dossier_search(removed).matching_lines, 0)
  let (_, fresh) = update_brief_view(_ => @rabbita.none, New, opened)
  assert_eq(fresh.search_query, "")
}

///|
test "dossier saved revision digest bound export and blocked stale incomplete states" {
  let view = dossier_saved_fixture()
  let exported = dossier_export(view)
  assert_true(exported.contains(view.opened.unwrap().revision_id))
  assert_true(
    exported.contains(dossier_test_digest(view.draft.sources[0].content_hex)),
  )
  let json = @json.parse(exported)
  assert_true(json is { "results": { "matching_lines": Number(2), .. }, .. })
  for
    bad in [
      { ..view, opened: None, },
      { ..view, pending: true, },
      { ..view, search_query: "", },
      { ..view, draft: { ..view.draft, question: "different", }, },
      {
        ..view,
        opened: Some({ ..view.opened.unwrap(), state: "incomplete", }),
      },
      {
        ..view,
        opened: Some({ ..view.opened.unwrap(), revision_id: "changed", }),
      },
      {
        ..view,
        opened: Some({ ..view.opened.unwrap(), brief_id: "changed", }),
      },
    ] {
    let failed = try {
      ignore(dossier_export(bad))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
  println("DOSSIER_SEARCH_SYNTHETIC_ARTIFACT=" + exported)
}

///|
test "dossier production download boundary exact bytes retry and errors" {
  for fail_ in [false, true] {
    experiment_download_fixture(fail_)
    defer experiment_download_restore()
    let view = dossier_saved_fixture()
    let (_, after) = update_brief_view(_ => @rabbita.none, SearchExport, view)
    assert_eq(after.draft, view.draft)
    if fail_ {
      assert_true(after.error.unwrap().contains("download failed"))
    } else {
      guard @json.parse(experiment_download_readback())
        is {
          "name": String("moonfind-dossier-search.json"),
          "content": String(content),
          "clicked": True,
          ..
        } else {
        fail("missing browser download")
      }
      assert_eq(content, dossier_export(view))
      assert_eq(after.error, None)
      let (_, again) = update_brief_view(
        _ => @rabbita.none,
        SearchExport,
        after,
      )
      assert_eq(again.error, None)
    }
  }
}

///|
test "dossier reopen reducer binds search to loaded historical revision and escapes filenames" {
  let saved = dossier_saved_fixture()
  let status = saved.opened.unwrap()
  let (_, opening) = update_brief_view(
    _ => @rabbita.none,
    Open(status.brief_id, status.revision_id),
    {
      ..dossier_fixture("newer source"),
      search_query: "delay",
      search_fold: true,
    },
  )
  let payload : Json = {
    "contract_id": status.contract_id,
    "brief_id": status.brief_id,
    "revision_id": status.revision_id,
    "state": status.state,
    "snapshot": status.snapshot.unwrap().to_json(),
    "issues": [],
  }
  let (_, loaded) = update_brief_view(
    _ => @rabbita.none,
    Loaded(opening.generation, status.brief_id, status.revision_id, Ok(payload)),
    opening,
  )
  assert_false(loaded.pending)
  assert_eq(dossier_search(loaded).matching_lines, 2)
  assert_eq(dossier_export(loaded), dossier_export(saved))
  let (_, stale) = update_brief_view(
    _ => @rabbita.none,
    Loaded(
      opening.generation - 1,
      status.brief_id,
      status.revision_id,
      Ok(payload),
    ),
    opening,
  )
  assert_true(stale.pending)
  assert_eq(dossier_search(stale).matching_lines, 0)
  let source = loaded.draft.sources[0]
  let hostile = {
    ..loaded,
    draft: {
      ..loaded.draft,
      sources: [{ ..source, name: "<img src=x onerror=boom>.txt", }],
    },
  }
  install_choice_storage("ok")
  defer restore_choice_storage()
  let html = qa_test_render({ ..initial_model(), brief: hostile, })
  assert_true(html.contains("&lt;img src=x onerror=boom&gt;.txt"))
  assert_false(html.contains("<img src=x onerror=boom>"))
  let empty = @json.parse(
    dossier_export({ ..saved, search_query: "not present", }),
  )
  assert_true(empty is { "results": { "matching_lines": Number(0), .. }, .. })
}
