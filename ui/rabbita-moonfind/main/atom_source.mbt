///|
// Local Atom reading projection. Text and URI values remain inert supplied data.
extern "js" fn atom_source_capture(
  name : String,
  hex : String,
  captured_at : String,
) -> String =
  #|(name,hex,captured_at)=>{
  #| try {
  #|  if(!/\.(atom|xml)$/i.test(name)||name.length>140||/[\\/\u0000-\u001f\u007f]/.test(name))throw Error('Choose a safe .atom or .xml filename up to 140 characters.');
  #|  if(hex.length>65536||!/^(?:[0-9a-f]{2})+$/.test(hex))throw Error('Choose one UTF-8 Atom feed up to 32 KiB.');
  #|  const bytes=Uint8Array.from(hex.match(/../g),h=>parseInt(h,16));
  #|  const raw=new TextDecoder('utf-8',{fatal:true,ignoreBOM:true}).decode(bytes);
  #|  const valid=cp=>cp===9||cp===10||cp===13||(cp>=32&&cp<=0xd7ff)||(cp>=0xe000&&cp<=0xfffd)||(cp>=0x10000&&cp<=0x10ffff);
  #|  for(const ch of raw)if(!valid(ch.codePointAt(0)))throw Error('Unsupported XML control character.');
  #|  const text=raw.replace(/^\uFEFF/,'').replace(/\r\n?/g,'\n');let at=0,nodes=0;
  #|  const error=message=>{throw Error(message+' At XML line '+(text.slice(0,at).split('\n').length)+'.');};
  #|  const ws=()=>{while(/[ \t\n\r]/.test(text[at]||'!'))at++;};
  #|  const decode=value=>value.replace(/&([^;]*);|&/g,(whole,key)=>{
  #|   const named={amp:'&',lt:'<',gt:'>',quot:'"',apos:"'"};if(Object.hasOwn(named,key))return named[key];
  #|   if(!key||!/^#(?:[0-9]+|x[0-9a-fA-F]+)$/.test(key))error('Only predefined and numeric XML entities are supported');
  #|   const cp=key[1]==='x'?parseInt(key.slice(2),16):Number(key.slice(1));if(!valid(cp))error('Invalid XML character reference');return String.fromCodePoint(cp);
  #|  });
  #|  const readName=()=>{const m=/^[A-Za-z_][A-Za-z0-9_.-]*(?::[A-Za-z_][A-Za-z0-9_.-]*)?/.exec(text.slice(at));if(!m)error('Expected a supported ASCII XML name');at+=m[0].length;return m[0];};
  #|  const comment=()=>{const end=text.indexOf('-->',at+4);if(end<0||text.slice(at+4,end).includes('--')||text[end-1]==='-')error('Malformed XML comment');at=end+3;};
  #|  if(text.startsWith('<?xml')){
  #|   const end=text.indexOf('?>');if(end<0)error('Unclosed XML declaration');const declaration=text.slice(0,end+2);
  #|   if(!/^<\?xml[ \t\n\r]+version[ \t\n\r]*=[ \t\n\r]*(['"])1\.0\1(?:[ \t\n\r]+encoding[ \t\n\r]*=[ \t\n\r]*(['"])[Uu][Tt][Ff]-8\2)?(?:[ \t\n\r]+standalone[ \t\n\r]*=[ \t\n\r]*(['"])(?:yes|no)\3)?[ \t\n\r]*\?>$/.test(declaration))error('Only XML 1.0 UTF-8 declarations are supported');at=end+2;
  #|  }
  #|  const misc=()=>{for(;;){ws();if(text.startsWith('<!--',at))comment();else break;}};
  #|  const element=(depth,parentNS)=>{
  #|   if(depth>16||++nodes>4096)error('Atom XML exceeds 16 nesting levels or 4,096 elements');
  #|   const line=text.slice(0,at).split('\n').length;if(text[at++]!=='<')error('Expected an XML element');const tag=readName(),attrs=new Map(),ns=new Map(parentNS);
  #|   for(;;){const before=at;ws();if(text.startsWith('/>',at)||text[at]==='>')break;if(before===at)error('Separate XML attributes with whitespace');const key=readName();if(attrs.has(key))error('Duplicate XML attribute');ws();if(text[at++]!=='=')error('Expected attribute value');ws();const quote=text[at++];if(quote!=='"'&&quote!=="'")error('Quote XML attributes');const end=text.indexOf(quote,at);if(end<0)error('Unclosed XML attribute');const value=text.slice(at,end);if(value.includes('<'))error('Unescaped markup in XML attribute');attrs.set(key,decode(value.replace(/[\t\n\r]/g,' ')));at=end+1;}
  #|   for(const [key,value] of attrs){if(key==='xmlns'){if(value==='http://www.w3.org/XML/1998/namespace'||value==='http://www.w3.org/2000/xmlns/')error('Unsupported default namespace');ns.set('',value);}else if(key.startsWith('xmlns:')){const prefix=key.slice(6);if(!value||prefix==='xmlns'||value==='http://www.w3.org/2000/xmlns/'||(prefix==='xml')!==(value==='http://www.w3.org/XML/1998/namespace'))error('Unsupported namespace binding');ns.set(prefix,value);}}
  #|   const expanded=(key,isAttribute=false)=>{if(!key.includes(':'))return (isAttribute?'':(ns.get('')||''))+'|'+key;const [prefix,local]=key.split(':');if(!ns.has(prefix))error('Undeclared XML prefix');return ns.get(prefix)+'|'+local;};
  #|   const attrNames=new Set();for(const key of attrs.keys()){if(key==='xmlns'||key.startsWith('xmlns:'))continue;const full=expanded(key,true);if(attrNames.has(full))error('Duplicate expanded XML attribute');attrNames.add(full);}
  #|   const node={tag,expanded:expanded(tag),attrs,children:[],text:'',line};if(text.startsWith('/>',at)){at+=2;return node;}at++;
  #|   for(;;){
  #|    if(at>=text.length)error('Unclosed XML element');
  #|    if(text.startsWith('</',at)){at+=2;const close=readName();ws();if(close!==tag||text[at++]!=='>')error('Mismatched XML close tag');return node;}
  #|    if(text.startsWith('<!--',at)){comment();continue;}
  #|    if(text.startsWith('<![CDATA[',at)){const end=text.indexOf(']]>',at+9);if(end<0)error('Unclosed CDATA');node.text+=text.slice(at+9,end);at=end+3;continue;}
  #|    if(text.startsWith('<!',at)||text.startsWith('<?',at))error('DTD, entities and processing instructions are unsupported');
  #|    if(text[at]==='<'){node.children.push(element(depth+1,ns));continue;}
  #|    let end=text.indexOf('<',at);if(end<0)end=text.length;const chunk=text.slice(at,end);if(chunk.includes(']]>'))error('CDATA terminator outside CDATA');node.text+=decode(chunk);at=end;
  #|   }
  #|  };
  #|  misc();if(text.startsWith('<!',at)||text.startsWith('<?',at))error('DTD, entities and processing instructions are unsupported');
  #|  const root=element(1,new Map([['xml','http://www.w3.org/XML/1998/namespace']]));misc();if(at!==text.length)error('Unexpected content after Atom root');
  #|  const atom='http://www.w3.org/2005/Atom|';
  #|  if(root.expanded!==atom+'feed')throw Error('Choose an Atom 1.0 feed in the http://www.w3.org/2005/Atom namespace.');
  #|  const children=(parent,tag)=>parent.children.filter(n=>n.expanded===atom+tag);
  #|  const one=(parent,tag)=>{const found=children(parent,tag);if(found.length>1)throw Error('Duplicate '+tag+' field at XML line '+parent.line+'.');return found[0]||null;};
  #|  const leaf=node=>{if(!node)return null;if(node.children.length)throw Error('Nested markup in projected '+node.tag+' is unsupported; use text or escaped HTML.');return node.text;};
  #|  const value=(parent,tag)=>leaf(one(parent,tag));
  #|  const construct=(parent,tag)=>{const n=one(parent,tag);if(!n)return null;const type=n.attrs.get('type')||'text';if(!['text','html'].includes(type))throw Error('Projected '+tag+' supports text or escaped html; XHTML stays unsupported.');return {type,value:leaf(n)};};
  #|  const people=(parent,tag)=>children(parent,tag).map(n=>({name:value(n,'name'),uri:value(n,'uri'),email:value(n,'email')}));
  #|  const links=parent=>children(parent,'link').map(n=>({href:n.attrs.get('href')??null,rel:n.attrs.get('rel')??'alternate',type:n.attrs.get('type')??null,hreflang:n.attrs.get('hreflang')??null,title:n.attrs.get('title')??null,length:n.attrs.get('length')??null}));
  #|  const categories=parent=>children(parent,'category').map(n=>({term:n.attrs.get('term')??null,scheme:n.attrs.get('scheme')??null,label:n.attrs.get('label')??null}));
  #|  const title=construct(root,'title'),feedAuthors=people(root,'author');
  #|  const feed={id:value(root,'id'),title:title?.value??null,title_type:title?.type??null,updated:value(root,'updated'),subtitle:construct(root,'subtitle'),authors:feedAuthors,links:links(root)};
  #|  const entries=children(root,'entry');if(entries.length>128)throw Error('Import at most 128 Atom entries.');
  #|  const known=['id','title','updated','published','summary','author','contributor','link','category'];
  #|  const items=entries.map((entry,index)=>{
  #|   const title=construct(entry,'title'),summary=construct(entry,'summary');
  #|   return {source_item:index+1,source_line:entry.line,id:value(entry,'id'),title:title?.value??null,title_type:title?.type??null,updated:value(entry,'updated'),published:value(entry,'published'),summary:summary?.value??null,summary_type:summary?.type??null,authors:people(entry,'author'),contributors:people(entry,'contributor'),links:links(entry),categories:categories(entry),unprojected_elements:entry.children.filter(n=>!known.some(k=>n.expanded===atom+k)).map(n=>n.tag)};
  #|  });
  #|  const capture={contract_id:'moonfind.local-atom-capture.v1',original_name:name,original_capture_time:captured_at,boundary:'Local supplied Atom metadata and summary text; not authenticated, fetched articles or verified full text. URLs and HTML are inert strings. Dates and relative links retain supplied spelling. Entry authors remain entry-local; feed authors are separate. Content and extensions remain in original XML.',feed,unprojected_feed_elements:root.children.filter(n=>!['id','title','updated','subtitle','author','link','entry'].some(k=>n.expanded===atom+k)).map(n=>n.tag),items};
  #|  const content=new TextEncoder().encode(JSON.stringify(capture,null,2));if(content.length>32768)throw Error('Structured Atom capture exceeds 32 KiB; choose a smaller feed.');
  #|  const toHex=b=>Array.from(b,c=>c.toString(16).padStart(2,'0')).join('');
  #|  const source=(suffix,body,origin)=>({name:name+suffix,origin,captured_at,kind:'local-file',content_hex:body});
  #|  return JSON.stringify({sources:[source('.txt',hex,'User-selected Atom 1.0 feed: '+name+'; exact original XML bytes retained as inert text'),source('.items.json',toHex(content),'Structured local Atom entries from '+name+'; original entry and XML line locators; supplied metadata and summaries only')]});
  #| }catch(error){return JSON.stringify({error:String(error)});}
  #|}

