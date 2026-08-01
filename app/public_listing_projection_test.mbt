///|
test "public search projection stays organic and explainable" {
  let listing : @public_search.PublicListingV1 = {
    contract_id: "moonsuite.public-listing.v1",
    listing_id: "building-robot-lab",
    listing_kind: "building",
    publisher_id: "publisher-a",
    title: "Robot Lab",
    summary: "Published robotics work and services.",
    capabilities: ["robotics"],
    tags: ["embodied-ai"],
    action_ids: ["visit"],
    publication_state: "published",
    published_at: "2026-08-01T00:00:00Z",
    version: 1,
    content_digest: "sha256:" + "b".repeat(64),
    license_class: "publisher-declared",
    rights_summary: "Public listing may be indexed.",
  }
  let projected = project_public_listing_search({
    contract_id: "moonfind.public-listing-search-response.v1",
    query: "robotics",
    provider_id: "moonfind.lexical-public-listing.v1",
    organic_only: true,
    results: [{ listing, score: 44, reasons: ["Capability matches"] }],
    total_candidates: 1,
  })
  assert_true(projected.organic_only)
  assert_eq(projected.cards.length(), 1)
  assert_true(projected.cards[0].reason.contains("Capability"))
}
