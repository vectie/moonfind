///|
fn shortlist_pick(view : BriefView, index : Int) -> BriefView {
  reading_apply(
    view,
    Shortlist(
      Toggle(reference_choice(view, reference_catalog(view).references[index])),
    ),
  )
}

///|
fn shortlist_fixture() -> BriefView {
  let base = reading_fixture()
  let bib = shortlist_pick(reading_apply(base, Query("Conflicting method")), 1)
  let ris = shortlist_pick(reading_apply(bib, Query("No DOI available")), 8)
  let csl = shortlist_pick(reading_apply(ris, ShowDoi("10.1234/shared")), 4)
  reading_apply(csl, Query("Rivera"))
}

///|
fn assert_shortlist_refused(view : BriefView) -> Unit raise {
  try reference_shortlist_json(view) catch {
    _ => ()
  } noraise {
    _ => fail("Expected JSON refusal")
  }
  try reference_shortlist_ris(view) catch {
    _ => ()
  } noraise {
    _ => fail("Expected RIS refusal")
  }
}

///|
test "shortlist chooses across formats queries and DOI groups with separate ordered exports" {
  let view = shortlist_fixture()
  assert_eq(view.error, None)
  assert_eq(reference_matches(view, reference_catalog(view)).length(), 1)
  let refs = reference_shortlist_records(view)
  assert_eq(refs.map(r => (r.source_slot, r.record_number)), [
    (2, 2),
    (6, 2),
    (4, 1),
  ])
  assert_eq(refs.map(r => r.format), ["bibtex", "ris", "csl"])
  assert_eq(refs[0].doi_match_key, refs[2].doi_match_key)
  assert_eq(refs[1].doi_match_key, "")
  assert_eq(refs[2].item_id, "9007199254740993")
  let output = reference_shortlist_json(view)
  guard @json.parse(output)
    is {
      "contract_id": String("moonfind.reference-shortlist.v1"),
      "exported_count": Number(3, ..),
      "references": references,
      "selection_captures": Array(captures),
      ..
    } else {
    fail("shortlist contract")
  }
  assert_eq(references, refs.to_json())
  assert_eq(captures.length(), 3)
  assert_false(output.contains("content_hex"))
  assert_false(output.contains("RIS conflict"))
  assert_true(
    @json.parse(reference_list_export(view))
    is { "exported_count": Number(1, ..), .. },
  )
  assert_eq(ris_export_records(reference_ris_export(view)).length(), 1)
  let ris = reference_shortlist_ris(view)
  let records = ris_export_records(ris)
  assert_eq(records.length(), 3)
  for i, record in records {
    guard @json.parse(record["N1"][0])
      is { "reference": reference, "capture_origin": String(origin), .. } else {
      fail("provenance note")
    }
    assert_eq(reference, ToJson::to_json(refs[i]))
    assert_eq(origin, view.draft.sources[refs[i].source_slot - 1].origin)
  }
  reading_evidence(
    "shortlist-inputs.json",
    view.draft.sources.to_json().stringify(indent=2),
  )
  reading_evidence("selected-references.json", output)
  reading_evidence("selected-references.ris", ris)
  reading_evidence("current-match.json", reference_list_export(view))
  reading_evidence("current-match.ris", reference_ris_export(view))
}

///|
test "shortlist clear filters clear choices remove hidden and reselect are independent" {
  let view = shortlist_fixture()
  for
    action in [
      ReferenceListMsg::Clear,
      Duplicates,
      Query("nothing matches"),
      ShowDoi("10.1234/shared.extra"),
    ] {
    let changed = reading_apply(view, action)
    assert_eq(changed.reference_shortlist, view.reference_shortlist)
    assert_eq(reference_shortlist_json(changed), reference_shortlist_json(view))
  }
  let cleared = reading_apply(view, Shortlist(Clear))
  assert_eq(cleared.reference_shortlist, [])
  assert_eq(cleared.reference_query, view.reference_query)
  assert_eq(cleared.reference_doi_filter, view.reference_doi_filter)
  assert_eq(cleared.draft, view.draft)
  let first = view.reference_shortlist[0]
  let removed = reading_apply(view, Shortlist(Toggle(first)))
  assert_eq(reference_shortlist_records(removed).length(), 2)
  let reselected = reading_apply(removed, Shortlist(Toggle(first)))
  assert_eq(reselected.reference_shortlist[2], first)
  assert_eq(reselected.reference_shortlist.length(), 3)
  let twice = reading_apply(reselected, Shortlist(Toggle(first)))
  assert_eq(twice.reference_shortlist, removed.reference_shortlist)
}