///|
extern "js" fn atom_source_choose(
  capture : (String, String, String) -> String,
  callback : (String) -> Unit,
) -> Unit =
  #|(capture,callback)=>{
  #| let finished=false;const finish=value=>{if(!finished){finished=true;callback(value);}};
  #| try {
  #|  const input=document.createElement('input');input.type='file';input.accept='.atom,.xml';input.multiple=false;
  #|  input.addEventListener('cancel',()=>finish(JSON.stringify({sources:[]})),{once:true});
  #|  input.addEventListener('change',async()=>{try{
  #|   const files=Array.from(input.files||[]);if(!files.length){finish(JSON.stringify({sources:[]}));return;}if(files.length!==1||files[0].size>32768)throw Error('Choose one Atom 1.0 feed up to 32 KiB.');
  #|   const file=files[0],bytes=new Uint8Array(await file.arrayBuffer());
  #|   finish(capture(file.name,Array.from(bytes,b=>b.toString(16).padStart(2,'0')).join(''),new Date().toISOString()));
  #|  }catch(error){finish(JSON.stringify({error:String(error)}));}},{once:true});input.click();
  #| }catch(error){finish(JSON.stringify({error:String(error)}));}
  #|}

///|
fn atom_source_loaded(view : BriefView, raw : String) -> BriefView raise {
  let payload = @json.parse(raw)
  if payload is { "error": String(message), .. } {
    fail(message)
  }
  guard payload is { "sources": sources, .. } else {
    fail("No Atom capture returned.")
  }
  let sources : Array[BriefInputSource] = @json.from_json(sources)
  if sources.is_empty() {
    return view
  }
  guard sources.length() == 2 &&
    sources.all(source => source.content_hex.length() <= 65536) else {
    fail(
      "Atom import needs its unchanged original and structured entries, each up to 32 KiB.",
    )
  }
  let combined = view.draft.sources + sources
  guard combined.length() <= 8 &&
    combined.fold(init=0, (sum, source) => sum + source.content_hex.length()) <=
    262144 else {
    fail(
      "Atom import needs two free source slots and must fit the 128 KiB dossier limit.",
    )
  }
  let source = sources[1]
  let table = json_evidence_table(source, "/items")
  {
    ..brief_edited(view, { ..view.draft, sources: combined, }),
    json_evidence: {
      ..empty_json_evidence_view(),
      slot: combined.length(),
      source: Some(source),
      pointer: "/items",
      table: Some(table),
      csv_fields: "[\"/title\",\"/updated\",\"/links/0/href\",\"/authors/0/name\"]",
    },
  }
}
