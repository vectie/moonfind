///|
struct JsonEvidenceCohortDraft {
  first_pointer : String
  first_value : String
  second_pointer : String
  second_value : String
  any : Bool
} derive(Debug, Eq)

///|
struct JsonEvidenceCohortCondition {
  pointer : String
  value : String
} derive(Debug, Eq, FromJson)

///|
struct JsonEvidenceCohortRow {
  record_number : Int
  source_line : Int
  record_pointer : String
  status : String
  results : Array[String]
  values : Array[JsonEvidenceLensRow]
} derive(Debug, Eq, FromJson)

///|
struct JsonEvidenceCohort {
  total : Int
  mode : String
  conditions : Array[JsonEvidenceCohortCondition]
  matched : Array[Int]
  excluded : Array[Int]
  unresolved : Array[Int]
  rows : Array[JsonEvidenceCohortRow]
} derive(Debug, Eq, FromJson)

///|
fn empty_json_evidence_cohort_draft() -> JsonEvidenceCohortDraft {
  {
    first_pointer: "",
    first_value: "",
    second_pointer: "",
    second_value: "",
    any: false,
  }
}

///|
// Both projections come from the existing lossless source parser. Numeric
// equality deliberately compares source tokens; JSON.parse only decodes strings
// and validates the requested scalar, never supplies a numeric comparison value.
extern "js" fn json_evidence_cohort_text(
  responses_json : String,
  values_json : String,
  any : Bool,
) -> String =
  #|(responses_json,values_json,any) => {
  #| try {
  #|   const responses=JSON.parse(responses_json).map(value=>JSON.parse(value)), requested=JSON.parse(values_json);
  #|   if(![1,2].includes(responses.length)||requested.length!==responses.length)throw Error('Use one or two field conditions.');
  #|   const conditions=requested.map((value,index)=>{
  #|     if(typeof value!=='string'||value.length>1024)throw Error('Condition '+(index+1)+': use a scalar JSON literal up to 1,024 UTF-16 units.');
  #|     const raw=value.replace(/^[ \t\r\n]+|[ \t\r\n]+$/g,''), parsed=JSON.parse(raw);
  #|     if(parsed!==null&&typeof parsed==='object')throw Error('Condition '+(index+1)+': use a string, number, boolean or null, not an array or object.');
  #|     return {raw,kind:parsed===null?'null':typeof parsed,value:parsed};
  #|   });
  #|   for(const response of responses){
  #|     if(response.error)throw Error(response.error);
  #|     if(!response.lens||!response.lens.pointer)throw Error('Enter a field pointer for each condition.');
  #|   }
  #|   const first=responses[0], count=first.table.rows.length;
  #|   for(const response of responses){
  #|     if(JSON.stringify(response.table)!==JSON.stringify(first.table)||response.lens.rows.length!==count)throw Error('Conditions must inspect the same current source records.');
  #|   }
  #|   const matched=[],excluded=[],unresolved=[];
  #|   const rows=first.table.rows.map((record,index)=>{
  #|     const values=responses.map(response=>response.lens.rows[index]);
  #|     const results=values.map((row,i)=>{
  #|       if(row.record_number!==record.record_number||row.source_line!==record.source_line||row.record_pointer!==record.pointer)throw Error('Source record identity changed. Explore the source again.');
  #|       if(row.kind==='missing'||row.kind==='blocked')return row.kind;
  #|       const kind=row.kind==='empty-string'?'string':row.kind, condition=conditions[i];
  #|       if(kind!==condition.kind)return 'no-match';
  #|       return (kind==='string'?row.text===condition.value:row.raw===condition.raw)?'match':'no-match';
  #|     });
  #|     const unknown=results.some(result=>result==='missing'||result==='blocked');
  #|     const status=any?(results.includes('match')?'match':unknown?'unresolved':'no-match'):(results.includes('no-match')?'no-match':unknown?'unresolved':'match');
  #|     (status==='match'?matched:status==='no-match'?excluded:unresolved).push(record.record_number);
  #|     return {record_number:record.record_number,source_line:record.source_line,record_pointer:record.pointer,status,results,values};
  #|   });
  #|   return JSON.stringify({cohort:{total:count,mode:any?'any':'all',conditions:conditions.map((condition,index)=>({pointer:responses[index].lens.pointer,value:condition.raw})),matched,excluded,unresolved,rows}});
  #| }catch(error){return JSON.stringify({error:String(error)});}
  #|}

///|
fn json_evidence_cohort(state : JsonEvidenceView) -> JsonEvidenceCohort raise {
  guard state.source is Some(source) && state.table is Some(table) else {
    fail("Explore a current JSON or JSONL capture before previewing a cohort.")
  }
  let draft = state.cohort_draft
  guard !draft.first_pointer.is_empty() else {
    fail("Enter the first condition's field pointer.")
  }
  guard !draft.second_pointer.is_empty() || draft.second_value.is_empty() else {
    fail(
      "Enter a second field pointer, or clear its value to use one condition.",
    )
  }
  let pointers = [draft.first_pointer]
  let values = [draft.first_value]
  if !draft.second_pointer.is_empty() {
    pointers.push(draft.second_pointer)
    values.push(draft.second_value)
  }
  let responses = pointers.map(pointer => {
    json_evidence_parse_mode(
      source.content_hex,
      state.pointer,
      table.format == "jsonl",
      pointer,
    )
  })
  match
    @json.parse(
      json_evidence_cohort_text(
        responses.to_json().stringify(),
        values.to_json().stringify(),
        draft.any,
      ),
    ) {
    { "error": String(message), .. } => fail(message)
    { "cohort": cohort, .. } => @json.from_json(cohort)
    _ => fail("JSON cohort inspection is unavailable.")
  }
}

///|
fn json_evidence_cohort_selection(
  cohort : JsonEvidenceCohort,
  status : String,
) -> Array[Int] raise {
  match status {
    "match" => cohort.matched.copy()
    "unresolved" => cohort.unresolved.copy()
    _ => fail("Choose matching or unresolved records from the current preview.")
  }
}
