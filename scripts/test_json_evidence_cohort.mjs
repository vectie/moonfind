import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const main = new URL('../ui/rabbita-moonfind/main/', import.meta.url);
const file = name => readFileSync(new URL(name, main), 'utf8');
function extern(source, name) {
  const start = source.indexOf(`extern "js" fn ${name}(`);
  assert.notEqual(start, -1, `Production extern ${name} exists`);
  const body = source.slice(start).split('\n///|')[0].split('\n')
    .filter(line => /^\s*#\|/.test(line)).map(line => line.replace(/^\s*#\|/, '')).join('\n');
  return vm.runInNewContext(`(${body})`, { TextDecoder, TextEncoder });
}
const parse = extern(file('json_evidence.mbt'), 'json_evidence_parse_mode');
const combine = extern(file('json_evidence_cohort.mbt'), 'json_evidence_cohort_text');
const ndjson = extern(file('json_evidence_ndjson.mbt'), 'json_evidence_ndjson_text');
const fixture = readFileSync(new URL('../fixtures/json-evidence-cohort.json', import.meta.url), 'utf8');
const conditions = [['/site', '"school"'], ['/interview/outcome', '"unresolved"']];
function run(source, conditions, { pointer = '', lines = false, any = false } = {}) {
  const responses = conditions.map(([field]) => parse(Buffer.from(source).toString('hex'), pointer, lines, field));
  return JSON.parse(combine(JSON.stringify(responses), JSON.stringify(conditions.map(([, value]) => value)), any));
}
function inspect(source, conditions, options) {
  const response = run(source, conditions, options);
  assert.equal(response.error, undefined);
  return response.cohort;
}
function table(source, pointer = '', lines = false) {
  return JSON.parse(parse(Buffer.from(source).toString('hex'), pointer, lines, '')).table;
}
function output(source, selected, pointer = '', lines = false) {
  const result = JSON.parse(ndjson(JSON.stringify(table(source, pointer, lines)), JSON.stringify(selected)));
  assert.equal(result.error, undefined);
  return result.text;
}

test('research journey: preview school interviews with unresolved outcomes, extract and reopen exact original records', () => {
  const before = fixture;
  const cohort = inspect(fixture, conditions, { pointer: '/observations' });
  assert.deepEqual(cohort.matched, [1, 8]);
  assert.deepEqual(cohort.excluded, [2, 3, 6, 9]);
  assert.deepEqual(cohort.unresolved, [4, 5, 7, 10]);
  assert.equal(cohort.total, 10);
  assert.equal(cohort.mode, 'all');
  assert.deepEqual(cohort.conditions, conditions.map(([pointer, value]) => ({ pointer, value })));
  assert.equal(cohort.rows[7].record_pointer, '/observations/7');
  assert.equal(cohort.rows[7].values[1].value_pointer, '/observations/7/interview/outcome');
  const text = output(fixture, cohort.matched, '/observations');
  assert.ok(text.includes('9007199254740993'));
  const reopened = inspect(text, conditions, { lines: true });
  assert.deepEqual(reopened.matched, [1, 2]);
  assert.deepEqual(table(text, '', true).rows.map(row => JSON.parse(row.raw).id), ['school-1', 'school-6']);
  assert.equal(fixture, before);
});

test('All and Any apply explicit unknown logic and keep per-condition missing versus blocked reasons', () => {
  const all = inspect(fixture, conditions, { pointer: '/observations' });
  const any = inspect(fixture, conditions, { pointer: '/observations', any: true });
  assert.deepEqual(all.rows[3].results, ['match', 'missing']);
  assert.deepEqual(all.rows[4].results, ['match', 'blocked']);
  assert.equal(all.rows[3].status, 'unresolved');
  assert.equal(all.rows[4].values[1].raw, '');
  assert.deepEqual(any.matched, [1, 2, 3, 4, 5, 6, 7, 8]);
  assert.deepEqual(any.excluded, [9]);
  assert.deepEqual(any.unresolved, [10]);
  const falseAndUnknown = inspect('[{"a":false}]', [['/a', 'true'], ['/b', 'null']]);
  assert.deepEqual(falseAndUnknown.excluded, [1]);
  assert.deepEqual(inspect('[{"a":false}]', [['/a', 'true'], ['/b', 'null']], { any: true }).unresolved, [1]);
});

test('unresolved records can be retained separately without filling missing data or treating it as null', () => {
  const cohort = inspect(fixture, conditions, { pointer: '/observations' });
  const text = output(fixture, cohort.unresolved, '/observations');
  const records = text.trim().split('\n').map(line => JSON.parse(line));
  assert.deepEqual(records.map(row => row.id), ['school-3', 'school-4', 'unknown-site', 'unknown-interview']);
  assert.deepEqual(records[0].interview, {});
  assert.equal(records[1].interview, null);
  assert.equal(Object.hasOwn(records[3], 'interview'), false);
  const nulls = inspect(fixture, [['/interview/outcome', 'null']], { pointer: '/observations' });
  assert.deepEqual(nulls.matched, [6]);
  assert.deepEqual(nulls.unresolved, [4, 5, 10]);
});

test('one-condition workflow separates exact strings from numbers, booleans, nulls and containers', () => {
  const source = '[{"a":"true"},{"a":true},{"a":false},{"a":null},{"a":[]},{"a":{}},{"a":""}]';
  assert.deepEqual(inspect(source, [['/a', 'true']]).matched, [2]);
  assert.deepEqual(inspect(source, [['/a', '"true"']]).matched, [1]);
  assert.deepEqual(inspect(source, [['/a', '""']]).matched, [7]);
  assert.deepEqual(inspect(source, [['/a', 'false']]).matched, [3]);
  assert.deepEqual(inspect(source, [['/a', 'null']]).matched, [4]);
  assert.deepEqual(inspect(source, [['/a', '0']]).matched, []);
});

test('strings match decoded text exactly while preserving original escaped tokens and private sibling fields', () => {
  const source = '[{"a":"school","private":"kept"},{"a":"\\u0073chool"},{"a":"School"},{"a":" school"},{"a":"é"},{"a":"e\\u0301"}]';
  const cohort = inspect(source, [['/a', ' "\\u0073chool" ']]);
  assert.deepEqual(cohort.matched, [1, 2]);
  const text = output(source, cohort.matched);
  assert.ok(text.includes('"a":"\\u0073chool"'));
  assert.ok(text.includes('"private":"kept"'));
  assert.deepEqual(inspect(source, [['/a', '"é"']]).matched, [5]);
});

test('numeric equality uses exact source tokens without rounding, overflow or normalization', () => {
  const source = '[{"n":1},{"n":1.0},{"n":1e0},{"n":0},{"n":-0},{"n":9007199254740992},{"n":9007199254740993},{"n":1e400},{"n":"1"}]';
  assert.deepEqual(inspect(source, [['/n', ' 1.0 ']]).matched, [2]);
  assert.deepEqual(inspect(source, [['/n', '1']]).matched, [1]);
  assert.deepEqual(inspect(source, [['/n', '-0']]).matched, [5]);
  assert.deepEqual(inspect(source, [['/n', '9007199254740993']]).matched, [7]);
  assert.deepEqual(inspect(source, [['/n', '1e400']]).matched, [8]);
  assert.equal(output(source, [2, 5, 7, 8]), '{"n":1.0}\n{"n":-0}\n{"n":9007199254740993}\n{"n":1e400}\n');
});

test('JSONL selection keeps physical source lines and escaped nested/array pointers', () => {
  const source = '\uFEFF\n{"a/b":{"~x":[{"":"海 🌙"}]}}\r\n\r\n{"a/b":{"~x":[{"":"other"}]}}\n{"a/b":null}\n';
  const cohort = inspect(source, [['/a~1b/~0x/0/', '"海 🌙"']], { lines: true });
  assert.deepEqual(cohort.matched, [1]);
  assert.deepEqual(cohort.unresolved, [3]);
  assert.deepEqual(cohort.rows.map(row => row.source_line), [2, 4, 5]);
  assert.equal(cohort.rows[0].values[0].value_pointer, '/a~1b/~0x/0/');
  assert.equal(cohort.rows[0].record_pointer, '');
  assert.equal(output(source, cohort.matched, '', true), '{"a/b":{"~x":[{"":"海 🌙"}]}}\n');
});

test('repeated records remain distinct, all source rows partition once, and empty results remain explicit', () => {
  const source = '[{"a":true},{"a":true},{"a":false},{}]';
  const cohort = inspect(source, [['/a', 'true']]);
  assert.deepEqual(cohort.matched, [1, 2]);
  assert.deepEqual([...cohort.matched, ...cohort.excluded, ...cohort.unresolved].sort(), [1, 2, 3, 4]);
  assert.equal(output(source, cohort.matched), '{"a":true}\n{"a":true}\n');
  const empty = inspect('[]', [['/a', 'true']]);
  assert.equal(empty.total, 0);
  assert.deepEqual(empty.rows, []);
  assert.deepEqual(empty.matched, []);
});

test('repairable input errors return no partial cohort and repaired conditions use the same original source', () => {
  for (const conditions of [[['/site', 'school']], [['/site', '{}']], [['/site', '[]']], [['site', '"school"']], [['', 'null']], [['/site', '"school"'], ['/bad~2', 'null']]]) {
    const result = run(fixture, conditions, { pointer: '/observations' });
    assert.ok(result.error);
    assert.equal(result.cohort, undefined);
  }
  assert.deepEqual(inspect(fixture, [['/site', '"school"']], { pointer: '/observations' }).matched, [1, 3, 4, 5, 6, 8]);
});

test('shared capture bounds still apply to cohort intake and the supported 512-record source works', () => {
  const source = '[' + Array(512).fill('{"a":true}').join(',') + ']';
  assert.equal(inspect(source, [['/a', 'true']]).matched.length, 512);
  const response = run('[' + Array(513).fill('{"a":true}').join(',') + ']', [['/a', 'true']]);
  assert.ok(response.error);
  assert.equal(response.cohort, undefined);
});

test('source wiring only: cohort uses the existing parser, preview and replacement-selection into existing extract actions', () => {
  const helper = file('json_evidence_cohort.mbt');
  const view = file('json_evidence_cohort_view.mbt');
  const reducer = file('json_evidence.mbt');
  assert.match(helper, /json_evidence_parse_mode\(\s*source.content_hex, state.pointer, table.format == "jsonl", pointer,/);
  assert.match(file('json_evidence_view.mbt'), /json_evidence_cohort_panel\(emit, state\)/);
  assert.match(view, /JsonEvidence\(PreviewCohort\)/);
  assert.match(view, /JsonEvidence\(SelectCohort\("match"\)\)/);
  assert.match(view, /JsonEvidence\(SelectCohort\("unresolved"\)\)/);
  assert.match(reducer, /SelectCohort\(status\) => \{[\s\S]*?state.table is Some\(_\) && state.cohort is Some\(cohort\)[\s\S]*?json_evidence_cohort_selection\(cohort, status\)[\s\S]*?selected, query: ""/);
  assert.match(reducer, /Download => \{[\s\S]*?json_evidence_export\(view\)/);
  assert.match(reducer, /Add => \{[\s\S]*?let content = json_evidence_export\(view\)/);
  assert.match(view, /1, 1.0 and 1e0 are different/);
  assert.equal(view.includes('innerHTML'), false);
});

test('source wiring only: condition edits and source lifecycle invalidate preview while retaining appropriate selections', () => {
  const reducer = file('json_evidence.mbt');
  assert.ok(reducer.indexOf('if view.pending') < reducer.indexOf('PreviewCohort =>'));
  assert.ok(reducer.indexOf('let view = sync_json_evidence(view)') < reducer.indexOf('PreviewCohort =>'));
  for (const event of ['ExploreLines =>', 'Pointer(pointer) =>', 'Explore =>', 'CohortField(index, value) =>', 'CohortAny(any) =>']) {
    const section = reducer.slice(reducer.indexOf(event));
    assert.ok(section.indexOf('cohort: None') < section.indexOf('error: None'), event);
  }
  assert.match(reducer, /view.draft.sources.get\(state.slot - 1\) != Some\(source\)[\s\S]*?empty_json_evidence_view\(\)/);
  assert.match(file('json_evidence_cohort.mbt'), /!draft.second_pointer.is_empty\(\) \|\| draft.second_value.is_empty\(\)/);
  const edit = reducer.slice(reducer.indexOf('CohortField(index, value) =>'), reducer.indexOf('PreviewCohort =>'));
  assert.equal(edit.includes('selected:'), false);
});
