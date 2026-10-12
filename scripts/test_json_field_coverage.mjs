import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';
const file = name => readFileSync(new URL('../ui/rabbita-moonfind/main/' + name, import.meta.url), 'utf8');
function extern(source, name) {
  const start = source.indexOf(`extern "js" fn ${name}(`);
  assert.notEqual(start, -1);
  const code = source.slice(start).split('\n///|')[0].split('\n')
    .filter(line => /^\s*#\|/.test(line)).map(line => line.replace(/^\s*#\|/, '')).join('\n');
  return vm.runInNewContext(`(${code})`, { TextDecoder, TextEncoder });
}
const intake = extern(file('json_evidence.mbt'), 'json_evidence_parse_mode');
const coverage = extern(file('json_evidence_coverage.mbt'), 'json_evidence_coverage_json');
const ndjson = extern(file('json_evidence_ndjson.mbt'), 'json_evidence_ndjson_text');
function parse(text, pointer = '', lines = false) {
  const result = JSON.parse(intake(Buffer.from(text).toString('hex'), pointer, lines));
  assert.equal(result.error, undefined);
  return result.table;
}
const inspect = (table, column = -1, kind = '') => JSON.parse(coverage(JSON.stringify(table), column, kind));
const fixture = readFileSync(new URL('../fixtures/json-field-coverage.json', import.meta.url), 'utf8');
const table = parse(fixture, '/observations');
const field = (result, name) => result.fields.find(value => value.field === name);
const bucket = (result, name, kind) => field(result, name).buckets.find(value => value.kind === kind);

test('fixture intake exposes source field order and exact all-source denominator', () => {
  const result = inspect(table);
  assert.deepEqual(result.fields.map(value => value.field), table.columns);
  for (const field of result.fields) {
    assert.equal(field.total, 5);
    assert.equal(field.buckets.reduce((sum, bucket) => sum + bucket.count, 0), 5);
    assert.equal(field.buckets.flatMap(bucket => bucket.records).length, 5);
  }
});

test('missing, null, empty strings and whitespace-only strings stay distinct', () => {
  const result = inspect(table);
  assert.deepEqual(bucket(result, 'outcome', 'missing').records, [4]);
  assert.deepEqual(bucket(result, 'outcome', 'null').records, [1]);
  assert.deepEqual(bucket(result, 'outcome', 'empty-string').records, [2]);
  assert.deepEqual(bucket(result, 'outcome', 'string').records, [3, 5]);
});

test('zero, false and empty containers count as present values, never missing', () => {
  const result = inspect(table);
  assert.deepEqual(bucket(result, 'count', 'number').records, [1, 2]);
  assert.deepEqual(bucket(result, 'count', 'string').records, [3]);
  assert.deepEqual(bucket(result, 'confirmed', 'boolean').records, [1]);
  assert.deepEqual(bucket(result, 'tags', 'array').records, [1]);
  assert.deepEqual(bucket(result, 'detail', 'object').records, [1]);
});

test('every coverage bucket selects exactly the classified records in source order', () => {
  for (const field of inspect(table).fields) for (const bucket of field.buckets) {
    assert.deepEqual(inspect(table, field.column, bucket.kind).selected, bucket.records);
  }
});

test('coverage selected records flow into the existing NDJSON output and intake unchanged', () => {
  const column = table.columns.indexOf('count');
  const selected = inspect(table, column, 'number').selected;
  const output = JSON.parse(ndjson(JSON.stringify(table), JSON.stringify(selected)));
  assert.equal(output.record_count, 2);
  assert.match(output.text, /9007199254740993/);
  assert.deepEqual(output.text.trim().split('\n').map(line => JSON.parse(line).id), ['clinic-1', 'clinic-2']);
  const reopened = parse(output.text, '', true);
  assert.deepEqual(inspect(reopened, reopened.columns.indexOf('outcome'), 'null').selected, [1]);
  assert.deepEqual(inspect(reopened, reopened.columns.indexOf('outcome'), 'empty-string').selected, [2]);
});

test('JSONL gaps retain physical source locators while selection uses record identities', () => {
  const source = parse('\uFEFF\n{"id":"one","value":null}\n\n{"id":"two"}\n{"id":"three","value":0}\n', '', true);
  const selected = inspect(source, source.columns.indexOf('value'), 'missing').selected;
  assert.deepEqual(selected, [2]);
  assert.equal(source.rows.find(row => selected.includes(row.record_number)).source_line, 4);
  assert.deepEqual(JSON.parse(ndjson(JSON.stringify(source), JSON.stringify(selected))).text, '{"id":"two"}\n');
});

test('field labels including empty names, escaped names and prototype-like names are literal', () => {
  const source = parse('[{"":null,"a/b~c":0,"__proto__":false,"海 🌙":""},{}]');
  const result = inspect(source);
  assert.deepEqual(result.fields.map(field => field.field), ['', 'a/b~c', '__proto__', '海 🌙']);
  assert.deepEqual(inspect(source, 2, 'boolean').selected, [1]);
  assert.deepEqual(inspect(source, 3, 'empty-string').selected, [1]);
});

test('nested fields do not enter the top-level denominator or imply missing nested values', () => {
  const source = parse('[{"detail":{"outcome":null}},{"detail":{}},{"detail":[]},{}]');
  const result = inspect(source);
  assert.deepEqual(result.fields.map(field => field.field), ['detail']);
  assert.deepEqual(bucket(result, 'detail', 'object').records, [1, 2]);
  assert.deepEqual(bucket(result, 'detail', 'array').records, [3]);
  assert.deepEqual(bucket(result, 'detail', 'missing').records, [4]);
});

test('search and old selection cannot change counts or the replacement selection', () => {
  const hidden = { ...table, query: 'school', selected: [1, 3, 5], visible_rows: [table.rows[2]] };
  assert.deepEqual(inspect(hidden), inspect(table));
  assert.deepEqual(inspect(hidden, table.columns.indexOf('outcome'), 'empty-string').selected, [2]);
  assert.deepEqual(inspect(hidden, table.columns.indexOf('outcome'), 'boolean').selected, []);
});

test('empty tables and empty object records do not invent fields', () => {
  for (const value of ['[]', '[{},{}]']) assert.deepEqual(inspect(parse(value)), { fields: [], selected: [] });
});

test('source tokens, cells and original fixture remain unchanged by repeated exploration', () => {
  const before = JSON.stringify(table);
  inspect(table); inspect(table, 2, 'number');
  assert.equal(JSON.stringify(table), before);
  assert.equal(readFileSync(new URL('../fixtures/json-field-coverage.json', import.meta.url), 'utf8'), fixture);
  const extreme = parse('[{"x":1e400},{"x":-0},{"x":1.2300},{"x":"1e400"}]');
  assert.deepEqual(inspect(extreme, 0, 'number').selected, [1, 2, 3]);
  assert.deepEqual(extreme.rows.map(row => row.cells[0].text), ['1e400', '-0', '1.2300', '1e400']);
});

test('changed table or invalid category returns repairable error with no partial selection', () => {
  const bad = structuredClone(table); bad.rows[0].record_number = 2;
  for (const result of [inspect(bad), inspect(table, 100, 'missing'), inspect(table, 0, 'truth'), inspect({ ...table, rows: Array(513).fill(table.rows[0]) })]) {
    assert.ok(result.error);
    assert.equal(result.selected, undefined);
    assert.equal(result.fields, undefined);
  }
});

test('maximum source field/record shape preserves a full source denominator', () => {
  const columns = Array.from({ length: 32 }, (_, i) => `f${i}`);
  const first = Object.fromEntries(columns.map(key => [key, 0]));
  const source = parse(JSON.stringify([first, ...Array.from({ length: 511 }, () => ({}))]));
  const result = inspect(source, 31, 'missing');
  assert.equal(result.fields.length, 32);
  assert.equal(result.fields[31].total, 512);
  assert.deepEqual(result.selected, Array.from({ length: 511 }, (_, i) => i + 2));
});

test('source wiring only: visible coverage uses current table and guarded replacement reducer', () => {
  const main = file('json_evidence.mbt'), helper = file('json_evidence_coverage.mbt');
  assert.match(file('json_evidence_view.mbt'), /json_evidence_coverage_panel\(emit, table\)/);
  assert.match(helper, /JsonEvidence\(SelectCoverage\(field.column, bucket.kind\)\)/);
  assert.match(helper, /Replace selection:/);
  assert.match(main, /SelectCoverage\(column, kind\) => \{[\s\S]*?guard state.table is Some\(table\)[\s\S]*?json_evidence_coverage_selection\(table, column, kind\)[\s\S]*?json_evidence: \{ ..state, selected, query: "", \}/);
  assert.ok(main.indexOf('if view.pending') < main.indexOf('SelectCoverage(column, kind) =>'));
  assert.ok(main.indexOf('let view = sync_json_evidence(view)') < main.indexOf('SelectCoverage(column, kind) =>'));
  assert.match(main, /view.draft.sources.get\(state.slot - 1\) != Some\(source\)/);
});