///|
test "shortlist stays selected while each production format reducer appends sources" {
  let fixture = reading_fixture()
  let blank = {
    ..fixture,
    draft: { ..fixture.draft, sources: [], },
    pending: true,
  }
  let first = update_brief_view(
      _ => @rabbita.none,
      Bibtex(
        Selected(
          blank.generation,
          Ok([
            ToJson::to_json(fixture.draft.sources[0]),
            ToJson::to_json(fixture.draft.sources[1]),
          ]),
        ),
      ),
      blank,
    ).1
  let picked = shortlist_pick(first, 1)
  let next = update_brief_view(
      _ => @rabbita.none,
      Csl(
        Selected(
          picked.generation,
          Ok([
            ToJson::to_json(fixture.draft.sources[2]),
            ToJson::to_json(fixture.draft.sources[3]),
          ]),
        ),
      ),
      { ..picked, pending: true, },
    ).1
  assert_eq(next.reference_shortlist, picked.reference_shortlist)
  assert_eq(reference_shortlist_records(next).length(), 1)
  let next = shortlist_pick(next, 4)
  let last = update_brief_view(
      _ => @rabbita.none,
      Ris(
        Selected(
          next.generation,
          Ok([
            ToJson::to_json(fixture.draft.sources[4]),
            ToJson::to_json(fixture.draft.sources[5]),
          ]),
        ),
      ),
      { ..next, pending: true, },
    ).1
  assert_eq(last.reference_shortlist, next.reference_shortlist)
  assert_eq(reference_shortlist_records(last).length(), 2)
  assert_eq(reference_catalog(last).references.length(), 9)
  let edited = update_brief_view(
      _ => @rabbita.none,
      Edit("question", "A different question"),
      last,
    ).1
  assert_eq(
    reference_shortlist_records(edited),
    reference_shortlist_records(last),
  )
}

///|
test "shortlist source removal replacement and identical capture shifts never retarget choices" {
  let base = reading_fixture()
  let copy = base.draft.sources[1]
  let repeated = { ..base, draft: { ..base.draft, sources: [copy, copy], }, }
  let selected = shortlist_pick(shortlist_pick(repeated, 0), 4)
  assert_eq(reference_shortlist_records(selected).map(r => r.source_slot), [
    1, 2,
  ])
  let removed = update_brief_view(_ => @rabbita.none, RemoveSource(0), selected).1
  assert_eq(removed.reference_shortlist, selected.reference_shortlist)
  assert_eq(
    reference_catalog(removed).references[0],
    selected.reference_shortlist[0].reference,
  )
  assert_false(
    reference_choice_current(
      removed,
      reference_catalog(removed),
      removed.reference_shortlist[0],
    ),
  )
  assert_shortlist_refused(removed)
  let cleared = reading_apply(removed, Shortlist(Clear))
  let stale = reading_apply(
    cleared,
    Shortlist(Toggle(selected.reference_shortlist[0])),
  )
  assert_eq(stale.reference_shortlist, [])
  assert_true(stale.error.unwrap().contains("changed"))
  assert_eq(reading_apply(stale, Shortlist(Clear)).error, None)
  let fresh = shortlist_pick(cleared, 0)
  assert_eq(reference_shortlist_records(fresh).length(), 1)
  let changed_source = { ..copy, origin: "Replacement capture origin", }
  let replaced = brief_edited(selected, {
    ..selected.draft,
    sources: [changed_source, copy],
  })
  assert_eq(replaced.reference_shortlist, selected.reference_shortlist)
  assert_shortlist_refused(replaced)
  // Defensive snapshot comparison also rejects a replacement outside the normal reducer.
  let bypass = {
    ..selected,
    draft: { ..selected.draft, sources: [changed_source, copy], },
  }
  assert_shortlist_refused(bypass)
  let original : BibtexSelection = @json.from_json(
    @json.parse(reference_capture_text(copy.content_hex)),
  )
  let replacement = {
    ..original,
    references: [
      {
        ..original.references[0],
        title: "Changed evidence with the same DOI and original record number",
      },
    ],
  }
  let replacement_json : Json = {
    "contract_id": replacement.contract_id,
    "source_name": replacement.source_name,
    "source_digest": replacement.source_digest,
    "references": replacement.references.to_json(),
  }
  let changed_record = {
    ..copy,
    content_hex: brief_text_hex(replacement_json.stringify()),
  }
  let replaced_record = brief_edited(selected, {
    ..selected.draft,
    sources: [changed_record, copy],
  })
  assert_shortlist_refused(replaced_record)
  let repaired = shortlist_pick(
    reading_apply(replaced_record, Shortlist(Clear)),
    0,
  )
  assert_eq(
    reference_shortlist_records(repaired)[0].title,
    "Changed evidence with the same DOI and original record number",
  )
  reading_evidence(
    "changed-source-selected.json",
    reference_shortlist_json(repaired),
  )
  reading_evidence("shortlist-source-changed.html", reading_render(removed))
}

