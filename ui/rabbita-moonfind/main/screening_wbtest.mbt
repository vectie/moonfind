///|
fn screening_apply(view : BriefView, action : ScreeningMsg) -> BriefView {
  update_brief_view(
    _ => @rabbita.none,
    Screening(view.screening.key, view.screening.log.revision, action),
    view,
  ).1
}

///|
fn screening_pick(
  view : BriefView,
  index : Int,
  status : String,
  reason : String,
) -> BriefView {
  let chosen = screening_apply(
    view,
    Screen(reference_choice(view, reference_catalog(view).references[index])),
  )
  screening_apply(
    screening_apply(
      screening_apply(chosen, Decision(status)),
      Rationale(reason),
    ),
    SaveDecision(false),
  )
}

///|
fn screening_reload(view : BriefView) -> BriefView {
  sync_screening({
    ..view,
    screening: restore_screening(view.draft),
    screening_sessions: Map([]),
  })
}

///|
test "screening imported citations become independent decisions with append-only revision history and next queue" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let base = reading_fixture()
  let original_export = reference_list_export(base)
  let first = screening_pick(
    base, 0, "include", "Directly studies the target method 🌒",
  )
  let second = screening_pick(
    first, 1, "exclude", "Same DOI text, but different supplied method; out of scope",
  )
  let third = screening_pick(
    second, 4, "undecided", "Metadata only; obtain the permitted abstract before deciding",
  )
  let references = reference_catalog(third).references
  assert_eq(references.length(), 9)
  assert_eq(screening_status(third, references[0]), "include")
  assert_eq(screening_status(third, references[1]), "exclude")
  assert_eq(screening_status(third, references[4]), "undecided")
  assert_eq(screening_status(third, references[7]), "unscreened")
  assert_eq(references[0].doi_match_key, references[1].doi_match_key)
  let revised = screening_pick(
    third, 0, "undecided", "Reconsidered: sample size is missing",
  )
  assert_eq(revised.screening.log.decisions.length(), 4)
  assert_eq(
    revised.screening.log.decisions[0],
    first.screening.log.decisions[0],
  )
  assert_eq(screening_status(revised, references[0]), "undecided")
  let next = screening_apply(revised, SaveDecision(true))
  assert_eq(next.screening.log.decisions.length(), 4)
  assert_eq(next.screening.editor.unwrap().reference, references[2])
  assert_eq(next.screening.rationale, "")
  assert_true(next.screening.saved)
  assert_eq(reference_list_export(next), original_export)
  assert_eq(next.draft, base.draft)
  assert_eq(screening_reload(next).screening.log, next.screening.log)
  reading_evidence("screening-history.json", screening_json(next))
  reading_evidence("screening.csv", screening_csv(next))
  reading_evidence("screening-panel.html", reading_render(next))
}

///|
test "screening filters show precise status intersection but history export retains hidden decisions" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let first = screening_pick(
    reading_fixture(),
    0,
    "include",
    "Relevant contact experiment",
  )
  let second = screening_pick(first, 1, "exclude", "Outside population")
  let view = screening_pick(second, 4, "include", "Relevant synthesis")
  let filtered = screening_apply(
    reading_apply(view, Query("contact")),
    Scope("include"),
  )
  assert_eq(screening_matches(filtered).length(), 2)
  assert_eq(
    screening_matches(screening_apply(filtered, Scope("exclude"))).length(),
    1,
  )
  let empty = screening_apply(
    reading_apply(view, Query("no-match-token")),
    Scope("unscreened"),
  )
  assert_eq(screening_matches(empty).length(), 0)
  let report = @json.parse(screening_json(empty))
  guard report is { "visible_rows": Array([]), "complete_history": history, .. } else {
    fail("Unexpected filtered report")
  }
  let decisions : Array[ScreeningDecision] = @json.from_json(history)
  assert_eq(decisions, view.screening.log.decisions)
  assert_eq(screening_csv(empty).split("\r\n").count(), 2)
  assert_eq(screening_apply(view, Scope("unknown")).screening.scope, "all")
  assert_eq(view.screening.log, filtered.screening.log)
  assert_eq(
    reference_list_export(filtered),
    reference_list_export(reading_apply(view, Query("contact"))),
  )
  reading_evidence("screening-filtered.csv", screening_csv(filtered))
}

