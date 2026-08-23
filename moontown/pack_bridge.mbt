///|
pub(all) struct TownPackCandidate {
  contract_id : String
  candidate_ref : String
  origin_ref : String
  target_pack_id : String
  intake_operation_id : String
  submitted_by : String
  submitted_at : String
  title : String
  rationale : String
  claim_ceiling : String
  evidence_refs : Array[String]
  domain_payload : Json
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PackTownSubject {
  subject_ref : String
  schema_id : String
  title : String
  summary : String
  lifecycle_state : String
  attention : String
  place_refs : Array[String]
  related_refs : Array[String]
  workflow_refs : Array[String]
  run_refs : Array[String]
  evidence_refs : Array[String]
  operation_ids : Array[String]
  domain_payload : Json
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PackTownProjection {
  contract_id : String
  pack_id : String
  product_id : String
  version : String
  generated_at : String
  subjects : Array[PackTownSubject]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn intake_research_candidate(
  candidate : TownPackCandidate,
  query : String,
  categories : Array[String],
  keywords : Array[String],
  cadence : String,
  domain_profile : String,
) -> @research.ResearchWatch raise {
  if candidate.contract_id != "moontown.pack-candidate-intake.v1" ||
    candidate.target_pack_id != "moonfind" ||
    candidate.intake_operation_id != "research.candidate.intake" {
    fail("candidate is not addressed to MoonFind research intake")
  }
  if candidate.candidate_ref.trim().is_empty() ||
    candidate.title.trim().is_empty() ||
    query.trim().is_empty() ||
    domain_profile.trim().is_empty() {
    fail("candidate identity, title, query, and domain profile are required")
  }
  {
    watch_id: candidate.candidate_ref,
    title: candidate.title,
    query,
    categories,
    keywords,
    negative_keywords: [],
    max_papers: 50,
    cadence,
    domain_profile,
  }
}

///|
pub fn project_research_watch(
  watch : @research.ResearchWatch,
  summary : String,
  evidence_refs : Array[String],
  generated_at : String,
) -> PackTownProjection {
  {
    contract_id: "moontown.pack-projection.v1",
    pack_id: "moonfind",
    product_id: "moonfind",
    version: "0.1.0",
    generated_at,
    subjects: [
      {
        subject_ref: "research/watches/\{watch.watch_id}",
        schema_id: "research-watch",
        title: watch.title,
        summary,
        lifecycle_state: "watch-draft",
        attention: "review",
        place_refs: ["places/research-salon"],
        related_refs: [],
        workflow_refs: ["workflows/humanoid-research"],
        run_refs: [],
        evidence_refs,
        operation_ids: ["papers.acquire-arxiv", "research.prepare-analysis"],
        domain_payload: {
          "query": watch.query,
          "categories": watch.categories,
          "keywords": watch.keywords,
          "cadence": watch.cadence,
          "domain_profile": watch.domain_profile,
        },
      },
    ],
  }
}
