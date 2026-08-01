# Public listing search adapter

MoonFind exposes an optional, generic retrieval adapter for MoonTown's
sanitized published marketplace cards. MoonTown remains the owner of
publication, identity, ACLs, recommendations, notifications, sponsorship and
messaging. This adapter owns only admission, indexing and explainable organic
retrieval.

Only the exact `moonsuite.public-listing.v1` wire object is admitted. Unknown
fields fail closed. A listing must be `published`, versioned, rights-labelled
and bound to a canonical SHA-256 digest. The adapter rejects private/shared
cards and obvious paths, credentials, authority or consent material.

Public actions use the shared v1 vocabulary: `follow`, `message`, `try`,
`visit`, `request_access`, `install`, `invite`, and `share`. Search returns
those reviewed identifiers as presentation affordances; it never interprets
them as runtime commands.

The built-in `moonfind.lexical-public-listing.v1` ranker is deterministic. Its
response always declares `organic_only: true`; sponsored placement is never a
ranking feature. `PublicListingRankProviderV1` is the typed seam for a future
embedding ranker, which receives only the already-sanitized index record and
must still return visible reasons.

This package does not create another agent runtime and does not import
MoonTown domain policy. MoonClaw remains the only agent runtime, while Town
decides what is public and how results are presented or recommended.

The adapter is declared as a provider port, not an executable pack tool. The
current installed-pack HTTP adapter implements only MoonFind's governed
research operation; advertising search there without a Town index transport
would create a false capability. Town can use the deterministic library
directly in a composed host until a typed catalog transport is installed.
