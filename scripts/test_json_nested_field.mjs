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
const intake = extern(file('json_evidence.mbt'), 'json_evidence_parse_mode');
const ndjson = extern(file('json_evidence_ndjson.mbt'), 'json_evidence_ndjson_text');
const hex = text => Buffer.from(text, 'utf8').toString('hex');
function response(text, fieldPointer, pointer = '', lines = false) {
  return JSON.parse(intake(hex(text), pointer, lines, fieldPointer));
}
function inspect(text, fieldPointer, pointer = '', lines = false) {
  const result = response(text, fieldPointer, pointer, lines);
  assert.equal(result.error, undefined);
  assert.ok(result.lens);
  return result;
}
const records = (lens, kind) => lens.buckets.find(bucket => bucket.kind === kind).records;
const exportRecords = (table, selection) => JSON.parse(ndjson(JSON.stringify(table), JSON.stringify(selection)));
const fixture = readFileSync(new URL('../fixtures/json-nested-field.json', import.meta.url), 'utf8');

test('research workflow: inspect nested interview outcomes and retain exact selected originals', () => {
  const { table, lens } = inspect(fixture, '/interview/outcome', '/observations');
  assert.equal(lens.pointer, '/interview/outcome');
  assert.equal(lens.total, 7);
  assert.deepEqual(records(lens, 'missing'), [4, 7]);
  assert.deepEqual(records(lens, 'blocked'), [5]);
  assert.deepEqual(records(lens, 'null'), [1]);
  assert.deepEqual(records(lens, 'empty-string'), [2]);
  assert.deepEqual(records(lens, 'string'), [3]);
  assert.deepEqual(records(lens, 'boolean'), [6]);
  const output = exportRecords(table, records(lens, 'missing'));
  assert.equal(output.error, undefined);
  assert.deepEqual(output.text.trim().split('\n').map(line => JSON.parse(line).id), ['school-2', 'school-3']);
  assert.ok(output.text.includes('"interview":{}'));
  assert.equal(fixture, readFileSync(new URL('../fixtures/json-nested-field.json', import.meta.url), 'utf8'));
});

test('each nested category partitions all source records, including records hidden by other UI state', () => {
  const { lens } = inspect(fixture, '/interview/outcome', '/observations');
  assert.deepEqual(lens.buckets.map(bucket => bucket.kind), ['missing', 'blocked', 'null', 'empty-string', 'string', 'number', 'boolean', 'array', 'object']);
  assert.equal(lens.buckets.reduce((sum, bucket) => sum + bucket.count, 0), 7);
  assert.deepEqual(lens.buckets.flatMap(bucket => bucket.records).sort((a, b) => a - b), [1, 2, 3, 4, 5, 6, 7]);
  for (const bucket of lens.buckets) assert.equal(bucket.count, bucket.records.length);
  assert.deepEqual(records(lens, 'number'), []);
});

test('nested numbers retain exact source spellings and do not use floating-point projection', () => {
  const tokens = ['9007199254740993', '-0', '1.2300', '1e+400'];
  const source = '[' + tokens.map(value => '{"detail":{"measurement":' + value + '}}').join(',') + ']';
  const { table, lens } = inspect(source, '/detail/measurement');
  assert.deepEqual(lens.rows.map(row => row.text), tokens);
  assert.deepEqual(lens.rows.map(row => row.raw), tokens);
  assert.deepEqual(records(lens, 'number'), [1, 2, 3, 4]);
  const output = exportRecords(table, records(lens, 'number'));
  assert.deepEqual(inspect(output.text, '/detail/measurement', '', true).lens.rows.map(row => row.raw), tokens);
});

test('strings expose decoded display and exact JSON token with escapes and inert source text', () => {
  const raw = '"  \\u0041 海 🌙\\n<script>inert</script> https://example.invalid  "';
  const { lens } = inspect('[{"detail":{"note":' + raw + '}}]', '/detail/note');
  assert.equal(lens.rows[0].raw, raw);
  assert.equal(lens.rows[0].text, JSON.parse(raw));
  assert.equal(lens.rows[0].kind, 'string');
});

