///|
// Minimal controlled DOM for Rabbita mount/diff and actual event handlers.
// This does not emulate layout, a browser engine, file picking or native I/O.
extern "js" fn screening_dom_install() -> Unit =
  #|() => {
  #| const names=['document','window','HTMLElement','HTMLInputElement','HTMLSelectElement','SVGElement','MouseEvent','InputEvent'];
  #| globalThis.__screenDomSaved=names.map(n=>[n,Object.getOwnPropertyDescriptor(globalThis,n)]);
  #| class Node {
  #|  constructor(tag='',type=1,text=''){this.tagName=tag.toUpperCase();this.nodeType=type;this.nodeValue=text;this.childNodes=[];this.parentNode=null;this.attrs={};this.handlers={};this.value='';this.style={setProperty(){},removeProperty(){}};}
  #|  get textContent(){return this.nodeType===8?'':this.nodeType===3?this.nodeValue:this.childNodes.map(n=>n.textContent).join('');}
  #|  set textContent(s){this.childNodes=[];if(s)this.appendChild(new Node('',3,s));}
  #|  get nextSibling(){if(!this.parentNode)return null;return this.parentNode.childNodes[this.parentNode.childNodes.indexOf(this)+1]||null;}
  #|  get previousSibling(){if(!this.parentNode)return null;return this.parentNode.childNodes[this.parentNode.childNodes.indexOf(this)-1]||null;}
  #|  get firstChild(){return this.childNodes[0]||null;}
  #|  set innerHTML(s){this.childNodes=[];if(s)this.appendChild(new Node('div'));}
  #|  insertBefore(n,before){if(n.nodeType===11){for(const x of [...n.childNodes])this.insertBefore(x,before);return n;}if(n.parentNode)n.parentNode.removeChild(n);let i=before?this.childNodes.indexOf(before):this.childNodes.length;if(i<0)throw Error('Missing insertion anchor');this.childNodes.splice(i,0,n);n.parentNode=this;return n;}
  #|  appendChild(n){return this.insertBefore(n,null);}
  #|  removeChild(n){const i=this.childNodes.indexOf(n);if(i<0)throw Error('Missing removal node');this.childNodes.splice(i,1);n.parentNode=null;return n;}
  #|  remove(){if(this.parentNode)this.parentNode.removeChild(this);}
  #|  isSameNode(n){return this===n;}
  #|  setAttribute(k,v){this.attrs[k]=v;if(k==='id')this.id=v;}
  #|  removeAttribute(k){delete this.attrs[k];}
  #|  getAttribute(k){return this.attrs[k]??null;}
  #|  addEventListener(type,fn){(this.handlers[type]??=[]).push(fn);}
  #|  removeEventListener(type,fn){this.handlers[type]=(this.handlers[type]||[]).filter(x=>x!==fn);}
  #| }
  #| class Event {constructor(target){this.target=target;this.currentTarget=target;} preventDefault(){} stopPropagation(){}}
  #| const root=new Node('div');root.id='screening-test-root';
  #| const all=()=>{const a=[];const walk=n=>{a.push(n);n.childNodes.forEach(walk)};walk(root);return a};
  #| globalThis.__screenDom={root,all,frames:[],events:[]};
  #| for(const name of ['HTMLElement','HTMLInputElement','HTMLSelectElement','SVGElement'])Object.defineProperty(globalThis,name,{configurable:true,value:Node});
  #| for(const name of ['MouseEvent','InputEvent'])Object.defineProperty(globalThis,name,{configurable:true,value:Event});
  #| Object.defineProperty(globalThis,'document',{configurable:true,value:{getElementById:id=>all().find(n=>n.id===id)||null,querySelector:()=>null,createElement:tag=>new Node(tag),createElementNS:(_,tag)=>new Node(tag),createTextNode:s=>new Node('',3,s),createComment:s=>new Node('',8,s),createDocumentFragment:()=>new Node('',11),body:root}});
  #| Object.defineProperty(globalThis,'window',{configurable:true,value:{requestAnimationFrame:fn=>{globalThis.__screenDom.frames.push(fn);return 1;},location:{href:'http://fixture.invalid/apps/moonfind/briefs'}}});
  #|}

///|
extern "js" fn screening_dom_flush() -> Unit =
  #|() => {const d=globalThis.__screenDom;for(let i=0;d.frames.length;i++){if(i>100)throw Error('Render did not settle');d.frames.shift()(0);}}

///|
extern "js" fn screening_dom_event(
  tag : String,
  text : String,
  index : Int,
  kind : String,
  value : String,
) -> Unit =
  #|(tag,text,index,kind,value) => {
  #| const d=globalThis.__screenDom;const nodes=d.all().filter(n=>n.tagName===tag.toUpperCase()&&(!text||n.textContent===text||n.attrs['aria-label']===text));
  #| const node=nodes[index];if(!node)throw Error('Missing mounted '+tag+' '+text+' #'+index);
  #| node.value=value;const callbacks=node.handlers[kind];if(!callbacks?.length)throw Error('Missing '+kind+' handler');
  #| d.events.push({tag,text,index,kind,value});for(const callback of callbacks)callback(new globalThis.MouseEvent(node));
  #|}

