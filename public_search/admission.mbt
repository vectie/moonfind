///|
fn public_listing_digest_valid(value : String) -> Bool {
  if !value.has_prefix("sha256:") || value.length() != 71 {
    return false
  }
  value[7:]
  .iter()
  .all(fn(character) {
    (character >= '0' && character <= '9') ||
    (character >= 'a' && character <= 'f')
  })
}

///|
fn public_listing_id_valid(value : String) -> Bool {
  !value.is_blank() &&
  value.length() <= 128 &&
  !value.has_prefix("-") &&
  !value.has_prefix(".") &&
  !value.has_prefix(":") &&
  !value.has_suffix("-") &&
  !value.has_suffix(".") &&
  !value.has_suffix(":") &&
  value
  .iter()
  .all(fn(character) {
    (character >= 'a' && character <= 'z') ||
    (character >= '0' && character <= '9') ||
    character == '-' ||
    character == '.' ||
    character == ':'
  })
}

///|
fn public_listing_action_valid(value : String) -> Bool {
  match value {
    "follow"
    | "message"
    | "try"
    | "visit"
    | "request_access"
    | "install"
    | "invite"
    | "share" => true
    _ => false
  }
}

///|
fn public_listing_text_sensitive(value : String) -> Bool {
  let lowered = value.to_lower()
  lowered.contains("/users/") ||
  lowered.contains("/home/") ||
  lowered.contains("file://") ||
  lowered.contains("workspace_root") ||
  lowered.contains("workspace-root") ||
  lowered.contains("api_key") ||
  lowered.contains("api-key") ||
  lowered.contains("authorization:") ||
  lowered.contains("authorization=") ||
  lowered.contains("bearer ") ||
  lowered.contains("oauth_token") ||
  lowered.contains("oauth-token") ||
  lowered.contains("begin private key") ||
  lowered.contains("private_key")
}

///|
fn public_listing_strings_safe(values : ArrayView[String]) -> Bool {
  values.all(fn(value) {
    !value.is_blank() && !public_listing_text_sensitive(value)
  })
}

///|
fn public_listing_exact_fields(fields : Map[String, Json]) -> Bool {
  let allowed = [
    "contract_id", "listing_id", "listing_kind", "publisher_id", "title", "summary",
    "capabilities", "tags", "action_ids", "publication_state", "published_at", "version",
    "content_digest", "license_class", "rights_summary",
  ]
  if fields.length() != allowed.length() {
    return false
  }
  for key, _ in fields {
    if !allowed.contains(key) {
      return false
    }
  }
  true
}

///|
pub fn validate_public_listing(listing : PublicListingV1) -> Array[String] {
  let issues : Array[String] = []
  if listing.contract_id != "moonsuite.public-listing.v1" {
    issues.push("contract_id must be moonsuite.public-listing.v1")
  }
  if !public_listing_id_valid(listing.listing_id) {
    issues.push("listing_id must be a canonical public identifier")
  }
  if listing.listing_kind != "agent" && listing.listing_kind != "building" {
    issues.push("listing_kind must be agent or building")
  }
  if !public_listing_id_valid(listing.publisher_id) {
    issues.push("publisher_id must be a canonical public identifier")
  }
  if listing.publication_state != "published" {
    issues.push("only published listings may enter the public index")
  }
  if listing.title.is_blank() || listing.summary.is_blank() {
    issues.push("title and summary are required")
  }
  if listing.published_at.is_blank() || listing.version < 1 {
    issues.push("published_at and a positive version are required")
  }
  if !public_listing_digest_valid(listing.content_digest) {
    issues.push("content_digest must be canonical lowercase sha256")
  }
  if listing.license_class.is_blank() || listing.rights_summary.is_blank() {
    issues.push("license_class and rights_summary are required")
  }
  if !public_listing_strings_safe(listing.capabilities) ||
    !public_listing_strings_safe(listing.tags) ||
    !public_listing_strings_safe(listing.action_ids) {
    issues.push(
      "capabilities, tags, and actions must contain safe public values",
    )
  }
  if listing.action_ids.is_empty() ||
    !listing.action_ids.all(public_listing_action_valid) {
    issues.push("action_ids must use the governed public action vocabulary")
  }
  if public_listing_text_sensitive(listing.title) ||
    public_listing_text_sensitive(listing.summary) ||
    public_listing_text_sensitive(listing.rights_summary) {
    issues.push("public listing text contains private or secret-like material")
  }
  issues
}

///|
/// Admit an exact public wire object. Unknown top-level fields fail closed so
/// producers cannot accidentally index private runtime/profile extensions.
pub fn admit_public_listing_json(value : Json) -> PublicListingV1 raise {
  guard value is Object(fields) && public_listing_exact_fields(fields) else {
    fail("public listing must contain only the exact sanitized field set")
  }
  let listing : PublicListingV1 = @json.from_json(value)
  let issues = validate_public_listing(listing)
  if !issues.is_empty() {
    fail("public listing rejected: " + issues.join("; "))
  }
  listing
}
