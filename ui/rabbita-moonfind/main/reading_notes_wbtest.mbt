///|
fn notes_apply(view : BriefView, action : ReadingNotesMsg) -> BriefView {
  update_brief_view(
    _ => @rabbita.none,
    ReadingNotes(
      view.reading_notes.key,
      view.reading_notes.notebook.revision,
      action,
    ),
    view,
  ).1
}

///|
fn notes_pick(view : BriefView, index : Int, text : String) -> BriefView {
  let chosen = notes_apply(
    view,
    Create(reference_choice(view, reference_catalog(view).references[index])),
  )
  notes_apply(chosen, Write(chosen.reading_notes.selected, text))
}

///|
fn notes_reload(view : BriefView) -> BriefView {
  sync_reading_notes({
    ..view,
    reading_notes: restore_reading_notes(view.draft),
    reading_note_sessions: Map([]),
  })
}

///|
fn notes_payload(draft : BriefDraft) -> Json {
  let snapshot : BriefSnapshot = {
    contract_id: "moonfind.brief-snapshot.v1",
    revision_id: "notes-revision",
    state: "prepared",
    brief: draft,
    sources: [],
    boundary: "Synthetic host response; no native persistence claim",
  }
  {
    "contract_id": "moonfind.brief-status.v1",
    "brief_id": draft.brief_id,
    "revision_id": "notes-revision",
    "state": "prepared",
    "snapshot": ToJson::to_json(snapshot),
    "issues": [],
  }
}

///|
test "reading notes save reload exact handwritten text reference capture and duplicate identities" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let base = reading_fixture()
  let first = notes_pick(
    base, 0, "My observation 🌒\n<script>Check replication</script>\r\nDo not merge DOI peers.",
  )
  let second = notes_pick(first, 1, "Conflicting same-DOI evidence")
  let third = notes_pick(second, 4, "Exact numeric CSL ID")
  let book = third.reading_notes.notebook
  assert_true(third.reading_notes.saved)
  assert_eq(book.notes.length(), 3)
  assert_eq(book.notes[0].reference, reference_catalog(base).references[0])
  assert_eq(book.notes[0].capture, base.draft.sources[1])
  assert_eq(book.notes[2].reference.item_id, "9007199254740993")
  assert_eq(
    book.notes[0].reference.doi_match_key,
    book.notes[1].reference.doi_match_key,
  )
  assert_false(book.notes[0].id == book.notes[1].id)
  let restored = notes_reload(third)
  assert_eq(restored.reading_notes.notebook, book)
  let html = reading_render(notes_apply(restored, Select(book.notes[0].id)))
  assert_true(html.contains("Browser-local reading notes"))
  assert_true(html.contains("&lt;script&gt;Check replication&lt;/script&gt;"))
  assert_false(html.contains("<script>Check replication</script>"))
  assert_true(html.contains("Native brief Save does not contain notes"))
  assert_true(html.contains("New reading note for this snapshot"))
  reading_evidence(
    "reading-notes-inputs.json",
    ToJson::to_json(base.draft.sources).stringify(indent=2),
  )
  reading_evidence(
    "reading-notes-retained.json",
    ToJson::to_json(book).stringify(indent=2),
  )
  reading_evidence("reading-notes-panel.html", html)
}

