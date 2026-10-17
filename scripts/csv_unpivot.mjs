#!/usr/bin/env node
// Wide local survey/experiment CSV -> ordinary CSV for MoonFind's evidence explorer.
// Reuse the reviewed bounded reader/parser/writer; never evaluate or fetch cell text.
import {basename, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {digest, LIMITS, parseCsv, parsePlan, readBounded, writeBundle} from './csv_bibliography.mjs';

const fail = message => { throw new Error(message); };
const jsonBytes = value => Buffer.from(JSON.stringify(value, null, 2) + '\n');
const exactKeys = (value, expected, label) => {
  if (value === null || typeof value !== 'object' || Array.isArray(value) ||
      Object.keys(value).length !== expected.length || expected.some(key => !Object.hasOwn(value, key))) {
    fail(`${label}: use exactly ${expected.join(', ')}`);
  }
};
const text = (value, max, label) => {
  if (typeof value !== 'string' || !value.trim() || value.length > max) fail(`${label}: nonblank text up to ${max} characters required`);
};
const quote = value => '"' + value.replaceAll('"', '""') + '"';
// Count serialized UTF-8 bytes before constructing the expanded table/string.
const quotedBytes = value => Buffer.byteLength(value, 'utf8') + 2 + [...value].filter(c => c === '"').length;
const rowBytes = values => values.reduce((total, value) => total + quotedBytes(value), values.length - 1 + 2);
const serialize = rows => Buffer.from(rows.map(row => row.map(quote).join(',')).join('\r\n') + '\r\n');

function validatePlan(plan, table) {
  exactKeys(plan, ['contract_id', 'context_columns', 'question_columns', 'record_numbers', 'empty_policy', 'source'], 'Plan');
  if (plan.contract_id !== 'moonfind.csv-unpivot-plan.v1') fail('Plan: unsupported contract_id');
  exactKeys(plan.source, ['origin', 'captured_at', 'restrictions', 'access'], 'Source');
  text(plan.source.origin, 2000, 'Source origin');
  text(plan.source.captured_at, 80, 'Source captured_at');
  text(plan.source.restrictions, 2000, 'Source restrictions');
  if (plan.source.access !== 'permitted') fail('Source access: explicitly permitted input required; denied or unavailable input cannot become evidence');
  if (jsonBytes(plan).length > LIMITS.plan) fail('Plan: normalized plan exceeds 16 KiB');
  const columns = (values, min, label) => {
    if (!Array.isArray(values) || values.length < min || values.length > LIMITS.columns ||
        new Set(values).size !== values.length || values.some(value => typeof value !== 'string' || !table.columns.includes(value))) {
      fail(`${label}: choose ${min ? 'one or more' : 'zero or more'} unique exact existing headers`);
    }
    return table.columns.map((name, index) => ({name, number: index + 1})).filter(column => values.includes(column.name));
  };
  const context = columns(plan.context_columns, 0, 'Context columns');
  const questions = columns(plan.question_columns, 1, 'Question columns');
  if (context.some(column => plan.question_columns.includes(column.name))) fail('Columns: context and question selections must not overlap');
  if (context.length + 4 > LIMITS.columns) fail('Output: context columns plus four evidence columns exceed 32 columns');
  const selected = plan.record_numbers;
  if (!Array.isArray(selected) || !selected.length || new Set(selected).size !== selected.length ||
      selected.some(n => !Number.isSafeInteger(n) || n < 2 || n > table.rows.length + 1)) fail('Selection: choose unique existing logical data records (header is 1)');
  if (!['keep', 'omit-empty'].includes(plan.empty_policy)) fail('Empty policy: explicitly choose keep or omit-empty');
  if (selected.length * questions.length > LIMITS.rows) fail('Expansion: selected records × question columns exceeds 512; narrow the plan before conversion');
  return {context, questions, selected: new Set(selected)};
}

export function createUnpivotBundle(sourceBytes, plan, originalName = 'source.csv') {
  if (!(sourceBytes instanceof Uint8Array) || sourceBytes.length < 1 || sourceBytes.length > LIMITS.source) fail('CSV: UTF-8 input must be 1–32768 bytes');
  const original = Buffer.from(sourceBytes);
  const table = parseCsv(original);
  text(originalName, 512, 'Original filename');
  if (basename(originalName) !== originalName || !/\.csv$/i.test(originalName)) fail('Original filename: local .csv basename required');
  const {context, questions, selected} = validatePlan(plan, table);
  const columns = ['source_record', 'source_column', ...context.map(column => `context:${column.name}`), 'question', 'answer'];
  const valuesFor = (row, column) => [String(row.record_number), String(column.number),
    ...context.map(c => row.values[c.number - 1]), column.name, row.values[column.number - 1]];
  let outputBytes = rowBytes(columns), outputCount = 0;
  for (const row of table.rows) if (selected.has(row.record_number)) {
    for (const column of questions) {
      if (plan.empty_policy === 'omit-empty' && row.values[column.number - 1] === '') continue;
      outputBytes += rowBytes(valuesFor(row, column));
      outputCount++;
      if (outputBytes > LIMITS.capture) fail('Expanded CSV exceeds 32 KiB; select fewer records/questions/context columns');
    }
  }
  if (!outputCount) fail('Selection produces no evidence rows; choose keep to retain empty answers or select other cells');
  const rows = [], rowMap = [], omittedEmpty = [];
  for (const row of table.rows) if (selected.has(row.record_number)) {
    for (const column of questions) {
      if (plan.empty_policy === 'omit-empty' && row.values[column.number - 1] === '') {
        omittedEmpty.push([row.record_number, column.number]); continue;
      }
      rows.push(valuesFor(row, column));
      rowMap.push([rows.length + 1, row.record_number, column.number]);
    }
  }
  const answers = serialize([columns, ...rows]);
  if (answers.length !== outputBytes) fail('Internal serialized byte-count mismatch');
  const source = {original_name: originalName, retained_file: 'source.csv', bytes: original.length,
    digest: digest(original), data_records: table.rows.length, columns: table.columns, ...plan.source};
  const policies = {
    ordering: 'Original record order, then original question-column order; plan click/order does not reorder evidence',
    values: 'Exact strings; no numeric/date coercion, response splitting, inference, imputation or formula execution',
    empty: plan.empty_policy === 'keep' ? 'All selected cells retained, including empty and whitespace-only answers' :
      'Only exactly empty strings omitted; whitespace-only answers retained; no absent/ragged cells accepted',
    identity: 'Logical source record and one-based question column identify each cell; duplicate/blank respondent labels do not merge rows',
    retention: 'The complete original CSV includes unselected/private cells; this bundle is not redaction',
    authority: 'Access, restrictions and capture metadata are user-supplied, not independently verified; observations are not validated',
  };
  const provenance = {contract_id: 'moonfind.csv-unpivot-provenance.v1', source,
    derived: {file: 'answers.csv', bytes: answers.length, digest: digest(answers), columns, data_records: rows.length},
    plan: structuredClone(plan),
    context_mapping: context.map(c => ({source_column: c.number, source_header: c.name, output_header: `context:${c.name}`})),
    row_map_columns: ['output_record', 'source_record', 'source_column'], row_map: rowMap,
    omitted_empty_cell_columns: ['source_record', 'source_column'], omitted_empty_cells: omittedEmpty,
    omitted_source_records: table.rows.filter(row => !selected.has(row.record_number)).map(row => row.record_number),
    unused_source_columns: table.columns.flatMap((name, index) => context.some(c => c.number === index + 1) ||
      questions.some(c => c.number === index + 1) ? [] : [{number: index + 1, name}]), policies};
  const provenanceBytes = jsonBytes(provenance);
  if (provenanceBytes.length > LIMITS.capture) fail('Provenance exceeds 32 KiB; narrow the plan');
  const files = {'source.csv': original, 'answers.csv': answers, 'provenance.json': provenanceBytes};
  const limitations = ['Local transform only; supplied observations and restrictions are not verified.',
    'Native CSV intake/save/reopen/export and installed browser integration are separate unrun qualification gates.',
    'No gateways, providers, links or other sources were contacted.'];
  const manifest = {contract_id: 'moonfind.csv-unpivot-bundle.v1', complete: true,
    files: Object.entries(files).map(([name, bytes]) => ({name, bytes: bytes.length, digest: digest(bytes)})), limitations};
  files['manifest.json'] = jsonBytes(manifest);
  return {files, preview: {contract_id: 'moonfind.csv-unpivot-preview.v1', source, columns,
    candidate_cells: plan.record_numbers.length * questions.length, output_count: rows.length,
    rows: rows.map((values, index) => ({record_number: index + 2, values})),
    omitted_empty_cells: omittedEmpty, omitted_source_records: provenance.omitted_source_records,
    unused_source_columns: provenance.unused_source_columns, policies,
    file_sizes: manifest.files.map(({name, bytes}) => ({name, bytes})), limitations}};
}

const HELP = `MoonFind wide survey/experiment CSV to long-form evidence (Node 20+, no dependencies)
  node scripts/csv_unpivot.mjs inspect --csv INPUT.csv
  node scripts/csv_unpivot.mjs preview --csv INPUT.csv --plan PLAN.json
  node scripts/csv_unpivot.mjs convert --csv INPUT.csv --plan PLAN.json --out-dir NEW_DIRECTORY

Inspect headers and logical records, explicitly choose context/questions/records
and an empty-cell policy, then preview before converting. Import answers.csv with
MoonFind's existing Import CSV table control. Retain source.csv and provenance.json
alongside the selected evidence in the brief. Existing destinations are refused.
See docs/CSV_SURVEY_UNPIVOT.md and fixtures/survey-unpivot-plan.json.
`;
export function main(args) {
  if (args.length === 1 && ['--help', '-h'].includes(args[0])) { process.stdout.write(HELP); return; }
  const [command, ...rest] = args;
  const allowed = command === 'inspect' ? ['--csv'] : command === 'preview' ? ['--csv', '--plan'] :
    command === 'convert' ? ['--csv', '--plan', '--out-dir'] : [];
  if (!allowed.length || rest.length !== allowed.length * 2) fail(HELP);
  const options = new Map();
  for (let index = 0; index < rest.length; index += 2) {
    if (!allowed.includes(rest[index]) || options.has(rest[index]) || !rest[index + 1] || rest[index + 1].startsWith('--')) fail('CLI: unknown, duplicate or missing option');
    options.set(rest[index], rest[index + 1]);
  }
  if (allowed.some(key => !options.has(key))) fail('CLI: missing required option');
  const path = resolve(options.get('--csv'));
  if (!/\.csv$/i.test(path)) fail('CSV: choose a local .csv file');
  const bytes = readBounded(path, LIMITS.source, 'CSV');
  if (command === 'inspect') {
    process.stdout.write(JSON.stringify({original_name: basename(path), digest: digest(bytes), ...parseCsv(bytes)}, null, 2) + '\n'); return;
  }
  const plan = parsePlan(readBounded(resolve(options.get('--plan')), LIMITS.plan, 'Plan'));
  const bundle = createUnpivotBundle(bytes, plan, basename(path));
  if (command === 'preview') process.stdout.write(JSON.stringify(bundle.preview, null, 2) + '\n');
  else {
    const directory = resolve(options.get('--out-dir')); writeBundle(directory, bundle);
    process.stdout.write(JSON.stringify({directory, output_count: bundle.preview.output_count,
      files: Object.keys(bundle.files), native_intake_save_run: false}, null, 2) + '\n');
  }
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { main(process.argv.slice(2)); } catch (error) { process.stderr.write(`CSV unpivot: ${error.message}\n`); process.exitCode = 1; }
}
