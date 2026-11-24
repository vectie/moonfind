///|
fn atom_test_xml() -> String {
  let xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:extra="urn:extra">
    #|<id>urn:feed:demo</id><title>Local research</title><updated>2026-10-20T08:00:00+08:00</updated><author><name>Feed editor</name></author>
    #|<entry><id>urn:duplicate</id><title>Clinic &amp; field 🌒</title><updated>2026-10-19T22:00:00Z</updated><author><name>Ada</name><uri>../ada</uri></author><link href="https://example.invalid/?a=1&amp;b=2"/><link rel="enclosure" href="../audio" length="9007199254740993"/><category term="clinic" label="Field"/><summary type="html">&lt;img src="https://example.invalid/private"&gt; Clinic summary</summary><content type="text">Original content</content><extra:note>Preserved</extra:note></entry>
    #|<entry><id>urn:duplicate</id><title>Clinic follow-up</title><summary/></entry>
    #|<entry><title>School interview</title></entry>
    #|</feed>
  xml
}

///|
fn atom_test_raw(xml~ : String = atom_test_xml()) -> String {
  atom_source_capture(
    "research.atom",
    brief_text_hex(xml),
    "2026-10-20T03:00:00Z",
  )
}

///|
fn atom_test_model() -> Model {
  let model = initial_model()
  update(
    _ => @rabbita.none,
    BriefAction(AtomLoaded(model.brief.generation, atom_test_raw())),
    model,
  ).1
}

///|
extern "js" fn atom_test_picker(
  choose : ((String, String, String) -> String, (String) -> Unit) -> Unit,
  capture : (String, String, String) -> String,
  xml : String,
) -> Unit =
  #|(choose,capture,xml)=>{
  #| const previous=globalThis.document;const pending=[];let calls=0;
  #| const assert=x=>{if(!x)throw Error('Atom picker assertion failed');};
  #| try{for(const cancel of [false,true]){
  #|  let resolve;pending.push(new Promise(r=>resolve=r));const listeners={};
  #|  globalThis.document={createElement(){return {files:[{name:'saved.atom',size:new TextEncoder().encode(xml).length,arrayBuffer:async()=>new TextEncoder().encode(xml).buffer}],addEventListener(e,f){listeners[e]=f;},click(){assert(this.accept==='.atom,.xml'&&!this.multiple);if(cancel){listeners.cancel();listeners.cancel();}else listeners.change();}};}};
  #|  let count=0;choose(capture,raw=>{try{assert(++count===1);calls++;const result=JSON.parse(raw);assert(result.sources.length===(cancel?0:2));if(!cancel)assert(Buffer.from(result.sources[0].content_hex,'hex').toString('utf8')===xml);}catch(e){console.error(e);process.exitCode=1;}resolve();});
  #| }}finally{globalThis.document=previous;}
  #| Promise.all(pending).then(()=>assert(calls===2)).catch(e=>{console.error(e);process.exitCode=1;});
  #|}

///|
test "Atom actual file picker reads saved feed and cancellation completes once" {
  atom_test_picker(atom_source_choose, atom_source_capture, atom_test_xml())
}

///|
test "Atom retains original bytes and projects supplied entries links authors and inert HTML" {
  let model = atom_test_model()
  assert_eq(model.brief.error, None)
  let sources = model.brief.draft.sources
  assert_eq(sources.length(), 2)
  assert_eq(sources[0].content_hex, brief_text_hex(atom_test_xml()))
  let json = @json.parse(brief_source_preview(sources[1].content_hex))
  guard json is { "items": Array(items), "feed": feed, .. } else {
    fail("No Atom items")
  }
  assert_eq(items.length(), 3)
  assert_true(
    feed is { "authors": Array([{ "name": String("Feed editor"), .. }]), .. },
  )
  assert_true(
    items[0]
    is {
      "title": String("Clinic & field 🌒"),
      "authors": Array([{ "name": String("Ada"), "uri": String("../ada"), .. }]),
      "summary_type": String("html"),
      ..
    },
  )
  assert_true(
    items[0]
    is {
      "unprojected_elements": Array([String("content"), String("extra:note")]),
      ..
    },
  )
  assert_true(
    items[1]
    is {
      "id": String("urn:duplicate"),
      "authors": Array([]),
      "updated": Null,
      "summary": String(""),
      ..
    },
  )
  let html = qa_test_render(model)
  assert_true(html.contains("Import saved Atom feed"))
  assert_true(html.contains("&lt;img"))
  assert_false(html.contains("<img src=\"https://example.invalid/private"))
}