///|
test "screening source changes detach history permanently and preserve appended identities" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let base = screening_pick(
    reading_fixture(),
    0,
    "include",
    "Original exact capture",
  )
  let entry = base.screening.log.decisions[0]
  let appended = sync_screening(
    brief_edited(base, {
      ..base.draft,
      sources: base.draft.sources + [base.draft.sources[1]],
    }),
  )
  assert_eq(screening_status(appended, entry.reference), "include")
  assert_eq(
    screening_status(appended, reference_catalog(appended).references[9]),
    "unscreened",
  )
  let removed = update_brief_view(_ => @rabbita.none, RemoveSource(0), appended).1
  assert_false(removed.screening.log.decisions[0].attached)
  assert_eq(removed.screening.log.decisions[0].capture, entry.capture)
  let restored = sync_screening(brief_edited(removed, base.draft))
  assert_eq(screening_status(restored, entry.reference), "unscreened")
  assert_false(screening_reload(restored).screening.log.decisions[0].attached)
  let blocked = screening_apply(restored, SaveDecision(false))
  assert_eq(blocked.screening.log, restored.screening.log)
  assert_true(blocked.screening.notice.contains("source changed"))
  let current = screening_pick(
    screening_apply(blocked, Cancel),
    0,
    "exclude",
    "Fresh decision after source replacement",
  )
  assert_eq(current.screening.log.decisions.length(), 2)
  assert_eq(screening_status(current, entry.reference), "exclude")
  reading_evidence("screening-detached-history.json", screening_json(current))
}

///|
test "screening New and successful reopen isolate brief identities and retain unsaved editor sessions" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let base = screening_pick(
    reading_fixture(),
    0,
    "include",
    "Retained decision",
  )
  let edited = screening_apply(base, Rationale("Unconfirmed editor text"))
  let fresh = update_brief_view(_ => @rabbita.none, New, edited).1
  assert_true(fresh.screening.log.decisions.is_empty())
  assert_true(fresh.screening.editor is None)
  let opening = update_brief_view(
      _ => @rabbita.none,
      Open(base.draft.brief_id, "notes-revision"),
      fresh,
    ).1
  let reopened = update_brief_view(
      _ => @rabbita.none,
      Loaded(
        opening.generation,
        base.draft.brief_id,
        "notes-revision",
        Ok(notes_payload(base.draft)),
      ),
      opening,
    ).1
  assert_eq(reopened.screening.log, base.screening.log)
  assert_eq(reopened.screening.rationale, "Unconfirmed editor text")
  assert_eq(screening_reload(reopened).screening.log, base.screening.log)
  assert_false(screening_json(reopened).contains("Unconfirmed editor text"))
  let saved_bytes = choice_storage_read(base.screening.key)
  let pending = update_brief_view(_ => @rabbita.none, Save, base).1
  assert_true(pending.pending)
  assert_eq(
    screening_apply(pending, Rationale("ignored")).screening.rationale,
    base.screening.rationale,
  )
  assert_eq(choice_storage_read(base.screening.key), saved_bytes)
}

///|
test "screening editor requires reason protects unsaved changes and rejects stale pending events" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let base = reading_fixture()
  let choice = reference_choice(base, reference_catalog(base).references[0])
  let editor = screening_apply(base, Screen(choice))
  let empty = screening_apply(editor, SaveDecision(false))
  assert_true(empty.screening.log.decisions.is_empty())
  assert_true(empty.screening.notice.contains("rationale"))
  let dirty = screening_apply(
    editor,
    Rationale("<script>my rationale</script>\r\n=1+2"),
  )
  let other = screening_apply(
    dirty,
    Screen(reference_choice(dirty, reference_catalog(dirty).references[1])),
  )
  assert_eq(other.screening.editor, Some(choice))
  assert_eq(other.screening.rationale, dirty.screening.rationale)
  assert_true(other.screening.notice.contains("Save or cancel"))
  let too_long = screening_apply(
    screening_apply(dirty, Rationale("x".repeat(2001))),
    SaveDecision(false),
  )
  assert_true(too_long.screening.log.decisions.is_empty())
  let stale = update_brief_view(
      _ => @rabbita.none,
      Screening(
        base.screening.key,
        base.screening.log.revision - 1,
        SaveDecision(false),
      ),
      dirty,
    ).1
  assert_eq(stale.screening.log, dirty.screening.log)
  assert_true(stale.screening.notice.contains("stale"))
  let saved = screening_apply(dirty, SaveDecision(false))
  let html = reading_render(saved)
  assert_true(html.contains("&lt;script&gt;my rationale&lt;/script&gt;"))
  assert_false(html.contains("<script>my rationale</script>"))
  assert_true(html.contains("Save and next unscreened"))
  assert_true(
    html.contains("Native brief Save does not include screening decisions"),
  )
  assert_eq(
    screening_apply(saved, SaveDecision(false)).screening.log,
    saved.screening.log,
  )
}

