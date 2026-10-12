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
const breakdown = extern(file('json_evidence_pairs.mbt'), 'json_evidence_pairs_text');
const ndjson = extern(file('json_evidence_ndjson.mbt'), 'json_evidence_ndjson_text');
const hex = text => Buffer.from(text, 'utf8').toString('hex');
const project = (text, field, pointer = '', lines = false) => intake(hex(text), pointer, lines, field);
function result(text, left = '/site', right = '/interview/outcome', pointer = '', lines = false) {
  return JSON.parse(breakdown(JSON.stringify([project(text, left, pointer, lines), project(text, right, pointer, lines)])));
}
function compare(text, left = '/site', right = '/interview/outcome', pointer = '', lines = false) {
  const response = result(text, left, right, pointer, lines);
  assert.equal(response.error, undefined);
  assert.ok(response.pairs);
  return response.pairs;
}
const fixture = readFileSync(new URL('../fixtures/json-value-pairs.json', import.meta.url), 'utf8');
const group = (pairs, first, second) => pairs.groups.find(g => g.first.display === first && g.second.display === second);
const output = (table, records) => JSON.parse(ndjson(JSON.stringify(table), JSON.stringify(records)));

test('research workflow: discover conflicting site/outcome pairs and extract exact source records', () => {
  const pairs = compare(fixture, '/site', '/interview/outcome', '/observations');
  assert.equal(pairs.total, 12);
  assert.equal(pairs.groups.length, 10);
  assert.equal(pairs.scalar_count, 7);
  assert.equal(pairs.gap_count, 5);
  assert.deepEqual(group(pairs, '"school"', '"unresolved"').records, [2, 5]);
  assert.deepEqual(group(pairs, '"school"', '"resolved"').records, [3]);
  const table = JSON.parse(project(fixture, '/site', '/observations')).table;
  const chosen = group(pairs, '"school"', '"unresolved"');
  const exported = output(table, chosen.records);
  assert.equal(exported.error, undefined);
  assert.equal(exported.record_count, 2);
  assert.ok(exported.text.includes('9007199254740993'));
  assert.ok(exported.text.includes('sch\\u006fol'));
  assert.equal(compare(exported.text, '/site', '/interview/outcome', '', true).groups[0].count, 2);
  assert.equal(fixture, readFileSync(new URL('../fixtures/json-value-pairs.json', import.meta.url), 'utf8'));
});

test('observed groups partition all records and retain first-observed order, not alphabetical or ranked order', () => {
  const pairs = compare(fixture, '/site', '/interview/outcome', '/observations');
  assert.deepEqual(pairs.groups.map(g => g.pair_number), Array.from({ length: 10 }, (_, i) => i + 1));
  assert.deepEqual(pairs.groups[0].records, [1]);
  assert.equal(pairs.groups[0].first.display, '"clinic"');
  assert.equal(pairs.groups[1].first.display, '"school"');
  assert.equal(pairs.groups.reduce((total, g) => total + g.count, 0), 12);
  assert.deepEqual(pairs.groups.flatMap(g => g.records).sort((a, b) => a - b), Array.from({ length: 12 }, (_, i) => i + 1));
  for (const g of pairs.groups) {
    assert.equal(g.count, g.records.length);
    assert.deepEqual(g.rows.map(row => row.record_number), g.records);
  }
});

test('missing, blocked, explicit null, empty string, false and zero are separate observed categories', () => {
  const source = '[{"a":{},"b":1},{"a":null,"b":1},{"a":{"v":null},"b":1},{"a":{"v":""},"b":1},{"a":{"v":false},"b":1},{"a":{"v":0},"b":1}]';
  const pairs = compare(source, '/a/v', '/b');
  assert.deepEqual(pairs.groups.map(g => g.first.kind), ['missing', 'blocked', 'null', 'string', 'boolean', 'number']);
  assert.equal(pairs.scalar_count, 4);
  assert.equal(pairs.gap_count, 2);
  assert.equal(pairs.groups[3].first.display, '""');
  assert.equal(pairs.groups[4].first.display, 'false');
  assert.equal(pairs.groups[5].first.display, '0');
  assert.equal(pairs.groups[0].rows[0].values[0].raw, '');
});

test('non-scalar fields group only by kind while their differing source tokens stay inspectable', () => {
  const source = '[{"a":[],"b":"x"},{"a":[1],"b":"x"},{"a":{},"b":"x"},{"a":{"x":1},"b":"x"}]';
  const pairs = compare(source, '/a', '/b');
  assert.equal(pairs.groups.length, 2);
  assert.deepEqual(pairs.groups.map(g => g.count), [2, 2]);
  assert.equal(pairs.scalar_count, 0);
  assert.equal(pairs.gap_count, 4);
  assert.deepEqual(pairs.groups[0].rows.map(row => row.values[0].raw), ['[]', '[1]']);
  assert.deepEqual(pairs.groups[1].rows.map(row => row.values[0].raw), ['{}', '{"x":1}']);
  for (const g of pairs.groups) {
    assert.equal(g.scalar, false);
    assert.match(g.first.display, /values not compared/);
  }
});

