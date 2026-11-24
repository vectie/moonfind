///|
struct JsonEvidenceCoverageBucket {
  kind : String
  count : Int
  records : Array[Int]
} derive(Debug, Eq, FromJson)

///|
struct JsonEvidenceFieldCoverage {
  field : String
  column : Int
  total : Int
  buckets : Array[JsonEvidenceCoverageBucket]
} derive(Debug, Eq, FromJson)

///|
// Consume the lossless parser's typed cells, never reparse numeric tokens.
// Empty strings have their own bucket; all other JSON values retain their type.
extern "js" fn json_evidence_coverage_json(
  table_json : String,
  column : Int,
  kind : String,
) -> String =
  #|(table_json,column,kind) => {
  #| try {
  #|   const table=JSON.parse(table_json);
  #|   const kinds=['missing','null','empty-string','string','number','boolean','array','object'];
  #|   if(!table || !['json-array','json-object','jsonl'].includes(table.format) || !Array.isArray(table.columns) || table.columns.length>32 || table.columns.some(c=>typeof c!=='string') || new Set(table.columns).size!==table.columns.length || !Array.isArray(table.rows) || table.rows.length>512) throw Error('Explore a current JSON or JSONL table first.');
  #|   for(const [index,row] of table.rows.entries()) {
  #|     if(!row || row.record_number!==index+1 || !Array.isArray(row.cells) || row.cells.length!==table.columns.length) throw Error('Evidence table changed; explore the source again.');
  #|     for(const cell of row.cells) if(!cell || !kinds.includes(cell.kind) || cell.kind==='empty-string' || typeof cell.text!=='string') throw Error('Evidence cell type is unavailable; explore the source again.');
  #|   }
  #|   const fields=table.columns.map((field,index)=>{
  #|     const buckets=kinds.map(kind=>({kind,count:0,records:[]}));
  #|     for(const row of table.rows) {
  #|       const cell=row.cells[index], kind=cell.kind==='string'&&cell.text===''?'empty-string':cell.kind;
  #|       const bucket=buckets.find(bucket=>bucket.kind===kind);
  #|       bucket.count++;bucket.records.push(row.record_number);
  #|     }
  #|     return {field,column:index,total:table.rows.length,buckets};
  #|   });
  #|   let selected=[];
  #|   if(column!==-1 || kind!=='') {
  #|     if(!Number.isInteger(column) || column<0 || column>=fields.length || !kinds.includes(kind)) throw Error('Choose a current field and coverage category.');
  #|     selected=fields[column].buckets.find(bucket=>bucket.kind===kind).records;
  #|   }
  #|   return JSON.stringify({fields,selected});
  #| }catch(error){return JSON.stringify({error:String(error)});}
  #|}

///|
fn json_evidence_coverage(
  table : JsonEvidenceTable,
) -> Array[JsonEvidenceFieldCoverage] raise {
  match
    @json.parse(
      json_evidence_coverage_json(table.to_json().stringify(), -1, ""),
    ) {
    { "error": String(message), .. } => fail(message)
    { "fields": fields, .. } => @json.from_json(fields)
    _ => fail("Field coverage is unavailable.")
  }
}

///|
fn json_evidence_coverage_selection(
  table : JsonEvidenceTable,
  column : Int,
  kind : String,
) -> Array[Int] raise {
  match
    @json.parse(
      json_evidence_coverage_json(table.to_json().stringify(), column, kind),
    ) {
    { "error": String(message), .. } => fail(message)
    { "selected": selected, .. } => @json.from_json(selected)
    _ => fail("Coverage selection is unavailable.")
  }
}

///|
fn json_evidence_coverage_panel(
  emit : @rabbita.Emit[Msg],
  table : JsonEvidenceTable,
) -> @rabbita.Html {
  let result = Ok(json_evidence_coverage(table)) catch { e => Err(e) }
  details([
    summary("Inspect JSON field coverage"),
    p(
      "Counts cover all \{table.rows.length()} explored source records, regardless of search or selection. Only top-level fields are compared. Missing, null and empty strings remain separate; zero, false, empty arrays and empty objects are present values. Counts describe source shape, not truth or completeness of an answer.",
    ),
    p(
      "Each category replaces the selection with its source records and clears the search. A zero-count category clears the selection. Use the existing extract, NDJSON or Add to brief actions afterward; every original field is included.",
    ),
    match result {
      Err(error) => p("\{error}")
      Ok(fields) =>
        div(
          fields.map(field => {
            details([
              summary(
                (if field.field.is_empty() {
                  "(empty field name)"
                } else {
                  field.field
                }) +
                " · \{field.total} source records",
              ),
              div(
                style=["display:flex", "gap:8px", "flex-wrap:wrap"],
                field.buckets.map(bucket => {
                  action_button(
                    "Replace selection: " +
                    bucket.kind +
                    " · \{bucket.count} / \{field.total}",
                    emit(
                      BriefAction(
                        JsonEvidence(SelectCoverage(field.column, bucket.kind)),
                      ),
                    ),
                  )
                }),
              ),
            ])
          }),
        )
    },
  ])
}
