///|
fn json_lines_table(source : BriefInputSource) -> JsonEvidenceTable raise {
  match
    @json.parse(json_evidence_parse_mode(source.content_hex, "", true, "")) {
    { "error": String(message), .. } => fail(message)
    { "table": table, .. } => @json.from_json(table)
    _ => fail("JSONL evidence could not be read.")
  }
}

///|
extern "js" fn json_lines_choose(done : (String) -> Unit) -> Unit =
  #|done=>{
  #| try {
  #| const input=document.createElement('input');input.type='file';input.accept='.jsonl,.ndjson,.txt';input.multiple=false;
  #| input.addEventListener('cancel',()=>done(JSON.stringify({cancelled:true})),{once:true});
  #| input.addEventListener('change',async()=>{
  #|  try{
  #|   const files=Array.from(input.files||[]);if(!files.length){done(JSON.stringify({cancelled:true}));return;}
  #|   if(files.length!==1)throw Error('Choose one JSONL evidence file.');
  #|   const file=files[0];if(!/\.(jsonl|ndjson|txt)$/i.test(file.name)||file.size>32768)throw Error('Choose one UTF-8 .jsonl, .ndjson or .txt JSONL up to 32 KiB.');
  #|   const name=/\.(jsonl|ndjson)$/i.test(file.name)?file.name+'.txt':file.name;
  #|   if(name.length>160||/[\\/\u0000-\u001f\u007f]/.test(name))throw Error('Use a safe JSONL filename whose retained .txt name is at most 160 characters.');
  #|   const bytes=new Uint8Array(await file.arrayBuffer());if(bytes.length>32768)throw Error('JSONL bytes exceed 32 KiB.');
  #|   const text=new TextDecoder('utf-8',{fatal:true,ignoreBOM:true}).decode(bytes);
  #|   if(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(text))throw Error('Binary control bytes are unsupported.');
  #|   done(JSON.stringify({source:{name,origin:'User-selected JSONL evidence file: '+file.name+'; exact original bytes retained as '+name,captured_at:new Date().toISOString(),kind:'local-file',content_hex:Array.from(bytes,b=>b.toString(16).padStart(2,'0')).join('')}}));
  #|  }catch(error){done(JSON.stringify({error:String(error)}));}
  #| },{once:true});input.click();
  #| }catch(error){done(JSON.stringify({error:String(error)}));}
  #|}
