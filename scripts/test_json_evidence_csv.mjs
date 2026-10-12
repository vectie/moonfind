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
const source = file('json_evidence_csv.mbt');
const intake = extern(file('json_evidence.mbt'), 'json_evidence_parse_mode');
const configure = extern(source, 'json_evidence_csv_fields_text');
const projectCsv = extern(source, 'json_evidence_csv_text');
const fixture = readFileSync(new URL('../fixtures/json-projected-fields.json', import.meta.url), 'utf8');
const hex = text => Buffer.from(text, 'utf8').toString('hex');
function projections(text, fields, pointer = '', lines = false) {
  return fields.map(field => intake(hex(text), pointer, lines, field));
}
function result(text, fields, selected, pointer = '', lines = false) {
  const config = JSON.parse(configure(JSON.stringify(fields)));
  if (config.error) return config;
  return JSON.parse(projectCsv(JSON.stringify(projections(text, config.fields, pointer, lines)), JSON.stringify(selected)));
}
function output(...args) {
  const response = result(...args);
  assert.equal(response.error, undefined);
  assert.ok(response.csv);
  return response.csv;
}
// Independent strict CSV reader. It never invokes the production serializer
// or JSON parser and preserves CR/LF inside quoted fields verbatim.
function readCsv(text) {
  const rows = []; let row = [], field = '', state = 'start';
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (state === 'quoted') {
      if (ch === '"') {
        if (text[i + 1] === '"') { field += '"'; i++; } else state = 'closed';
      } else field += ch;
    } else if (state === 'start' && ch === '"') state = 'quoted';
    else if (ch === ',' && state === 'closed') { row.push(field); field = ''; state = 'start'; }
    else if (ch === '\r' && text[++i] === '\n' && state === 'closed') {
      row.push(field); rows.push(row); row = []; field = ''; state = 'start';
    } else assert.fail(`Unexpected CSV at ${i}, state ${state}`);
  }
  assert.equal(state, 'start'); assert.deepEqual(row, []);
  for (const cells of rows) assert.equal(cells.length, rows[0].length);
  return rows;
}
function decodedValue(row, fieldIndex) {
  const at = 3 + fieldIndex * 3;
  return row[at + 2] === 'apostrophe-prefix' ? row[at].slice(1) : row[at];
}
const fields = ['/site', '/interview/outcome', '/metrics/count'];

test('research workflow: select clinic evidence, project nested fields and reopen a real CSV file without private sibling fields', () => {
  const csv = output(fixture, fields, [6, 1, 3, 4, 5], '/observations');
  assert.equal(csv.record_count, 5); assert.equal(csv.field_count, 3);
  const temp = mkdtempSync(join(tmpdir(), 'moonfind-csv-'));
  try {
    const path = join(temp, 'selected-fields.csv');
    writeFileSync(path, csv.text);
    const rows = readCsv(readFileSync(path, 'utf8'));
    assert.deepEqual(rows.map(row => row[0]), ['source_record', '1', '3', '4', '5', '6']);
    assert.deepEqual(rows[0], ['source_record', 'source_line', 'source_pointer', ...fields.flatMap(field => [field + ' value', field + ' kind', field + ' encoding'])]);
    assert.equal(rows[1][2], '/observations/0');
    assert.equal(decodedValue(rows[1], 1), 'slow, needs "review"');
    assert.equal(decodedValue(rows[1], 2), '9007199254740993');
    assert.equal(csv.text.includes('private_note'), false);
    assert.equal(csv.text.includes('not projected'), false);
    assert.equal(csv.text.includes('resolved'), false);
  } finally { rmSync(temp, { recursive: true, force: true }); }
  assert.equal(readFileSync(new URL('../fixtures/json-projected-fields.json', import.meta.url), 'utf8'), fixture);
});

test('missing, blocked, null, empty text, false and zero remain independently interpretable', () => {
  const text = '[{}, {"a":null}, {"a":{}}, {"a":{"x":null}}, {"a":{"x":""}}, {"a":{"x":false}}, {"a":{"x":0}}]';
  const rows = readCsv(output(text, ['/a/x'], [1, 2, 3, 4, 5, 6, 7]).text).slice(1);
  assert.deepEqual(rows.map(row => row[4]), ['missing', 'blocked', 'missing', 'null', 'empty-string', 'boolean', 'number']);
  assert.deepEqual(rows.map(row => decodedValue(row, 0)), ['', '', '', 'null', '', 'false', '0']);
});

test('numeric spellings and numeric-looking strings retain their exact text and separate kinds', () => {
  const values = ['9007199254740993', '1.00', '1e400', '1e-9999', '-0', '"0012"', '"2026-10-12"'];
  const rows = readCsv(output('[' + values.map(value => '{"v":' + value + '}').join(',') + ']', ['/v'], values.map((_, i) => i + 1)).text).slice(1);
  assert.deepEqual(rows.map(row => decodedValue(row, 0)), ['9007199254740993', '1.00', '1e400', '1e-9999', '-0', '0012', '2026-10-12']);
  assert.deepEqual(rows.map(row => row[4]), ['number', 'number', 'number', 'number', 'number', 'string', 'string']);
  assert.equal(rows[4][5], 'apostrophe-prefix');
});

