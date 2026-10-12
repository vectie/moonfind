///|
fn brief_test_source(
  text : String,
  name? : String = "source.txt",
  origin? : String = "local fixture",
) -> @research.BriefSourceInputV1 {
  let hex = StringBuilder()
  for byte in @utf8.encode(text) {
    hex.write_string(byte.to_hex())
  }
  {
    name,
    origin,
    captured_at: "2026-10-07T14:00:00Z",
    kind: "local-file",
    content_hex: hex.to_string(),
  }
}

///|
fn brief_test_request() -> @research.ResearchBriefV1 {
  {
    contract_id: "moonfind.research-brief.v1",
    brief_id: "brief-test",
    parent_revision: None,
    question: "Which option deserves a trial? 月面 🌒 <script>",
    objective: "Prepare a comparison",
    audience: "Research team",
    decision: "Choose the next measurement",
    source_restrictions: "Selected captures only",
    requested_filenames: ["comparison.md", "evidence.csv"],
    acceptance_criteria: "Distinguish unknowns and disagreements",
    sources: [brief_test_source("Exact source 月面 🌒\r\nrow,2\r\n")],
  }
}

///|
async test "brief catalog capacity never makes an existing interrupted capture impossible to retry" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="find-brief-capacity"),
  )
  let request = brief_test_request()
  let revision = brief_identity(request)
  @fs.mkdir(brief_directory(config, request.brief_id, revision), recursive=true)
  for i in 1..<200 {
    @fs.mkdir(
      brief_directory(config, "capacity-\{i}", revision),
      recursive=true,
    )
  }
  assert_eq(list_briefs(config).length(), 200)
  assert_true(
    try {
      ignore(save_brief(config, { ..request, brief_id: "one-too-many", }))
      false
    } catch {
      _ => true
    },
  )
  assert_false(@fs.exists(brief_root(config) + "/one-too-many"))
  assert_eq(save_brief(config, request).state, "prepared")
  assert_eq(list_briefs(config).length(), 200)
}

///|
async test "brief one source save reopen retry complete ZIP preserves exact Unicode CRLF without run or provider" {
  let config = {
    ..model_route_config(workspace=@fs.tmpdir(prefix="find-brief-one")),
    run_id: "",
  }
  assert_eq(list_briefs(config).length(), 0)
  assert_false(@fs.exists(brief_root(config)))
  let request = brief_test_request()
  let saved = save_brief(config, request)
  assert_eq(saved.state, "prepared")
  let snapshot = saved.snapshot.unwrap()
  assert_eq(snapshot.sources.length(), 1)
  assert_eq(
    snapshot.sources[0].digest,
    @store.digest_text("Exact source 月面 🌒\r\nrow,2\r\n"),
  )
  let path = brief_directory(config, request.brief_id, saved.revision_id)
  let bytes_before = @fs.read_file(path + "/snapshot.json").binary()
  assert_eq(
    brief_status(config, request.brief_id, saved.revision_id).snapshot.unwrap(),
    snapshot,
  )
  assert_eq(save_brief(config, request).revision_id, saved.revision_id)
  assert_eq(@fs.read_file(path + "/snapshot.json").binary(), bytes_before)
  assert_eq(list_briefs(config).length(), 1)
  let report = @utf8.decode(
    export_brief(config, request.brief_id, saved.revision_id, "brief.md"),
  )
  assert_true(report.contains("Prepared brief only"))
  assert_true(
    report.contains("Acceptance criteria (user supplied, not approved)"),
  )
  let archive = @moonzip.unzip_sync(
    export_brief(config, request.brief_id, saved.revision_id, "dossier.zip").to_fixedarray(),
  )
  assert_eq(archive.length(), 4)
  assert_eq(
    Bytes::from_fixedarray(archive[2].1),
    brief_source_bytes(request.sources[0]),
  )
  assert_false(
    @fs.exists(config.workspace + "/.moonsuite/products/moonfind/runs"),
  )
}

///|
async test "brief duplicate source names and content retain distinct origins and immutable changed-source revision" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="find-brief-multiple"),
  )
  let first = brief_test_source(
    "same bytes\n",
    name="同名.csv",
    origin="team A",
  )
  let second = { ..first, origin: "team B", }
  let request = {
    ..brief_test_request(),
    sources: [
      first,
      second,
      brief_test_source("\uFEFF{\"claim\":\"unverified\"}\n", name="claim.json"),
      brief_test_source("@article{x,title={Moon}}\n", name="refs.bib"),
    ],
  }
  let original = save_brief(config, request)
  let sources = original.snapshot.unwrap().sources
  assert_eq(sources.length(), 4)
  assert_eq(sources[0].digest, sources[1].digest)
  assert_true(sources[0].archive_path != sources[1].archive_path)
  let old_zip = export_brief(
    config,
    request.brief_id,
    original.revision_id,
    "dossier.zip",
  )
  let changed = {
    ..request,
    parent_revision: Some(original.revision_id),
    sources: [brief_test_source("new bytes", name="同名.csv")],
  }
  let newer = save_brief(config, changed)
  assert_true(newer.revision_id != original.revision_id)
  assert_eq(list_briefs(config).length(), 2)
  assert_eq(
    export_brief(config, request.brief_id, original.revision_id, "dossier.zip"),
    old_zip,
  )
  assert_eq(
    brief_status(config, request.brief_id, original.revision_id).snapshot.unwrap().brief,
    request,
  )
  assert_eq(
    newer.snapshot.unwrap().brief.parent_revision,
    Some(original.revision_id),
  )
  assert_true(
    try {
      ignore(
        save_brief(config, {
          ..request,
          question: "new content under the initial ID",
        }),
      )
      false
    } catch {
      _ => true
    },
  )
}