///|
extern "js" fn screening_dom_text() -> String =
  #|() => globalThis.__screenDom.root.textContent

///|
extern "js" fn screening_dom_events() -> String =
  #|() => JSON.stringify(globalThis.__screenDom.events,null,2)

///|
extern "js" fn screening_dom_restore() -> Unit =
  #|() => {for(const [n,d] of globalThis.__screenDomSaved){if(d)Object.defineProperty(globalThis,n,d);else delete globalThis[n];}delete globalThis.__screenDom;delete globalThis.__screenDomSaved;}

///|
test "screening mounted DOM handlers screen revise save New reopen and reimport without retargeting" {
  install_choice_storage("ok")
  defer restore_choice_storage()
  let base = reading_fixture()
  screening_dom_install()
  defer screening_dom_restore()
  let observed = Ref(base)
  let retained = Ref(base.draft)
  let cell = @rabbita.cell(
    model=base,
    update=(emit, message, view) => {
      guard message is BriefAction(action) else { return (@rabbita.none, view) }
      let (_, reduced) = update_brief_view(emit, action, view)
      // Controlled successful host responses exercise production Save/Open/Loaded
      // handlers. No HTTP command is executed and native retention is not claimed.
      let next = match action {
        Save => {
          retained.val = view.draft
          let opened = update_brief_view(
              emit,
              Loaded(
                reduced.generation,
                view.draft.brief_id,
                "",
                Ok(notes_payload(view.draft)),
              ),
              reduced,
            ).1
          {
            ..opened,
            catalog: [
              {
                brief_id: view.draft.brief_id,
                revision_id: "notes-revision",
                question: view.draft.question,
                state: "prepared",
              },
            ],
          }
        }
        Open(id, revision) =>
          update_brief_view(
            emit,
            Loaded(
              reduced.generation,
              id,
              revision,
              Ok(notes_payload(retained.val)),
            ),
            reduced,
          ).1
        // Explicit fixture button appends the exact existing selection capture
        // at a new source slot, like a second local selection import.
        Refresh =>
          sync_screening(
            brief_edited(reduced, {
              ..reduced.draft,
              sources: reduced.draft.sources + [base.draft.sources[1]],
            }),
          )
        _ => reduced
      }
      observed.val = next
      (@rabbita.none, next)
    },
    view=(emit, view) => {
      div([
        screening_panel(emit, view),
        action_button("Save prepared brief", emit(BriefAction(Save))),
        action_button("New blank brief", emit(BriefAction(New))),
        action_button(
          "Reopen saved fixture",
          emit(BriefAction(Open(base.draft.brief_id, "notes-revision"))),
        ),
        action_button("Append selection fixture", emit(BriefAction(Refresh))),
      ])
    },
  )
  @rabbita.new(cell).mount("screening-test-root")
  screening_dom_flush()
  screening_dom_event("button", "Screen citation", 0, "click", "")
  screening_dom_flush()
  screening_dom_event("select", "", 1, "change", "include")
  screening_dom_flush()
  screening_dom_event(
    "textarea", "Screening rationale", 0, "input", "Mounted handler rationale 🌒",
  )
  screening_dom_flush()
  screening_dom_event("button", "Save and next unscreened", 0, "click", "")
  screening_dom_flush()
  assert_eq(observed.val.screening.log.decisions.length(), 1)
  assert_eq(observed.val.screening.editor.unwrap().reference.record_number, 2)
  assert_true(screening_dom_text().contains("include: 1"))
  screening_dom_event("select", "", 1, "change", "exclude")
  screening_dom_flush()
  screening_dom_event(
    "textarea", "Screening rationale", 0, "input", "Independent same-DOI exclusion",
  )
  screening_dom_flush()
  screening_dom_event("button", "Save decision", 0, "click", "")
  screening_dom_flush()
  screening_dom_event("button", "Save prepared brief", 0, "click", "")
  screening_dom_flush()
  let decisions = observed.val.screening.log.decisions
  assert_eq(decisions.length(), 2)
  assert_true(observed.val.opened is Some(_))
  screening_dom_event("button", "New blank brief", 0, "click", "")
  screening_dom_flush()
  assert_true(observed.val.screening.log.decisions.is_empty())
  screening_dom_event("button", "Reopen saved fixture", 0, "click", "")
  screening_dom_flush()
  assert_eq(observed.val.screening.log.decisions, decisions)
  assert_true(screening_dom_text().contains("include: 1"))
  screening_dom_event("button", "Append selection fixture", 0, "click", "")
  screening_dom_flush()
  assert_eq(reference_catalog(observed.val).references.length(), 13)
  assert_eq(
    screening_status(
      observed.val,
      reference_catalog(observed.val).references[9],
    ),
    "unscreened",
  )
  assert_eq(observed.val.screening.log.decisions, decisions)
  screening_dom_event("select", "", 0, "change", "exclude")
  screening_dom_flush()
  assert_eq(screening_matches(observed.val).length(), 1)
  reading_evidence("screening-mounted-events.json", screening_dom_events())
  reading_evidence("screening-mounted-text.txt", screening_dom_text())
  reading_evidence(
    "screening-mounted-history.json",
    screening_json(observed.val),
  )
}
