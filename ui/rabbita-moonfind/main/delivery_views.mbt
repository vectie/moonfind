///|
fn delivery_file_links(id : String, name : String) -> @rabbita.Html {
  match delivery_file_url(id, name) {
    None => span("File link unavailable")
    Some(url) =>
      div(class="delivery-actions", [
        a(
          href=url,
          target=Blank,
          rel="noopener noreferrer",
          escape=true,
          attrs=@html.Attrs::build().aria_label(
            "Preview " + name + " in a new tab",
          ),
          "Preview " + name,
        ),
        a(href=url, download=name, escape=true, "Download " + name),
      ])
  }
}

///|
fn delivery_manifest_panel(manifest : DeliveryManifest) -> @rabbita.Html {
  div(class="delivery-package", [
    evidence_fact("Package ID", manifest.delivery_id),
    evidence_fact("Saved run", manifest.run_id),
    ul(
      class="delivery-files",
      manifest.files.map(file => {
        li([
          strong(file.name),
          span(
            class="delivery-file-meta",
            (if file.name == "report.md" { "Markdown" } else { "JSON" }) +
            " · " +
            file.byte_count.to_string() +
            " bytes · " +
            file.media_type,
          ),
          delivery_file_links(manifest.delivery_id, file.name),
          details([summary("Exact byte digest"), code(file.digest)]),
        ])
      }),
    ),
    div(class="delivery-file", [
      strong("manifest.json"),
      span(
        class="delivery-file-meta",
        "JSON · file names, byte sizes and digests",
      ),
      delivery_file_links(manifest.delivery_id, "manifest.json"),
    ]),
    match delivery_file_url(manifest.delivery_id, "package.zip") {
      Some(url) =>
        a(
          class="delivery-zip",
          href=url,
          download="moonfind-" + manifest.delivery_id + ".zip",
          escape=true,
          "Download complete package · ZIP · 3 files + manifest",
        )
      None => @html.nothing
    },
    details([
      summary("Package provenance and boundaries"),
      evidence_fact("Run byte digest", manifest.run_digest),
      evidence_fact("Synthesis byte digest", manifest.source_digest),
      p(manifest.boundary),
    ]),
  ])
}

///|
fn delivery_panel(emit : @rabbita.Emit[Msg], model : Model) -> @rabbita.Html {
  let current = delivery_context_current(model)
  let pending = if current { model.delivery.pending } else { None }
  let status = if current { model.delivery.status } else { None }
  let selected_id = if current { model.delivery.selected_id } else { None }
  let preparing = pending.map(request => request.preparing).unwrap_or(false)
  let complete = status.map(value => value.state == "complete").unwrap_or(false)
  section(
    class="delivery-panel",
    attrs=@html.Attrs::build().data_set("testid", "report-delivery"),
    [
      h3("Report files"),
      p(
        "Save a durable Markdown report with its evidence, retained synthesis and manifest. These files project retained content; preparing them does not create new synthesis, approve a decision or add a review gate.",
      ),
      div(class="delivery-actions", [
        button(
          class="research-next",
          disabled=pending is Some(_) ||
            model.workspace is None ||
            !model.delivery.workspace_ready,
          on_click=emit(RefreshDelivery),
          if selected_id is Some(_) {
            "Back to current package"
          } else {
            "Check saved packages"
          },
        ),
        button(
          class="research-next",
          disabled=pending is Some(_) ||
            !current ||
            current_synthesis(model) is None ||
            selected_id is Some(_) ||
            complete,
          on_click=emit(PrepareDelivery),
          if preparing {
            "Preparing report files…"
          } else {
            "Prepare report files"
          },
        ),
      ]),
      if current && !model.delivery.versions.is_empty() {
        details(class="delivery-versions", [
          summary(
            "Saved package versions (\{model.delivery.versions.length()})",
          ),
          p(
            "Open an immutable saved version. Older packages remain labeled as historical and do not replace the current research result.",
          ),
          ul(
            model.delivery.versions.map(id => {
              li(
                button(
                  class="research-next delivery-version",
                  disabled=pending is Some(_) || selected_id == Some(id),
                  on_click=emit(SelectDelivery(id)),
                  "Open saved package " + id,
                ),
              )
            }),
          ),
        ])
      } else {
        @html.nothing
      },
      div(
        class="delivery-status",
        attrs=@html.Attrs::build().aria_live("polite"),
        [
          if !model.delivery.workspace_ready {
            p(
              "Waiting for a readable current workspace. Reload the result before checking report files; previous package links are hidden.",
            )
          } else if pending is Some(_) {
            p(
              if preparing {
                "Preparing exact files for the displayed synthesis. Preview and download links appear only after validation."
              } else {
                "Checking saved report files… Previous package links are hidden until this check finishes."
              },
            )
          } else if current && model.delivery.error is Some(error) {
            p(class="evidence-boundary", "Report files unavailable: " + error)
          } else {
            match status {
              None =>
                p(
                  "No package loaded. Check saved packages to read existing files. A readable completed synthesis is required to prepare the current report.",
                )
              Some(value) =>
                div([
                  strong(
                    match value.state {
                      "complete" =>
                        if selected_id is Some(_) {
                          "Historical saved package · complete"
                        } else {
                          "Current package · complete"
                        }
                      "not-prepared" => "Report files not prepared"
                      "incomplete" =>
                        "Saved package incomplete · downloads unavailable"
                      "stale" =>
                        "Historical saved package · current research differs"
                      _ => "Report files unavailable"
                    },
                  ),
                  p(value.detail),
                  if selected_id is Some(id) {
                    p(
                      class="evidence-boundary",
                      "Historical version: " +
                      id +
                      ". Its saved evidence and synthesis may differ from the current workspace.",
                    )
                  } else if value.state == "stale" {
                    p(
                      class="evidence-boundary",
                      "This intact package contains earlier retained content. Its saved evidence or synthesis differs from the current workspace, or current source bytes are unavailable. Preview and download preserve that historical version; prepare report files to package readable current content.",
                    )
                  } else {
                    @html.nothing
                  },
                  if !value.issues.is_empty() {
                    ul(value.issues.map(issue => li(issue)))
                  } else {
                    @html.nothing
                  },
                  match value.manifest {
                    Some(manifest) if value.state == "complete" ||
                      value.state == "stale" =>
                      delivery_manifest_panel(manifest)
                    _ => @html.nothing
                  },
                ])
            }
          },
        ],
      ),
    ],
  )
}
