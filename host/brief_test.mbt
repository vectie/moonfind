///|
async test "public brief catalog is read-only and malformed IDs cannot escape workspace" {
  let workspace = @fs.tmpdir(prefix="find-brief-public")
  let config : @host.Config = {
    workspace,
    run_id: "",
    book_workspace: workspace,
    public_base_url: "http://127.0.0.1:4313",
    capability_catalog_path: None,
    moonclaw_gateway_base: None,
    moonclaw_gateway_token: None,
    moonclaw_submit_url: None,
    moonclaw_reconcile_url: None,
    moontown_base_url: None,
  }
  assert_eq(@host.list_briefs(config).length(), 0)
  assert_eq(
    @host.brief_status(config, "../outside", "invalid").state,
    "incomplete",
  )
  assert_false(@fs.exists(workspace + "/.moonsuite"))
}
