///|
fn brief_fixture_draft() -> BriefDraft {
  {
    ..blank_brief(),
    brief_id: "brief-ui-fixture",
    question: "Local source question 月面 🌒 <script>",
    objective: "Plan a comparison",
    audience: "Lab reviewers",
    decision: "Choose the next experiment",
    acceptance_criteria: "Show unknowns",
    sources: [
      {
        name: "source.txt",
        origin: "pasted fixture",
        captured_at: "2026-10-07T14:00:00Z",
        kind: "pasted-text",
        content_hex: brief_text_hex("source 月面 🌒\r\n"),
      },
    ],
  }
}

///|
fn brief_fixture_reply(draft : BriefDraft, revision : String) -> Json {
  {
    "contract_id": "moonfind.brief-status.v1",
    "brief_id": draft.brief_id,
    "revision_id": revision,
    "state": "prepared",
    "issues": [],
    "snapshot": {
      "contract_id": "moonfind.brief-snapshot.v1",
      "revision_id": revision,
      "state": "prepared",
      "brief": draft.to_json(),
      "sources": [
        {
          "slot": 1,
          "name": "source.txt",
          "origin": "pasted fixture",
          "captured_at": "2026-10-07T14:00:00Z",
          "kind": "pasted-text",
          "availability": "retained-local-capture",
          "archive_path": "sources/source-1.txt",
          "byte_count": 22,
          "digest": "sha256:fixture",
        },
      ],
      "boundary": "Prepared brief only. No research or approval.",
    },
  }
}

///|
test "brief unreadable and corrupt browser drafts are preserved until explicit New" {
  for mode in ["read-error", "corrupt"] {
    install_choice_storage("ok")
    defer restore_choice_storage()
    let raw = if mode == "corrupt" {
      "{broken"
    } else {
      brief_fixture_draft().to_json().stringify()
    }
    assert_eq(choice_storage_write("moonfind.offline-brief.v1", raw), "")
    if mode == "read-error" {
      set_choice_storage_mode("read-error")
    }
    let model = initial_model()
    assert_true(model.brief.storage_problem is Some(_))
    assert_true(qa_test_render(model).contains("has not been replaced"))
    set_choice_storage_mode("ok")
    let (_, edited) = update(
      _ => @rabbita.none,
      BriefAction(Edit("question", "new unsaved text")),
      model,
    )
    assert_true(edited.brief.storage_problem is Some(_))
    assert_eq(
      @json.parse(choice_storage_read("moonfind.offline-brief.v1")),
      ({ "value": raw } : Json),
    )
    let (_, fresh) = update(_ => @rabbita.none, BriefAction(New), edited)
    assert_true(fresh.brief.storage_problem is None)
    assert_eq(
      @json.parse(choice_storage_read("moonfind.offline-brief.v1")),
      ({ "value": fresh.brief.draft.to_json().stringify() } : Json),
    )
  }
}

///|
test "brief restored saved copy explicitly requires reopen before revision edits" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let draft = brief_fixture_draft()
  ignore(
    choice_storage_write(
      "moonfind.offline-brief.v1",
      draft.to_json().stringify(),
    ),
  )
  let restored = initial_model()
  assert_true(restored.brief.restored_draft)
  assert_true(
    qa_test_render(restored).contains(
      "reopen its saved revision below before editing",
    ),
  )
  let revision = "revision-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  let (_, opening) = update(
    _ => @rabbita.none,
    BriefAction(Open(draft.brief_id, revision)),
    restored,
  )
  let (_, reopened) = update(
    _ => @rabbita.none,
    BriefAction(
      Loaded(
        opening.brief.generation,
        draft.brief_id,
        revision,
        Ok(brief_fixture_reply(draft, revision)),
      ),
    ),
    opening,
  )
  assert_false(reopened.brief.restored_draft)
  let (_, edited) = update(
    _ => @rabbita.none,
    BriefAction(Edit("question", "Revised after reopen")),
    reopened,
  )
  assert_eq(edited.brief.draft.parent_revision, Some(revision))
}

///|
test "brief UI retains exact draft retry and ignores stale asynchronous save reopen and file callbacks" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = {
    ..initial_model(),
    brief: { ..initial_brief_view(), draft: brief_fixture_draft(), },
  }
  let (_, saving) = update(_ => @rabbita.none, BriefAction(Save), model)
  assert_true(saving.brief.pending)
  let (_, duplicate) = update(_ => @rabbita.none, BriefAction(Save), saving)
  assert_eq(duplicate.brief.generation, saving.brief.generation)
  let (_, blocked_edit) = update(
    _ => @rabbita.none,
    BriefAction(Edit("question", "later")),
    saving,
  )
  assert_eq(blocked_edit.brief.draft, saving.brief.draft)
  let (_, fresh) = update(_ => @rabbita.none, BriefAction(New), saving)
  let (_, stale) = update(
    _ => @rabbita.none,
    BriefAction(
      Loaded(
        saving.brief.generation,
        model.brief.draft.brief_id,
        "",
        Ok(
          brief_fixture_reply(
            model.brief.draft,
            "revision-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          ),
        ),
      ),
    ),
    fresh,
  )
  assert_eq(stale.brief.draft, fresh.brief.draft)
  assert_true(stale.brief.opened is None)
  let (_, file_stale) = update(
    _ => @rabbita.none,
    BriefAction(FilesLoaded(saving.brief.generation, "{\"sources\":[]}")),
    fresh,
  )
  assert_eq(file_stale.brief.draft, fresh.brief.draft)
}

