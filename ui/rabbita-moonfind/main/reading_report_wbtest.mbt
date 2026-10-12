///|
fn report_fixture() -> BriefView {
  let first = notes_pick(
    reading_fixture(),
    0,
    "Replication question 🌒\r\n```\n# A supplied heading\n<script>literal note</script>\n``````\n[do not open](javascript:alert(1))",
  )
  let second = notes_pick(first, 1, "Contradictory result; keep this separate")
  let third = notes_pick(second, 4, "Exact CSL identity")
  let fourth = notes_pick(third, 7, "A RIS observation")
  notes_pick(fourth, 8, "")
}

///|
test "report search covers handwritten text retained metadata and exact independent notes" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = report_fixture()
  let book = view.reading_notes.notebook
  let stored = choice_storage_read(view.reading_notes.key)
  for
    (query, count) in [
      ("  REPLICATION  ", 1),
      ("GARCÍA", 3),
      ("9007199254740993", 1),
      ("Conflicting method", 1),
      ("synthetic.ris", 2),
      ("Review this conflicting abstract", 1),
      ("2026-10-09T17:00:00Z", 5),
      ("missing text", 0),
      ("  ", 5),
    ] {
    let filtered = notes_apply(view, ReportQuery(query))
    assert_eq(reading_report_matches(filtered).length(), count)
    assert_eq(filtered.reading_notes.notebook, book)
    assert_eq(choice_storage_read(view.reading_notes.key), stored)
  }
  let filtered = notes_apply(view, ReportQuery("shared"))
  assert_eq(reading_report_matches(filtered).length(), 4)
  assert_eq(
    reading_report_matches(filtered).map(n => n.id),
    book.notes[:4].to_owned().map(n => n.id),
  )
  let unlisted = reading_apply(filtered, Query("no bibliography matches"))
  assert_eq(reading_report_matches(unlisted), reading_report_matches(filtered))
  let cleared = notes_apply(unlisted, ClearReport)
  assert_eq(reading_report_matches(cleared).length(), 5)
  assert_eq(cleared.reference_query, "no bibliography matches")
  assert_eq(reference_list_export(cleared), reference_list_export(unlisted))
  assert_eq(
    notes_apply(view, ReportScope("unknown")).reading_notes.report_scope,
    "all",
  )
  assert_eq(notes_reload(filtered).reading_notes.report_query, "")
}

///|
test "report source removal keeps detached snapshots searchable and exports no replacement" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = report_fixture()
  let originals = view.reading_notes.notebook.notes
  let removed = update_brief_view(_ => @rabbita.none, RemoveSource(1), view).1
  assert_true(
    reading_report_matches(notes_apply(removed, ReportScope("attached"))).is_empty(),
  )
  let detached = notes_apply(removed, ReportScope("detached"))
  assert_eq(reading_report_matches(detached).length(), 5)
  for i, n in detached.reading_notes.notebook.notes {
    assert_eq(n.reference, originals[i].reference)
    assert_eq(n.text, originals[i].text)
    assert_eq(n.capture, originals[i].capture)
  }
  let selected = notes_apply(detached, ReportQuery("replication"))
  let content = reading_report_markdown(selected)
  assert_true(
    content.contains("Snapshot status: detached; retained snapshot only"),
  )
  assert_true(content.contains(originals[0].reference.title))
  assert_false(content.contains(originals[1].text))
  reading_evidence("report-detached.md", content)
  reading_evidence(
    "report-detached-notes.json",
    ToJson::to_json(reading_report_matches(selected)).stringify(indent=2),
  )
  // A newly created note can be attached alongside old detached notes.
  let mixed = notes_pick(removed, 0, "Fresh current CSL observation")
  assert_eq(
    reading_report_matches(notes_apply(mixed, ReportScope("attached"))).length(),
    1,
  )
  assert_eq(
    reading_report_matches(notes_apply(mixed, ReportScope("detached"))).length(),
    5,
  )
  assert_eq(reading_report_matches(mixed).length(), 6)
}