///|
async test "brief source symlinks and dangling staging symlinks are never followed" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="find-brief-symlink"),
  )
  let request = brief_test_request()
  let snapshot = brief_snapshot(request)
  let directory = brief_directory(
    config,
    request.brief_id,
    snapshot.revision_id,
  )
  @fs.mkdir(directory + "/sources", recursive=true)
  let outside = config.workspace + "/outside.txt"
  @fs.write_file(outside, "keep me", create_mode=CreateNew)
  @fs.symlink(target=outside, directory + "/sources/source-1.txt")
  assert_true(
    try {
      ignore(save_brief(config, request))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(@fs.read_file(outside).text(), "keep me")
  @fs.remove(directory + "/sources/source-1.txt")
  let absent = config.workspace + "/must-not-create.txt"
  @fs.symlink(target=absent, directory + "/sources/source-1.txt.pending")
  assert_true(
    try {
      ignore(save_brief(config, request))
      false
    } catch {
      _ => true
    },
  )
  assert_false(@fs.exists(absent))
}

///|
async test "brief unsupported binary PDF invalid UTF8 incomplete oversized and traversal requests fail before storage" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="find-brief-invalid"),
  )
  let request = brief_test_request()
  for
    invalid in [
      { ..request, question: "", },
      { ..request, sources: [], },
      { ..request, sources: [brief_test_source("%PDF-1.0", name="paper.pdf")], },
      { ..request, sources: [{ ..request.sources[0], content_hex: "00", }], },
      { ..request, sources: [{ ..request.sources[0], content_hex: "ff", }], },
      { ..request, sources: [{ ..request.sources[0], content_hex: "A0", }], },
      { ..request, sources: [{ ..request.sources[0], content_hex: "0", }], },
      { ..request, sources: [brief_test_source(String::make(32769, 'a'))], },
      { ..request, sources: Array::make(9, request.sources[0]), },
      { ..request, brief_id: "../outside", },
      { ..request, requested_filenames: ["../outside.txt"], },
      { ..request, requested_filenames: ["report.md", "REPORT.md"], },
      { ..request, sources: [brief_test_source("x", name="../source.txt")], },
    ] {
    assert_true(
      try {
        ignore(save_brief(config, invalid))
        false
      } catch {
        _ => true
      },
    )
    assert_false(@fs.exists(brief_root(config)))
  }
}

///|
async test "brief missing or changed committed bytes block complete export and are never repaired by retry" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="find-brief-corrupt"),
  )
  let request = brief_test_request()
  let saved = save_brief(config, request)
  let directory = brief_directory(config, request.brief_id, saved.revision_id)
  let source = directory + "/" + saved.snapshot.unwrap().sources[0].archive_path
  @fs.write_file(source, "changed", create_mode=CreateOrTruncate)
  assert_eq(
    brief_status(config, request.brief_id, saved.revision_id).state,
    "incomplete",
  )
  assert_eq(save_brief(config, request).state, "incomplete")
  assert_eq(@fs.read_file(source).text(), "changed")
  assert_true(
    try {
      ignore(
        export_brief(config, request.brief_id, saved.revision_id, "dossier.zip"),
      )
      false
    } catch {
      _ => true
    },
  )
  @fs.remove(source)
  assert_eq(
    brief_status(config, request.brief_id, saved.revision_id).state,
    "incomplete",
  )
  assert_eq(list_briefs(config)[0].state, "incomplete")
  assert_true(
    try {
      ignore(
        save_brief(config, {
          ..request,
          parent_revision: Some(saved.revision_id),
          objective: "revised",
        }),
      )
      false
    } catch {
      _ => true
    },
  )
}

///|
async test "brief interrupted staging retry is idempotent while conflicting immutable bytes are preserved" {
  let config = model_route_config(
    workspace=@fs.tmpdir(prefix="find-brief-interrupted"),
  )
  let request = brief_test_request()
  let snapshot = brief_snapshot(request)
  let directory = brief_directory(
    config,
    request.brief_id,
    snapshot.revision_id,
  )
  @fs.mkdir(directory + "/sources", recursive=true)
  @fs.write_file(
    directory + "/sources/source-1.txt.pending",
    "partial bytes",
    create_mode=CreateNew,
  )
  @fs.write_file(
    directory + "/snapshot.json.pending",
    "{",
    create_mode=CreateNew,
  )
  assert_eq(list_briefs(config)[0].state, "incomplete")
  let recovered = save_brief(config, request)
  assert_eq(recovered.state, "prepared")
  assert_eq(recovered.revision_id, snapshot.revision_id)
  assert_eq(save_brief(config, request).revision_id, snapshot.revision_id)
  let other = { ..request, brief_id: "brief-collision", }
  let other_dir = brief_directory(config, other.brief_id, brief_identity(other))
  @fs.mkdir(other_dir + "/sources", recursive=true)
  @fs.write_file(
    other_dir + "/sources/source-1.txt",
    "conflicting bytes",
    create_mode=CreateNew,
  )
  assert_true(
    try {
      ignore(save_brief(config, other))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(
    @fs.read_file(other_dir + "/sources/source-1.txt").text(),
    "conflicting bytes",
  )
  assert_false(@fs.exists(other_dir + "/snapshot.json"))
}
