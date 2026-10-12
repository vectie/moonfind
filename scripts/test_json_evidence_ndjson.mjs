import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';
import test from 'node:test';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const main = resolve(root, 'ui/rabbita-moonfind/main');
const read = name => readFileSync(resolve(main, name), 'utf8');
const production = read('json_evidence_ndjson.mbt');
const existing = read('json_evidence.mbt');
function extract(source, name, globals = {}) {
  const start = source.indexOf(`extern "js" fn ${name}(`);
  assert.notEqual(start, -1, `missing production function ${name}`);
  const part = source.slice(start).split('\n///|')[0];
  const body = part.split('\n').filter(line => /^\s*#\|/.test(line))
    .map(line => line.replace(/^\s*#\|/, '')).join('\n');
  return vm.runInNewContext(`(${body})`, { TextDecoder, TextEncoder, Blob, ...globals });
}
const parse = extract(existing, 'json_evidence_parse_mode');
const convert = extract(production, 'json_evidence_ndjson_text');
const hex = text => Buffer.from(text, 'utf8').toString('hex');
function table(text, pointer = '', lines = false) {
  const response = JSON.parse(parse(hex(text), pointer, lines));
  assert.equal(response.error, undefined);
  return response.table;
}
function result(input, selected) {
  return JSON.parse(convert(JSON.stringify(input), JSON.stringify(selected)));
}
const fixture = readFileSync(resolve(root, 'fixtures/ndjson-selection.json'), 'utf8');
const source = table(fixture, '/observations');
const selectedText = result(source, [3, 1, 3]).text;

test('production parser to converter: source order and unique selected positions', () => {
  assert.equal(source.rows.length, 3);
  const output = result(source, [3, 1, 3]);
  assert.equal(output.record_count, 2);
  assert.deepEqual(output.text.trimEnd().split('\n').map(line => JSON.parse(line).id), ['clinic-1', 'clinic-3']);
  assert.ok(output.text.endsWith('\n'));
  assert.equal(output.text.split('\n').length, 3);
});

test('large integers, negative zero, trailing zeroes and overflowing exponent tokens remain exact', () => {
  for (const token of ['"count":9007199254740993', '"ratio":1.2300', '"negative_zero":-0', '"large_exponent":1e+400']) {
    assert.ok(selectedText.includes(token), token);
  }
});

test('string spaces, escape spellings, unicode and inert source content remain exact', () => {
  for (const token of ['  synthetic clinic observation\\r\\nkeep spaces  ', '\\u0041', '海 🌙', '<script>never execute</script> https://example.invalid']) {
    assert.ok(selectedText.includes(token), token);
  }
  assert.ok(selectedText.includes('comma, brace} and tab\\t'));
  assert.ok(selectedText.includes('quote: \\" slash: \\\\ unicode: \\u0041'));
});

test('nested values and missing/null/empty distinctions survive', () => {
  const [first, third] = selectedText.trimEnd().split('\n').map(line => JSON.parse(line));
  assert.deepEqual(first.nested.array, [null, true, 'comma, brace} and tab\t']);
  assert.equal(third.empty, '');
  assert.equal(third.nullable, null);
  assert.equal(Object.hasOwn(third, 'count'), false);
});

test('raw output contains no added envelope, provenance or unselected data', () => {
  assert.equal(selectedText.includes('excluded synthetic record'), false);
  const objects = selectedText.trimEnd().split('\n').map(line => JSON.parse(line));
  for (const object of objects) {
    for (const key of ['contract_id', 'source_record', 'source_pointer', 'source_line', 'source', 'host_recorded_digest']) {
      assert.equal(Object.hasOwn(object, key), false);
    }
  }
});

test('lossless reimport through the existing JSONL parser', () => {
  const reopened = table(selectedText, '', true);
  assert.equal(reopened.rows.length, 2);
  assert.deepEqual(reopened.rows.map(row => row.source_line), [1, 2]);
  assert.equal(reopened.rows[0].cells[1].text, '9007199254740993');
  assert.equal(result(reopened, [1, 2]).text, selectedText);
});

test('JSONL selection uses record identities rather than physical line numbers', () => {
  const input = table('\uFEFF\r\n {"id":1}\r\n\r\n {"id":2} \r\n', '', true);
  assert.deepEqual(input.rows.map(row => row.source_line), [2, 4]);
  assert.equal(result(input, [2]).text, '{"id":2}\n');
});

test('hidden selections do not depend on query or visible-row state', () => {
  const input = { ...source, query: 'school', visible_rows: [source.rows[1]] };
  assert.equal(result(input, [1, 3]).text, selectedText);
});

test('repeated identical source records remain independent records', () => {
  const input = table('[{"x":1},{"x":1}]');
  assert.equal(result(input, [2, 1, 2]).text, '{"x":1}\n{"x":1}\n');
});

test('conversion does not mutate sources, rows or selections', () => {
  const before = JSON.stringify(source), selected = [3, 1, 3];
  result(source, selected);
  assert.equal(JSON.stringify(source), before);
  assert.deepEqual(selected, [3, 1, 3]);
  assert.equal(readFileSync(resolve(root, 'fixtures/ndjson-selection.json'), 'utf8'), fixture);
});

test('empty objects are supported without invented metadata', () => {
  assert.equal(result(table('[{}]'), [1]).text, '{}\n');
});

for (const selected of [[], [0], [-1], [4], [1.5], ['1'], null, {}, [1, 4]]) {
  test(`invalid or stale selection fails without partial output: ${JSON.stringify(selected)}`, () => {
    const output = result(source, selected);
    assert.match(output.error, /Select at least one current/);
    assert.equal(output.text, undefined);
  });
}

test('changed record identities and oversized tables fail closed', () => {
  const changed = structuredClone(source);
  changed.rows[1].record_number = 1;
  assert.match(result(changed, [1]).error, /identity changed/);
  assert.match(result({ format: 'json-array', rows: Array(513).fill({}) }, [1]).error, /current JSON/);
  assert.match(result({ ...source, format: 'csv' }, [1]).error, /current JSON/);
});

test('malformed/scalar raw values and malformed transport yield errors', () => {
  for (const raw of ['{bad}', '[]', 'null', 'true', '"text"', '9007199254740993']) {
    const output = result({ format: 'json-array', rows: [{ record_number: 1, raw }] }, [1]);
    assert.ok(output.error);
    assert.equal(output.text, undefined);
  }
  assert.ok(JSON.parse(convert('{', '[]')).error);
});

test('selected raw byte bound is enforced without truncation', () => {
  const raw = JSON.stringify({ text: '海'.repeat(11000) });
  assert.match(result({ format: 'json-array', rows: [{ record_number: 1, raw }] }, [1]).error, /32 KiB/);
});

test('original duplicate keys are refused by the existing intake before projection', () => {
  const output = JSON.parse(parse(hex('[{"x":1,"x":2}]'), '', false));
  assert.match(output.error, /Duplicate JSON object field/);
});

function downloadHarness(failAt = '') {
  const calls = [], timers = [];
  let blob;
  const check = step => { calls.push(step); if (failAt === step) throw Error(step); };
  const link = { remove() { check('remove'); }, click() { check('click'); } };
  const download = extract(production, 'json_evidence_ndjson_download', {
    URL: {
      createObjectURL(value) { check('url'); blob = value; return 'blob:controlled-test'; },
      revokeObjectURL(value) { assert.equal(value, 'blob:controlled-test'); check('revoke'); },
    },
    document: {
      createElement(tag) { assert.equal(tag, 'a'); check('create'); return link; },
      body: { appendChild(value) { assert.equal(value, link); check('append'); } },
    },
    setTimeout(callback, ms) { assert.equal(ms, 1000); timers.push(callback); },
  });
  return { download, calls, timers, link, get blob() { return blob; } };
}

test('production download creates exact real Blob bytes and revokes its object URL', async () => {
  const h = downloadHarness();
  assert.equal(h.download(selectedText), '');
  assert.equal(h.link.download, 'moonfind-selected-records.ndjson');
  assert.equal(h.link.href, 'blob:controlled-test');
  assert.equal(h.blob.type, 'application/x-ndjson;charset=utf-8');
  assert.equal(await h.blob.text(), selectedText);
  assert.deepEqual(Buffer.from(await h.blob.arrayBuffer()), Buffer.from(selectedText));
  assert.deepEqual(h.calls, ['url', 'create', 'append', 'click', 'remove']);
  assert.equal(h.timers.length, 1);
  h.timers[0]();
  assert.equal(h.calls.at(-1), 'revoke');
});

for (const failure of ['url', 'create', 'append', 'click']) {
  test(`download failure at ${failure} reports retryable error and cleans up allocated resources`, () => {
    const h = downloadHarness(failure);
    assert.match(h.download(selectedText), /source and selections remain available/);
    assert.equal(h.timers.length, failure === 'url' ? 0 : 1);
    h.timers.forEach(callback => callback());
    if (['append', 'click'].includes(failure)) assert.ok(h.calls.includes('remove'));
    if (failure !== 'url') assert.ok(h.calls.includes('revoke'));
  });
}

test('source-wiring checks only: normal UI action, pending/stale guards and preview connect to production helper', () => {
  const view = read('json_evidence_view.mbt');
  assert.match(view, /emit\(BriefAction\(JsonEvidence\(DownloadNdjson\)\)\)/);
  assert.match(view, /Preview selected raw NDJSON records/);
  assert.match(existing, /DownloadNdjson => \{\s*let error = json_evidence_ndjson_download\(json_evidence_ndjson\(view\)\)/);
  assert.ok(existing.indexOf('if view.pending') < existing.indexOf('DownloadNdjson =>'));
  assert.ok(existing.indexOf('let view = sync_json_evidence(view)') < existing.indexOf('DownloadNdjson =>'));
  assert.match(production, /ignore\(json_evidence_export\(view\)\)/);
  assert.match(production, /table\.to_json\(\)\.stringify\(\),\s*state\.selected\.to_json\(\)\.stringify\(\)/);
});
