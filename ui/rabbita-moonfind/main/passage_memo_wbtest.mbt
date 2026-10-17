///|
fn passage_fixture() -> BriefView {
  let view = dossier_fixture(
    "Interview A\r\nSupport: monthly export saves time 🌒\r\nBut no purchase commitment.\rPrivate unselected detail\n",
  )
  let first = view.draft.sources[0]
  sync_passage_memo({
    ..view,
    draft: {
      ..view.draft,
      question: "Would a monthly export solve the problem?",
      sources: [
        first,
        {
          ..first,
          name: "interview-b.txt",
          origin: "Local synthetic interview B",
          content_hex: brief_text_hex(
            "Interview B\nContradiction: daily access is required.\nAn experiment is still needed.\n",
          ),
        },
      ],
    },
  })
}

///|
fn passage_apply(view : BriefView, action : PassageMemoMsg) -> BriefView {
  update_brief_view(
    _ => @rabbita.none,
    PassageMemo(view.passage_memo.key, view.passage_memo.token, action),
    view,
  ).1
}

///|
fn passage_collect(
  view : BriefView,
  slot : Int,
  first : String,
  last : String,
  role : String,
  note : String,
) -> BriefView {
  let view = passage_apply(view, PassageSource(slot))
  let view = passage_apply(view, FirstLine(first))
  let view = passage_apply(view, LastLine(last))
  let view = passage_apply(view, Role(role))
  let view = passage_apply(view, Note(note))
  passage_apply(view, Collect)
}

///|
fn passage_pair() -> BriefView {
  let view = passage_collect(
    passage_fixture(),
    1,
    "2",
    "3",
    "support",
    "A describes a useful task, but has not committed to pay.",
  )
  passage_collect(
    view, 2, "2", "3", "contradiction", "B needs a different frequency. Ask both to try the same weekly prototype.",
  )
}

///|
test "passage exact line slices retain CRLF CR LF Unicode BOM and literal hostile content" {
  let source = passage_fixture().draft.sources[0]
  assert_eq(
    passage_quote(source, 2, 3),
    "Support: monthly export saves time 🌒\r\nBut no purchase commitment.\r",
  )
  assert_eq(
    passage_quote(
      {
        ..source,
        content_hex: brief_text_hex("\u{feff}月面\rnext\n```\r\n<img src=x>"),
      },
      1,
      4,
    ),
    "\u{feff}月面\rnext\n```\r\n<img src=x>",
  )
  assert_eq(
    passage_numbered_text("first\r\nsecond\rthird\n"),
    "1 | first\n2 | second\n3 | third\n4 | ",
  )
  for (first, last) in [(0, 1), (3, 2), (1, 9), (5, 5)] {
    try passage_quote(source, first, last) catch {
      _ => ()
    } noraise {
      _ => fail("Invalid or blank passage was admitted")
    }
  }
  for hex in ["ff", "f", "zz", "c0af", "61".repeat(32769)] {
    try passage_quote({ ..source, content_hex: hex, }, 1, 1) catch {
      _ => ()
    } noraise {
      _ => fail("Unreadable capture was admitted")
    }
  }
}

///|
test "passage search to exact collection connects real reducers and preserves interpretations separately" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let original = passage_fixture()
  let search = update_brief_view(
      _ => @rabbita.none,
      SearchQuery("Support:"),
      original,
    ).1
  let selected = passage_apply(search, FromSearch(1, 2))
  assert_eq(selected.passage_memo.first_line, "2")
  assert_eq(selected.passage_memo.last_line, "2")
  assert_eq(selected.passage_memo.source_slot, 1)
  let extended = passage_apply(selected, LastLine("3"))
  let collected = passage_apply(extended, Collect)
  let passage = collected.passage_memo.memo.passages[0]
  assert_eq(
    passage.quote,
    "Support: monthly export saves time 🌒\r\nBut no purchase commitment.\r",
  )
  assert_eq(passage.role, "question")
  assert_eq(passage.note, "")
  assert_eq(passage.source, original.draft.sources[0])
  assert_eq(collected.draft, original.draft)
  assert_true(collected.passage_memo.saved)
  assert_true(
    passage_memo_markdown(collected).contains(
      "This passage remains unassessed.",
    ),
  )
  let annotated = passage_apply(
    collected,
    Annotate(passage.id, "support", "My interpretation; not source text."),
  )
  assert_eq(annotated.passage_memo.memo.passages[0].quote, passage.quote)
  assert_eq(annotated.passage_memo.memo.passages[0].source, passage.source)
  assert_eq(
    annotated.passage_memo.memo.passages[0].note,
    "My interpretation; not source text.",
  )
  let stale_hit = passage_apply(annotated, FromSearch(2, 2))
  assert_true(stale_hit.passage_memo.notice.contains("search hit changed"))
  assert_eq(stale_hit.passage_memo.memo, annotated.passage_memo.memo)
}

