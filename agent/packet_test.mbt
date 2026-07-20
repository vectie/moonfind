///|
fn responsibility_command() -> MoonClawResearchCommand {
  {
    protocol: "moonclaw.mooncode.v1",
    session_id: "moonfind-test",
    book_root: "/tmp/book",
    command: "prompt",
    model: "gpt-5.6-sol",
    capability_scope_id: "moonfind.humanoid.synthesis",
    capability_participant_id: "participant-1",
    text: "analyze evidence",
    packet: {
      "product_id": "moonfind",
      "required_review": "named-human",
      "owner_route": "moonfind.humanoid-models",
    },
  }
}

///|
test "research command delegates a bounded model loop without ownership transfer" {
  assert_true(
    research_command_responsibility_issues(responsibility_command()).is_empty(),
  )
  let wrong_model = { ..responsibility_command(), model: "gpt-5.4" }
  assert_false(research_command_responsibility_issues(wrong_model).is_empty())
  let self_approving = {
    ..responsibility_command(),
    packet: {
      "product_id": "moonfind",
      "required_review": "agent",
      "owner_route": "moonfind.humanoid-models",
      "capability_activation": "full",
    },
  }
  assert_false(
    research_command_responsibility_issues(self_approving).is_empty(),
  )
}
