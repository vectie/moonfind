///|
fn brief_readable(snapshot : BriefSnapshotV1) -> String {
  let brief = snapshot.brief
  let out = StringBuilder()
  out.write_string("# Prepared research brief\n\n" + snapshot.boundary + "\n\n")
  out.write_string(
    "Brief: " +
    brief.brief_id +
    "\nRevision: " +
    snapshot.revision_id +
    "\nParent: " +
    brief.parent_revision.unwrap_or("None (initial capture)") +
    "\n\n",
  )
  for
    (name, value) in [
      ("Question", brief.question),
      ("Objective", brief.objective),
      ("Audience", brief.audience),
      ("Decision to inform", brief.decision),
      ("Source restrictions", brief.source_restrictions),
      (
        "Requested filenames (not produced)",
        brief.requested_filenames.join("\n"),
      ),
      (
        "Acceptance criteria (user supplied, not approved)",
        brief.acceptance_criteria,
      ),
    ] {
    out.write_string("## " + name + "\n\n" + value + "\n\n")
  }
  out.write_string(
    "## Retained source dossier\n\nEvery selected source is included under its slot-based archive path. Repeated names or identical content retain separate provenance. Capture time and origin are user/browser-supplied metadata. No original path is fetched or reopened.\n\n",
  )
  for source in snapshot.sources {
    out.write_string(
      "### Source \{source.slot}: " +
      source.name +
      "\n\nOrigin: " +
      source.origin +
      "\nCapture time: " +
      source.captured_at +
      "\nKind: " +
      source.kind +
      "\nAvailability: " +
      source.availability +
      "\nRetained file: " +
      source.archive_path +
      "\nBytes: \{source.byte_count}\nDigest: " +
      source.digest +
      "\n\n",
    )
  }
  out.write_string(ris_readable_selections(brief))
  out.write_string(endnote_readable_selections(brief))
  out.write_string(nbib_readable_selections(brief))
  out.write_string(bibtex_readable_selections(brief))
  out.write_string(csl_readable_selections(brief))
  out.write_string(csv_readable_selections(brief))
  out.to_string()
}

///|
/// Complete export is reconstructed only after all immutable bytes validate.
/// Requested output filenames are instructions, never substituted artifacts.
pub async fn export_brief(
  config : Config,
  id : String,
  revision : String,
  name : String,
) -> Bytes {
  let status = brief_status(config, id, revision)
  guard status.state == "prepared" && status.snapshot is Some(snapshot) else {
    fail(
      "Complete export unavailable: the selected revision has missing or changed retained bytes",
    )
  }
  let readable = @utf8.encode(brief_readable(snapshot))
  if name == "brief.md" {
    return readable
  }
  guard name == "dossier.zip" else { fail("Unsupported brief export filename") }
  let files : Array[(String, Bytes)] = [
    ("brief.md", readable),
    ("brief.json", @utf8.encode(snapshot.to_json().stringify(indent=2) + "\n")),
  ]
  // Take all source bytes from the already validated immutable request in this
  // response. An external filesystem mutation cannot mix two capture bases.
  for i, source in snapshot.sources {
    files.push(
      (source.archive_path, brief_source_bytes(snapshot.brief.sources[i])),
    )
  }
  let manifest : Json = {
    "contract_id": "moonfind.brief-dossier-manifest.v1",
    "brief_id": id,
    "revision_id": revision,
    "state": "prepared",
    "boundary": snapshot.boundary,
    "sources": snapshot.sources.to_json(),
    "files": files
    .map(item => {
      let (path, bytes) = item
      let file : Json = {
        "path": path,
        "byte_count": bytes.length(),
        "digest": @store.digest_text(@utf8.decode(bytes) catch { _ => "" }),
      }
      file
    })
    .to_json(),
  }
  files.push(
    ("manifest.json", @utf8.encode(manifest.stringify(indent=2) + "\n")),
  )
  delivery_zip(files)
}
