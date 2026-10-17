#!/usr/bin/env node
// Explicit cell corrections in a derived CSV. The complete source is immutable.
import {basename, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {digest, LIMITS, parseCsv, parsePlan, readBounded, writeBundle} from './csv_bibliography.mjs';

const fail = message => { throw new Error(message); };
const json = value => Buffer.from(JSON.stringify(value, null, 2) + '\n');
const keys = (value, names, label) => {
  if (!value || typeof value !== 'object' || Array.isArray(value) ||
      Object.keys(value).length !== names.length || names.some(name => !Object.hasOwn(value, name))) {
    fail(`${label}: use exactly ${names.join(', ')}`);
  }
};
const text = (value, max, label) => {
  if (typeof value !== 'string' || !value.trim() || value.length > max) fail(`${label}: nonblank text up to ${max} characters required`);
};
const cell = (value, label) => {
  if (typeof value !== 'string' || Buffer.from(value).toString('utf8') !== value) fail(`${label}: a valid Unicode string is required`);
};
const quote = value => '"' + value.replaceAll('"', '""') + '"';

export function inspectCorrections(bytes) {
  const table = parseCsv(bytes);
  return {contract_id: 'moonfind.csv-correction-inspect.v1', source_digest: digest(bytes),
    bytes: bytes.length, ...table, numbering: 'Logical records: header is 1; first data record is 2. Embedded newlines do not increment the record number.'};
}

export function createCorrectionBundle(bytes, plan, originalName = 'source.csv') {
  const original = Buffer.from(bytes), table = parseCsv(original);
  text(originalName, 512, 'Original filename');
  if (!/^[^/\\\0]+\.csv$/i.test(originalName)) fail('Original filename must be a local .csv basename');
  keys(plan, ['contract_id', 'source_digest', 'corrections', 'source'], 'Plan');
  if (plan.contract_id !== 'moonfind.csv-correction-plan.v1') fail('Unsupported correction plan contract');
  if (json(plan).length > LIMITS.plan) fail('Plan exceeds 16 KiB');
  const sourceDigest = digest(original);
  if (typeof plan.source_digest !== 'string' || !/^sha256:[0-9a-f]{64}$/.test(plan.source_digest)) fail('Plan source_digest must be a SHA-256 digest from inspect');
  if (plan.source_digest !== sourceDigest) fail('Source digest changed; inspect the new source and explicitly review a new plan');
  keys(plan.source, ['origin', 'captured_at', 'restrictions', 'access'], 'Source declaration');
  text(plan.source.origin, 2000, 'Source origin');
  text(plan.source.captured_at, 80, 'Source captured_at');
  text(plan.source.restrictions, 2000, 'Source restrictions');
  if (plan.source.access !== 'permitted') fail('Source access must be permitted');
  if (!Array.isArray(plan.corrections) || !plan.corrections.length || plan.corrections.length > LIMITS.rows) fail('Supply 1–512 explicit cell corrections');
  const targets = new Set(), changes = [];
  for (const [index, edit] of plan.corrections.entries()) {
    keys(edit, ['record_number', 'column', 'expected_old', 'replacement'], `Correction ${index + 1}`);
    if (!Number.isSafeInteger(edit.record_number) || edit.record_number < 2 || edit.record_number > table.rows.length + 1) fail('Correction record_number must name an existing data record; header is record 1');
    const column = table.columns.indexOf(edit.column);
    if (column < 0) fail('Correction column must be an exact existing header');
    cell(edit.expected_old, 'Expected old value'); cell(edit.replacement, 'Replacement');
    const key = `${edit.record_number}:${column}`;
    if (targets.has(key)) fail(`Duplicate correction target at record ${edit.record_number}, column ${column + 1}`);
    targets.add(key);
    const actual = table.rows[edit.record_number - 2].values[column];
    if (actual !== edit.expected_old) fail(`Expected old value mismatch at record ${edit.record_number}, column ${column + 1}; inspect and review the exact current cell`);
    if (edit.replacement === actual) fail(`Correction at record ${edit.record_number}, column ${column + 1} makes no change`);
    changes.push({plan_correction_number: index + 1, source_record_number: edit.record_number,
      derived_record_number: edit.record_number, column_number: column + 1, column: edit.column,
      old_value: actual, replacement: edit.replacement});
  }
  // No mutation occurs until every target and guard has been checked. Source
  // coordinates stay stable; edits are simultaneous, never chained mappings.
  const rows = table.rows.map(row => ({record_number: row.record_number, values: [...row.values]}));
  for (const change of changes) rows[change.derived_record_number - 2].values[change.column_number - 1] = change.replacement;
  changes.sort((a, b) => a.source_record_number - b.source_record_number || a.column_number - b.column_number);
  const output = Buffer.from([table.columns, ...rows.map(row => row.values)].map(row => row.map(quote).join(',')).join('\r\n') + '\r\n');
  if (output.length > LIMITS.capture) fail('Corrected CSV exceeds 32 KiB; use a smaller input or replacement');
  parseCsv(output);
  const source = {original_name: originalName, retained_file: 'source.csv', digest: sourceDigest,
    bytes: original.length, ...plan.source};
  const derived = {file: 'corrected.csv', digest: digest(output), bytes: output.length};
  const policies = {
    authority: 'Permission, origin, restrictions, capture time and corrections are operator declarations; observations are not verified.',
    coordinates: 'Logical records and one-based columns in source.csv and corrected.csv are identical. Header is record 1. Every cell not listed in changes retains its exact string value.',
    serialization: 'The working copy uses quoted fields and CRLF record endings. The exact original bytes, including BOM and original line endings, remain in source.csv.',
    values: 'Exact case-sensitive, whitespace-sensitive strings; no trimming, type coercion, category inference or formula evaluation. Spreadsheet software may interpret formula-like text.',
    retention: 'Complete source and all rows/columns retained; this is not redaction.',
  };
  const provenance = {contract_id: 'moonfind.csv-correction-provenance.v1', source, derived, plan,
    plan_digest: digest(json(plan)), columns: table.columns, data_record_count: rows.length, changes, policies};
  const provenanceBytes = json(provenance);
  if (provenanceBytes.length > LIMITS.capture) fail('Provenance exceeds 32 KiB; use fewer corrections or a smaller input');
  const files = {'source.csv': original, 'corrected.csv': output, 'provenance.json': provenanceBytes};
  const limitations = ['Local Node companion only; no provider, network, source licensing or observation validation.',
    'Keep the provenance companion with derived evidence; existing CSV intake does not automatically ingest this lineage.',
    'CLI conversion does not qualify browser mounting, native host intake, installed persistence or save/reopen.'];
  files['manifest.json'] = json({contract_id: 'moonfind.csv-correction-bundle.v1', complete: true,
    files: Object.entries(files).map(([name, data]) => ({name, bytes: data.length, digest: digest(data)})), limitations});
  return {files, preview: {contract_id: 'moonfind.csv-correction-preview.v1', source, derived,
    columns: table.columns, data_record_count: rows.length, correction_count: changes.length,
    changes, rows, policies, limitations}};
}

const HELP = `MoonFind explicit local CSV cell corrections (Node 20+, no dependencies)
  node scripts/csv_correct.mjs inspect --csv INPUT.csv
  node scripts/csv_correct.mjs preview --csv INPUT.csv --plan PLAN.json
  node scripts/csv_correct.mjs convert --csv INPUT.csv --plan PLAN.json --out-dir NEW_DIRECTORY
Inspect logical record numbers, copy the source digest, then explicitly choose
record_number, exact column, expected_old and replacement strings. Review the
preview before converting. Import corrected.csv using the existing CSV table
explorer. See docs/CSV_CELL_CORRECTIONS.md. Original files are never overwritten.
`;
export function main(args) {
  if (args.length === 1 && ['-h', '--help'].includes(args[0])) { process.stdout.write(HELP); return; }
  const [command, ...rest] = args;
  const allowed = command === 'inspect' ? ['--csv'] : command === 'preview' ? ['--csv', '--plan'] : command === 'convert' ? ['--csv', '--plan', '--out-dir'] : [];
  if (!allowed.length || rest.length !== allowed.length * 2) fail(HELP);
  const options = new Map();
  for (let i = 0; i < rest.length; i += 2) {
    if (!allowed.includes(rest[i]) || options.has(rest[i]) || !rest[i + 1] || rest[i + 1].startsWith('--')) fail('Unknown, duplicate or missing option');
    options.set(rest[i], rest[i + 1]);
  }
  const path = resolve(options.get('--csv'));
  if (!/\.csv$/i.test(path)) fail('Choose a local .csv file');
  const bytes = readBounded(path, LIMITS.source, 'CSV');
  if (command === 'inspect') { process.stdout.write(JSON.stringify(inspectCorrections(bytes), null, 2) + '\n'); return; }
  const bundle = createCorrectionBundle(bytes, parsePlan(readBounded(resolve(options.get('--plan')), LIMITS.plan, 'Plan')), basename(path));
  if (command === 'preview') process.stdout.write(JSON.stringify(bundle.preview, null, 2) + '\n');
  else { const directory = resolve(options.get('--out-dir')); writeBundle(directory, bundle); process.stdout.write(JSON.stringify({directory, files: Object.keys(bundle.files)}) + '\n'); }
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { main(process.argv.slice(2)); } catch (error) { process.stderr.write(`CSV correction: ${error.message}\n`); process.exitCode = 1; }
}
