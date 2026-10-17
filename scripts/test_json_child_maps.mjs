import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync,existsSync} from 'node:fs';
import {dirname,resolve,join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import vm from 'node:vm';
import {createChildrenBundle as build,previewChildren as preview,inspectChildren} from './json_children.mjs';
import {parseJsonValues,resolveValue} from './json_child_values.mjs';
import {digest,parseCsv} from './csv_bibliography.mjs';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const input=readFileSync(join(root,'fixtures/child-map-observations.json'));
const plan=()=>JSON.parse(readFileSync(join(root,'fixtures/child-map-observations-plan.json')));
const evidence=process.env.MOONFIND_CHILD_MAP_EVIDENCE;
assert.ok(evidence,'Set MOONFIND_CHILD_MAP_EVIDENCE to a new retained evidence directory');
assert.equal(existsSync(evidence),false,'Use a new directory to preserve prior evidence');
mkdirSync(evidence,{recursive:true});
const save=(name,value)=>writeFileSync(join(evidence,name),typeof value==='string'||Buffer.isBuffer(value)?value:JSON.stringify(value,null,2)+'\n');
const cli=(...args)=>spawnSync(process.execPath,[join(root,'scripts/json_children.mjs'),...args],{encoding:'utf8',timeout:5000});
const forInput=(bytes,overrides={})=>({...plan(),source_digest:digest(bytes),parent_pointer:'',children_pointer:'/readings',...overrides});

test('keyed children retain parent context, lexical numeric-key order and exact original tokens',()=>{
  const bundle=build(input,plan(),'child-map-observations.json'),view=bundle.preview,table=parseCsv(bundle.files['observations.csv']);
  assert.equal(view.output_count,7);assert.equal(view.parent_count,4);assert.equal(view.skipped_parent_count,2);
  assert.deepEqual(view.parents.map(p=>[p.state,p.action,p.child_count]),[['children','expand',4],['children','expand',3],['empty','skip',0],['missing','skip',null]]);
  assert.deepEqual(table.rows.map(r=>r.values.slice(5)),[
    ['"alpha"','string','"10"','string','9007199254740993','number'],
    ['"alpha"','string','"2"','string','1.2300e+02','number'],
    ['"alpha"','string','"a/b~"','string','-0','number'],
    ['"alpha"','string','""','string','"\\u0061"','string'],
    ['"beta"','string','"10"','string','1e400','number'],
    ['"beta"','string','"\\u0032"','string','null','null'],
    ['"beta"','string','"a/b~"','string','','missing']]);
  assert.deepEqual(table.rows.map(r=>r.values[4]),['/studies/0/readings/10','/studies/0/readings/2','/studies/0/readings/a~1b~0','/studies/0/readings/','/studies/1/readings/10','/studies/1/readings/2','/studies/1/readings/a~1b~0']);
  assert.deepEqual(table.rows.map(r=>r.values[3]),['0','1','2','3','0','1','2']);
  const parsed=parseJsonValues(input),provenance=JSON.parse(bundle.files['provenance.json']);
  for(const [i,record] of provenance.records.entries())for(const cell of record.cells){
    const actual=table.rows[i].values[table.columns.indexOf(cell.column)];
    assert.equal(actual,cell.span_utf16?parsed.text.slice(...cell.span_utf16):'');
    if(cell.target==='member_key'){
      assert.equal(JSON.parse(actual),record.child_key);assert.ok(resolveValue(parsed.root,cell.pointer));
    } else {
      const node=resolveValue(parsed.root,cell.pointer);assert.deepEqual(cell.span_utf16,node?[node.start,node.end]:null);
    }
  }
  assert.deepEqual(bundle.files['source.json'],input);assert.deepEqual(build(input,plan(),'child-map-observations.json'),bundle);
  for(const member of JSON.parse(bundle.files['manifest.json']).files){assert.equal(digest(bundle.files[member.name]),member.digest);assert.equal(bundle.files[member.name].length,member.bytes);}
  save('preview.json',view);
});

test('scalar map values retain types, BOM and escaped key tokens with RFC 6901 locations',()=>{
  const bytes=Buffer.from('\uFEFF[{"study":"月","readings":{"\\u0061\\/b~":-0,"":false,"01":null,"1":"\\u0062"}}]\r\n');
  const p=forInput(bytes,{child_mode:'scalars',fields:[{scope:'parent',pointer:'/study',name:'study'},{scope:'key',pointer:'',name:'key'},{scope:'value',pointer:'',name:'value'}]});
  const bundle=build(bytes,p),table=parseCsv(bundle.files['observations.csv']);
  assert.deepEqual(table.rows.map(r=>r.values[4]),['/0/readings/a~1b~0','/0/readings/','/0/readings/01','/0/readings/1']);
  assert.deepEqual(table.rows.map(r=>r.values.slice(7)),[['"\\u0061\\/b~"','string','-0','number'],['""','string','false','boolean'],['"01"','string','null','null'],['"1"','string','"\\u0062"','string']]);
  assert.deepEqual(bundle.files['source.json'],bytes);
  const parsed=parseJsonValues(bytes);
  for(const row of bundle.preview.lineage)for(const cell of row.cells)assert.equal(parsed.text.slice(...cell.span_utf16),table.rows[row.csv_record-2].values[table.columns.indexOf(cell.column)]);
});

test('empty and missing maps require independent policies and never invent rows',()=>{
  const bytes=Buffer.from('[{"readings":{}},{}]'),p=forInput(bytes);
  for(const field of ['empty_maps','missing_maps']){
    p[field]='error';const view=preview(bytes,p);assert.equal(view.can_convert,false);assert.equal(view.output_count,null);assert.equal(view.candidate_count,0);assert.equal(view.blockers.length,1);
    assert.throws(()=>build(bytes,p),/child map/);p[field]='skip';
  }
  assert.equal(build(bytes,p).preview.output_count,0);
  for(const source of ['[{"readings":null}]','[{"readings":[]}]','[{"readings":1}]']){
    const invalid=Buffer.from(source);assert.throws(()=>build(invalid,forInput(invalid)),/not object/);
  }
});

test('decoded duplicates refuse within each map while explicit key/value fields and source identity are enforced',()=>{
  const duplicate=Buffer.from('[{"readings":{"a":{},"\\u0061":{}}}]');
  assert.throws(()=>build(duplicate,forInput(duplicate)),/duplicate JSON key/);
  for(const edit of [p=>p.fields[1].pointer='/x',p=>p.fields=p.fields.filter(f=>f.scope!=='key'),p=>p.fields=p.fields.filter(f=>f.scope!=='value'),p=>p.fields[2].scope='child',p=>p.source.access='denied',p=>p.source_digest='sha256:stale']){
    const p=plan();edit(p);assert.throws(()=>build(input,p));
  }
  assert.throws(()=>build(Buffer.concat([input,Buffer.from('\n')]),plan()),/digest changed/);
  const changed=Buffer.concat([input,Buffer.from('\n')]),p={...plan(),source_digest:digest(changed)};
  assert.notEqual(build(changed,p).preview.source.digest,build(input,plan()).preview.source.digest);
});

test('existing array plans continue to expand observations without map interpretation',()=>{
  const bytes=readFileSync(join(root,'fixtures/child-observations.json')),p=JSON.parse(readFileSync(join(root,'fixtures/child-observations-plan.json')));
  const bundle=build(bytes,p);assert.equal(bundle.preview.output_count,4);assert.equal(bundle.preview.contract_id,'moonfind.json-children-preview.v1');
  assert.deepEqual(parseCsv(bundle.files['observations.csv']).rows.map(r=>r.values[4]),['/studies/0/readings/0','/studies/0/readings/1','/studies/1/readings/0','/studies/1/readings/1']);
});

test('actual inspect, preview and convert CLI exposes maps and explicit policy blockers',()=>{
  const source=join(root,'fixtures/child-map-observations.json'),planPath=join(root,'fixtures/child-map-observations-plan.json'),common=['--json',source,'--plan',planPath];
  const inspected=cli('inspect','--json',source);assert.equal(inspected.status,0,inspected.stderr);
  const inventory=JSON.parse(inspected.stdout),map=inventory.maps.find(m=>m.pointer==='/studies/0/readings');
  assert.deepEqual(map.first_keys,['10','2','a/b~','']);assert.equal(inventory.digest,digest(input));
  assert.deepEqual(inspectChildren(input),inventory);
  const shown=cli('preview',...common);assert.equal(shown.status,0,shown.stderr);assert.equal(JSON.parse(shown.stdout).output_count,7);
  const out=join(evidence,'bundle'),converted=cli('convert',...common,'--out-dir',out);assert.equal(converted.status,0,converted.stderr);
  assert.deepEqual(readFileSync(join(out,'observations.csv')),build(input,plan()).files['observations.csv']);assert.deepEqual(readFileSync(join(out,'source.json')),input);
  assert.notEqual(cli('convert',...common,'--out-dir',out).status,0);
  const blockedPlan=plan();blockedPlan.empty_maps='error';blockedPlan.missing_maps='error';save('blocked-plan.json',blockedPlan);
  const blocked=['--json',source,'--plan',join(evidence,'blocked-plan.json')],blockedOut=join(evidence,'blocked');
  const blockedView=cli('preview',...blocked);assert.equal(blockedView.status,0,blockedView.stderr);assert.equal(JSON.parse(blockedView.stdout).blockers.length,2);
  assert.notEqual(cli('convert',...blocked,'--out-dir',blockedOut).status,0);assert.equal(existsSync(blockedOut),false);
  assert.deepEqual(readFileSync(source),input);save('cli-inspect.json',inspected.stdout);save('cli-preview.json',shown.stdout);save('cli-convert.json',converted.stdout);save('cli-blocked-preview.json',blockedView.stdout);
});

test('current pinned CSV consumer imports, filters, selects and extracts repeated keys across parents',()=>{
  const retained=process.env.MOONFIND_RETAINED_EVIDENCE,workspace=process.env.MOONFIND_WORKSPACE;
  assert.ok(retained&&workspace,'Set retained R765 evidence and workspace; current consumer proof cannot skip');
  const pins=[['source-artifact-input-sha256.txt','179a6d01bef4f9ef94ef450fb6a77a2764bebbc7c5f4f606879e169130568607'],['compile-interfaces-sha256.txt','bd71c37a9b672ee4a50de368e74cc06a722f2c3d1c9fb671d55c3d9fb3474314']];
  const verified=[];
  for(const [name,expected] of pins){
    const bytes=readFileSync(join(retained,name));assert.equal(digest(bytes).slice(7),expected,name);
    for(const line of bytes.toString().trim().split('\n')){
      const match=/^([0-9a-f]{64})  (.+)$/.exec(line);assert.ok(match,name);
      const [,hash,path]=match,prefix='.moonsuite-background/philosophy-r763-767/r765/source/';
      const current=path.startsWith(prefix)?join(root,path.slice(prefix.length)):resolve(workspace,path);
      assert.equal(digest(readFileSync(current)).slice(7),hash,current);verified.push({path:current,sha256:hash});
    }
  }
  const artifact=join(retained,'range-runtime.cjs'),bytes=readFileSync(artifact),hash=digest(bytes).slice(7);
  assert.equal(hash,'b4ced4539764212ff329a646ef409d8bb1c8885d87cf2fe4be183022421181b7');
  const code=bytes.toString(),end=code.lastIndexOf('\n(() => {');assert.ok(end>0);
  const context=vm.createContext({console,TextEncoder,TextDecoder,URL,Blob,Buffer,setTimeout,clearTimeout});vm.runInContext(code.slice(0,end),context,{timeout:5000});
  const prefix='_M0FP36vectie18moonfind_2drabbita4main',ctor='_M0DTP36vectie18moonfind_2drabbita4main6CsvMsg',run=s=>vm.runInContext(s,context,{timeout:2000});
  // Feed the actual CLI conversion to the unchanged production reducer.
  const output=readFileSync(join(evidence,'bundle/observations.csv')),table=parseCsv(output);
  context.payload=JSON.stringify({...table,total_count:table.rows.length,source:{name:'observations.csv',origin:'Synthetic keyed child observations',captured_at:'2026-10-15',kind:'local-file',content_hex:output.toString('hex')}});
  run(`var view=${prefix}20initial__brief__view();view.pending=true;var parsed=_M0FPC14json13parse_2einner(new _M0TPC16string10StringView(payload,0,payload.length),100);if(parsed.$tag!==1)throw Error('parse failed');var reply=new _M0DTPC16result6ResultGRPB4JsonRPC15error5ErrorE2Ok(parsed._0);view=${prefix}17update__csv__view(undefined,new ${ctor}8Imported(view.generation,reply),view)._1;`);
  assert.equal(run('view.error'),undefined);
  run(`view=${prefix}17update__csv__view(undefined,new ${ctor}12SearchColumn(8),view)._1;view=${prefix}17update__csv__view(undefined,new ${ctor}6Filter('10'),view)._1;view=${prefix}17update__csv__view(undefined,new ${ctor}14SelectMatching(),view)._1;`);
  assert.deepEqual(JSON.parse(run('JSON.stringify(view.csv.selected)')),[2,6]);
  const extracted=run(`${prefix}18csv__extract__text(view.csv)`);assert.equal(extracted.$tag,1);
  const selected=parseCsv(Buffer.from(extracted._0));assert.deepEqual(selected.rows.map(r=>r.values),[table.rows[0].values,table.rows[4].values]);
  assert.deepEqual(selected.rows.map(r=>r.values[4]),['/studies/0/readings/10','/studies/1/readings/10']);
  assert.deepEqual(selected.rows.map(r=>r.values[9]),['9007199254740993','1e400']);
  save('explorer-selected.csv',extracted._0);save('consumer-pins.json',verified);
  save('explorer-consumer.json',{artifact,sha256:hash,verified_pins:verified.length,executed:['CLI convert','Imported','SearchColumn','Filter','SelectMatching','csv_extract_text'],selected_records:[2,6],original_pointers:selected.rows.map(r=>r.values[4]),limits:'Current production CSV reducers with supplied intake JSON; browser bootstrap and original test invocation omitted. No changed MoonBit/extern logic, host import, browser mounting, persistence, provider or production qualification.'});
});
