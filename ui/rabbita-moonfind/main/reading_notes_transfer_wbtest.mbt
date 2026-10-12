///|
extern "js" fn notes_transfer_clear_test_store() -> Unit =
  #|() => globalThis.__choice_values.clear()

///|
fn notes_transfer_fixture() -> BriefView {
  let first = notes_pick(
    reading_fixture(),
    0,
    "Observation 🌒\r\n<script>Keep exact text</script>",
  )
  let second = notes_pick(first, 1, "Same DOI, independent note")
  notes_pick(second, 4, "Numeric CSL ID stays exact: 9007199254740993")
}

///|
fn notes_transfer_preview(view : BriefView, text : String) -> BriefView {
  notes_apply(notes_apply(view, ImportText(text)), PreviewImport)
}

///|
fn notes_transfer_confirm(view : BriefView) -> BriefView {
  notes_apply(view, ConfirmImport(view.reading_notes.import_text))
}

///|
test "reading backup preview cancellation exact merge and repeated import are non destructive" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let source = notes_transfer_fixture()
  let backup = reading_notes_backup(source.reading_notes)
  notes_transfer_clear_test_store()
  let target = reading_fixture()
  let bytes = choice_storage_read(target.reading_notes.key)
  let preview = notes_transfer_preview(target, backup)
  assert_eq(preview.reading_notes.notebook, target.reading_notes.notebook)
  assert_eq(choice_storage_read(target.reading_notes.key), bytes)
  assert_eq(preview.reading_notes.import_preview.unwrap().added, 3)
  let cancelled = notes_apply(preview, CancelImport)
  assert_true(cancelled.reading_notes.import_preview is None)
  assert_eq(cancelled.reading_notes.import_text, "")
  assert_eq(cancelled.reading_notes.notebook, target.reading_notes.notebook)
  assert_eq(choice_storage_read(target.reading_notes.key), bytes)
  let imported = notes_transfer_confirm(
    notes_transfer_preview(cancelled, backup),
  )
  assert_true(imported.reading_notes.saved)
  assert_eq(
    imported.reading_notes.notebook.notes,
    source.reading_notes.notebook.notes,
  )
  assert_eq(imported.draft, target.draft)
  assert_eq(imported.reference_shortlist, target.reference_shortlist)
  assert_eq(
    notes_reload(imported).reading_notes.notebook,
    imported.reading_notes.notebook,
  )
  let first_bytes = choice_storage_read(imported.reading_notes.key)
  let repeated = notes_transfer_confirm(
    notes_transfer_preview(imported, backup),
  )
  assert_eq(repeated.reading_notes.notebook, imported.reading_notes.notebook)
  assert_eq(choice_storage_read(imported.reading_notes.key), first_bytes)
  assert_true(
    repeated.reading_notes.notice.contains("already exists unchanged"),
  )
  assert_eq(reference_list_export(imported), reference_list_export(target))
  assert_eq(reference_ris_export(imported), reference_ris_export(target))
  reading_evidence(
    "backup-roundtrip.json",
    reading_notes_backup(imported.reading_notes),
  )
}

///|
test "reading backup conflicts schema wrong brief tampered snapshots and oversize reject atomically" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let target = notes_transfer_fixture()
  let book = target.reading_notes.notebook
  let note = book.notes[0]
  let novel = { ..note, id: "new-note-before-conflict", }
  let bytes = choice_storage_read(target.reading_notes.key)
  for
    invalid in [
      { ..book, contract_id: "future.v99", },
      { ..book, brief_id: "another-brief", },
      { ..book, notes: [note, note], },
      { ..book, notes: [novel, { ..note, text: "Changed same ID", }], },
      {
        ..book,
        notes: [
          { ..note, reference: { ..note.reference, title: "Retarget", }, },
        ],
      },
      { ..book, notes: [{ ..note, text: "x".repeat(10001), }], },
      { ..book, notes: Array::makei(101, i => { ..note, id: "note-\{i}", }), },
    ] {
    let rejected = notes_transfer_preview(
      target,
      ToJson::to_json(invalid).stringify(),
    )
    assert_true(rejected.reading_notes.import_preview is None)
    assert_eq(rejected.reading_notes.notebook, book)
    assert_true(rejected.reading_notes.notice.contains("refused"))
    assert_eq(choice_storage_read(target.reading_notes.key), bytes)
  }
  for text in ["{broken", "[]", "x".repeat(1048577)] {
    let rejected = notes_transfer_preview(target, text)
    assert_true(rejected.reading_notes.import_preview is None)
    assert_eq(rejected.reading_notes.notebook, book)
  }
  let full = {
    ..book,
    notes: Array::makei(100, i => { ..note, id: "existing-\{i}", }),
  }
  try
    reading_notes_import_preview(ToJson::to_json(book).stringify(), full)
  catch {
    _ => ()
  } noraise {
    _ => fail("Expected merged note-count refusal")
  }
}

