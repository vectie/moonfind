///|
// A bounded parser for saved Netscape bookmark exports, never an HTML document
// renderer. It has no DOM, URL, network, script or entity-expansion capability.
extern "js" fn bookmark_source_capture(
  name : String,
  hex : String,
  captured_at : String,
) -> String =
  #|(name,hex,captured_at)=>{
  #| try {
  #|  if(!/\.html?$/i.test(name)||!name.trim())throw Error('Choose a saved .html or .htm bookmark export.');
  #|  if(hex.length>65536||! /^(?:[0-9a-fA-F]{2})*$/.test(hex))throw Error('Use a UTF-8 bookmark export up to 32 KiB.');
  #|  const original=new TextDecoder('utf-8',{fatal:true,ignoreBOM:true}).decode(Uint8Array.from(hex.match(/../g)||[],b=>parseInt(b,16)));
  #|  const text=original.replace(/^\uFEFF/,'').replace(/\r\n?/g,'\n');
  #|  if(text.includes('\u0000'))throw Error('NUL characters are unsupported in bookmark exports.');
  #|  let at=0,count=0;const tokens=[];
  #|  const error=message=>{throw Error(message+' Near HTML line '+(text.slice(0,at).split('\n').length)+'.');};
  #|  const decode=value=>value.replace(/&(#(?:[xX][0-9a-fA-F]+|[0-9]+)|[A-Za-z][A-Za-z0-9]*);/g,(raw,key)=>{
  #|   const named={amp:'&',lt:'<',gt:'>',quot:'"',apos:"'",nbsp:'\u00a0'};
  #|   if(Object.hasOwn(named,key))return named[key];
  #|   if(key[0]!=='#')error('Unsupported named HTML entity '+raw);
  #|   const cp=/^#[xX]/.test(key)?parseInt(key.slice(2),16):Number(key.slice(1));
  #|   if(!Number.isInteger(cp)||cp===0||cp>0x10ffff||(cp>=0xd800&&cp<=0xdfff))error('Invalid numeric HTML entity');
  #|   return String.fromCodePoint(cp);
  #|  });
  #|  const ws=()=>{while(/[ \t\n\r]/.test(text[at]||'!'))at++;};
  #|  ws();if(!/^<!DOCTYPE[ \t\n]+NETSCAPE-Bookmark-file-1[ \t\n]*>/i.test(text.slice(at)))error('Expected the Netscape bookmark-export doctype');
  #|  at+=/^<!DOCTYPE[ \t\n]+NETSCAPE-Bookmark-file-1[ \t\n]*>/i.exec(text.slice(at))[0].length;
  #|  while(at<text.length){
  #|   if(++count>4096)error('Bookmark export exceeds 4,096 tokens');
  #|   const line=text.slice(0,at).split('\n').length;
  #|   if(text.startsWith('<!--',at)){const end=text.indexOf('-->',at+4);if(end<0)error('Unclosed HTML comment');at=end+3;continue;}
  #|   if(text[at]!=='<'){let end=text.indexOf('<',at);if(end<0)end=text.length;tokens.push({kind:'text',value:decode(text.slice(at,end)),line});at=end;continue;}
  #|   at++;let close=false;if(text[at]==='/'){close=true;at++;}
  #|   const match=/^[A-Za-z][A-Za-z0-9]*/.exec(text.slice(at));if(!match)error('Unsupported declaration or malformed HTML tag');
  #|   const tag=match[0].toUpperCase();at+=match[0].length;const attrs=new Map();
  #|   if(!['META','TITLE','H1','DL','P','DT','DD','H3','A','HR'].includes(tag))error('Unsupported bookmark tag '+tag);
  #|   for(;;){
  #|    const start=at;ws();if(text[at]==='>'||text.startsWith('/>',at))break;
  #|    if(close||start===at)error('Malformed HTML tag');
  #|    const keyMatch=/^[A-Za-z_][A-Za-z0-9_:.-]*/.exec(text.slice(at));if(!keyMatch)error('Malformed HTML attribute');
  #|    const key=keyMatch[0].toUpperCase();at+=keyMatch[0].length;if(attrs.has(key))error('Duplicate HTML attribute '+key);const keyEnd=at;ws();
  #|    let value='';if(text[at]==='='){at++;ws();const quote=text[at++];if(quote!=='"'&&quote!=="'")error('Use quoted bookmark attributes');const end=text.indexOf(quote,at);if(end<0)error('Unclosed HTML attribute');value=decode(text.slice(at,end));if(value.includes('\u0000'))error('NUL in HTML attribute');at=end+1;}else{at=keyEnd;} // Preserve the next attribute's separator after valueless lookahead.
  #|    attrs.set(key,value);
  #|   }
  #|   const self=text.startsWith('/>',at);at+=self?2:1;if(self&&!['META','HR'].includes(tag))error('Unsupported self-closing bookmark tag');
  #|   tokens.push({kind:close?'close':'open',tag,attrs,line});
  #|  }
  #|  let pos=0;const folders=[],bookmarks=[];
  #|  const skip=()=>{while(pos<tokens.length&&((tokens[pos].kind==='text'&&!tokens[pos].value.trim())||tokens[pos].tag==='P'))pos++;};
  #|  const label=tag=>{let value='';while(pos<tokens.length&&tokens[pos].kind==='text')value+=tokens[pos++].value;const end=tokens[pos++];if(!end||end.kind!=='close'||end.tag!==tag)throw Error('Expected plain text and closing '+tag+' tag. Escaped markup is supported; embedded elements are not.');return value;};
  #|  const description=()=>{let value='';while(pos<tokens.length&&tokens[pos].kind==='text')value+=tokens[pos++].value;if(tokens[pos]?.kind==='close'&&tokens[pos].tag==='DD')pos++;return value.replace(/\n[ \t]*$/,'');};
  #|  skip();while(pos<tokens.length&&['META','TITLE','H1'].includes(tokens[pos].tag)){
  #|   const token=tokens[pos++];if(token.kind!=='open')throw Error('Unexpected bookmark header close tag.');
  #|   if(token.tag==='META'){const charset=token.attrs.get('CHARSET');const content=token.attrs.get('CONTENT')||'';if((charset&&!/^utf-8$/i.test(charset))||(/charset\s*=/i.test(content)&&! /charset\s*=\s*utf-8(?:\s|;|$)/i.test(content)))throw Error('Only UTF-8 bookmark exports are supported.');}
  #|   else label(token.tag);skip();
  #|  }
  #|  const list=(path,folderLines,folderIds,depth)=>{
  #|   if(depth>16)throw Error('Bookmark folders exceed 16 levels.');
  #|   const start=tokens[pos++];if(!start||start.kind!=='open'||start.tag!=='DL')throw Error('Expected a bookmark folder list.');
  #|   let target=null;
  #|   for(;;){
  #|    skip();const token=tokens[pos++];if(!token)throw Error('Unclosed bookmark folder list.');
  #|    if(token.kind==='close'&&token.tag==='DL')return;
  #|    if(token.kind==='close'&&token.tag==='DT')continue;
  #|    if(token.kind==='open'&&token.tag==='DD'){if(!target||target.description!==null)throw Error('Description needs one preceding bookmark or folder.');target.description=description();continue;}
  #|    if(token.kind==='open'&&token.tag==='HR'){target=null;continue;}
  #|    if(token.kind!=='open'||token.tag!=='DT')throw Error('Expected a bookmark or folder entry at HTML line '+token.line+'.');
  #|    skip();const entry=tokens[pos++];if(!entry||entry.kind!=='open'||!['H3','A','HR'].includes(entry.tag))throw Error('Expected A or H3 after DT.');
  #|    if(entry.tag==='HR'){target=null;continue;}
  #|    const title=label(entry.tag),attrs=entry.attrs;
  #|    const base={source_line:entry.line,title,folder_path:path.slice(),folder_source_lines:folderLines.slice(),folder_ids:folderIds.slice(),add_date:attrs.get('ADD_DATE')??null,last_modified:attrs.get('LAST_MODIFIED')??null,description:null};
  #|    if(entry.tag==='A'){
  #|     if(!attrs.has('HREF')||!attrs.get('HREF').trim())throw Error('Bookmark at HTML line '+entry.line+' needs a nonempty HREF.');
  #|     target={source_bookmark:bookmarks.length+1,...base,url:attrs.get('HREF'),tags:attrs.get('TAGS')??null,last_visit:attrs.get('LAST_VISIT')??null,unprojected_attributes:Array.from(attrs.keys()).filter(k=>!['HREF','ADD_DATE','LAST_MODIFIED','TAGS','LAST_VISIT'].includes(k))};
  #|     bookmarks.push(target);if(bookmarks.length>128)throw Error('Import at most 128 bookmarks.');
  #|    }else{
  #|     const folder={source_folder:folders.length+1,...base,path:[...path,title],unprojected_attributes:Array.from(attrs.keys()).filter(k=>!['ADD_DATE','LAST_MODIFIED'].includes(k))};folders.push(folder);if(folders.length>128)throw Error('Import at most 128 folders.');
  #|     skip();if(tokens[pos]?.kind==='close'&&tokens[pos].tag==='DT'){pos++;skip();}
  #|     if(tokens[pos]?.kind==='open'&&tokens[pos].tag==='DD'){pos++;folder.description=description();skip();}
  #|     list(folder.path,[...folderLines,entry.line],[...folderIds,folder.source_folder],depth+1);target=null;
  #|    }
  #|   }
  #|  };
  #|  list([],[],[],0);skip();if(pos!==tokens.length)throw Error('Unexpected content after bookmark list.');
  #|  const capture={contract_id:'moonfind.local-bookmark-capture.v1',original_name:name,original_capture_time:captured_at,boundary:'Supplied local bookmark metadata, not destination contents or authenticated provenance. URLs and HTML text are inert. Folder paths are ordered title arrays; duplicate URLs and equal-named folders remain separate records. Dates retain supplied strings without validation or conversion. Unprojected attributes remain only in the exact original.',folders,bookmarks};
  #|  const bytes=new TextEncoder().encode(JSON.stringify(capture,null,2));if(bytes.length>32768)throw Error('Structured bookmark capture exceeds 32 KiB; use a smaller supplied export.');
  #|  const toHex=bytes=>Array.from(bytes,b=>b.toString(16).padStart(2,'0')).join('');
  #|  const source=(suffix,body,origin)=>({name:name+suffix,origin,captured_at,kind:'local-file',content_hex:body});
  #|  return JSON.stringify({sources:[source('.txt',hex,'User-selected bookmark export: '+name+'; exact original HTML bytes retained as inert text'),source('.bookmarks.json',toHex(bytes),'Structured bookmark reading queue from '+name+'; supplied titles, folder paths, URLs and descriptions only; destinations not read')]});
  #| }catch(error){return JSON.stringify({error:String(error)});}
  #|}

