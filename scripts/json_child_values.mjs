// Bounded lossless JSON syntax tree for the child-observation product companion.
// Numbers and values remain source spans; JSON.parse only decodes string tokens.
export const JSON_LIMITS = Object.freeze({bytes: 32768, nodes: 10000, depth: 64, pointer: 1024});
const fail = message => { throw new Error(message); };
export const pointerKey = key => key.replaceAll('~', '~0').replaceAll('/', '~1');
function unicode(value) {
  for (let i=0;i<value.length;i++) {
    const unit=value.charCodeAt(i);
    if(unit>=0xd800&&unit<=0xdbff) {const next=value.charCodeAt(++i);if(!(next>=0xdc00&&next<=0xdfff))fail('JSON: unpaired Unicode surrogate is unsupported');}
    else if(unit>=0xdc00&&unit<=0xdfff)fail('JSON: unpaired Unicode surrogate is unsupported');
  }
}
export function pointerTokens(pointer) {
  if(typeof pointer!=='string'||pointer.length>JSON_LIMITS.pointer)fail('JSON Pointer must be a string of at most 1024 units');
  unicode(pointer);
  if(pointer==='')return [];
  if(!pointer.startsWith('/'))fail('JSON Pointer must be empty or begin with /; URI fragments are unsupported');
  return pointer.slice(1).split('/').map(part=>{if(/~(?:[^01]|$)/.test(part))fail('JSON Pointer escape must be ~0 or ~1');return part.replaceAll('~1','/').replaceAll('~0','~');});
}
export function parseJsonValues(bytes) {
  if(!(bytes instanceof Uint8Array)||!bytes.length||bytes.length>JSON_LIMITS.bytes)fail('JSON: UTF-8 input must be 1–32768 bytes');
  let text;
  try{text=new TextDecoder('utf-8',{fatal:true,ignoreBOM:true}).decode(bytes);}catch{fail('JSON: invalid UTF-8');}
  let offset=text[0]==='\uFEFF'?1:0,nodes=0;
  const error=message=>fail(`JSON: ${message} at UTF-16 offset ${offset}`);
  const ws=()=>{while(/[ \r\n\t]/.test(text[offset]||'x'))offset++;};
  const string=()=>{
    const start=offset++;
    while(offset<text.length) {
      const char=text[offset++];
      if(char==='"') {let value;try{value=JSON.parse(text.slice(start,offset));}catch{error('invalid string');}unicode(value);return value;}
      if(char==='\\')offset++;
      else if(char.charCodeAt(0)<32)error('unescaped control character');
    }
    error('unterminated string');
  };
  const value=depth=>{
    ws();if(++nodes>JSON_LIMITS.nodes)error('more than 10000 values');
    const start=offset,children=[];let type;
    const char=text[offset];
    if(char==='{'||char==='[') {
      if(depth>=JSON_LIMITS.depth)error('more than 64 nested containers');
      type=char==='{'?'object':'array';const close=char==='{'?'}':']',keys=new Set();offset++;ws();
      if(text[offset]!==close)while(true) {
        let key=String(children.length),key_start=null,key_end=null;
        if(type==='object') {if(text[offset]!=='"')error('expected object key');key_start=offset;key=string();key_end=offset;if(keys.has(key))error('duplicate JSON key '+JSON.stringify(key));keys.add(key);ws();if(text[offset++]!==':')error('expected colon');}
        children.push({key,key_start,key_end,node:value(depth+1)});ws();if(text[offset]!==',')break;offset++;ws();
      }
      if(text[offset++]!==close)error('expected '+close);
    } else if(char==='"') {type='string';string();}
    else {
      const token=/^(?:true|false|null|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?)/.exec(text.slice(offset))?.[0];
      if(!token)error('expected JSON value');
      type=token==='null'?'null':token==='true'||token==='false'?'boolean':'number';offset+=token.length;
    }
    return {type,start,end:offset,children};
  };
  const root=value(0);ws();if(offset!==text.length)error('unexpected trailing content');
  return {text,root,nodes};
}
// Only a genuinely absent member/index is missing. Traversing a scalar refuses.
export function resolveValue(root, pointer) {
  let node=root;
  for(const token of pointerTokens(pointer)) {
    if(!['object','array'].includes(node.type))fail('JSON Pointer continues through a scalar, not a missing field');
    if(node.type==='array'&&!/^(?:0|[1-9]\d*)$/.test(token))fail('JSON Pointer array index must be canonical and zero-based');
    const child=node.children.find(item=>item.key===token);if(!child)return null;node=child.node;
  }
  return node;
}