///|
test "reading backup source continuity detaches new snapshots and never reattaches retained notes" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let source = notes_transfer_fixture()
  let backup = reading_notes_backup(source.reading_notes)
  notes_transfer_clear_test_store()
  let base = reading_fixture()
  let changed = update_brief_view(_ => @rabbita.none, RemoveSource(0), base).1
  let preview = notes_transfer_preview(changed, backup)
  assert_eq(preview.reading_notes.import_preview.unwrap().detached, 3)
  let imported = notes_transfer_confirm(preview)
  assert_true(imported.reading_notes.notebook.notes.all(note => !note.attached))
  for i, note in imported.reading_notes.notebook.notes {
    let original = source.reading_notes.notebook.notes[i]
    assert_eq(note, { ..original, attached: false, })
  }
  let restored_sources = sync_reading_notes({ ..imported, draft: source.draft, })
  let repeated = notes_transfer_confirm(
    notes_transfer_preview(restored_sources, backup),
  )
  assert_true(repeated.reading_notes.notebook.notes.all(note => !note.attached))
  assert_eq(repeated.reading_notes.notebook.notes.length(), 3)
  let detached_backup = reading_notes_backup(imported.reading_notes)
  notes_transfer_clear_test_store()
  let fresh = notes_transfer_confirm(
    notes_transfer_preview(reading_fixture(), detached_backup),
  )
  assert_true(fresh.reading_notes.notebook.notes.all(note => !note.attached))
}

///|
test "reading backup save failures preserve storage and retain merged notes visibly unsaved" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let donor = notes_transfer_fixture()
  let backup = reading_notes_backup(donor.reading_notes)
  notes_transfer_clear_test_store()
  let target = reading_fixture()
  let preview = notes_transfer_preview(target, backup)
  let before = choice_storage_read(target.reading_notes.key)
  set_choice_storage_mode("quota")
  let failed = notes_transfer_confirm(preview)
  assert_false(failed.reading_notes.saved)
  assert_eq(
    failed.reading_notes.notebook.notes,
    donor.reading_notes.notebook.notes,
  )
  assert_eq(choice_storage_read(target.reading_notes.key), before)
  assert_true(reading_render(failed).contains("NOT VERIFIED SAVED"))
  assert_eq(
    reading_notes_decode(
      reading_notes_backup(failed.reading_notes),
      target.draft.brief_id,
    ).notes,
    donor.reading_notes.notebook.notes,
  )
  set_choice_storage_mode("ok")
  let saved = notes_apply(failed, Save)
  assert_true(saved.reading_notes.saved)
  assert_eq(
    notes_reload(saved).reading_notes.notebook,
    saved.reading_notes.notebook,
  )
  notes_transfer_clear_test_store()
  let empty = reading_fixture()
  let stale_preview = notes_transfer_preview(empty, backup)
  let winner = notes_pick(
    empty, 7, "Another tab wrote while import was in preview",
  )
  let winning_bytes = choice_storage_read(winner.reading_notes.key)
  let conflict = notes_transfer_confirm(stale_preview)
  assert_false(conflict.reading_notes.saved)
  assert_true(conflict.reading_notes.notice.contains("changed elsewhere"))
  assert_eq(choice_storage_read(winner.reading_notes.key), winning_bytes)
}

