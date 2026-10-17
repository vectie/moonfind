#!/usr/bin/env node
// Explicit local category edits. Original columns and source bytes remain intact.
import {basename, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {digest, LIMITS, parseCsv, parsePlan, readBounded, writeBundle} from './csv_bibliography.mjs';
const fail = message => { throw new Error(message); };
const json = value => Buffer.from(JSON.stringify(value, null, 2) + '\n');
const keys = (v, names, label) => {
  if (!v || typeof v !== 'object' || Array.isArray(v) || Object.keys(v).length !== names.length || names.some(n => !Object.hasOwn(v, n))) fail(`${label}: expected ${names.join(', ')}`);
};
const text = (v, max, label) => { if (typeof v !== 'string' || !v.trim() || v.length > max) fail(`${label}: nonblank text up to ${max} characters required`); };
const quote = value => '"' + value.replaceAll('"', '""') + '"';

export function createRecodeBundle(bytes, plan, originalName = 'source.csv') {
  const table = parseCsv(bytes);
  text(originalName, 512, 'Original filename');
  if (basename(originalName) !== originalName || !/\.csv$/i.test(originalName)) fail('Original filename must be a .csv basename');
  keys(plan, ['contract_id', 'column', 'output_column', 'mappings', 'unmatched', 'source'], 'Plan');
  if (plan.contract_id !== 'moonfind.csv-recode-plan.v1') fail('Unsupported plan contract');
  if (json(plan).length > LIMITS.plan) fail('Plan exceeds 16 KiB');
  const index = table.columns.indexOf(plan.column);
  if (index < 0) fail('Choose an exact existing column');
  text(plan.output_column, 256, 'Output column');
  const normalized = plan.output_column.trim().normalize('NFC');
  if (table.columns.some(n => n.trim().normalize('NFC') === normalized)) fail('Output column must be new');
  if (table.columns.length >= LIMITS.columns) fail('No room for a new column: maximum 32');
  if (!['keep', 'empty', 'error'].includes(plan.unmatched)) fail('Unmatched policy must be keep, empty or error');
  keys(plan.source, ['origin', 'captured_at', 'restrictions', 'access'], 'Source');
  text(plan.source.origin, 2000, 'Origin'); text(plan.source.captured_at, 80, 'Captured at'); text(plan.source.restrictions, 2000, 'Restrictions');
  if (plan.source.access !== 'permitted') fail('Source access must be permitted');
  if (!Array.isArray(plan.mappings) || !plan.mappings.length || plan.mappings.length > LIMITS.rows) fail('Supply 1–512 explicit mappings');
  const mapping = new Map();
  for (const item of plan.mappings) {
    keys(item, ['from', 'to'], 'Mapping');
    if (typeof item.from !== 'string' || typeof item.to !== 'string') fail('Mapping values must be strings');
    if (mapping.has(item.from)) fail('Duplicate mapping input');
    mapping.set(item.from, item.to);
  }
  const changes = table.rows.map(row => {
    const original = row.values[index], matched = mapping.has(original);
    if (!matched && plan.unmatched === 'error') fail(`Unmatched value at record ${row.record_number}: ${JSON.stringify(original)}`);
    return {record_number: row.record_number, original, value: matched ? mapping.get(original) : plan.unmatched === 'keep' ? original : '', matched};
  });
  const columns = [...table.columns, plan.output_column];
  const rows = table.rows.map((row, i) => ({record_number: row.record_number, values: [...row.values, changes[i].value]}));
  const output = Buffer.from([columns, ...rows.map(row => row.values)].map(row => row.map(quote).join(',')).join('\r\n') + '\r\n');
  if (output.length > LIMITS.capture) fail('Recoded CSV exceeds 32 KiB; use a smaller input');
  // Check against the same intake contract used by the existing CSV tools.
  parseCsv(output);
  const source = {original_name: originalName, digest: digest(bytes), bytes: bytes.length, ...plan.source};
  const policies = {matching: 'Exact case-sensitive strings, including whitespace and empty strings; no coercion or inferred categories',
    originals: 'All original columns and row order preserved; new column appended; original source bytes retained',
    values: 'Mapping is user-authored interpretation, not validation of observations. Formula-like values are inert text here; spreadsheet software may interpret them.',
    retention: 'Complete source retained; this is not redaction', authority: 'Source permission and capture metadata are supplied by the operator'};
  const provenance = {contract_id: 'moonfind.csv-recode-provenance.v1', source, plan, changes,
    derived: {file: 'recoded.csv', bytes: output.length, digest: digest(output)}, policies};
  const provenanceBytes = json(provenance);
  if (provenanceBytes.length > LIMITS.capture) fail('Provenance exceeds 32 KiB; use a smaller input');
  const files = {'source.csv': Buffer.from(bytes), 'recoded.csv': output, 'provenance.json': provenanceBytes};
  const limitations = ['Offline local transform; supplied observations and category meanings are not verified.',
    'Native host and installed browser save/reopen were not qualified by this CLI. No provider or network calls.'];
  files['manifest.json'] = json({contract_id: 'moonfind.csv-recode-bundle.v1', files: Object.entries(files).map(([name, data]) => ({name, bytes: data.length, digest: digest(data)})), limitations});
  return {files, preview: {source, columns, rows, changes, matched_count: changes.filter(c => c.matched).length,
    unmatched_count: changes.filter(c => !c.matched).length, policies, limitations}};
}
const HELP = `MoonFind local CSV category recoding (Node 20+)
  node scripts/csv_recode.mjs inspect --csv INPUT.csv
  node scripts/csv_recode.mjs preview --csv INPUT.csv --plan PLAN.json
  node scripts/csv_recode.mjs convert --csv INPUT.csv --plan PLAN.json --out-dir NEW_DIRECTORY
Import recoded.csv with MoonFind's Import CSV table control. See docs/CSV_CATEGORY_RECODING.md.
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
  if (command === 'inspect') { process.stdout.write(JSON.stringify(parseCsv(bytes), null, 2) + '\n'); return; }
  const bundle = createRecodeBundle(bytes, parsePlan(readBounded(resolve(options.get('--plan')), LIMITS.plan, 'Plan')), basename(path));
  if (command === 'preview') process.stdout.write(JSON.stringify(bundle.preview, null, 2) + '\n');
  else { const directory = resolve(options.get('--out-dir')); writeBundle(directory, bundle); process.stdout.write(JSON.stringify({directory, files: Object.keys(bundle.files)}) + '\n'); }
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { main(process.argv.slice(2)); } catch (error) { process.stderr.write(`CSV recode: ${error.message}\n`); process.exitCode = 1; }
}
