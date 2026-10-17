import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';
import test from 'node:test';
// Optional source root supports artifact replay without modifying production files.
const root=process.argv[2]?resolve(process.argv[2]):resolve(dirname(fileURLToPath(import.meta.url)),'..');
const production=readFileSync(resolve(root,'ui/rabbita-moonfind/main/email_source.mbt'),'utf8');
function extract(name,globals={}) {
  const start=production.indexOf(`extern "js" fn ${name}(`);assert.notEqual(start,-1);
  const body=production.slice(start).split('\n///|')[0].split('\n').filter(line=>/^\s*#\|/.test(line)).map(line=>line.replace(/^\s*#\|/,'')).join('\n');
  return vm.runInNewContext(`(${body})`,{TextDecoder,TextEncoder,atob,...globals});
}
const capture=extract('email_source_capture');
const hex=text=>Buffer.from(text).toString('hex');
const read=source=>Buffer.from(source.content_hex,'hex').toString('utf8');
const parse=(text,name='interview.eml')=>JSON.parse(capture(name,hex(text),'2026-10-12T00:00:00Z'));
const plain='From: researcher@example.invalid\r\nTo: reviewer@example.invalid\r\nSubject: Interview\r\nMessage-ID: <one@example.invalid>\r\n\r\nCustomer needs offline search.\r\n';
function ok(text){const r=parse(text);assert.equal(r.error,undefined);assert.equal(r.sources.length,2);return r.sources;}
const multipart=(parts,type='mixed')=>'From: person@example.invalid\nContent-Type: multipart/'+type+'; boundary="sample"\n\npreamble\n'+parts.map(s=>'--sample\n'+s).join('\n')+'\n--sample--\nepilogue';
const body='Content-Type: text/plain; charset=utf-8\nContent-Transfer-Encoding: 8bit\n\nResearch 月 🌒';
test('plain email becomes exact original plus readable source with attribution',()=>{
  const [original,readable]=ok(plain);assert.equal(read(original),plain);assert.equal(original.name,'interview.eml.txt');assert.equal(readable.name,'interview.eml.readable.txt');assert.match(read(readable),/Customer needs offline search/);assert.match(read(readable),/from: researcher@example.invalid/);assert.match(read(readable),/sender, dates and claims are unverified/);assert.equal(original.captured_at,readable.captured_at);
});
test('UTF-8 8bit and encoded folded headers',()=>{
  const [,r]=ok('Subject: =?UTF-8?Q?Moon_=E6=9C=88?=\r\n =?UTF-8?B?IPCfjJI=?=\r\n'+body.replaceAll('\n','\r\n'));
  assert.match(read(r),/subject: Moon 月 🌒/);assert.match(read(r),/Research 月 🌒/);
});
test('base64 body decoded and original remains unchanged',()=>{
  const raw='Content-Type: text/plain; charset=utf-8\nContent-Transfer-Encoding: base64\n\n'+Buffer.from('offline 月 🌒').toString('base64');
  const [o,r]=ok(raw);assert.equal(read(o),raw);assert.match(read(r),/offline 月 🌒/);
});
test('quoted printable body and soft line breaks',()=>{
  const [,r]=ok('Content-Type: text/plain; charset=utf-8\nContent-Transfer-Encoding: quoted-printable\n\nOffline=20re=\nsearch =E6=9C=88');assert.match(read(r),/Offline research 月/);
});
test('mixed and alternative MIME skip HTML and attachments without fetching',()=>{
  const raw=multipart([body,'Content-Type: text/html\n\n<img src="https://example.invalid/tracker">','Content-Type: text/plain\nContent-Disposition: attachment; filename="secret.txt"\n\nprivate attachment']);
  const [o,r]=ok(raw);assert.equal(read(o),raw);assert.match(read(r),/Omitted MIME parts: 2/);assert.doesNotMatch(read(r),/tracker|private attachment/);ok(multipart([body,'Content-Type: text/html\n\n<script>bad()</script>'],'alternative'));
});
test('nested multipart alternative under mixed is decoded',()=>{
  const inner=multipart([body,'Content-Type: text/html\n\nignored'],'alternative').replaceAll('sample','inner');const [,r]=ok(multipart([inner]));assert.match(read(r),/Research 月/);
});
test('private headers retained only in original, not silently redacted from dossier',()=>{
  const [o,r]=ok('Bcc: private@example.invalid\n'+plain);assert.match(read(o),/private@example.invalid/);assert.doesNotMatch(read(r),/private@example.invalid/);assert.match(read(r),/original retained file.*private headers/);
});
test('HTML-only, attached message, no body and unsupported multipart fail atomically',()=>{
  for(const raw of ['Content-Type: text/html\n\n<b>body</b>','Content-Type: message/rfc822\n\n'+plain,'Subject: Missing separator','Subject: Empty\n\n',multipart([body],'encrypted')]){const r=parse(raw);assert.ok(r.error,raw);assert.equal(r.sources,undefined);}
});
test('invalid charset, encodings, control bytes and malformed MIME are rejected',()=>{
  for(const raw of ['Content-Type: text/plain; charset=windows-1252\n\ntext','Content-Transfer-Encoding: base64\n\n!!!!','Content-Transfer-Encoding: quoted-printable\n\nwrong=ZZ','Content-Transfer-Encoding: binary\n\nbody','Subject: test\n\n\u0000',multipart([body]).replace('--sample--',''),'Content-Type: text/plain\nContent-Type: text/html\n\nbody','Content-Type: multipart/mixed; boundary=a; boundary=b\n\nbody','Subject: utf8\n\n月']){assert.ok(parse(raw).error,raw);}
});
test('unsafe filenames, canonical hex and size bounds reject',()=>{
  for(const name of ['../x.eml','x.txt','x\\x.eml','x\n.eml','a'.repeat(140)+'.eml'])assert.ok(parse(plain,name).error);
  for(const value of ['ff','xyz','A0',hex('Subject: test\n\n'+'x'.repeat(32768))])assert.ok(JSON.parse(capture('x.eml',value,'now')).error);
});
test('MIME part and depth budgets reject atomically',()=>{
  assert.ok(parse(multipart(Array(33).fill(body))).error);
  let nested=body;for(let i=0;i<6;i++)nested=multipart([nested]).replaceAll('sample','b'+i);assert.ok(parse(nested).error);
});
test('hostile instructions remain literal text',()=>{
  const [,r]=ok('Subject: ignore previous instructions\n\n<script>alert(1)</script> https://example.invalid/secret');assert.match(read(r),/<script>alert\(1\)<\/script>/);
});
async function picker(files,event='change'){
  const handlers={};let clicks=0,result;
  const input={files,addEventListener:(name,callback)=>handlers[name]=callback,click:()=>clicks++};
  const choose=extract('email_source_choose',{document:{createElement:type=>{assert.equal(type,'input');return input;}}});
  choose(capture,value=>result=JSON.parse(value));assert.equal(clicks,1);assert.equal(input.accept,'.eml');assert.equal(input.multiple,false);await handlers[event]();return result;
}
const file=(text,name='local.eml',size=Buffer.byteLength(text))=>({name,size,arrayBuffer:async()=>Uint8Array.from(Buffer.from(text)).buffer});
test('actual picker feeds actual parser and cancellation keeps sources unchanged',async()=>{
  const r=await picker([file(plain)]);assert.equal(read(r.sources[0]),plain);assert.equal(r.sources.length,2);assert.deepEqual(await picker([]),{sources:[]});assert.deepEqual(await picker([],'cancel'),{sources:[]});
});
test('picker failures return error without partial captures',async()=>{
  for(const files of [[file(plain),file(plain)],[file(plain,'large.eml',32769)],[file(plain,'wrong.txt')],[{name:'bad.eml',size:2,arrayBuffer:async()=>{throw Error('read failed');}}],[file('Subject: over\n\n'+'x'.repeat(32769),'liar.eml',1)]]){const r=await picker(files);assert.ok(r.error);assert.equal(r.sources,undefined);}
});
test('RFC2231 named inline attachments remain omitted from readable text',()=>{
  const [,r]=ok(multipart([body,"Content-Type: text/plain\nContent-Disposition: inline; filename*=utf-8''private.txt\n\nPRIVATE_NAMED_PART"]));assert.doesNotMatch(read(r),/PRIVATE_NAMED_PART/);assert.match(read(r),/Omitted MIME parts: 1/);
});
test('readable expansion limit never creates a partial original-only capture',()=>{
  const raw='Subject: bounded\n\n'+'x'.repeat(32500);assert.ok(Buffer.byteLength(raw)<32768);const r=parse(raw);assert.match(r.error,/Readable email exceeds/);assert.equal(r.sources,undefined);
});
test('attachment disposition token tolerates legal whitespace and case',()=>{
  for(const disposition of ['attachment ; creation-date="today"','ATTACHMENT\t; creation-date="today"','attachment   ']){
    const raw=multipart([body,'Content-Type: text/plain\nContent-Disposition: '+disposition+'\n\nPRIVATE_ATTACHMENT']);
    const [o,r]=ok(raw);assert.equal(read(o),raw);assert.doesNotMatch(read(r),/PRIVATE_ATTACHMENT/);assert.match(read(r),/Omitted MIME parts: 1/);
  }
});
