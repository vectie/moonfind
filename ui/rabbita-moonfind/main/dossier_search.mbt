///|
struct DossierHit {
  slot : Int
  name : String
  line : Int
  context : String
} derive(Debug, Eq, ToJson, FromJson)

///|
struct DossierResults {
  hits : Array[DossierHit]
  matching_lines : Int
  omitted : Int
  skipped_slots : Array[Int]
  issue : String
} derive(Debug, Eq, ToJson, FromJson)

///|
// Deliberately literal, not a regular expression. ASCII folding preserves offsets.
extern "js" fn dossier_search_json(
  sources : String,
  query : String,
  fold : Bool,
) -> String =
  #|(sources, query, fold) => {
  #| const out = {hits:[],matching_lines:0,omitted:0,skipped_slots:[],issue:''};
  #| if (!query.length) return JSON.stringify(out);
  #| if (query.length > 256 || /[\r\n]/.test(query)) {out.issue='Use a single-line literal of at most 256 UTF-16 units.'; return JSON.stringify(out);}
  #| const normalize = s => fold ? s.replace(/[A-Z]/g, c => c.toLowerCase()) : s;
  #| const needle = normalize(query);
  #| const inputs = JSON.parse(sources);
  #| if (inputs.length > 8) {out.issue='At most 8 loaded captures can be searched.'; return JSON.stringify(out);}
  #| inputs.forEach((source, index) => {
  #|   let text;
  #|   try {
  #|     if (source.content_hex.length > 65536 || !/^(?:[0-9a-fA-F]{2})*$/.test(source.content_hex)) throw new Error('invalid capture');
  #|     text = new TextDecoder('utf-8',{fatal:true,ignoreBOM:true}).decode(Uint8Array.from(source.content_hex.match(/../g)||[], x => parseInt(x,16)));
  #|   } catch (_) {out.skipped_slots.push(index+1); return;}
  #|   text.split(/\r\n|\r|\n/).forEach((line, lineIndex) => {
  #|     const at = normalize(line).indexOf(needle); if (at < 0) return;
  #|     out.matching_lines++;
  #|     if (out.hits.length >= 200) {out.omitted++; return;}
  #|     const chars = Array.from(line), before = Array.from(line.slice(0,at)).length;
  #|     const start = Math.max(0,before-60), end = Math.min(chars.length,start+240);
  #|     const context = (start ? '…' : '') + chars.slice(start,end).join('') + (end < chars.length ? '…' : '');
  #|     out.hits.push({slot:index+1,name:source.name,line:lineIndex+1,context});
  #|   });
  #| });
  #| return JSON.stringify(out);
  #|}

///|
fn dossier_search(view : BriefView) -> DossierResults {
  @json.from_json(
    @json.parse(
      dossier_search_json(
        view.draft.sources.to_json().stringify(),
        view.search_query,
        view.search_fold,
      ),
    ),
  ) catch {
    _ =>
      {
        hits: [],
        matching_lines: 0,
        omitted: 0,
        skipped_slots: [],
        issue: "Loaded captures could not be searched.",
      }
  }
}

///|
extern "js" fn dossier_capture_section(
  text : String,
  line : Int,
  before : Bool,
) -> String =
  #|(text,line,before) => {const lines=text.split(/\r\n|\r|\n/); return (before ? lines.slice(0,line-1) : lines.slice(line-1)).join('\n');}

