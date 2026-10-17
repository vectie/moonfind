///|
// Synchronous SHA-256 of bounded original UTF-8 bytes for response binding.
// This uses no provider, Node API or new dependency; tested against Node crypto.
extern "js" fn csv_source_digest(hex : String) -> String =
  #|hex => {
  #| if(typeof hex!=='string'||hex.length>65536||hex.length%2||!/^[0-9a-f]*$/.test(hex))return '';
  #| const size=hex.length/2,bytes=new Uint8Array(Math.ceil((size+9)/64)*64);
  #| for(let i=0;i<size;i++)bytes[i]=parseInt(hex.slice(i*2,i*2+2),16);
  #| bytes[size]=128;const view=new DataView(bytes.buffer);view.setUint32(bytes.length-4,size*8,false);
  #| const k=[0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2];
  #| const hash=[0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19],w=new Uint32Array(64),rotr=(v,n)=>(v>>>n)|(v<<(32-n));
  #| for(let start=0;start<bytes.length;start+=64){
  #|   for(let i=0;i<16;i++)w[i]=view.getUint32(start+i*4,false);
  #|   for(let i=16;i<64;i++){const x=w[i-15],y=w[i-2],s0=rotr(x,7)^rotr(x,18)^(x>>>3),s1=rotr(y,17)^rotr(y,19)^(y>>>10);w[i]=(w[i-16]+s0+w[i-7]+s1)>>>0;}
  #|   let [a,b,c,d,e,f,g,h]=hash;
  #|   for(let i=0;i<64;i++){const s1=rotr(e,6)^rotr(e,11)^rotr(e,25),ch=(e&f)^(~e&g),t1=(h+s1+ch+k[i]+w[i])>>>0,s0=rotr(a,2)^rotr(a,13)^rotr(a,22),maj=(a&b)^(a&c)^(b&c),t2=(s0+maj)>>>0;h=g;g=f;f=e;e=(d+t1)>>>0;d=c;c=b;b=a;a=(t1+t2)>>>0;}
  #|   for(const [i,value] of [a,b,c,d,e,f,g,h].entries())hash[i]=(hash[i]+value)>>>0;
  #| }
  #| return 'sha256:'+hash.map(value=>value.toString(16).padStart(8,'0')).join('');
  #|}

///|
fn csv_validate_selection(
  view : BriefView,
  sources : Array[BriefInputSource],
) -> Unit raise {
  guard view.csv.intake is Some(intake) &&
    sources.length() == 2 &&
    sources[0] == intake.source else {
    fail("CSV selection reply does not match the current source.")
  }
  guard view.csv.selected.all(number => {
      intake.rows.any(row => row.record_number == number)
    }) &&
    view.csv.columns.all(number => {
      number >= 1 && number <= intake.columns.length()
    }) else {
    fail("CSV projection refers to a changed source record or column.")
  }
  let companion = sources[1]
  guard companion.name == "csv-selection.json" &&
    companion.origin == "Selected CSV records from " + intake.source.name &&
    companion.captured_at == intake.source.captured_at &&
    companion.kind == "pasted-text" &&
    companion.content_hex.length() <= 65536 &&
    !csv_source_digest(companion.content_hex).is_empty() else {
    fail(
      "CSV selection companion metadata or bytes do not match the requested projection.",
    )
  }
  let payload = @json.parse(brief_source_preview(companion.content_hex))
  let selection : CsvSelection = @json.from_json(payload)
  let positions = Array::makei(intake.columns.length(), i => i).filter(i => {
    view.csv.columns.contains(i + 1)
  })
  let rows = intake.rows
    .filter(row => view.csv.selected.contains(row.record_number))
    .map(row => CsvRow::{
      record_number: row.record_number,
      values: positions.map(i => row.values[i]),
    })
  let expected : Json = {
    "contract_id": "moonfind.csv-selection.v1",
    "source_name": intake.source.name.to_json(),
    "source_digest": csv_source_digest(intake.source.content_hex).to_json(),
    "source_row_count": intake.total_count.to_json(),
    "column_numbers": positions.map(i => i + 1).to_json(),
    "columns": positions.map(i => intake.columns[i]).to_json(),
    "rows": rows.to_json(),
  }
  guard payload == expected &&
    !positions.is_empty() &&
    !rows.is_empty() &&
    selection.contract_id == "moonfind.csv-selection.v1" &&
    selection.source_name == intake.source.name &&
    selection.source_digest == csv_source_digest(intake.source.content_hex) &&
    selection.source_row_count == intake.total_count &&
    selection.column_numbers == positions.map(i => i + 1) &&
    selection.columns == positions.map(i => intake.columns[i]) &&
    selection.rows == rows else {
    fail(
      "CSV selection companion does not match the exact requested source, rows and columns. Your selections are unchanged.",
    )
  }
}
