///|
struct JsonEvidenceCell {
  kind : String
  text : String
} derive(Debug, Eq, ToJson, FromJson)

///|
struct JsonEvidenceRow {
  record_number : Int
  source_line : Int
  pointer : String
  raw : String
  cells : Array[JsonEvidenceCell]
} derive(Debug, Eq, ToJson, FromJson)

///|
struct JsonEvidenceTable {
  format : String
  columns : Array[String]
  rows : Array[JsonEvidenceRow]
} derive(Debug, Eq, ToJson, FromJson)

///|
struct JsonEvidenceView {
  slot : Int
  source : BriefInputSource?
  pointer : String
  table : JsonEvidenceTable?
  query : String
  selected : Array[Int]
  lens_pointer : String
  lens : JsonEvidenceLens?
  cohort_draft : JsonEvidenceCohortDraft
  cohort : JsonEvidenceCohort?
  pair_first_pointer : String
  pair_second_pointer : String
  pairs : JsonEvidencePairs?
  csv_fields : String
  compare_slot : Int
  compare_source : BriefInputSource?
  compare_pointer : String
  compare_lines : Bool
  compare_key : String
  compare_fields : String
} derive(Debug, Eq)

///|
enum JsonEvidenceMsg {
  Source(Int)
  Pointer(String)
  Explore
  ExploreLines
  ChooseLines
  LinesLoaded(Int, String)
  Search(String)
  Toggle(Int)
  SelectMatching
  SelectCoverage(Int, String)
  LensPointer(String)
  ExploreLens
  SelectLens(String)
  CohortField(Int, String)
  CohortAny(Bool)
  PreviewCohort
  SelectCohort(String)
  PairPointer(Int, String)
  PreviewPairs
  SelectPair(Int)
  Clear
  Download
  DownloadNdjson
  CsvFields(String)
  DownloadCsv
  CompareSource(Int)
  CompareLines(Bool)
  CompareField(Int, String)
  DownloadComparison
  Add
}

///|
fn empty_json_evidence_view() -> JsonEvidenceView {
  {
    slot: 0,
    source: None,
    pointer: "",
    table: None,
    query: "",
    selected: [],
    lens_pointer: "",
    lens: None,
    cohort_draft: empty_json_evidence_cohort_draft(),
    cohort: None,
    pair_first_pointer: "",
    pair_second_pointer: "",
    pairs: None,
    csv_fields: "[]",
    compare_slot: 0,
    compare_source: None,
    compare_pointer: "",
    compare_lines: false,
    compare_key: "",
    compare_fields: "[]",
  }
}

