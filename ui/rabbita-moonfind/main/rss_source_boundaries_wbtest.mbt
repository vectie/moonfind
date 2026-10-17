///|
// Only the OS/browser boundary is replaced. The actual production picker and
// decoder run. Promise assertions report failures to the Node test process.
extern "js" fn rss_test_picker(
  choose : ((String, String, String) -> String, (String) -> Unit) -> Unit,
  capture : (String, String, String) -> String,
  xml : String,
) -> Unit =
  #|(choose,capture,xml)=>{
  #| const previous=globalThis.document;let calls=0,fetches=0;
  #| const assert=value=>{if(!value)throw Error('RSS picker boundary assertion failed');};
  #| const guardedCapture=(...args)=>{const previousFetch=globalThis.fetch;globalThis.fetch=()=>{fetches++;throw Error('RSS intake attempted a network request');};try{return capture(...args);}finally{globalThis.fetch=previousFetch;}};
  #| const pending=[];
  #| try{
  #|  for(const mode of ['ok','cancel','empty','large','bad','read-failed']){
  #|   let resolve;pending.push(new Promise(r=>resolve=r));
  #|   const listeners={},file={name:mode==='bad'?'bad.atom':'selected.rss',size:mode==='large'?32769:new TextEncoder().encode(xml).length,arrayBuffer:async()=>{if(mode==='read-failed')throw Error('disk read failed');return new TextEncoder().encode(xml).buffer;}};
  #|   globalThis.document={createElement(tag){assert(tag==='input');return {addEventListener(event,fn){listeners[event]=fn;},files:mode==='empty'?[]:[file],click(){assert(this.accept==='.rss,.xml'&&this.multiple===false);if(mode==='cancel'){listeners.cancel();listeners.cancel();}else listeners.change();}};}};
  #|   let count=0;choose(guardedCapture,result=>{try{count++;calls++;assert(count===1);const parsed=JSON.parse(result);if(mode==='ok'){assert(parsed.sources.length===2);assert(Buffer.from(parsed.sources[0].content_hex,'hex').toString('utf8')===xml);assert(JSON.parse(Buffer.from(parsed.sources[1].content_hex,'hex').toString('utf8')).items.length===3);}else if(mode==='cancel'||mode==='empty')assert(parsed.sources.length===0);else assert(typeof parsed.error==='string');resolve();}catch(error){console.error(error);process.exitCode=1;resolve();}});
  #|  }
  #| }finally{globalThis.document=previous;}
  #| Promise.all(pending).then(()=>{assert(calls===6&&fetches===0);}).catch(error=>{console.error(error);process.exitCode=1;});
  #|}

///|
test "RSS actual picker handles complete read cancellation duplicates wrong type size and disk failure without fetching" {
  rss_test_picker(rss_source_choose, rss_source_capture, rss_test_xml())
}

///|
extern "js" fn rss_test_artifact_write(name : String, content : String) -> Unit =
  #|(name,content)=>{const dir=process.env.MOONFIND_RSS_EVIDENCE;if(dir)process.getBuiltinModule('fs').writeFileSync(dir+'/'+name,content);}

///|
extern "js" fn rss_test_blob_verify(expected : String, name : String) -> String =
  #|(expected,name)=>{
  #| const got=globalThis.__numericDownload;
  #| if(!got.clicked||got.name!==name||!(got.blob instanceof Blob))return 'RSS output download metadata mismatch';
  #| got.blob.text().then(text=>{
  #|  if(text!==expected)throw Error('RSS output Blob bytes changed');
  #|  const dir=process.env.MOONFIND_RSS_EVIDENCE;if(dir){const fs=process.getBuiltinModule('fs');fs.writeFileSync(dir+'/'+name,text);const reopened=fs.readFileSync(dir+'/'+name,'utf8');if(reopened!==expected)throw Error('RSS output disk readback changed');fs.writeFileSync(dir+'/'+name+'.receipt.json',JSON.stringify({filename:name,mime:got.blob.type,bytes:got.blob.size,sha256:process.getBuiltinModule('crypto').createHash('sha256').update(reopened).digest('hex'),real_blob:true,readback_equal:true},null,2));}
  #| }).catch(error=>{console.error(error);process.exitCode=1;});return '';
  #|}

///|
test "RSS real Blob selected JSON and CSV downloads fail repairably and reopen with exact bytes" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let imported = rss_test_model()
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
  rss_test_artifact_write("rss-original.xml", rss_test_xml())
  rss_test_artifact_write(
    "rss-items.json",
    brief_source_preview(model.brief.draft.sources[1].content_hex),
  )
  rss_test_artifact_write("rss-explorer.html", qa_test_render(model))
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
          rss_test_blob_verify(
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