///|
test "screening storage quota conflict unavailable and corrupt bytes never erase history" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let base = screening_pick(reading_fixture(), 0, "include", "First decision")
  let stored = choice_storage_read(base.screening.key)
  set_choice_storage_mode("quota")
  let unsaved = screening_pick(
    base, 1, "exclude", "Retained after storage failure",
  )
  assert_false(unsaved.screening.saved)
  assert_eq(unsaved.screening.log.decisions.length(), 2)
  assert_eq(choice_storage_read(base.screening.key), stored)
  assert_true(
    screening_json(unsaved).contains("Retained after storage failure"),
  )
  set_choice_storage_mode("ok")
  let retried = screening_apply(unsaved, RetrySave)
  assert_true(retried.screening.saved)
  assert_eq(screening_reload(retried).screening.log, retried.screening.log)
  let conflict = screening_pick(base, 2, "undecided", "Stale-tab decision")
  assert_false(conflict.screening.saved)
  assert_true(conflict.screening.notice.contains("another tab"))
  assert_eq(screening_reload(conflict).screening.log, retried.screening.log)
  ignore(choice_storage_write(base.screening.key, "{corrupt stored bytes"))
  let blocked = screening_reload(retried)
  assert_true(blocked.screening.blocked)
  assert_eq(blocked.screening.unreadable, "{corrupt stored bytes")
  assert_true(screening_apply(blocked, RetrySave).screening.blocked)
  assert_eq(
    choice_storage_read(base.screening.key),
    "{\"value\":\"{corrupt stored bytes\"}",
  )
  ignore(
    choice_storage_write(
      base.screening.key,
      ToJson::to_json(retried.screening.log).stringify(),
    ),
  )
  set_choice_storage_mode("read-error")
  let unreadable = screening_reload(retried)
  assert_true(unreadable.screening.blocked)
  set_choice_storage_mode("ok")
  let recovered = screening_apply(unreadable, RetryRead)
  assert_false(recovered.screening.blocked)
  assert_eq(recovered.screening.log, retried.screening.log)
}

///|
test "screening decoder bounds status exact capture sequence brief and full revision limit" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let view = screening_pick(reading_fixture(), 0, "include", "Valid decision")
  let log = view.screening.log
  let entry = log.decisions[0]
  for
    invalid in [
      { ..log, brief_id: "different", },
      { ..log, contract_id: "future", },
      { ..log, decisions: [{ ..entry, sequence: 3, }], },
      { ..log, decisions: [{ ..entry, decision: "accepted-fact", }], },
      { ..log, decisions: [{ ..entry, rationale: " ", }], },
      {
        ..log,
        decisions: [
          {
            ..entry,
            reference: { ..entry.reference, title: "Changed title", },
          },
        ],
      },
    ] {
    try
      screening_decode(ToJson::to_json(invalid).stringify(), log.brief_id)
    catch {
      _ => ()
    } noraise {
      _ => fail("Invalid screening log accepted")
    }
  }
  let full = {
    ..view,
    screening: {
      ..view.screening,
      log: {
        ..log,
        revision: 200,
        decisions: Array::makei(200, i => { ..entry, sequence: i + 1, }),
      },
    },
  }
  let rejected = screening_apply(
    screening_apply(full, Rationale("Revision 201")),
    SaveDecision(false),
  )
  assert_eq(rejected.screening.log, full.screening.log)
  assert_true(rejected.screening.notice.contains("200 retained"))
}

///|
test "screening public root downloads real Blob CSV and full JSON without changing original citations" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let base = screening_pick(
    reading_fixture(),
    0,
    "include",
    "=HYPERLINK(\"https://example.invalid\")\r\nQuoted \"reason\" 🌒",
  )
  let view = screening_apply(base, Scope("include"))
  let model = { ..initial_model(), brief: view, }
  for
    (action, name, mime, content) in [
      (
        ScreeningMsg::ExportCsv,
        "moonfind-screening.csv",
        "text/csv;charset=utf-8",
        screening_csv(view),
      ),
      (
        ScreeningMsg::ExportJson,
        "moonfind-screening-history.json",
        "application/json;charset=utf-8",
        screening_json(view),
      ),
    ] {
    for mode in ["create", "click", ""] {
      shortlist_download_fixture(mode)
      let result = update(
          _ => @rabbita.none,
          BriefAction(
            Screening(view.screening.key, view.screening.log.revision, action),
          ),
          model,
        ).1.brief
      assert_eq(result.screening.log, view.screening.log)
      assert_eq(result.draft, view.draft)
      if mode.is_empty() {
        assert_true(result.screening.notice.contains("download requested"))
        shortlist_download_verify(content, name, mime)
      } else {
        assert_true(result.screening.notice.contains("download failed"))
      }
      shortlist_download_restore()
    }
  }
  assert_true(
    screening_csv(view).contains(
      "\"'=HYPERLINK(\"\"https://example.invalid\"\")",
    ),
  )
  assert_eq(screening_csv_cell("  +123"), "\"'  +123\"")
  assert_eq(
    screening_csv_cell("normal\nvalue,\"quoted\""),
    "\"normal\nvalue,\"\"quoted\"\"\"",
  )
  assert_true(screening_json(view).contains("=HYPERLINK"))
  // Unrelated local-source bodies are never included in the screening report.
  let extra = reading_source(
    "private-unrelated.txt", "Unrelated sensitive draft body",
  )
  let appended = sync_screening(
    brief_edited(view, { ..view.draft, sources: view.draft.sources + [extra], }),
  )
  assert_false(screening_json(appended).contains(extra.content_hex))
  reading_evidence("screening-formula-safe.csv", screening_csv(view))
}