///|
// Validate JSON, then retain exact token spans. Numbers never pass through a
// floating-point value in the table or extract. JSON.parse is used only for
// syntax validation and decoding individual string tokens.
extern "js" fn json_evidence_parse_mode(
  hex : String,
  pointer : String,
  lines : Bool,
  field_pointer : String,
) -> String =
  #|(hex,pointer,lines,field_pointer='') => {
  #| try {
  #|   if(hex.length>65536 || !/^(?:[0-9a-fA-F]{2})*$/.test(hex)) throw Error('Use a valid UTF-8 JSON capture up to 32 KiB.');
  #|   let text=new TextDecoder('utf-8',{fatal:true,ignoreBOM:true}).decode(Uint8Array.from(hex.match(/../g)||[],v=>parseInt(v,16))).replace(/^\uFEFF/,'');
  #|   const original=text;
  #|   if(!lines)JSON.parse(text);
  #|   let at=0;
  #|   const ws=()=>{while(/[ \t\r\n]/.test(text[at]||'!'))at++;};
  #|   const string=()=>{const start=at++;while(at<text.length){if(text[at]==='\\'){at+=2;continue;}if(text[at++]==='"')return JSON.parse(text.slice(start,at));}throw Error('Unclosed JSON string.');};
  #|   const read=depth=>{
  #|     if(depth>32)throw Error('JSON nesting exceeds 32 levels.');
  #|     ws();const start=at;let node;
  #|     if(text[at]==='{'){
  #|       at++;ws();const members=new Map();
  #|       if(text[at]!=='}')while(true){const key=string();if(members.has(key))throw Error('Duplicate JSON object field: '+key);ws();at++;const value=read(depth+1);members.set(key,value);ws();if(text[at]!==',')break;at++;ws();}
  #|       at++;node={kind:'object',members};
  #|     }else if(text[at]==='['){
  #|       at++;ws();const items=[];
  #|       if(text[at]!==']')while(true){items.push(read(depth+1));ws();if(text[at]!==',')break;at++;}
  #|       at++;node={kind:'array',items};
  #|     }else if(text[at]==='"'){node={kind:'string',value:string()};}
  #|     else {while(at<text.length&&!/[ \t\r\n,\]}]/.test(text[at]))at++;const token=text.slice(start,at);node={kind:token==='null'?'null':token==='true'||token==='false'?'boolean':'number'};}
  #|     node.raw=text.slice(start,at);return node;
  #|   };
  #|   const lineNumbers=[];let node;
  #|   if(lines){
  #|     const items=[];
  #|     for(const [index,line] of original.split(/\r\n|\n|\r/).entries()){
  #|       if(/^[ \t]*$/.test(line))continue;
  #|       try {JSON.parse(line);text=line;at=0;const record=read(0);if(record.kind!=='object')throw Error('Each JSONL line must contain one object.');items.push(record);lineNumbers.push(index+1);if(items.length>512)throw Error('Explore at most 512 JSON records.');}
  #|       catch(error){throw Error('Source line '+(index+1)+': '+String(error));}
  #|     }
  #|     if(!items.length)throw Error('No JSONL object records were found.');
  #|     node={kind:'array',items};pointer='';
  #|   }else node=read(0);
  #|   const pointerKeys=value=>{
  #|     if(typeof value!=='string'||value.length>1024||(value!==''&&!value.startsWith('/')))throw Error('Use a JSON Pointer up to 1,024 UTF-16 units beginning with /, or an empty root pointer.');
  #|     return value===''?[]:value.slice(1).split('/').map(encoded=>{
  #|       if(/~(?![01])/.test(encoded))throw Error('JSON Pointer escapes must be ~0 for ~ or ~1 for /.');
  #|       return encoded.replace(/~1/g,'/').replace(/~0/g,'~');
  #|     });
  #|   };
  #|   const fieldKeys=pointerKeys(field_pointer);
  #|   for(const key of pointerKeys(pointer)){
  #|     if(node.kind==='object'&&node.members.has(key))node=node.members.get(key);
  #|     else if(node.kind==='array'&&/^(0|[1-9][0-9]*)$/.test(key)&&Number(key)<node.items.length)node=node.items[Number(key)];
  #|     else throw Error('JSON Pointer does not identify a value in this capture.');
  #|   }
  #|   if(node.kind!=='array')throw Error('Choose a JSON array of object records.');
  #|   if(node.items.length>512)throw Error('Explore at most 512 JSON records.');
  #|   const columns=[];
  #|   for(const record of node.items){
  #|     if(record.kind!=='object')throw Error('Every array record must be an object.');
  #|     for(const key of record.members.keys())if(!columns.includes(key)){columns.push(key);if(columns.length>32)throw Error('Explore at most 32 distinct JSON fields.');}
  #|   }
  #|   const rows=node.items.map((record,index)=>({record_number:index+1,source_line:lines?lineNumbers[index]:0,pointer:lines?'':pointer+'/'+index,raw:record.raw,cells:columns.map(key=>{const value=record.members.get(key);return value?{kind:value.kind,text:value.kind==='string'?value.value:value.raw}:{kind:'missing',text:''};})}));
  #|   const result={table:{format:lines?'jsonl':'json-array',columns,rows}};
  #|   if(field_pointer!==''){
  #|     const kinds=['missing','blocked','null','empty-string','string','number','boolean','array','object'];
  #|     const buckets=kinds.map(kind=>({kind,count:0,records:[]}));
  #|     const values=node.items.map((record,index)=>{
  #|       let value=record,kind='';
  #|       for(const key of fieldKeys){
  #|         if(value.kind==='object'){
  #|           if(!value.members.has(key)){kind='missing';break;}
  #|           value=value.members.get(key);
  #|         }else if(value.kind==='array'){
  #|           if(!/^(0|[1-9][0-9]*)$/.test(key)){kind='blocked';break;}
  #|           if(Number(key)>=value.items.length){kind='missing';break;}
  #|           value=value.items[Number(key)];
  #|         }else {kind='blocked';break;}
  #|       }
  #|       const absent=kind!=='';
  #|       if(!absent)kind=value.kind==='string'&&value.value===''?'empty-string':value.kind;
  #|       const row=rows[index],bucket=buckets.find(bucket=>bucket.kind===kind);
  #|       bucket.count++;bucket.records.push(row.record_number);
  #|       return {record_number:row.record_number,source_line:row.source_line,record_pointer:row.pointer,value_pointer:row.pointer+field_pointer,kind,text:absent?'':value.kind==='string'?value.value:value.raw,raw:absent?'':value.raw};
  #|     });
  #|     result.lens={pointer:field_pointer,total:rows.length,rows:values,buckets};
  #|   }
  #|   return JSON.stringify(result);
  #| }catch(error){return JSON.stringify({error:String(error)});}
  #|}