test('array element inspection follows indexes without exploding or flattening source records', () => {
  const { table, lens } = inspect(fixture, '/visits/0/duration', '/observations');
  assert.equal(lens.total, 7);
  assert.equal(lens.rows[0].raw, '1.2300');
  assert.equal(lens.rows[0].value_pointer, '/observations/0/visits/0/duration');
  assert.deepEqual(records(lens, 'number'), [1]);
  assert.deepEqual(records(lens, 'string'), [3]);
  assert.deepEqual(records(lens, 'missing'), [2, 4, 5, 6, 7]);
  assert.equal(exportRecords(table, [1]).text, table.rows[0].raw + '\n');
});

test('missing ancestors and wrong-shape parents have distinct buckets from explicit null', () => {
  const source = '[{}, {"a":{}}, {"a":null}, {"a":false}, {"a":0}, {"a":""}, {"a":[]}, {"a":{"b":null}}]';
  const { lens } = inspect(source, '/a/b');
  assert.deepEqual(records(lens, 'missing'), [1, 2]);
  assert.deepEqual(records(lens, 'blocked'), [3, 4, 5, 6, 7]);
  assert.deepEqual(records(lens, 'null'), [8]);
  for (const row of lens.rows.slice(0, 7)) {
    assert.equal(row.text, ''); assert.equal(row.raw, '');
  }
});

test('empty strings, whitespace, false and empty containers retain meaningful shape differences', () => {
  const { lens } = inspect('[{"a":{"b":""}},{"a":{"b":" "}},{"a":{"b":false}},{"a":{"b":[]}},{"a":{"b":{}}}]', '/a/b');
  assert.deepEqual(lens.rows.map(row => row.kind), ['empty-string', 'string', 'boolean', 'array', 'object']);
  assert.deepEqual(lens.rows.map(row => row.raw), ['""', '" "', 'false', '[]', '{}']);
});

test('escaped, empty, Unicode and prototype-like member names are literal path segments', () => {
  const source = '[{"a/b":{"~key":{"":7}},"__proto__":{"constructor":{"海 🌙":"yes"}},"":false}]';
  assert.equal(inspect(source, '/a~1b/~0key/').lens.rows[0].raw, '7');
  assert.equal(inspect(source, '/__proto__/constructor/海 🌙').lens.rows[0].raw, '"yes"');
  assert.equal(inspect(source, '/').lens.rows[0].raw, 'false');
  const escapedOnce = '[{"~1":{"x":true}}]';
  assert.equal(inspect(escapedOnce, '/~01/x').lens.rows[0].raw, 'true');
});

test('object numeric keys differ from array indexes and unsupported array indexes are blocked', () => {
  const source = '[{"a":{"01":"object","-":"literal"}},{"a":["zero","one"]}]';
  for (const pointer of ['/a/01', '/a/-']) {
    const { lens } = inspect(source, pointer);
    assert.equal(lens.rows[0].kind, 'string');
    assert.equal(lens.rows[1].kind, 'blocked');
  }
  const { lens } = inspect(source, '/a/999999999999999999999999999999');
  assert.deepEqual(records(lens, 'missing'), [1, 2]);
});

test('JSONL nested inspection retains physical source lines and record-relative value pointers', () => {
  const source = '\uFEFF\r\n{"id":"one","a":{"b":null}}\r\n\r\n{"id":"two","a":{}}\r\n{"id":"three","a":{"b":0}}\r\n';
  const { table, lens } = inspect(source, '/a/b', '', true);
  assert.deepEqual(lens.rows.map(row => row.source_line), [2, 4, 5]);
  assert.deepEqual(lens.rows.map(row => row.record_number), [1, 2, 3]);
  assert.deepEqual(lens.rows.map(row => row.value_pointer), ['/a/b', '/a/b', '/a/b']);
  assert.deepEqual(lens.rows.map(row => row.record_pointer), ['', '', '']);
  assert.equal(exportRecords(table, records(lens, 'missing')).text, '{"id":"two","a":{}}\n');
});

test('absent-in-every-record paths and empty sources remain inspectable without invented values', () => {
  const empty = inspect('[]', '/detail/outcome').lens;
  assert.equal(empty.total, 0);
  assert.deepEqual(empty.rows, []);
  for (const bucket of empty.buckets) { assert.equal(bucket.count, 0); assert.deepEqual(bucket.records, []); }
  assert.deepEqual(records(inspect('[{},{}]', '/detail/outcome').lens, 'missing'), [1, 2]);
});