///|
test "shortlist pending empty unreadable and failed downloads retain choices" {
  let base = shortlist_fixture()
  let pending = { ..base, pending: true, }
  for
    action in [
      Shortlist(Clear),
      Shortlist(Toggle(base.reference_shortlist[0])),
      Shortlist(ExportJson),
      Shortlist(ExportRis),
      Clear,
    ] {
    let after = reading_apply(pending, action)
    assert_eq(after.reference_shortlist, base.reference_shortlist)
    assert_eq(after.error, base.error)
  }
  assert_shortlist_refused(pending)
  let empty = reading_apply(base, Shortlist(Clear))
  for
    view in [
      empty,
      {
        ..base,
        draft: {
          ..base.draft,
          sources: base.draft.sources +
          [reading_source("ris-selection.json", "{}")],
        },
      },
    ] {
    for action in [Shortlist(ExportJson), Shortlist(ExportRis)] {
      let refused = reading_apply(view, action)
      assert_eq(refused.reference_shortlist, view.reference_shortlist)
      assert_eq(refused.draft, view.draft)
      assert_true(refused.error is Some(_))
    }
  }
  for stage in ["create", "click"] {
    shortlist_download_fixture(stage)
    defer shortlist_download_restore()
    for action in [Shortlist(ExportJson), Shortlist(ExportRis)] {
      let after = reading_apply(base, action)
      assert_eq(after.reference_shortlist, base.reference_shortlist)
      assert_eq(after.draft, base.draft)
      assert_true(after.error.unwrap().contains("download failed"))
    }
  }
}

///|
test "shortlist session lifetime New and successful reopen clear while save or failed reopen retain" {
  let base = shortlist_fixture()
  assert_eq(initial_brief_view().reference_shortlist, [])
  let fresh = update_brief_view(_ => @rabbita.none, New, {
      ..base,
      pending: true,
    }).1
  assert_eq(fresh.reference_shortlist, [])
  assert_eq(fresh.draft.sources, [])
  let opening = update_brief_view(
      _ => @rabbita.none,
      Open("other", "rev"),
      base,
    ).1
  assert_eq(opening.reference_shortlist, base.reference_shortlist)
  let failed = update_brief_view(
      _ => @rabbita.none,
      Loaded(
        opening.generation,
        "other",
        "rev",
        Ok({ "error": { "message": "unavailable" } }),
      ),
      opening,
    ).1
  assert_eq(failed.reference_shortlist, base.reference_shortlist)
  let snapshot : BriefSnapshot = {
    contract_id: "moonfind.brief-snapshot.v1",
    revision_id: "rev",
    state: "prepared",
    brief: base.draft,
    sources: [],
    boundary: "Synthetic host reply only",
  }
  let payload : Json = {
    "contract_id": "moonfind.brief-status.v1",
    "brief_id": base.draft.brief_id,
    "revision_id": "rev",
    "state": "prepared",
    "snapshot": snapshot.to_json(),
    "issues": [],
  }
  let saved = update_brief_view(
      _ => @rabbita.none,
      Loaded(base.generation, base.draft.brief_id, "", Ok(payload)),
      { ..base, pending: true, },
    ).1
  assert_eq(saved.error, None)
  assert_eq(saved.reference_shortlist, base.reference_shortlist)
  let reopened = update_brief_view(
      _ => @rabbita.none,
      Loaded(base.generation, base.draft.brief_id, "rev", Ok(payload)),
      { ..base, pending: true, },
    ).1
  assert_eq(reopened.error, None)
  assert_eq(reopened.reference_shortlist, [])
  assert_eq(reopened.draft, base.draft)
  assert_false(
    ToJson::to_json(base.draft).stringify().contains("reference_shortlist"),
  )
}

///|
test "shortlist compiled controls render counts hidden choices escaping and refusal states" {
  let base = shortlist_fixture()
  let html = reading_render(base)
  for
    text in [
      "Your reference shortlist", "3 chosen", "3 hidden by filters", "0 unavailable",
      "Temporary, session-only", "Download selected references JSON", "Download selected references RIS",
      "Download current reading list JSON", "Download current bibliography RIS",
      "Remove this choice", "Add to shortlist", "Conflicting method", "No DOI available",
      "Contact synthesis",
    ] {
    assert_true(html.contains(text), msg=text)
  }
  let all = reading_render(shortlist_pick(reading_fixture(), 0))
  assert_true(all.contains("Remove from shortlist"))
  assert_true(all.contains("&lt;script&gt;"))
  assert_false(all.contains("<script>"))
  let pending = reading_render({ ..base, pending: true, })
  assert_false(pending.contains("Download selected references JSON"))
  assert_false(pending.contains("Remove this choice"))
  assert_false(pending.contains("Add to shortlist"))
  let removed = update_brief_view(_ => @rabbita.none, RemoveSource(1), base).1
  let invalid = reading_render(removed)
  assert_true(invalid.contains("3 unavailable"))
  assert_true(invalid.contains("Unavailable: source changed or moved"))
  assert_false(invalid.contains("Download selected references RIS"))
  reading_evidence("shortlist-panel.html", html)
}

