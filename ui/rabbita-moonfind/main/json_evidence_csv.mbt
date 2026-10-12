///|
struct JsonEvidenceCsv {
  text : String
  record_count : Int
  field_count : Int
  escaped_cells : Int
} derive(Debug, Eq, FromJson)

///|
// JSON syntax permits literal whitespace and newlines in member names without
// conflating them with list delimiters. The shared lens validates each pointer.
extern "js" fn json_evidence_csv_fields_text(input : String) -> String =
  #|input => {
  #| try {
  #|   if(typeof input!=='string'||input.length>49152)throw Error('Choose one to eight field pointers.');
  #|   const fields=JSON.parse(input);
  #|   if(!Array.isArray(fields)||fields.length<1||fields.length>8||fields.some(field=>typeof field!=='string'||!field.startsWith('/')||field.length>1024||/~(?![01])/.test(field)))throw Error('Use a JSON array of one to eight nonempty JSON Pointers, each up to 1,024 UTF-16 units.');
  #|   if(new Set(fields).size!==fields.length)throw Error('Choose each field pointer once.');
  #|   return JSON.stringify({fields});
  #| }catch(error){return JSON.stringify({error:String(error)});}
  #|}

///|
// Consume the existing lossless per-field projections. Source numbers remain
// strings throughout; this is CSV serialization, never numeric calculation.
extern "js" fn json_evidence_csv_text(
  responses_json : String,
  selected_json : String,
) -> String =
  #|(responses_json,selected_json) => {
  #| try {
  #|   const responses=JSON.parse(responses_json).map(value=>JSON.parse(value));
  #|   if(responses.length<1||responses.length>8)throw Error('Choose one to eight field pointers.');
  #|   for(const response of responses){
  #|     if(response.error)throw Error(response.error);
  #|     if(!response.table||!response.lens||!response.lens.pointer)throw Error('Explore current fields before exporting CSV.');
  #|   }
  #|   const table=responses[0].table, fields=responses.map(response=>response.lens.pointer);
  #|   if(!['json-array','jsonl'].includes(table.format)||!Array.isArray(table.rows)||table.rows.length>512)throw Error('Explore a current JSON or JSONL source.');
  #|   if(new Set(fields).size!==fields.length)throw Error('Choose each field pointer once.');
  #|   for(const response of responses){
  #|     if(JSON.stringify(response.table)!==JSON.stringify(table)||response.lens.rows.length!==table.rows.length)throw Error('Every CSV field must inspect the same current source records.');
  #|   }
  #|   const selected=JSON.parse(selected_json);
  #|   if(!Array.isArray(selected)||!selected.length||selected.length>512||selected.some(number=>!Number.isInteger(number)||number<1||number>table.rows.length))throw Error('Select at least one current JSON record before exporting CSV.');
  #|   const chosen=new Set(selected), rows=[['source_record','source_line','source_pointer',...fields.flatMap(field=>[field+' value',field+' kind',field+' encoding'])]];
  #|   let escaped_cells=0;
  #|   for(const [index,record] of table.rows.entries()){
  #|     if(record.record_number!==index+1)throw Error('Source record identity changed. Explore again.');
  #|     const values=responses.map(response=>response.lens.rows[index]);
  #|     for(const value of values){
  #|       if(value.record_number!==record.record_number||value.source_line!==record.source_line||value.record_pointer!==record.pointer)throw Error('Source record identity changed. Explore again.');
  #|     }
  #|     if(!chosen.has(record.record_number))continue;
  #|     const cells=[String(record.record_number),table.format==='jsonl'?String(record.source_line):'',table.format==='json-array'?record.pointer:''];
  #|     for(const value of values){
  #|       if(!['missing','blocked','null','empty-string','string','number','boolean','array','object'].includes(value.kind)||typeof value.text!=='string'||typeof value.raw!=='string')throw Error('Unsupported source field value.');
  #|       let text=value.kind==='missing'||value.kind==='blocked'?'':value.kind==='string'||value.kind==='empty-string'?value.text:value.raw;
  #|       // Quote CSV normally AND mark a reversible prefix for formula-like
  #|       // text, leading apostrophes, or leading controls. Quoting alone does
  #|       // not stop a spreadsheet from interpreting formulas.
  #|       const escaped=/^[\u0000-\u0020\u007f-\u009f]*[=+\-@']/.test(text)||/^[\u0000-\u001f\u007f-\u009f]/.test(text);
  #|       if(escaped){text="'"+text;escaped_cells++;}
  #|       cells.push(text,value.kind,escaped?'apostrophe-prefix':'literal');
  #|     }
  #|     rows.push(cells);
  #|   }
  #|   const text=rows.map(row=>row.map(cell=>'"'+cell.replace(/"/g,'""')+'"').join(',')).join('\r\n')+'\r\n';
  #|   if(new TextEncoder().encode(text).length>1048576)throw Error('Projected CSV exceeds 1 MiB. Choose fewer fields or records.');
  #|   return JSON.stringify({csv:{text,record_count:rows.length-1,field_count:fields.length,escaped_cells}});
  #| }catch(error){return JSON.stringify({error:String(error)});}
  #|}

///|
fn json_evidence_csv(view : BriefView) -> JsonEvidenceCsv raise {
  // The existing exporter checks source-slot identity. CSV carries locators,
  // but never copies a digest or pretends to be a complete source snapshot.
  ignore(json_evidence_export(view))
  let state = view.json_evidence
  let fields : Array[String] = match
    @json.parse(json_evidence_csv_fields_text(state.csv_fields)) {
    { "fields": fields, .. } => @json.from_json(fields)
    { "error": String(message), .. } => fail(message)
    _ => fail("Choose CSV field pointers.")
  }
  let source = state.source.unwrap()
  let table = state.table.unwrap()
  let responses = fields.map(pointer => {
    json_evidence_parse_mode(
      source.content_hex,
      state.pointer,
      table.format == "jsonl",
      pointer,
    )
  })
  match
    @json.parse(
      json_evidence_csv_text(
        responses.to_json().stringify(),
        state.selected.to_json().stringify(),
      ),
    ) {
    { "csv": csv, .. } => @json.from_json(csv)
    { "error": String(message), .. } => fail(message)
    _ => fail("Projected CSV evidence could not be exported.")
  }
}

///|
extern "js" fn json_evidence_csv_download(content : String) -> String =
  #|content => {
  #| let url,link;
  #| try {
  #|   url=URL.createObjectURL(new Blob([content],{type:'text/csv;charset=utf-8'}));
  #|   link=document.createElement('a');link.href=url;link.download='moonfind-selected-fields.csv';
  #|   document.body.appendChild(link);link.click();return '';
  #| }catch(_){return 'CSV download failed; your source, field pointers and selections remain available. Try again.';}
  #| finally {if(link){try{link.remove();}catch(_){}}if(url)setTimeout(()=>URL.revokeObjectURL(url),1000);}
  #|}