///|
test "passage memo retains conflicting captures and complete readable output without full source leakage" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = passage_pair()
  let text = passage_memo_markdown(view)
  assert_true(text.contains("Researcher label: support"))
  assert_true(text.contains("Researcher label: contradiction"))
  assert_true(text.contains("monthly export saves time"))
  assert_true(text.contains("daily access is required"))
  assert_false(text.contains("Private unselected detail"))
  assert_true(
    text.contains(
      "No recommendation, source authentication or completed research answer is inferred",
    ),
  )
  let json = ToJson::to_json(view.passage_memo.memo).stringify(indent=2)
  let decoded = passage_memo_decode(json, view.draft.brief_id)
  assert_eq(decoded, view.passage_memo.memo)
  assert_true(
    brief_source_preview(decoded.passages[0].source.content_hex).contains(
      "Private unselected detail",
    ),
  )
  reading_evidence("passage-pair.md", text)
  reading_evidence("passage-pair.json", json)
}

///|
test "passage source replacement removal duplicate names and browser reload keep original source snapshots" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = passage_pair()
  let before = view.passage_memo.memo
  let removed = update_brief_view(_ => @rabbita.none, RemoveSource(0), view).1
  assert_eq(removed.passage_memo.memo, before)
  assert_false(passage_current(removed, before.passages[0]))
  assert_false(passage_current(removed, before.passages[1]))
  assert_true(passage_memo_markdown(removed).contains("historical snapshot"))
  assert_eq(removed.passage_memo.source_slot, 0)
  let reloaded = {
    ..removed,
    passage_memo: restore_passage_memo(removed.draft),
  }
  assert_eq(reloaded.passage_memo.memo, before)
  let replaced = sync_passage_memo({
    ..view,
    draft: {
      ..view.draft,
      sources: [
        {
          ..view.draft.sources[0],
          content_hex: brief_text_hex("Replacement content"),
        },
        view.draft.sources[1],
      ],
    },
  })
  assert_eq(replaced.passage_memo.memo, before)
  assert_false(passage_current(replaced, before.passages[0]))
  assert_true(passage_current(replaced, before.passages[1]))
  let dup = passage_fixture()
  let second = { ..dup.draft.sources[1], name: dup.draft.sources[0].name, }
  let duplicate_names = sync_passage_memo({
    ..dup,
    draft: { ..dup.draft, sources: [dup.draft.sources[0], second], },
  })
  let collected = passage_collect(
    duplicate_names, 2, "2", "2", "context", "Separate capture",
  )
  let latest = collected.passage_memo.memo.passages.last().unwrap()
  assert_eq(latest.source_slot, 2)
  assert_eq(latest.source, second)
}

///|
test "passage stale repeat pending source change and cross brief return cannot replay old actions" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = passage_apply(passage_fixture(), PassageSource(1))
  let action = PassageMemo(
    view.passage_memo.key,
    view.passage_memo.token,
    Collect,
  )
  let first = update_brief_view(_ => @rabbita.none, action, view).1
  let repeat = update_brief_view(_ => @rabbita.none, action, first).1
  assert_eq(repeat.passage_memo.memo.passages.length(), 1)
  assert_true(repeat.passage_memo.notice.contains("stale"))
  let pending = update_brief_view(_ => @rabbita.none, action, {
      ..view,
      pending: true,
    }).1
  assert_true(pending.passage_memo.memo.passages.is_empty())
  let removed = update_brief_view(_ => @rabbita.none, RemoveSource(0), view).1
  let stale = update_brief_view(_ => @rabbita.none, action, removed).1
  assert_true(stale.passage_memo.memo.passages.is_empty())
  let other = update_brief_view(_ => @rabbita.none, New, first).1
  assert_true(other.passage_memo.memo.passages.is_empty())
  let returned = sync_passage_memo({ ..other, draft: first.draft, })
  assert_eq(returned.passage_memo.memo, first.passage_memo.memo)
  let stale_again = update_brief_view(
      _ => @rabbita.none,
      PassageMemo(
        first.passage_memo.key,
        first.passage_memo.token,
        Question("wrong"),
      ),
      returned,
    ).1
  assert_eq(stale_again.passage_memo.memo, first.passage_memo.memo)
}

