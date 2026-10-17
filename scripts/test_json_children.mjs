import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,existsSync,symlinkSync,statSync} from 'node:fs';
import {dirname,resolve,join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import vm from 'node:vm';
import {createChildrenBundle as build,previewChildren as preview,inspectChildren,LINEAGE_COLUMNS} from './json_children.mjs';
import {parseJsonValues,resolveValue} from './json_child_values.mjs';
import {digest,parseCsv,parsePlan,LIMITS} from './csv_bibliography.mjs';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const input=readFileSync(join(root,'fixtures/child-observations.json'));
const plan=()=>JSON.parse(readFileSync(join(root,'fixtures/child-observations-plan.json')));
const evidence=process.env.MOONFIND_CHILDREN_EVIDENCE;
assert.ok(evidence,'Set MOONFIND_CHILDREN_EVIDENCE to a retained evidence directory');
mkdirSync(evidence,{recursive:true});const scratch=mkdtempSync(join(evidence,'cli-'));
const cli=(...args)=>spawnSync(process.execPath,[join(root,'scripts/json_children.mjs'),...args],{encoding:'utf8',timeout:5000});
const pFor=(bytes,overrides={})=>({...plan(),source_digest:digest(bytes),parent_pointer:'',children_pointer:'/children',fields:[{scope:'child',pointer:'',name:'value'}],...overrides});

test('expand selected nested observations in source order with exact raw values, kinds and lineage',()=>{
  const bundle=build(input,plan(),'child-observations.json'),view=bundle.preview,table=parseCsv(bundle.files['observations.csv']);
  assert.equal(view.parent_count,4);assert.equal(view.output_count,4);assert.equal(view.skipped_parent_count,2);
  assert.deepEqual(view.parents.map(p=>[p.state,p.action,p.child_count]),[['children','expand',2],['children','expand',2],['empty','skip',0],['missing','skip',null]]);
  assert.deepEqual(table.columns.slice(0,5),LINEAGE_COLUMNS);
  assert.deepEqual(table.rows.map(r=>r.values.slice(5)),[
    ['"alpha"','string','"baseline"','string','9007199254740993','number','"=1+1"','string'],
    ['"alpha"','string','"follow-up"','string','1.2300e+02','number','','missing'],
    ['"beta"','string','"baseline"','string','-0','number','null','null'],
    ['"beta"','string','"follow-up"','string','1e400','number','"\\u0061"','string']]);
  assert.deepEqual(table.rows.map(r=>r.values.slice(1,5)),[['0','/studies/0','0','/studies/0/readings/0'],['0','/studies/0','1','/studies/0/readings/1'],['1','/studies/1','0','/studies/1/readings/0'],['1','/studies/1','1','/studies/1/readings/1']]);
  const parsed=parseJsonValues(input),provenance=JSON.parse(bundle.files['provenance.json']);
  for(const [index,record] of provenance.records.entries())for(const cell of record.cells){
    const node=resolveValue(parsed.root,cell.pointer),column=table.columns.indexOf(cell.column);
    assert.equal(table.rows[index].values[column],node?parsed.text.slice(node.start,node.end):'');
    assert.equal(table.rows[index].values[column+1],cell.kind);
    assert.deepEqual(cell.span_utf16,node?[node.start,node.end]:null);
  }
  assert.deepEqual(bundle.files['source.json'],input);assert.equal(provenance.source.digest,digest(input));
  assert.equal(provenance.derived.digest,digest(bundle.files['observations.csv']));
  for(const file of JSON.parse(bundle.files['manifest.json']).files){assert.equal(file.digest,digest(bundle.files[file.name]));assert.equal(file.bytes,bundle.files[file.name].length);}
  assert.deepEqual(build(input,plan(),'child-observations.json'),bundle);
  for(const [name,bytes] of Object.entries(bundle.files))writeFileSync(join(evidence,name),bytes);
  writeFileSync(join(evidence,'preview.json'),JSON.stringify(view,null,2));
});
test('empty and missing arrays are distinct policy blockers; explicit skip yields no invented child rows',()=>{
  const bytes=Buffer.from('[{"children":[]},{}]'),p=pFor(bytes);
  for(const key of ['empty_arrays','missing_arrays']){
    p[key]='error';const view=preview(bytes,p);assert.equal(view.can_convert,false);assert.equal(view.output_count,null);assert.equal(view.candidate_count,0);
    assert.throws(()=>build(bytes,p),/child array/);p[key]='skip';
  }
  const bundle=build(bytes,p);assert.equal(bundle.preview.output_count,0);assert.equal(bundle.preview.skipped_parent_count,2);assert.deepEqual(parseCsv(bundle.files['observations.csv']).rows,[]);
  const empty=Buffer.from('[]');assert.equal(build(empty,pFor(empty)).preview.output_count,0);
});
test('scalar mode preserves repeated scalar observations and heterogeneous kinds without coercion',()=>{
  const bytes=Buffer.from('[{"children":[0,-0,1e400,1e-999999,"x","x",false,null]}]');
  const bundle=build(bytes,pFor(bytes,{child_mode:'scalars'})),rows=parseCsv(bundle.files['observations.csv']).rows;
  assert.deepEqual(rows.map(r=>r.values.slice(5)),[['0','number'],['-0','number'],['1e400','number'],['1e-999999','number'],['"x"','string'],['"x"','string'],['false','boolean'],['null','null']]);
  assert.equal(new Set(rows.map(r=>r.values[4])).size,8);
  const mixed=Buffer.from('[{"children":[1,{}]}]');assert.throws(()=>build(mixed,pFor(mixed)),/must be an object/);assert.throws(()=>build(mixed,pFor(mixed,{child_mode:'scalars'})),/must be scalar/);
  const p=pFor(bytes,{child_mode:'scalars',fields:[{scope:'child',pointer:'/x',name:'value'}]});assert.throws(()=>build(bytes,p),/empty pointer/);
});
test('literal slash, tilde, empty and prototype keys resolve to exact child/parent locations',()=>{
  const bytes=Buffer.from('{"a/b~":[{"__proto__":"safe","child/~":[{"":1,"a/b~":2}]}]}');
  const p=pFor(bytes,{parent_pointer:'/a~1b~0',children_pointer:'/child~1~0',fields:[{scope:'parent',pointer:'/__proto__',name:'parent'},{scope:'child',pointer:'/',name:'empty'},{scope:'child',pointer:'/a~1b~0',name:'escaped'}]});
  const bundle=build(bytes,p),row=parseCsv(bundle.files['observations.csv']).rows[0];
  assert.equal(row.values[4],'/a~1b~0/0/child~1~0/0');assert.deepEqual(row.values.slice(5),['"safe"','string','1','number','2','number']);
  assert.equal(bundle.preview.lineage[0].cells[1].pointer,'/a~1b~0/0/child~1~0/0/');
});
test('null/scalar containers, scalar traversal, malformed source, duplicate keys and invalid Unicode refuse',()=>{
  for(const source of ['[{"children":null}]','[{"children":1}]','[{"children":{}}]','[null]','[{"children":[1]}]','[{"children":[],"children":[]}]','[{"children":[],"\\u0063hildren":[]}]','[{"children":[{"x":1,"x":2}]}]','[{"children":[{"x":01}]}]','[{"children":[]},]','[','[{"children":[{"x":"\\ud800"}]}]']){
    const bytes=Buffer.from(source);assert.throws(()=>build(bytes,pFor(bytes)),source);
  }
  const bytes=Buffer.from('[{"children":[{"x":null}]}]');
  assert.throws(()=>build(bytes,pFor(bytes,{fields:[{scope:'child',pointer:'/x/y',name:'x'}]})),/scalar/);
  assert.throws(()=>parseJsonValues(Buffer.from([0xff])),/UTF-8/);
  assert.throws(()=>parseJsonValues(Buffer.from('[{"children":[{"x":"a\nb"}]}]')));
});
test('strict plan/source binding, permission, field kinds and output column names fail closed',()=>{
  for(const edit of [p=>p.source_digest='sha256:stale',p=>p.source.access='denied',p=>p.child_mode='auto',p=>p.empty_arrays='omit',p=>p.missing_arrays='ignore',p=>p.parent_pointer='/none',p=>p.children_pointer='',p=>p.fields=[],p=>p.fields=[{scope:'parent',pointer:'/study',name:'study'}],p=>p.fields[0].name='source_digest',p=>p.fields[0].name=' label ',p=>p.fields[0].name='label_kind',p=>p.fields[0].scope='both',p=>p.fields[0].pointer='/bad~2',p=>p.extra=true,p=>p.contract_id='v2',p=>p.source.origin='',p=>p.fields[0].name='\ud800']){
    const p=plan();edit(p);assert.throws(()=>build(input,p));
  }
  assert.throws(()=>build(Buffer.concat([input,Buffer.from('\n')]),plan()),/digest changed/);
  assert.throws(()=>build(input,plan(),'../source.json'),/basename/);
  assert.throws(()=>parsePlan(Buffer.from('{"x":1,"x":2}')),/duplicate JSON key/);
  const p=plan();p.fields[0].pointer='/'+ 'x'.repeat(1024);assert.throws(()=>build(input,p),/1024/);
});
test('BOM, CRLF, multibyte text and structured cells keep original bytes and raw spans',()=>{
  const bytes=Buffer.from('\uFEFF[\r\n{"children":[{"月":"line\\n\\u0061","obj":{"x":1e+02},"arr":[-0]}]}\r\n]\r\n');
  const p=pFor(bytes,{fields:[{scope:'child',pointer:'/月',name:'月'},{scope:'child',pointer:'/obj',name:'obj'},{scope:'child',pointer:'/arr',name:'arr'}]});
  const bundle=build(bytes,p);assert.deepEqual(bundle.files['source.json'],bytes);
  assert.deepEqual(parseCsv(bundle.files['observations.csv']).rows[0].values.slice(5),['"line\\n\\u0061"','string','{"x":1e+02}','object','[-0]','array']);
  const parsed=parseJsonValues(bytes);for(const cell of bundle.preview.lineage[0].cells)assert.equal(parsed.text.slice(...cell.span_utf16),parsed.text.slice(resolveValue(parsed.root,cell.pointer).start,resolveValue(parsed.root,cell.pointer).end));
});
test('row/column/source/plan/depth/node/output/provenance limits refuse before writes or large persisted fixtures',()=>{
  assert.throws(()=>parseJsonValues(Buffer.alloc(LIMITS.source+1,32)),/32768/);
  const p=plan();p.fields=Array.from({length:14},(_,i)=>({scope:'child',pointer:'/value',name:'v'+i}));assert.throws(()=>build(input,p),/1–13/);
  p.fields=p.fields.slice(0,13);assert.equal(parseCsv(build(input,p).files['observations.csv']).columns.length,31);
  p.source.origin='x'.repeat(20000);assert.throws(()=>build(input,p),/16 KiB/);
  const tooDeep=Buffer.from('['.repeat(65)+'0'+']'.repeat(65));assert.throws(()=>parseJsonValues(tooDeep),/64/);
  const tooMany=Buffer.from('['+Array(10000).fill('0').join(',')+']');assert.throws(()=>parseJsonValues(tooMany),/10000/);
  const parents=Buffer.from('['+Array(513).fill('{"children":[]}').join(',')+']');assert.throws(()=>build(parents,pFor(parents)),/512 parent/);
  const children=Buffer.from('[{"children":['+Array(513).fill('0').join(',')+']}]');assert.throws(()=>build(children,pFor(children,{child_mode:'scalars'})),/32 KiB|512 observations/);
  const expanded=Buffer.from('[{"long":"'+'a'.repeat(17000)+'","children":[{},{}]}]');assert.throws(()=>build(expanded,pFor(expanded,{fields:[{scope:'parent',pointer:'/long',name:'long'},{scope:'child',pointer:'',name:'child'}]})),/observations.csv exceeds/);
  const many=Buffer.from('[{"children":['+Array(60).fill('{}').join(',')+']}]');assert.throws(()=>build(many,pFor(many,{fields:Array.from({length:8},(_,i)=>({scope:'child',pointer:'/v'+i,name:'v'+i}))})),/provenance.json exceeds/);
});
test('inspect inventories source-bound array locations and explicitly shortens a bounded inventory',()=>{
  const view=inspectChildren(input);assert.equal(view.digest,digest(input));assert.deepEqual(view.arrays.map(a=>a.pointer),['/studies','/studies/0/readings','/studies/1/readings','/studies/2/readings']);
  const many=inspectChildren(Buffer.from('['+Array(70).fill('[]').join(',')+']'));assert.equal(many.arrays.length,64);assert.equal(many.array_count,71);assert.equal(many.inventory_shortened,true);
});
test('real CLI inspect/preview/convert preserves original and refuses existing or symlink destinations',()=>{
  const source=join(root,'fixtures/child-observations.json'),planPath=join(root,'fixtures/child-observations-plan.json'),common=['--json',source,'--plan',planPath];
  const inspected=cli('inspect','--json',source);assert.equal(inspected.status,0,inspected.stderr);assert.equal(JSON.parse(inspected.stdout).digest,digest(input));
  const shown=cli('preview',...common);assert.equal(shown.status,0,shown.stderr);assert.equal(JSON.parse(shown.stdout).output_count,4);
  const out=join(scratch,'bundle'),converted=cli('convert',...common,'--out-dir',out);assert.equal(converted.status,0,converted.stderr);
  assert.deepEqual(readFileSync(join(out,'observations.csv')),build(input,plan()).files['observations.csv']);assert.deepEqual(readFileSync(source),input);assert.deepEqual(readFileSync(join(out,'source.json')),input);
  assert.notEqual(cli('convert',...common,'--out-dir',out).status,0);
  const link=join(scratch,'link');symlinkSync(out,link,'dir');assert.notEqual(cli('convert',...common,'--out-dir',link).status,0);
  assert.equal(statSync(out).mode&0o777,0o700);assert.equal(statSync(join(out,'source.json')).mode&0o777,0o600);
  writeFileSync(join(evidence,'cli-result.json'),JSON.stringify({inspect:JSON.parse(inspected.stdout),preview:JSON.parse(shown.stdout),convert:JSON.parse(converted.stdout)},null,2));
});
test('policy-blocked/stale plans never write output, and malformed CLI fails',()=>{
  const p=plan();p.empty_arrays='error';p.missing_arrays='error';const path=join(scratch,'blocked-plan.json');writeFileSync(path,JSON.stringify(p));
  const common=['--json',join(root,'fixtures/child-observations.json'),'--plan',path],out=join(scratch,'blocked');
  const shown=cli('preview',...common);assert.equal(shown.status,0,shown.stderr);assert.equal(JSON.parse(shown.stdout).blockers.length,2);
  assert.notEqual(cli('convert',...common,'--out-dir',out).status,0);assert.equal(existsSync(out),false);
  p.source_digest='sha256:stale';writeFileSync(path,JSON.stringify(p));assert.notEqual(cli('convert',...common,'--out-dir',out).status,0);assert.equal(existsSync(out),false);
  assert.notEqual(cli('preview',...common,'--out-dir',out).status,0);assert.notEqual(cli('inspect','--json',common[1],'--json',common[1]).status,0);
  writeFileSync(join(evidence,'blocked-preview.json'),shown.stdout);
});
test('unchanged pinned production explorer imports, filters, selects and extracts exact child observations',()=>{
  const retained=process.env.MOONFIND_RETAINED_UI;assert.ok(retained,'Set MOONFIND_RETAINED_UI; consumer test cannot skip');
  const bytes=readFileSync(retained),hash=digest(bytes).slice(7);assert.equal(hash,'831f79da21c3b3d27fb456a8d67c46a176584c14b27a6932af052f697b1ebb0e');
  const pins=JSON.parse(readFileSync(join(root,'fixtures/retained_ui_inputs.json'),'utf8'));assert.equal(pins.consumer_sha256,hash);
  for(const pin of pins.files)assert.equal(digest(readFileSync(join(root,pin.path))).slice(7),pin.sha256,pin.path);
  const code=bytes.toString(),end=code.lastIndexOf('\n(() => {');assert.ok(end>0);
  const context=vm.createContext({console,TextEncoder,TextDecoder,URL,Blob,Buffer,setTimeout,clearTimeout});vm.runInContext(code.slice(0,end),context,{timeout:5000});
  const prefix='_M0FP36vectie18moonfind_2drabbita4main',ctor='_M0DTP36vectie18moonfind_2drabbita4main6CsvMsg',run=s=>vm.runInContext(s,context,{timeout:2000});
  const bundle=build(input,plan()),output=bundle.files['observations.csv'],table=parseCsv(output);
  context.payload=JSON.stringify({...table,total_count:table.rows.length,source:{name:'observations.csv',origin:'Synthetic explicitly expanded observations',captured_at:'2026-10-14',kind:'local-file',content_hex:output.toString('hex')}});
  run(`var view=${prefix}20initial__brief__view();view.pending=true;var parsed=_M0FPC14json13parse_2einner(new _M0TPC16string10StringView(payload,0,payload.length),100);if(parsed.$tag!==1)throw Error('parse failed');var reply=new _M0DTPC16result6ResultGRPB4JsonRPC15error5ErrorE2Ok(parsed._0);view=${prefix}17update__csv__view(undefined,new ${ctor}8Imported(view.generation,reply),view)._1;`);
  assert.equal(run('view.error'),undefined);
  run(`view=${prefix}17update__csv__view(undefined,new ${ctor}12SearchColumn(8),view)._1;view=${prefix}17update__csv__view(undefined,new ${ctor}6Filter('follow-up'),view)._1;view=${prefix}17update__csv__view(undefined,new ${ctor}14SelectMatching(),view)._1;`);
  assert.deepEqual(JSON.parse(run('JSON.stringify(view.csv.selected)')),[3,5]);
  const extracted=run(`${prefix}18csv__extract__text(view.csv)`);assert.equal(extracted.$tag,1);
  const selected=parseCsv(Buffer.from(extracted._0));assert.deepEqual(selected.rows.map(r=>r.values),[table.rows[1].values,table.rows[3].values]);
  assert.deepEqual(selected.rows.map(r=>r.values[4]),['/studies/0/readings/1','/studies/1/readings/1']);
  assert.deepEqual(selected.rows.map(r=>r.values[9]),['1.2300e+02','1e400']);
  const source=parseJsonValues(input);
  for(const row of selected.rows){assert.equal(row.values[0],digest(input));const child=resolveValue(source.root,row.values[4]),value=resolveValue(child,'/value');assert.equal(row.values[9],source.text.slice(value.start,value.end));}
  writeFileSync(join(evidence,'explorer-selected.csv'),extracted._0);
  writeFileSync(join(evidence,'explorer-consumer.json'),JSON.stringify({retained_ui:retained,sha256:hash,source_pins_verified:pins.files.length,executed:['Imported','SearchColumn','Filter','SelectMatching','csv_extract_text'],selected:[3,5],original_children:selected.rows.map(r=>r.values[4]),limits:'Actual unchanged production reducers and extraction with supplied intake JSON; browser bootstrap omitted. Sidecar not automatically consumed; no native host/browser/persistence/production qualification.'},null,2));
});
