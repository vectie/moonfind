import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const main = new URL('../ui/rabbita-moonfind/main/', import.meta.url);
const file = name => readFileSync(new URL(name, main), 'utf8');
function extern(name, fn) {
  const source = file(name);
  const start = source.indexOf(`extern "js" fn ${fn}(`);
  assert.notEqual(start, -1);
  const body = source.slice(start).split('\n///|')[0].split('\n')
    .filter(line => /^\s*#\|/.test(line)).map(line => line.replace(/^\s*#\|/, '')).join('\n');
  return vm.runInNewContext(`(${body})`, { TextDecoder, TextEncoder });
}
const parse = extern('json_evidence.mbt', 'json_evidence_parse_mode');
const ndjson = extern('json_evidence_ndjson.mbt', 'json_evidence_ndjson_text');
const csv = extern('json_evidence_csv.mbt', 'json_evidence_csv_text');
const pairs = extern('json_evidence_pairs.mbt', 'json_evidence_pairs_text');
const compare = extern('json_evidence_compare.mbt', 'json_evidence_compare_text');
const coverage = extern('json_evidence_coverage.mbt', 'json_evidence_coverage_json');
const fixture = '{"observations":{"10":{"site":"clinic","outcome":null,"count":9007199254740993},"2":{"site":"school","outcome":"pending","count":1e400},"a/b~c":{"site":"sch\\u006fol","outcome":"pending"},"":{"site":"clinic"}}}';
const project = (text, pointer = '/observations', field = '', lines = false) => parse(Buffer.from(text).toString('hex'), pointer, lines, field);
function table(text = fixture, pointer = '/observations') {
  const result = JSON.parse(project(text, pointer));
  assert.equal(result.error, undefined);
  return result.table;
}

test('keyed intake preserves source order, exact tokens and escaped member identity', () => {
  const result = table();
  assert.equal(result.format, 'json-object');
  assert.deepEqual(result.rows.map(r => r.pointer), ['/observations/10', '/observations/2', '/observations/a~1b~0c', '/observations/']);
  assert.deepEqual(result.rows.map(r => r.record_number), [1, 2, 3, 4]);
  assert.ok(result.rows[0].raw.includes('9007199254740993'));
  assert.ok(result.rows[1].raw.includes('1e400'));
  assert.ok(result.rows[2].raw.includes('sch\\u006fol'));
  assert.deepEqual(result.columns, ['site', 'outcome', 'count']);
  assert.equal(result.rows[3].cells[1].kind, 'missing');
});

test('nested field and value pairs continue into exact selected raw records', () => {
  const projections = ['/site', '/outcome'].map(field => project(fixture, '/observations', field));
  const result = JSON.parse(pairs(JSON.stringify(projections)));
  assert.equal(result.error, undefined);
  const group = result.pairs.groups.find(g => g.first.display === '"school"');
  assert.deepEqual(group.records, [2, 3]);
  assert.equal(group.rows[1].values[1].value_pointer, '/observations/a~1b~0c/outcome');
  const exported = JSON.parse(ndjson(JSON.stringify(table()), JSON.stringify(group.records)));
  assert.equal(exported.record_count, 2);
  const reopened = JSON.parse(project(exported.text, '', '', true)).table;
  assert.equal(reopened.rows.length, 2);
  assert.ok(reopened.rows[0].raw.includes('1e400'));
  assert.ok(reopened.rows[1].raw.includes('sch\\u006fol'));
});

test('coverage and projected CSV preserve keyed source pointers', () => {
  const result = JSON.parse(coverage(JSON.stringify(table()), 1, 'missing'));
  assert.equal(result.error, undefined);
  const exported = JSON.parse(csv(JSON.stringify([project(fixture, '/observations', '/site')]), '[1,3,4]'));
  assert.equal(exported.error, undefined);
  assert.ok(exported.csv.text.includes('/observations/a~1b~0c'));
  assert.ok(exported.csv.text.includes('/observations/10'));
});

test('retained exact source bytes reproject identically after dossier JSON round-trip', () => {
  const source = {name:'observations.json',origin:'User-selected local evidence',captured_at:'2026-10-15T00:00:00Z',kind:'local-file',content_hex:Buffer.from('\uFEFF'+fixture+'\r\n').toString('hex')};
  const restored = JSON.parse(JSON.stringify({sources:[source]})).sources[0];
  assert.deepEqual(restored, source);
  assert.equal(parse(restored.content_hex, '/observations', false, '/outcome'), parse(source.content_hex, '/observations', false, '/outcome'));
  assert.equal(JSON.parse(parse(restored.content_hex, '/observations', false, '')).table.format, 'json-object');
});

test('snapshot comparison retains keyed record and nested value locators without inferred keys', () => {
  const before = '{"a/b":{"id":"a","v":9007199254740993}}';
  const after = '{"different":{"id":"a","v":9007199254740994}}';
  const projections = text => JSON.stringify(['/id','/v'].map(field => project(text, '', field)));
  const descriptor = slot => ({slot,name:'observations.json',origin:'local',captured_at:'2026-10-15',kind:'local-file',array_pointer:''});
  const response = JSON.parse(compare(projections(before), projections(after), JSON.stringify({before:descriptor(1),after:descriptor(2)})));
  assert.equal(response.error, undefined);
  const report = JSON.parse(response.comparison.text);
  assert.equal(report.records[0].status, 'changed');
  assert.equal(report.records[0].before.source_pointer, '/a~1b');
  assert.equal(report.records[0].after.fields[0].source_value_pointer, '/different/v');
  assert.equal(report.records[0].before.fields[0].raw, '9007199254740993');
  assert.equal(report.sources.before.format, 'json-object');
});

test('empty, numeric, reserved, Unicode and escaped keys remain literal identities', () => {
  const result = table('{"__proto__":{},"constructor":{},"海 🌙":{},"01":{},"x\\u002fy":{},"":{}}', '');
  assert.deepEqual(result.rows.map(r => r.pointer), ['/__proto__','/constructor','/海 🌙','/01','/x~1y','/']);
  assert.equal(table('{}', '').rows.length, 0);
  assert.equal(table('{"a/b":{"~":{"":{"id":1}}}}', '/a~1b/~0').rows[0].pointer, '/a~1b/~0/');
});

test('mixed values, duplicate decoded keys, malformed pointers and invalid bytes fail atomically', () => {
  for (const text of ['{"a":{},"b":1}', '{"a":{},"b":[]}', '{"a":{},"b":null}', '{"a":{},"\\u0061":{}}', '{"a":{"x":1,"x":2}}', 'null', 'true', '{']) {
    const result = JSON.parse(project(text, ''));
    assert.ok(result.error, text);
    assert.equal(result.table, undefined);
  }
  for (const pointer of ['/missing', '/~2', '#/observations']) assert.ok(JSON.parse(project(fixture, pointer)).error);
  assert.ok(JSON.parse(parse('ff', '', false, '')).error);
  assert.ok(JSON.parse(parse('0', '', false, '')).error);
});

test('all source bounds still apply to keyed containers without silent truncation', () => {
  const keyed = n => '{'+Array.from({length:n}, (_,i) => JSON.stringify(String(i))+':{}').join(',')+'}';
  assert.equal(table(keyed(512), '').rows.length, 512);
  assert.ok(JSON.parse(project(keyed(513), '')).error);
  assert.ok(JSON.parse(project('{"a":{"text":"'+'x'.repeat(32768)+'"}}', '')).error);
  assert.ok(JSON.parse(project('{"a":{'+Array.from({length:33}, (_,i)=>'"f'+i+'":0').join(',')+'}}', '')).error);
  assert.ok(JSON.parse(project('{"a":'+'{"x":'.repeat(33)+'{}'+'}'.repeat(33)+'}', '')).error);
});

test('existing array and JSONL locators remain unchanged', () => {
  assert.equal(table('[{"x":1}]', '').format, 'json-array');
  assert.equal(table('[{"x":1}]', '').rows[0].pointer, '/0');
  const result = JSON.parse(project('\r\n{"x":1}\r\n', '', '', true)).table;
  assert.equal(result.format, 'jsonl');
  assert.equal(result.rows[0].source_line, 2);
});

test('source wiring only: retained source guards and explicit explorer controls remain visible', () => {
  const source = file('json_evidence.mbt');
  assert.match(source, /view.draft.sources.get\(state.slot - 1\) != Some\(source\)/);
  assert.match(source, /source_pointer/);
  assert.match(source, /sources: view.draft.sources \+ \[capture\]/);
  assert.match(file('json_evidence_view.mbt'), /Save and reopen the brief/);
  assert.match(file('json_evidence_view.mbt'), /keyed member names/);
});
