#!/usr/bin/env node
// Local exact-key whole-row selection. No inferred keys, cell merges or network.
import {basename, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {digest, LIMITS, parseCsv, parsePlan, readBounded, writeBundle} from './csv_bibliography.mjs';

export const SOURCE_RECORD_COLUMN = 'consolidation_source_record';
const fail = message => { throw new Error(message); };
const json = value => Buffer.from(JSON.stringify(value, null, 2) + '\n');
const exact = (value, names, label) => {
  if (!value || typeof value !== 'object' || Array.isArray(value) || Object.keys(value).length !== names.length || names.some(name => !Object.hasOwn(value, name))) fail(`${label}: expected exactly ${names.join(', ')}`);
};
const text = (value, max, label) => { if (typeof value !== 'string' || !value.trim() || value.length > max) fail(`${label}: nonblank text up to ${max} characters required`); };
const csv = rows => Buffer.from(rows.map(row => row.map(value => '"' + value.replaceAll('"', '""') + '"').join(',')).join('\r\n') + '\r\n');

function derivedFiles(preview) {
  const output = csv([preview.columns, ...preview.rows.map(row => row.values)]);
  const provenance = {contract_id: 'moonfind.csv-consolidate-provenance.v1', source: preview.source, plan: preview.plan,
    derived: {file: 'consolidated.csv', bytes: output.length, digest: digest(output), columns: preview.columns, data_records: preview.rows.length},
    groups: preview.groups, policies: preview.policies};
  return {'consolidated.csv': output, 'provenance.json': json(provenance)};
}

export function previewConsolidation(bytes, plan, originalName = 'source.csv') {
  const table = parseCsv(bytes);
  text(originalName, 512, 'Original filename');
  if (basename(originalName) !== originalName || !/\.csv$/i.test(originalName)) fail('Original filename must be a .csv basename');
  exact(plan, ['contract_id', 'key_columns', 'duplicate_policy', 'empty_keys', 'source'], 'Plan');
  if (plan.contract_id !== 'moonfind.csv-consolidate-plan.v1') fail('Unsupported plan contract');
  if (json(plan).length > LIMITS.plan) fail('Plan exceeds 16 KiB');
  if (!Array.isArray(plan.key_columns) || !plan.key_columns.length || plan.key_columns.length > LIMITS.columns || plan.key_columns.some(name => typeof name !== 'string' || !table.columns.includes(name)) || new Set(plan.key_columns).size !== plan.key_columns.length) fail('Choose distinct exact existing key columns');
  if (!['keep-first', 'keep-last', 'error'].includes(plan.duplicate_policy)) fail('Duplicate policy must be keep-first, keep-last or error');
  if (!['error', 'keep-separate'].includes(plan.empty_keys)) fail('Empty keys policy must be error or keep-separate');
  exact(plan.source, ['origin', 'captured_at', 'restrictions', 'access'], 'Source');
  text(plan.source.origin, 2000, 'Origin'); text(plan.source.captured_at, 80, 'Captured at'); text(plan.source.restrictions, 2000, 'Restrictions');
  if (plan.source.access !== 'permitted') fail('Source access must be permitted');
  if (table.columns.length >= LIMITS.columns) fail('Consolidation allows at most 31 input columns to retain source record identity');
  if (table.columns.some(name => name.trim().normalize('NFC') === SOURCE_RECORD_COLUMN)) fail(`Reserved output column already exists: ${SOURCE_RECORD_COLUMN}`);
  const indexes = plan.key_columns.map(name => table.columns.indexOf(name));
  const grouped = new Map(), emptyRecords = [];
  for (const row of table.rows) {
    const values = indexes.map(index => row.values[index]), empty = values.some(value => value === '');
    if (empty) emptyRecords.push(row.record_number);
    // JSON array encoding avoids delimiter, quoting and composite-key collisions.
    // Any empty component is isolated by source record, never matched implicitly.
    const key = empty ? `record:${row.record_number}` : JSON.stringify(values);
    if (!grouped.has(key)) grouped.set(key, {key_values: values, empty_key: empty, members: []});
    grouped.get(key).members.push(row);
  }
  const duplicateGroups = [...grouped.values()].filter(group => group.members.length > 1);
  const blockers = [];
  if (emptyRecords.length && plan.empty_keys === 'error') blockers.push(`Empty key components at source records ${emptyRecords.join(', ')}; choose keep-separate explicitly or repair a separate input copy`);
  if (duplicateGroups.length && plan.duplicate_policy === 'error') blockers.push(`Duplicate keys in ${duplicateGroups.length} groups; choose keep-first or keep-last explicitly, or repair a separate input copy`);
  const canConvert = blockers.length === 0, rows = [], groups = [];
  for (const group of grouped.values()) {
    const conflicts = [];
    for (let index = 0; index < table.columns.length; index++) {
      if (indexes.includes(index)) continue;
      const values = new Map();
      for (const member of group.members) {
        const value = member.values[index];
        if (!values.has(value)) values.set(value, []);
        values.get(value).push(member.record_number);
      }
      if (values.size > 1) conflicts.push({column: table.columns[index], values: [...values].map(([value, source_records]) => ({value, source_records}))});
    }
    const selected = canConvert ? (plan.duplicate_policy === 'keep-last' ? group.members.at(-1) : group.members[0]) : null;
    const outputRecord = selected ? rows.length + 2 : null;
    if (selected) rows.push({record_number: outputRecord, values: [...selected.values, String(selected.record_number)]});
    groups.push({key_values: group.key_values, empty_key: group.empty_key,
      source_records: group.members.map(member => member.record_number), conflicts,
      selected_source_record: selected?.record_number ?? null, output_record: outputRecord,
      omitted_source_records: selected ? group.members.filter(member => member !== selected).map(member => member.record_number) : []});
  }
  const policies = {
    matching: 'Exact case-sensitive decoded string tuples. No trimming, Unicode normalization, numeric coercion or guessed keys. Empty means the empty string only.',
    duplicates: 'One entire original row is chosen. No cell merging, aggregation or inference. Error blocks all duplicate keys, even identical rows.',
    ordering: 'Groups appear in first-occurrence order. First/last means input logical record order, never observation time or quality.',
    lineage: 'Original header is logical record 1; multiline fields do not create extra records. The new consolidation_source_record column identifies the chosen original row; groups retain every member record.',
    values: 'Original cell text is unchanged. Formula-like text is inert here but spreadsheet software may execute it.',
    retention: 'Complete original source bytes, including omitted rows and private columns, are retained. This is not redaction.',
    authority: 'Access, origin, capture time, restrictions and duplicate interpretation are operator-declared and not verified.',
  };
  const preview = {contract_id: 'moonfind.csv-consolidate-preview.v1',
    source: {original_name: originalName, digest: digest(bytes), bytes: bytes.length, ...structuredClone(plan.source)},
    plan: structuredClone(plan), columns: [...table.columns, SOURCE_RECORD_COLUMN], rows, groups,
    input_count: table.rows.length, group_count: groups.length, duplicate_group_count: duplicateGroups.length,
    conflict_group_count: groups.filter(group => group.conflicts.length > 0).length,
    empty_key_records: emptyRecords, output_count: canConvert ? rows.length : null,
    omitted_count: canConvert ? table.rows.length - rows.length : null, can_convert: canConvert, blockers, policies,
    limitations: ['Local whole-row selection only; equal keys do not prove observations describe the same entity.',
      'Provenance JSON is not automatically loaded by CSV intake. Retain it and source.csv with the consolidated CSV.',
      'Native host, browser mounting, installed persistence, provider execution and full release gates are not qualified by this CLI.'],
  };
  if (canConvert) {
    const files = derivedFiles(preview);
    preview.file_sizes = Object.entries(files).map(([name, data]) => ({name, bytes: data.length}));
    for (const [name, data] of Object.entries(files)) if (data.length > LIMITS.capture) blockers.push(`${name} exceeds 32 KiB; use a smaller input`);
    preview.can_convert = blockers.length === 0;
  }
  return preview;
}

export function createConsolidationBundle(bytes, plan, originalName = 'source.csv') {
  const preview = previewConsolidation(bytes, plan, originalName);
  if (!preview.can_convert) fail(preview.blockers.join('; '));
  const files = {'source.csv': Buffer.from(bytes), ...derivedFiles(preview)};
  parseCsv(files['consolidated.csv']);
  files['manifest.json'] = json({contract_id: 'moonfind.csv-consolidate-bundle.v1',
    files: Object.entries(files).map(([name, data]) => ({name, bytes: data.length, digest: digest(data)})), limitations: preview.limitations});
  return {files, preview};
}

const HELP = `MoonFind local CSV duplicate consolidation (Node 20+)
  node scripts/csv_consolidate.mjs inspect --csv INPUT.csv
  node scripts/csv_consolidate.mjs preview --csv INPUT.csv --plan PLAN.json
  node scripts/csv_consolidate.mjs convert --csv INPUT.csv --plan PLAN.json --out-dir NEW_DIRECTORY
Import consolidated.csv with the ordinary Import CSV table control. Keep source.csv and provenance.json.
Preview includes groups, conflicting cell values, exact source records and any policy blockers.
See docs/CSV_RECORD_CONSOLIDATION.md.
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
  if (command === 'inspect') { process.stdout.write(JSON.stringify({digest: digest(bytes), ...parseCsv(bytes)}, null, 2) + '\n'); return; }
  const plan = parsePlan(readBounded(resolve(options.get('--plan')), LIMITS.plan, 'Plan'));
  if (command === 'preview') process.stdout.write(JSON.stringify(previewConsolidation(bytes, plan, basename(path)), null, 2) + '\n');
  else {
    const bundle = createConsolidationBundle(bytes, plan, basename(path)), directory = resolve(options.get('--out-dir'));
    writeBundle(directory, bundle);
    process.stdout.write(JSON.stringify({directory, output_count: bundle.preview.output_count, omitted_count: bundle.preview.omitted_count, files: Object.keys(bundle.files), installed_intake_run: false}) + '\n');
  }
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { main(process.argv.slice(2)); } catch (error) { process.stderr.write(`CSV consolidation: ${error.message}\n`); process.exitCode = 1; }
}