///|
test "reading backup stale confirmation file callbacks pending blocked and cancellation cannot mutate notes" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let target = notes_transfer_fixture()
  let text = reading_notes_backup(target.reading_notes)
  let preview = notes_transfer_preview(target, text)
  let changed = notes_apply(
    preview,
    Write(preview.reading_notes.selected, "Edited after preview"),
  )
  assert_true(changed.reading_notes.import_preview is None)
  let refused = notes_apply(changed, ConfirmImport(text))
  assert_eq(refused.reading_notes.notebook, changed.reading_notes.notebook)
  let changed_input = notes_apply(preview, ImportText(text + " "))
  assert_true(changed_input.reading_notes.import_preview is None)
  let new_preview = notes_apply(changed_input, PreviewImport)
  let stale = notes_apply(new_preview, ConfirmImport(text))
  assert_eq(stale.reading_notes.notebook, target.reading_notes.notebook)
  assert_true(stale.reading_notes.notice.contains("Preview this backup"))
  let choosing = notes_apply(target, ChooseBackup)
  let token = choosing.reading_notes.import_token
  let payload = ({ "text": text } : Json).stringify()
  let cancelled = notes_apply(choosing, CancelImport)
  let late = notes_apply(cancelled, BackupLoaded(token, payload))
  assert_eq(late.reading_notes.import_text, "")
  assert_eq(late.reading_notes.notebook, target.reading_notes.notebook)
  let chosen = notes_apply(choosing, BackupLoaded(token, payload))
  assert_eq(chosen.reading_notes.import_text, text)
  assert_true(chosen.reading_notes.import_preview is None)
  assert_eq(chosen.reading_notes.notebook, target.reading_notes.notebook)
  let pending = { ..preview, pending: true, }
  assert_eq(
    notes_transfer_confirm(pending).reading_notes.notebook,
    target.reading_notes.notebook,
  )
  assert_eq(choice_storage_write(target.reading_notes.key, "{unreadable"), "")
  let blocked = notes_reload(target)
  for
    action in [
      ReadingNotesMsg::ChooseBackup,
      ExportBackup,
      ImportText(text),
      PreviewImport,
      ConfirmImport(text),
    ] {
    let refused = notes_apply(blocked, action)
    assert_true(refused.reading_notes.blocked)
    assert_eq(refused.reading_notes.unreadable, "{unreadable")
  }
}

///|
test "reading backup compiled UI exposes file paste preview counts escaping and explicit confirm only" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let source = notes_transfer_fixture()
  let backup = reading_notes_backup(source.reading_notes)
  notes_transfer_clear_test_store()
  let target = reading_fixture()
  let html = reading_render(target)
  for
    label in [
      "Download reading notes JSON backup", "Choose reading-note backup JSON file",
      "Reading-note backup JSON", "Preview reading-note import", "Cancel reading-note import",
    ] {
    assert_true(html.contains(label), msg=label)
  }
  assert_false(html.contains("Confirm reading-note merge"))
  let preview = notes_transfer_preview(target, backup)
  let html = reading_render(preview)
  assert_true(
    html.contains(
      "3 new notes, 0 identical existing notes skipped, 0 new notes detached",
    ),
  )
  assert_true(html.contains("Confirm reading-note merge"))
  assert_true(html.contains("&lt;script&gt;Keep exact text&lt;/script&gt;"))
  assert_false(html.contains("<script>Keep exact text</script>"))
  assert_true(html.contains("9007199254740993"))
  assert_false(
    reading_render({ ..preview, pending: true, }).contains(
      "Confirm reading-note merge",
    ),
  )
  reading_evidence("backup-preview-panel.html", html)
}

///|
test "reading backup actual Blob download includes unsaved exact notes and reports download failure" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let source = notes_transfer_fixture()
  set_choice_storage_mode("quota")
  let unsaved = notes_apply(
    source,
    Write(source.reading_notes.selected, "Unsaved portable edit 🌒"),
  )
  assert_false(unsaved.reading_notes.saved)
  for failure in ["create", "click"] {
    shortlist_download_fixture(failure)
    let failed = notes_apply(unsaved, ExportBackup)
    shortlist_download_restore()
    assert_true(failed.reading_notes.notice.contains("download failed"))
    assert_eq(failed.reading_notes.notebook, unsaved.reading_notes.notebook)
  }
  shortlist_download_fixture("")
  defer shortlist_download_restore()
  let downloaded = notes_apply(unsaved, ExportBackup)
  assert_true(downloaded.reading_notes.notice.contains("download requested"))
  assert_false(downloaded.reading_notes.saved)
  shortlist_download_verify(
    reading_notes_backup(unsaved.reading_notes),
    "moonfind-reading-notes.json",
    "application/json;charset=utf-8",
  )
}