///|
// Use the real Node Blob. Only the document and URL boundary are controlled.
// Verification asynchronously reads its actual ArrayBuffer after the reducer;
// Node completes these microtasks before exit, and any mismatch fails the run.
extern "js" fn shortlist_download_fixture(failure : String) -> Unit =
  #|failure => {
  #| globalThis.__shortlistSaved={document:Object.getOwnPropertyDescriptor(globalThis,'document'),create:URL.createObjectURL,revoke:URL.revokeObjectURL};
  #| globalThis.__shortlistDownload={};
  #| URL.createObjectURL=blob=>{if(failure==='create')throw Error('create failure'); if(!(blob instanceof Blob))throw Error('not a real Blob'); globalThis.__shortlistDownload.blob=blob; return 'blob:shortlist-fixture';};
  #| URL.revokeObjectURL=()=>{};
  #| Object.defineProperty(globalThis,'document',{configurable:true,value:{body:{appendChild(){}},createElement(){return {remove(){},click(){if(failure==='click')throw Error('click failure'); globalThis.__shortlistDownload.name=this.download; globalThis.__shortlistDownload.clicked=true;}};}}});
  #|}

///|
extern "js" fn shortlist_download_restore() -> Unit =
  #|()=>{const old=globalThis.__shortlistSaved;if(old.document)Object.defineProperty(globalThis,'document',old.document);else delete globalThis.document;URL.createObjectURL=old.create;URL.revokeObjectURL=old.revoke;delete globalThis.__shortlistSaved;delete globalThis.__shortlistDownload;}

///|
extern "js" fn shortlist_download_verify(
  expected : String,
  filename : String,
  mime : String,
) -> Unit =
  #|(expected,filename,mime)=>{
  #| const item=globalThis.__shortlistDownload;
  #| if(!item.clicked||item.name!==filename||item.blob.type!==mime)throw Error('Download name, click, or MIME mismatch');
  #| item.blob.arrayBuffer().then(buffer=>{
  #|  const actual=Buffer.from(buffer),wanted=Buffer.from(expected,'utf8');
  #|  if(!actual.equals(wanted))throw Error('Actual Blob bytes mismatch');
  #|  const dir=process.env.MOONFIND_READING_EVIDENCE;
  #|  if(dir){const fs=process.getBuiltinModule('fs');fs.writeFileSync(dir+'/'+filename,actual);fs.writeFileSync(dir+'/'+filename+'.receipt.json',JSON.stringify({filename,mime,bytes:actual.length,sha256:process.getBuiltinModule('crypto').createHash('sha256').update(actual).digest('hex'),real_blob:true,exact_utf8_match:true},null,2));}
  #| }).catch(error=>{console.error(error);process.exitCode=1;});
  #|}

///|
test "shortlist actual JSON and RIS Blob bytes preserve hidden choices after failed retry" {
  let base = shortlist_fixture()
  shortlist_download_fixture("create")
  let failed = reading_apply(base, Shortlist(ExportJson))
  shortlist_download_restore()
  assert_true(failed.error is Some(_))
  shortlist_download_fixture("")
  defer shortlist_download_restore()
  let json = reading_apply(failed, Shortlist(ExportJson))
  assert_eq(json.error, None)
  assert_eq(json.reference_shortlist, base.reference_shortlist)
  shortlist_download_verify(
    reference_shortlist_json(base),
    "moonfind-selected-references.json",
    "application/json;charset=utf-8",
  )
  let ris = reading_apply(json, Shortlist(ExportRis))
  assert_eq(ris.error, None)
  assert_eq(ris.reference_shortlist, base.reference_shortlist)
  shortlist_download_verify(
    reference_shortlist_ris(base),
    "moonfind-selected-references.ris",
    "application/x-research-info-systems;charset=utf-8",
  )
}

///|
test "shortlist oversized exports refuse without losing the chosen records" {
  let base = reading_fixture()
  // Deliberately exceed normal intake bounds to test each writer's byte cap.
  let many = {
    ..base,
    draft: { ..base.draft, sources: Array::make(500, base.draft.sources[1]), },
  }
  let selected = {
    ..many,
    reference_shortlist: reference_catalog(many).references.map(r => {
      reference_choice(many, r)
    }),
  }
  assert_shortlist_refused(selected)
  for
    action in [
      ReferenceShortlistMsg::ExportJson,
      ReferenceShortlistMsg::ExportRis,
    ] {
    let after = reading_apply(selected, Shortlist(action))
    assert_eq(after.reference_shortlist, selected.reference_shortlist)
    assert_true(after.error.unwrap().contains("1 MiB"))
  }
}
