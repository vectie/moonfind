import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import vm from 'node:vm';

const main = new URL('../ui/rabbita-moonfind/main/', import.meta.url);
const file = name => readFileSync(new URL(name, main), 'utf8');
function extern(source, name, globals = {}) {
  const start = source.indexOf(`extern "js" fn ${name}(`);
  assert.notEqual(start, -1, `Production extern ${name} exists`);
  const body = source.slice(start).split('\n///|')[0].split('\n')
    .filter(line => /^\s*#\|/.test(line)).map(line => line.replace(/^\s*#\|/, '')).join('\n');
  return vm.runInNewContext(`(${body})`, { TextDecoder, TextEncoder, Blob, ...globals });
}
const source = file('json_evidence_compare.mbt');
const intake = extern(file('json_evidence.mbt'), 'json_evidence_parse_mode');
const configure = extern(file('json_evidence_csv.mbt'), 'json_evidence_csv_fields_text');
const compare = extern(source, 'json_evidence_compare_text');
const beforeFixture = readFileSync(new URL('../fixtures/json-snapshot-before.json', import.meta.url), 'utf8');
const afterFixture = readFileSync(new URL('../fixtures/json-snapshot-after.jsonl', import.meta.url), 'utf8');
const hex = text => Buffer.from(text).toString('hex');
const descriptor = (slot, array_pointer = '') => ({ slot, name: `snapshot-${slot}.txt`, origin: `local-file:snapshot-${slot}`, captured_at: `2026-10-0${slot}T10:00:00Z`, kind: 'pasted-text', array_pointer });
function projections(text, pointers, array = '', lines = false) {
  return JSON.stringify(pointers.map(pointer => intake(hex(text), array, lines, pointer)));
}
function result(before, after, fields = ['/value'], options = {}) {
  const config = JSON.parse(configure(JSON.stringify(fields)));
  if (config.error) return config;
  const pointers = [options.key ?? '/id', ...config.fields];
  const metadata = { brief_id: 'revision-inspection', before: descriptor(1, options.beforeArray), after: descriptor(2, options.afterArray) };
  return JSON.parse(compare(projections(before, pointers, options.beforeArray, options.beforeLines), projections(after, pointers, options.afterArray, options.afterLines), JSON.stringify(metadata)));
}
function output(...args) {
  const response = result(...args);
  assert.equal(response.error, undefined);
  assert.ok(response.comparison);
  return JSON.parse(response.comparison.text);
}
function fixtureResult() {
  return result(beforeFixture, afterFixture, ['/interview/outcome', '/metrics/count'], { beforeArray: '/observations', afterLines: true });
}

test('operator workflow: compare JSON to JSONL, reopen a real comparison file and trace every changed value', () => {
  const response = fixtureResult();
  assert.equal(response.error, undefined);
  const temp = mkdtempSync(join(tmpdir(), 'moonfind-snapshot-'));
  try {
    const path = join(temp, 'comparison.json');
    writeFileSync(path, response.comparison.text);
    const report = JSON.parse(readFileSync(path, 'utf8'));
    assert.equal(report.contract_id, 'moonfind.json-snapshot-comparison.v1');
    assert.deepEqual(report.counts, { added: 1, removed: 1, changed: 2, unchanged_fields: 1 });
    assert.deepEqual(report.records.map(row => row.status), ['changed', 'unchanged_fields', 'removed', 'changed', 'added']);
    const change = report.records[0];
    assert.equal(change.before.source_pointer, '/observations/0');
    assert.equal(change.after.source_line, 3);
    assert.equal(change.after.source_record, 2);
    assert.deepEqual(change.changed_fields, ['/interview/outcome', '/metrics/count']);
    assert.equal(change.before.fields[1].raw, '9007199254740993');
    assert.equal(change.after.fields[1].raw, '9007199254740994');
    assert.equal(report.records[2].after, null);
    assert.equal(report.records[4].before, null);
    assert.equal(report.records[3].before.fields[0].kind, 'missing');
    assert.equal(report.records[3].after.fields[0].kind, 'null');
    assert.deepEqual(report.field_pointers, ['/interview/outcome', '/metrics/count']);
    assert.equal(report.sources.before.array_pointer, '/observations');
    assert.equal(report.sources.after.array_pointer, null);
    assert.equal(report.sources.after.format, 'jsonl');
    assert.equal(response.comparison.text.includes('private_note'), false);
    assert.equal(response.comparison.text.includes('new private note'), false);
  } finally { rmSync(temp, { recursive: true, force: true }); }
  assert.equal(readFileSync(new URL('../fixtures/json-snapshot-before.json', import.meta.url), 'utf8'), beforeFixture);
});

test('typed keys do not pair a numeric ID with a string or boolean ID', () => {
  const report = output('[{"id":1,"value":"n"},{"id":"1","value":"s"},{"id":true,"value":"b"}]', '[{"id":true,"value":"b"},{"id":1,"value":"n2"},{"id":"1","value":"s"}]');
  assert.deepEqual(report.records.map(row => [row.before.key.kind, row.after.source_record, row.status]), [['number', 2, 'changed'], ['string', 3, 'unchanged_fields'], ['boolean', 1, 'unchanged_fields']]);
});

test('numeric key spelling and large key tokens remain exact without floating-point pairing', () => {
  const text = '[{"id":9007199254740993},{"id":9007199254740992},{"id":1},{"id":1.0},{"id":1e0},{"id":-0},{"id":0}]';
  const report = output(text, text);
  assert.equal(report.counts.unchanged_fields, 7);
  assert.deepEqual(report.records.map(row => row.before.key.raw), ['9007199254740993', '9007199254740992', '1', '1.0', '1e0', '-0', '0']);
  assert.deepEqual(output('[{"id":1}]', '[{"id":1.0}]').counts, { added: 1, removed: 1, changed: 0, unchanged_fields: 0 });
});

test('string keys match decoded escapes but keep original tokens on each side', () => {
  const report = output('[{"id":"a\\u0062","value":1}]', '[{"id":"ab","value":1}]');
  assert.equal(report.counts.unchanged_fields, 1);
  assert.equal(report.records[0].before.key.raw, '"a\\u0062"');
  assert.equal(report.records[0].after.key.raw, '"ab"');
});

test('case, whitespace and Unicode normalization are not silently applied to keys', () => {
  const report = output(JSON.stringify([{ id: 'Cafe' }, { id: 'café' }, { id: ' x' }]), JSON.stringify([{ id: 'cafe' }, { id: 'cafe\u0301' }, { id: 'x' }]));
  assert.equal(report.counts.added, 3); assert.equal(report.counts.removed, 3);
});

test('ambiguous duplicate keys report both source records instead of guessing a join', () => {
  const invalid = '[{"id":"a\\u0062"},{"id":"ab"}]';
  for (const [before, after, label] of [[invalid, '[]', 'Before'], ['[]', invalid, 'After']]) {
    const response = result(before, after);
    assert.match(response.error, new RegExp(`${label} records 1 and 2: duplicate string key`));
    assert.equal(response.comparison, undefined);
  }
});

test('absent, blocked, null, empty and container keys require an operator repair', () => {
  const text = '[{"id":null}]';
  assert.match(result(text, '[]').error, /key is null/);
  assert.match(result('[{}]', '[]').error, /key is missing/);
  assert.match(result('[{"id":""}]', '[]').error, /key is empty-string/);
  assert.match(result('[{"id":{}}]', '[]').error, /key is object/);
  assert.match(result('[{"id":null}]', '[]', ['/value'], { key: '/id/nested' }).error, /key is blocked/);
});

test('missing, blocked, null and empty field values remain distinct in the change record', () => {
  const before = '[{"id":1},{"id":2,"x":null},{"id":3,"x":{"v":null}},{"id":4,"x":{"v":""}}]';
  const after = '[{"id":1,"x":null},{"id":2,"x":{"v":null}},{"id":3,"x":{"v":""}},{"id":4,"x":{}}]';
  const report = output(before, after, ['/x/v']);
  assert.deepEqual(report.records.map(row => [row.before.fields[0].kind, row.after.fields[0].kind]), [['missing', 'blocked'], ['blocked', 'null'], ['null', 'empty-string'], ['empty-string', 'missing']]);
  assert.equal(report.counts.changed, 4);
});

test('exact selected source tokens expose numeric spelling and container/escape changes', () => {
  const before = '[{"id":1,"value":1.0},{"id":2,"value":"a\\u0062"},{"id":3,"value":{"a":1,"b":2}},{"id":4,"value":[1, 2]}]';
  const after = '[{"id":1,"value":1e0},{"id":2,"value":"ab"},{"id":3,"value":{"b":2,"a":1}},{"id":4,"value":[1,2]}]';
  assert.equal(output(before, after).counts.changed, 4);
});

test('record reordering, outer formatting and unselected fields do not imply compared-value changes', () => {
  const report = output('[{"id":1,"value":5,"note":"old"},{"id":2,"value":6}]', '[\n { "value":6, "id":2 },\n { "id":1, "value":5, "note":"new" }\n]');
  assert.equal(report.counts.unchanged_fields, 2);
  assert.deepEqual(report.records.map(row => row.after.source_record), [2, 1]);
  assert.equal(JSON.stringify(report).includes('"note"'), false);
});

test('nested and escaped key/field pointers retain exact requested provenance', () => {
  const text = '[{"a/b":{"~key":["one"]},"":"empty member","__proto__":"ordinary"}]';
  const report = output(text, text, ['/', '/__proto__'], { key: '/a~1b/~0key/0' });
  assert.equal(report.key_pointer, '/a~1b/~0key/0');
  assert.deepEqual(report.records[0].before.fields.map(value => value.source_value_pointer), ['/0/', '/0/__proto__']);
  assert.equal(report.records[0].before.fields[1].text, 'ordinary');
});

test('empty arrays are explicit zero-record snapshots and added rows use after-source order', () => {
  const empty = output('[]', '[]');
  assert.deepEqual(empty.records, []);
  assert.deepEqual(empty.counts, { added: 0, removed: 0, changed: 0, unchanged_fields: 0 });
  const added = output('[]', '[{"id":"b"},{"id":"a"}]');
  assert.deepEqual(added.records.map(row => row.after.key.text), ['b', 'a']);
});

test('comparison errors for malformed intake, bad pointers and unsupported field configuration have no partial report', () => {
  assert.match(result('[{"id":1,"id":2}]', '[]').error, /Duplicate JSON object field/);
  assert.ok(result('[1]', '[]').error);
  assert.ok(result('[]', '[]', []).error);
  assert.ok(result('[]', '[]', ['/a', '/a']).error);
  assert.ok(result('[]', '[]', ['/a~2']).error);
  assert.match(result('[]', '[]', ['/value'], { key: '' }).error, /nonempty record key/);
});

test('JSONL-to-JSON comparison retains physical line gaps, ignores the JSONL array pointer and preserves chosen containers', () => {
  const report = output('\uFEFF\r\n{"id":"x","value":{"private":"chosen descendant"}}\r\n\r\n', '{"rows":[{"id":"x","value":{"private":"chosen descendant"}}]}', ['/value'], { beforeLines: true, beforeArray: '/ignored', afterArray: '/rows' });
  assert.equal(report.records[0].before.source_line, 2);
  assert.equal(report.records[0].before.source_pointer, null);
  assert.equal(report.sources.before.array_pointer, null);
  assert.equal(report.records[0].after.source_pointer, '/rows/0');
  assert.equal(report.records[0].after.fields[0].raw, '{"private":"chosen descendant"}');
});

test('record and field limits remain complete when the output fits the independent 1 MiB cap', () => {
  const text = JSON.stringify(Array.from({ length: 512 }, (_, id) => ({ id, value: id })));
  const fields = ['/value', '/a', '/b', '/c', '/d', '/e', '/f', '/g'];
  const report = output(text, text);
  assert.equal(report.records.length, 512); assert.equal(report.counts.unchanged_fields, 512);
  assert.equal(report.records.at(-1).before.key.raw, '511');
  const smaller = JSON.stringify(Array.from({ length: 32 }, (_, id) => ({ id, value: id })));
  const allFields = output(smaller, smaller, fields);
  assert.equal(allFields.records.length, 32);
  assert.equal(allFields.records.at(-1).before.fields.length, 8);
});

test('disjoint complete sources produce 1024 inspectable membership changes', () => {
  const before = JSON.stringify(Array.from({ length: 512 }, (_, id) => ({ id })));
  const after = JSON.stringify(Array.from({ length: 512 }, (_, id) => ({ id: id + 512 })));
  const report = output(before, after);
  assert.equal(report.records.length, 1024); assert.equal(report.counts.added, 512); assert.equal(report.counts.removed, 512);
  assert.equal(report.records.at(-1).after.key.raw, '1023');
});

test('expanded selected containers exceeding 1 MiB fail without truncating a comparison', () => {
  let value = '\\'.repeat(10000);
  for (let i = 0; i < 8; i++) value = { a: value };
  const text = JSON.stringify([{ id: 1, value }]);
  assert.ok(Buffer.byteLength(text) < 32768);
  const fields = Array.from({ length: 8 }, (_, i) => '/value' + '/a'.repeat(i));
  const response = result(text, text, fields);
  assert.match(response.error, /exceeds 1 MiB/); assert.equal(response.comparison, undefined);
});

test('source projection and descriptor mismatches cannot produce a mixed-source comparison', () => {
  const pointers = ['/id', '/value'];
  const good = projections('[{"id":1,"value":1}]', pointers);
  const mixed = JSON.parse(good);
  mixed[1] = intake(hex('[{"id":1,"value":2}]'), '', false, '/value');
  const metadata = { brief_id: 'test', before: descriptor(1), after: descriptor(2) };
  assert.match(JSON.parse(compare(JSON.stringify(mixed), good, JSON.stringify(metadata))).error, /same current source/);
  const changedLocator = JSON.parse(mixed[0]); changedLocator.lens.rows[0].source_line = 7;
  assert.match(JSON.parse(compare(JSON.stringify([JSON.stringify(changedLocator), JSON.parse(good)[1]]), good, JSON.stringify(metadata))).error, /source locator changed/);
  metadata.after.slot = 1;
  assert.match(JSON.parse(compare(good, good, JSON.stringify(metadata))).error, /different loaded source slots/);
});

function downloadHarness(fail = false) {
  const calls = [], timers = []; let blob;
  const link = { click() { calls.push('click'); if (fail) throw Error('blocked'); }, remove() { calls.push('remove'); } };
  const download = extern(source, 'json_evidence_compare_download', {
    URL: { createObjectURL(value) { blob = value; return 'blob:comparison'; }, revokeObjectURL(value) { assert.equal(value, 'blob:comparison'); calls.push('revoke'); } },
    document: { createElement(tag) { assert.equal(tag, 'a'); return link; }, body: { appendChild(value) { assert.equal(value, link); calls.push('append'); } } },
    setTimeout(fn, ms) { assert.equal(ms, 1000); timers.push(fn); },
  });
  return { download, calls, timers, link, get blob() { return blob; } };
}

test('production download creates exact UTF-8 Blob bytes, JSON MIME and filename at a controlled DOM boundary', async () => {
  const text = fixtureResult().comparison.text;
  const h = downloadHarness(); assert.equal(h.download(text), '');
  assert.equal(h.link.download, 'moonfind-json-snapshot-comparison.json');
  assert.equal(h.blob.type, 'application/json;charset=utf-8');
  assert.deepEqual(Buffer.from(await h.blob.arrayBuffer()), Buffer.from(text));
  assert.equal(JSON.parse(await h.blob.text()).counts.changed, 2);
  h.timers.forEach(fn => fn()); assert.deepEqual(h.calls, ['append', 'click', 'remove', 'revoke']);
});

test('a failed download remains retryable without modifying comparison sources or settings', () => {
  const text = fixtureResult().comparison.text;
  const h = downloadHarness(true);
  assert.match(h.download(text), /sources and comparison settings remain available/);
  h.timers.forEach(fn => fn()); assert.equal(h.calls.at(-1), 'revoke');
  assert.equal(fixtureResult().comparison.text, text);
  assert.equal(downloadHarness().download(text), '');
});

test('source wiring only: explicit before/after controls feed a live current comparison and download', () => {
  const view = file('json_evidence_compare_view.mbt');
  const reducer = file('json_evidence.mbt');
  assert.match(file('json_evidence_view.mbt'), /json_evidence_comparison_panel\(emit, view\)/);
  for (const action of ['CompareSource', 'CompareLines', 'CompareField', 'DownloadComparison']) assert.ok(view.includes(action));
  assert.match(view, /let comparison = json_evidence_comparison\(view\)/);
  assert.match(reducer, /DownloadComparison => \{\s*let comparison = json_evidence_comparison\(view\)\s*let error = json_evidence_compare_download\(comparison.text\)/);
  assert.match(source, /before.content_hex, state.pointer, table.format == "jsonl", pointer/);
  assert.match(source, /after.content_hex, state.compare_pointer, state.compare_lines, pointer/);
  assert.equal(view.includes('innerHTML'), false);
});

test('source wiring only: pending/current-source guards and reset lifecycle prevent stale snapshot downloads', () => {
  const reducer = file('json_evidence.mbt');
  assert.ok(reducer.indexOf('if view.pending') < reducer.indexOf('DownloadComparison =>'));
  assert.ok(reducer.indexOf('let view = sync_json_evidence(view)') < reducer.indexOf('DownloadComparison =>'));
  assert.match(source, /view.draft.sources.get\(state.slot - 1\) == Some\(before\)/);
  assert.match(source, /view.draft.sources.get\(state.compare_slot - 1\) == Some\(after\)/);
  assert.match(reducer, /compare_source: view.draft.sources.get\(compare_slot - 1\)/);
  assert.match(reducer, /compare_slot: 0, compare_source: None/);
  const download = reducer.slice(reducer.indexOf('DownloadComparison =>'), reducer.indexOf('DownloadNdjson =>'));
  assert.equal(download.includes('selected:'), false);
  assert.equal(download.includes('brief_edited'), false);
});
