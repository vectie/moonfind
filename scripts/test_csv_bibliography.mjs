import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {mkdirSync, mkdtempSync, readFileSync, readdirSync, statSync, symlinkSync, writeFileSync} from 'node:fs';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import test from 'node:test';
import {createBundle, digest, FIELDS, LIMITS, parseCsv, parsePlan, readBounded} from './csv_bibliography.mjs';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const fixture = readFileSync(join(root, 'fixtures/csv-bibliography.csv'));
const planBytes = readFileSync(join(root, 'fixtures/csv-bibliography-plan.json'));
const plan = JSON.parse(planBytes);
const expected = JSON.parse(readFileSync(join(root, 'fixtures/csv-bibliography.expected.csl.json')));
const clone = value => structuredClone(value);
const json = bytes => JSON.parse(bytes.toString('utf8'));
const bytes = value => Buffer.from(value);
const build = (input = fixture, config = plan) => createBundle(input, config, 'csv-bibliography.csv');
const csv = rows => bytes(rows.map(row => row.map(value => '"' + value.replaceAll('"', '""') + '"').join(',')).join('\r\n') + '\r\n');
const columns = ['id', 'title', 'type', 'author', 'date', 'venue', 'doi', 'url', 'abstract'];
const minimalPlan = () => ({contract_id: 'moonfind.csv-bibliography-plan.v1',
  mapping: Object.fromEntries(Object.keys(FIELDS).map((field, index) => [field, index < 3 ? columns[index] : null])),
  record_numbers: [2], source: {origin: 'Local synthetic test', captured_at: '2026-10-12', restrictions: 'Synthetic only'}});
const simple = (id = '001', title = 'Title') => csv([columns, [id, title, 'book', '', '', '', '', '', '']]);

