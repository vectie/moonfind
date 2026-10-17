import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {mkdirSync, mkdtempSync, readFileSync, readdirSync, statSync, symlinkSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import vm from 'node:vm';
import test from 'node:test';
import {createUnpivotBundle} from './csv_unpivot.mjs';
import {parseCsv, parsePlan} from './csv_bibliography.mjs';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const fixture = readFileSync(join(root, 'fixtures/survey-wide.csv'));
const planBytes = readFileSync(join(root, 'fixtures/survey-unpivot-plan.json'));
const plan = JSON.parse(planBytes);
const expected = JSON.parse(readFileSync(join(root, 'fixtures/survey-unpivot.expected.json')));
const json = bytes => JSON.parse(bytes.toString('utf8'));
const bytes = value => Buffer.from(value);
const build = (input = fixture, config = plan) => createUnpivotBundle(input, config, 'survey-wide.csv');
const csv = rows => bytes(rows.map(row => row.map(value => '"' + value.replaceAll('"', '""') + '"').join(',')).join('\r\n') + '\r\n');
const p = (records = [2]) => ({contract_id: 'moonfind.csv-unpivot-plan.v1', context_columns: ['id'],
  question_columns: ['q'], record_numbers: records, empty_policy: 'keep',
  source: {origin: 'Synthetic test', captured_at: '2026-10-13', restrictions: 'Invented', access: 'permitted'}});
// Independent quoted-output decoder, not the production CSV parser.
function readQuoted(input) {
  const text = input.toString('utf8'), rows = []; let index = 0;
  while (index < text.length) {
    const row = [];
    while (true) {
      assert.equal(text[index++], '"'); let cell = '';
      while (true) {
        assert.ok(index < text.length, 'unterminated field'); const c = text[index++];
        if (c !== '"') { cell += c; continue; }
        if (text[index] === '"') { cell += '"'; index++; } else break;
      }
      row.push(cell);
      if (text[index] === ',') { index++; continue; }
      assert.equal(text.slice(index, index + 2), '\r\n'); index += 2; break;
    }
    rows.push(row);
  }
  return rows;
}

test('wide survey becomes exact independent long-form fixture in source order', () => {
  const bundle = build();
  assert.deepEqual(readQuoted(bundle.files['answers.csv']), expected);
  assert.deepEqual(bundle.preview.rows.map(row => row.values), expected.slice(1));
  assert.equal(bundle.preview.candidate_cells, 4);
  assert.equal(bundle.preview.output_count, 4);
  assert.equal(expected[1][2], '001');
  assert.equal(expected[3][2], '001'); // Duplicate labels must not merge observations.
  assert.equal(bundle.files['source.csv'].subarray(0, 3).toString('hex'), 'efbbbf');
  assert.deepEqual(bundle.files['source.csv'], fixture);
});
test('provenance binds every derived row to exact source cell and duplicated context', () => {
  const bundle = build(), provenance = json(bundle.files['provenance.json']);
  assert.deepEqual(provenance.row_map, [[2,2,3],[3,2,4],[4,3,3],[5,3,4]]);
  assert.deepEqual(provenance.omitted_source_records, [4]);
  assert.deepEqual(provenance.unused_source_columns, [{number:5,name:'private_note'}]);
  assert.deepEqual(provenance.plan, plan);
  assert.deepEqual(provenance.context_mapping.map(c => c.source_column), [1,2]);
  const original = parseCsv(fixture);
  for (const [outputRecord, sourceRecord, sourceColumn] of provenance.row_map) {
    assert.equal(bundle.preview.rows[outputRecord - 2].values.at(-1), original.rows[sourceRecord - 2].values[sourceColumn - 1]);
  }
  const sha = b => 'sha256:' + createHash('sha256').update(b).digest('hex');
  assert.equal(provenance.source.digest, sha(fixture));
  assert.equal(provenance.derived.digest, sha(bundle.files['answers.csv']));
  for (const entry of json(bundle.files['manifest.json']).files) {
    assert.equal(entry.bytes, bundle.files[entry.name].length);
    assert.equal(entry.digest, sha(bundle.files[entry.name]));
  }
});
test('empty versus whitespace versus absent values have distinct outcomes', () => {
  const input = csv([['id','q'],['',''],['same',' '],['same','0'],['same','\t']]);
  const keep = p([2,3,4,5]);
  assert.deepEqual(build(input, keep).preview.rows.map(row => row.values.at(-1)), ['',' ','0','\t']);
  const omit = {...keep, empty_policy:'omit-empty'};
  const bundle = build(input, omit);
  assert.deepEqual(bundle.preview.rows.map(row => row.values.at(-1)), [' ','0','\t']);
  assert.deepEqual(bundle.preview.omitted_empty_cells, [[2,2]]);
  assert.deepEqual(json(bundle.files['provenance.json']).row_map, [[2,3,2],[3,4,2],[4,5,2]]);
  assert.throws(() => build(bytes('id,q\na\n'), p()), /fields/);
  assert.throws(() => build(csv([['id','q'],['a','']]), {...p(),empty_policy:'omit-empty'}), /no evidence rows/);
});
test('formula, markup, URLs, big IDs, Unicode and multiline text remain inert strings', () => {
  const values = ['=SUM(A1:A2)','<script>bad()</script>','javascript:bad()','https://example.invalid/a','9007199254740993','月😀\r\n"quote",comma','é','é'];
  const input = csv([['id','q'],...values.map(value => [value,value])]);
  const bundle = build(input,p(values.map((_,i)=>i+2)));
  assert.deepEqual(readQuoted(bundle.files['answers.csv']).slice(1).map(row=>row.slice(2)), values.map(value=>[value,'q',value]));
});
test('optional zero context columns leaves explicit source record/column identity', () => {
  const plan = {...p(),context_columns:[]};
  const bundle = build(csv([['id','q'],['ignored','value']]),plan);
  assert.deepEqual(bundle.preview.columns,['source_record','source_column','question','answer']);
  assert.deepEqual(bundle.preview.rows[0].values,['2','2','q','value']);
});
test('generated header namespace cannot collide with context or question text', () => {
  const input = csv([['source_record','context:question','question','answer'],['id','x','q','a']]);
  const plan = {...p(),context_columns:['source_record','context:question'],question_columns:['question','answer']};
  const bundle = build(input,plan);
  assert.equal(new Set(bundle.preview.columns).size,bundle.preview.columns.length);
  assert.deepEqual(bundle.preview.rows.map(row=>row.values.slice(-2)),[['question','q'],['answer','a']]);
});
test('blank/duplicate/normalized ambiguous headers and malformed input fail closed', () => {
  for (const source of ['id,q,q\na,b,c\n','id, q,q\na,b,c\n','id,é,é\na,b,c\n','id, \na,b\n','id,q\na,"unfinished','id,q\na,"x"tail\n','id,q\na,b,c\n']) assert.throws(()=>build(bytes(source),p()));
  assert.throws(()=>build(Buffer.from([0xff]),p()),/UTF-8/);
  assert.throws(()=>build(Buffer.alloc(32769,65),p()),/32768/);
});
test('explicit plan rejects unknown/extra/missing keys, overlaps and ambiguous selections', () => {
  const edits = [v=>v.contract_id='unknown',v=>v.extra=true,v=>delete v.empty_policy,v=>v.empty_policy='drop-blank',
    v=>v.question_columns=[],v=>v.question_columns=['absent'],v=>v.question_columns=['q','q'],v=>v.context_columns=['id','q'],
    v=>v.context_columns=['id','id'],v=>v.context_columns=null,v=>v.record_numbers=[],v=>v.record_numbers=[2,2],
    v=>v.record_numbers=[1],v=>v.record_numbers=[3],v=>v.record_numbers=['2'],v=>v.record_numbers=[2.5],
    v=>delete v.source.restrictions,v=>v.source.restrictions=' ',v=>v.source.access='denied',v=>v.source.access='unavailable',
    v=>v.source.captured_at='',v=>v.source.extra='bad'];
  for (const edit of edits) {const config=p();edit(config);assert.throws(()=>build(csv([['id','q'],['a','x']]),config));}
  assert.throws(()=>parsePlan(bytes('{"question_columns":[],"question_\\u0063olumns":[]}')),/duplicate/);
});
test('candidate expansion is bounded before empty omission or row construction', () => {
  const input=csv([['id','q','r'],...Array.from({length:257},(_,i)=>[String(i),'',''])]);
  const config={...p(Array.from({length:257},(_,i)=>i+2)),question_columns:['q','r'],empty_policy:'omit-empty'};
  assert.throws(()=>build(input,config),/selected records × question columns exceeds 512/);
});
test('512 generated rows pass while column expansion and UTF-8 repetition stay bounded', () => {
  const input=csv([['id','q'],...Array.from({length:512},()=>['a','x'])]);
  assert.equal(build(input,p(Array.from({length:512},(_,i)=>i+2))).preview.output_count,512);
  const headers=Array.from({length:32},(_,i)=>'c'+i);
  assert.throws(()=>build(csv([headers,headers]),{...p(),context_columns:headers.slice(0,29),question_columns:[headers[29]]}),/32 columns/);
  const wide=csv([['id','q','r','s'],['月'.repeat(5000),'1','2','3']]);
  assert.ok(wide.length<32768);
  assert.throws(()=>build(wide,{...p(),question_columns:['q','r','s']}),/Expanded CSV exceeds 32 KiB/);
});
test('changed original and changed empty policy change identities without mutating inputs', () => {
  const before = Buffer.from(fixture), beforePlan=structuredClone(plan), bundle=build();
  const changed=build(bytes(fixture.toString().replace('Unselected respondent retained','changed')));
  assert.deepEqual(changed.files['answers.csv'],bundle.files['answers.csv']);
  assert.notEqual(json(changed.files['provenance.json']).source.digest,json(bundle.files['provenance.json']).source.digest);
  assert.notDeepEqual(build(fixture,{...plan,empty_policy:'omit-empty'}).files['provenance.json'],bundle.files['provenance.json']);
  assert.deepEqual(fixture,before);assert.deepEqual(plan,beforePlan);
});
test('production CSV join consumes reshaped table and preserves source locators', () => {
  const source=readFileSync(join(root,'ui/rabbita-moonfind/main/csv_join.mbt'),'utf8');
  const body=source.slice(source.indexOf('extern "js" fn csv_join_preview_text(')).split('\n///|')[0].split('\n').filter(line=>/^\s*#\|/.test(line)).map(line=>line.replace(/^\s*#\|/,'')).join('\n');
  const joinPreview=vm.runInNewContext('('+body+')',{TextEncoder});
  const table=parseCsv(build().files['answers.csv']);
  const right=parseCsv(csv([['segment','criterion'],['clinic','time handoff'],['lab','repeat observation']]));
  const result=JSON.parse(joinPreview(JSON.stringify({...table,total_count:table.rows.length}),JSON.stringify({...right,total_count:right.rows.length}),4,1,'left','[2]'));
  assert.equal(result.error,undefined);assert.equal(result.preview.issue,'');
  assert.equal(result.preview.matched,4);
  const parsed=readQuoted(bytes(result.preview.text));
  assert.deepEqual(parsed.slice(1).map(row=>row.at(-1)),['time handoff','time handoff','repeat observation','repeat observation']);
  assert.deepEqual(parsed.slice(1).map(row=>row.slice(2,4)),[['2','3'],['2','4'],['3','3'],['3','4']]);
});
test('deterministic corpus roundtrips quoting and individual cell lineage', () => {
  const pool=['',' ','\n','\r\n','"',',','😀','月','0001','=1+1','é','é'];
  for(let seed=0;seed<60;seed++) {
    const data=Array.from({length:4},(_,row)=>[pool[(seed+row)%pool.length],pool[(seed*3+row)%pool.length],pool[(seed*7+row)%pool.length]]);
    const config={...p([5,2,4,3]),question_columns:['r','q']};
    const actual=readQuoted(build(csv([['id','q','r'],...data]),config).files['answers.csv']).slice(1);
    assert.deepEqual(actual,data.flatMap((row,index)=>[[''+(index+2),'2',row[0],'q',row[1]],[''+(index+2),'3',row[0],'r',row[2]]]));
  }
});

const base=process.env.MOONFIND_CSV_TEST_DIR||tmpdir();mkdirSync(base,{recursive:true});
const scratch=mkdtempSync(join(base,'unpivot-'));const csvPath=join(scratch,'survey-wide.csv'),planPath=join(scratch,'plan.json');
writeFileSync(csvPath,fixture);writeFileSync(planPath,planBytes);
const cli=(...args)=>spawnSync(process.execPath,[join(root,'scripts/csv_unpivot.mjs'),...args],{encoding:'utf8',timeout:1500,maxBuffer:1024*1024});
const convert=(dest,input=csvPath,config=planPath)=>cli('convert','--csv',input,'--plan',config,'--out-dir',dest);
test('actual CLI inspect/preview/convert writes exact files only in a new directory',()=>{
  assert.equal(cli('--help').status,0);
  const inspect=cli('inspect','--csv',csvPath);assert.equal(inspect.status,0,inspect.stderr);assert.equal(JSON.parse(inspect.stdout).rows.length,3);
  const preview=cli('preview','--csv',csvPath,'--plan',planPath);assert.equal(preview.status,0,preview.stderr);assert.equal(JSON.parse(preview.stdout).output_count,4);
  const directory=join(scratch,'bundle');const result=convert(directory);assert.equal(result.status,0,result.stderr);
  assert.deepEqual(readdirSync(directory).sort(),Object.keys(build().files).sort());
  for(const [name,expected] of Object.entries(build().files))assert.deepEqual(readFileSync(join(directory,name)),expected);
  assert.equal(JSON.parse(result.stdout).native_intake_save_run,false);
  assert.equal(convert(directory).status,1);
  assert.deepEqual(readFileSync(csvPath),fixture);assert.deepEqual(readFileSync(planPath),planBytes);
});
test('existing destination files/symlinks are refused without modifying targets',()=>{
  const file=join(scratch,'existing');writeFileSync(file,'keep');assert.equal(convert(file).status,1);assert.equal(readFileSync(file,'utf8'),'keep');
  const target=join(scratch,'target');mkdirSync(target);const link=join(scratch,'link');symlinkSync(target,link,'dir');assert.equal(convert(link).status,1);assert.deepEqual(readdirSync(target),[]);
});
test('invalid plans/options fail before output creation with no misleading stdout',()=>{
  const config=join(scratch,'bad.json');writeFileSync(config,JSON.stringify({...plan,source:{...plan.source,access:'denied'}}));
  const dest=join(scratch,'denied');const result=convert(dest,csvPath,config);assert.equal(result.status,1);assert.equal(result.stdout,'');assert.match(result.stderr,/permitted/);assert.throws(()=>statSync(dest),/ENOENT/);
  for(const args of [[],['inspect','--csv',csvPath,'--csv',csvPath],['preview','--csv',csvPath,'--plan',''],['convert','--csv',csvPath,'--plan',planPath,'--unknown',dest]]) assert.equal(cli(...args).status,1);
});
test('CSV and plan FIFOs without writers reject promptly before creating output',{skip:process.platform==='win32'},()=>{
  for(const part of ['csv','plan']) {
    const fifo=join(scratch,'fifo-'+part+(part==='csv'?'.csv':'.json'));const made=spawnSync('mkfifo',[fifo],{encoding:'utf8',timeout:1500});assert.equal(made.status,0,made.stderr);
    const dest=join(scratch,'fifo-output-'+part),result=convert(dest,part==='csv'?fifo:csvPath,part==='plan'?fifo:planPath);
    assert.equal(result.error,undefined);assert.equal(result.status,1);assert.equal(result.stdout,'');assert.match(result.stderr,/regular file/);assert.throws(()=>statSync(dest),/ENOENT/);
  }
});
