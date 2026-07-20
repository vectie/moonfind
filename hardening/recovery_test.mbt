///|
test "recovery derives one next action without inventing completion" {
  let empty = recovery_snapshot(
    "run-1", "awaiting-agent-analysis", false, false, false, false, false, false,
    false, 10L,
  )
  assert_eq(empty.next_action, "acquire-and-isolate-full-text")
  assert_false(empty.terminal)
  let analyzed = recovery_snapshot(
    "run-1", "human-review", true, true, true, false, false, false, false, 20L,
  )
  assert_eq(analyzed.next_action, "build-moontown-handoff")
  let accepted_without_handoff = recovery_snapshot(
    "run-1", "accepted", true, true, true, true, true, true, false, 30L,
  )
  assert_eq(accepted_without_handoff.next_action, "rebuild-bookkeeper-handoff")
  assert_false(accepted_without_handoff.terminal)
  let complete = recovery_snapshot(
    "run-1", "accepted", true, true, true, true, true, true, true, 40L,
  )
  assert_eq(complete.next_action, "complete")
  assert_true(complete.terminal)
}
