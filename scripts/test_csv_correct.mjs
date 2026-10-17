import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync, writeFileSync, mkdirSync, existsSync, symlinkSync} from 'node:fs';
import {dirname, resolve, join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import vm from 'node:vm';
import {createCorrectionBundle as build, inspectCorrections} from './csv_correct.mjs';
import {createRecodeBundle} from './csv_recode.mjs';
import {digest, LIMITS, parseCsv, parsePlan} from './csv_bibliography.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const input = readFileSync(join(root, 'fixtures/cell-corrections.csv'));
const plan = () => parsePlan(readFileSync(join(root, 'fixtures/cell-corrections-plan.json')));
const evidence = process.env.MOONFIND_CORRECTION_EVIDENCE;
assert.ok(evidence, 'Set MOONFIND_CORRECTION_EVIDENCE to a new retained evidence directory');
assert.equal(existsSync(evidence), false, 'Use a new evidence directory');
mkdirSync(evidence, {recursive: true});
const save = (name, value) => writeFileSync(join(evidence, name), typeof value === 'string' || Buffer.isBuffer(value) ? value : JSON.stringify(value, null, 2) + '\n', {flag: 'wx'});
const cli = (...args) => spawnSync(process.execPath, [join(root, 'scripts/csv_correct.mjs'), ...args], {encoding: 'utf8', timeout: 5000});
const forInput = (bytes, corrections) => ({...plan(), source_digest: digest(bytes), corrections});
const edit = (record_number, column, expected_old, replacement) => ({record_number, column, expected_old, replacement});

test('only explicit individual cells change, with stable coordinates and exact retained source', () => {
  const p = plan(), before = JSON.stringify(p), bundle = build(input, p, 'cell-corrections.csv');
  const original = parseCsv(input), table = parseCsv(bundle.files['corrected.csv']), provenance = JSON.parse(bundle.files['provenance.json']);
  assert.deepEqual(table.columns, original.columns);
  assert.deepEqual(table.rows.map(row => row.values), [
    ['001', 'clinic', 'slow handoff', 'low'],
    ['002', 'retail', 'quoted "claim",\nchecked', ' medium '],
    ['003', 'clinc', 'same category, kept', 'low'],
    ['004', 'clinic', 'already correct', 'reviewed'],
  ]);
  assert.equal(bundle.preview.correction_count, 3);
  assert.deepEqual(provenance.changes.map(c => [c.source_record_number, c.derived_record_number, c.column_number, c.plan_correction_number]), [[2, 2, 2, 2], [3, 3, 3, 3], [5, 5, 4, 1]]);
  const changed = new Set();
  for (const change of provenance.changes) {
    const row = change.source_record_number - 2, col = change.column_number - 1;
    assert.equal(original.columns[col], change.column);
    assert.equal(original.rows[row].values[col], change.old_value);
    assert.equal(table.rows[row].values[col], change.replacement);
    changed.add(`${row}:${col}`);
  }
  for (const [r, row] of original.rows.entries()) for (const [c, value] of row.values.entries()) {
    if (!changed.has(`${r}:${c}`)) assert.equal(table.rows[r].values[c], value);
  }
  assert.equal(JSON.stringify(p), before); assert.deepEqual(bundle.files['source.csv'], input);
  assert.deepEqual(build(input, p, 'cell-corrections.csv'), bundle);
  assert.equal(provenance.source.digest, digest(input)); assert.equal(provenance.derived.digest, digest(bundle.files['corrected.csv']));
  assert.equal(provenance.plan_digest, digest(Buffer.from(JSON.stringify(p, null, 2) + '\n')));
  assert.deepEqual(provenance.plan, p); assert.equal(provenance.source.restrictions, p.source.restrictions);
  for (const member of JSON.parse(bundle.files['manifest.json']).files) {
    assert.equal(digest(bundle.files[member.name]), member.digest); assert.equal(bundle.files[member.name].length, member.bytes);
  }
  save('preview.json', bundle.preview);
});

test('BOM, mixed line endings, multiline cells, empty strings, Unicode and formula text stay literal', () => {
  const bytes = Buffer.from('\uFEFFid,value,note\r\n001,"line1\r\nline2",月\r002,,"a""b"\n003,0,=1+2');
  const p = forInput(bytes, [edit(2, 'value', 'line1\r\nline2', ' spaced, "quote"\n😀 '), edit(3, 'value', '', '=SUM(1,2)'), edit(4, 'value', '0', '')]);
  const bundle = build(bytes, p), table = parseCsv(bundle.files['corrected.csv']);
  assert.deepEqual(bundle.files['source.csv'], bytes);
  assert.deepEqual(table.rows.map(row => row.values), [['001', ' spaced, "quote"\n😀 ', '月'], ['002', '=SUM(1,2)', 'a"b'], ['003', '', '=1+2']]);
  assert.deepEqual(inspectCorrections(bytes).rows.map(row => row.record_number), [2, 3, 4]);
  for (const replacement of ['\uD800', '\uDC00']) assert.throws(() => build(bytes, forInput(bytes, [edit(2, 'note', '月', replacement)])), /valid Unicode/);
});

test('stale digests and incorrect expected old strings refuse, while an explicit new snapshot is distinct', () => {
  const changed = Buffer.concat([Buffer.from('\uFEFF'), input]);
  assert.throws(() => build(changed, plan()), /digest changed/);
  const p = plan(); p.source_digest = digest(changed);
  const renewed = build(changed, p); assert.notEqual(renewed.preview.source.digest, build(input, plan()).preview.source.digest);
  assert.deepEqual(parseCsv(renewed.files['corrected.csv']), parseCsv(build(input, plan()).files['corrected.csv']));
  for (const expected of ['CLINC', ' clinc', 'clinic']) {
    const p = plan(); p.corrections[1].expected_old = expected;
    assert.throws(() => build(input, p), /Expected old value mismatch/);
  }
  const p2 = plan(); p2.source.access = 'denied'; assert.throws(() => build(input, p2), /permitted/);
  const p3 = plan(); p3.source_digest = 'sha256:stale'; assert.throws(() => build(input, p3), /SHA-256/);
});

test('plans refuse duplicate targets, unknown fields, header changes, bad coordinates and no-op edits', () => {
  const invalid = [
    p => p.corrections.push({...p.corrections[0]}),
    p => p.corrections[0].replacement = p.corrections[0].expected_old,
    p => p.corrections[0].record_number = 1,
    p => p.corrections[0].record_number = 6,
    p => p.corrections[0].record_number = '5',
    p => p.corrections[0].record_number = 2.5,
    p => p.corrections[0].column = 'Confidence',
    p => p.corrections[0].column = ' confidence ',
    p => p.corrections[0].replacement = null,
    p => p.corrections[0].expected_old = 0,
    p => p.corrections[0].extra = true,
    p => p.extra = true,
    p => p.source.extra = true,
    p => p.source.origin = ' ',
    p => p.contract_id = 'moonfind.csv-recode-plan.v1',
    p => p.corrections = [],
  ];
  for (const mutate of invalid) { const p = plan(); mutate(p); assert.throws(() => build(input, p)); }
  assert.throws(() => parsePlan(Buffer.from('{"source":1,"\\u0073ource":2}')), /duplicate JSON key/);
  assert.throws(() => parsePlan(Buffer.from('{"edits":[{"replacement":"a","replacement":"b"}]}')), /duplicate JSON key/);
  for (const name of ['../source.csv', 'nested\\source.csv', 'source.json']) assert.throws(() => build(input, plan(), name), /basename/);
});

test('CSV, plan, output and provenance bounds fail without truncation', () => {
  for (const value of ['a,a\nx,y\n', 'a,b\nx\n', 'a\n"unfinished', 'a\nx"y\n']) {
    const bytes = Buffer.from(value); assert.throws(() => build(bytes, forInput(bytes, [edit(2, 'a', 'x', 'y')])));
  }
  assert.throws(() => inspectCorrections(Buffer.from([0xff])), /invalid UTF-8/);
  assert.throws(() => inspectCorrections(Buffer.alloc(LIMITS.source + 1, 65)), /1–32768/);
  const p = plan(); p.corrections[0].replacement = 'x'.repeat(LIMITS.plan);
  assert.throws(() => build(input, p), /Plan exceeds/);
  const bytes = Buffer.from('a,b\nx,' + 'z'.repeat(20000) + '\n');
  assert.throws(() => build(bytes, forInput(bytes, [edit(2, 'a', 'x', 'y'.repeat(15000))])), /Corrected CSV exceeds/);
  const old = 'a'.repeat(7800), large = Buffer.from('a\n' + old + '\n');
  assert.throws(() => build(large, forInput(large, [edit(2, 'a', old, 'b'.repeat(7800))])), /Provenance exceeds/);
});

test('multiple corrections in one row are independent and category recoding remains separate', () => {
  const bytes = Buffer.from('a,b\nx,x\nx,x\n'), p = forInput(bytes, [edit(2, 'a', 'x', 'y'), edit(2, 'b', 'x', 'z')]);
  assert.deepEqual(parseCsv(build(bytes, p).files['corrected.csv']).rows.map(r => r.values), [['y', 'z'], ['x', 'x']]);
  const source = readFileSync(join(root, 'fixtures/category-recode.csv'));
  const recode = parsePlan(readFileSync(join(root, 'fixtures/category-recode-plan.json')));
  const output = parseCsv(createRecodeBundle(source, recode).files['recoded.csv']);
  assert.deepEqual(output.rows.map(r => r.values.at(-1)), ['agree', 'agree', 'disagree', 'unknown', 'unanswered', ' yes']);
});

test('actual inspect/preview/convert CLI preserves originals and existing destinations', () => {
  const source = join(root, 'fixtures/cell-corrections.csv'), planPath = join(root, 'fixtures/cell-corrections-plan.json');
  const common = ['--csv', source, '--plan', planPath], inspected = cli('inspect', '--csv', source);
  assert.equal(inspected.status, 0, inspected.stderr); assert.deepEqual(JSON.parse(inspected.stdout), inspectCorrections(input));
  const shown = cli('preview', ...common); assert.equal(shown.status, 0, shown.stderr);
  assert.equal(JSON.parse(shown.stdout).correction_count, 3);
  const out = join(evidence, 'bundle'), converted = cli('convert', ...common, '--out-dir', out);
  assert.equal(converted.status, 0, converted.stderr);
  const bundle = build(input, plan(), 'cell-corrections.csv');
  for (const [name, bytes] of Object.entries(bundle.files)) assert.deepEqual(readFileSync(join(out, name)), bytes);
  assert.notEqual(cli('convert', ...common, '--out-dir', out).status, 0);
  const existing = join(evidence, 'existing.csv'); save('existing.csv', 'keep me');
  assert.notEqual(cli('convert', ...common, '--out-dir', existing).status, 0); assert.equal(readFileSync(existing, 'utf8'), 'keep me');
  const link = join(evidence, 'existing-link'); symlinkSync(out, link);
  assert.notEqual(cli('convert', ...common, '--out-dir', link).status, 0);
  assert.notEqual(cli('convert', ...common, '--out-dir', source).status, 0);
  assert.deepEqual(readFileSync(source), input);
  assert.notEqual(cli('inspect', '--csv', source, '--csv', source).status, 0);
  save('cli-inspect.json', inspected.stdout); save('cli-preview.json', shown.stdout); save('cli-convert.json', converted.stdout);
});

test('actual CLI refuses stale and old-value plans before creating any output', () => {
  const source = join(root, 'fixtures/cell-corrections.csv');
  for (const [name, mutate] of [['stale', p => p.source_digest = 'sha256:' + '0'.repeat(64)], ['old-value', p => p.corrections[1].expected_old = 'clinic'], ['denied', p => p.source.access = 'denied']]) {
    const p = plan(); mutate(p); save(`${name}-plan.json`, p);
    const common = ['--csv', source, '--plan', join(evidence, `${name}-plan.json`)];
    const shown = cli('preview', ...common), out = join(evidence, `${name}-bundle`), converted = cli('convert', ...common, '--out-dir', out);
    assert.notEqual(shown.status, 0); assert.notEqual(converted.status, 0); assert.equal(existsSync(out), false);
    save(`${name}-refusal.json`, {preview_exit: shown.status, preview_error: shown.stderr, convert_exit: converted.status, convert_error: converted.stderr, output_exists: existsSync(out)});
  }
  const duplicate = readFileSync(join(root, 'fixtures/cell-corrections-plan.json'), 'utf8').replace('"corrections": [', '"contract_id": "moonfind.csv-correction-plan.v1", "corrections": [');
  save('duplicate-key-plan.json', duplicate);
  const result = cli('convert', '--csv', source, '--plan', join(evidence, 'duplicate-key-plan.json'), '--out-dir', join(evidence, 'duplicate-bundle'));
  assert.notEqual(result.status, 0); assert.match(result.stderr, /duplicate JSON key/); assert.equal(existsSync(join(evidence, 'duplicate-bundle')), false);
  assert.deepEqual(readFileSync(source), input);
});

test('current pinned production CSV reducer imports, filters, selects and extracts corrected CLI output', () => {
  const retained = process.env.MOONFIND_RETAINED_EVIDENCE, workspace = process.env.MOONFIND_WORKSPACE;
  assert.ok(retained && workspace, 'Set retained R765 evidence and workspace; consumer proof cannot skip');
  const pins = [['source-artifact-input-sha256.txt', '179a6d01bef4f9ef94ef450fb6a77a2764bebbc7c5f4f606879e169130568607'], ['compile-interfaces-sha256.txt', 'bd71c37a9b672ee4a50de368e74cc06a722f2c3d1c9fb671d55c3d9fb3474314']];
  const verified = [];
  for (const [name, expected] of pins) {
    const bytes = readFileSync(join(retained, name)); assert.equal(digest(bytes).slice(7), expected, name);
    for (const line of bytes.toString().trim().split('\n')) {
      const match = /^([0-9a-f]{64})  (.+)$/.exec(line); assert.ok(match, name);
      const [, hash, path] = match, prefix = '.moonsuite-background/philosophy-r763-767/r765/source/';
      const current = path.startsWith(prefix) ? join(root, path.slice(prefix.length)) : resolve(workspace, path);
      assert.equal(digest(readFileSync(current)).slice(7), hash, current); verified.push({path: current, sha256: hash});
    }
  }
  assert.equal(verified.length, 187);
  const artifact = join(retained, 'range-runtime.cjs'), bytes = readFileSync(artifact), hash = digest(bytes).slice(7);
  assert.equal(hash, 'b4ced4539764212ff329a646ef409d8bb1c8885d87cf2fe4be183022421181b7');
  const code = bytes.toString(), end = code.lastIndexOf('\n(() => {'); assert.ok(end > 0);
  const context = vm.createContext({console, TextEncoder, TextDecoder, URL, Blob, Buffer, setTimeout, clearTimeout});
  vm.runInContext(code.slice(0, end), context, {timeout: 5000});
  const prefix = '_M0FP36vectie18moonfind_2drabbita4main', ctor = '_M0DTP36vectie18moonfind_2drabbita4main6CsvMsg';
  const run = s => vm.runInContext(s, context, {timeout: 2000});
  const output = readFileSync(join(evidence, 'bundle/corrected.csv')), table = parseCsv(output);
  context.payload = JSON.stringify({...table, total_count: table.rows.length, source: {name: 'corrected.csv', origin: 'Synthetic reviewed cell corrections', captured_at: '2026-10-16', kind: 'local-file', content_hex: output.toString('hex')}});
  run(`var view=${prefix}20initial__brief__view();view.pending=true;var parsed=_M0FPC14json13parse_2einner(new _M0TPC16string10StringView(payload,0,payload.length),100);if(parsed.$tag!==1)throw Error('parse failed');var reply=new _M0DTPC16result6ResultGRPB4JsonRPC15error5ErrorE2Ok(parsed._0);view=${prefix}17update__csv__view(undefined,new ${ctor}8Imported(view.generation,reply),view)._1;`);
  assert.equal(run('view.error'), undefined);
  run(`view=${prefix}17update__csv__view(undefined,new ${ctor}12SearchColumn(2),view)._1;view=${prefix}17update__csv__view(undefined,new ${ctor}6Filter('clinic'),view)._1;view=${prefix}17update__csv__view(undefined,new ${ctor}14SelectMatching(),view)._1;`);
  assert.deepEqual(JSON.parse(run('JSON.stringify(view.csv.selected)')), [2, 5]);
  const extracted = run(`${prefix}18csv__extract__text(view.csv)`); assert.equal(extracted.$tag, 1);
  const selected = parseCsv(Buffer.from(extracted._0));
  assert.deepEqual(selected.rows.map(r => r.values), [table.rows[0].values, table.rows[3].values]);
  assert.deepEqual(selected.rows.map(r => r.values[0]), ['001', '004']);
  save('explorer-selected.csv', extracted._0); save('consumer-pins.json', verified);
  save('explorer-consumer.json', {artifact, sha256: hash, verified_pins: verified.length,
    executed: ['CLI convert', 'Imported', 'SearchColumn', 'Filter', 'SelectMatching', 'csv_extract_text'],
    selected_records: [2, 5], unchanged_same_value_record: 4,
    limits: 'Current production CSV reducers with supplied intake JSON. Historical test invocation and browser bootstrap omitted. No changed MoonBit/extern logic, host import, browser mounting, persistence, provider or production qualification.'});
});
