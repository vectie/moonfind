///|
fn public_search_normalize(value : String) -> String {
  let mut normalized = value.to_lower()
  for
    separator in [
      ",", ".", ":", ";", "!", "?", "(", ")", "[", "]", "{", "}", "-", "_", "/",
      "\\", "\n", "\t",
    ] {
    normalized = normalized.replace_all(old=separator, new=" ")
  }
  normalized
  .split(" ")
  .filter_map(fn(part) {
    let term = part.trim()
    if term.is_empty() {
      None
    } else {
      Some(term.to_owned())
    }
  })
  .collect()
  .join(" ")
}

///|
fn public_search_terms(value : String) -> Array[String] {
  let terms : Array[String] = []
  for part in public_search_normalize(value).split(" ") {
    let term = part.trim().to_owned()
    if !term.is_empty() && !terms.contains(term) {
      terms.push(term)
    }
  }
  terms
}

///|
pub fn index_public_listing(
  listing : PublicListingV1,
) -> PublicListingIndexRecordV1 raise {
  let issues = validate_public_listing(listing)
  if !issues.is_empty() {
    fail("public listing rejected: " + issues.join("; "))
  }
  let text = [
    listing.title,
    listing.summary,
    listing.publisher_id,
    listing.listing_kind,
    listing.capabilities.join(" "),
    listing.tags.join(" "),
  ].join(" ")
  {
    contract_id: "moonfind.public-listing-index-record.v1",
    listing,
    normalized_text: public_search_normalize(text),
    terms: public_search_terms(text),
    semantic_provider_ref: None,
  }
}

///|
fn public_search_add_reason(reasons : Array[String], reason : String) -> Unit {
  if !reasons.contains(reason) {
    reasons.push(reason)
  }
}

///|
fn lexical_public_listing_rank(
  query : String,
  record : PublicListingIndexRecordV1,
) -> PublicListingRankSignalV1 {
  let normalized_query = public_search_normalize(query)
  if normalized_query.is_empty() {
    return { score: 1, reasons: ["Published marketplace listing"] }
  }
  let query_terms = public_search_terms(normalized_query)
  let title = public_search_normalize(record.listing.title)
  let summary = public_search_normalize(record.listing.summary)
  let capabilities = record.listing.capabilities.map(public_search_normalize)
  let tags = record.listing.tags.map(public_search_normalize)
  let reasons : Array[String] = []
  let mut score = 0
  if title.contains(normalized_query) {
    score += 60
    public_search_add_reason(reasons, "Title matches the query")
  }
  for term in query_terms {
    if public_search_terms(title).contains(term) {
      score += 24
      public_search_add_reason(reasons, "Title contains requested terms")
    }
    if capabilities.contains(term) {
      score += 20
      public_search_add_reason(reasons, "Capability matches the request")
    }
    if tags.contains(term) {
      score += 16
      public_search_add_reason(reasons, "Published tag matches the request")
    }
    if public_search_terms(summary).contains(term) {
      score += 7
      public_search_add_reason(reasons, "Summary contains requested terms")
    }
  }
  if query_terms.all(fn(term) { record.terms.contains(term) }) {
    score += 12
    public_search_add_reason(reasons, "All query terms are present")
  }
  { score, reasons }
}

///|
pub fn deterministic_lexical_public_listing_provider() -> PublicListingRankProviderV1 {
  {
    provider_id: "moonfind.lexical-public-listing.v1",
    rank: lexical_public_listing_rank,
  }
}

///|
fn public_search_record_matches_filters(
  record : PublicListingIndexRecordV1,
  request : PublicListingSearchRequestV1,
) -> Bool {
  (
    request.listing_kinds.is_empty() ||
    request.listing_kinds.contains(record.listing.listing_kind)
  ) &&
  request.required_capabilities.all(fn(required) {
    record.listing.capabilities
    .map(public_search_normalize)
    .contains(public_search_normalize(required))
  }) &&
  request.required_tags.all(fn(required) {
    record.listing.tags
    .map(public_search_normalize)
    .contains(public_search_normalize(required))
  })
}

///|
pub fn search_public_listing_index_with_provider(
  index : ArrayView[PublicListingIndexRecordV1],
  request : PublicListingSearchRequestV1,
  provider : PublicListingRankProviderV1,
) -> PublicListingSearchResponseV1 raise {
  if request.contract_id != "moonfind.public-listing-search-request.v1" ||
    request.limit < 1 ||
    request.limit > 100 {
    fail("public listing search requires the v1 contract and limit 1..100")
  }
  if request.listing_kinds.any(fn(kind) {
      kind != "agent" && kind != "building"
    }) {
    fail("listing kind filters must be agent or building")
  }
  let ranked : Array[PublicListingSearchResultV1] = []
  for record in index {
    if record.contract_id != "moonfind.public-listing-index-record.v1" ||
      !validate_public_listing(record.listing).is_empty() ||
      !public_search_record_matches_filters(record, request) {
      continue
    }
    let signal = (provider.rank)(request.query, record)
    if signal.score > 0 {
      ranked.push({
        listing: record.listing,
        score: signal.score,
        reasons: signal.reasons,
      })
    }
  }
  ranked.sort_by(fn(left, right) {
    let by_score = right.score.compare(left.score)
    if by_score != 0 {
      by_score
    } else {
      left.listing.listing_id.compare(right.listing.listing_id)
    }
  })
  {
    contract_id: "moonfind.public-listing-search-response.v1",
    query: request.query,
    provider_id: provider.provider_id,
    organic_only: true,
    results: if ranked.length() > request.limit {
      ranked[:request.limit].to_owned()
    } else {
      ranked
    },
    total_candidates: index.length(),
  }
}

///|
pub fn search_public_listing_index(
  index : ArrayView[PublicListingIndexRecordV1],
  request : PublicListingSearchRequestV1,
) -> PublicListingSearchResponseV1 raise {
  search_public_listing_index_with_provider(
    index,
    request,
    deterministic_lexical_public_listing_provider(),
  )
}