///|
test "report markdown retains exact notes unicode provenance and separate same DOI records" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = report_fixture()
  let report = reading_report_markdown(view)
  for n in view.reading_notes.notebook.notes {
    assert_true(report.contains(n.id))
    assert_true(report.contains(n.reference.source_digest))
    assert_true(report.contains(n.reference.title))
    assert_true(report.contains(n.capture.origin))
    assert_true(report.contains(n.text))
    assert_false(report.contains(n.capture.content_hex))
  }
  assert_true(report.contains("Original item ID (number): 9007199254740993"))
  assert_true(report.contains("No handwritten text yet."))
  assert_true(report.contains("No abstract supplied."))
  assert_true(report.contains("```````\nReplication question 🌒\r\n"))
  assert_true(report.contains("not a full-text review"))
  assert_false(report.contains("content_hex"))
  reading_evidence("report-all.md", report)
  reading_evidence(
    "report-all-notes.json",
    ToJson::to_json(view.reading_notes.notebook.notes).stringify(indent=2),
  )
  reading_evidence(
    "report-empty.md",
    reading_report_markdown(notes_apply(view, ReportQuery("no-match-token"))),
  )
}

///|
test "report literal fences handle trailing delimiters CRLF empty text and source markup" {
  assert_eq(reading_report_literal(""), "```\n\n```\n\n")
  assert_eq(reading_report_literal("hello\r\n"), "```\nhello\r\n```\n\n")
  assert_eq(
    reading_report_literal("ends with ````"),
    "`````\nends with ````\n`````\n\n",
  )
  assert_eq(
    reading_report_literal("~~~\n<img src=x>\n~~~"),
    "```\n~~~\n<img src=x>\n~~~\n```\n\n",
  )
}

///|
test "report reducers reject pending blocked stale and wrong brief actions without changing notes" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = report_fixture()
  for
    action in [
      ReportQuery("x"),
      ReportScope("detached"),
      ClearReport,
      ExportReport,
    ] {
    let pending = notes_apply({ ..view, pending: true, }, action)
    assert_eq(pending.reading_notes.notebook, view.reading_notes.notebook)
    assert_eq(pending.reading_notes.report_query, "")
    assert_eq(pending.reading_notes.report_scope, "all")
    let blocked = notes_apply(
      { ..view, reading_notes: { ..view.reading_notes, blocked: true, }, },
      action,
    )
    assert_eq(blocked.reading_notes.notebook, view.reading_notes.notebook)
    assert_eq(blocked.reading_notes.report_query, "")
    let stale = update_brief_view(
        _ => @rabbita.none,
        ReadingNotes(
          view.reading_notes.key,
          view.reading_notes.notebook.revision - 1,
          action,
        ),
        view,
      ).1
    assert_eq(stale.reading_notes.notebook, view.reading_notes.notebook)
    assert_eq(stale.reading_notes.report_query, "")
    assert_true(stale.reading_notes.notice.contains("stale"))
  }
  for
    invalid in [
      { ..view, pending: true, },
      { ..view, reading_notes: { ..view.reading_notes, blocked: true, }, },
      { ..view, draft: { ..view.draft, brief_id: "other-brief", }, },
    ] {
    try reading_report_markdown(invalid) catch {
      _ => ()
    } noraise {
      _ => fail("Expected report to refuse unavailable current notebook")
    }
  }
  let filtered = notes_apply(view, ReportQuery("replication"))
  let fresh = update_brief_view(_ => @rabbita.none, New, filtered).1
  assert_eq(fresh.reading_notes.report_query, "")
  assert_eq(fresh.reading_notes.report_scope, "all")
  assert_true(fresh.reading_notes.notebook.notes.is_empty())
}

///|
test "report rendered notebook narrows cards and previews escaped Markdown" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = notes_apply(report_fixture(), ReportQuery("replication"))
  let html = reading_render(view)
  assert_true(html.contains("Search reading notes"))
  assert_true(html.contains("1 matching of 5 retained notes"))
  assert_true(html.contains("Preview annotated reading report"))
  assert_true(html.contains("Download annotated reading report Markdown"))
  assert_true(html.contains("&lt;script&gt;literal note&lt;/script&gt;"))
  assert_false(html.contains("<script>literal note</script>"))
  assert_false(html.contains("Contradictory result; keep this separate"))
  assert_false(
    reading_render({ ..view, pending: true, }).contains(
      "Download annotated reading report Markdown",
    ),
  )
  reading_evidence("report-rendered-filtered.html", html)
}