test('string groups decode escapes but preserve case, whitespace, Unicode and every exact source token', () => {
  const source = '[{"a":"A","b":"x"},{"a":"\\u0041","b":"x"},{"a":"a","b":"x"},{"a":" A ","b":"x"},{"a":"海 🌙\\n<script>inert</script>","b":"x"}]';
  const pairs = compare(source, '/a', '/b');
  assert.equal(pairs.groups.length, 4);
  assert.deepEqual(pairs.groups[0].records, [1, 2]);
  assert.deepEqual(pairs.groups[0].rows.map(row => row.values[0].raw), ['"A"', '"\\u0041"']);
  assert.equal(pairs.groups[3].first.display, '"海 🌙\\n<script>inert</script>"');
  assert.equal(compare('[{"a":"é","b":1},{"a":"é","b":1}]', '/a', '/b').groups.length, 2);
});

test('numeric pairs never round, coerce, normalize exponent spellings or merge negative zero', () => {
  const tokens = ['9007199254740992', '9007199254740993', '1', '1.0', '1e0', '-0', '0', '1e400', '1e-400'];
  const source = '[' + tokens.map(value => '{"a":' + value + ',"b":true}').join(',') + ']';
  const pairs = compare(source, '/a', '/b');
  assert.deepEqual(pairs.groups.map(g => g.first.display), tokens);
  assert.equal(pairs.scalar_count, tokens.length);
  assert.equal(compare('[{"a":1,"b":0},{"a":"1","b":0},{"a":true,"b":0}]', '/a', '/b').groups.length, 3);
});

test('pair identities cannot collide through delimiters, reserved keys or category-looking strings', () => {
  const source = '[{"a":"a|b","b":"c"},{"a":"a","b":"b|c"},{"a":"__proto__","b":"constructor"},{"a":"(missing path)","b":"x"},{"b":"x"},{"a":"null","b":"x"},{"a":null,"b":"x"}]';
  assert.equal(compare(source, '/a', '/b').groups.length, 7);
});

test('source pointers retain array indexes and literal escaped, empty and Unicode member names', () => {
  const source = '{"x/y":[{"a/b":{"~":{"":true}},"海":{"0":null}},{"a/b":{"~":{"":false}},"海":{"0":null}}]}';
  const pairs = compare(source, '/a~1b/~0/', '/海/0', '/x~1y');
  const row = pairs.groups[1].rows[0];
  assert.equal(row.record_number, 2);
  assert.equal(row.record_pointer, '/x~1y/1');
  assert.equal(row.values[0].value_pointer, '/x~1y/1/a~1b/~0/');
  assert.equal(row.values[1].value_pointer, '/x~1y/1/海/0');
});

test('JSONL pair drilldown preserves physical blank-line gaps and original selected order', () => {
  const source = '\uFEFF\r\n{"a":"x","b":1}\r\n\r\n{"a":"y","b":1}\r\n{"a":"x","b":1}\r\n';
  const pairs = compare(source, '/a', '/b', '', true);
  assert.deepEqual(pairs.groups[0].records, [1, 3]);
  assert.deepEqual(pairs.groups[0].rows.map(row => row.source_line), [2, 5]);
  assert.deepEqual(pairs.groups[0].rows.map(row => row.values[1].value_pointer), ['/b', '/b']);
  const table = JSON.parse(project(source, '/a', '', true)).table;
  assert.equal(output(table, pairs.groups[0].records).text, '{"a":"x","b":1}\n{"a":"x","b":1}\n');
});

test('every record is counted once when a field follows an array index, without exploding arrays', () => {
  const source = '[{"a":["x","y"],"b":true},{"a":[],"b":true},{"a":null,"b":true},{"a":{"0":"x"},"b":true}]';
  const pairs = compare(source, '/a/0', '/b');
  assert.equal(pairs.total, 4);
  assert.deepEqual(pairs.groups.map(g => g.records), [[1, 4], [2], [3]]);
});

test('empty input, repeated identical objects and all-absent fields remain honest observed counts', () => {
  const empty = compare('[]', '/a', '/b');
  assert.equal(empty.total, 0);
  assert.equal(empty.scalar_count, 0);
  assert.equal(empty.gap_count, 0);
  assert.deepEqual(empty.groups, []);
  const absent = compare('[{},{}]', '/a', '/b');
  assert.equal(absent.groups.length, 1);
  assert.deepEqual(absent.groups[0].records, [1, 2]);
  assert.equal(absent.gap_count, 2);
  assert.equal(compare('[{"a":1,"b":2},{"a":1,"b":2}]', '/a', '/b').groups[0].count, 2);
});

