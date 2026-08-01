///|
pub(all) struct PublicListingSearchCardV1 {
  listing_id : String
  listing_kind : String
  title : String
  summary : String
  publisher_id : String
  capabilities : Array[String]
  action_ids : Array[String]
  score : Int
  reason : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PublicListingSearchWorkspaceV1 {
  contract_id : String
  title : String
  query : String
  source_label : String
  organic_only : Bool
  result_count : Int
  cards : Array[PublicListingSearchCardV1]
  empty_state : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Rabbita-ready read projection. It does not blend sponsored cards into the
/// organic result set and carries only the already-sanitized public card.
pub fn project_public_listing_search(
  response : @public_search.PublicListingSearchResponseV1,
) -> PublicListingSearchWorkspaceV1 {
  let cards = response.results.map(fn(result) {
    {
      listing_id: result.listing.listing_id,
      listing_kind: result.listing.listing_kind,
      title: result.listing.title,
      summary: result.listing.summary,
      publisher_id: result.listing.publisher_id,
      capabilities: result.listing.capabilities.copy(),
      action_ids: result.listing.action_ids.copy(),
      score: result.score,
      reason: result.reasons.join(" · "),
    }
  })
  {
    contract_id: "moonfind.public-listing-search-workspace.v1",
    title: "Published agents and buildings",
    query: response.query,
    source_label: "Organic results · " + response.provider_id,
    organic_only: response.organic_only,
    result_count: cards.length(),
    cards,
    empty_state: if cards.is_empty() {
      "No published listing matches. Try a capability, domain, or publisher."
    } else {
      ""
    },
  }
}