///|
test "reading notes filters and appends retain snapshots while removal reorder replacement detach forever" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let base = notes_pick(reading_fixture(), 1, "Retained original")
  let before = base.reading_notes.notebook.notes[0]
  for
    action in [
      ReferenceListMsg::Query("nothing"),
      Duplicates,
      ShowDoi("10.1234/shared"),
      Clear,
    ] {
    assert_eq(
      reading_apply(base, action).reading_notes.notebook.notes[0],
      before,
    )
  }
  let appended = sync_reading_notes(
    brief_edited(base, {
      ..base.draft,
      sources: base.draft.sources + [base.draft.sources[1]],
    }),
  )
  assert_true(
    reading_note_current(appended, appended.reading_notes.notebook.notes[0]),
  )
  let duplicate = notes_pick(
    appended, 9, "Identical repeated capture remains separate",
  )
  assert_eq(duplicate.reading_notes.notebook.notes.length(), 2)
  assert_eq(duplicate.reading_notes.notebook.notes[1].reference.source_slot, 7)
  // Every branch starts from a separately restored base to respect compare/write.
  for mode in ["remove", "reorder", "replace"] {
    let current = notes_reload(duplicate)
    let sources = current.draft.sources.copy()
    if mode == "remove" {
      sources.remove(0) |> ignore
    } else if mode == "reorder" {
      let source = sources[1]
      sources[1] = sources[6]
      sources[6] = source
      // Identical captures have identical bytes; removing their earlier occurrence
      // is observable and must detach rather than migrate the retained slot.
      sources.remove(1) |> ignore
    } else {
      sources[1] = { ..sources[1], origin: "changed origin, same DOI", }
    }
    let changed = sync_reading_notes(
      brief_edited(current, { ..current.draft, sources, }),
    )
    let note = changed.reading_notes.notebook.notes[0]
    assert_false(note.attached)
    assert_eq(note.reference, before.reference)
    assert_eq(note.capture, before.capture)
    assert_eq(note.text, before.text)
    let back = sync_reading_notes(brief_edited(changed, base.draft))
    assert_false(back.reading_notes.notebook.notes[0].attached)
    assert_false(notes_reload(back).reading_notes.notebook.notes[0].attached)
    reading_evidence(
      "reading-notes-detached-" + mode + ".json",
      ToJson::to_json(back.reading_notes.notebook).stringify(indent=2),
    )
  }
}

///|
test "reading notes New successful same other brief reopen save and failed reopen lifecycle isolation" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let base = notes_pick(reading_fixture(), 1, "Original brief notebook")
  let saved_bytes = choice_storage_read(base.reading_notes.key)
  let saved = update_brief_view(
      _ => @rabbita.none,
      Loaded(
        base.generation,
        base.draft.brief_id,
        "",
        Ok(notes_payload(base.draft)),
      ),
      { ..base, pending: true, },
    ).1
  assert_eq(saved.reading_notes.notebook, base.reading_notes.notebook)
  let opening = update_brief_view(
      _ => @rabbita.none,
      Open("other-brief", "notes-revision"),
      saved,
    ).1
  let failed = update_brief_view(
      _ => @rabbita.none,
      Loaded(
        opening.generation,
        "other-brief",
        "notes-revision",
        Ok({ "error": { "message": "unavailable" } }),
      ),
      opening,
    ).1
  assert_eq(failed.reading_notes.notebook, base.reading_notes.notebook)
  let fresh = update_brief_view(_ => @rabbita.none, New, base).1
  assert_eq(fresh.reading_notes.notebook.notes, [])
  assert_false(fresh.reading_notes.key == base.reading_notes.key)
  assert_eq(choice_storage_read(base.reading_notes.key), saved_bytes)
  let other_draft = { ..base.draft, brief_id: "other-brief", }
  let other = update_brief_view(
      _ => @rabbita.none,
      Loaded(
        fresh.generation,
        "other-brief",
        "notes-revision",
        Ok(notes_payload(other_draft)),
      ),
      { ..fresh, pending: true, },
    ).1
  assert_eq(other.reading_notes.notebook.notes, [])
  let other = notes_pick(other, 1, "Independent same reference note")
  let back = update_brief_view(
      _ => @rabbita.none,
      Loaded(
        other.generation,
        base.draft.brief_id,
        "notes-revision",
        Ok(notes_payload(base.draft)),
      ),
      { ..other, pending: true, },
    ).1
  assert_eq(back.reading_notes.notebook, base.reading_notes.notebook)
  assert_eq(
    notes_reload(other).reading_notes.notebook.notes[0].text,
    "Independent same reference note",
  )
  assert_eq(choice_storage_read(base.reading_notes.key), saved_bytes)
}

