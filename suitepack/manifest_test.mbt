///|
test "manifest declares generic local corpus accounting and MoonBook" {
  let value = manifest()
  assert_true(validation_report().ok)
  assert_true(value.required_runtime_extensions.contains("moonbook"))
  assert_true(
    value.schemas.any(fn(contract) {
      contract.id == "local-input-coverage" &&
      contract.path == "schemas/local-input-coverage.schema.json"
    }),
  )
  assert_true(
    value.tools.any(fn(tool) {
      tool.id == "research.account-local-corpus" &&
      tool.input_schema_id == "local-input-coverage" &&
      tool.output_schema_id == "local-input-coverage"
    }),
  )
  assert_true(
    value.tools.any(fn(tool) {
      tool.id == "research.challenge-local-corpus" &&
      tool.input_schema_id == "local-input-coverage" &&
      tool.output_schema_id == "moontown-research-scenario"
    }),
  )
}

///|
test "manifest declares review-gated read-only Q&A grounding" {
  let value = manifest()
  assert_true(
    value.schemas.any(fn(contract) {
      contract.id == "read-only-qa-grounding" &&
      contract.path == "schemas/read-only-qa-grounding.schema.json"
    }),
  )
  assert_true(
    value.tools.any(fn(tool) {
      tool.id == "book.prepare-read-only-qa-grounding" &&
      tool.input_schema_id == "research-run" &&
      tool.output_schema_id == "read-only-qa-grounding" &&
      tool.authority == SandboxExecution &&
      tool.review_required
    }),
  )
}

///|
test "manifest exposes a MoonDesk-hostable application route" {
  let value = manifest()
  assert_true(
    value.app_entrypoints.any(fn(entrypoint) {
      entrypoint.id == "research-studio" &&
      entrypoint.path == "/apps/moonfind/research"
    }),
  )
}