///|
extern "js" fn bookmark_source_choose(
  capture : (String, String, String) -> String,
  done : (String) -> Unit,
) -> Unit =
  #|(capture,done)=>{
  #| let finished=false;const finish=value=>{if(!finished){finished=true;done(value);}};
  #| try {
  #|  const input=document.createElement('input');input.type='file';input.accept='.html,.htm';input.multiple=false;
  #|  input.addEventListener('cancel',()=>finish(JSON.stringify({sources:[]})),{once:true});
  #|  input.addEventListener('change',async()=>{try{
  #|   const files=Array.from(input.files||[]);if(!files.length){finish(JSON.stringify({sources:[]}));return;}if(files.length!==1||files[0].size>32768)throw Error('Choose one bookmark export up to 32 KiB.');
  #|   const file=files[0],bytes=new Uint8Array(await file.arrayBuffer());
  #|   finish(capture(file.name,Array.from(bytes,b=>b.toString(16).padStart(2,'0')).join(''),new Date().toISOString()));
  #|  }catch(error){finish(JSON.stringify({error:String(error)}));}},{once:true});input.click();
  #| }catch(error){finish(JSON.stringify({error:String(error)}));}
  #|}

///|
fn bookmark_source_loaded(view : BriefView, raw : String) -> BriefView raise {
  let payload = @json.parse(raw)
  if payload is { "error": String(message), .. } {
    fail(message)
  }
  guard payload is { "sources": sources, .. } else {
    fail("No bookmark capture returned.")
  }
  let sources : Array[BriefInputSource] = @json.from_json(sources)
  if sources.is_empty() {
    return view
  }
  guard sources.length() == 2 &&
    sources.all(source => source.content_hex.length() <= 65536) else {
    fail(
      "Bookmark import needs its original and structured queue, each up to 32 KiB.",
    )
  }
  let combined = view.draft.sources + sources
  guard combined.length() <= 8 &&
    combined.fold(init=0, (sum, source) => sum + source.content_hex.length()) <=
    262144 else {
    fail(
      "Bookmark import needs two free source slots and must fit the 128 KiB dossier limit.",
    )
  }
  let source = sources[1]
  let table = json_evidence_table(source, "/bookmarks")
  {
    ..brief_edited(view, { ..view.draft, sources: combined, }),
    json_evidence: {
      ..empty_json_evidence_view(),
      slot: combined.length(),
      source: Some(source),
      pointer: "/bookmarks",
      table: Some(table),
      csv_fields: "[\"/title\",\"/url\",\"/folder_path\",\"/add_date\",\"/description\"]",
    },
  }
}
