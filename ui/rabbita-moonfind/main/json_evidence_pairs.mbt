///|
struct JsonEvidencePairValue {
  kind : String
  display : String
} derive(Debug, Eq, FromJson)

///|
struct JsonEvidencePairRow {
  record_number : Int
  source_line : Int
  record_pointer : String
  values : Array[JsonEvidenceLensRow]
} derive(Debug, Eq, FromJson)

///|
struct JsonEvidencePairGroup {
  pair_number : Int
  first : JsonEvidencePairValue
  second : JsonEvidencePairValue
  scalar : Bool
  count : Int
  records : Array[Int]
  rows : Array[JsonEvidencePairRow]
} derive(Debug, Eq, FromJson)

///|
struct JsonEvidencePairs {
  first_pointer : String
  second_pointer : String
  total : Int
  scalar_count : Int
  gap_count : Int
  groups : Array[JsonEvidencePairGroup]
} derive(Debug, Eq, FromJson)

///|
// Count observed pairs from two projections of the SAME lossless intake.
// No source value passes through Number; strings group by decoded exact text.
// Missing/blocked/container kinds form explicitly non-scalar groups, never
// invented scalar values. Each source row belongs to exactly one pair.
extern "js" fn json_evidence_pairs_text(responses_json : String) -> String =
  #|responses_json => {
  #| try {
  #|   const responses=JSON.parse(responses_json).map(value=>JSON.parse(value));
  #|   if(responses.length!==2)throw Error('Choose two field pointers.');
  #|   for(const response of responses){
  #|     if(response.error)throw Error(response.error);
  #|     if(!response.lens||!response.lens.pointer)throw Error('Enter both field pointers.');
  #|   }
  #|   const [first,second]=responses, count=first.table.rows.length;
  #|   if(first.lens.pointer===second.lens.pointer)throw Error('Choose two different field pointers. Use the nested-field lens for one field.');
  #|   if(JSON.stringify(first.table)!==JSON.stringify(second.table)||responses.some(response=>response.lens.rows.length!==count))throw Error('Both fields must inspect the same current source records.');
  #|   const category=row=>{
  #|     const kind=row.kind==='empty-string'?'string':row.kind;
  #|     if(kind==='string')return {key:JSON.stringify([kind,row.text]),value:{kind,display:JSON.stringify(row.text)},scalar:true};
  #|     if(['number','boolean','null'].includes(kind))return {key:JSON.stringify([kind,row.raw]),value:{kind,display:row.raw},scalar:true};
  #|     if(!['missing','blocked','array','object'].includes(kind))throw Error('Unsupported source field kind.');
  #|     return {key:JSON.stringify([kind]),value:{kind,display:kind==='missing'?'(missing path)':kind==='blocked'?'(blocked path)':'(non-scalar '+kind+'; values not compared)'},scalar:false};
  #|   };
  #|   const groups=[], byPair=new Map();let scalar_count=0;
  #|   first.table.rows.forEach((record,index)=>{
  #|     const values=responses.map(response=>response.lens.rows[index]);
  #|     for(const value of values){
  #|       if(value.record_number!==record.record_number||value.source_line!==record.source_line||value.record_pointer!==record.pointer)throw Error('Source record identity changed. Explore the source again.');
  #|     }
  #|     const left=category(values[0]),right=category(values[1]),scalar=left.scalar&&right.scalar,key=JSON.stringify([left.key,right.key]);
  #|     if(scalar)scalar_count++;
  #|     let group=byPair.get(key);
  #|     if(!group){group={pair_number:groups.length+1,first:left.value,second:right.value,scalar,count:0,records:[],rows:[]};byPair.set(key,group);groups.push(group);}
  #|     group.count++;group.records.push(record.record_number);
  #|     group.rows.push({record_number:record.record_number,source_line:record.source_line,record_pointer:record.pointer,values});
  #|   });
  #|   return JSON.stringify({pairs:{first_pointer:first.lens.pointer,second_pointer:second.lens.pointer,total:count,scalar_count,gap_count:count-scalar_count,groups}});
  #| }catch(error){return JSON.stringify({error:String(error)});}
  #|}

///|
fn json_evidence_pairs(state : JsonEvidenceView) -> JsonEvidencePairs raise {
  guard state.source is Some(source) && state.table is Some(table) else {
    fail("Explore a current JSON or JSONL capture before comparing two fields.")
  }
  let responses = [state.pair_first_pointer, state.pair_second_pointer].map(pointer => {
    json_evidence_parse_mode(
      source.content_hex,
      state.pointer,
      table.format == "jsonl",
      pointer,
    )
  })
  match @json.parse(json_evidence_pairs_text(responses.to_json().stringify())) {
    { "error": String(message), .. } => fail(message)
    { "pairs": pairs, .. } => @json.from_json(pairs)
    _ => fail("Two-field JSON breakdown is unavailable.")
  }
}

///|
fn json_evidence_pair_selection(
  pairs : JsonEvidencePairs,
  number : Int,
) -> Array[Int] raise {
  for group in pairs.groups {
    if group.pair_number == number {
      return group.records.copy()
    }
  }
  fail("Choose an observed pair from the current breakdown.")
}