// No native function is emulated as proof. These tests exercise the production
// Node parser/converter/CLI. The native literal is a pending real-parser test.
test('BOM, quoted comma/newline/escaped quote and Unicode preserve logical records', () => {
  const table = parseCsv(fixture);
  assert.equal(fixture.subarray(0, 3).toString('hex'), 'efbbbf');
  assert.equal(table.columns[0], 'source_id');
  assert.deepEqual(table.rows.map(row => row.record_number), [2, 3, 4]);
  assert.equal(table.rows[0].values[1], 'Contact, sensing 🌒');
  assert.equal(table.rows[0].values[8], 'First line.\r\n第二行 with "quotes".');
  assert.equal(table.rows[0].values[9], '=UNTRUSTED()');
  for (const separator of ['\r\n', '\n', '\r']) assert.deepEqual(parseCsv(bytes(`a,b${separator}x,${separator}`)).rows[0].values, ['x', '']);
  assert.deepEqual(parseCsv(bytes('a,b\nx,')).rows[0].values, ['x', '']);
});
test('production converter equals independently authored ordinary CSL fixture', () => {
  const bundle = build();
  assert.deepEqual(json(bundle.files['references.csl.json']), expected);
  assert.equal(expected[0].author.length, 1);
  assert.equal(expected[0].author[0].literal, 'García, Ana; 王 明');
  assert.deepEqual(Object.keys(expected[0].issued), ['literal']);
  assert.equal(expected[1].id, '9007199254740993');
  assert.equal(Object.hasOwn(expected[1], 'abstract'), false);
});
test('fixture corresponds to actual native CSL contract test; runtime remains unrun here', () => {
  const native = readFileSync(join(root, 'research/csv_bibliography_test.mbt'), 'utf8');
  const literal = native.split('\n').filter(line => /^\s*#\|/.test(line)).map(line => line.replace(/^\s*#\|/, '')).join('\n');
  assert.deepEqual(JSON.parse(literal), expected);
  assert.match(native, /@research\.parse_csl\(input\)/);
  const parser = readFileSync(join(root, 'research/csl.mbt'), 'utf8');
  assert.match(parser, /csl_string\(parts, "literal"\)/);
  assert.match(parser, /csl_string\(date, "literal"\)/);
  assert.match(parser, /"metadata-only"/);
  assert.match(parser, /venue: if venue\.is_blank\(\)/);
  const host = readFileSync(join(root, 'host/csl.mbt'), 'utf8');
  assert.match(host, /@research\.parse_csl\(csl_source_text\(request\.source\)\)/);
  assert.match(readFileSync(join(root, 'ui/rabbita-moonfind/main/csl_view.mbt'), 'utf8'), /reference\.availability/);
});
test('byte-exact original and mapping/row/digest provenance retain omitted content', () => {
  const sourceBefore = Buffer.from(fixture), planBefore = clone(plan);
  const bundle = build();
  assert.deepEqual(bundle.files['source.csv'], fixture);
  const p = json(bundle.files['provenance.json']);
  const sha = input => 'sha256:' + createHash('sha256').update(input).digest('hex');
  assert.equal(p.source.digest, sha(fixture));
  assert.equal(p.derived.digest, sha(bundle.files['references.csl.json']));
  assert.equal(p.source.origin, plan.source.origin);
  assert.equal(p.source.captured_at, plan.source.captured_at);
  assert.equal(p.source.restrictions, plan.source.restrictions);
  assert.deepEqual(p.requested_record_numbers, [3, 2]);
  assert.deepEqual(p.records.map(row => [row.source_record_number, row.csl_record_number, row.source_id]), [[2, 1, '001'], [3, 2, '9007199254740993']]);
  assert.deepEqual(p.omitted_source_record_numbers, [4]);
  assert.deepEqual(p.unmapped_columns, [{column_number: 10, column_name: 'curator_note'}]);
  assert.equal(p.mapping.find(m => m.field === 'issuedText').csl_path, 'issued.literal');
  assert.equal(p.mapping.find(m => m.field === 'literalAuthor').column_number, 4);
  assert.match(bundle.files['source.csv'].toString(), /This row is still retained/);
  assert.deepEqual(fixture, sourceBefore); assert.deepEqual(plan, planBefore);
  for (const entry of json(bundle.files['manifest.json']).files) {
    assert.equal(entry.bytes, bundle.files[entry.name].length);
    assert.equal(entry.digest, sha(bundle.files[entry.name]));
  }
});
test('preview labels absent abstract metadata-only and explains every omitted optional field', () => {
  const preview = build().preview;
  assert.equal(preview.references[0].availability, 'metadata-and-abstract');
  assert.equal(preview.references[1].availability, 'metadata-only');
  assert.deepEqual(preview.references[1].omitted_fields, [{field: 'DOI', reason: 'blank-cell'}, {field: 'abstract', reason: 'blank-cell'}]);
  const p = build(simple(), minimalPlan()).preview;
  assert.equal(p.references[0].availability, 'metadata-only');
  assert.equal(p.references[0].omitted_fields.length, 6);
  assert.ok(p.references[0].omitted_fields.every(item => item.reason === 'unmapped'));
  assert.match(p.policies.retention, /not redaction/);
  assert.equal(preview.references[1].reference.URL, 'javascript:alert(1)');
});
test('source-byte changes and mapping changes create different snapshot identities', () => {
  const original = build();
  const changed = build(bytes(fixture.toString().replace('This row is still retained', 'Changed unselected note')));
  assert.notEqual(json(changed.files['provenance.json']).source.digest, json(original.files['provenance.json']).source.digest);
  assert.deepEqual(changed.files['references.csl.json'], original.files['references.csl.json']);
  const map = clone(plan); map.mapping.DOI = null;
  assert.notEqual(digest(build(fixture, map).files['provenance.json']), digest(original.files['provenance.json']));
});
test('missing/unknown mappings, reused columns and implicit selection are refused', () => {
  for (const edit of [p => delete p.mapping.title, p => p.mapping.title = 'missing',
    p => p.mapping.sourceID = null, p => p.mapping.title = p.mapping.sourceID,
    p => p.mapping.extra = 'title', p => p.record_numbers = [], p => p.record_numbers = [2, 2],
    p => p.record_numbers = [1], p => p.record_numbers = [5], p => p.record_numbers = ['2'],
    p => p.record_numbers = [2.1], p => p.contract_id = 'unknown', p => delete p.source.restrictions]) {
    const p = clone(plan); edit(p); assert.throws(() => build(fixture, p));
  }
});
test('ambiguous headers and duplicate or missing IDs anywhere in the source fail closed', () => {
  for (const input of ['a,a\nx,x', 'a, a \nx,x', 'é,é\nx,x', 'a, \nx,x']) assert.throws(() => parseCsv(bytes(input)), /header/);
  for (const id of ['001', '', ' 002', '002 ']) {
    const input = csv([columns, ['001', 'First', 'book', '', '', '', '', '', ''], [id, 'Unselected', 'book', '', '', '', '', '', '']]);
    assert.throws(() => build(input, minimalPlan()), /sourceID/);
  }
  const unicode = csv([columns, ['é', 'First', 'book', '', '', '', '', '', ''], ['é', 'Second', 'book', '', '', '', '', '', '']]);
  assert.throws(() => build(unicode, minimalPlan()), /ambiguous/);
  assert.equal(json(build(simple('__proto__'), minimalPlan()).files['references.csl.json'])[0].id, '__proto__');
});
test('blank selected titles and unsupported types are repairable errors with no inferred values', () => {
  assert.throws(() => build(simple('id', '  '), minimalPlan()), /title is blank/);
  for (const type of ['', ' Book', 'journal', 'article-journal ']) {
    assert.throws(() => build(csv([columns, ['id', 'Title', type, '', '', '', '', '', '']]), minimalPlan()), /CSL type/);
  }
});
test('strict malformed CSV and invalid UTF-8 never produce partial references', () => {
  for (const input of ['', '\uFEFF', 'a,b\nx', 'a\nx,y', 'a\n"unclosed', 'a\n"ok" trailing', 'a\nno"quote']) assert.throws(() => parseCsv(bytes(input)));
  assert.throws(() => parseCsv(Buffer.from([0xc0, 0xaf])), /UTF-8/);
  assert.throws(() => parseCsv(Buffer.from([0xff])), /UTF-8/);
});
test('source bytes, record/column counts and derived captures have enforced bounds', () => {
  assert.equal(parseCsv(bytes('a\n' + 'x'.repeat(32766))).rows.length, 1);
  assert.throws(() => parseCsv(bytes('a\n' + 'x'.repeat(32767))), /32768/);
  assert.equal(parseCsv(bytes('a\n' + 'x\n'.repeat(512))).rows.length, 512);
  assert.throws(() => parseCsv(bytes('a\n' + 'x\n'.repeat(513))), /512/);
  assert.equal(parseCsv(csv([Array.from({length: 32}, (_, i) => 'c' + i)])).columns.length, 32);
  assert.throws(() => parseCsv(csv([Array.from({length: 33}, (_, i) => 'c' + i)])), /32 columns/);
  assert.throws(() => build(simple('id', '\u0001'.repeat(6000)), minimalPlan()), /CSL output exceeds/);
  const rows = Array.from({length: 200}, (_, i) => [String(i), 'T', 'book', '', '', '', '', '', '']);
  const p = minimalPlan(); p.record_numbers = rows.map((_, i) => i + 2);
  assert.throws(() => build(csv([columns, ...rows]), p), /Provenance exceeds/);
});
test('plan parser rejects duplicate escaped-equivalent JSON keys and oversized/invalid plans', () => {
  assert.deepEqual(parsePlan(planBytes), plan);
  assert.deepEqual(parsePlan(bytes('\uFEFF' + planBytes)), plan);
  for (const input of ['{"mapping":1,"mapping":2}', '{"mapping":{"title":"a","tit\\u006ce":"b"}}', '{bad}', '[] trailing']) assert.throws(() => parsePlan(bytes(input)));
  assert.throws(() => parsePlan(bytes(' '.repeat(LIMITS.plan + 1))), /16384/);
  assert.throws(() => parsePlan(Buffer.from([0xff])), /UTF-8/);
});

// Retain bounded test evidence under the caller's explicitly private TMPDIR.
const testRoot = process.env.MOONFIND_CSV_TEST_DIR;
if (!testRoot) throw new Error('Set MOONFIND_CSV_TEST_DIR to a private evidence directory; tests never clean up');
mkdirSync(testRoot, {recursive: true});
const scratch = mkdtempSync(join(testRoot, 'csv-bibliography-'));
const inputPath = join(scratch, 'input.csv'), planPath = join(scratch, 'plan.json');
writeFileSync(inputPath, fixture); writeFileSync(planPath, planBytes);
const run = args => spawnSync(process.execPath, [join(root, 'scripts/csv_bibliography.mjs'), ...args], {encoding: 'utf8', env: process.env, maxBuffer: 256 * 1024, timeout: 10000});
const args = command => [command, '--csv', inputPath, '--plan', planPath];
test('real CLI inspect, preview and convert retain exact bytes, omissions and manifest', () => {
  const inspect = run(['inspect', '--csv', inputPath]); assert.equal(inspect.status, 0, inspect.stderr);
  assert.equal(JSON.parse(inspect.stdout).rows[0].record_number, 2);
  const preview = run(args('preview')); assert.equal(preview.status, 0, preview.stderr);
  assert.equal(JSON.parse(preview.stdout).selected_count, 2);
  assert.deepEqual(JSON.parse(preview.stdout).omitted_source_record_numbers, [4]);
  const destination = join(scratch, 'converted');
  const converted = run([...args('convert'), '--out-dir', destination]); assert.equal(converted.status, 0, converted.stderr);
  assert.equal(JSON.parse(converted.stdout).native_intake_save_run, false);
  assert.deepEqual(readFileSync(join(destination, 'source.csv')), fixture);
  assert.deepEqual(json(readFileSync(join(destination, 'references.csl.json'))), expected);
  const manifest = json(readFileSync(join(destination, 'manifest.json')));
  for (const file of manifest.files) assert.equal(digest(readFileSync(join(destination, file.name))), file.digest);
  assert.deepEqual(readFileSync(inputPath), fixture);
  assert.deepEqual(readFileSync(planPath), planBytes);
  assert.equal(statSync(destination).mode & 0o777, 0o700);
  for (const name of readdirSync(destination)) assert.equal(statSync(join(destination, name)).mode & 0o777, 0o600);
});
test('CLI refuses existing directory/file/symlink destinations without overwriting or mutating inputs', () => {
  const protectedDir = join(scratch, 'protected'); mkdirSync(protectedDir);
  const sentinel = join(protectedDir, 'source.csv'); writeFileSync(sentinel, 'keep');
  const file = join(scratch, 'existing-file'); writeFileSync(file, 'keep-file');
  const link = join(scratch, 'existing-link'); symlinkSync(protectedDir, link);
  for (const path of [protectedDir, file, link, inputPath]) {
    const result = run([...args('convert'), '--out-dir', path]); assert.notEqual(result.status, 0);
  }
  assert.equal(readFileSync(sentinel, 'utf8'), 'keep'); assert.equal(readFileSync(file, 'utf8'), 'keep-file');
  assert.deepEqual(readFileSync(inputPath), fixture); assert.deepEqual(readFileSync(planPath), planBytes);
});
test('CLI validation errors create no destination; bounded reads and command options fail safely', () => {
  const badPlan = join(scratch, 'bad-plan.json'); writeFileSync(badPlan, '{"mapping":1,"mapping":2}');
  const destination = join(scratch, 'must-not-exist');
  const failed = run(['convert', '--csv', inputPath, '--plan', badPlan, '--out-dir', destination]);
  assert.notEqual(failed.status, 0); assert.throws(() => statSync(destination), /ENOENT/);
  for (const command of [['preview', '--csv', inputPath], ['inspect', '--csv', inputPath, '--csv', inputPath], ['unexpected'], ['convert', '--csv', inputPath, '--plan', planPath, '--bogus', destination]]) assert.notEqual(run(command).status, 0);
  assert.throws(() => readBounded(inputPath, 2, 'CSV'), /regular file/);
  assert.throws(() => readBounded(scratch, LIMITS.source, 'CSV'), /regular file/);
  const help = run(['--help']); assert.equal(help.status, 0); assert.match(help.stdout, /no dependencies/);
  assert.deepEqual(readdirSync(protectedPath()), ['source.csv']);
});
function protectedPath() { return join(scratch, 'protected'); }

// Named-pipe probes run in isolated child processes with no writer. A timeout
// is a failure, never a successful rejection. FIFO files remain as evidence.
function fifo(path) {
  const made = spawnSync('mkfifo', [path], {encoding: 'utf8', timeout: 1500});
  assert.equal(made.error, undefined); assert.equal(made.status, 0, made.stderr);
}
function rejectsFifo(args) {
  const result = spawnSync(process.execPath, [join(root, 'scripts/csv_bibliography.mjs'), ...args],
    {encoding: 'utf8', env: process.env, maxBuffer: 256 * 1024, timeout: 1500});
  assert.equal(result.error, undefined, 'FIFO input must return without timing out');
  assert.equal(result.signal, null); assert.equal(result.status, 1);
  assert.equal(result.stdout, ''); assert.match(result.stderr, /choose a regular file/);
}
test('CSV FIFO without a writer is rejected promptly before creating a destination',
  {skip: process.platform === 'win32' ? 'POSIX named pipes require POSIX' : false}, () => {
    const pipe = join(scratch, 'no-writer.csv'); fifo(pipe);
    const destination = join(scratch, 'csv-fifo-output');
    rejectsFifo(['inspect', '--csv', pipe]);
    rejectsFifo(['convert', '--csv', pipe, '--plan', planPath, '--out-dir', destination]);
    assert.throws(() => statSync(destination), /ENOENT/);
    assert.deepEqual(readFileSync(planPath), planBytes);
  });
test('plan FIFO without a writer is rejected promptly before creating a destination',
  {skip: process.platform === 'win32' ? 'POSIX named pipes require POSIX' : false}, () => {
    const pipe = join(scratch, 'no-writer-plan.json'); fifo(pipe);
    const destination = join(scratch, 'plan-fifo-output');
    rejectsFifo(['preview', '--csv', inputPath, '--plan', pipe]);
    rejectsFifo(['convert', '--csv', inputPath, '--plan', pipe, '--out-dir', destination]);
    assert.throws(() => statSync(destination), /ENOENT/);
    assert.deepEqual(readFileSync(inputPath), fixture);
  });