///|
test "reading notes pending stale card stale edit and stale brief actions cannot write" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let base = reading_fixture()
  let choice = reference_choice(base, reference_catalog(base).references[1])
  let edited = notes_pick(base, 1, "Current")
  let bytes = choice_storage_read(edited.reading_notes.key)
  let stale = update_brief_view(
      _ => @rabbita.none,
      ReadingNotes(
        base.reading_notes.key,
        base.reading_notes.notebook.revision,
        Create(choice),
      ),
      edited,
    ).1
  assert_eq(stale.reading_notes.notebook, edited.reading_notes.notebook)
  assert_true(stale.reading_notes.notice.contains("stale"))
  let pending = { ..edited, pending: true, }
  for
    action in [
      ReadingNotesMsg::Create(choice),
      Write(edited.reading_notes.selected, "late"),
      Save,
      Select("unknown"),
      RetryRead,
    ] {
    assert_eq(
      notes_apply(pending, action).reading_notes.notebook,
      edited.reading_notes.notebook,
    )
  }
  let removed = update_brief_view(_ => @rabbita.none, RemoveSource(0), edited).1
  assert_eq(
    notes_apply(removed, Create(choice)).reading_notes.notebook.notes.length(),
    1,
  )
  let fresh = update_brief_view(_ => @rabbita.none, New, edited).1
  let stale_new = update_brief_view(
      _ => @rabbita.none,
      ReadingNotes(
        edited.reading_notes.key,
        edited.reading_notes.notebook.revision,
        Write(edited.reading_notes.selected, "wrong brief"),
      ),
      fresh,
    ).1
  assert_eq(stale_new.reading_notes.notebook.notes, [])
  assert_false(bytes.is_empty())
}

///|
test "reading notes corrupt mismatched and unreadable storage remain unchanged until readable" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let base = reading_fixture()
  let key = base.reading_notes.key
  assert_eq(choice_storage_write(key, "{broken note data"), "")
  let broken = notes_reload(base)
  assert_true(broken.reading_notes.blocked)
  assert_eq(broken.reading_notes.unreadable, "{broken note data")
  let attempted = notes_pick(broken, 0, "must not replace")
  assert_eq(attempted.reading_notes.notebook.notes, [])
  assert_eq(
    choice_storage_read(key),
    choice_storage_read(broken.reading_notes.key),
  )
  assert_eq(
    @json.parse(choice_storage_read(key)),
    ({ "value": "{broken note data" } : Json),
  )
  set_choice_storage_mode("read-error")
  let unreadable = notes_reload(base)
  assert_true(unreadable.reading_notes.blocked)
  set_choice_storage_mode("ok")
  assert_true(notes_apply(unreadable, RetryRead).reading_notes.blocked)
  assert_eq(
    choice_storage_write(
      key,
      ToJson::to_json(base.reading_notes.notebook).stringify(),
    ),
    "",
  )
  let recovered = notes_apply(unreadable, RetryRead)
  assert_false(recovered.reading_notes.blocked)
  assert_true(
    notes_pick(recovered, 0, "Recovered readable storage").reading_notes.saved,
  )
}

///|
test "reading notes quota retry cross-tab conflict and failed-session switching preserve bytes" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let base = notes_pick(reading_fixture(), 1, "Persisted")
  let bytes = choice_storage_read(base.reading_notes.key)
  set_choice_storage_mode("quota")
  let unsaved = notes_apply(
    base,
    Write(base.reading_notes.selected, "Unsaved edit"),
  )
  assert_false(unsaved.reading_notes.saved)
  assert_eq(choice_storage_read(base.reading_notes.key), bytes)
  let fresh = update_brief_view(_ => @rabbita.none, New, unsaved).1
  let back = sync_reading_notes({ ..fresh, draft: base.draft, })
  assert_eq(back.reading_notes.notebook.notes[0].text, "Unsaved edit")
  assert_false(back.reading_notes.saved)
  set_choice_storage_mode("ok")
  let saved = notes_apply(back, Save)
  assert_true(saved.reading_notes.saved)
  assert_eq(
    notes_reload(saved).reading_notes.notebook.notes[0].text,
    "Unsaved edit",
  )
  let other_tab = notes_reload(saved)
  let first_tab = notes_apply(
    saved,
    Write(saved.reading_notes.selected, "Another tab won"),
  )
  let first_bytes = choice_storage_read(first_tab.reading_notes.key)
  let stale = notes_apply(
    notes_apply(other_tab, Select(saved.reading_notes.selected)),
    Write(saved.reading_notes.selected, "Do not overwrite winner"),
  )
  assert_false(stale.reading_notes.saved)
  assert_true(stale.reading_notes.notice.contains("changed elsewhere"))
  assert_eq(
    stale.reading_notes.notebook.notes[0].text,
    "Do not overwrite winner",
  )
  assert_eq(choice_storage_read(stale.reading_notes.key), first_bytes)
}