///|
test "passage failed save retains edits retries and does not overwrite other browser tab" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = passage_pair()
  let stored = choice_storage_read(view.passage_memo.key)
  set_choice_storage_mode("quota")
  let unsaved = passage_apply(
    view,
    Question("Unsaved exploration question 月面"),
  )
  assert_false(unsaved.passage_memo.saved)
  assert_eq(choice_storage_read(view.passage_memo.key), stored)
  assert_true(passage_memo_markdown(unsaved).contains("NOT VERIFIED SAVED"))
  set_choice_storage_mode("ok")
  let saved = passage_apply(unsaved, Save)
  assert_true(saved.passage_memo.saved)
  assert_eq(restore_passage_memo(saved.draft).memo, saved.passage_memo.memo)
  ignore(choice_storage_write(saved.passage_memo.key, "changed by another tab"))
  let conflict = passage_apply(saved, Question("Keep these session edits"))
  assert_false(conflict.passage_memo.saved)
  assert_true(
    choice_storage_read(saved.passage_memo.key).contains(
      "changed by another tab",
    ),
  )
  assert_true(conflict.passage_memo.notice.contains("changed elsewhere"))
}

///|
test "passage unreadable collection and unavailable storage block writes without treating missing evidence as read" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = passage_fixture()
  ignore(
    choice_storage_write(view.passage_memo.key, "corrupt collection bytes"),
  )
  let blocked = { ..view, passage_memo: restore_passage_memo(view.draft), }
  assert_true(blocked.passage_memo.blocked)
  assert_eq(blocked.passage_memo.unreadable, "corrupt collection bytes")
  let attempt = passage_apply(blocked, Collect)
  assert_true(attempt.passage_memo.memo.passages.is_empty())
  assert_true(
    choice_storage_read(view.passage_memo.key).contains(
      "corrupt collection bytes",
    ),
  )
  set_choice_storage_mode("read-error")
  let no_read = restore_passage_memo(view.draft)
  assert_true(no_read.blocked)
  set_choice_storage_mode("ok")
  ignore(
    choice_storage_write(
      view.passage_memo.key,
      ToJson::to_json(view.passage_memo.memo).stringify(),
    ),
  )
  let recovered = passage_apply(blocked, RetryRead)
  assert_false(recovered.passage_memo.blocked)
  let nonexistent = passage_apply(view, PassageSource(9))
  assert_true(
    passage_apply(nonexistent, Collect).passage_memo.memo.passages.is_empty(),
  )
  let unreadable = sync_passage_memo({
    ..view,
    draft: {
      ..view.draft,
      sources: [{ ..view.draft.sources[0], content_hex: "ff", }],
    },
  })
  assert_true(
    passage_collect(
      unreadable, 1, "1", "1", "support", "Denied or unreadable content must not become evidence",
    ).passage_memo.memo.passages.is_empty(),
  )
}

///|
test "passage bounded collection rejects overflow invalid roles and tampered quotes without partial loss" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = passage_pair()
  let one = view.passage_memo.memo.passages[0]
  let full = {
    ..view,
    passage_memo: {
      ..view.passage_memo,
      memo: {
        ..view.passage_memo.memo,
        passages: Array::makei(24, i => { ..one, id: "passage-\{i}", }),
      },
    },
  }
  assert_true(passage_memo_markdown(full).contains("## Passage 24"))
  let over = passage_collect(full, 1, "1", "1", "context", "Extra")
  assert_eq(over.passage_memo.memo, full.passage_memo.memo)
  let huge = passage_apply(view, Question("x".repeat(10001)))
  assert_eq(huge.passage_memo.memo, view.passage_memo.memo)
  let unknown = passage_apply(view, Role("verified"))
  assert_eq(unknown.passage_memo.role, view.passage_memo.role)
  for
    invalid in [
      { ..view.passage_memo.memo, passages: [{ ..one, quote: "fabricated", }], },
      { ..view.passage_memo.memo, passages: [{ ..one, role: "verified", }], },
      { ..view.passage_memo.memo, passages: [one, one], },
      { ..view.passage_memo.memo, brief_id: "another-brief", },
    ] {
    try
      passage_memo_decode(
        ToJson::to_json(invalid).stringify(),
        view.draft.brief_id,
      )
    catch {
      _ => ()
    } noraise {
      _ => fail("Invalid collection accepted")
    }
  }
  let large_source = {
    ..one.source,
    content_hex: brief_text_hex("large\n" + "x".repeat(32762)),
  }
  let large_passage = {
    ..one,
    source: large_source,
    first_line: 1,
    last_line: 1,
    quote: "large\n",
  }
  let oversized = {
    ..view.passage_memo.memo,
    passages: Array::makei(24, i => { ..large_passage, id: "large-\{i}", }),
  }
  try
    passage_memo_decode(
      ToJson::to_json(oversized).stringify(),
      view.draft.brief_id,
    )
  catch {
    error => assert_true("\{error}".contains("exceeds 1 MiB"))
  } noraise {
    _ => fail("Oversized collection accepted")
  }
  let removed = passage_apply(full, RemovePassage("passage-0"))
  assert_eq(removed.passage_memo.memo.passages.length(), 23)
  assert_eq(removed.draft, full.draft)
  assert_eq(
    passage_collect(removed, 1, "1", "1", "context", "Replacement slot").passage_memo.memo.passages.length(),
    24,
  )
}