///|
test "brief UI prepared state is immutable until edit creates a child basis and changed content is retained" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = {
    ..initial_model(),
    brief: { ..initial_brief_view(), draft: brief_fixture_draft(), },
  }
  let (_, saving) = update(_ => @rabbita.none, BriefAction(Save), model)
  let revision = "revision-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  let (_, saved) = update(
    _ => @rabbita.none,
    BriefAction(
      Loaded(
        saving.brief.generation,
        model.brief.draft.brief_id,
        "",
        Ok(brief_fixture_reply(model.brief.draft, revision)),
      ),
    ),
    saving,
  )
  assert_eq(saved.brief.opened.unwrap().state, "prepared")
  let (_, repeat) = update(_ => @rabbita.none, BriefAction(Save), saved)
  assert_false(repeat.brief.pending)
  let html = qa_test_render(saved)
  assert_true(html.contains("Download complete source dossier + manifest"))
  assert_true(
    html.contains(
      "/api/v1/briefs/brief-ui-fixture/" + revision + "/dossier.zip",
    ),
  )
  assert_true(html.contains("&lt;script&gt;"))
  assert_false(html.contains("<script>"))
  let (_, edited) = update(
    _ => @rabbita.none,
    BriefAction(Edit("objective", "A changed objective")),
    saved,
  )
  assert_eq(edited.brief.draft.parent_revision, Some(revision))
  assert_true(edited.brief.opened is None)
  assert_false(
    qa_test_render(edited).contains(
      "Download complete source dossier + manifest",
    ),
  )
  let restored = initial_brief_view()
  assert_eq(restored.draft, edited.brief.draft)
  assert_eq(saved.brief.draft.objective, "Plan a comparison")
}

///|
test "brief UI rejects mismatched save response and incomplete saved basis has no export" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = {
    ..initial_model(),
    brief: { ..initial_brief_view(), draft: brief_fixture_draft(), },
  }
  let (_, saving) = update(_ => @rabbita.none, BriefAction(Save), model)
  let revision = "revision-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  let mismatch = brief_fixture_reply(
    { ..model.brief.draft, objective: "not submitted", },
    revision,
  )
  let (_, bad) = update(
    _ => @rabbita.none,
    BriefAction(
      Loaded(
        saving.brief.generation,
        model.brief.draft.brief_id,
        "",
        Ok(mismatch),
      ),
    ),
    saving,
  )
  assert_true(bad.brief.opened is None)
  assert_true(bad.brief.error is Some(_))
  let (_, opened) = update(
    _ => @rabbita.none,
    BriefAction(Open(model.brief.draft.brief_id, revision)),
    model,
  )
  let incomplete : Json = {
    "contract_id": "moonfind.brief-status.v1",
    "brief_id": model.brief.draft.brief_id,
    "revision_id": revision,
    "state": "incomplete",
    "issues": ["Missing source bytes"],
  }
  let (_, blocked) = update(
    _ => @rabbita.none,
    BriefAction(
      Loaded(
        opened.brief.generation,
        model.brief.draft.brief_id,
        revision,
        Ok(incomplete),
      ),
    ),
    opened,
  )
  assert_eq(blocked.brief.error, Some("Missing source bytes"))
  assert_eq(blocked.brief.opened.unwrap().state, "incomplete")
  assert_false(
    qa_test_render(blocked).contains(
      "Download complete source dossier + manifest",
    ),
  )
}

///|
// Narrow synchronous Node test transport. All requests go to the actual native
// localhost host; the compiled production reducer and Rabbita HTTP commands run
// unchanged. This is not a fabricated host response or an interactive browser.
extern "js" fn brief_install_native_transport() -> Bool =
  #|() => {
  #| const base = process.env.MOONFIND_BRIEF_NATIVE_URL;
  #| if (!base) return false;
  #| if (!/^http:\/\/127\.0\.0\.1:\d+$/.test(base)) throw new Error('localhost fixture required');
  #| const cp = process.getBuiltinModule('child_process');
  #| globalThis.__briefNativeOldFetch = globalThis.fetch; globalThis.__briefNativeRequests = [];
  #| const chain = (v,e) => ({then(fn){ if(e) return chain(null,e); try{return fn(v)||chain(null,null);}catch(err){return chain(null,err);}},catch(fn){if(e)fn(e);return chain(null,null);}});
  #| globalThis.fetch = (path, options) => {
  #|   try {
  #|     if (!path.startsWith('/api/v1/briefs')) throw new Error('Non-brief request forbidden');
  #|     const args = ['--fail-with-body','--silent','--show-error', '--max-time','10','-X',options.method || 'GET'];
  #|     if(options.body) args.push('-H','Content-Type: application/json','--data-binary',options.body);
  #|     args.push(base + path); globalThis.__briefNativeRequests.push({path,method:options.method || 'GET',body:options.body || null});
  #|     const text=cp.execFileSync('curl',args,{encoding:'utf8'});
  #|     if (globalThis.__briefDropResponseOnce) { globalThis.__briefDropResponseOnce=false; throw new Error('Simulated response loss after native host persisted the request'); }
  #|     return chain({text:()=>chain(text,null)},null);
  #|   }catch(e){return chain(null,e);}
  #| }; return true;
  #|}

