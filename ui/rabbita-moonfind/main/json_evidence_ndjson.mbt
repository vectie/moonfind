///|
// Strip JSON structural whitespace without parsing/re-serializing its values.
// The table comes from the lossless explorer; its raw records keep number and
// escape spellings. The array transport contains those records as strings.
extern "js" fn json_evidence_ndjson_text(
  table_json : String,
  selected_json : String,
) -> String =
  #|(table_json,selected_json) => {
  #| try {
  #|   const table=JSON.parse(table_json), selected=JSON.parse(selected_json);
  #|   if(!table || !['json-array','json-object','jsonl'].includes(table.format) || !Array.isArray(table.rows) || table.rows.length>512)throw Error('Explore a current JSON or JSONL table before exporting NDJSON.');
  #|   if(!Array.isArray(selected) || !selected.length || selected.length>512 || selected.some(n=>!Number.isInteger(n)||n<1||n>table.rows.length))throw Error('Select at least one current JSON record before exporting NDJSON.');
  #|   const chosen=new Set(selected), lines=[];
  #|   let bytes=0;
  #|   for(const [index,row] of table.rows.entries()){
  #|     if(!row || row.record_number!==index+1 || typeof row.raw!=='string')throw Error('JSON record identity changed. Explore the source again.');
  #|     if(!chosen.has(row.record_number))continue;
  #|     bytes+=new TextEncoder().encode(row.raw).length;
  #|     if(bytes>32768)throw Error('Selected source records exceed the 32 KiB evidence limit.');
  #|     const value=JSON.parse(row.raw);
  #|     if(!value || Array.isArray(value) || typeof value!=='object')throw Error('Each NDJSON record must be a JSON object.');
  #|     let line='', quoted=false, escaped=false;
  #|     for(const ch of row.raw){
  #|       if(quoted){
  #|         line+=ch;
  #|         if(escaped)escaped=false;
  #|         else if(ch==='\\')escaped=true;
  #|         else if(ch==='"')quoted=false;
  #|       }else if(ch==='"'){quoted=true;line+=ch;}
  #|       else if(!/[ \t\r\n]/.test(ch))line+=ch;
  #|     }
  #|     lines.push(line);
  #|   }
  #|   return JSON.stringify({text:lines.join('\n')+'\n',record_count:lines.length});
  #| }catch(error){return JSON.stringify({error:String(error)});}
  #|}

///|
fn json_evidence_ndjson(view : BriefView) -> String raise {
  // Reuse the existing current-source guard. No saved digest or provenance is
  // copied into this raw-record output; the original dossier remains canonical.
  ignore(json_evidence_export(view))
  let state = view.json_evidence
  let table = state.table.unwrap()
  match
    @json.parse(
      json_evidence_ndjson_text(
        table.to_json().stringify(),
        state.selected.to_json().stringify(),
      ),
    ) {
    { "text": String(text), .. } => text
    { "error": String(message), .. } => fail(message)
    _ => fail("NDJSON evidence could not be exported.")
  }
}

///|
extern "js" fn json_evidence_ndjson_download(content : String) -> String =
  #|content => {
  #| let url,link;
  #| try {
  #|   url=URL.createObjectURL(new Blob([content],{type:'application/x-ndjson;charset=utf-8'}));
  #|   link=document.createElement('a');link.href=url;link.download='moonfind-selected-records.ndjson';
  #|   document.body.appendChild(link);link.click();return '';
  #| }catch(_){return 'NDJSON download failed; your source and selections remain available. Try again.';}
  #| finally {if(link){try{link.remove();}catch(_){}}if(url)setTimeout(()=>URL.revokeObjectURL(url),1000);}
  #|}
