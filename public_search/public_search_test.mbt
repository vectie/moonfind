///|
fn public_search_listing(
  id : String,
  kind : String,
  title : String,
  capabilities : Array[String],
  tags : Array[String],
) -> PublicListingV1 {
  {
    contract_id: "moonsuite.public-listing.v1",
    listing_id: id,
    listing_kind: kind,
    publisher_id: "publisher-a",
    title,
    summary: "An accepted public marketplace projection.",
    capabilities,
    tags,
    action_ids: ["visit", "message"],
    publication_state: "published",
    published_at: "2026-08-01T00:00:00Z",
    version: 1,
    content_digest: "sha256:" + "a".repeat(64),
    license_class: "publisher-declared",
    rights_summary: "Public card and accepted examples may be indexed.",
  }
}

///|
test "public admission rejects private extensions and unpublished cards" {
  let valid = public_search_listing(
    "agent-robot-guide",
    "agent",
    "Robot Guide",
    ["robotics", "planning"],
    ["embodied-ai"],
  )
  assert_eq(admit_public_listing_json(valid.to_json()), valid)
  guard valid.to_json() is Object(fields) else {
    fail("fixture must be object")
  }
  fields["workspace_root"] = "/Users/private/work".to_json()
  try admit_public_listing_json(Json::object(fields)) catch {
    error => assert_true("\{error}".contains("exact sanitized field set"))
  } noraise {
    _ => fail("private extension must fail closed")
  }
  let draft = { ..valid, publication_state: "shared_private" }
  assert_true(!validate_public_listing(draft).is_empty())
  assert_true(
    !validate_public_listing({ ..valid, listing_id: "-private-agent" }).is_empty(),
  )
  assert_true(
    !validate_public_listing({ ..valid, listing_id: "private-agent." }).is_empty(),
  )
  assert_true(
    !validate_public_listing({ ..valid, action_ids: ["run-shell"] }).is_empty(),
  )
  assert_true(
    !validate_public_listing({
      ..valid,
      summary: "Authorization: Bearer secret",
    }).is_empty(),
  )
}

///| Golden captured from MoonTown's `public_listing_index_export` so changes

///|
/// to either side fail at the sanitized cross-product boundary.
test "actual MoonTown public export is admitted" {
  let exported = @json.parse(
    (
      #|{"contract_id":"moonsuite.public-listing.v1","listing_id":"agent.robot-guide","listing_kind":"agent","publisher_id":"publisher-a","title":"Robot Guide","summary":"A governed agent that helps teams understand robotics projects.","capabilities":["research","robotics"],"tags":["robotics","education"],"action_ids":["try","follow","message"],"publication_state":"published","published_at":"120","version":3,"content_digest":"sha256:940c93776db717aa5dcd9d46bceda0f8e420013de0a742e114514b3baa69b44b","license_class":"publisher-defined","rights_summary":"Publisher owns or licenses all public card material."}
    ),
  )
  let admitted = admit_public_listing_json(exported)
  assert_eq(admitted.listing_id, "agent.robot-guide")
  assert_eq(admitted.version, 3)
}

///|
test "organic search ranks published agents and buildings with explanations" {
  let robot = index_public_listing(
    public_search_listing(
      "agent-robot-guide",
      "agent",
      "Robot Planning Guide",
      ["robotics", "planning"],
      ["embodied-ai"],
    ),
  )
  let studio = index_public_listing(
    public_search_listing(
      "building-animation-studio",
      "building",
      "Animation Studio",
      ["storyboard", "editing"],
      ["aigc"],
    ),
  )
  let response = search_public_listing_index([robot, studio], {
    contract_id: "moonfind.public-listing-search-request.v1",
    query: "robot planning",
    listing_kinds: ["agent"],
    required_capabilities: ["robotics"],
    required_tags: [],
    limit: 10,
  })
  assert_true(response.organic_only)
  assert_eq(response.provider_id, "moonfind.lexical-public-listing.v1")
  assert_eq(response.results.length(), 1)
  assert_eq(response.results[0].listing.listing_id, "agent-robot-guide")
  assert_true(response.results[0].score > 0)
  assert_true(!response.results[0].reasons.is_empty())
}
