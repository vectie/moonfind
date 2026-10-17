#!/usr/bin/env node
// Explicitly mapped concatenation of local datasets, retaining every original.
import {basename, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {digest, LIMITS, parseCsv, parsePlan, readBounded, writeBundle} from './csv_bibliography.mjs';
const fail = message => { throw new Error(message); };
const json = value => Buffer.from(JSON.stringify(value, null, 2) + '\n');
const exact = (value, keys, label) => {
  if (!value || typeof value !== 'object' || Array.isArray(value) || Object.keys(value).length !== keys.length || keys.some(k => !Object.hasOwn(value, k))) fail(`${label}: expected exactly ${keys.join(', ')}`);
};
const text = (v, n, label) => { if (typeof v !== 'string' || !v.trim() || v.length > n) fail(`${label}: nonblank text up to ${n} characters required`); };
const csv = rows => Buffer.from(rows.map(row => row.map(v => '"' + v.replaceAll('"','""') + '"').join(',')).join('\r\n')+'\r\n');
export function createAppendBundle(inputs, plan) {
  exact(plan,['contract_id','columns','sources'],'Plan');
  if (plan.contract_id !== 'moonfind.csv-append-plan.v1') fail('Unsupported plan');
  if (json(plan).length > LIMITS.plan) fail('Plan exceeds 16 KiB');
  if (!Array.isArray(inputs) || inputs.length < 2 || inputs.length > 8 || !Array.isArray(plan.sources) || plan.sources.length !== inputs.length) fail('Choose 2..8 inputs with one explicit source mapping each');
  if (!Array.isArray(plan.columns) || plan.columns.length < 1 || plan.columns.length > 30) fail('Choose 1..30 output columns');
  plan.columns.forEach(v => text(v,512,'Output column'));
  const columns = ['source_id','source_record',...plan.columns];
  // Shared parser enforces normalized header uniqueness, including reserved names.
  parseCsv(csv([columns]));
  const files = {}, sources = [], rows = [], rowMap = [];
  for (let index = 0; index < inputs.length; index++) {
    const input = inputs[index], spec = plan.sources[index];
    exact(input,['name','bytes'],'Input');
    text(input.name,512,'Input name');
    if (basename(input.name) !== input.name || !/\.csv$/i.test(input.name)) fail('Input name must be a CSV basename');
    exact(spec,['id','mapping','origin','captured_at','restrictions','access'],'Source');
    text(spec.id,80,'Source id');
    if (sources.some(s => s.id === spec.id)) fail('Duplicate source id');
    for (const key of ['origin','restrictions']) text(spec[key],2000,key);
    text(spec.captured_at,80,'Capture time');
    if (spec.access !== 'permitted') fail('Only explicitly permitted sources can become evidence');
    const table = parseCsv(input.bytes);
    if (!Array.isArray(spec.mapping) || spec.mapping.length !== plan.columns.length || spec.mapping.some(c => typeof c !== 'string' || !table.columns.includes(c)) || new Set(spec.mapping).size !== spec.mapping.length) fail('Mapping must name one distinct exact existing source header per output column');
    if (rows.length + table.rows.length > LIMITS.rows) fail('Appended output exceeds 512 records');
    const positions = spec.mapping.map(c => table.columns.indexOf(c));
    const retained = `source-${index+1}.csv`;
    files[retained] = Buffer.from(input.bytes);
    sources.push({...structuredClone(spec), original_name:input.name, retained_file:retained, digest:digest(input.bytes), bytes:input.bytes.length, columns:table.columns, data_records:table.rows.length, unused_columns:table.columns.filter(c => !spec.mapping.includes(c))});
    for (const row of table.rows) {
      rows.push([spec.id,String(row.record_number),...positions.map(p => row.values[p])]);
      rowMap.push([rows.length+1,index+1,row.record_number]);
    }
  }
  if (!rows.length) fail('Append produces no data records');
  const appended = csv([columns,...rows]);
  if (appended.length > LIMITS.capture) fail('Appended CSV exceeds 32 KiB; use smaller source datasets');
  // Verify the ordinary intake contract, not merely our serializer.
  parseCsv(appended);
  const policies = {ordering:'Input order, then original logical record order (header is 1). No joins, deduplication, sorting or inference.', values:'Exact strings, including blanks, duplicate records and formula-looking text; no execution or type coercion.', retention:'All source bytes are retained, including unused/private columns. This is not redaction.', authority:'Access, origin, capture time and restrictions are supplied by the user, not independently verified.'};
  const provenance = {contract_id:'moonfind.csv-append-provenance.v1', sources, plan:structuredClone(plan), derived:{file:'appended.csv',digest:digest(appended),bytes:appended.length,columns,data_records:rows.length}, row_map_columns:['output_record','source_number','source_record'],row_map:rowMap,policies};
  const provenanceBytes = json(provenance);
  if (provenanceBytes.length > LIMITS.capture) fail('Provenance exceeds 32 KiB');
  files['appended.csv']=appended; files['provenance.json']=provenanceBytes;
  const limitations=['Local mapped append only. Retained explorer JS consumer tests do not qualify installed browser, host intake, save/reopen, provider or release gates.'];
  const manifest={contract_id:'moonfind.csv-append-bundle.v1',complete:true,files:Object.entries(files).map(([name,b])=>({name,bytes:b.length,digest:digest(b)})),limitations};
  files['manifest.json']=json(manifest);
  return {files,preview:{contract_id:'moonfind.csv-append-preview.v1',columns,rows:rows.map((values,i)=>({record_number:i+2,values})),output_count:rows.length,sources,policies,limitations}};
}
const HELP=`Mapped CSV append (Node 20+, local only)\n  node scripts/csv_append.mjs inspect --csv INPUT.csv\n  node scripts/csv_append.mjs preview --csv FIRST.csv --csv SECOND.csv [--csv ...] --plan PLAN.json\n  node scripts/csv_append.mjs convert --csv FIRST.csv --csv SECOND.csv [--csv ...] --plan PLAN.json --out-dir NEW_DIRECTORY\nImport appended.csv with the ordinary Import CSV table control; keep provenance.json and originals. See docs/CSV_MAPPED_APPEND.md.\n`;
export function main(args) {
  if(args.length===1 && ['--help','-h'].includes(args[0])) {process.stdout.write(HELP);return;}
  const [command,...rest]=args;
  if(!['inspect','preview','convert'].includes(command)||rest.length%2) fail(HELP);
  const paths=[], options=new Map();
  for(let i=0;i<rest.length;i+=2) {
    const key=rest[i], value=rest[i+1];
    if(!value||value.startsWith('--')) fail('Missing option value');
    if(key==='--csv') paths.push(value);
    else if(['--plan','--out-dir'].includes(key)&&!options.has(key)) options.set(key,value);
    else fail('Unknown or duplicate option');
  }
  if(command==='inspect' ? paths.length!==1||options.size : paths.length<2||paths.length>8||!options.has('--plan')||options.size!==(command==='convert'?2:1)||options.has('--out-dir')!==(command==='convert')) fail(HELP);
  const inputs=paths.map(p=>({name:basename(p),bytes:readBounded(resolve(p),LIMITS.source,'CSV')}));
  if(command==='inspect') {process.stdout.write(JSON.stringify({name:inputs[0].name,digest:digest(inputs[0].bytes),...parseCsv(inputs[0].bytes)},null,2)+'\n');return;}
  const plan=parsePlan(readBounded(resolve(options.get('--plan')),LIMITS.plan,'Plan'));
  const bundle=createAppendBundle(inputs,plan);
  if(command==='preview') process.stdout.write(JSON.stringify(bundle.preview,null,2)+'\n');
  else {const directory=resolve(options.get('--out-dir'));writeBundle(directory,bundle);process.stdout.write(JSON.stringify({directory,output_count:bundle.preview.output_count,files:Object.keys(bundle.files),installed_intake_run:false})+'\n');}
}
if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  try{main(process.argv.slice(2));}catch(e){process.stderr.write('CSV append: '+e.message+'\n');process.exitCode=1;}
}