test('field inspection never changes the existing top-level table, repeated records or source order', () => {
  const source = '[{"a":{"b":1.20}},{"a":{"b":1.20}},{"a":{"b":"1.20"}}]';
  const ordinary = response(source, '').table;
  const first = inspect(source, '/a/b');
  inspect(source, '/a'); inspect(source, '/other');
  assert.deepEqual(first.table, ordinary);
  assert.deepEqual(records(first.lens, 'number'), [1, 2]);
  assert.equal(exportRecords(first.table, records(first.lens, 'number')).record_count, 2);
  assert.deepEqual(inspect(source, '/a/b'), first);
});

test('malformed pointer is a repairable error with no partial table or lens; repaired input works', () => {
  for (const pointer of ['#/a/b', 'a/b', '/a/~', '/a/~2', '/' + 'x'.repeat(1024)]) {
    const result = response(fixture, pointer, '/observations');
    assert.ok(result.error);
    assert.equal(result.table, undefined);
    assert.equal(result.lens, undefined);
  }
  assert.equal(inspect(fixture, '/interview/outcome', '/observations').lens.total, 7);
});

test('the shared intake bounds and duplicate-key rule still apply before nested inspection', () => {
  for (const source of ['[{"a":{"b":1,"b":2}}]', '[1]', '[' + Array(513).fill('{}').join(',') + ']', '[{"a":"' + 'x'.repeat(32768) + '"}]']) {
    const result = response(source, '/a/b');
    assert.ok(result.error);
    assert.equal(result.lens, undefined);
  }
  const source = '[' + Array(512).fill('{"a":{"b":0}}').join(',') + ']';
  assert.equal(inspect(source, '/a/b').lens.buckets.find(bucket => bucket.kind === 'number').count, 512);
});

test('source wiring only: field lens uses the shared parser and the actual explorer UI', () => {
  const helper = file('json_evidence_lens.mbt');
  assert.match(helper, /json_evidence_parse_mode\([\s\S]*source.content_hex,[\s\S]*state.pointer,[\s\S]*table.format == "jsonl",[\s\S]*state.lens_pointer,/);
  assert.match(file('json_evidence_view.mbt'), /json_evidence_lens_panel\(emit, state\)/);
  assert.match(helper, /JsonEvidence\(ExploreLens\)/);
  assert.match(helper, /JsonEvidence\(SelectLens\(bucket.kind\)\)/);
  assert.match(helper, /JsonEvidence\(Toggle\(row.record_number\)\)/);
  assert.match(helper, /return bucket.records.copy\(\)/);
  assert.match(helper, /Every original field is included/);
  assert.equal(helper.includes('innerHTML'), false);
});

test('source wiring only: current-source guards, reset events and replacement-selection behavior are connected', () => {
  const source = file('json_evidence.mbt');
  assert.ok(source.indexOf('if view.pending') < source.indexOf('ExploreLens =>'));
  assert.ok(source.indexOf('let view = sync_json_evidence(view)') < source.indexOf('ExploreLens =>'));
  assert.match(source, /view.draft.sources.get\(state.slot - 1\) != Some\(source\)/);
  assert.match(source, /LensPointer\(lens_pointer\) => \{[\s\S]*?lens_pointer, lens: None/);
  for (const event of ['ExploreLines =>', 'Pointer(pointer) =>', 'Explore =>']) {
    const section = source.slice(source.indexOf(event));
    assert.ok(section.indexOf('lens: None') < section.indexOf('error: None'));
  }
  assert.match(source, /SelectLens\(kind\) => \{[\s\S]*?state.table is Some\(_\) && state.lens is Some\(lens\)[\s\S]*?lens.pointer == state.lens_pointer[\s\S]*?json_evidence_lens_selection\(lens, kind\)[\s\S]*?json_evidence: \{ ..state, selected, query: "", \}/);
  assert.match(file('json_lines.mbt'), /json_evidence_parse_mode\(source.content_hex, "", true, ""\)/);
});
