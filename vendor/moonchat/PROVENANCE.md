# Pinned MoonChat review contract

This is the unmodified pure `review/` package from the official MoonChat
repository, commit `d567f1d23c1d2bf128e99d094f857d4e6ff5061f`, tree
`20a5f1f9431b59f7213a72817b62161858210455`, recovered on 2026-10-04.
Source: https://github.com/vectie/moonchat/tree/d567f1d23c1d2bf128e99d094f857d4e6ff5061f/review

The package is vendored as an exact source pin because the recovered full
MoonChat module uses async 0.20.2 while this host uses async 0.19.4. The pure
review package only consumes core JSON and MoonLib conversation 0.1.19,
already pinned by MoonFind. No MoonChat runtime, adapter or new dependency
resolution is introduced. Its public package header is regenerated under
the local vendor path; its MoonBit source and upstream regression tests are
unchanged. Apache-2.0 license retained alongside this file.

Review semantics belong to MoonChat. Make updates by replacing this pin
with another independently verified upstream package, not by changing its
validation, authority, projection or tests in MoonFind. Host-specific
receipt storage, source matching and UI remain in `host/` and the Rabbita
consumer. This does not claim current upstream or Mac parity.
