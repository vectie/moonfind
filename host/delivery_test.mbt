///|
async test "public delivery API reads an empty workspace without creating files" {
  let workspace = @fs.tmpdir(prefix="find-delivery-public")
  let config : @host.Config = {
    workspace,
    run_id: "run-public",
    book_workspace: workspace,
    public_base_url: "http://127.0.0.1:4313",
    capability_catalog_path: None,
    moonclaw_gateway_base: None,
    moonclaw_gateway_token: None,
    moonclaw_submit_url: None,
    moonclaw_reconcile_url: None,
    moontown_base_url: None,
  }
  let status = @host.delivery_status(config)
  assert_eq(status.contract_id, "moonfind.delivery-status.v1")
  assert_eq(status.state, "not-prepared")
  assert_true(status.manifest is None)
  assert_true(status.versions.is_empty())
  assert_false(@fs.exists(workspace + "/.moonsuite"))
  assert_true(
    try {
      ignore(@host.read_delivery_file(config, "../escape", "report.md"))
      false
    } catch {
      _ => true
    },
  )
  assert_false(@fs.exists(workspace + "/.moonsuite"))
}