///|
test "reading notes strict decode snapshot tampering schema and bounds refuse without mutation" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let base = notes_pick(reading_fixture(), 1, "Kept")
  let book = base.reading_notes.notebook
  let note = book.notes[0]
  for
    invalid in [
      { ..book, contract_id: "unknown", },
      { ..book, brief_id: "different", },
      { ..book, revision: -1, },
      { ..book, notes: [note, note], },
      {
        ..book,
        notes: [
          {
            ..note,
            reference: { ..note.reference, title: "Same DOI retarget attempt", },
          },
        ],
      },
      {
        ..book,
        notes: [{ ..note, reference: { ..note.reference, source_slot: 0, }, }],
      },
      {
        ..book,
        notes: [{ ..note, capture: { ..note.capture, content_hex: "ff", }, }],
      },
      { ..book, notes: [{ ..note, text: "x".repeat(10001), }], },
    ] {
    try
      reading_notes_decode(ToJson::to_json(invalid).stringify(), book.brief_id)
    catch {
      _ => ()
    } noraise {
      _ => fail("Expected refusal")
    }
  }
  let refused = notes_apply(base, Write(note.id, "x".repeat(10001)))
  assert_eq(refused.reading_notes.notebook, book)
  assert_eq(notes_reload(refused).reading_notes.notebook, book)
  assert_eq(
    notes_apply(base, Write("unknown", "ignored")).reading_notes.notebook,
    book,
  )
}

///|
test "reading notes remain independent of existing selected and current JSON RIS scopes" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let base = shortlist_fixture()
  let selected_json = reference_shortlist_json(base)
  let selected_ris = reference_shortlist_ris(base)
  let current_json = reference_list_export(base)
  let current_ris = reference_ris_export(base)
  let noted = notes_pick(
    base, 1, "Private handwritten annotation excluded from citation exports",
  )
  assert_eq(reference_shortlist_json(noted), selected_json)
  assert_eq(reference_shortlist_ris(noted), selected_ris)
  assert_eq(reference_list_export(noted), current_json)
  assert_eq(reference_ris_export(noted), current_ris)
  reading_evidence("notes-selected-regression.json", selected_json)
  reading_evidence("notes-selected-regression.ris", selected_ris)
  reading_evidence("notes-current-regression.json", current_json)
  reading_evidence("notes-current-regression.ris", current_ris)
}

///|
extern "js" fn notes_restart_role() -> String =
  #|() => process.env.MOONFIND_NOTES_RESTART || ''

///|
// Executed separately in writer/reader/detached Node processes against one actual
// --localstorage-file. The ordinary suite leaves this explicit integration idle.
test "reading notes real file-backed restart integration" {
  let role = notes_restart_role()
  if role.is_empty() {
    return
  }
  if role == "writer" {
    let base = reading_fixture()
    let model = { ..initial_model(), brief: base, }
    let (_, edited) = update_brief(
      _ => @rabbita.none,
      Edit("question", "Restart exact paper notes"),
      model,
    )
    let first = notes_pick(
      edited.brief,
      4,
      "Restart annotation 🌒\nQuestion: does the method replicate?",
    )
    assert_true(first.reading_notes.saved)
    assert_eq(first.reading_notes.notebook.notes.length(), 1)
    reading_evidence(
      "restart-writer.json",
      ToJson::to_json(first.reading_notes.notebook).stringify(indent=2),
    )
  } else {
    let restored = initial_brief_view()
    assert_true(restored.restored_draft)
    assert_eq(restored.draft.question, "Restart exact paper notes")
    assert_eq(restored.reading_notes.notebook.notes.length(), 1)
    let note = restored.reading_notes.notebook.notes[0]
    assert_eq(note.reference.item_id, "9007199254740993")
    assert_eq(note.reference.title, "Contact synthesis")
    assert_eq(
      note.text,
      "Restart annotation 🌒\nQuestion: does the method replicate?",
    )
    assert_true(reference_selection(note.capture, 4).contains(note.reference))
    if role == "reader" {
      assert_true(reading_note_current(restored, note))
      reading_evidence(
        "restart-reader.json",
        ToJson::to_json(restored.reading_notes.notebook).stringify(indent=2),
      )
      let model = { ..initial_model(), brief: restored, }
      let (_, removed) = update_brief(
        _ => @rabbita.none,
        RemoveSource(0),
        model,
      )
      assert_false(removed.brief.reading_notes.notebook.notes[0].attached)
      assert_true(removed.brief.reading_notes.saved)
      reading_evidence(
        "restart-source-removed.json",
        ToJson::to_json(removed.brief.reading_notes.notebook).stringify(
          indent=2,
        ),
      )
    } else {
      assert_eq(role, "detached")
      assert_false(note.attached)
      assert_eq(restored.draft.sources.length(), 5)
      reading_evidence(
        "restart-detached-reader.json",
        ToJson::to_json(restored.reading_notes.notebook).stringify(indent=2),
      )
    }
  }
}