///|
extern "js" fn notes_transfer_role() -> String =
  #|() => process.env.MOONFIND_BACKUP_ROLE || ''

///|
extern "js" fn notes_transfer_read_artifact() -> String =
  #|() => process.getBuiltinModule('fs').readFileSync(process.env.MOONFIND_BACKUP_INPUT,'utf8')

///|
// Explicit three-process integration: source store -> actual downloaded Blob file
// -> distinct destination store -> fresh process reload of the imported notes.
test "reading backup real file transfer and fresh destination storage restart" {
  let role = notes_transfer_role()
  if role.is_empty() {
    return
  }
  if role == "writer" {
    let source = notes_transfer_fixture()
    assert_true(source.reading_notes.saved)
    shortlist_download_fixture("")
    defer shortlist_download_restore()
    let downloaded = notes_apply(source, ExportBackup)
    assert_true(downloaded.reading_notes.notice.contains("download requested"))
    shortlist_download_verify(
      reading_notes_backup(source.reading_notes),
      "moonfind-reading-notes.json",
      "application/json;charset=utf-8",
    )
    reading_evidence(
      "portable-original-notes.json",
      ToJson::to_json(source.reading_notes.notebook.notes).stringify(),
    )
  } else if role == "importer" {
    let target = reading_fixture()
    assert_eq(target.reading_notes.notebook.notes.length(), 0)
    let (_, model) = update_brief(
      _ => @rabbita.none,
      Edit("question", "Restored portable reading notes"),
      { ..initial_model(), brief: target, },
    )
    let choosing = notes_apply(model.brief, ChooseBackup)
    let loaded = notes_apply(
      choosing,
      BackupLoaded(
        choosing.reading_notes.import_token,
        ({ "text": notes_transfer_read_artifact() } : Json).stringify(),
      ),
    )
    let preview = notes_apply(loaded, PreviewImport)
    assert_eq(preview.reading_notes.notebook.notes.length(), 0)
    let imported = notes_transfer_confirm(preview)
    assert_true(imported.reading_notes.saved)
    assert_eq(imported.reading_notes.notebook.notes.length(), 3)
    reading_evidence(
      "portable-imported-notes.json",
      ToJson::to_json(imported.reading_notes.notebook.notes).stringify(),
    )
  } else {
    assert_eq(role, "reader")
    let restored = initial_brief_view()
    assert_true(restored.restored_draft)
    assert_eq(restored.draft.question, "Restored portable reading notes")
    assert_eq(restored.reading_notes.notebook.notes.length(), 3)
    assert_eq(
      restored.reading_notes.notebook.notes[2].reference.item_id,
      "9007199254740993",
    )
    assert_true(
      restored.reading_notes.notebook.notes.all(note => {
        reading_note_current(restored, note)
      }),
    )
    reading_evidence(
      "portable-reloaded-notes.json",
      ToJson::to_json(restored.reading_notes.notebook.notes).stringify(),
    )
  }
}

