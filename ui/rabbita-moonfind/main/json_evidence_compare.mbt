///|
struct JsonEvidenceComparison {
  text : String
  added : Int
  removed : Int
  changed : Int
  unchanged_fields : Int
} derive(Debug, Eq, FromJson)

///|
// Join two independently parsed captures by an explicit unique typed key.
// Selected field kinds and original tokens are compared without numeric coercion.
extern "js" fn json_evidence_compare_text(
  before_json : String,
  after_json : String,
  metadata_json : String,
) -> String =
  #|(before_json,after_json,metadata_json) => {
  #| try {
  #|   const metadata=JSON.parse(metadata_json);
  #|   const parse=(input,label)=>{
  #|     const projections=JSON.parse(input).map(text=>JSON.parse(text));
  #|     if(projections.length<2||projections.length>9)throw Error('Choose a key and one to eight comparison fields.');
  #|     for(const projection of projections){
  #|       if(projection.error)throw Error(label+': '+projection.error);
  #|       if(!projection.table||!projection.lens||!projection.lens.pointer)throw Error('Enter a nonempty record key pointer and comparison field pointers.');
  #|     }
  #|     const table=projections[0].table,pointers=projections.map(p=>p.lens.pointer);
  #|     if(!['json-array','json-object','jsonl'].includes(table.format)||table.rows.length>512)throw Error('Explore bounded JSON or JSONL records.');
  #|     if(new Set(pointers.slice(1)).size!==pointers.length-1)throw Error('Choose each comparison field once.');
  #|     for(const projection of projections){
  #|       if(JSON.stringify(projection.table)!==JSON.stringify(table)||projection.lens.rows.length!==table.rows.length)throw Error(label+': all fields must inspect the same current source.');
  #|     }
  #|     const records=[],byKey=new Map();
  #|     table.rows.forEach((row,index)=>{
  #|       if(row.record_number!==index+1)throw Error(label+': source record identity changed.');
  #|       const values=projections.map(p=>p.lens.rows[index]);
  #|       for(const value of values){
  #|         if(value.record_number!==row.record_number||value.source_line!==row.source_line||value.record_pointer!==row.pointer)throw Error(label+': source locator changed.');
  #|         if(!['missing','blocked','null','empty-string','string','number','boolean','array','object'].includes(value.kind)||typeof value.raw!=='string'||typeof value.text!=='string')throw Error('Unsupported source field value.');
  #|       }
  #|       const key=values[0];
  #|       if(!['string','number','boolean'].includes(key.kind))throw Error(label+' record '+row.record_number+': key is '+key.kind+'. Choose a present nonempty string, number or boolean key in every record.');
  #|       const identity=JSON.stringify([key.kind,key.kind==='string'?key.text:key.raw]);
  #|       if(byKey.has(identity))throw Error(label+' records '+byKey.get(identity).source_record+' and '+row.record_number+': duplicate '+key.kind+' key '+(key.kind==='string'?JSON.stringify(key.text):key.raw)+'. Choose a unique key; no records were paired.');
  #|       const record={source_record:row.record_number,source_line:table.format==='jsonl'?row.source_line:null,source_pointer:table.format!=='jsonl'?row.pointer:null,
  #|         key:{kind:key.kind,text:key.text,raw:key.raw},fields:values.slice(1).map((value,i)=>({pointer:pointers[i+1],source_value_pointer:table.format!=='jsonl'?value.value_pointer:null,kind:value.kind,text:value.text,raw:value.raw}))};
  #|       byKey.set(identity,record);records.push({identity,record});
  #|     });
  #|     return {pointers,format:table.format,records,byKey};
  #|   };
  #|   const before=parse(before_json,'Before'),after=parse(after_json,'After');
  #|   if(JSON.stringify(before.pointers)!==JSON.stringify(after.pointers))throw Error('Both sources must use the same record key and ordered field pointers.');
  #|   const sources={};
  #|   for(const [side,parsed] of [['before',before],['after',after]]){
  #|     const supplied=metadata[side];
  #|     if(!supplied||!Number.isInteger(supplied.slot)||supplied.slot<1||supplied.slot>8||['name','origin','captured_at','kind','array_pointer'].some(key=>typeof supplied[key]!=='string'))throw Error('Current source descriptors are required.');
  #|     sources[side]={slot:supplied.slot,name:supplied.name,origin:supplied.origin,captured_at:supplied.captured_at,kind:supplied.kind,format:parsed.format,array_pointer:parsed.format==='jsonl'?null:supplied.array_pointer,record_count:parsed.records.length};
  #|   }
  #|   if(sources.before.slot===sources.after.slot)throw Error('Choose two different loaded source slots.');
  #|   const counts={added:0,removed:0,changed:0,unchanged_fields:0},records=[];
  #|   for(const {identity,record:left} of before.records){
  #|     const right=after.byKey.get(identity)||null;
  #|     const changed_fields=right?left.fields.filter((value,i)=>value.kind!==right.fields[i].kind||value.raw!==right.fields[i].raw).map(value=>value.pointer):[];
  #|     const status=!right?'removed':changed_fields.length?'changed':'unchanged_fields';
  #|     counts[status]++;records.push({status,changed_fields,before:left,after:right});
  #|   }
  #|   for(const {identity,record:right} of after.records){
  #|     if(!before.byKey.has(identity)){counts.added++;records.push({status:'added',changed_fields:[],before:null,after:right});}
  #|   }
  #|   const report={contract_id:'moonfind.json-snapshot-comparison.v1',brief_id:metadata.brief_id,
  #|     key_pointer:before.pointers[0],field_pointers:before.pointers.slice(1),
  #|     key_matching:'Typed keys: decoded exact strings; original number tokens; boolean tokens. No coercion, case folding or Unicode normalization.',
  #|     field_comparison:'Selected field kind and exact source token. Whitespace, member order or escape changes inside a selected token count. Unselected fields are not compared.',
  #|     sources,counts,records,
  #|     boundary:'Reading artifact only. Source descriptors are supplied capture metadata, not authenticated provenance or a newly verified digest. No source body, host manifest or saved brief revision is included. Chosen containers include all descendants. No truth, freshness or source-rights approval is implied.'};
  #|   const text=JSON.stringify(report,null,2)+'\n';
  #|   if(new TextEncoder().encode(text).length>1048576)throw Error('Comparison exceeds 1 MiB. Choose fewer fields or smaller captures. Nothing was truncated.');
  #|   return JSON.stringify({comparison:{text,...counts}});
  #| }catch(error){return JSON.stringify({error:String(error)});}
  #|}

