#!/usr/bin/env node
// Local, dependency-free CSV -> ordinary CSL JSON. No network or native host calls.
import {createHash} from 'node:crypto';
import {closeSync, constants, fstatSync, mkdirSync, openSync, readSync, writeFileSync} from 'node:fs';
import {basename, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

export const LIMITS = Object.freeze({source: 32768, plan: 16384, columns: 32, rows: 512, capture: 32768});
export const FIELDS = Object.freeze({
  sourceID: 'id', title: 'title', type: 'type', literalAuthor: 'author[0].literal',
  issuedText: 'issued.literal', venue: 'container-title', DOI: 'DOI', URL: 'URL', abstract: 'abstract',
});
const required = new Set(['sourceID', 'title', 'type']);
export const TYPES = Object.freeze(['article', 'article-journal', 'book', 'chapter', 'dataset',
  'manuscript', 'paper-conference', 'report', 'thesis', 'webpage']);
const fail = message => { throw new Error(message); };
const blank = value => value.trim().length === 0;
export const digest = bytes => 'sha256:' + createHash('sha256').update(bytes).digest('hex');
const jsonBytes = value => Buffer.from(JSON.stringify(value, null, 2) + '\n', 'utf8');
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const keys = (value, expected, label) => {
  if (!object(value) || Object.keys(value).length !== expected.length ||
      expected.some(key => !Object.hasOwn(value, key))) fail(`${label}: use exactly ${expected.join(', ')}`);
};
const text = (value, limit, label) => {
  if (typeof value !== 'string' || blank(value) || value.length > limit) fail(`${label}: nonblank text up to ${limit} characters required`);
};
function decode(bytes, max, label) {
  if (!(bytes instanceof Uint8Array) || !bytes.length || bytes.length > max) fail(`${label}: UTF-8 input must be 1–${max} bytes`);
  try { return new TextDecoder('utf-8', {fatal: true, ignoreBOM: true}).decode(bytes); }
  catch { fail(`${label}: invalid UTF-8`); }
}

// Logical records match research/csv.mbt: header=1, first data record=2.
// Keep embedded newlines and all cell strings exactly as supplied.
export function parseCsv(bytes) {
  let input = decode(bytes, LIMITS.source, 'CSV');
  if (input[0] === '\uFEFF') input = input.slice(1);
  if (!input.length) fail('CSV: missing header');
  let position = 0;
  const records = [];
  const separator = character => character === ',' || character === '\r' || character === '\n';
  function field() {
    let value = '';
    if (input[position] === '"') {
      position++;
      while (position < input.length) {
        const character = input[position++];
        if (character !== '"') { value += character; continue; }
        if (input[position] === '"') { value += '"'; position++; continue; }
        if (position < input.length && !separator(input[position])) fail('CSV: expected separator after closing quote');
        return value;
      }
      fail('CSV: unfinished quoted field');
    }
    while (position < input.length && !separator(input[position])) {
      if (input[position] === '"') fail('CSV: quote inside an unquoted field');
      value += input[position++];
    }
    return value;
  }
  while (position < input.length) {
    const values = [];
    while (true) {
      values.push(field());
      if (values.length > LIMITS.columns) fail('CSV: at most 32 columns');
      if (input[position] === ',') { position++; continue; }
      if (input[position] === '\r') position++;
      if (input[position] === '\n') position++;
      break;
    }
    records.push(values);
    if (records.length > LIMITS.rows + 1) fail('CSV: at most 512 data records');
  }
  const columns = records.shift();
  const seen = new Set();
  for (const name of columns) {
    const identity = name.trim().normalize('NFC');
    if (!identity || seen.has(identity)) fail('CSV: blank or ambiguous header names (including surrounding whitespace/Unicode normalization)');
    seen.add(identity);
  }
  const rows = records.map((values, index) => {
    if (values.length !== columns.length) fail(`CSV: record ${index + 2} has ${values.length} fields; expected ${columns.length}`);
    return {record_number: index + 2, values};
  });
  return {columns, rows};
}

export function parsePlan(bytes) {
  const source = decode(bytes, LIMITS.plan, 'Plan').replace(/^\uFEFF/, '');
  // JSON.parse permits duplicate object keys. Reject them rather than silently
  // choosing the last mapping. This lexical pass covers escaped-equivalent keys.
  const stack = [];
  let expectKey = false;
  for (let i = 0; i < source.length; i++) {
    const c = source[i];
    if (c === '"') {
      const start = i;
      for (i++; i < source.length; i++) {
        if (source[i] === '\\') { i++; continue; }
        if (source[i] === '"') break;
      }
      if (expectKey && stack.at(-1)?.keys) {
        let key;
        try { key = JSON.parse(source.slice(start, i + 1)); } catch { fail('Plan: invalid JSON'); }
        const seen = stack.at(-1).keys;
        if (seen.has(key)) fail(`Plan: duplicate JSON key ${JSON.stringify(key)}`);
        seen.add(key);
      }
      expectKey = false;
    } else if (c === '{') { stack.push({keys: new Set()}); expectKey = true; }
    else if (c === '[') { stack.push({}); expectKey = false; }
    else if (c === '}' || c === ']') { stack.pop(); expectKey = false; }
    else if (c === ',') expectKey = Boolean(stack.at(-1)?.keys);
    else if (c === ':') expectKey = false;
  }
  try { return JSON.parse(source); } catch { fail('Plan: invalid JSON'); }
}

function validatePlan(plan, table) {
  keys(plan, ['contract_id', 'mapping', 'record_numbers', 'source'], 'Plan');
  if (plan.contract_id !== 'moonfind.csv-bibliography-plan.v1') fail('Plan: unsupported contract_id');
  keys(plan.source, ['origin', 'captured_at', 'restrictions'], 'Plan source');
  text(plan.source.origin, 2000, 'Source origin');
  text(plan.source.captured_at, 80, 'Source captured_at');
  text(plan.source.restrictions, 2000, 'Source restrictions');
  keys(plan.mapping, Object.keys(FIELDS), 'Mapping');
  const used = new Set();
  const mapping = Object.entries(FIELDS).map(([field, csl_path]) => {
    const column_name = plan.mapping[field];
    if (column_name === null && !required.has(field)) return {field, csl_path, column_number: null, column_name: null};
    if (typeof column_name !== 'string' || !table.columns.includes(column_name)) fail(`Mapping ${field}: choose an exact existing header${required.has(field) ? '' : ' or null'}`);
    if (used.has(column_name)) fail(`Mapping: ambiguous reuse of column ${JSON.stringify(column_name)}`);
    used.add(column_name);
    return {field, csl_path, column_number: table.columns.indexOf(column_name) + 1, column_name};
  });
  const selected = plan.record_numbers;
  if (!Array.isArray(selected) || !selected.length || selected.length > LIMITS.rows ||
      selected.some(n => !Number.isSafeInteger(n) || n < 2 || n > table.rows.length + 1) ||
      new Set(selected).size !== selected.length) fail('Selection: choose unique existing data record numbers (header is record 1)');
  return mapping;
}

export function createBundle(sourceBytes, plan, originalName = 'source.csv') {
  const original = Buffer.from(sourceBytes);
  const table = parseCsv(original);
  text(originalName, 512, 'Original filename');
  if (basename(originalName) !== originalName || !/\.csv$/i.test(originalName)) fail('Original filename: local .csv basename required');
  const mapping = validatePlan(plan, table);
  const resolved = new Map(mapping.map(entry => [entry.field, entry.column_number]));
  const value = (row, key) => resolved.get(key) === null ? null : row.values[resolved.get(key) - 1];
  // Validate IDs across ALL rows, not just the selected subset. Never renumber,
  // trim or numerically coerce a supplied identity (including leading zeroes).
  const ids = new Set();
  for (const row of table.rows) {
    const id = value(row, 'sourceID');
    if (blank(id) || id !== id.trim()) fail(`Record ${row.record_number}: sourceID is blank or has surrounding whitespace`);
    const identity = id.normalize('NFC');
    if (ids.has(identity)) fail(`Record ${row.record_number}: duplicate or ambiguous sourceID ${JSON.stringify(id)}`);
    ids.add(identity);
  }
  const selected = new Set(plan.record_numbers);
  const references = [];
  const recordProvenance = [];
  const previews = [];
  for (const row of table.rows.filter(row => selected.has(row.record_number))) {
    const id = value(row, 'sourceID');
    const title = value(row, 'title');
    const type = value(row, 'type');
    if (blank(title)) fail(`Record ${row.record_number}: title is blank`);
    if (!TYPES.includes(type)) fail(`Record ${row.record_number}: explicitly supply a supported CSL type: ${TYPES.join(', ')}`);
    const item = {id, type, title};
    const omissions = [];
    for (const field of Object.keys(FIELDS).filter(field => !required.has(field))) {
      const cell = value(row, field);
      if (cell === null || blank(cell)) {
        omissions.push({field, reason: cell === null ? 'unmapped' : 'blank-cell'});
      } else if (field === 'literalAuthor') item.author = [{literal: cell}];
      else if (field === 'issuedText') item.issued = {literal: cell};
      else item[FIELDS[field]] = cell;
    }
    const provenance = {
      csl_record_number: references.length + 1, source_record_number: row.record_number,
      source_id: id, availability: Object.hasOwn(item, 'abstract') ? 'metadata-and-abstract' : 'metadata-only',
      omitted_fields: omissions,
    };
    references.push(item);
    recordProvenance.push(provenance);
    previews.push({...provenance, reference: item});
  }
  const csl = jsonBytes(references);
  const source = {
    original_name: originalName, retained_file: 'source.csv', bytes: original.length,
    digest: digest(original), ...plan.source, data_record_count: table.rows.length,
    columns: table.columns,
  };
  const provenance = {
    contract_id: 'moonfind.csv-bibliography-provenance.v1', source,
    derived: {file: 'references.csl.json', bytes: csl.length, digest: digest(csl)},
    mapping, requested_record_numbers: [...plan.record_numbers], records: recordProvenance,
    omitted_source_record_numbers: table.rows.filter(row => !selected.has(row.record_number)).map(row => row.record_number),
    unmapped_columns: table.columns.flatMap((column_name, index) =>
      mapping.some(entry => entry.column_number === index + 1) ? [] : [{column_number: index + 1, column_name}]),
    policies: {
      identity: 'Exact supplied string; no numeric conversion or generated IDs',
      author: 'One literal value; no splitting or inferred personal-name components',
      issued: 'Literal supplied text; no date or year inference',
      availability: 'Metadata and supplied abstract only; full text was not retrieved',
      retention: 'Complete original CSV retained, including unselected rows and unmapped columns; this is not redaction',
    },
  };
  const provenanceBytes = jsonBytes(provenance);
  if (csl.length > LIMITS.capture) fail('CSL output exceeds 32 KiB; select fewer records');
  if (provenanceBytes.length > LIMITS.capture) fail('Provenance exceeds 32 KiB; select fewer records');
  const files = {'source.csv': original, 'references.csl.json': csl, 'provenance.json': provenanceBytes};
  const manifest = {
    contract_id: 'moonfind.csv-bibliography-bundle.v1', complete: true,
    files: Object.entries(files).map(([name, bytes]) => ({name, bytes: bytes.length, digest: digest(bytes)})),
    limitations: ['Native MoonFind intake/save and installed browser interoperability have not been run by this converter.',
      'This bounded CSL subset is not general Zotero compatibility or a full CSL validator.',
      'No source links, DOI services, providers or full text were fetched.'],
  };
  files['manifest.json'] = jsonBytes(manifest);
  return {
    files,
    preview: {contract_id: 'moonfind.csv-bibliography-preview.v1', source,
      mapping, selected_count: references.length, references: previews,
      omitted_source_record_numbers: provenance.omitted_source_record_numbers,
      unmapped_columns: provenance.unmapped_columns, policies: provenance.policies,
      file_sizes: manifest.files.map(({name, bytes}) => ({name, bytes})),
      limitations: manifest.limitations},
  };
}

// Read at most max+1 bytes using an already-open regular file, including when
// another process grows it after fstat. Open nonblocking so an unwritten FIFO
// cannot hang before the regular-file guard. No file is opened for writing.
export function readBounded(path, max, label) {
  const fd = openSync(path, constants.O_RDONLY | constants.O_NONBLOCK);
  try {
    const stat = fstatSync(fd);
    if (!stat.isFile() || stat.size < 1 || stat.size > max) fail(`${label}: choose a regular file of 1–${max} bytes`);
    const buffer = Buffer.alloc(max + 1);
    let length = 0;
    while (length < buffer.length) {
      const count = readSync(fd, buffer, length, buffer.length - length, null);
      if (!count) break;
      length += count;
    }
    if (!length || length > max) fail(`${label}: input changed size or exceeds ${max} bytes`);
    return buffer.subarray(0, length);
  } finally { closeSync(fd); }
}

export function writeBundle(directory, bundle) {
  // A new directory is mandatory. An existing file/directory/symlink is refused.
  // Validate/conversion finishes before this function; manifest is written last.
  mkdirSync(directory, {mode: 0o700});
  for (const [name, bytes] of Object.entries(bundle.files)) {
    writeFileSync(join(directory, name), bytes, {flag: 'wx', mode: 0o600});
  }
}

const HELP = `MoonFind local CSV bibliography bridge (Node 20+, no dependencies)
  node scripts/csv_bibliography.mjs inspect --csv INPUT.csv
  node scripts/csv_bibliography.mjs preview --csv INPUT.csv --plan PLAN.json
  node scripts/csv_bibliography.mjs convert --csv INPUT.csv --plan PLAN.json --out-dir NEW_DIRECTORY

Inspect prints exact header names and logical source records. Preview prints all
selected CSL references, missing metadata and retained-but-unmapped columns/rows.
Convert writes the unchanged CSV, ordinary CSL array, mapping/row provenance and
a final digest manifest. Existing destinations are refused. See
docs/CSV_BIBLIOGRAPHY_MAPPING.md and fixtures/csv-bibliography-plan.json.
`;
export function main(args) {
  if (args.length === 1 && ['--help', '-h'].includes(args[0])) { process.stdout.write(HELP); return; }
  const [command, ...rest] = args;
  const allowed = command === 'inspect' ? ['--csv'] : command === 'preview' ? ['--csv', '--plan'] :
    command === 'convert' ? ['--csv', '--plan', '--out-dir'] : [];
  if (!allowed.length || rest.length !== allowed.length * 2) fail(HELP);
  const options = new Map();
  for (let i = 0; i < rest.length; i += 2) {
    if (!allowed.includes(rest[i]) || options.has(rest[i]) || !rest[i + 1] || rest[i + 1].startsWith('--')) fail('CLI: unknown, duplicate or missing option');
    options.set(rest[i], rest[i + 1]);
  }
  if (allowed.some(key => !options.has(key))) fail('CLI: missing required option');
  const path = resolve(options.get('--csv'));
  if (!/\.csv$/i.test(path)) fail('CSV: choose a local .csv file');
  const bytes = readBounded(path, LIMITS.source, 'CSV');
  if (command === 'inspect') {
    process.stdout.write(JSON.stringify({original_name: basename(path), digest: digest(bytes), ...parseCsv(bytes)}, null, 2) + '\n');
    return;
  }
  const plan = parsePlan(readBounded(resolve(options.get('--plan')), LIMITS.plan, 'Plan'));
  const bundle = createBundle(bytes, plan, basename(path));
  if (command === 'preview') process.stdout.write(JSON.stringify(bundle.preview, null, 2) + '\n');
  else {
    const directory = resolve(options.get('--out-dir'));
    writeBundle(directory, bundle);
    process.stdout.write(JSON.stringify({directory, selected_count: bundle.preview.selected_count,
      files: Object.keys(bundle.files), native_intake_save_run: false}, null, 2) + '\n');
  }
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { main(process.argv.slice(2)); } catch (error) {
    process.stderr.write(`CSV bibliography: ${error.message}\n`);
    process.exitCode = 1;
  }
}