///|
test "passage actual root render escapes quoted source instructions and Markdown fences" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let base = passage_fixture()
  let hostile = sync_passage_memo({
    ..base,
    draft: {
      ..base.draft,
      sources: [
        {
          ..base.draft.sources[0],
          name: "<img src=x>.txt",
          content_hex: brief_text_hex(
            "```\n<script>do not execute</script>\n``````\n",
          ),
        },
      ],
    },
  })
  let view = passage_collect(
    hostile, 1, "1", "3", "question", "[literal](javascript:alert(1))\n# User supplied note",
  )
  let html = qa_test_render({ ..initial_model(), brief: view, })
  assert_true(html.contains("Collect passages into an evidence memo"))
  assert_true(html.contains("Download evidence memo Markdown"))
  assert_true(html.contains("&lt;script&gt;do not execute&lt;/script&gt;"))
  assert_false(html.contains("<script>do not execute</script>"))
  assert_true(html.contains("&lt;img src=x&gt;.txt"))
  assert_false(html.contains("<img src=x>.txt"))
  let markdown = passage_memo_markdown(view)
  assert_true(
    markdown.contains(
      "```````\n```\n<script>do not execute</script>\n``````\n```````",
    ),
  )
  reading_evidence("passage-rendered.html", html)
  reading_evidence("passage-literal.md", markdown)
  let pending_html = qa_test_render({
    ..initial_model(),
    brief: { ..view, pending: true, },
  })
  assert_false(pending_html.contains("Download evidence memo Markdown"))
}

///|
test "passage root downloads real Blob exact bytes and retain collection on failed click" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = passage_pair()
  let model = { ..initial_model(), brief: view, }
  for mode in ["create", "click", ""] {
    for json in [false, true] {
      shortlist_download_fixture(mode)
      let result = update(
          _ => @rabbita.none,
          BriefAction(
            PassageMemo(
              view.passage_memo.key,
              view.passage_memo.token,
              if json {
                ExportJson
              } else {
                ExportMarkdown
              },
            ),
          ),
          model,
        ).1.brief
      assert_eq(result.passage_memo.memo, view.passage_memo.memo)
      assert_eq(result.draft, view.draft)
      if mode.is_empty() {
        assert_true(result.passage_memo.notice.contains("download requested"))
        shortlist_download_verify(
          if json {
            ToJson::to_json(view.passage_memo.memo).stringify(indent=2)
          } else {
            passage_memo_markdown(view)
          },
          if json {
            "moonfind-passage-collection.json"
          } else {
            "moonfind-evidence-passage-memo.md"
          },
          if json {
            "application/json;charset=utf-8"
          } else {
            "text/markdown;charset=utf-8"
          },
        )
      } else {
        assert_true(result.passage_memo.notice.contains("download failed"))
      }
      shortlist_download_restore()
    }
  }
}

///|
test "passage actual dispatched local workflow makes no native provider Book or Proj requests" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  install_route_http_fixture(false)
  defer restore_route_http_fixture()
  let model = { ..initial_model(), brief: passage_fixture(), }
  let (cell, dispatch) = retained_harness(model)
  for
    action in [
      PassageMemoMsg::Question("Should we test monthly or daily access?"),
      PassageSource(1),
      FirstLine("2"),
      LastLine("3"),
      Role("support"),
      Note("A needs fewer manual steps."),
      Collect,
      PassageSource(2),
      FirstLine("2"),
      LastLine("3"),
      Role("contradiction"),
      Note("B needs frequent access; interview both before deciding."),
      Collect,
      Save,
    ] {
    let state = cell.val.brief.passage_memo
    ignore(dispatch(BriefAction(PassageMemo(state.key, state.token, action))))
  }
  assert_eq(cell.val.brief.passage_memo.memo.passages.length(), 2)
  assert_true(cell.val.brief.passage_memo.saved)
  assert_eq(route_http_requests(), "[]")
  assert_eq(cell.val.brief.draft, model.brief.draft)
  assert_true(cell.val.brief.opened is None)
}