///|
extern "js" fn brief_native_export(path : String) -> String =
  #|path => {
  #| if (!path.startsWith('/api/v1/briefs/')) throw new Error('Non-brief export forbidden');
  #| globalThis.__briefNativeRequests.push({path,method:'GET'});
  #| const bytes=process.getBuiltinModule('child_process').execFileSync('curl',['--fail','--silent','--show-error','--max-time','10',process.env.MOONFIND_BRIEF_NATIVE_URL+path]);
  #| return bytes.toString('hex');
  #|}

///|
extern "js" fn brief_native_requests() -> String = "() => JSON.stringify(globalThis.__briefNativeRequests)"

///|
extern "js" fn brief_drop_next_response() -> Unit = "() => {globalThis.__briefDropResponseOnce=true;}"

///|
extern "js" fn brief_restore_native_transport() -> Unit = "() => {globalThis.fetch=globalThis.__briefNativeOldFetch;}"

///|
test "brief compiled UI actual native host save reopen revise export with zero provider requests" {
  if !brief_install_native_transport() {
    return
  }
  defer brief_restore_native_transport()
  install_choice_storage("ok")
  defer restore_choice_storage()
  let scheduler = RouteTestScheduler::{
    hooks: { url_request: None, url_changed: None, },
  }
  let cell = Ref::new({
    ..initial_model(),
    brief: { ..initial_brief_view(), draft: brief_fixture_draft(), },
  })
  fn dispatch(message : Msg) -> @rabbita.Cmd {
    let (command, next) = update(dispatch, message, cell.val)
    cell.val = next
    @cmd.Scheduler::add(scheduler, command)
    @rabbita.none
  }
  ignore(
    choice_storage_write(
      "moonfind.offline-brief.v1",
      cell.val.brief.draft.to_json().stringify(),
    ),
  )
  brief_drop_next_response()
  ignore(dispatch(BriefAction(Save)))
  assert_true(cell.val.brief.error is Some(_))
  assert_true(cell.val.brief.opened is None)
  assert_false(cell.val.brief.pending)
  ignore(dispatch(BriefAction(Save)))
  assert_eq(cell.val.brief.error, None)
  let first = cell.val.brief.opened.unwrap()
  assert_eq(first.state, "prepared")
  let first_draft = cell.val.brief.draft
  let first_html = qa_test_render(cell.val)
  assert_true(first_html.contains("/" + first.revision_id + "/dossier.zip"))
  let first_zip = brief_native_export(
    "/api/v1/briefs/" +
    first.brief_id +
    "/" +
    first.revision_id +
    "/dossier.zip",
  )
  assert_true(first_zip.has_prefix("504b0304"))
  cell.val = initial_model()
  assert_true(cell.val.brief.restored_draft)
  ignore(dispatch(BriefAction(Open(first.brief_id, first.revision_id))))
  assert_false(cell.val.brief.restored_draft)
  assert_eq(cell.val.brief.draft, first_draft)
  ignore(dispatch(BriefAction(Edit("objective", "Revised question basis"))))
  ignore(dispatch(BriefAction(RemoveSource(0))))
  ignore(dispatch(BriefAction(PasteField("name", "source.txt"))))
  ignore(dispatch(BriefAction(PasteField("origin", "Updated local capture"))))
  ignore(
    dispatch(BriefAction(PasteField("text", "Changed source 月面 🌒\r\n"))),
  )
  ignore(dispatch(BriefAction(AddPaste)))
  ignore(dispatch(BriefAction(Save)))
  assert_eq(cell.val.brief.error, None)
  let second = cell.val.brief.opened.unwrap()
  assert_true(second.revision_id != first.revision_id)
  assert_eq(cell.val.brief.draft.parent_revision, Some(first.revision_id))
  assert_true(
    cell.val.brief.draft.sources[0].content_hex !=
    first_draft.sources[0].content_hex,
  )
  ignore(dispatch(BriefAction(Open(first.brief_id, first.revision_id))))
  assert_eq(cell.val.brief.draft, first_draft)
  assert_eq(
    brief_native_export(
      "/api/v1/briefs/" +
      first.brief_id +
      "/" +
      first.revision_id +
      "/dossier.zip",
    ),
    first_zip,
  )
  assert_eq(cell.val.brief.catalog.length(), 2)
  println(
    "MOONFIND_BRIEF_NATIVE=" +
    (
      {
        "first": first.revision_id,
        "second": second.revision_id,
        "requests": @json.parse(brief_native_requests()),
        "provider_calls": 0,
        "html": first_html,
        "zip_hex": first_zip,
      } : Json).stringify(),
  )
}
