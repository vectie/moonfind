///|
fn schema(id : String) -> @pack.ContractRef {
  @pack.contract_ref(id, "1.0.0", "schemas/" + id + ".schema.json")
}

///|
fn tool(
  id : String,
  input : String,
  output : String,
  authority : @pack.AuthorityClass,
  evidence : Array[String],
  review_required? : Bool = false,
) -> @pack.ToolDeclaration {
  @pack.tool_declaration(
    id,
    "moonfind",
    input,
    output,
    authority,
    idempotent=true,
    evidence_outputs=evidence,
    review_required~,
  )
}

///|
pub fn manifest() -> @pack.MoonPackManifest {
  {
    id: "moonfind",
    version: "0.1.0",
    display_name: "Moonfind Evidence-Backed AutoResearch",
    product_id: "moonfind",
    kind: DomainPack,
    required_runtime_extensions: ["moonclaw", "moontown"],
    book_templates: [
      @pack.contract_ref(
        "moonfind-research-book", "1.0.0", "book/research-book.md",
      ),
    ],
    schemas: [
      schema("research-watch"),
      schema("paper-record"),
      schema("research-run"),
      schema("research-analysis-result"),
      schema("human-research-review"),
      schema("moontown-research-scenario"),
      schema("bookkeeper-deliverable-candidate"),
      schema("capability-observation"),
    ],
    tools: [
      tool("papers.acquire-arxiv", "research-watch", "paper-record", Observe, [
        "raw/arxiv", "records/papers",
      ]),
      tool(
        "research.prepare-analysis",
        "research-run",
        "research-run",
        SandboxExecution,
        ["records/moonclaw-commands"],
      ),
      tool(
        "research.cross-paper-synthesize",
        "research-run",
        "moontown-research-scenario",
        SandboxExecution,
        ["records/moontown-scenarios", "records/model-ideas"],
      ),
      tool(
        "research.review",
        "human-research-review",
        "research-run",
        WorkspaceMutation,
        ["records/human-reviews", "records/accepted-outcomes"],
        review_required=true,
      ),
      tool(
        "bookkeeper.deliverable-handoff",
        "research-run",
        "bookkeeper-deliverable-candidate",
        WorkspaceMutation,
        ["records/bookkeeper-deliverables", "records/three-gap-candidates"],
        review_required=true,
      ),
      tool(
        "moonflow.capability-observe",
        "research-run",
        "capability-observation",
        SandboxExecution,
        ["records/capability-observations"],
        review_required=true,
      ),
    ],
    workflows: [
      @pack.contract_ref(
        "humanoid-research", "1.0.0", "workflows/humanoid-research.v1.json",
      ),
    ],
    skills: [
      @pack.contract_ref(
        "humanoid-cross-paper-synthesis", "1.0.0", "skills/humanoid-cross-paper-synthesis.md",
      ),
    ],
    policies: [
      @pack.contract_ref(
        "humanoid-model-research", "1.0.0", "policies/humanoid-model-research.v1.md",
      ),
    ],
    provider_ports: [
      @pack.contract_ref(
        "arxiv-paper-metadata", "1.0.0", "providers/arxiv-development.json",
      ),
    ],
    schedules: [
      @pack.schedule_declaration(
        "humanoid-daily-watch", "0 8 * * *", "Asia/Shanghai", "humanoid-research",
      ),
    ],
    app_entrypoints: [
      @pack.app_entrypoint(
        "research-studio", "ui/rabbita-moonfind", "research-operator",
      ),
    ],
    migrations: [],
    evaluations: [],
    uninstall_contract: Some(
      @pack.contract_ref("uninstall", "1.0.0", "UNINSTALL.md"),
    ),
  }
}

///|
pub fn validation_report() -> @pack.ValidationReport {
  @pack.validate_manifest(manifest())
}