///|
test "Atom namespace prefixes and empty feeds import without rewriting supplied dates" {
  let raw = atom_test_raw(
    xml="<a:feed xmlns:a=\"http://www.w3.org/2005/Atom\"><a:title>Prefixed</a:title><a:entry><a:title>A</a:title><a:updated>supplied date</a:updated></a:entry></a:feed>",
  )
  let view = atom_source_loaded(initial_model().brief, raw)
  assert_eq(view.json_evidence.table.unwrap().rows.length(), 1)
  assert_true(
    brief_source_preview(view.draft.sources[1].content_hex).contains(
      "supplied date",
    ),
  )
  let empty = atom_source_loaded(
    initial_model().brief,
    atom_test_raw(xml="<feed xmlns=\"http://www.w3.org/2005/Atom\"/>"),
  )
  assert_eq(empty.json_evidence.table.unwrap().rows.length(), 0)
}

///|
test "Atom import opens explorer search selection CSV and brief draft restore" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = atom_test_model()
  assert_eq(model.brief.json_evidence.pointer, "/items")
  let searched = update(
      _ => @rabbita.none,
      BriefAction(JsonEvidence(Search("clinic"))),
      model,
    ).1
  let selected = update(
      _ => @rabbita.none,
      BriefAction(JsonEvidence(SelectMatching)),
      searched,
    ).1
  assert_eq(selected.brief.json_evidence.selected, [1, 2])
  let csv = json_evidence_csv(selected.brief)
  assert_eq(csv.record_count, 2)
  assert_true(csv.text.contains("Clinic & field 🌒"))
  assert_true(csv.text.contains("Ada"))
  assert_false(csv.text.contains("School interview"))
  let added = update(
      _ => @rabbita.none,
      BriefAction(JsonEvidence(Add)),
      selected,
    ).1
  assert_eq(added.brief.error, None)
  assert_eq(added.brief.draft.sources.length(), 3)
  assert_eq(added.brief.draft.sources[0], model.brief.draft.sources[0])
  assert_eq(initial_model().brief.draft.sources, added.brief.draft.sources)
}

///|
test "Atom cancelled stale and unsupported captures leave the brief sources unchanged" {
  let model = atom_test_model()
  let choosing = update(_ => @rabbita.none, BriefAction(ChooseAtom), model).1
  let stale = update(
      _ => @rabbita.none,
      BriefAction(AtomLoaded(model.brief.generation, atom_test_raw())),
      choosing,
    ).1
  assert_eq(stale.brief.draft, model.brief.draft)
  let cancelled = update(
      _ => @rabbita.none,
      BriefAction(AtomLoaded(choosing.brief.generation, "{\"sources\":[]}")),
      choosing,
    ).1
  assert_eq(cancelled.brief.draft, model.brief.draft)
  for
    xml in [
      "<rss version=\"2.0\"/>", "<feed/>", "<feed xmlns=\"http://www.w3.org/2005/Atom\"><title type=\"xhtml\"><div/></title></feed>",
    ] {
    let failed = update(
        _ => @rabbita.none,
        BriefAction(AtomLoaded(choosing.brief.generation, atom_test_raw(xml~))),
        choosing,
      ).1
    assert_true(failed.brief.error is Some(_))
    assert_eq(failed.brief.draft, model.brief.draft)
  }
}

///|
test "Atom saved brief reply reopens both imported sources" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let model = atom_test_model()
  let saving = update(_ => @rabbita.none, BriefAction(Save), model).1
  let revision = "revision-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  let reply = brief_fixture_reply(model.brief.draft, revision)
  let saved = update(
      _ => @rabbita.none,
      BriefAction(
        Loaded(
          saving.brief.generation,
          model.brief.draft.brief_id,
          "",
          Ok(reply),
        ),
      ),
      saving,
    ).1
  assert_eq(saved.brief.error, None)
  let opening = update(
      _ => @rabbita.none,
      BriefAction(Open(model.brief.draft.brief_id, revision)),
      saved,
    ).1
  let reopened = update(
      _ => @rabbita.none,
      BriefAction(
        Loaded(
          opening.brief.generation,
          model.brief.draft.brief_id,
          revision,
          Ok(reply),
        ),
      ),
      opening,
    ).1
  assert_eq(reopened.brief.error, None)
  assert_eq(reopened.brief.draft.sources, model.brief.draft.sources)
}