///|
fn json_evidence_table(
  source : BriefInputSource,
  pointer : String,
) -> JsonEvidenceTable raise {
  match
    @json.parse(
      json_evidence_parse_mode(source.content_hex, pointer, false, ""),
    ) {
    { "error": String(message), .. } => fail(message)
    { "table": table, .. } => @json.from_json(table)
    _ => fail("JSON evidence could not be read.")
  }
}

///|
extern "js" fn json_evidence_fold(value : String) -> String =
  #|value => value.toLowerCase().replace(/ς/g,'σ')

///|
fn json_evidence_matches(view : JsonEvidenceView) -> Array[JsonEvidenceRow] {
  let query = json_evidence_fold(view.query.trim().to_owned())
  view.table
  .map(table => {
    table.rows.filter(row => {
      query.is_empty() ||
      row.cells.any(cell => json_evidence_fold(cell.text).contains(query))
    })
  })
  .unwrap_or([])
}

///|
fn json_evidence_selected(view : JsonEvidenceView) -> Array[JsonEvidenceRow] {
  view.table
  .map(table => {
    table.rows.filter(row => view.selected.contains(row.record_number))
  })
  .unwrap_or([])
}

///|
fn sync_json_evidence(view : BriefView) -> BriefView {
  let state = view.json_evidence
  if state.source is Some(source) &&
    view.draft.sources.get(state.slot - 1) != Some(source) {
    { ..view, json_evidence: empty_json_evidence_view(), }
  } else {
    view
  }
}