///|
fn dossier_export(view : BriefView) -> String raise {
  guard !view.pending &&
    view.opened is Some(status) &&
    status.state == "prepared" &&
    status.snapshot is Some(snapshot) &&
    snapshot.brief == view.draft &&
    status.brief_id == view.draft.brief_id &&
    snapshot.state == "prepared" &&
    snapshot.contract_id == "moonfind.brief-snapshot.v1" &&
    snapshot.revision_id == status.revision_id &&
    snapshot.sources.length() == view.draft.sources.length() else {
    fail(
      "Save or reopen a complete unchanged revision before exporting search results.",
    )
  }
  for index, source in snapshot.sources {
    guard source.slot == index + 1 &&
      source.name == view.draft.sources[index].name &&
      source.origin == view.draft.sources[index].origin &&
      source.captured_at == view.draft.sources[index].captured_at &&
      source.kind == view.draft.sources[index].kind &&
      source.byte_count * 2 == view.draft.sources[index].content_hex.length() &&
      source.digest.has_prefix("sha256:") else {
      fail("Saved source identity is incomplete; reopen the retained revision.")
    }
  }
  let results = dossier_search(view)
  guard !view.search_query.is_empty() &&
    results.issue.is_empty() &&
    results.skipped_slots.is_empty() else {
    fail("Enter a valid query and resolve unreadable captures before export.")
  }
  (
    {
      "contract_id": "moonfind.dossier-reading-search.v1",
      "brief_id": status.brief_id,
      "revision_id": status.revision_id,
      "sources": snapshot.sources.to_json(),
      "query": view.search_query,
      "ascii_case_fold": view.search_fold,
      "semantics": "Literal substring; one hit per matching line; CRLF, LF and CR delimit lines; no Unicode normalization or Unicode case folding. Source/line order. First 200 hits; context at most 240 Unicode code points plus ellipses.",
      "results": results.to_json(),
      "boundary": "Local reading aid only. Digests identify host-retained source bytes; matches do not establish truth, relevance, research completion or approval. Sources are not refreshed.",
    } : Json).stringify(indent=2)
}

///|
extern "js" fn dossier_download(content : String) -> String =
  #|content => {
  #| let url;
  #| try {
  #|   url = URL.createObjectURL(new Blob([content], {type:'application/json;charset=utf-8'}));
  #|   const link = document.createElement('a'); link.href=url; link.download='moonfind-dossier-search.json';
  #|   document.body.appendChild(link); link.click(); link.remove(); return '';
  #| } catch (_) {return 'Search download failed; results remain available. Try again.';}
  #| finally {if(url) setTimeout(() => URL.revokeObjectURL(url),1000);}
  #|}

///|
fn dossier_panel(emit : @rabbita.Emit[Msg], view : BriefView) -> @rabbita.Html {
  let results = dossier_search(view)
  div(id="dossier-search", [
    h3("Search loaded source dossier"),
    p(
      "Literal single-line search. Case-sensitive by default; optional ASCII-only case folding. Unicode is exact, without normalization. CRLF, LF and CR each delimit one line. One hit per matching line, in source order; first 200 shown. Context is clipped to 240 Unicode code points. No sources are fetched or refreshed.",
    ),
    field_label(
      "Search captured text",
      text_field(
        view.search_query,
        "Literal text",
        emit.map(value => BriefAction(SearchQuery(value))),
      ),
    ),
    action_button(
      if view.search_fold {
        "ASCII case folding: on"
      } else {
        "ASCII case folding: off"
      },
      emit(BriefAction(SearchFold)),
    ),
    p(
      "\{results.matching_lines} matching lines · \{results.omitted} omitted · skipped unreadable slots: " +
      results.skipped_slots.map(slot => slot.to_string()).join(", "),
    ),
    p(results.issue),
    ul(
      results.hits.map(hit => {
        li([
          action_button(
            "Open source \{hit.slot}: " + hit.name + " · line \{hit.line}",
            emit(BriefAction(SearchOpen(hit.slot, hit.line))),
          ),
          pre(
            style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
            hit.context,
          ),
        ])
      }),
    ),
    match view.search_open {
      Some((slot, line)) if slot > 0 && slot <= view.draft.sources.length() => {
        let source = view.draft.sources[slot - 1]
        div(id="dossier-open-capture", [
          h3("Source \{slot}: " + source.name + " · opened at line \{line}"),
          p(
            "Capture from the selected line onward. Earlier lines can be expanded below. Display line endings are normalized; retained bytes are unchanged.",
          ),
          pre(
            style=[
              "white-space:pre-wrap", "overflow-wrap:anywhere", "max-height:320px",
              "overflow:auto",
            ],
            dossier_capture_section(
              brief_source_preview(source.content_hex),
              line,
              false,
            ),
          ),
          details([
            summary("Earlier capture lines"),
            pre(
              style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
              dossier_capture_section(
                brief_source_preview(source.content_hex),
                line,
                true,
              ),
            ),
          ]),
        ])
      }
      _ => div("")
    },
    if view.opened.map(status => status.state == "prepared").unwrap_or(false) &&
      !view.pending {
      action_button(
        "Download search reading artifact",
        emit(BriefAction(SearchExport)),
      )
    } else {
      p(
        "Save or reopen a complete unchanged revision to export digest-bound search results.",
      )
    },
  ])
}
