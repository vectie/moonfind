# MoonFind

> **General research domain pack · evidence-backed delivery alpha.** Read the
> [product contract](docs/PRODUCT_CONTRACT.md) for provider licensing,
> hostile-document isolation, the closed loop and release gates.

MoonFind is a MoonSuite domain pack for general, evidence-backed research jobs.
The product target is to turn a brief into usable files with source links,
verification receipts, and explicit gaps. The general job path saves a brief,
plans and runs it through MoonClaw, collects finished files, and issues a
delivery manifest after checking bytes and submitted acceptance evidence.
The existing path tracks research questions, acquires and normalizes papers,
asks MoonClaw to create cited summaries and falsifiable ideas, uses MoonTown to
challenge bridges across paper-books, and routes reviewed outcomes to MoonBook
Bookkeeper for Three-Gap learning. See the [reprioritized implementation
plan](docs/IMPLEMENTATION_PLAN.md).

The first specialization is humanoid robotics model research over arXiv. Domain semantics stay in `humanoid/`; general job and delivery contracts stay in `research/`. The implementation is MoonBit-native and the application UI is Rabbita. There is no Python runtime or secondary agent runtime. The [ClawsGO comparison](docs/CLAWSGO_COMPARISON.md) explains the new priorities.

For repeated measurements or responses, [expand nested JSON arrays or keyed child maps into individual CSV observations](docs/JSON_CHILD_OBSERVATIONS.md) with explicit parent/key/value fields, exact original tokens and source-bound lineage, then filter/select them in the ordinary CSV explorer.

For general offline preparation, the [research brief studio](docs/OFFLINE_BRIEFS.md)
captures a question, scope, requested outputs and exact local source bytes. It
supports one or more sources, immutable saved revisions and complete dossier
exports without a research run or provider. A prepared brief is not executed
research or approval of its requested outputs and acceptance criteria.

For a saved news or research bulletin, [import a local RSS 2.0 feed](docs/LOCAL_RSS_RESEARCH.md).
Preserve the original XML, search structured items in the JSON explorer, select
contradictory descriptions and take chosen title/link/date/author fields into CSV.
The importer does not fetch articles, subscribe to feeds or verify source claims.

For a collected reading queue, [import a saved browser bookmark export](docs/RESEARCH_BOOKMARKS.md).
Keep exact HTML beside structured folder paths, titles, duplicate links and
descriptions. Explore a folder or search term, then carry selected links into
JSON/CSV or the brief dossier. Bookmark destinations remain unread and inert.

For a known transcription error, [correct specific CSV cells in a working copy](docs/CSV_CELL_CORRECTIONS.md).
Inspect logical records, review digest-bound old/new cell values, then import the
new CSV while retaining the exact original and per-cell correction provenance.

For inconsistent local category labels, [recode explicit values into a new CSV column](docs/CSV_CATEGORY_RECODING.md).
Preview each mapping, choose how unmatched values are handled, and explore the
derived table while retaining every original column and the exact source file.

For repeated local observations, [consolidate CSV rows with explicit exact keys](docs/CSV_RECORD_CONSOLIDATION.md).
Preview each group and conflicting values, choose keep-first, keep-last or error,
and import the new table with retained source-record identity and original bytes.

From a saved offline brief, [compare choices using its exact local source dossier](docs/OFFLINE_CHOICES.md).
Record alternatives, criteria, uncertainty and a next experiment without creating
a research run. Save/reopen, explicitly continue across saved source revisions,
and export the complete user-authored worksheet and history as Markdown or JSON.

In the research studio, [exact-result review drafts](docs/REVIEW_DRAFTS.md)
autosave selected synthesis IDs, rationale and Three-Gap fields in this browser.
Reload resumes only the same trusted Book, run and source digest. Backup,
restore, clear and storage-error controls are available beside the form;
restoring a draft never submits a review or restores approval authority.

## Start a general research job

```bash
cd ui/rabbita-moonfind && npm run build && cd ../..
moon run cmd/ui_host --target native -- --workspace "$HOME/Research" --port 4313
```