///|
test "reading notes changed metadata same DOI and moved source preserve original snapshot" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let base = notes_pick(reading_fixture(), 1, "Original title observation")
  let original = base.reading_notes.notebook.notes[0]
  let sources = base.draft.sources.copy()
  let selection : BibtexSelection = @json.from_json(
    @json.parse(reference_capture_text(sources[1].content_hex)),
  )
  let changed_selection = {
    ..selection,
    references: selection.references.map(record => {
      if record.record_number == 2 {
        { ..record, title: "Revised title retaining DOI", }
      } else {
        record
      }
    }),
  }
  sources[1] = {
    ..sources[1],
    content_hex: brief_text_hex(
      (
        {
          "contract_id": changed_selection.contract_id,
          "source_name": changed_selection.source_name,
          "source_digest": changed_selection.source_digest,
          "references": ToJson::to_json(changed_selection.references),
        } : Json).stringify(),
    ),
  }
  let changed = sync_reading_notes(
    brief_edited(base, { ..base.draft, sources, }),
  )
  assert_false(changed.reading_notes.notebook.notes[0].attached)
  assert_eq(
    changed.reading_notes.notebook.notes[0].reference,
    original.reference,
  )
  let selected = notes_pick(changed, 1, "New title gets its own note")
  assert_eq(selected.reading_notes.notebook.notes.length(), 2)
  assert_eq(
    selected.reading_notes.notebook.notes[1].reference.title,
    "Revised title retaining DOI",
  )
  assert_eq(
    selected.reading_notes.notebook.notes[1].reference.doi,
    original.reference.doi,
  )
  assert_false(
    selected.reading_notes.notebook.notes[0].id ==
    selected.reading_notes.notebook.notes[1].id,
  )
  let moved = selected.draft.sources.copy()
  let first = moved[1]
  moved[1] = moved[3]
  moved[3] = first
  let reordered = sync_reading_notes(
    brief_edited(selected, { ..selected.draft, sources: moved, }),
  )
  assert_true(
    reordered.reading_notes.notebook.notes.all(note => !note.attached),
  )
  assert_eq(reordered.reading_notes.notebook.notes[1].reference.source_slot, 2)
  assert_eq(
    notes_reload(reordered).reading_notes.notebook,
    reordered.reading_notes.notebook,
  )
  reading_evidence(
    "reading-notes-changed-metadata.json",
    ToJson::to_json(reordered.reading_notes.notebook).stringify(indent=2),
  )
}

///|
test "reading notes notebook size refusal preserves prior editable saved state" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let base = notes_pick(reading_fixture(), 1, "Keep saved note")
  let state = base.reading_notes
  let huge = {
    ..state,
    notebook: {
      ..state.notebook,
      sources: [{ ..base.draft.sources[1], origin: "x".repeat(1100000), }],
    },
  }
  let refused = commit_reading_note(state, huge)
  assert_eq(refused.notebook, state.notebook)
  assert_true(refused.saved)
  assert_true(
    refused.notice.contains("previous notes and stored bytes are unchanged"),
  )
  assert_eq(choice_storage_read(state.key), choice_storage_read(refused.key))
  let huge_book = {
    ..state.notebook,
    notes: Array::makei(100, i => {
      ..state.notebook.notes[0],
      id: "note-\{i}",
    }),
  }
  let full = { ..base, reading_notes: { ..state, notebook: huge_book, }, }
  assert_eq(
    notes_apply(
      full,
      Create(reference_choice(full, reference_catalog(full).references[1])),
    ).reading_notes.notebook,
    huge_book,
  )
  try reading_notes_decode("x".repeat(1048577), state.notebook.brief_id) catch {
    _ => ()
  } noraise {
    _ => fail("Expected size refusal")
  }
}
