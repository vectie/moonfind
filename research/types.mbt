///|
pub fn research_contract_version() -> String {
  "moonfind.research.v1"
}

///|
pub(all) struct RecordRef {
  record_id : String
  record_version : String
  record_digest : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct ResearchWatch {
  watch_id : String
  title : String
  query : String
  categories : Array[String]
  keywords : Array[String]
  negative_keywords : Array[String]
  max_papers : Int
  cadence : String
  domain_profile : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PaperRecord {
  paper_id : String
  versioned_id : String
  title : String
  abstract_text : String
  authors : Array[String]
  categories : Array[String]
  published_at : String
  updated_at : String
  abs_url : String
  pdf_url : String
  source_digest : String
  retrieved_at : Int64
  relevance_score : Int
  relevance_reasons : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PaperClaim {
  claim_id : String
  statement : String
  paper_ids : Array[String]
  evidence_location : String
  confidence : String
  counterevidence : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PaperSummary {
  paper_id : String
  one_sentence : String
  problem : String
  method : String
  evidence : String
  limitations : Array[String]
  claims : Array[PaperClaim]
  open_questions : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct ResearchQuestion {
  question_id : String
  question : String
  source_paper_ids : Array[String]
  missing_evidence : Array[String]
  next_check : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct ResearchIdea {
  idea_id : String
  title : String
  thesis : String
  mechanism : String
  source_paper_ids : Array[String]
  cross_paper_bridge : String
  novelty_claim : String
  counter_hypothesis : String
  risks : Array[String]
  falsifier : String
  next_experiment : String
  domain_payload : Json
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct ResearchAnalysisResult {
  contract_version : String
  result_id : String
  model : String
  summaries : Array[PaperSummary]
  questions : Array[ResearchQuestion]
  ideas : Array[ResearchIdea]
  synthesis_notes : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct ResearchRun {
  contract_version : String
  run_id : String
  watch : ResearchWatch
  status : String
  papers : Array[PaperRecord]
  summaries : Array[PaperSummary]
  questions : Array[ResearchQuestion]
  ideas : Array[ResearchIdea]
  synthesis_notes : Array[String]
  validation_issues : Array[String]
  started_at : Int64
  completed_at : Int64?
  human_review_status : String
  accepted_idea_ids : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct HumanResearchReview {
  review_id : String
  run_id : String
  reviewer_id : String
  authority_ref : String
  disposition : String
  accepted_idea_ids : Array[String]
  rejected_idea_ids : Array[String]
  notes : String
  reviewed_at : Int64
} derive(Debug, Eq, ToJson, FromJson)