Open `http://127.0.0.1:4313/apps/moonfind/jobs`. Set
`MOONCLAW_GATEWAY_BASE` or pass `--moonclaw-gateway` to run a saved brief;
if the gateway requires authentication, also set `MOONCLAW_GATEWAY_TOKEN`.
Each job lives below `.moonsuite/products/moonfind/jobs/<job-id>/`. Add pasted
text/CSV/JSON/BibTeX, fetch arXiv metadata and abstracts, capture a public
HTTPS page or PDF, or put local files in its `input/` directory before starting.
Captured URLs include a retrieval record and digest. MoonClaw plans the brief, runs in a
separate workspace with the brief and inputs mounted, and writes final files
to its `outputs/`. Refreshing a completed job collects those files into the
MoonFind job's `outputs/` directory. The UI shows actual files, sizes, digests,
and missing requested filenames. Text files have inline previews; images can
be previewed in the job screen; PDFs open in the browser. The **Download
complete ZIP bundle** action includes the brief, source snapshots, final
files, evidence files, revision record, and delivery records when present.
The **Revise** action creates a child job with the prior file and original
sources in `input/`, preserving the old version. MoonFind saves the Cowork session before
planning and records the proposal and run IDs for reconnection. If MoonClaw
pauses for missing information, the job screen shows its reason and accepts a
response through **Resume run**; the same run continues.
Success criteria can be shared across outputs or prefixed with
`filename => criterion` to target one requested file.

To verify a delivery, write `delivery-evidence.json` beside `job.json`. It
names each requested output, real relative evidence files, and one `passed`
check for every exact acceptance criterion in the brief. For example:

```json
{
  "contract_id": "moonfind.delivery-evidence.v1",
  "job_id": "job-123",
  "outputs": [{
    "output_id": "report.md",
    "evidence_refs": ["evidence/sources.md"],
    "checks": [{
      "criterion": "Answers the research objective",
      "status": "passed",
      "evidence_ref": "evidence/sources.md"
    }]
  }]
}
```

The **Verify delivery** action checks file presence, references, requested
criteria, and actual output bytes before writing `delivery-manifest.json`.
It marks the bundle ready for researcher review, not scientifically accepted.
If an output file changes, the UI marks the manifest stale until verification
runs again. The [delivery evidence schema](schemas/delivery-evidence.schema.json)
describes the input contract.

The general path is deliberately open to new job types and output formats.
Researchers can explore and keep intermediate work in the MoonClaw run
workspace; final files go in `outputs/`. The specialized arXiv and robotics workflows remain
available for governed evidence and review.