///|
// Actual production picker, real File/Blob.arrayBuffer and fatal UTF-8 decoder.
// Only the browser document boundary is controlled; the graphical dialog is not.
extern "js" fn notes_picker_exercise(
  pick : ((String) -> Unit) -> Unit,
  text : String,
) -> Unit =
  #|(pick,text) => {
  #| const old=Object.getOwnPropertyDescriptor(globalThis,'document');
  #| const modes=['valid','cancel','empty','oversize','wrong-extension','invalid-utf8','read-failure','click-failure','changed-byte-size'];
  #| let completed=0;
  #| try {
  #|  for(const mode of modes){
  #|   Object.defineProperty(globalThis,'document',{configurable:true,value:{createElement(tag){
  #|    if(tag!=='input')throw Error('Expected file input');
  #|    const handlers={};
  #|    const file=mode==='invalid-utf8'?new File([new Uint8Array([255])],'backup.json'):new File([text],mode==='wrong-extension'?'backup.txt':'backup.json');
  #|    const files=mode==='empty'?[]:[mode==='oversize'?{name:'backup.json',size:1048577,arrayBuffer(){throw Error('Must reject before read');}}:mode==='changed-byte-size'?{name:'backup.json',size:1,arrayBuffer:async()=>new ArrayBuffer(1048577)}:mode==='read-failure'?{name:'backup.json',size:1,arrayBuffer:async()=>{throw Error('read failed');}}:file];
  #|    return {files,remove(){},addEventListener(type,fn){handlers[type]=fn;},click(){
  #|     if(this.type!=='file'||this.multiple!==false||!this.accept.includes('.json'))throw Error('Incorrect picker wiring');
  #|     if(mode==='click-failure')throw Error('click failed');
  #|     if(mode==='cancel')handlers.cancel();else handlers.change();
  #|    }};
  #|   }}});
  #|   pick(raw=>{
  #|    try {
  #|     const reply=JSON.parse(raw);
  #|     if(mode==='valid'){if(reply.text!==text)throw Error('Exact file bytes were not preserved');}
  #|     else if(mode==='cancel'||mode==='empty'){if(reply.cancelled!==true)throw Error('Cancellation mismatch');}
  #|     else if(typeof reply.error!=='string')throw Error('Expected explicit read failure: '+mode);
  #|     completed++;
  #|    }catch(error){console.error(error);process.exitCode=1;}
  #|   });
  #|  }
  #| }finally{if(old)Object.defineProperty(globalThis,'document',old);else delete globalThis.document;}
  #| process.once('beforeExit',()=>{
  #|  if(completed!==modes.length){console.error('Not all file-picker callbacks completed',completed);process.exitCode=1;}
  #|  const dir=process.env.MOONFIND_READING_EVIDENCE;
  #|  if(dir)process.getBuiltinModule('fs').writeFileSync(dir+'/backup-picker-receipt.json',JSON.stringify({cases:modes,completed,real_file_blob:true,document_boundary_controlled:true},null,2));
  #| });
  #|}

///|
test "reading backup real File bytes chooser validation and cancellation callbacks" {
  notes_picker_exercise(
    reading_notes_choose_backup, "{\"notes\":\"Exact UTF-8 🌒\\r\\n\"}",
  )
}

///|
test "reading backup duplicate exact snapshots remain distinct and combined byte limit refuses" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let donor = notes_pick(reading_fixture(), 8, "Short reference")
  let book = donor.reading_notes.notebook
  let note = book.notes[0]
  let separate = {
    ..book,
    notes: [note, { ..note, id: "distinct-exact-snapshot", }],
  }
  let empty = { ..book, notes: [], }
  let preview = reading_notes_import_preview(
    ToJson::to_json(separate).stringify(),
    empty,
  )
  assert_eq(preview.added, 2)
  assert_eq(preview.notebook.notes.map(note => note.id), [
    note.id,
    "distinct-exact-snapshot",
  ])
  let half = {
    ..book,
    notes: Array::makei(50, i => {
      ..note,
      id: "retained-\{i}",
      text: "x".repeat(10000),
    }),
  }
  let other = {
    ..book,
    notes: Array::makei(50, i => {
      ..note,
      id: "incoming-\{i}",
      text: "x".repeat(10000),
    }),
  }
  reading_notes_decode(ToJson::to_json(half).stringify(), book.brief_id)
  |> ignore
  let text = ToJson::to_json(other).stringify()
  reading_notes_decode(text, book.brief_id) |> ignore
  try reading_notes_import_preview(text, half) catch {
    error => assert_true("\{error}".contains("1 MiB"))
  } noraise {
    _ => fail("Expected merged byte-limit refusal")
  }
}

///|
extern "js" fn notes_transfer_discard_writes() -> Unit =
  #|() => { globalThis.localStorage.setItem=()=>{}; }

///|
test "reading backup a nonthrowing dropped storage write cannot report a verified save" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let donor = notes_transfer_fixture()
  let backup = reading_notes_backup(donor.reading_notes)
  notes_transfer_clear_test_store()
  let target = reading_fixture()
  let before = choice_storage_read(target.reading_notes.key)
  let preview = notes_transfer_preview(target, backup)
  notes_transfer_discard_writes()
  let failed = notes_transfer_confirm(preview)
  assert_false(failed.reading_notes.saved)
  assert_true(failed.reading_notes.notice.contains("could not be verified"))
  assert_eq(choice_storage_read(target.reading_notes.key), before)
  assert_eq(
    failed.reading_notes.notebook.notes,
    donor.reading_notes.notebook.notes,
  )
}