///|
fn json_evidence_export(view : BriefView) -> String raise {
  let state = view.json_evidence
  guard state.source is Some(source) &&
    state.table is Some(table) &&
    view.draft.sources.get(state.slot - 1) == Some(source) else {
    fail("Explore a current JSON capture before exporting records.")
  }
  let records = json_evidence_selected(state)
  let (revision, digest) : (Json, Json) = match view.opened {
    Some(status) if status.state == "prepared" &&
      status.snapshot is Some(snapshot) &&
      snapshot.brief == view.draft &&
      snapshot.revision_id == status.revision_id &&
      snapshot.sources.get(state.slot - 1) is Some(saved) &&
      saved.slot == state.slot &&
      saved.name == source.name &&
      saved.origin == source.origin &&
      saved.captured_at == source.captured_at &&
      saved.kind == source.kind &&
      saved.byte_count * 2 == source.content_hex.length() =>
      (Json::string(status.revision_id), Json::string(saved.digest))
    _ => (Json::null(), Json::null())
  }
  let metadata : Json = {
    "contract_id": if table.format == "jsonl" {
      "moonfind.jsonl-evidence-extract.v1"
    } else {
      "moonfind.json-evidence-extract.v1"
    },
    "source_format": table.format,
    "brief_id": view.draft.brief_id,
    "prepared_revision_id": revision,
    "source": {
      "slot": state.slot,
      "name": source.name,
      "origin": source.origin,
      "captured_at": source.captured_at,
      "kind": source.kind,
      "host_recorded_digest": digest,
    },
    "array_pointer": if table.format == "jsonl" {
      Json::null()
    } else {
      Json::string(state.pointer)
    },
    "source_record_count": table.rows.length(),
    "selected_record_count": records.length(),
    "boundary": "Selected original JSON object records with zero-based source JSON Pointers for JSON arrays or one-based physical source lines for JSONL. Original numeric tokens and object bytes are preserved; no truth or full-text verification is implied. The complete source stays in the brief but is not included in this extract. Review all fields before sharing.",
  }
  let header = metadata.stringify(indent=2)
  let body = records
    .map(row => {
      "{\"source_pointer\":" +
      (if table.format == "jsonl" {
        "null"
      } else {
        Json::string(row.pointer).stringify()
      }) +
      (if table.format == "jsonl" {
        ",\"source_line\":" + row.source_line.to_string()
      } else {
        ""
      }) +
      ",\"source_record\":" +
      row.record_number.to_string() +
      ",\"record\":" +
      row.raw +
      "}"
    })
    .join(",\n")
  // Keep the exact record spans outside metadata serialization.
  header.strip_suffix("}").unwrap().trim_end().to_owned() +
  ",\n  \"records\": [\n" +
  body +
  "\n  ]\n}\n"
}

///|
extern "js" fn json_evidence_download(content : String) -> String =
  #|content => {
  #| let url,link;
  #| try {
  #|   url=URL.createObjectURL(new Blob([content],{type:'application/json;charset=utf-8'}));
  #|   link=document.createElement('a');link.href=url;link.download='moonfind-json-evidence-extract.json';
  #|   document.body.appendChild(link);link.click();return '';
  #| }catch(_){return 'JSON evidence download failed; your selections remain available. Try again.';}
  #| finally {if(link){try{link.remove();}catch(_){}}if(url)setTimeout(()=>URL.revokeObjectURL(url),1000);}
  #|}

