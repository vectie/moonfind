import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,existsSync,symlinkSync} from 'node:fs';
import {join,resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import vm from 'node:vm';
import {createAppendBundle as build} from './csv_append.mjs';
import {parseCsv,parsePlan,digest} from './csv_bibliography.mjs';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const evidence=process.env.MOONFIND_APPEND_EVIDENCE;
assert.ok(evidence,'Set MOONFIND_APPEND_EVIDENCE to a new retained evidence directory');mkdirSync(evidence,{recursive:true});
const input=()=>[{name:'east.csv',bytes:Buffer.from('person,answer,private\r\n0001,"hello, 月",secret\r\n0001,"line\nanswer",hidden\r\n')},{name:'west.csv',bytes:Buffer.from('response,id\n=1+1,0001\n,0002\n')}];
const plan=()=>({contract_id:'moonfind.csv-append-plan.v1',columns:['respondent','response'],sources:[{id:'east',mapping:['person','answer'],origin:'Synthetic east survey',captured_at:'2026-10-14',restrictions:'Synthetic; retain locally',access:'permitted'},{id:'west',mapping:['id','response'],origin:'Synthetic west survey',captured_at:'2026-10-14',restrictions:'Synthetic; retain locally',access:'permitted'}]});
test('mapped append retains duplicates, empty strings, original bytes and per-row source identity',()=>{
 const ins=input(),p=plan(),result=build(ins,p),prov=JSON.parse(result.files['provenance.json']);
 assert.equal(result.preview.output_count,4);
 assert.deepEqual(parseCsv(result.files['appended.csv']).rows.map(r=>r.values),[['east','2','0001','hello, 月'],['east','3','0001','line\nanswer'],['west','2','0001','=1+1'],['west','3','0002','']]);
 assert.deepEqual(prov.row_map,[[2,1,2],[3,1,3],[4,2,2],[5,2,3]]);
 assert.deepEqual(prov.sources.map(s=>s.unused_columns),[['private'],[]]);
 for(let i=0;i<2;i++){assert.deepEqual(result.files[`source-${i+1}.csv`],ins[i].bytes);assert.equal(prov.sources[i].digest,digest(ins[i].bytes));}
 assert.deepEqual(ins,input());assert.deepEqual(p,plan());
 for(const [name,bytes] of Object.entries(result.files))writeFileSync(join(evidence,name),bytes);
 writeFileSync(join(evidence,'preview.json'),JSON.stringify(result.preview,null,2));
 const changed=input();changed[0].bytes=Buffer.from(changed[0].bytes.toString().replace('secret','changed'));
 const change=build(changed,p);assert.deepEqual(change.files['appended.csv'],result.files['appended.csv']);assert.notDeepEqual(change.files['provenance.json'],result.files['provenance.json']);
});
test('invalid mappings, provenance authority and ambiguous headers fail closed',()=>{
 for(const edit of [p=>p.sources[0].access='denied',p=>p.sources[0].access='unavailable',p=>p.sources[1].id='east',p=>p.sources[0].mapping=['person','absent'],p=>p.sources[0].mapping=['person','person'],p=>p.sources[0].mapping=['person'],p=>p.columns=['a',' a'],p=>p.columns=['source_id','response'],p=>p.columns=['é','é'],p=>p.sources[0].restrictions='',p=>p.sources[0].extra=true,p=>p.extra=true,p=>p.sources.pop(),p=>p.columns=[],p=>p.columns=['a',null]]) {const p=plan();edit(p);assert.throws(()=>build(input(),p));}
 for(const bytes of [Buffer.from([255]),Buffer.from('person,answer\na,"unterminated'),Buffer.from('person,person\na,b'),Buffer.alloc(32769,65)]) {const ins=input();ins[0].bytes=bytes;assert.throws(()=>build(ins,plan()));}
 assert.throws(()=>parsePlan(Buffer.from('{"sources":[],"sources":[]}')),/duplicate/);
});
test('record/output/source caps include every dataset before emitting output',()=>{
 const ins=input();ins[0].bytes=Buffer.from('person,answer\n'+'a,b\n'.repeat(511));assert.throws(()=>build(ins,plan()),/512/);
 ins[0].bytes=Buffer.from('person,answer\n'+'a,b\n'.repeat(510));assert.equal(build(ins,plan()).preview.output_count,512);
 const huge=input();huge[0].bytes=Buffer.from('person,answer\n'+('a,'.repeat(1))+'月'.repeat(10000)+'\n');huge[1].bytes=Buffer.from('response,id\n'+'月'.repeat(10000)+',a\n');assert.throws(()=>build(huge,plan()),/32 KiB/);
 assert.throws(()=>build([input()[0]],plan()),/2..8/);
});
const scratch=mkdtempSync(join(evidence,'cli-'));
for(const item of input())writeFileSync(join(scratch,item.name),item.bytes);
writeFileSync(join(scratch,'plan.json'),JSON.stringify(plan()));
const cli=(...args)=>spawnSync(process.execPath,[join(root,'scripts/csv_append.mjs'),...args],{encoding:'utf8',timeout:2000,maxBuffer:1024*1024});
const common=['--csv',join(scratch,'east.csv'),'--csv',join(scratch,'west.csv'),'--plan',join(scratch,'plan.json')];
test('real CLI inspect preview and new-directory bundle; existing destinations refused',()=>{
 assert.equal(cli('inspect','--csv',join(scratch,'east.csv')).status,0);
 const preview=cli('preview',...common);assert.equal(preview.status,0,preview.stderr);assert.equal(JSON.parse(preview.stdout).output_count,4);
 const dest=join(scratch,'bundle');const result=cli('convert',...common,'--out-dir',dest);assert.equal(result.status,0,result.stderr);assert.deepEqual(readFileSync(join(dest,'appended.csv')),build(input(),plan()).files['appended.csv']);
 assert.equal(cli('convert',...common,'--out-dir',dest).status,1);
 const link=join(scratch,'link');symlinkSync(dest,link);assert.equal(cli('convert',...common,'--out-dir',link).status,1);
 writeFileSync(join(scratch,'bad.json'),JSON.stringify({...plan(),extra:1}));const bad=join(scratch,'bad-out');assert.equal(cli('convert',...common.slice(0,4),'--plan',join(scratch,'bad.json'),'--out-dir',bad).status,1);assert.equal(existsSync(bad),false);
 for(const args of [[],['preview',...common,'--plan','x'],['inspect','--csv',join(scratch,'east.csv'),'--plan','x']])assert.equal(cli(...args).status,1);
});
test('retained production evidence explorer imports, filters, selects and exports appended rows',()=>{
 const retained=process.env.MOONFIND_RETAINED_UI;assert.ok(retained,'Set MOONFIND_RETAINED_UI to pinned R704 compiled JS');
 const bytes=readFileSync(retained),hash=createHash('sha256').update(bytes).digest('hex');
 assert.equal(hash,'831f79da21c3b3d27fb456a8d67c46a176584c14b27a6932af052f697b1ebb0e');
 const sourcePins=JSON.parse(readFileSync(join(root,'fixtures/retained_ui_inputs.json'),'utf8'));
 assert.equal(sourcePins.consumer_sha256,hash);
 for(const pin of sourcePins.files) assert.equal(createHash('sha256').update(readFileSync(join(root,pin.path))).digest('hex'),pin.sha256,'Retained consumer source changed: '+pin.path);
 const code=bytes.toString(),end=code.lastIndexOf('\n(() => {');assert.ok(end>0);
 const context=vm.createContext({console,TextEncoder,TextDecoder,URL,Blob,Buffer,setTimeout,clearTimeout});
 vm.runInContext(code.slice(0,end),context,{timeout:5000});
 const prefix='_M0FP36vectie18moonfind_2drabbita4main', ctor='_M0DTP36vectie18moonfind_2drabbita4main6CsvMsg';
 const run=s=>vm.runInContext(s,context,{timeout:2000});
 const table=parseCsv(build(input(),plan()).files['appended.csv']);
 context.payload=JSON.stringify({...table,total_count:table.rows.length,source:{name:'appended.csv',origin:'Mapped local synthetic CSV append; see retained provenance.json',captured_at:'2026-10-14',kind:'local-file',content_hex:build(input(),plan()).files['appended.csv'].toString('hex')}});
 run(`var view=${prefix}20initial__brief__view();view.pending=true;var parsed=_M0FPC14json13parse_2einner(new _M0TPC16string10StringView(payload,0,payload.length),100);if(parsed.$tag!==1)throw Error('parse failed');var reply=new _M0DTPC16result6ResultGRPB4JsonRPC15error5ErrorE2Ok(parsed._0);view=${prefix}17update__csv__view(undefined,new ${ctor}8Imported(view.generation,reply),view)._1;`);
 assert.equal(run('view.error'),undefined);assert.equal(run('view.csv.intake.rows.length'),4);
 run(`view=${prefix}17update__csv__view(undefined,new ${ctor}12SearchColumn(1),view)._1;view=${prefix}17update__csv__view(undefined,new ${ctor}6Filter('WEST'),view)._1;view=${prefix}17update__csv__view(undefined,new ${ctor}14SelectMatching(),view)._1;`);
 assert.deepEqual(JSON.parse(run('JSON.stringify(view.csv.selected)')),[4,5]);
 const extracted=run(`${prefix}18csv__extract__text(view.csv)`);assert.equal(extracted.$tag,1);
 const rows=parseCsv(Buffer.from(extracted._0));assert.deepEqual(rows.rows.map(r=>r.values.slice(0,2)),[['west','2'],['west','3']]);assert.equal(rows.rows[0].values[3],'=1+1');
 writeFileSync(join(evidence,'explorer-selected.csv'),extracted._0);
 writeFileSync(join(evidence,'explorer-consumer.json'),JSON.stringify({retained_ui:retained,sha256:hash,executed:['production Imported reducer with supplied intake JSON','production SearchColumn and Filter','production SelectMatching','production csv_extract_text'],selected:[4,5],output_source_ids:['west','west'],limits:'Bootstrap mounting skipped; host intake response supplied by test. No browser, server, save/reopen, installed lifecycle or provider qualification.'},null,2));
});
