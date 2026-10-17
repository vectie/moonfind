import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync, writeFileSync, mkdirSync, mkdtempSync, existsSync, symlinkSync, statSync} from 'node:fs';
import {resolve, dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import vm from 'node:vm';
import {createConsolidationBundle as build, previewConsolidation as preview, SOURCE_RECORD_COLUMN} from './csv_consolidate.mjs';
import {createAppendBundle} from './csv_append.mjs';
import {digest, parseCsv, parsePlan, LIMITS} from './csv_bibliography.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const input = readFileSync(join(root, 'fixtures/record-consolidation.csv'));
const plan = () => JSON.parse(readFileSync(join(root, 'fixtures/record-consolidation-plan.json')));
const simplePlan = () => ({...plan(), key_columns: ['id']});
const evidence = process.env.MOONFIND_CONSOLIDATE_EVIDENCE;
assert.ok(evidence, 'Set MOONFIND_CONSOLIDATE_EVIDENCE to a retained evidence directory');
mkdirSync(evidence, {recursive: true});
const scratch = mkdtempSync(join(evidence, 'cli-'));
const cli = (...args) => spawnSync(process.execPath, [join(root, 'scripts/csv_consolidate.mjs'), ...args], {encoding: 'utf8', timeout: 5000});

test('keep-last selects complete original rows, retaining composite-key groups, conflicts and source identities', () => {
  const bundle = build(input, plan(), 'record-consolidation.csv');
  const view = bundle.preview, original = parseCsv(input), output = parseCsv(bundle.files['consolidated.csv']);
  assert.equal(view.input_count, 6); assert.equal(view.output_count, 4); assert.equal(view.omitted_count, 2);
  assert.equal(view.duplicate_group_count, 2); assert.equal(view.conflict_group_count, 2);
  assert.deepEqual(view.groups.map(group => group.source_records), [[2,4], [3,6], [5], [7]]);
  assert.deepEqual(view.groups.map(group => group.selected_source_record), [4,6,5,7]);
  assert.deepEqual(view.groups.map(group => group.output_record), [2,3,4,5]);
  assert.deepEqual(view.groups[0].conflicts.find(c => c.column === 'response').values, [{value:'yes',source_records:[2]}, {value:'no',source_records:[4]}]);
  assert.deepEqual(output.columns, [...original.columns, SOURCE_RECORD_COLUMN]);
  for (const [index, sourceRecord] of [4,6,5,7].entries()) {
    assert.deepEqual(output.rows[index].values.slice(0,-1), original.rows[sourceRecord-2].values);
    assert.equal(output.rows[index].values.at(-1), String(sourceRecord));
  }
  assert.deepEqual(bundle.files['source.csv'], input);
  assert.deepEqual(bundle.files['consolidated.csv'], readFileSync(join(root, 'fixtures/record-consolidation-expected.csv')));
  const provenance = JSON.parse(bundle.files['provenance.json']);
  assert.equal(provenance.source.digest, digest(input));
  assert.equal(provenance.derived.digest, digest(bundle.files['consolidated.csv']));
  for (const entry of JSON.parse(bundle.files['manifest.json']).files) {
    assert.equal(entry.bytes, bundle.files[entry.name].length); assert.equal(entry.digest, digest(bundle.files[entry.name]));
  }
  for (const [name, bytes] of Object.entries(bundle.files)) writeFileSync(join(evidence, name), bytes);
  writeFileSync(join(evidence, 'preview.json'), JSON.stringify(view, null, 2));
});

test('keep-first and keep-last use input order, never combine cells or infer chronology', () => {
  const bytes = Buffer.from('id,date,a,b\nx,2099,first,\ny,2000,unique,other\nx,1900,,last\n');
  const p = simplePlan(); p.duplicate_policy = 'keep-first';
  assert.deepEqual(parseCsv(build(bytes,p).files['consolidated.csv']).rows.map(r=>r.values), [['x','2099','first','','2'], ['y','2000','unique','other','3']]);
  p.duplicate_policy = 'keep-last';
  assert.deepEqual(parseCsv(build(bytes,p).files['consolidated.csv']).rows.map(r=>r.values), [['x','1900','','last','4'], ['y','2000','unique','other','3']]);
});

test('error policy still previews duplicate groups and conflicts but refuses conversion, including identical rows', () => {
  const p = simplePlan(); p.duplicate_policy = 'error';
  for (const data of ['id,value\nx,a\nx,b\n', 'id,value\nx,a\nx,a\n']) {
    const view = preview(Buffer.from(data), p);
    assert.equal(view.can_convert,false); assert.equal(view.duplicate_group_count,1);
    assert.equal(view.output_count,null); assert.deepEqual(view.rows,[]);
    assert.equal(view.groups[0].selected_source_record,null); assert.deepEqual(view.groups[0].source_records,[2,3]);
    assert.throws(()=>build(Buffer.from(data),p), /Duplicate keys/);
  }
  assert.equal(preview(Buffer.from('id,value\nx,a\ny,b\n'),p).can_convert,true);
  assert.equal(preview(Buffer.from('id,value\nx,a\nx,a\n'),p).conflict_group_count,0);
});

test('empty composite key components require explicit separate retention and whitespace is exact text', () => {
  const bytes = Buffer.from('id,visit,value\n,1,a\n,1,b\nx,,c\nx,,d\n ,1,e\n ,1,f\n');
  const p = {...simplePlan(),key_columns:['id','visit']};
  const blocked = preview(bytes,p); assert.equal(blocked.can_convert,false); assert.deepEqual(blocked.empty_key_records,[2,3,4,5]);
  assert.throws(()=>build(bytes,p), /Empty key/);
  p.empty_keys = 'keep-separate';
  const view = build(bytes,p).preview; assert.equal(view.output_count,5); assert.equal(view.duplicate_group_count,1);
  assert.deepEqual(view.groups.map(g=>g.source_records),[[2],[3],[4],[5],[6,7]]);
});

test('tuple encoding, case, Unicode forms, numeric-looking values and formulas never coerce or collide', () => {
  const bytes = Buffer.from('id,part,value\n"a,b",c,one\na,"b,c",two\n0,x,three\n00,x,four\nA,x,five\na,x,six\né,x,seven\né,x,eight\n=1+1,x,formula\n');
  const p = {...simplePlan(),key_columns:['id','part']};
  const output = parseCsv(build(bytes,p).files['consolidated.csv']);
  assert.equal(output.rows.length,9);
  assert.deepEqual(output.rows.map(r=>r.values.slice(0,-1)),parseCsv(bytes).rows.map(r=>r.values));
  const exotic=Buffer.from('id,value\n"a,月\n""b""",first\n"a,月\n""b""",last\n');
  assert.deepEqual(build(exotic,simplePlan()).preview.groups[0].source_records,[2,3]);
  assert.deepEqual(parseCsv(build(exotic,simplePlan()).files['consolidated.csv']).rows[0].values,['a,月\n"b"','last','3']);
});

test('mapped append output feeds consolidation without discarding prior source_id or source_record lineage', () => {
  const inputs = [{name:'a.csv',bytes:Buffer.from('id,value\nx,old\ny,same\n')}, {name:'b.csv',bytes:Buffer.from('id,value\nx,new\n')}];
  const appended = createAppendBundle(inputs,{contract_id:'moonfind.csv-append-plan.v1',columns:['id','value'],sources:inputs.map((_,i)=>({id:`wave-${i+1}`,mapping:['id','value'],...plan().source}))});
  const bundle = build(appended.files['appended.csv'],simplePlan(),'appended.csv');
  assert.deepEqual(parseCsv(bundle.files['consolidated.csv']).rows.map(r=>r.values),[['wave-2','2','x','new','4'],['wave-1','3','y','same','3']]);
  assert.deepEqual(bundle.files['source.csv'],appended.files['appended.csv']);
  assert.deepEqual(bundle.preview.groups[0].source_records,[2,4]);
});

test('strict plan, explicit permission, reserved headers and duplicate JSON keys fail closed', () => {
  for (const edit of [p=>p.key_columns=[],p=>p.key_columns=['participant','participant'],p=>p.key_columns=['Participant'],p=>p.duplicate_policy='merge',p=>p.empty_keys='group',p=>p.source.access='denied',p=>p.source.origin='',p=>p.extra=true,p=>p.contract_id='v2']) {
    const p=plan();edit(p);assert.throws(()=>build(input,p));
  }
  assert.throws(()=>build(input,plan(),'../source.csv'),/basename/);
  assert.throws(()=>build(Buffer.from(`id, ${SOURCE_RECORD_COLUMN} \nx,2\n`),simplePlan()),/Reserved/);
  assert.throws(()=>parsePlan(Buffer.from('{"key_columns":["id"],"key_columns":["value"]}')),/duplicate JSON key/);
  assert.throws(()=>build(Buffer.from('id,id\nx,y\n'),simplePlan()),/ambiguous/);
  assert.throws(()=>build(Buffer.from('id,value\nx\n'),simplePlan()),/record 2/);
  assert.throws(()=>build(Buffer.from([0xff]),simplePlan()),/UTF-8/);
});

test('header-only input and exact 31-column allowance preserve the ordinary CSV contract', () => {
  assert.equal(build(Buffer.from('id,value\n'),simplePlan()).preview.output_count,0);
  const headers = ['id',...Array.from({length:30},(_,i)=>`c${i}`)];
  const bytes = Buffer.from(headers.join(',')+'\n'+headers.map(()=> 'x').join(',')+'\n');
  assert.equal(parseCsv(build(bytes,simplePlan()).files['consolidated.csv']).columns.length,32);
  assert.throws(()=>build(Buffer.from([...headers,'extra'].join(',')+'\n'),simplePlan()),/31 input columns/);
});

test('input, record, plan, output and lineage bounds refuse before any bundle write', () => {
  assert.throws(()=>build(Buffer.alloc(LIMITS.source+1,97),simplePlan()),/UTF-8 input/);
  assert.throws(()=>build(Buffer.from('id\n'+'x\n'.repeat(513)),simplePlan()),/512 data records/);
  const p=simplePlan();p.key_columns=Array(9000).fill('id');assert.throws(()=>build(Buffer.from('id\nx\n'),p),/16 KiB/);
  const expanded=Buffer.from('id,value\nx,'+'a'.repeat(32740)+'\n');
  assert.ok(expanded.length<=LIMITS.source);
  const outputView=preview(expanded,simplePlan());assert.equal(outputView.can_convert,false);assert.ok(outputView.blockers.some(s=>s.includes('consolidated.csv exceeds')));
  const many=Buffer.from('id,value\n'+Array.from({length:200},(_,i)=>`k${i},v${i}`).join('\n')+'\n');
  const lineageView=preview(many,simplePlan());assert.equal(lineageView.can_convert,false);assert.ok(lineageView.blockers.some(s=>s.includes('provenance.json exceeds')));
  assert.throws(()=>build(many,simplePlan()),/provenance.json exceeds/);
});

test('real CLI inspect, preview and conversion preserve originals and refuse existing or symlink destinations', () => {
  const source=join(root,'fixtures/record-consolidation.csv'), planPath=join(root,'fixtures/record-consolidation-plan.json');
  const common=['--csv',source,'--plan',planPath];
  const inspected=cli('inspect','--csv',source);assert.equal(inspected.status,0,inspected.stderr);assert.equal(JSON.parse(inspected.stdout).rows.length,6);
  const shown=cli('preview',...common);assert.equal(shown.status,0,shown.stderr);assert.equal(JSON.parse(shown.stdout).can_convert,true);
  const out=join(scratch,'bundle');const converted=cli('convert',...common,'--out-dir',out);assert.equal(converted.status,0,converted.stderr);
  assert.deepEqual(readFileSync(join(out,'consolidated.csv')),build(input,plan()).files['consolidated.csv']);
  assert.notEqual(cli('convert',...common,'--out-dir',out).status,0);
  assert.deepEqual(readFileSync(join(out,'source.csv')),input);assert.deepEqual(readFileSync(source),input);
  const link=join(scratch,'link');symlinkSync(out,link,'dir');assert.notEqual(cli('convert',...common,'--out-dir',link).status,0);
  assert.equal(statSync(out).mode & 0o777,0o700);assert.equal(statSync(join(out,'source.csv')).mode & 0o777,0o600);
  writeFileSync(join(evidence,'cli-result.json'),JSON.stringify({inspect:JSON.parse(inspected.stdout),preview:JSON.parse(shown.stdout),convert:JSON.parse(converted.stdout)},null,2));
});

test('policy-blocked CLI preview succeeds with groups; convert and malformed CLI never create output', () => {
  const p=plan();p.duplicate_policy='error';const path=join(scratch,'error-plan.json');writeFileSync(path,JSON.stringify(p));
  const out=join(scratch,'blocked'),common=['--csv',join(root,'fixtures/record-consolidation.csv'),'--plan',path];
  const shown=cli('preview',...common);assert.equal(shown.status,0,shown.stderr);assert.equal(JSON.parse(shown.stdout).can_convert,false);
  const failed=cli('convert',...common,'--out-dir',out);assert.notEqual(failed.status,0);assert.match(failed.stderr,/Duplicate keys/);assert.equal(existsSync(out),false);
  assert.notEqual(cli('preview',...common,'--out-dir',out).status,0);
  assert.notEqual(cli('inspect','--csv',common[1],'--csv',common[1]).status,0);
  writeFileSync(join(evidence,'blocked-preview.json'),shown.stdout);
});

test('retained production explorer imports consolidated rows and extracts source identity with selected evidence', () => {
  const retained=process.env.MOONFIND_RETAINED_UI;assert.ok(retained,'Set MOONFIND_RETAINED_UI');
  const bytes=readFileSync(retained),hash=createHash('sha256').update(bytes).digest('hex');
  assert.equal(hash,'831f79da21c3b3d27fb456a8d67c46a176584c14b27a6932af052f697b1ebb0e');
  const pins=JSON.parse(readFileSync(join(root,'fixtures/retained_ui_inputs.json'),'utf8'));assert.equal(pins.consumer_sha256,hash);
  for(const pin of pins.files)assert.equal(createHash('sha256').update(readFileSync(join(root,pin.path))).digest('hex'),pin.sha256,pin.path);
  const code=bytes.toString(),end=code.lastIndexOf('\n(() => {');assert.ok(end>0);
  const context=vm.createContext({console,TextEncoder,TextDecoder,URL,Blob,Buffer,setTimeout,clearTimeout});
  vm.runInContext(code.slice(0,end),context,{timeout:5000});
  const prefix='_M0FP36vectie18moonfind_2drabbita4main',ctor='_M0DTP36vectie18moonfind_2drabbita4main6CsvMsg';
  const run=s=>vm.runInContext(s,context,{timeout:2000});
  const bundle=build(input,plan()),output=bundle.files['consolidated.csv'],table=parseCsv(output);
  context.payload=JSON.stringify({...table,total_count:table.rows.length,source:{name:'consolidated.csv',origin:'Synthetic explicitly consolidated observations',captured_at:'2026-10-14',kind:'local-file',content_hex:output.toString('hex')}});
  run(`var view=${prefix}20initial__brief__view();view.pending=true;var parsed=_M0FPC14json13parse_2einner(new _M0TPC16string10StringView(payload,0,payload.length),100);if(parsed.$tag!==1)throw Error('parse failed');var reply=new _M0DTPC16result6ResultGRPB4JsonRPC15error5ErrorE2Ok(parsed._0);view=${prefix}17update__csv__view(undefined,new ${ctor}8Imported(view.generation,reply),view)._1;`);
  assert.equal(run('view.error'),undefined);
  run(`view=${prefix}17update__csv__view(undefined,new ${ctor}12SearchColumn(6),view)._1;view=${prefix}17update__csv__view(undefined,new ${ctor}6Filter('corrected'),view)._1;view=${prefix}17update__csv__view(undefined,new ${ctor}14SelectMatching(),view)._1;`);
  assert.deepEqual(JSON.parse(run('JSON.stringify(view.csv.selected)')),[2]);
  const extracted=run(`${prefix}18csv__extract__text(view.csv)`);assert.equal(extracted.$tag,1);
  assert.deepEqual(parseCsv(Buffer.from(extracted._0)).rows[0].values,['wave-b','2','001','baseline','no','corrected\nafter review','4']);
  assert.equal(bundle.preview.groups.find(g=>g.output_record===2).selected_source_record,4);
  writeFileSync(join(evidence,'explorer-selected.csv'),extracted._0);
  writeFileSync(join(evidence,'explorer-consumer.json'),JSON.stringify({retained_ui:retained,sha256:hash,executed:['Imported','SearchColumn','Filter','SelectMatching','csv_extract_text'],selected:[2],selected_input_record:4,limits:'Production reducers/extract executed with supplied intake JSON. Bootstrap skipped. No native host, browser mounting, persistence or installed qualification.'},null,2));
});
