///|
fn delivery_contents(
  run : @research.ResearchRun,
  output : @moontown.TownSynthesisOutput,
) -> Array[(String, String)] {
  let report = StringBuilder()
  report.write_string("# " + run.watch.title + "\n\n")
  report.write_string(delivery_boundary() + "\n\n")
  report.write_string(
    "Run: " +
    run.run_id +
    "\n\nQuestion / source query: " +
    run.watch.query +
    "\n\n",
  )
  report.write_string("## Returned synthesis\n\n")
  for idea in output.ideas {
    report.write_string(
      "### " +
      idea.title +
      "\n\nID: " +
      idea.id +
      "\n\n" +
      idea.summary +
      "\n\n",
    )
    report.write_string(
      "Participating source books: " +
      idea.participating_books.join(", ") +
      "\n\n",
    )
    report.write_string("Why it matters: " + idea.why_it_matters + "\n\n")
    report.write_string(
      "Research questions: " + idea.research_questions.join("; ") + "\n\n",
    )
    report.write_string("Next experiment: " + idea.next_experiment + "\n\n")
  }
  report.write_string("## Retained analysis and contradictions\n\n")
  for summary in run.summaries {
    report.write_string(
      "### Source " + summary.paper_id + "\n\n" + summary.one_sentence + "\n\n",
    )
    report.write_string(
      "Evidence: " +
      summary.evidence +
      "\n\nLimitations: " +
      summary.limitations.join("; ") +
      "\n\n",
    )
    for claim in summary.claims {
      report.write_string(
        "- Claim " + claim.claim_id + ": " + claim.statement + "\n",
      )
      report.write_string(
        "  Sources: " +
        claim.paper_ids.join(", ") +
        "; location: " +
        claim.evidence_location +
        "\n",
      )
      report.write_string(
        "  Reported confidence: " +
        claim.confidence +
        "; counterevidence: " +
        claim.counterevidence +
        "\n",
      )
    }
    report.write_string(
      "\nOpen questions: " + summary.open_questions.join("; ") + "\n\n",
    )
  }
  for idea in run.ideas {
    report.write_string(
      "### Analysis candidate: " + idea.title + "\n\n" + idea.thesis + "\n\n",
    )
    report.write_string(
      "Sources: " +
      idea.source_paper_ids.join(", ") +
      "\n\nCounter-hypothesis: " +
      idea.counter_hypothesis +
      "\n\n",
    )
    report.write_string(
      "Risks: " +
      idea.risks.join("; ") +
      "\n\nFalsifier: " +
      idea.falsifier +
      "\n\nNext experiment: " +
      idea.next_experiment +
      "\n\n",
    )
  }
  report.write_string("## Unresolved questions\n\n")
  for question in run.questions {
    report.write_string(
      "- " +
      question.question +
      "\n  Sources: " +
      question.source_paper_ids.join(", ") +
      "\n  Missing evidence: " +
      question.missing_evidence.join("; ") +
      "\n  Next check: " +
      question.next_check +
      "\n",
    )
  }
  report.write_string("\n## Source register\n\n")
  for paper in run.papers {
    report.write_string(
      "### " +
      paper.title +
      "\n\nID: " +
      paper.paper_id +
      "; snapshot: " +
      paper.versioned_id +
      "\n\n",
    )
    report.write_string(
      "Origin: " +
      paper.abs_url +
      "\nPDF locator (not proof of retrieved full text): " +
      paper.pdf_url +
      "\n\n",
    )
    report.write_string(
      "Digest: " +
      paper.source_digest +
      "; retrieved at epoch milliseconds: \{paper.retrieved_at}\n\n",
    )
    report.write_string(
      "Retained abstract / input text:\n\n" + paper.abstract_text + "\n\n",
    )
  }
  report.write_string(
    "## Retained notes and gaps\n\n" +
    run.synthesis_notes.join("\n\n") +
    "\n\n" +
    run.validation_issues.join("\n\n") +
    "\n",
  )
  let evidence : Json = {
    "contract_id": "moonfind.delivery-evidence.v1",
    "run_id": run.run_id,
    "question": run.watch.query,
    "source_scope": run.watch.to_json(),
    "availability": "Retained metadata and abstract/input text only. PDF URLs do not establish full-text retrieval or rights.",
    "papers": run.papers.to_json(),
    "summaries": run.summaries.to_json(),
    "questions": run.questions.to_json(),
    "synthesis_notes": run.synthesis_notes.to_json(),
    "validation_issues": run.validation_issues.to_json(),
    "ideas": run.ideas
    .map(idea => {
      let value : Json = {
        "idea_id": idea.idea_id,
        "title": idea.title,
        "thesis": idea.thesis,
        "mechanism": idea.mechanism,
        "source_paper_ids": idea.source_paper_ids.to_json(),
        "cross_paper_bridge": idea.cross_paper_bridge,
        "novelty_claim": idea.novelty_claim,
        "counter_hypothesis": idea.counter_hypothesis,
        "risks": idea.risks.to_json(),
        "falsifier": idea.falsifier,
        "next_experiment": idea.next_experiment,
      }
      value
    })
    .to_json(),
  }
  [
    ("report.md", report.to_string()),
    ("evidence.json", evidence.stringify(indent=2) + "\n"),
    ("synthesis.json", output.to_json().stringify(indent=2) + "\n"),
  ]
}
