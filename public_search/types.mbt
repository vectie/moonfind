///|
/// Sanitized, explicitly published marketplace projection. This is a public
/// card, not an agent runtime, MoonBook, workspace, or private memory export.
pub(all) struct PublicListingV1 {
  contract_id : String
  listing_id : String
  listing_kind : String
  publisher_id : String
  title : String
  summary : String
  capabilities : Array[String]
  tags : Array[String]
  action_ids : Array[String]
  publication_state : String
  published_at : String
  version : Int
  content_digest : String
  license_class : String
  rights_summary : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PublicListingIndexRecordV1 {
  contract_id : String
  listing : PublicListingV1
  normalized_text : String
  terms : Array[String]
  semantic_provider_ref : String?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PublicListingSearchRequestV1 {
  contract_id : String
  query : String
  listing_kinds : Array[String]
  required_capabilities : Array[String]
  required_tags : Array[String]
  limit : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PublicListingRankSignalV1 {
  score : Int
  reasons : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PublicListingSearchResultV1 {
  listing : PublicListingV1
  score : Int
  reasons : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PublicListingSearchResponseV1 {
  contract_id : String
  query : String
  provider_id : String
  organic_only : Bool
  results : Array[PublicListingSearchResultV1]
  total_candidates : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Ranking provider port. The deterministic lexical provider is built in;
/// future embedding providers must return the same explainable signal and do
/// not gain access to the unsanitized source object.
pub(all) struct PublicListingRankProviderV1 {
  provider_id : String
  rank : (String, PublicListingIndexRecordV1) -> PublicListingRankSignalV1
}