arXiv intake here contains metadata and abstracts, not article full text.
Plain arXiv topics become quoted phrase searches; advanced field queries are
accepted as entered. See the [arXiv API query guide](https://info.arxiv.org/help/api/user-manual.html#51-details-of-query-construction).
Captured public URLs are snapshots supplied for the job, not a license grant
or a claim that their contents were independently verified. Researchers should
review source use, citations, and conclusions before accepting delivery.

## Specialized evidence and learning loop

Use [JSON evidence cohorts](docs/JSON_EVIDENCE_COHORTS.md) to select source
records satisfying one or two exact nested-field conditions. Preview All/Any
results and unresolved paths separately, then retain original records through
the existing provenance extract, NDJSON or add-to-brief controls.

Use the [nested JSON field lens](docs/JSON_NESTED_FIELD_LENS.md) in the local
evidence explorer to inspect paths such as `/interview/outcome`, distinguish
missing values from blocked parent shapes, and select exact original records
for the existing provenance extract or NDJSON output.

Use [JSON snapshot comparison](docs/JSON_SNAPSHOT_COMPARISON.md) to compare two
loaded captures by a unique record key and chosen nested fields, inspect exact
before/after values and locators, and download a bounded reading report.

Use [projected JSON/JSONL CSV output](docs/JSON_PROJECTED_CSV.md) to take selected
records at explicit nested field pointers into a spreadsheet, with source
locators and distinct missing, blocked, null and empty-value kinds.

The local JSON/JSONL evidence explorer also offers
[selected-record NDJSON downloads](docs/SELECTED_NDJSON_OUTPUT.md) for
line-oriented tools. Preview the exact chosen objects, including hidden
selections, with original numeric/string tokens and no added provenance envelope.
Keep the original dossier when you need capture identity and source lineage.

```text
Research watch
  → arXiv point-in-time paper records
  → deterministic domain relevance ranking
  → MoonClaw gpt-5.6-sol analysis packet
  → evidence-backed summaries, claims, questions, ideas
  → Moontown research salon across paper-books
  → named-human review
  → MoonBook outcome binding
  → Bookkeeper Three-Gap analysis
  → reviewed capability proposal
  → MoonFlow canary/shadow activation
  → next MoonClaw run resolves the assigned capability
  → observed experiment outcome returns to Bookkeeper
```

Moonfind never installs a capability or approves its own output. Model ideas are proposals until evidence and a named human review say otherwise.

MoonFind also exposes an optional [public listing search adapter](docs/PUBLIC_LISTING_SEARCH_ADAPTER.md)
for MoonTown's exact sanitized `moonsuite.public-listing.v1` cards. It performs
deterministic, explainable organic retrieval only; Town continues to own
publication, recommendations, sponsorship, notifications and messaging.

See [Responsibility and testability](docs/RESPONSIBILITY_AND_TESTABILITY.md)
for the executable delegation boundary and layered test model.
See [Execution and capability truth](docs/EXECUTION_AND_CAPABILITY_TRUTH.md)
for the restart-safe installed-pack → MoonClaw Cowork call chain.

## Run the complete fixture

```bash
moon run cmd/main -- run-fixture /tmp/moonfind-workspace fixtures
moon run cmd/main -- status /tmp/moonfind-workspace humanoid-cross-paper-demo
moon run cmd/main -- export-ui /tmp/moonfind-workspace humanoid-cross-paper-demo ui/rabbita-moonfind/public/moonfind-workspace.json
```

The run is written below `.moonsuite/products/moonfind/runs/<run-id>/` with:

- the normalized and ranked paper set;
- a MoonClaw command bound to `gpt-5.6-sol` and `moonfind.humanoid.synthesis`;
- the validated analysis and human-review state;
- a Moontown `research-salon` scenario;
- a versioned Moontown handoff bound to the Moonfind run;
- a MoonBook Bookkeeper deliverable candidate, ready for its own durable review before outcome binding;
- a MoonFlow capability observation;
- a Rabbita workspace projection.

For UI-to-UI qualification, stop before the legacy fixture applies its direct
terminal review:

```bash
MF_QUAL="$(mktemp -d /tmp/moonfind-ui-qualification.XXXXXX)"
moon run cmd/main -- prepare-fixture "$MF_QUAL/suite" fixtures
```

This leaves `humanoid-cross-paper-demo` at `human-review`, with a typed
MoonTown handoff and no `human-review.json`. Follow the
[UI-to-UI guide](docs/qualification/UI_TO_UI_USE_CASES.md) to exercise the
governed MoonTown, MoonChat, and MoonBook path.

## Use live arXiv intake

```bash
moon run cmd/main -- prepare-live ~/Research moonfind-2026-07-20
```

The pending run is durable. The production operator path first invokes
`moonfind/research.prepare-analysis@0.1.0` through MoonClaw's generic
installed-pack seam, appends every attempt/receipt revision, and only then
submits the exact resulting command through the existing MoonClaw Cowork
gateway. The Cowork session/run identity is appended before polling. Save its
durable JSON result, then:

```bash
moon run cmd/main -- complete ~/Research moonfind-2026-07-20 analysis-result.json
moon run cmd/main -- review ~/Research moonfind-2026-07-20 human-review.json
```

Before full text can enter the MoonClaw packet, record a
`moonfind.full-text-evidence.v1` artifact. The command fails closed unless the
provider-use decision allows the exact use, the hostile-PDF isolation receipt
is bound to the PDF digest, active content was removed with networking disabled,
the expansion/page limits pass, and page/section evidence locations exist:

```bash
moon run cmd/main -- record-fulltext ~/Research moonfind-2026-07-20 full-text-evidence.json
moon run cmd/main -- resume ~/Research moonfind-2026-07-20
```

`resume` rebuilds a missing MoonClaw packet from durable run/full-text records
and writes `recovery.json` with the next idempotent action. It never invents a
completed stage.

The arXiv adapter remains a public development/research adapter. Provider
policy records for Crossref, OpenAlex, Semantic Scholar, and a licensed
full-text port are present, but are deny-by-default until a named review records
usable terms. Validate an intended use with:

```bash
moon run cmd/main -- validate-provider provider-policy.json use-request.json
```

## Run the current Moontown handoff

Moonfind and Moontown remain separate products. Moonfind writes a versioned handoff; Moontown consumes it through its existing civic runtime and writes a machine-readable receipt. MoonDesk now exposes the generic MoonFlow composition canvas and can invoke authority-bound actions published by MoonFlow. Moonfind still does not call a model provider directly: the installed MoonClaw host remains the only agent runtime. The equivalent operator path is:

```bash
RUN_DIR="$HOME/Research/.moonsuite/products/moonfind/runs/moonfind-2026-07-20"
RECEIPT="/tmp/moonfind-2026-07-20-moontown-receipt.json"

cd ../moontown
moon run src/cmd/main -- civic protocols pattern-handoff \
  "$RUN_DIR/moontown-handoff.json" "$RECEIPT" "$HOME/Research/.moontown"

cd ../moonfind
moon run cmd/main -- ingest-moontown \
  "$HOME/Research" moonfind-2026-07-20 "$RECEIPT" \
  "$HOME/Research/.moontown/books/wenyu-social-square/raw/bootstrap/civic-communication-results.json"
```

The production route uses Moontown's existing MoonClaw reducer. `pattern-handoff-fixture` exists only for deterministic integration testing. The normal `moonfind review` command refuses to proceed until both the run-bound receipt and typed reducer output have been ingested. A completed receipt must still say `review_status: pending`; Bookkeeper/human review is a separate authority gate. The self-contained `run-fixture` command bypasses the cross-repository prerequisite only as a pack-local fixture.

## Compose a cross-suite robotics job

Publish Moonfind's typed robotics graph into a MoonBook, open that book in
MoonDesk, and switch to MoonFlow:

```bash
moon run cmd/main -- publish-robotics-graph \
  /path/to/moonbook \
  fixtures/humanoid-robotics-requests \
  fixtures/humanoid-robotics-capability-catalog.fixture.v1.json \
  2026-07-31T12:00:00Z
```

The JSON is a 63-stage exact desired graph, never a runnable graph. Every stage
uses a canonical operation, schema, authority, and claim class. MoonBook owns
wiki requirements and Bookkeeper closure; MoonClaw is the only runtime and
runs the `wiki` and `mooncode` roles with `gpt-5.6-sol`. MoonChat owns the
owner, stakeholder, and final authority decisions. The MoonCast tail is a
complete staged production and cut-editor flow through immutable delivery,
client decision, and final evidence—not a monolithic video or publication
call.

`project_desired_graph` shows catalog-derived suggestions for every gap and
emits no `moonsuite.work-model.v1` object unless the entire selected graph is
exactly conformant, healthy, and within its claim ceiling. One missing or
expired operation blocks the entire import. MoonFlow executes; MoonGate and
MoonLib are support-only; MoonEdit and MoonLeaf remain libraries. MoonFish is
outside the robotics book. There is no physical command and no publication
stage.

The checked-in capability catalog beside the workflow is deterministic
fixture-only data. It is deliberately marked synthetic and is not packaged as
production health evidence.

Publication is fail-closed on request materialization. Every one of the 63
stages has exactly one first, pack-owned typed request; MoonFlow appends
dependency outputs later. The publisher requires a complete
`moonfind.robotics-request-materialization.v1` ledger, checks exact
stage/schema/path coverage, payload digests, required top-level fields, and
registered constants, then copies the requests and graph into the target
MoonBook. The bundled request set is schema-valid synthetic scenario data for
projection/adapter preflight only. Replace it with an equivalently complete
validated bundle for real work.

The catalog and evaluation timestamp are explicit. The publisher preserves
bound intent as `flow/desired-graph.json`, projects it against that exact
healthy catalog, writes the resulting `moonsuite.work-model.v1` to
`flow/work-graph.json`, and snapshots the exact evaluated catalog as
`flow/capability-catalog.json` for MoonDesk/MoonFlow validation and replay.
The timestamp above is valid only inside the short-lived synthetic fixture
health window.

The pack contains enforcement contracts and local paths for full-text evidence,
reducer-output ingestion, restart recovery, malicious-document isolation,
provider licensing, and MoonDesk-to-MoonFlow/MoonClaw execution. Production use
still requires real provider contracts, credentials, a deployed isolated
extractor, conformant product adapters and explicit authority grants. The
desired composition JSON is not itself proof of those external facts.

## Rabbita UI

The offline brief studio at `/apps/moonfind/briefs` accepts local BibTeX
bibliographies as citation-keyed cards. Search by title, key, author, year, venue
or keyword; select references; save/reopen the brief; and export the original
bibliography plus selected metadata and a readable reference section. Continue
into an offline comparison to record uncertainties and the next research step.
See [BibTeX bibliography workflow](docs/BIBTEX_BIBLIOGRAPHIES.md) and the synthetic
[`local-bibliography.bib`](fixtures/local-bibliography.bib) sample.

```bash
cd ui/rabbita-moonfind
npm install
npm run build
npm run dev
```

The primary UI now starts with a general research brief and output files. When
a specialized run is selected, the same workspace also shows the humanoid
question: _which cross-paper model idea is worth falsifying next, and why?_
Papers, bridges, counter-hypotheses, falsifiers, open evidence gaps, and the
Bookkeeper state remain visible together.

The same offline studio also accepts **CSL JSON** reference-manager exports.
Search item IDs, citation keys, authors/editors, dates or DOI; choose references;
and continue through the saved brief, dossier and editable comparison. Original
bytes, exact IDs and metadata/abstract availability stay visible. See the
[CSL JSON guide](docs/CSL_JSON_BIBLIOGRAPHIES.md) and
[synthetic library](fixtures/local-bibliography.csl.json).

For tabular sources, **Import CSV table** explores local interview, observation
or evidence rows. Search all cells or one column, select rows and output columns,
then save/reopen the chosen evidence table and export a readable dossier with
the complete original CSV. See the [CSV evidence guide](docs/CSV_EVIDENCE_TABLES.md)
and [synthetic interview table](fixtures/local-evidence.csv).

For wide survey or experiment exports, [reshape selected question columns into
a question-answer CSV](docs/CSV_SURVEY_UNPIVOT.md), then import the result in
the same CSV explorer. Explicit context, cell locators, empty-answer policy and
original-byte provenance keep repeated respondent labels and missing responses
inspectable without manual copying. The offline CLI does not run research.

For JSON observations, **Explore loaded JSON evidence** opens an object array at
the root or a JSON Pointer. Search/select records, preserve exact number tokens
and source locators, then download an extract or add it to the saved brief. See
the [JSON evidence guide](docs/JSON_EVIDENCE_EXPLORER.md) and
[synthetic observations](fixtures/json-evidence.json).

### Annotated reading reports

Search browser-local reading notes and retained reference metadata, choose
attached or detached snapshots, preview and download a human-readable Markdown
report with the matching notes, supplied abstracts and provenance. See
[the annotated reading report walkthrough](docs/ANNOTATED_READING_REPORT.md).

## Local interview quotations

Import WebVTT or SubRip (SRT) transcripts and reuse time-coded quotations in the brief studio. See [SubRip interview evidence](docs/SUBRIP_TRANSCRIPTS.md) for SRT intake, literal cue identifiers and provenance. See [WebVTT transcript workflow](docs/WEBVTT_TRANSCRIPTS.md) for the text adapter, locators, limits and save/reopen workflow.

### Explore local evidence passages

Select a dossier search hit or an explicit line range from any loaded capture,
collect supporting and conflicting passages, annotate them, and download a readable
evidence memo. Exact source snapshots survive later capture changes. See the
[Evidence passage memo workflow](docs/EVIDENCE_PASSAGE_MEMO.md) for the synthetic
walkthrough, browser persistence and output boundaries.

Correct supplied WebVTT/SRT cue text without overwriting the original, download a
usable revised transcript, and reuse it in time-coded quotations. See
[Transcript correction working copies](docs/TRANSCRIPT_CORRECTIONS.md).