///|
fn json_evidence_comparison(view : BriefView) -> JsonEvidenceComparison raise {
  let state = view.json_evidence
  guard state.source is Some(before) &&
    state.table is Some(table) &&
    view.draft.sources.get(state.slot - 1) == Some(before) else {
    fail("Explore a current before source first.")
  }
  guard state.compare_source is Some(after) &&
    view.draft.sources.get(state.compare_slot - 1) == Some(after) &&
    state.compare_slot != state.slot else {
    fail(
      "Choose a different current after source. Reselect it if the source list changed.",
    )
  }
  let fields : Array[String] = match
    @json.parse(json_evidence_csv_fields_text(state.compare_fields)) {
    { "fields": fields, .. } => @json.from_json(fields)
    { "error": String(message), .. } => fail(message)
    _ => fail("Choose comparison field pointers.")
  }
  let pointers = [state.compare_key] + fields
  let before_fields = pointers.map(pointer => {
    json_evidence_parse_mode(
      before.content_hex,
      state.pointer,
      table.format == "jsonl",
      pointer,
    )
  })
  let after_fields = pointers.map(pointer => {
    json_evidence_parse_mode(
      after.content_hex,
      state.compare_pointer,
      state.compare_lines,
      pointer,
    )
  })
  let metadata : Json = {
    "brief_id": view.draft.brief_id,
    "before": {
      "slot": state.slot,
      "name": before.name,
      "origin": before.origin,
      "captured_at": before.captured_at,
      "kind": before.kind,
      "array_pointer": state.pointer,
    },
    "after": {
      "slot": state.compare_slot,
      "name": after.name,
      "origin": after.origin,
      "captured_at": after.captured_at,
      "kind": after.kind,
      "array_pointer": state.compare_pointer,
    },
  }
  match
    @json.parse(
      json_evidence_compare_text(
        before_fields.to_json().stringify(),
        after_fields.to_json().stringify(),
        metadata.stringify(),
      ),
    ) {
    { "comparison": comparison, .. } => @json.from_json(comparison)
    { "error": String(message), .. } => fail(message)
    _ => fail("Snapshot comparison is unavailable.")
  }
}

///|
extern "js" fn json_evidence_compare_download(content : String) -> String =
  #|content => {
  #| let url,link;
  #| try {
  #|   url=URL.createObjectURL(new Blob([content],{type:'application/json;charset=utf-8'}));
  #|   link=document.createElement('a');link.href=url;link.download='moonfind-json-snapshot-comparison.json';
  #|   document.body.appendChild(link);link.click();return '';
  #| }catch(_){return 'Comparison download failed; your sources and comparison settings remain available. Try again.';}
  #| finally {if(link){try{link.remove();}catch(_){}}if(url)setTimeout(()=>URL.revokeObjectURL(url),1000);}
  #|}
