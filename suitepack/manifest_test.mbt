///|
test "manifest declares generic local corpus accounting and MoonBook" {
  let value = manifest()
  assert_true(validation_report().ok)
  assert_true(value.required_runtime_extensions.contains("moonbook"))
  assert_true(
    value.provider_ports.any(port => port.id == "moontown-pack-projection"),
  )
  assert_true(
    value.schemas.any(schema => schema.id == "pack-candidate-acknowledgement"),
  )
  assert_true(
    value.tools.any(tool => {
      tool.id == "research.candidate.intake" &&
      tool.input_schema_id == "town-pack-candidate" &&
      tool.output_schema_id == "research-watch" &&
      tool.authority == WorkspaceMutation &&
      tool.review_required
    }),
  )
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
    value.schemas.any(fn(contract) {
      contract.id == "ui-workspace" &&
      contract.path == "schemas/ui-workspace.schema.json"
    }),
  )
  assert_true(
    value.schemas.any(fn(contract) {
      contract.id == "series-use-case" &&
      contract.path == "schemas/series-use-case.schema.json"
    }),
  )
  assert_true(
    value.app_entrypoints.any(fn(entrypoint) {
      entrypoint.id == "research-studio" &&
      entrypoint.path == "/apps/moonfind/research"
    }),
  )
}