test('decoded strings, commas, quotes and embedded newlines survive an independent CSV reader', () => {
  const values = ['comma, quote " and\r\nnew line', '海 🌙', 'café', ' space ', 'sch\u006fol'];
  const text = JSON.stringify(values.map(value => ({ value })));
  const rows = readCsv(output(text, ['/value'], [1, 2, 3, 4, 5]).text).slice(1);
  assert.deepEqual(rows.map(row => decodedValue(row, 0)), values);
  const escaped = readCsv(output('[{"value":"sch\\u006fol"}]', ['/value'], [1]).text);
  assert.equal(escaped[1][3], 'school');
});

test('spreadsheet-sensitive values get an explicit reversible prefix rather than silent rewriting', () => {
  const values = ['=SUM(1,2)', ' +2', '-3', '@command', "'original", '\t=1', '\ntext', 'normal', '  normal'];
  const csv = output(JSON.stringify(values.map(value => ({ value }))), ['/value'], values.map((_, i) => i + 1));
  const rows = readCsv(csv.text).slice(1);
  assert.equal(csv.escaped_cells, 7);
  assert.deepEqual(rows.map(row => decodedValue(row, 0)), values);
  assert.deepEqual(rows.map(row => row[5]), [...Array(7).fill('apostrophe-prefix'), 'literal', 'literal']);
  rows.slice(0, 7).forEach(row => assert.ok(row[3].startsWith("'")));
});

test('objects and arrays are one chosen cell retaining original inner tokens, without flattening or truncation', () => {
  const text = '[{"x": { "private": "included by choosing container", "n": 9007199254740993 }}, {"x":[1.00,"a\\u0062"]}]';
  const rows = readCsv(output(text, ['/x'], [1, 2]).text);
  assert.equal(rows[1][3], '{ "private": "included by choosing container", "n": 9007199254740993 }');
  assert.equal(rows[2][3], '[1.00,"a\\u0062"]');
  assert.deepEqual(rows.slice(1).map(row => row[4]), ['object', 'array']);
});

test('JSONL output retains physical source lines through blank lines and BOM while selection uses record IDs', () => {
  const csv = output('\uFEFF\r\n{"v":"first"}\r\n\r\n{"v":"second"}\r\n', ['/v'], [2], '', true);
  const rows = readCsv(csv.text);
  assert.deepEqual(rows[1].slice(0, 3), ['2', '4', '']);
  assert.equal(rows[1][3], 'second');
});

test('field order and literal JSON Pointer keys preserve slash, tilde, empty and newline member names', () => {
  const pointers = ['/a~1b/~0x/0', '/', '/line\nbreak', '/__proto__'];
  const text = '[{"a/b":{"~x":["nested"]},"":"empty key","line\\nbreak":"line key","__proto__":"ordinary"}]';
  const rows = readCsv(output(text, pointers, [1]).text);
  assert.deepEqual(pointers.map((_, i) => decodedValue(rows[1], i)), ['nested', 'empty key', 'line key', 'ordinary']);
  assert.equal(rows[0][9], '/line\nbreak value');
});

test('repeated source records stay distinct; selection order and duplicate selected IDs do not reorder or duplicate rows', () => {
  const text = '[{"v":1},{"v":1},{"v":2}]';
  const csv = output(text, ['/v'], [3, 1, 3]);
  const rows = readCsv(csv.text);
  assert.deepEqual(rows.slice(1).map(row => row[0]), ['1', '3']);
  assert.equal(output(text, ['/v'], [1, 2]).record_count, 2);
});

test('only selected rows are exported independently of search or output field values', () => {
  const current = projections('[{"v":"hidden"},{"v":"visible"}]', ['/v']);
  const changed = current.map(raw => { const response = JSON.parse(raw); response.table.query = 'visible'; return JSON.stringify(response); });
  const csv = JSON.parse(projectCsv(JSON.stringify(changed), '[1]')).csv;
  assert.equal(readCsv(csv.text)[1][3], 'hidden');
});

test('repairable configuration and selection errors produce no partial CSV', () => {
  for (const config of ['not json', '[]', '["/a","/a"]', '["a"]', '["/a~2b"]', JSON.stringify(Array.from({ length: 9 }, (_, i) => '/' + i))]) {
    const response = JSON.parse(configure(config));
    assert.ok(response.error); assert.equal(response.fields, undefined);
  }
  for (const selected of [[], [2]]) {
    const response = result('[{"a":1}]', ['/a'], selected);
    assert.match(response.error, /Select at least one current/); assert.equal(response.csv, undefined);
  }
});

