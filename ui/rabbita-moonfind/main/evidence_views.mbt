///|
extern "js" fn safe_evidence_url(value : String) -> Bool =
  #| value => {
  #|   try {
  #|     const url = new URL(value);
  #|     return ['https:', 'http:'].includes(url.protocol) && !!url.hostname && !url.username && !url.password;
  #|   } catch (_) { return false; }
  #| }

///|
fn evidence_source_link(label : String, url : String) -> @rabbita.Html {
  if safe_evidence_url(url) {
    a(
      href=url,
      target=Blank,
      attrs=@html.Attrs::build().rel("noopener noreferrer"),
      label,
    )
  } else {
    span(label + " · source link unavailable")
  }
}

///|
fn evidence_citations(
  ids : Array[String],
  papers : Array[EvidencePaper],
) -> @rabbita.Html {
  div(
    class="evidence-citations",
    if ids.is_empty() {
      [small("No source paper IDs supplied")]
    } else {
      ids.map(id => {
        match
          papers.search_by(paper => {
            paper.paper_id == id || paper.versioned_id == id
          }) {
          Some(index) => evidence_source_link(id, papers[index].abs_url)
          None => span(id + " · source not in this projection")
        }
      })
    },
  )
}

///|
fn evidence_fact(label : String, text : String) -> @rabbita.Html {
  if text.is_blank() {
    @html.nothing
  } else {
    p([strong(label + ": "), span(text)])
  }
}

///|
fn evidence_detail_panel(workspace : DurableResearchWorkspace) -> @rabbita.Html {
  let papers = workspace.papers.unwrap_or([])
  let summaries = workspace.summaries.unwrap_or([])
  let ideas = workspace.ideas.unwrap_or([])
  let questions = workspace.questions.unwrap_or([])
  div(
    class="evidence-details",
    attrs=@html.Attrs::build().data_set("testid", "run-evidence"),
    [
      p(
        class="evidence-boundary",
        "Current run evidence and analysis candidates. These records are not the separately verified MoonTown synthesis or a named-human acceptance decision. Exact candidate IDs below identify analysis only; the review host validates IDs against the verified synthesis.",
      ),
      if !workspace.validation_issues.is_empty() {
        div(class="evidence-boundary", [
          strong("Evidence needs attention"),
          ul(workspace.validation_issues.map(issue => li(issue))),
        ])
      } else {
        @html.nothing
      },
      h3("Sources"),
      if papers.is_empty() {
        p(
          "No source records were supplied. A paper count alone cannot support a citation.",
        )
      } else {
        div(
          papers.map(paper => {
            details(class="evidence-record", [
              summary([strong(paper.title), code(paper.versioned_id)]),
              div(class="evidence-record-body", [
                code(paper.paper_id),
                p(paper.abstract_text),
                evidence_source_link(
                  "Source · " + paper.abs_url,
                  paper.abs_url,
                ),
                if paper.pdf_url.is_blank() {
                  @html.nothing
                } else {
                  evidence_source_link("PDF", paper.pdf_url)
                },
                evidence_fact("Source digest", paper.source_digest),
              ]),
            ])
          }),
        )
      },
      h3("Cited summaries"),
      if summaries.is_empty() {
        p("No evidence summaries were supplied for this run.")
      } else {
        div(
          summaries.map(item => {
            details(class="evidence-record", [
              summary([strong(item.one_sentence), code(item.paper_id)]),
              div(class="evidence-record-body", [
                evidence_citations([item.paper_id], papers),
                evidence_fact("Problem", item.problem),
                evidence_fact("Method", item.method),
                evidence_fact("Evidence", item.evidence),
                evidence_fact("Limitations", item.limitations.join("; ")),
                div(
                  item.claims.map(claim => {
                    article(class="evidence-claim", [
                      code(claim.claim_id),
                      p(claim.statement),
                      evidence_citations(claim.paper_ids, papers),
                      evidence_fact("Location", claim.evidence_location),
                      evidence_fact("Confidence", claim.confidence),
                      evidence_fact("Counterevidence", claim.counterevidence),
                    ])
                  }),
                ),
                evidence_fact("Open questions", item.open_questions.join("; ")),
              ]),
            ])
          }),
        )
      },
      h3("Analysis candidate ideas"),
      if ideas.is_empty() {
        p("No candidate ideas were supplied for this run.")
      } else {
        div(
          ideas.map(idea => {
            details(class="evidence-record", [
              summary([strong(idea.title), code(idea.idea_id)]),
              div(class="evidence-record-body", [
                evidence_fact("Exact candidate ID", idea.idea_id),
                evidence_citations(idea.source_paper_ids, papers),
                evidence_fact("Thesis", idea.thesis),
                evidence_fact("Mechanism", idea.mechanism),
                evidence_fact("Cross-paper bridge", idea.cross_paper_bridge),
                evidence_fact("Novelty claim", idea.novelty_claim),
                evidence_fact("Counter-hypothesis", idea.counter_hypothesis),
                evidence_fact("Risks", idea.risks.join("; ")),
                evidence_fact("Falsifier", idea.falsifier),
                evidence_fact("Next experiment", idea.next_experiment),
              ]),
            ])
          }),
        )
      },
      h3("Research questions"),
      if questions.is_empty() {
        p("No research questions were supplied for this run.")
      } else {
        div(
          questions.map(question => {
            details(class="evidence-record", [
              summary([strong(question.question), code(question.question_id)]),
              div(class="evidence-record-body", [
                evidence_citations(question.source_paper_ids, papers),
                evidence_fact(
                  "Missing evidence",
                  question.missing_evidence.join("; "),
                ),
                evidence_fact("Next check", question.next_check),
              ]),
            ])
          }),
        )
      },
    ],
  )
}
