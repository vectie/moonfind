///|
// Only file/DOM boundaries are controlled. The production picker and parser
// execute, including their asynchronous file reads and single-completion guard.
extern "js" fn bookmark_test_picker(
  choose : ((String, String, String) -> String, (String) -> Unit) -> Unit,
  capture : (String, String, String) -> String,
  html : String,
) -> Unit =
  #|(choose,capture,html)=>{
  #| const previous=globalThis.document;let calls=0,fetches=0;
  #| const assert=value=>{if(!value)throw Error('Bookmark picker boundary assertion failed');};
  #| const guardedCapture=(...args)=>{const previousFetch=globalThis.fetch;globalThis.fetch=()=>{fetches++;throw Error('Bookmark intake attempted a network request');};try{return capture(...args);}finally{globalThis.fetch=previousFetch;}};
  #| const pending=[];
  #| try{
  #|  for(const mode of ['ok','cancel','empty','large','bad','read-failed','multiple','actual-large']){
  #|   let resolve;pending.push(new Promise(r=>resolve=r));
  #|   const listeners={},file={name:mode==='bad'?'bad.json':'selected.html',size:mode==='large'?32769:new TextEncoder().encode(html).length,arrayBuffer:async()=>{if(mode==='read-failed')throw Error('disk read failed');return new TextEncoder().encode(mode==='actual-large'?'x'.repeat(32769):html).buffer;}};
  #|   globalThis.document={createElement(tag){assert(tag==='input');return {addEventListener(event,fn){listeners[event]=fn;},files:mode==='empty'?[]:mode==='multiple'?[file,file]:[file],click(){assert(this.accept==='.html,.htm'&&this.multiple===false);if(mode==='cancel'){listeners.cancel();listeners.cancel();}else listeners.change();}};}};
  #|   let count=0;choose(guardedCapture,result=>{try{count++;calls++;assert(count===1);const parsed=JSON.parse(result);if(mode==='ok'){assert(parsed.sources.length===2);assert(Buffer.from(parsed.sources[0].content_hex,'hex').toString('utf8')===html);assert(JSON.parse(Buffer.from(parsed.sources[1].content_hex,'hex').toString('utf8')).bookmarks.length===4);}else if(mode==='cancel'||mode==='empty')assert(parsed.sources.length===0);else assert(typeof parsed.error==='string');resolve();}catch(error){console.error(error);process.exitCode=1;resolve();}});
  #|  }
  #| }finally{globalThis.document=previous;}
  #| Promise.all(pending).then(()=>{assert(calls===8&&fetches===0);}).catch(error=>{console.error(error);process.exitCode=1;});
  #|}

///|
test "bookmarks actual picker reads cancels bounds and rejects failures without any URL request" {
  bookmark_test_picker(
    bookmark_source_choose,
    bookmark_source_capture,
    bookmark_test_html(),
  )
}

///|
extern "js" fn bookmark_test_artifact_write(
  name : String,
  content : String,
) -> Unit =
  #|(name,content)=>{const dir=process.env.MOONFIND_BOOKMARK_EVIDENCE;if(dir)process.getBuiltinModule('fs').writeFileSync(dir+'/'+name,content);}

///|
extern "js" fn bookmark_test_blob_verify(
  expected : String,
  name : String,
) -> String =
  #|(expected,name)=>{
  #| const got=globalThis.__numericDownload;
  #| if(!got.clicked||got.name!==name||!(got.blob instanceof Blob))return 'Bookmark output download metadata mismatch';
  #| got.blob.text().then(text=>{
  #|  if(text!==expected)throw Error('Bookmark output Blob bytes changed');
  #|  const dir=process.env.MOONFIND_BOOKMARK_EVIDENCE;if(dir){const fs=process.getBuiltinModule('fs');fs.writeFileSync(dir+'/'+name,text);const reopened=fs.readFileSync(dir+'/'+name,'utf8');if(reopened!==expected)throw Error('Bookmark output disk readback changed');fs.writeFileSync(dir+'/'+name+'.receipt.json',JSON.stringify({filename:name,mime:got.blob.type,bytes:got.blob.size,sha256:process.getBuiltinModule('crypto').createHash('sha256').update(reopened).digest('hex'),real_blob:true,readback_equal:true},null,2));}
  #| }).catch(error=>{console.error(error);process.exitCode=1;});return '';
  #|}

///|
test "bookmarks real Blob selected JSON and CSV files reopen exactly and failed downloads keep the queue" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let imported = bookmark_test_model()
  let searched = update(
      _ => @rabbita.none,
      BriefAction(JsonEvidence(Search("clinic"))),
      imported,
    ).1
  let model = update(
      _ => @rabbita.none,
      BriefAction(JsonEvidence(SelectMatching)),
      searched,
    ).1
  assert_eq(model.brief.json_evidence.selected, [1, 2])
  bookmark_test_artifact_write(
    "research-bookmarks.html.txt",
    bookmark_test_html(),
  )
  bookmark_test_artifact_write(
    "research-bookmarks.json",
    brief_source_preview(model.brief.draft.sources[1].content_hex),
  )
  bookmark_test_artifact_write("bookmark-explorer.html", qa_test_render(model))
  for action in [JsonEvidenceMsg::Download, JsonEvidenceMsg::DownloadCsv] {
    for mode in ["create", "click", "ok"] {
      csv_numeric_blob_fixture(mode)
      let result = update(
          _ => @rabbita.none,
          BriefAction(JsonEvidence(action)),
          model,
        ).1
      assert_eq(result.brief.draft, model.brief.draft)
      assert_eq(result.brief.json_evidence, model.brief.json_evidence)
      if mode == "ok" {
        assert_eq(result.brief.error, None)
        assert_eq(
          bookmark_test_blob_verify(
            if action is Download {
              json_evidence_export(model.brief)
            } else {
              json_evidence_csv(model.brief).text
            },
            if action is Download {
              "moonfind-json-evidence-extract.json"
            } else {
              "moonfind-selected-fields.csv"
            },
          ),
          "",
        )
      } else {
        assert_true(result.brief.error.unwrap().contains("download failed"))
      }
      csv_numeric_blob_restore()
    }
  }
}

///|
test "bookmarks empty queue is explicit and expansion limits leave original dossier unchanged" {
  let empty = "<!DOCTYPE NETSCAPE-Bookmark-file-1><DL><p></DL><p>"
  let sources = bookmark_test_sources(html=empty)
  assert_eq(json_evidence_table(sources[1], "/bookmarks").rows.length(), 0)
  let many = StringBuilder()
  many.write_string("<!DOCTYPE NETSCAPE-Bookmark-file-1><DL>")
  for _ in 0..<120 {
    many.write_string("<DT><A HREF='x'>x</A>")
  }
  many.write_string("</DL>")
  let raw = bookmark_test_raw(html=many.to_string())
  assert_true(
    @json.parse(raw) is { "error": String(message), .. } &&
    message.contains("Structured bookmark capture exceeds 32 KiB"),
  )
  let view = initial_brief_view()
  let result = reduce_brief_view(
      _ => @rabbita.none,
      BookmarksLoaded(view.generation, raw),
      view,
    ).1
  assert_eq(result.draft, view.draft)
  assert_eq(result.json_evidence, view.json_evidence)
}
