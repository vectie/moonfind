///|
struct CsvJoinPreview {
  columns : Array[String]
  rows : Array[CsvRow]
  text : String
  matched : Int
  unmatched_left : Int
  unmatched_right : Int
  empty_left : Int
  empty_right : Int
  duplicate_left : Int
  duplicate_right : Int
  issue : String
} derive(Debug, Eq, FromJson)

///|
struct CsvJoinOutput {
  source : BriefInputSource
  left : BriefInputSource
  right : BriefInputSource
  provenance : String
  preview : CsvJoinPreview
}

///|
struct CsvJoinView {
  left : CsvIntake?
  right : CsvIntake?
  left_key : Int
  right_key : Int
  right_fields : Array[Int]
  mode : String
  pending_output : CsvJoinOutput?
  adopted : CsvJoinOutput?
}

///|
enum CsvJoinMsg {
  PinLeft
  PinRight
  LeftKey(Int)
  RightKey(Int)
  Mode(String)
  ToggleRightField(Int, Int)
  Clear
  UseJoined
  Joined(Int, Result[Json, Error])
}

///|
fn empty_csv_join() -> CsvJoinView {
  {
    left: None,
    right: None,
    left_key: 0,
    right_key: 0,
    right_fields: [],
    mode: "inner",
    pending_output: None,
    adopted: None,
  }
}

///|
// Consume complete native CsvIntake snapshots, never a second CSV parser.
// Keys remain exact decoded strings: no trimming, case folding or coercion.
extern "js" fn csv_join_preview_text(
  left_json : String,
  right_json : String,
  left_key : Int,
  right_key : Int,
  mode : String,
  right_fields_json : String,
) -> String =
  #|(left_json,right_json,left_key,right_key,mode,right_fields_json) => {
  #| try {
  #|   const left=JSON.parse(left_json),right=JSON.parse(right_json);
  #|   for(const [side,table,key] of [['Left',left,left_key],['Right',right,right_key]]){
  #|     if(!table||!Array.isArray(table.columns)||table.columns.length<1||table.columns.length>32||table.columns.some(c=>typeof c!=='string'||!c.trim())||new Set(table.columns).size!==table.columns.length)throw Error(side+' table must have unique nonblank headers. Import it again.');
  #|     if(!Array.isArray(table.rows)||table.rows.length>512||table.total_count!==table.rows.length)throw Error(side+' snapshot must contain all source rows, up to 512. Import it again.');
  #|     if(!Number.isInteger(key)||key<1||key>table.columns.length)throw Error('Choose an explicit '+side.toLowerCase()+' key column.');
  #|     for(const [i,row] of table.rows.entries())if(row.record_number!==i+2||!Array.isArray(row.values)||row.values.length!==table.columns.length||row.values.some(v=>typeof v!=='string'))throw Error(side+' row identity or shape changed. Import it again.');
  #|   }
  #|   const fields=JSON.parse(right_fields_json);if(!Array.isArray(fields)||!fields.length||new Set(fields).size!==fields.length||fields.some(n=>!Number.isInteger(n)||n<1||n>right.columns.length))throw Error('Choose at least one existing right field to append, each once.');
  #|   const indexes=right.columns.map((_,i)=>i).filter(i=>fields.includes(i+1));
  #|   if(!['inner','left'].includes(mode))throw Error('Choose an inner or left join.');
  #|   const counts=(table,key)=>{const map=new Map();let empty=0;for(const row of table.rows){const value=row.values[key-1];if(value===''){empty++;continue;}map.set(value,(map.get(value)||0)+1);}return {map,empty,duplicates:[...map.values()].reduce((n,c)=>n+Math.max(0,c-1),0)};};
  #|   const lc=counts(left,left_key),rc=counts(right,right_key);
  #|   const matched=left.rows.filter(row=>row.values[left_key-1]!==''&&rc.map.has(row.values[left_key-1])).length;
  #|   const unmatched_right=right.rows.filter(row=>row.values[right_key-1]===''||!lc.map.has(row.values[right_key-1])).length;
  #|   const preview={columns:[],rows:[],text:'',matched,unmatched_left:left.rows.length-matched,unmatched_right,empty_left:lc.empty,empty_right:rc.empty,duplicate_left:lc.duplicates,duplicate_right:rc.duplicates,issue:''};
  #|   if(rc.duplicates){preview.issue='Right key has duplicate nonempty values. Resolve them in the source and import again; no arbitrary first match or many-to-many expansion is allowed.';return JSON.stringify({preview});}
  #|   if(left.columns.length+indexes.length+2>32){preview.issue='Joined CSV exceeds 32 columns including two source-record columns. Choose fewer appended right fields or a narrower left table.';return JSON.stringify({preview});}
  #|   const lookup=new Map(right.rows.filter(row=>row.values[right_key-1]!=='').map(row=>[row.values[right_key-1],row]));
  #|   preview.columns=['left_source_record','right_source_record',...left.columns.map((c,i)=>'left '+(i+1)+': '+c),...indexes.map(i=>'right '+(i+1)+': '+right.columns[i])];
  #|   const quote=value=>'"'+value.replace(/"/g,'""')+'"',record=values=>values.map(quote).join(',')+'\r\n';
  #|   const encoder=new TextEncoder();preview.text=record(preview.columns);let bytes=encoder.encode(preview.text).length;
  #|   for(const l of left.rows){const key=l.values[left_key-1],r=key===''?undefined:lookup.get(key);if(!r&&mode==='inner')continue;const values=[String(l.record_number),r?String(r.record_number):'',...l.values,...indexes.map(i=>r?r.values[i]:'')],line=record(values);bytes+=encoder.encode(line).length;if(bytes>32768)break;preview.rows.push({record_number:preview.rows.length+2,values});preview.text+=line;}
  #|   if(bytes>32768){preview.issue='Joined CSV exceeds the existing 32 KiB intake limit. Use smaller input tables.';preview.text='';preview.rows=[];}
  #|   return JSON.stringify({preview});
  #| }catch(error){return JSON.stringify({error:String(error)});}
  #|}

