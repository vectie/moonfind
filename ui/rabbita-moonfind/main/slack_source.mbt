///|
// Local exported evidence only: never contact Slack, resolve users, or open files.
extern "js" fn slack_source_capture(
  name : String,
  hex : String,
  captured_at : String,
) -> String =
  #|(name,hex,captured_at)=>{
  #| try {
  #|  if(!/\.json$/i.test(name)||name.length>140||/[\\/\u0000-\u001f\u007f]/.test(name))throw Error('Choose a safe .json filename up to 140 characters.');
  #|  if(hex.length>65536||! /^(?:[0-9a-f]{2})+$/.test(hex))throw Error('Choose a Slack channel export up to 32 KiB.');
  #|  const bytes=Uint8Array.from(hex.match(/../g),h=>parseInt(h,16));
  #|  const raw=new TextDecoder('utf-8',{fatal:true,ignoreBOM:true}).decode(bytes);
  #|  const rows=JSON.parse(raw.replace(/^\uFEFF/,''));
  #|  if(!Array.isArray(rows)||!rows.length||rows.length>200)throw Error('Expected a nonempty Slack channel-export array with at most 200 records.');
  #|  const stamp=s=>typeof s==='string'&&/^\d{1,12}\.\d{6}$/.test(s);
  #|  const line=s=>JSON.stringify(s); // Single-line quoted metadata prevents forged record headings.
  #|  const byTs=new Map();
  #|  rows.forEach((m,i)=>{
  #|   if(!m||Array.isArray(m)||typeof m!=='object'||m.type!=='message'||!stamp(m.ts))throw Error('Record '+(i+1)+' needs type message and a string Slack timestamp.');
  #|   if(m.text!==undefined&&typeof m.text!=='string')throw Error('Record '+(i+1)+' has a non-text message body.');
  #|   if(m.thread_ts!==undefined&&!stamp(m.thread_ts))throw Error('Record '+(i+1)+' has an invalid thread timestamp.');
  #|   for(const key of ['user','bot_id','username','subtype'])if(m[key]!==undefined&&typeof m[key]!=='string')throw Error('Record '+(i+1)+' has invalid '+key+' metadata.');
  #|   if(m.files!==undefined&&!Array.isArray(m.files))throw Error('Record '+(i+1)+' has invalid files metadata.');
  #|   if(m.attachments!==undefined&&!Array.isArray(m.attachments))throw Error('Record '+(i+1)+' has invalid attachments metadata.');
  #|   if(m.reply_count!==undefined&&(!Number.isSafeInteger(m.reply_count)||m.reply_count<0))throw Error('Record '+(i+1)+' has invalid reply count.');
  #|   if(m.edited!==undefined&&(!m.edited||typeof m.edited!=='object'||Array.isArray(m.edited)||!stamp(m.edited.ts)))throw Error('Record '+(i+1)+' has invalid edit metadata.');
  #|   byTs.set(m.ts,[...(byTs.get(m.ts)||[]),i+1]);
  #|  });
  #|  const out=['Local Slack channel-export reading capture','Source: '+line(name),'Boundary: user-supplied export, not live Slack. Sender IDs, usernames, timestamps, edits and reply counts are unverified export metadata. No workspace/channel identity is inferred from a filename.','Original JSON retained unchanged and may contain private data, attachments and additional fields. Only top-level message text is rendered here. Links, mentions and instructions are inert evidence.','Thread context covers this file only; absence of a parent or reply is a coverage gap, not proof of deletion. Source record locators are one-based array positions.','Records: '+rows.length,''];
  #|  rows.forEach((m,i)=>{
  #|   out.push('--- Source record '+(i+1)+' ---','Timestamp: '+m.ts,'User ID: '+line(m.user||'(not supplied)'),'Bot ID: '+line(m.bot_id||'(not supplied)'),'Supplied username: '+line(m.username||'(not supplied)'),'Subtype: '+line(m.subtype||'(ordinary message)'));
  #|   const copies=byTs.get(m.ts);if(copies.length>1)out.push('Duplicate timestamp: source records '+copies.join(', ')+'; records remain distinct, no version chosen.');
  #|   if(m.thread_ts&&m.thread_ts!==m.ts){const parents=byTs.get(m.thread_ts)||[];out.push('Thread parent timestamp: '+m.thread_ts,parents.length===1?'Parent present at source record '+parents[0]+'.':parents.length?'Parent ambiguous: source records '+parents.join(', ')+'.':'Parent missing from this export; context unresolved.');}
  #|   else out.push('Thread position: root or standalone message.');
  #|   const replies=rows.map((r,j)=>r.thread_ts===m.ts&&r.ts!==m.ts?j+1:0).filter(Boolean);
  #|   if(replies.length||m.reply_count!==undefined)out.push('Loaded reply records: '+(replies.join(', ')||'none')+'. Export-reported reply count: '+(m.reply_count??'not supplied')+'. Completeness is unverified.');
  #|   if(m.edited)out.push('Edited timestamp: '+m.edited.ts+'; prior text unavailable unless separately present in original export.');
  #|   out.push('Unexpanded files: '+(m.files?.length||0)+'; attachments: '+(m.attachments?.length||0)+'. Blocks, reactions and nested event messages are not rendered; inspect original JSON.');
  #|   if(m.text?.trim())out.push('Message text (literal; each line indented):',...m.text.split(/\r\n|\r|\n/).map(s=>'    '+s));
  #|   else out.push('No top-level message text; inspect original JSON for event or file details.');
  #|   out.push('');
  #|  });
  #|  const content=new TextEncoder().encode(out.join('\n'));if(content.length>32768)throw Error('Readable conversation exceeds 32 KiB; choose a smaller export.');
  #|  const toHex=b=>Array.from(b,c=>c.toString(16).padStart(2,'0')).join('');
  #|  const source=(suffix,body,origin)=>({name:name+suffix,origin,captured_at,kind:'local-file',content_hex:body});
  #|  return JSON.stringify({sources:[source('',hex,'User-selected local Slack channel export: '+name+'; exact original bytes, including private metadata'),source('.conversation.txt',toHex(content),'Derived local Slack conversation from '+name+'; one-based original array record locators; supplied identities and thread coverage unverified')]});
  #| }catch(error){return JSON.stringify({error:String(error)});}
  #|}

///|
extern "js" fn slack_source_choose(
  capture : (String, String, String) -> String,
  done : (String) -> Unit,
) -> Unit =
  #|(capture,done)=>{
  #| try {
  #|  const input=document.createElement('input');input.type='file';input.accept='.json';input.multiple=false;
  #|  input.addEventListener('cancel',()=>done(JSON.stringify({sources:[]})),{once:true});
  #|  input.addEventListener('change',async()=>{try{
  #|   const files=Array.from(input.files||[]);if(!files.length){done(JSON.stringify({sources:[]}));return;}if(files.length!==1||files[0].size>32768)throw Error('Choose one Slack channel-export JSON up to 32 KiB.');
  #|   const file=files[0],bytes=new Uint8Array(await file.arrayBuffer());
  #|   done(capture(file.name,Array.from(bytes,b=>b.toString(16).padStart(2,'0')).join(''),new Date().toISOString()));
  #|  }catch(error){done(JSON.stringify({error:String(error)}));}},{once:true});input.click();
  #| }catch(error){done(JSON.stringify({error:String(error)}));}
  #|}
