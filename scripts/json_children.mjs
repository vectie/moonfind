#!/usr/bin/env node
// Local JSON child observations -> ordinary CSV, with original bytes and lineage.
import {basename,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {digest,LIMITS,parseCsv,parsePlan,readBounded,writeBundle} from './csv_bibliography.mjs';
import {parseJsonValues,resolveValue,pointerTokens,pointerKey} from './json_child_values.mjs';

export const LINEAGE_COLUMNS=Object.freeze(['source_digest','parent_index','parent_pointer','child_index','child_pointer']);
const fail=message=>{throw new Error(message);};
const json=value=>Buffer.from(JSON.stringify(value,null,2)+'\n');
const csvRow=values=>Buffer.from(values.map(value=>'"'+value.replaceAll('"','""')+'"').join(',')+'\r\n');
const exact=(value,keys,label)=>{
  if(!value||typeof value!=='object'||Array.isArray(value)||Object.keys(value).length!==keys.length||keys.some(key=>!Object.hasOwn(value,key)))fail(`${label}: expected exactly ${keys.join(', ')}`);
};
const text=(value,max,label)=>{if(typeof value!=='string'||!value.trim()||value.length>max)fail(`${label}: nonblank text up to ${max} units required`);};
const isMapPlan=plan=>plan?.contract_id==='moonfind.json-child-map-plan.v1';
const contract=(plan,kind)=>`moonfind.json-${isMapPlan(plan)?'child-map':'children'}-${kind}.v1`;
function validate(plan,bytes) {
  const keyed=isMapPlan(plan),container=keyed?'maps':'arrays',valueScope=keyed?'value':'child';
  exact(plan,['contract_id','source_digest','parent_pointer','children_pointer','child_mode','empty_'+container,'missing_'+container,'fields','source'],'Plan');
  if(!keyed&&plan.contract_id!=='moonfind.json-children-plan.v1')fail('Unsupported plan contract');
  if(json(plan).length>LIMITS.plan)fail('Plan exceeds 16 KiB');
  if(plan.source_digest!==digest(bytes))fail('Source digest changed or is missing; inspect the current original and review a new plan');
  pointerTokens(plan.parent_pointer);pointerTokens(plan.children_pointer);
  if(plan.children_pointer==='')fail('Choose a nonempty children pointer relative to each parent');
  if(!['records','scalars'].includes(plan.child_mode))fail('Child mode must explicitly be records or scalars');
  if(!['error','skip'].includes(plan['empty_'+container])||!['error','skip'].includes(plan['missing_'+container]))fail(`Empty and missing ${container} policies must each be error or skip`);
  if(!Array.isArray(plan.fields)||!plan.fields.length||plan.fields.length>13)fail('Choose 1–13 explicit fields (each produces value and kind columns)');
  const columns=[...LINEAGE_COLUMNS],seen=new Set(columns);
  for(const field of plan.fields) {
    exact(field,['scope','pointer','name'],'Field');
    if(!(keyed?['parent','key','value']:['parent','child']).includes(field.scope))fail(keyed?'Field scope must be parent, key or value':'Field scope must be parent or child');
    pointerTokens(field.pointer);text(field.name,80,'Column name');
    if(field.scope==='key'&&field.pointer!=='')fail('Key fields must use the empty pointer for the member key token');
    if(plan.child_mode==='scalars'&&field.scope===valueScope&&field.pointer!=='')fail('Scalar child fields must use the empty pointer for the whole scalar');
    for(const name of [field.name,field.name+'_kind']) {
      const identity=name.trim().normalize('NFC');
      if(seen.has(identity))fail('Duplicate, ambiguous or reserved output column '+JSON.stringify(name));seen.add(identity);columns.push(name);
    }
  }
  if(!plan.fields.some(field=>field.scope===valueScope))fail(`Choose at least one ${valueScope} field`);
  if(keyed&&!plan.fields.some(field=>field.scope==='key'))fail('Choose at least one key field');
  exact(plan.source,['origin','captured_at','restrictions','access'],'Source');
  text(plan.source.origin,2000,'Origin');text(plan.source.captured_at,80,'Captured at');text(plan.source.restrictions,2000,'Restrictions');
  if(plan.source.access!=='permitted')fail('Source access must be permitted');
  // Check header ambiguity and ensure escaped surrogate names cannot silently
  // change during UTF-8 encoding. Data values below use raw source tokens.
  const header=csvRow(columns),decoded=parseCsv(header).columns;
  if(decoded.some((name,i)=>name!==columns[i]))fail('Column names must encode exactly as UTF-8');
  return columns;
}

export function inspectChildren(bytes) {
  const parsed=parseJsonValues(bytes),arrays=[],maps=[];let total=0,mapTotal=0;
  const visit=(node,pointer)=>{
    if(node.type==='array') {total++;if(arrays.length<64)arrays.push({pointer,count:node.children.length,first_child_types:node.children.slice(0,8).map(item=>item.node.type)});}
    if(node.type==='object') {mapTotal++;if(maps.length<64)maps.push({pointer,count:node.children.length,first_keys:node.children.slice(0,8).map(item=>item.key),first_value_types:node.children.slice(0,8).map(item=>item.node.type)});}
    for(const child of node.children)visit(child.node,pointer+'/'+pointerKey(child.key));
  };
  visit(parsed.root,'');
  return {contract_id:'moonfind.json-children-inspect.v1',digest:digest(bytes),bytes:bytes.length,root_type:parsed.root.type,nodes:parsed.nodes,arrays,array_count:total,inventory_shortened:total>arrays.length,maps,map_count:mapTotal,map_inventory_shortened:mapTotal>maps.length};
}

function derive(preview) {
  const output=Buffer.concat([csvRow(preview.columns),...preview.rows.map(row=>csvRow(row.values))]);
  const provenance=json({contract_id:contract(preview.plan,'provenance'),source:preview.source,plan:preview.plan,
    derived:{file:'observations.csv',bytes:output.length,digest:digest(output),columns:preview.columns,data_records:preview.rows.length},
    parents:preview.parents,records:preview.lineage,policies:preview.policies});
  if(output.length>LIMITS.capture)fail('observations.csv exceeds 32 KiB');
  if(provenance.length>LIMITS.capture)fail('provenance.json exceeds 32 KiB; use fewer parents, children or fields');
  return {'observations.csv':output,'provenance.json':provenance};
}
export function previewChildren(bytes,plan,originalName='source.json') {
  const parsed=parseJsonValues(bytes),columns=validate(plan,bytes);
  const keyed=isMapPlan(plan),container=keyed?'map':'array',expectedType=keyed?'object':'array';
  text(originalName,512,'Original filename');if(basename(originalName)!==originalName||!/\.json$/i.test(originalName))fail('Original filename must be a .json basename');
  const parentArray=resolveValue(parsed.root,plan.parent_pointer);
  if(parentArray?.type!=='array')fail('Parent pointer must select an existing array');
  if(parentArray.children.length>LIMITS.rows)fail('At most 512 parent records');
  const rows=[],lineage=[],parents=[],blockers=[];let outputBytes=csvRow(columns).length,lineageBytes=0;
  const sourceDigest=digest(bytes);
  for(const [parentIndex,{node:parent}] of parentArray.children.entries()) {
    const parentPointer=plan.parent_pointer+'/'+parentIndex,childrenPointer=parentPointer+plan.children_pointer;
    if(parent.type!=='object')fail(`Parent ${parentPointer} must be an object`);
    const children=resolveValue(parent,plan.children_pointer),state=!children?'missing':children.type!==expectedType?children.type:children.children.length?'children':'empty';
    if(!['missing','empty','children'].includes(state))fail(`Child ${container} ${childrenPointer} is ${state}, not ${expectedType}; null and other container types are not missing`);
    const policy=state==='missing'?plan['missing_'+container+'s']:state==='empty'?plan['empty_'+container+'s']:null;
    parents.push({parent_index:parentIndex,parent_pointer:parentPointer,children_pointer:childrenPointer,state,child_count:children?.children.length??null,action:policy??'expand'});
    if(policy==='error')blockers.push(`${state} child ${container} at ${childrenPointer}; choose skip explicitly or repair a separate source copy`);
    if(policy)continue;
    for(const [childIndex,entry] of children.children.entries()) {
      const child=entry.node,childPointer=childrenPointer+'/'+pointerKey(entry.key);
      if(plan.child_mode==='records'&&child.type!=='object')fail(`Child ${childPointer} must be an object in records mode`);
      if(plan.child_mode==='scalars'&&['object','array'].includes(child.type))fail(`Child ${childPointer} must be scalar in scalars mode`);
      if(rows.length>=LIMITS.rows)fail('Expansion exceeds 512 observations');
      const values=[sourceDigest,String(parentIndex),parentPointer,String(childIndex),childPointer],cells=[];
      for(const field of plan.fields) {
        if(field.scope==='key') {
          values.push(parsed.text.slice(entry.key_start,entry.key_end),'string');
          cells.push({column:field.name,pointer:childPointer,target:'member_key',kind:'string',span_utf16:[entry.key_start,entry.key_end]});
          continue;
        }
        const base=field.scope==='parent'?parent:child,basePointer=field.scope==='parent'?parentPointer:childPointer;
        const node=resolveValue(base,field.pointer),kind=node?.type??'missing';
        values.push(node?parsed.text.slice(node.start,node.end):'',kind);
        cells.push({column:field.name,pointer:basePointer+field.pointer,kind,span_utf16:node?[node.start,node.end]:null});
      }
      outputBytes+=csvRow(values).length;if(outputBytes>LIMITS.capture)fail('observations.csv exceeds 32 KiB; reduce expansion or fields');
      const record={csv_record:rows.length+2,parent_index:parentIndex,parent_pointer:parentPointer,child_index:childIndex,child_pointer:childPointer,cells};
      if(keyed)record.child_key=entry.key;
      lineageBytes+=json(record).length;if(lineageBytes>LIMITS.capture)fail('provenance.json exceeds 32 KiB; reduce expansion or fields');
      rows.push({record_number:rows.length+2,values});lineage.push(record);
    }
  }
  const preview={contract_id:contract(plan,'preview'),
    source:{original_name:originalName,retained_file:'source.json',digest:sourceDigest,bytes:bytes.length,...structuredClone(plan.source)},
    plan:structuredClone(plan),columns,rows,lineage,parents,blockers,can_convert:blockers.length===0,
    parent_count:parents.length,candidate_count:rows.length,output_count:blockers.length?null:rows.length,
    skipped_parent_count:parents.filter(parent=>parent.action==='skip').length,
    policies:{ordering:keyed?'Parent array order, then lexical source member order (including numeric keys). child_index is the zero-based member ordinal within its own map. Repeated keys across parents remain separate. No Cartesian product, deduplication or inferred identity.':'Parent array order, then child array order. Zero-based indexes. No Cartesian product, deduplication or inferred identity.',
      values:'Every present cell is its exact original JSON token, including quotes/escapes for strings and original number spelling. Companion _kind columns distinguish missing, null and value types; missing is an empty cell.',
      lineage:'Pointers are RFC 6901 paths into the digest-bound source.json. span_utf16 is a half-open range in the decoded source, including a leading BOM if present; not byte offsets. A member_key cell uses the member value pointer as its location and its own exact key-token span; JSON Pointer cannot address a key token.',
      omissions:`Empty and missing ${container}s require explicit error or skip. Null, wrong container types, unsupported child mode, duplicate decoded keys within one object and scalar traversal refuse. All skipped parents stay inventoried.`,
      retention:'Complete original bytes, including unselected/private data, are retained. This is not redaction.',
      authority:'Access, origin, restrictions and capture time are operator-declared. Import does not validate claims or authorize actions.'},
    limitations:['Provenance sidecar is not automatically consumed by ordinary CSV intake. Keep it with source.json and observations.csv.',
      'Raw JSON cell strings are evidence text, not decoded spreadsheet data. No numeric conversion, date parsing, scoring or formula execution.',
      'No browser, native host, persistence, provider, production or autonomy qualification.']};
  if(preview.can_convert) {const files=derive(preview);preview.file_sizes=Object.entries(files).map(([name,data])=>({name,bytes:data.length}));}
  return preview;
}
export function createChildrenBundle(bytes,plan,originalName='source.json') {
  const preview=previewChildren(bytes,plan,originalName);if(!preview.can_convert)fail(preview.blockers.join('; '));
  const files={'source.json':Buffer.from(bytes),...derive(preview)};parseCsv(files['observations.csv']);
  files['manifest.json']=json({contract_id:contract(plan,'bundle'),files:Object.entries(files).map(([name,data])=>({name,bytes:data.length,digest:digest(data)})),limitations:preview.limitations});
  return {files,preview};
}
const HELP=`MoonFind local JSON child observations (Node 20+)
  node scripts/json_children.mjs inspect --json INPUT.json
  node scripts/json_children.mjs preview --json INPUT.json --plan PLAN.json
  node scripts/json_children.mjs convert --json INPUT.json --plan PLAN.json --out-dir NEW_DIRECTORY
Inspect the source digest and array/map locations; explicitly choose parents, one child container, mode, policies and fields.
Array plan: moonfind.json-children-plan.v1. Keyed child-map plan: moonfind.json-child-map-plan.v1 (parent/key/value fields).
Import observations.csv with the ordinary Import CSV table control. Keep source.json and provenance.json.
See docs/JSON_CHILD_OBSERVATIONS.md.
`;
export function main(args) {
  if(args.length===1&&['--help','-h'].includes(args[0])){process.stdout.write(HELP);return;}
  const [command,...rest]=args,allowed=command==='inspect'?['--json']:command==='preview'?['--json','--plan']:command==='convert'?['--json','--plan','--out-dir']:[];
  if(!allowed.length||rest.length!==allowed.length*2)fail(HELP);const options=new Map();
  for(let i=0;i<rest.length;i+=2){if(!allowed.includes(rest[i])||options.has(rest[i])||!rest[i+1]||rest[i+1].startsWith('--'))fail('Unknown, duplicate or missing option');options.set(rest[i],rest[i+1]);}
  const path=resolve(options.get('--json'));if(!/\.json$/i.test(path))fail('Choose a local .json file');const bytes=readBounded(path,LIMITS.source,'JSON');
  if(command==='inspect'){process.stdout.write(JSON.stringify(inspectChildren(bytes),null,2)+'\n');return;}
  const plan=parsePlan(readBounded(resolve(options.get('--plan')),LIMITS.plan,'Plan'));
  if(command==='preview')process.stdout.write(JSON.stringify(previewChildren(bytes,plan,basename(path)),null,2)+'\n');
  else {const bundle=createChildrenBundle(bytes,plan,basename(path)),directory=resolve(options.get('--out-dir'));writeBundle(directory,bundle);process.stdout.write(JSON.stringify({directory,output_count:bundle.preview.output_count,skipped_parent_count:bundle.preview.skipped_parent_count,files:Object.keys(bundle.files),installed_intake_run:false})+'\n');}
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  try{main(process.argv.slice(2));}catch(error){process.stderr.write(`JSON child observations: ${error.message}\n`);process.exitCode=1;}
}