///|
fn csv_join_preview(state : CsvJoinView) -> CsvJoinPreview raise {
  guard state.left is Some(left) && state.right is Some(right) else {
    fail("Pin a left and a right table from the current CSV explorer.")
  }
  match
    @json.parse(
      csv_join_preview_text(
        left.to_json().stringify(),
        right.to_json().stringify(),
        state.left_key,
        state.right_key,
        state.mode,
        state.right_fields.to_json().stringify(),
      ),
    ) {
    { "preview": preview, .. } => @json.from_json(preview)
    { "error": String(message), .. } => fail(message)
    _ => fail("Join preview could not be prepared.")
  }
}

///|
fn csv_join_output(state : CsvJoinView) -> CsvJoinOutput raise {
  let preview = csv_join_preview(state)
  guard preview.issue.is_empty() else { fail(preview.issue) }
  let left = state.left.unwrap()
  let right = state.right.unwrap()
  let provenance = "Local exact-text CSV join\n" +
    "Join: " +
    state.mode +
    "; empty keys never match; duplicate nonempty right keys rejected.\n" +
    "Left key column: \{state.left_key} " +
    left.columns[state.left_key - 1].to_json().stringify() +
    "\n" +
    "Right key column: \{state.right_key} " +
    right.columns[state.right_key - 1].to_json().stringify() +
    "\n" +
    "Appended right column positions: " +
    Array::makei(right.columns.length(), i => i + 1)
    .filter(number => state.right_fields.contains(number))
    .to_json()
    .stringify() +
    "\n" +
    "Source record 1 is each original header; multiline cells remain one record.\n" +
    "Joined rows retain left_source_record and right_source_record; an empty right locator means unmatched, not a blank matched value.\n" +
    "Matched left rows: \{preview.matched}; unmatched left: \{preview.unmatched_left}; unmatched right: \{preview.unmatched_right}.\n" +
    "Empty left keys: \{preview.empty_left}; empty right keys: \{preview.empty_right}; repeated left key rows: \{preview.duplicate_left}.\n" +
    "Values preserve lexical text. No evidence verification, fuzzy matching or numeric normalization.\n"
  {
    source: {
      name: "joined-evidence.csv",
      origin: "Locally joined CSV; full originals and csv-join-lineage.txt are retained when selected rows are added to the brief",
      captured_at: brief_now(),
      kind: "pasted-text",
      content_hex: brief_text_hex(preview.text),
    },
    left: left.source,
    right: right.source,
    provenance,
    preview,
  }
}

///|
// Build source-slot locators only at selection time, so draft edits before then
// cannot cause the lineage companion to point at the wrong original sources.
fn csv_join_retained(view : BriefView) -> Array[BriefInputSource] raise {
  guard view.csv_join.adopted is Some(output) else { return [] }
  guard view.csv.intake is Some(intake) && intake.source == output.source else {
    fail("Joined source changed. Import or create the joined table again.")
  }
  let first = view.draft.sources.length() + 1
  let metadata = fn(source : BriefInputSource) {
    (
      {
        "name": source.name.to_json(),
        "origin": source.origin.to_json(),
        "captured_at": source.captured_at.to_json(),
        "byte_count": (source.content_hex.length() / 2).to_json(),
      } : Json).stringify()
  }
  let text = output.provenance +
    "Left original: source slot \{first}: " +
    metadata(output.left) +
    "\n" +
    "Right original: source slot \{first + 1}: " +
    metadata(output.right) +
    "\n" +
    "This lineage: source slot \{first + 2}. Complete joined CSV: source slot \{first + 3}. Selection: source slot \{first + 4}.\n" +
    "The saved dossier snapshot records byte digests for these exact sources. Removing or reordering sources invalidates these slot references.\n"
  let hex = brief_text_hex(text)
  guard hex.length() <= 65536 else { fail("Join lineage exceeds 32 KiB.") }
  [
    output.left,
    output.right,
    {
      name: "csv-join-lineage.txt",
      origin: "Local join lineage for joined-evidence.csv",
      captured_at: output.source.captured_at,
      kind: "pasted-text",
      content_hex: hex,
    },
  ]
}

