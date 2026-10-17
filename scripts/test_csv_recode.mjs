import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync, writeFileSync, mkdirSync, mkdtempSync} from 'node:fs';
import {resolve, dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import vm from 'node:vm';
import {createRecodeBundle as build} from './csv_recode.mjs';
import {parseCsv} from './csv_bibliography.mjs';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const input = readFileSync(join(root, 'fixtures/category-recode.csv'));
const plan = () => JSON.parse(readFileSync(join(root, 'fixtures/category-recode-plan.json')));
const evidence = process.env.MOONFIND_RECODE_EVIDENCE;
assert.ok(evidence, 'Set MOONFIND_RECODE_EVIDENCE to retained evidence directory');
mkdirSync(evidence, {recursive: true});
test('explicit many-to-one recoding preserves original data, context and logical records', () => {
  const result = build(input, plan()), original = parseCsv(input), derived = parseCsv(result.files['recoded.csv']);
  assert.deepEqual(derived.rows.map(r => r.values.slice(0, 3)), original.rows.map(r => r.values));
  assert.deepEqual(derived.rows.map(r => r.values[3]), ['agree', 'agree', 'disagree', 'unknown', 'unanswered', ' yes']);
  assert.deepEqual(derived.rows.map(r => r.record_number), [2,3,4,5,6,7]);
  assert.equal(result.preview.matched_count, 4); assert.equal(result.preview.unmatched_count, 2);
  assert.deepEqual(result.files['source.csv'], input);
  for (const [name, bytes] of Object.entries(result.files)) writeFileSync(join(evidence, name), bytes);
  writeFileSync(join(evidence, 'preview.json'), JSON.stringify(result.preview, null, 2));
});
test('unmatched policies are explicit and never alter original cells', () => {
  const p = plan(); p.unmatched = 'empty';
  assert.deepEqual(build(input, p).preview.rows.map(r => r.values[3]), ['agree','agree','disagree','','unanswered','']);
  p.unmatched = 'error'; assert.throws(() => build(input, p), /record 5/);
  p.mappings.push({from:'unknown',to:'other'}, {from:' yes',to:'agree'});
  assert.equal(build(input,p).preview.unmatched_count, 0);
});
test('quoted multiline Unicode values, false-like and zero-like strings are exact', () => {
  const p = plan(); p.column = 'response'; p.mappings = [{from:'a,月\n"b"',to:'分组,"A"\nnext'},{from:'0',to:'zero'}];
  const result = build(Buffer.from('response\r\n"a,月\n""b"""\r\n0\r\nfalse\r\n'),p);
  assert.deepEqual(parseCsv(result.files['recoded.csv']).rows.map(r=>r.values), [['a,月\n"b"','分组,"A"\nnext'],['0','zero'],['false','false']]);
});
test('ambiguous mapping and output choices are refused', () => {
  for (const edit of [p=>p.mappings.push({from:'Y',to:'other'}), p=>p.output_column=' response ', p=>p.column='missing', p=>p.unmatched='guess', p=>p.source.access='denied']) {
    const p=plan();edit(p);assert.throws(()=>build(input,p));
  }
});
const scratch = mkdtempSync(join(evidence, 'cli-'));
const cli = (...args) => spawnSync(process.execPath, [join(root,'scripts/csv_recode.mjs'),...args], {encoding:'utf8',timeout:3000});
test('real CLI inspect, preview and convert produce usable bundle; existing destination remains intact', () => {
  const common=['--csv',join(root,'fixtures/category-recode.csv'),'--plan',join(root,'fixtures/category-recode-plan.json')];
  const inspect=cli('inspect','--csv',join(root,'fixtures/category-recode.csv'));assert.equal(inspect.status,0,inspect.stderr);
  const preview=cli('preview',...common);assert.equal(preview.status,0,preview.stderr);assert.equal(JSON.parse(preview.stdout).matched_count,4);
  const out=join(scratch,'bundle');const converted=cli('convert',...common,'--out-dir',out);assert.equal(converted.status,0,converted.stderr);
  assert.deepEqual(readFileSync(join(out,'recoded.csv')),build(input,plan()).files['recoded.csv']);
  assert.notEqual(cli('convert',...common,'--out-dir',out).status,0);
  assert.deepEqual(readFileSync(join(out,'source.csv')),input);
  writeFileSync(join(evidence,'cli-result.json'),JSON.stringify({inspect:JSON.parse(inspect.stdout),preview:JSON.parse(preview.stdout),converted:JSON.parse(converted.stdout)},null,2));
});
test('retained production CSV explorer selects and extracts newly recoded category', () => {
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
  const output=build(input,plan()).files['recoded.csv'],table=parseCsv(output);
  context.payload=JSON.stringify({...table,total_count:table.rows.length,source:{name:'recoded.csv',origin:'Synthetic recoded categories',captured_at:'2026-10-14',kind:'local-file',content_hex:output.toString('hex')}});
  run(`var view=${prefix}20initial__brief__view();view.pending=true;var parsed=_M0FPC14json13parse_2einner(new _M0TPC16string10StringView(payload,0,payload.length),100);if(parsed.$tag!==1)throw Error('parse failed');var reply=new _M0DTPC16result6ResultGRPB4JsonRPC15error5ErrorE2Ok(parsed._0);view=${prefix}17update__csv__view(undefined,new ${ctor}8Imported(view.generation,reply),view)._1;`);
  assert.equal(run('view.error'),undefined);
  // SearchColumn is one-based, zero denotes all columns. Existing Filter uses substring matching.
  run(`view=${prefix}17update__csv__view(undefined,new ${ctor}12SearchColumn(4),view)._1;view=${prefix}17update__csv__view(undefined,new ${ctor}6Filter('unanswered'),view)._1;view=${prefix}17update__csv__view(undefined,new ${ctor}14SelectMatching(),view)._1;`);
  assert.deepEqual(JSON.parse(run('JSON.stringify(view.csv.selected)')),[6]);
  const extracted=run(`${prefix}18csv__extract__text(view.csv)`);assert.equal(extracted.$tag,1);
  assert.deepEqual(parseCsv(Buffer.from(extracted._0)).rows[0].values,['005','','fifth','unanswered']);
  writeFileSync(join(evidence,'explorer-selected.csv'),extracted._0);
  writeFileSync(join(evidence,'explorer-consumer.json'),JSON.stringify({retained_ui:retained,sha256:hash,executed:['Imported','SearchColumn','Filter','SelectMatching','csv_extract_text'],selected:[6],limits:'Production reducers/extract executed. Supplied intake JSON; bootstrap skipped. No native host, browser mounting, persistence or installed qualification.'},null,2));
});
