///|
async test "general research job shows actual output files and survives reload" {
  let workspace = @fs.tmpdir(prefix="moonfind-general-job-")
  let config : Config = {
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
  let job = create_research_job(config, {
    objective: "Compare three battery interface methods",
    audience: "materials research team",
    source_scope: ["open papers"],
    requested_outputs: [
      {
        output_id: "report.md",
        title: "Research report",
        kind: "report",
        format: "text/markdown",
        acceptance_criteria: ["Opens and answers the objective"],
      },
    ],
  })
  assert_eq(job.files.length(), 0)
  assert_eq(job.missing_outputs, ["report.md"])
  @fs.write_file(
    job.job_root + "/outputs/report.md",
    @utf8.encode("# Battery interfaces\n\nEvidence summary.\n"),
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  let refreshed = research_job_view(config, job.job.job_id)
  assert_eq(refreshed.files.length(), 1)
  assert_true(refreshed.missing_outputs.is_empty())
  assert_eq(refreshed.files[0].media_type, "text/markdown")
  let (bytes, media_type) = research_job_file(
    config,
    job.job.job_id,
    "report.md",
  )
  assert_eq(media_type, "text/markdown")
  assert_true(bytes.length() > 0)
  @fs.mkdir(job.job_root + "/evidence", permission=0o755)
  @fs.write_file(
    job.job_root + "/evidence/sources.md",
    @utf8.encode("# Sources reviewed\n\nTrial source.\n"),
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  let evidence : @research.DeliveryEvidence = {
    contract_id: "moonfind.delivery-evidence.v1",
    job_id: job.job.job_id,
    outputs: [
      {
        output_id: "report.md",
        evidence_refs: ["evidence/sources.md"],
        checks: [
          {
            criterion: "Opens and answers the objective",
            status: "passed",
            evidence_ref: "evidence/sources.md",
          },
        ],
      },
    ],
  }
  @store.write_json(
    job.job_root + "/delivery-evidence.json",
    evidence.to_json(),
  )
  let verified = verify_research_job_delivery(config, job.job.job_id)
  assert_true(verified.delivery_ready)
  assert_true(verified.delivery_manifest is Some(_))
  let delivered_archive = research_job_export(config, job.job.job_id)
  let delivered_names = @moonzip.unzip_sync(delivered_archive.to_fixedarray()).map(entry => {
      entry.0
    },
  )
  assert_true(delivered_names.contains("delivery-manifest.json"))
  assert_true(delivered_names.contains("delivery-evidence.json"))
  @fs.write_file(
    job.job_root + "/outputs/report.md",
    @utf8.encode("# Updated report\n"),
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  let stale = research_job_view(config, job.job.job_id)
  assert_false(stale.delivery_ready)
  assert_true(stale.delivery_issues.any(issue => issue.contains("changed")))
  let saved = record_research_job_session(config, job.job.job_id, {
    session_key: "cowork:test-session",
  })
  assert_eq(saved.session_key, Some("cowork:test-session"))
  assert_eq(list_research_jobs(config).length(), 1)
  @fs.rmdir(workspace, recursive=true)
}

///|
async test "sources previews export and revisions keep deliverables usable" {
  assert_eq(
    normalized_arxiv_search("retrieval augmented generation"),
    "all:\"retrieval augmented generation\"",
  )
  assert_eq(
    normalized_arxiv_search("all:retrieval augmented generation"),
    "all:\"retrieval augmented generation\"",
  )
  assert_eq(normalized_arxiv_search("cat:cs.AI"), "cat:cs.AI")
  assert_true(permitted_source_url("https://example.org/research"))
  assert_false(permitted_source_url("http://example.org/research"))
  assert_false(permitted_source_url("https://localhost/internal"))
  let workspace = @fs.tmpdir(prefix="moonfind-job-delivery-")
  let config : Config = {
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
  let job = create_research_job(config, {
    objective: "Compare two methods",
    audience: "Research team",
    source_scope: ["Supplied notes"],
    requested_outputs: [
      {
        output_id: "report.md",
        title: "Report",
        kind: "report",
        format: "text/markdown",
        acceptance_criteria: ["Has comparison"],
      },
    ],
  })
  let with_source = add_research_job_text_source(config, job.job.job_id, {
    name: "notes.md",
    content: "Method A is faster; method B is cheaper.",
  })
  assert_eq(with_source.sources.length(), 1)
  assert_true(
    with_source.agent_prompt.contains("Available source files: input/notes.md"),
  )
  let (source, _) = research_job_source_file(config, job.job.job_id, "notes.md")
  assert_true(source.length() > 0)
  @fs.write_file(
    job.job_root + "/outputs/report.md",
    @utf8.encode("# Comparison\n\nMethod A and B differ.\n"),
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  let preview = research_job_preview(config, job.job.job_id, "report.md")
  assert_true(preview.text.unwrap_or("").contains("Method A and B"))
  assert_false(preview.truncated)
  @fs.mkdir(job.job_root + "/evidence", permission=0o755)
  @fs.write_file(
    job.job_root + "/evidence/sources.md",
    @utf8.encode("# Reviewed sources\n"),
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  let archive = research_job_export(config, job.job.job_id)
  let names = @moonzip.unzip_sync(archive.to_fixedarray()).map(entry => entry.0)
  assert_true(names.contains("job.json"))
  assert_true(names.contains("input/notes.md"))
  assert_true(names.contains("outputs/report.md"))
  assert_true(names.contains("evidence/sources.md"))
  let revised = revise_research_job_file(config, job.job.job_id, {
    file_name: "report.md",
    instruction: "Explain the cost tradeoff more clearly",
  })
  assert_eq(revised.revision_of, Some(job.job.job_id))
  assert_eq(revised.sources.length(), 2)
  assert_true(revised.sources.any(file => file.name == "previous-report.md"))
  assert_eq(revised.missing_outputs, ["report.md"])
  assert_eq(research_job_view(config, job.job.job_id).files.length(), 1)
  @fs.rmdir(workspace, recursive=true)
}

///|
async test "four research job shapes use the same multi-file delivery path" {
  let workspace = @fs.tmpdir(prefix="moonfind-varied-jobs-")
  let config : Config = {
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
  let cases : Array[(String, Array[String])] = [
    ("Literature synthesis", ["report.md", "references.bib"]),
    ("Local corpus analysis", ["summary.md", "findings.csv"]),
    ("Technical comparison", ["memo.md", "matrix.csv"]),
    ("Humanoid research plan", ["experiment-plan.md", "risks.csv"]),
  ]
  for (objective, names) in cases {
    let outputs : Array[@research.RequestedOutput] = names.map(name => {
      output_id: name,
      title: name,
      kind: "artifact",
      format: job_file_media_type(name),
      acceptance_criteria: ["Contains a usable result"],
    })
    let job = create_research_job(config, {
      objective,
      audience: "researcher",
      source_scope: ["supplied source"],
      requested_outputs: outputs,
    })
    ignore(
      add_research_job_text_source(config, job.job.job_id, {
        name: "source.md",
        content: "# Supplied source\nFixture for delivery mechanics.\n",
      }),
    )
    for name in names {
      @fs.write_file(
        job.job_root + "/outputs/" + name,
        @utf8.encode("Result for " + objective + " in " + name + "\n"),
        create_mode=CreateOrTruncate,
        permission=0o644,
      )
    }
    let evidence : @research.DeliveryEvidence = {
      contract_id: "moonfind.delivery-evidence.v1",
      job_id: job.job.job_id,
      outputs: names.map(name => {
        output_id: name,
        evidence_refs: ["input/source.md", "outputs/" + name],
        checks: [
          {
            criterion: "Contains a usable result",
            status: "passed",
            evidence_ref: "outputs/" + name,
          },
        ],
      }),
    }
    @store.write_json(
      job.job_root + "/delivery-evidence.json",
      evidence.to_json(),
    )
    let verified = verify_research_job_delivery(config, job.job.job_id)
    assert_true(verified.delivery_ready)
    assert_true(verified.missing_outputs.is_empty())
    let archive = research_job_export(config, job.job.job_id)
    let archived = @moonzip.unzip_sync(archive.to_fixedarray()).map(entry => {
      entry.0
    })
    for name in names {
      assert_true(archived.contains("outputs/" + name))
    }
    assert_true(archived.contains("delivery-manifest.json"))
  }
  assert_eq(list_research_jobs(config).length(), 4)
  @fs.rmdir(workspace, recursive=true)
}