///|
fn update_csv_join(
  emit : @rabbita.Emit[Msg],
  action : CsvJoinMsg,
  view : BriefView,
) -> (@rabbita.Cmd, BriefView) {
  if action is ToggleRightField(generation, _) && generation != view.generation {
    return (@rabbita.none, view)
  }
  if view.pending && view.csv_join.pending_output is Some(_) {
    match action {
      ToggleRightField(_, number) =>
        return update_csv_join(
          emit,
          ToggleRightField(view.generation + 1, number),
          csv_join_cancel(view),
        )
      PinLeft | PinRight | LeftKey(_) | RightKey(_) | Mode(_) | Clear =>
        return update_csv_join(emit, action, csv_join_cancel(view))
      _ => ()
    }
  }
  match action {
    Joined(generation, _) if generation != view.generation ||
      !view.pending ||
      view.csv_join.pending_output is None => (@rabbita.none, view)
    Joined(_, result) =>
      try {
        let payload = match result {
          Ok(payload) => payload
          Err(error) => fail("\{error}")
        }
        if brief_reply_error(payload) is Some(message) {
          fail(message)
        }
        let intake : CsvIntake = @json.from_json(payload)
        let output = view.csv_join.pending_output.unwrap()
        guard intake.source == output.source &&
          intake.columns == output.preview.columns &&
          intake.rows == output.preview.rows &&
          intake.total_count == output.preview.rows.length() else {
          fail(
            "Host returned a different joined table. Your original snapshots are unchanged; try again.",
          )
        }
        (
          @rabbita.none,
          {
            ..view,
            pending: false,
            error: None,
            csv: {
              ..empty_csv_view(),
              intake: Some(intake),
              columns: Array::makei(intake.columns.length(), i => i + 1),
            },
            csv_join: {
              ..view.csv_join,
              pending_output: None,
              adopted: Some(output),
            },
          },
        )
      } catch {
        error =>
          (
            @rabbita.none,
            {
              ..view,
              pending: false,
              error: Some("\{error}"),
              csv_join: { ..view.csv_join, pending_output: None, },
            },
          )
      }
    _ if view.pending => (@rabbita.none, view)
    PinLeft | PinRight => {
      guard view.csv.intake is Some(intake) else {
        return (
          @rabbita.none,
          { ..view, error: Some("Import a CSV table first."), },
        )
      }
      guard view.csv_join.adopted is None else {
        return (
          @rabbita.none,
          {
            ..view,
            error: Some(
              "Import an original CSV before pinning. Chained joins are not supported.",
            ),
          },
        )
      }
      let state = match action {
        PinLeft => { ..view.csv_join, left: Some(intake), left_key: 0, }
        _ =>
          {
            ..view.csv_join,
            right: Some(intake),
            right_key: 0,
            right_fields: Array::makei(intake.columns.length(), i => i + 1),
          }
      }
      (
        @rabbita.none,
        {
          ..view,
          generation: view.generation + 1,
          csv_join: state,
          error: None,
        },
      )
    }
    LeftKey(key) =>
      (
        @rabbita.none,
        { ..view, csv_join: { ..view.csv_join, left_key: key, }, error: None, },
      )
    RightKey(key) =>
      (
        @rabbita.none,
        { ..view, csv_join: { ..view.csv_join, right_key: key, }, error: None, },
      )
    ToggleRightField(_, number) => {
      guard view.csv_join.right is Some(right) &&
        number >= 1 &&
        number <= right.columns.length() else {
        return (@rabbita.none, view)
      }
      (
        @rabbita.none,
        {
          ..view,
          csv_join: {
            ..view.csv_join,
            right_fields: csv_toggle(view.csv_join.right_fields, number),
          },
          error: None,
        },
      )
    }
    Mode(mode) => {
      guard ["inner", "left"].contains(mode) else {
        return (@rabbita.none, view)
      }
      (
        @rabbita.none,
        { ..view, csv_join: { ..view.csv_join, mode, }, error: None, },
      )
    }
    Clear =>
      (
        @rabbita.none,
        {
          ..view,
          generation: view.generation + 1,
          csv_join: { ..empty_csv_join(), adopted: view.csv_join.adopted, },
          error: None,
        },
      )
    UseJoined =>
      try {
        let output = csv_join_output(view.csv_join)
        let generation = view.generation + 1
        (
          @http.post(product_api_url("/api/v1/briefs/csv/intake"))
          .with_json({
            "source": ToJson::to_json(output.source),
            "query": "",
            "column_number": 0,
          })
          .expect_json(
            emit.map(reply => BriefAction(CsvJoin(Joined(generation, reply)))),
          ),
          {
            ..view,
            generation,
            pending: true,
            error: None,
            csv_join: { ..view.csv_join, pending_output: Some(output), },
          },
        )
      } catch {
        error => (@rabbita.none, { ..view, error: Some("\{error}"), })
      }
  }
}

///|
fn csv_join_cancel(view : BriefView) -> BriefView {
  {
    ..view,
    generation: view.generation + 1,
    pending: false,
    csv_join: { ..view.csv_join, pending_output: None, },
  }
}