test('swapping fields reverses displayed dimensions without changing pair memberships or source order', () => {
  const forward = compare(fixture, '/site', '/interview/outcome', '/observations');
  const reverse = compare(fixture, '/interview/outcome', '/site', '/observations');
  assert.deepEqual(reverse.groups.map(g => g.records), forward.groups.map(g => g.records));
  assert.deepEqual(reverse.groups.map(g => g.first), forward.groups.map(g => g.second));
  assert.deepEqual(reverse.groups.map(g => g.second), forward.groups.map(g => g.first));
});

test('invalid, empty or identical field pointers are repairable and do not produce partial groups', () => {
  for (const fields of [['', '/b'], ['/a', ''], ['/a', '/a'], ['#/a', '/b'], ['/a/~2', '/b'], ['/' + 'x'.repeat(1024), '/b']]) {
    const response = result('[{"a":1,"b":2}]', ...fields);
    assert.ok(response.error);
    assert.equal(response.pairs, undefined);
  }
  assert.equal(compare('[{"a":1,"b":2}]', '/a', '/b').total, 1);
});

test('existing intake bounds apply; 512 distinct observed pairs fit without Cartesian expansion or truncation', () => {
  const source = '[' + Array.from({ length: 512 }, (_, i) => `{"a":${i},"b":${i}}`).join(',') + ']';
  const pairs = compare(source, '/a', '/b');
  assert.equal(pairs.total, 512);
  assert.equal(pairs.groups.length, 512);
  assert.equal(pairs.groups[511].rows[0].values[1].raw, '511');
  for (const text of ['[{"a":1,"a":2,"b":0}]', '[1]', '[' + Array(513).fill('{}').join(',') + ']', '[{"a":"' + 'x'.repeat(32768) + '","b":0}]']) {
    const response = result(text, '/a', '/b');
    assert.ok(response.error);
    assert.equal(response.pairs, undefined);
  }
});

test('two projections must refer to the same exact source table and row identities', () => {
  const left = project('[{"a":1,"b":2}]', '/a');
  const other = project('[{"a":1,"b":3}]', '/b');
  assert.match(JSON.parse(breakdown(JSON.stringify([left, other]))).error, /same current source/);
  const changed = JSON.parse(project('[{"a":1,"b":2}]', '/b'));
  changed.lens.rows[0].record_number = 2;
  assert.match(JSON.parse(breakdown(JSON.stringify([left, JSON.stringify(changed)]))).error, /identity changed/);
});

test('source wiring only: existing explorer exposes both fields, preview, evidence rows and exact-record continuation', () => {
  const view = file('json_evidence_pairs_view.mbt');
  assert.match(file('json_evidence_view.mbt'), /json_evidence_pairs_panel\(emit, state\)/);
  for (const event of ['PairPointer(0, value)', 'PairPointer(1, value)', 'PreviewPairs', 'SelectPair(group.pair_number)']) assert.ok(view.includes(event));
  assert.match(view, /value\.raw/);
  assert.match(view, /row\.source_line/);
  assert.match(view, /Every original field is included/);
  assert.match(view, /Counts describe this capture only/);
  assert.equal(view.includes('innerHTML'), false);
  assert.match(file('json_evidence_pairs.mbt'), /json_evidence_parse_mode\([\s\S]*source.content_hex, state.pointer, table.format == "jsonl", pointer/);
  assert.match(file('json_evidence_pairs.mbt'), /return group.records.copy\(\)/);
});

test('source wiring only: pending/current-source guards, preview invalidation and explicit replacement protect continuation', () => {
  const source = file('json_evidence.mbt');
  assert.ok(source.indexOf('if view.pending') < source.indexOf('PreviewPairs =>'));
  assert.ok(source.indexOf('let view = sync_json_evidence(view)') < source.indexOf('SelectPair(number) =>'));
  assert.match(source, /view.draft.sources.get\(state.slot - 1\) != Some\(source\)/);
  for (const event of ['ExploreLines =>', 'Pointer(pointer) =>', 'Explore =>']) {
    const section = source.slice(source.indexOf(event));
    assert.ok(section.indexOf('pairs: None') < section.indexOf('error: None'));
  }
  assert.match(source, /pair_first_pointer: pointer, pairs: None/);
  assert.match(source, /pair_second_pointer: pointer, pairs: None/);
  assert.match(source, /SelectPair\(number\) => \{[\s\S]*?pairs.first_pointer == state.pair_first_pointer[\s\S]*?pairs.second_pointer == state.pair_second_pointer[\s\S]*?json_evidence_pair_selection\(pairs, number\)[\s\S]*?selected, query: ""/);
});