///|
fn update_json_evidence(
  emit : @rabbita.Emit[Msg],
  action : JsonEvidenceMsg,
  view : BriefView,
) -> (@rabbita.Cmd, BriefView) {
  if view.pending {
    return (@rabbita.none, view)
  }
  let view = sync_json_evidence(view)
  let state = view.json_evidence
  let next = try {
    match action {
      ChooseLines => {
        let generation = view.generation
        return (
          @cmd.custom_cmd(scheduler => {
            json_lines_choose(raw => {
              scheduler.add(
                emit(BriefAction(JsonEvidence(LinesLoaded(generation, raw)))),
              )
            })
          }),
          view,
        )
      }
      LinesLoaded(generation, _) if generation != view.generation => view
      LinesLoaded(_, raw) => {
        let payload = @json.parse(raw)
        if payload is { "cancelled": True, .. } {
          return (@rabbita.none, view)
        }
        if payload is { "error": String(error), .. } {
          fail(error)
        }
        guard payload is { "source": value, .. } else {
          fail("No JSONL source was selected.")
        }
        let source : BriefInputSource = @json.from_json(value)
        let table = json_lines_table(source)
        guard view.draft.sources.length() < 8 &&
          view.draft.sources.fold(init=source.content_hex.length(), (
            total,
            source,
          ) => total + source.content_hex.length()) <=
          262144 else {
          fail(
            "JSONL import needs one available source slot and 128 KiB total space.",
          )
        }
        {
          ..brief_edited(view, {
            ..view.draft,
            sources: view.draft.sources + [source],
          }),
          json_evidence: {
            ..empty_json_evidence_view(),
            slot: view.draft.sources.length() + 1,
            source: Some(source),
            table: Some(table),
          },
        }
      }
      ExploreLines => {
        guard state.source is Some(source) else {
          fail("Choose a loaded JSONL source first.")
        }
        let table = json_lines_table(source)
        {
          ..view,
          json_evidence: {
            ..state,
            pointer: "",
            table: Some(table),
            selected: [],
            query: "",
            lens: None,
            cohort: None,
            pairs: None,
          },
          error: None,
        }
      }
      Source(slot) => {
        let source = view.draft.sources.get(slot - 1)
        {
          ..view,
          json_evidence: {
            ..empty_json_evidence_view(),
            slot: if source is Some(_) {
              slot
            } else {
              0
            },
            source,
          },
          error: None,
        }
      }
      Pointer(pointer) =>
        {
          ..view,
          json_evidence: {
            ..state,
            pointer,
            table: None,
            selected: [],
            query: "",
            lens: None,
            cohort: None,
            pairs: None,
          },
          error: None,
        }
      Explore => {
        guard state.source is Some(source) else {
          fail("Choose a loaded JSON source first.")
        }
        let table = json_evidence_table(source, state.pointer)
        {
          ..view,
          json_evidence: {
            ..state,
            table: Some(table),
            selected: [],
            query: "",
            lens: None,
            cohort: None,
            pairs: None,
          },
          error: None,
        }
      }
      Search(query) => { ..view, json_evidence: { ..state, query, }, }
      LensPointer(lens_pointer) =>
        {
          ..view,
          json_evidence: { ..state, lens_pointer, lens: None, },
          error: None,
        }
      ExploreLens => {
        let lens = json_evidence_lens(state)
        { ..view, json_evidence: { ..state, lens: Some(lens), }, error: None, }
      }
      SelectLens(kind) => {
        guard state.table is Some(_) &&
          state.lens is Some(lens) &&
          lens.pointer == state.lens_pointer else {
          fail("Inspect a current nested field before selecting its records.")
        }
        let selected = json_evidence_lens_selection(lens, kind)
        {
          ..view,
          json_evidence: { ..state, selected, query: "", },
          error: None,
        }
      }
      CohortField(index, value) => {
        let draft = state.cohort_draft
        let cohort_draft = match index {
          0 => { ..draft, first_pointer: value, }
          1 => { ..draft, first_value: value, }
          2 => { ..draft, second_pointer: value, }
          3 => { ..draft, second_value: value, }
          _ => draft
        }
        {
          ..view,
          json_evidence: { ..state, cohort_draft, cohort: None, },
          error: None,
        }
      }
      CohortAny(any) =>
        {
          ..view,
          json_evidence: {
            ..state,
            cohort_draft: { ..state.cohort_draft, any, },
            cohort: None,
          },
          error: None,
        }
      PreviewCohort => {
        let cohort = json_evidence_cohort(state)
        {
          ..view,
          json_evidence: { ..state, cohort: Some(cohort), },
          error: None,
        }
      }
      SelectCohort(status) => {
        guard state.table is Some(_) && state.cohort is Some(cohort) else {
          fail("Preview a current JSON cohort before replacing selection.")
        }
        let selected = json_evidence_cohort_selection(cohort, status)
        {
          ..view,
          json_evidence: { ..state, selected, query: "", },
          error: None,
        }
      }
      PairPointer(index, pointer) => {
        let state = match index {
          0 => { ..state, pair_first_pointer: pointer, pairs: None, }
          1 => { ..state, pair_second_pointer: pointer, pairs: None, }
          _ => state
        }
        { ..view, json_evidence: state, error: None, }
      }
      PreviewPairs => {
        let pairs = json_evidence_pairs(state)
        {
          ..view,
          json_evidence: { ..state, pairs: Some(pairs), },
          error: None,
        }
      }
      SelectPair(number) => {
        guard state.table is Some(_) &&
          state.pairs is Some(pairs) &&
          pairs.first_pointer == state.pair_first_pointer &&
          pairs.second_pointer == state.pair_second_pointer else {
          fail(
            "Preview the current two fields before selecting an observed pair.",
          )
        }
        let selected = json_evidence_pair_selection(pairs, number)
        {
          ..view,
          json_evidence: { ..state, selected, query: "", },
          error: None,
        }
      }
      Toggle(number) => {
        guard state.table is Some(table) &&
          table.rows.any(row => row.record_number == number) else {
          return (@rabbita.none, view)
        }
        {
          ..view,
          json_evidence: {
            ..state,
            selected: csv_toggle(state.selected, number),
          },
        }
      }
      SelectCoverage(column, kind) => {
        guard state.table is Some(table) else {
          fail(
            "Explore a current JSON capture before selecting field coverage.",
          )
        }
        let selected = json_evidence_coverage_selection(table, column, kind)
        {
          ..view,
          json_evidence: { ..state, selected, query: "", },
          error: None,
        }
      }
      SelectMatching => {
        let selected = state.selected.copy()
        for row in json_evidence_matches(state) {
          if !selected.contains(row.record_number) {
            selected.push(row.record_number)
          }
        }
        { ..view, json_evidence: { ..state, selected, }, }
      }
      Clear => { ..view, json_evidence: { ..state, selected: [], }, }
      Download => {
        let error = json_evidence_download(json_evidence_export(view))
        { ..view, error: if error.is_empty() { None } else { Some(error) }, }
      }
      CsvFields(csv_fields) =>
        { ..view, json_evidence: { ..state, csv_fields, }, error: None, }
      DownloadCsv => {
        let csv = json_evidence_csv(view)
        let error = json_evidence_csv_download(csv.text)
        { ..view, error: if error.is_empty() { None } else { Some(error) }, }
      }
      CompareSource(compare_slot) =>
        {
          ..view,
          json_evidence: {
            ..state,
            compare_slot,
            compare_source: view.draft.sources.get(compare_slot - 1),
          },
          error: None,
        }
      CompareLines(compare_lines) =>
        { ..view, json_evidence: { ..state, compare_lines, }, error: None, }
      CompareField(index, value) => {
        let state = match index {
          0 => { ..state, compare_pointer: value, }
          1 => { ..state, compare_key: value, }
          2 => { ..state, compare_fields: value, }
          _ => state
        }
        { ..view, json_evidence: state, error: None, }
      }
      DownloadComparison => {
        let comparison = json_evidence_comparison(view)
        let error = json_evidence_compare_download(comparison.text)
        { ..view, error: if error.is_empty() { None } else { Some(error) }, }
      }
      DownloadNdjson => {
        let error = json_evidence_ndjson_download(json_evidence_ndjson(view))
        { ..view, error: if error.is_empty() { None } else { Some(error) }, }
      }
      Add => {
        guard !json_evidence_selected(state).is_empty() else {
          fail("Select at least one JSON record to add to the brief.")
        }
        let content = json_evidence_export(view)
        let hex = brief_text_hex(content)
        guard view.draft.sources.length() < 8 &&
          hex.length() <= 65536 &&
          view.draft.sources.fold(init=hex.length(), (total, source) => {
            total + source.content_hex.length()
          }) <=
          262144 else {
          fail(
            "The extract must fit one available source slot, 32 KiB per source and 128 KiB total. Select fewer records or download it separately.",
          )
        }
        let source = state.source.unwrap()
        let capture : BriefInputSource = {
          name: "json-evidence-extract.json",
          origin: "Selected JSON records from loaded source slot " +
          state.slot.to_string() +
          ": " +
          source.name +
          " at " +
          (if state.table is Some(table) && table.format == "jsonl" {
            "physical JSONL source lines"
          } else if state.pointer.is_empty() {
            "(root)"
          } else {
            state.pointer
          }),
          captured_at: brief_now(),
          kind: "pasted-text",
          content_hex: hex,
        }
        {
          ..brief_edited(view, {
            ..view.draft,
            sources: view.draft.sources + [capture],
          }),
          json_evidence: { ..state, selected: [], },
        }
      }
    }
  } catch {
    error => { ..view, error: Some("\{error}"), }
  }
  (@rabbita.none, next)
}
