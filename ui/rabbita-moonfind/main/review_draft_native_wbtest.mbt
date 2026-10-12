///|
extern "js" fn review_install_native_transport() -> Bool =
  #| () => {
  #|   const base = process.env.MOONFIND_REVIEW_NATIVE_URL;
  #|   if (!base) return false;
  #|   if (!/^http:\/\/127\.0\.0\.1:\d+$/.test(base)) throw new Error('localhost fixture required');
  #|   globalThis.__reviewOldFetch = globalThis.fetch; globalThis.__reviewRequests = [];
  #|   const chain = (v,e) => ({then(fn){if(e)return chain(null,e);try{return fn(v)||chain(null,null);}catch(err){return chain(null,err);}},catch(fn){if(e)fn(e);return chain(null,null);}});
  #|   globalThis.fetch = (path, options) => {
  #|     try {
  #|       const method = options?.method || 'GET';
  #|       if (method !== 'GET' || !['/api/v1/workspace','/api/v1/model-route','/api/v1/delivery'].includes(path)) throw new Error('Mutation or unexpected route forbidden');
  #|       globalThis.__reviewRequests.push({path,method});
  #|       const text = process.getBuiltinModule('child_process').execFileSync('curl',['--fail-with-body','--silent','--show-error','--max-time','10',base+path],{encoding:'utf8'});
  #|       return chain({text:()=>chain(text,null)},null);
  #|     } catch(e) { return chain(null,e); }
  #|   }; return true;
  #| }

///|
extern "js" fn review_native_requests() -> String = "() => JSON.stringify(globalThis.__reviewRequests)"

///|
extern "js" fn review_restore_native_transport() -> Unit = "() => {globalThis.fetch=globalThis.__reviewOldFetch;}"

///|
test "review draft compiled UI actual native completed result resumes without mutation" {
  if !review_install_native_transport() {
    return
  }
  defer review_restore_native_transport()
  install_choice_storage("ok")
  defer restore_choice_storage()
  let (cell, dispatch) = retained_harness(initial_model())
  ignore(dispatch(RefreshMoonTownStatus))
  assert_true(current_synthesis(cell.val) is Some(_))
  assert_eq(cell.val.review_phase, ReviewIdle)
  let context = review_result_context(cell.val)
  let output = current_synthesis(cell.val).unwrap()
  assert_eq(output.ideas[0].id, "idea-1")
  ignore(dispatch(ToggleResultIdea(context, "idea-1")))
  ignore(dispatch(SetReviewOutcome("request_changes")))
  ignore(
    dispatch(SetReviewMessage("Need matched evidence 月面 🌒\r\n<script>")),
  )
  ignore(
    dispatch(
      SetInformationGapSummary("Native fixture is not scientific validation"),
    ),
  )
  let draft = review_draft(cell.val).to_json()
  let saved = review_draft_json(cell.val)
  cell.val = initial_model()
  ignore(dispatch(RefreshMoonTownStatus))
  assert_eq(review_result_context(cell.val), context)
  assert_eq(review_draft(cell.val).to_json(), draft)
  assert_true(cell.val.review_prepare_reply is None)
  assert_true(cell.val.review_pending_context is None)
  assert_eq(cell.val.review_phase, ReviewIdle)
  assert_eq(cell.val.review_workflow.unwrap().state, "ready-for-human-review")
  let html = qa_test_render(cell.val)
  assert_true(html.contains("&lt;script&gt;"))
  assert_true(html.contains("Correlated fixture idea"))
  guard @json.parse(review_native_requests()) is Array(requests) else {
    fail("Missing requests")
  }
  assert_true(requests.all(request => request is { "method": "GET", .. }))
  println(
    "MOONFIND_REVIEW_NATIVE=" +
    (
      {
        "context": context,
        "source_digest": cell.val.moontown_result.unwrap().source_digest,
        "selected_ids": review_scope_ids(cell.val.review_scope),
        "saved_draft": saved,
        "requests": requests,
        "html": html,
        "mutation_requests": 0,
        "review_state": cell.val.review_workflow.unwrap().state,
      } : Json).stringify(),
  )
}