test('source changes and mismatched locator projections refuse mixed-source artifacts', () => {
  const first = projections('[{"a":1,"b":2}]', ['/a']);
  const other = projections('[{"a":1,"b":3}]', ['/b']);
  assert.match(JSON.parse(projectCsv(JSON.stringify([...first, ...other]), '[1]')).error, /same current source/);
  const response = JSON.parse(first[0]); response.lens.rows[0].source_line = 9;
  assert.match(JSON.parse(projectCsv(JSON.stringify([JSON.stringify(response)]), '[1]')).error, /identity changed/);
});

test('existing intake refuses malformed or duplicate-key sources before CSV generation', () => {
  for (const text of ['[{"a":1,"a":2}]', '[1]', '[{']) {
    const response = result(text, ['/a'], [1]);
    assert.ok(response.error); assert.equal(response.csv, undefined);
  }
});

test('maximum 512 selected records and eight requested fields export completely with unavailable fields visible', () => {
  const text = '[' + Array.from({ length: 512 }, (_, i) => '{"v":' + i + '}').join(',') + ']';
  const chosen = Array.from({ length: 512 }, (_, i) => i + 1);
  const csv = output(text, ['/v', ...Array.from({ length: 7 }, (_, i) => '/missing' + i)], chosen);
  assert.equal(csv.record_count, 512); assert.equal(csv.field_count, 8);
  const rows = readCsv(csv.text);
  assert.equal(rows.length, 513); assert.equal(rows[0].length, 27);
  assert.equal(rows[512][3], '511'); assert.equal(rows[512][7], 'missing');
});

function downloadHarness(failClick = false) {
  const calls = [], timers = []; let blob;
  const link = { click() { calls.push('click'); if (failClick) throw Error('blocked download'); }, remove() { calls.push('remove'); } };
  const download = extern(source, 'json_evidence_csv_download', {
    URL: { createObjectURL(value) { blob = value; return 'blob:csv-test'; }, revokeObjectURL(value) { assert.equal(value, 'blob:csv-test'); calls.push('revoke'); } },
    document: { createElement(tag) { assert.equal(tag, 'a'); return link; }, body: { appendChild(value) { assert.equal(value, link); calls.push('append'); } } },
    setTimeout(fn, ms) { assert.equal(ms, 1000); timers.push(fn); },
  });
  return { download, calls, timers, link, get blob() { return blob; } };
}

test('production download uses real UTF-8 CSV Blob bytes and requested filename at a controlled DOM boundary', async () => {
  const csv = output(fixture, fields, [1, 3], '/observations');
  const h = downloadHarness();
  assert.equal(h.download(csv.text), '');
  assert.equal(h.link.download, 'moonfind-selected-fields.csv');
  assert.equal(h.blob.type, 'text/csv;charset=utf-8');
  assert.deepEqual(Buffer.from(await h.blob.arrayBuffer()), Buffer.from(csv.text));
  assert.equal(readCsv(await h.blob.text()).length, 3);
  h.timers.forEach(fn => fn());
  assert.deepEqual(h.calls, ['append', 'click', 'remove', 'revoke']);
});

test('failed download retains data and cleans the allocated URL for a retryable outcome', () => {
  const csv = output(fixture, fields, [1], '/observations');
  const h = downloadHarness(true);
  assert.match(h.download(csv.text), /source, field pointers and selections remain available/);
  h.timers.forEach(fn => fn()); assert.equal(h.calls.at(-1), 'revoke');
  assert.equal(readCsv(csv.text).length, 2);
});

test('source wiring only: explorer exposes editable projection settings, current preview and standard download action', () => {
  const view = file('json_evidence_csv_view.mbt');
  assert.match(file('json_evidence_view.mbt'), /json_evidence_csv_panel\(emit, view\)/);
  assert.match(view, /on_input=emit\.map\(value => BriefAction\(JsonEvidence\(CsvFields\(value\)\)\)\)/);
  assert.match(view, /let csv = json_evidence_csv\(view\)/);
  assert.match(view, /emit\(BriefAction\(JsonEvidence\(DownloadCsv\)\)\)/);
  assert.match(view, /Import value columns as text/);
  assert.equal(view.includes('innerHTML'), false);
  assert.match(source, /source.content_hex, state.pointer, table.format == "jsonl", pointer/);
});

test('source wiring only: pending and current-source guards remain in force; live projection cannot reuse a stale preview', () => {
  const reducer = file('json_evidence.mbt');
  assert.ok(reducer.indexOf('if view.pending') < reducer.indexOf('DownloadCsv =>'));
  assert.ok(reducer.indexOf('let view = sync_json_evidence(view)') < reducer.indexOf('DownloadCsv =>'));
  assert.match(source, /ignore\(json_evidence_export\(view\)\)/);
  assert.match(reducer, /CsvFields\(csv_fields\) => \{\s*\.\.view, json_evidence: \{ \.\.state, csv_fields, \}, error: None/);
  assert.match(reducer, /DownloadCsv => \{\s*let csv = json_evidence_csv\(view\)\s*let error = json_evidence_csv_download\(csv.text\)/);
  assert.match(reducer, /csv_fields: "\[\]"/);
});