///|
test "report public root download uses real Blob unsaved text exact scope and failed retry" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = notes_apply(report_fixture(), ReportQuery("replication"))
  let id = view.reading_notes.notebook.notes[0].id
  set_choice_storage_mode("quota")
  let editing = notes_apply(view, Select(id))
  let unsaved = notes_apply(
    editing,
    Write(
      id,
      editing.reading_notes.notebook.notes[0].text + "\nUNSAVED addition",
    ),
  )
  assert_false(unsaved.reading_notes.saved)
  let stored = choice_storage_read(unsaved.reading_notes.key)
  let model = { ..initial_model(), brief: unsaved, }
  for mode in ["create", "click", ""] {
    shortlist_download_fixture(mode)
    let result = update(
        _ => @rabbita.none,
        BriefAction(
          ReadingNotes(
            unsaved.reading_notes.key,
            unsaved.reading_notes.notebook.revision,
            ExportReport,
          ),
        ),
        model,
      ).1.brief
    assert_eq(result.reading_notes.notebook, unsaved.reading_notes.notebook)
    assert_eq(result.reading_notes.report_query, "replication")
    assert_eq(result.draft, unsaved.draft)
    assert_false(result.reading_notes.saved)
    assert_eq(choice_storage_read(unsaved.reading_notes.key), stored)
    if mode.is_empty() {
      assert_true(result.reading_notes.notice.contains("download requested"))
      let content = reading_report_markdown(unsaved)
      assert_true(content.contains("NOT VERIFIED SAVED"))
      assert_true(content.contains("UNSAVED addition"))
      shortlist_download_verify(
        content, "moonfind-annotated-reading-report.md", "text/markdown;charset=utf-8",
      )
      reading_evidence("report-download-expected.md", content)
      reading_evidence(
        "report-download-notes.json",
        ToJson::to_json(reading_report_matches(unsaved)).stringify(indent=2),
      )
    } else {
      assert_true(result.reading_notes.notice.contains("download failed"))
    }
    shortlist_download_restore()
  }
}

///|
test "report complete hundred note output and one MiB refusal are explicit" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = notes_pick(reading_fixture(), 8, "Bounded note")
  let note = view.reading_notes.notebook.notes[0]
  let notes = Array::makei(100, i => { ..note, id: "report-note-\{i}", })
  let full = {
    ..view,
    reading_notes: {
      ..view.reading_notes,
      notebook: { ..view.reading_notes.notebook, notes, },
    },
  }
  let content = reading_report_markdown(full)
  assert_true(content.contains("Matching notes: 100 of 100"))
  assert_true(content.contains("## Note 100\n"))
  reading_evidence("report-hundred.md", content)
  // Large backtick runs require longer literal fences; never truncate the result.
  let expanded = {
    ..full,
    reading_notes: {
      ..full.reading_notes,
      notebook: {
        ..full.reading_notes.notebook,
        notes: notes.map(n => { ..n, text: "`".repeat(4000), }),
      },
    },
  }
  reading_notes_backup(expanded.reading_notes) |> ignore
  try reading_report_markdown(expanded) catch {
    error => assert_true("\{error}".contains("exceeds 1 MiB"))
  } noraise {
    _ => fail("Expected expanded report byte cap")
  }
}

///|
test "report Greek final sigma matches uppercase lowercase and substring queries" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = notes_pick(
    reading_fixture(),
    8,
    "Σωκράτης reported a replication issue",
  )
  let retained = view.reading_notes.notebook
  for
    query in [
      "Σωκράτης", "ΣΩΚΡΆΤΗΣ", "σωκράτης", "ΣΩΚΡΆΤΗΣ REPORTED",
      "της", "ΤΗΣ",
    ] {
    let filtered = notes_apply(view, ReportQuery(query))
    assert_eq(reading_report_matches(filtered).length(), 1)
    assert_eq(filtered.reading_notes.notebook, retained)
    assert_true(
      reading_report_markdown(filtered).contains(
        "Σωκράτης reported a replication issue",
      ),
    )
  }
  assert_eq(reading_report_search_key("Σ"), reading_report_search_key("ς"))
  assert_false(
    reading_report_search_key("é") == reading_report_search_key("e\u{301}"),
  )
}
