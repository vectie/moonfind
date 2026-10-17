#!/usr/bin/env node
// Local long-form measurements -> an inspectable wide comparison table.
import { basename, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { digest, LIMITS, parseCsv, parsePlan, readBounded, writeBundle } from './csv_bibliography.mjs';
const fail = text => { throw new Error(text); };
const json = value => Buffer.from(JSON.stringify(value, null, 2) + '\n');
const csv = rows => Buffer.from(rows.map(row => row.map(v => '"' + v.replaceAll('"', '""') + '"').join(',')).join('\r\n') + '\r\n');
export function createPivotBundle(bytes, plan) {
  const keys = ['contract_id','row_column','column_column','value_column','duplicate_policy','source'];
  if (!plan || Object.keys(plan).length !== keys.length || keys.some(k => !Object.hasOwn(plan,k)) || plan.contract_id !== 'moonfind.csv-pivot-plan.v1') fail('Use the documented CSV pivot plan');
  if (json(plan).length > LIMITS.plan) fail('Plan exceeds 16 KiB');
  const sourceKeys=['origin','captured_at','restrictions','access'];
  if (!plan.source || Object.keys(plan.source).length !== 4 || sourceKeys.some(k=>!Object.hasOwn(plan.source,k)) || plan.source.access !== 'permitted') fail('Source must declare origin, captured_at, restrictions and permitted access');
  for(const k of sourceKeys) if(typeof plan.source[k] !== 'string' || !plan.source[k].trim() || plan.source[k].length > 2000) fail('Source metadata must be nonblank bounded text');
  const table=parseCsv(bytes), names=[plan.row_column,plan.column_column,plan.value_column];
  if(new Set(names).size !== 3 || names.some(v=>typeof v !== 'string'||!table.columns.includes(v))) fail('Choose three distinct exact existing headers');
  if(!['error','first','last'].includes(plan.duplicate_policy)) fail('Duplicate policy must be error, first or last');
  const [ri,ci,vi]=names.map(v=>table.columns.indexOf(v));
  const rowKeys=[],columnKeys=[],cells=new Map();
  for(const row of table.rows) {
    const r=row.values[ri],c=row.values[ci];
    if(!c.trim()) fail('Pivot column values must be nonblank');
    if(!rowKeys.includes(r)) rowKeys.push(r);
    if(!columnKeys.includes(c)) columnKeys.push(c);
    if(columnKeys.length>31) fail('Pivot exceeds 31 value columns');
    const key=JSON.stringify([r,c]);
    const prior=cells.get(key);
    if(prior) {
      if(plan.duplicate_policy==='error') fail(`Duplicate cell at source record ${row.record_number}; select first or last explicitly`);
      prior.records.push(row.record_number);
      if(plan.duplicate_policy==='last') { prior.value=row.values[vi]; prior.selected_record=row.record_number; }
    } else cells.set(key,{value:row.values[vi],records:[row.record_number],selected_record:row.record_number});
  }
  const columns=[plan.row_column,...columnKeys];
  // The shared parser detects ambiguous/duplicate output headers (including row header).
  parseCsv(csv([columns]));
  const mapping=[];
  const rows=rowKeys.map((r,i)=>[r,...columnKeys.map((c,j)=>{
    const cell=cells.get(JSON.stringify([r,c]));
    if(cell) mapping.push({output_record:i+2,output_column:j+2,source_records:cell.records,selected_record:cell.selected_record});
    return cell?.value ?? '';
  })]);
  if(!rows.length) fail('No data records to pivot');
  const output=csv([columns,...rows]);
  if(output.length>LIMITS.source) fail('Pivot CSV exceeds 32 KiB');
  const provenance=json({contract_id:'moonfind.csv-pivot-provenance.v1',source:{...plan.source,file:'source.csv',digest:digest(bytes)},plan,output:{file:'pivoted.csv',digest:digest(output)},cells:mapping,missing_cell:'Empty string; absence is distinguished by no provenance cell entry',order:'First appearance of row and column values; exact text matching; no numeric conversion'});
  if(provenance.length>LIMITS.capture) fail('Provenance exceeds 32 KiB');
  const files={'source.csv':bytes,'pivoted.csv':output,'provenance.json':provenance};
  files['manifest.json']=json({contract_id:'moonfind.csv-pivot-bundle.v1',files:Object.entries(files).map(([name,b])=>({name,bytes:b.length,digest:digest(b)}))});
  return {files,preview:{columns,rows:rows.map((values,i)=>({record_number:i+2,values})),output_count:rows.length,duplicate_policy:plan.duplicate_policy,cell_mapping:mapping}};
}
const HELP='CSV pivot: node scripts/csv_pivot.mjs inspect --csv INPUT.csv | preview --csv INPUT.csv --plan PLAN.json | convert --csv INPUT.csv --plan PLAN.json --out-dir NEW_DIRECTORY\n';
export function main(args) {
  if(args.length===1&&['-h','--help'].includes(args[0])) {process.stdout.write(HELP);return;}
  const [command,...rest]=args, options=new Map();
  if(!['inspect','preview','convert'].includes(command)||rest.length%2) fail(HELP);
  for(let i=0;i<rest.length;i+=2) {if(!['--csv','--plan','--out-dir'].includes(rest[i])||options.has(rest[i])||!rest[i+1]||rest[i+1].startsWith('--')) fail(HELP);options.set(rest[i],rest[i+1]);}
  if(!options.has('--csv')||options.size!==(command==='inspect'?1:command==='preview'?2:3)||options.has('--plan')!==(command!=='inspect')||options.has('--out-dir')!==(command==='convert')) fail(HELP);
  const bytes=readBounded(resolve(options.get('--csv')),LIMITS.source,'CSV');
  if(command==='inspect') {process.stdout.write(JSON.stringify({name:basename(options.get('--csv')),...parseCsv(bytes)},null,2)+'\n');return;}
  const bundle=createPivotBundle(bytes,parsePlan(readBounded(resolve(options.get('--plan')),LIMITS.plan,'Plan')));
  if(command==='preview') process.stdout.write(JSON.stringify(bundle.preview,null,2)+'\n');
  else {const directory=resolve(options.get('--out-dir'));writeBundle(directory,bundle);process.stdout.write(JSON.stringify({directory,output_count:bundle.preview.output_count})+'\n');}
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)) {try{main(process.argv.slice(2));}catch(error){process.stderr.write('CSV pivot: '+error.message+'\n');process.exitCode=1;}}
