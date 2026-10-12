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
    display_name: "Moonfind Research Jobs",
    product_id: "moonfind",
    kind: DomainPack,
    required_runtime_extensions: ["moonclaw"],
    book_templates: [
      @pack.contract_ref(
        "moonfind-research-book", "1.0.0", "book/research-book.md",
      ),
    ],
    schemas: [
      schema("research-job"),
      schema("delivery-manifest"),
      schema("delivery-evidence"),
      schema("research-watch"),
      schema("local-input-coverage"),
      schema("paper-record"),
      schema("full-text-evidence"),
      schema("provider-use-decision"),
      schema("recovery-snapshot"),
      schema("research-run"),
      schema("moonclaw-research-command"),
      schema("research-execution-record"),
      schema("capability-graph-projection"),
      schema("research-analysis-result"),
      schema("human-research-review"),
      schema("cross-product-review-decision"),
      schema("moontown-research-scenario"),
      schema("bookkeeper-deliverable-candidate"),
      schema("capability-observation"),
      schema("read-only-qa-grounding"),
      schema("ui-workspace"),
      schema("series-use-case"),
      schema("public-listing-projection"),
      schema("public-listing-search-request"),
      schema("public-listing-search-response"),
      schema("pack-town-projection"),
      schema("town-pack-candidate"),
      schema("pack-candidate-acknowledgement"),
    ],
    tools: [
      tool("papers.acquire-arxiv", "research-watch", "paper-record", Observe, [
        "raw/arxiv", "records/papers",
      ]),
      tool(
        "research.account-local-corpus",
        "local-input-coverage",
        "local-input-coverage",
        WorkspaceMutation,
        ["raw/imports", "raw/extracted", "records/local-input-coverage"],
      ),
      tool(
        "papers.record-isolated-fulltext",
        "full-text-evidence",
        "full-text-evidence",
        SandboxExecution,
        [
          "raw/quarantine", "records/fulltext-evidence", "records/isolation-receipts",
        ],
      ),
      tool(
        "research.prepare-analysis",
        "research-run",
        "moonclaw-research-command",
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
        "research.challenge-local-corpus",
        "local-input-coverage",
        "moontown-research-scenario",
        SandboxExecution,
        ["records/moontown-scenarios", "records/local-corpus-challenges"],
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
        "book.prepare-read-only-qa-grounding",
        "research-run",
        "read-only-qa-grounding",
        SandboxExecution,
        ["records/qa-grounding"],
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
      tool(
        "research.candidate.intake",
        "town-pack-candidate",
        "research-watch",
        WorkspaceMutation,
        ["records/research-candidate-intake"],
        review_required=true,
      ),
    ],
    workflows: [
      @pack.contract_ref(
        "humanoid-research", "2.0.0", "workflows/humanoid-research.v1.json",
      ),
      @pack.contract_ref(
        "humanoid-robotics-suite-desired", "3.0.0", "workflows/humanoid-robotics-suite.v1.json",
      ),
      @pack.contract_ref(
        "lunar-habitat-decision-series-source", "1.0.0", "workflows/lunar-habitat-decision-series-source.v1.json",
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
      @pack.contract_ref(
        "crossref-policy", "1.0.0", "providers/crossref-policy.json",
      ),
      @pack.contract_ref(
        "openalex-policy", "1.0.0", "providers/openalex-policy.json",
      ),
      @pack.contract_ref(
        "semantic-scholar-policy", "1.0.0", "providers/semantic-scholar-policy.json",
      ),
      @pack.contract_ref(
        "licensed-fulltext-policy", "1.0.0", "providers/licensed-fulltext-policy.json",
      ),
      @pack.contract_ref(
        "moonflow-adapter-declaration", "1.0.0", "adapters/moonflow/adapter-declaration.v1.json",
      ),
      @pack.contract_ref(
        "moonflow-adapter-health-template", "1.0.0", "adapters/moonflow/adapter-health.template.v1.json",
      ),
      @pack.contract_ref(
        "public-listing-ranking", "1.0.0", "providers/public-listing-ranking.port.json",
      ),
      @pack.contract_ref(
        "moontown-pack-projection", "1.0.0", "providers/moontown-pack-projection.port.md",
      ),
    ],
    schedules: [
      @pack.schedule_declaration(
        "humanoid-daily-watch", "0 8 * * *", "Asia/Shanghai", "humanoid-research",
      ),
    ],
    app_entrypoints: [
      @pack.app_entrypoint("research-jobs", "/apps/moonfind/jobs", "researcher"),
      @pack.app_entrypoint(
        "research-studio", "/apps/moonfind/research", "research-operator",
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
