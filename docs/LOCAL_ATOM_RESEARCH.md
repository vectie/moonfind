# Saved Atom feeds in a research brief

MoonFind can turn a saved Atom 1.0 feed into a browsable research source without a provider or feed subscription.

1. Open the research brief workspace and choose **Import saved Atom feed (.atom / .xml)**.
2. Select `fixtures/local-research-feed.atom`, or your UTF-8 saved feed. Allow two free source slots.
3. The original XML is retained byte-for-byte as an inert `.txt` source. A second `.items.json` source opens in the existing JSON evidence explorer at `/items`.
4. Search for `clinic`, select matching rows, and download the selected CSV. Its initial fields are title, updated date, first link href and first entry author's name. Change the JSON pointer field list to project other link, author, summary or category fields.
5. Add selected evidence to the brief. Browser-local draft restoration retains both captures; the existing brief save/open workflow also retains them. After reopening, choose the `.items.json` source and explore `/items` again.

The capture preserves entry order, duplicate identifiers, supplied dates and relative URI spelling. Feed-level authors remain separate from entry authors. Text and escaped-HTML titles/summaries are inert strings; they are never rendered as source HTML. Missing fields remain null or empty arrays. Each entry includes its original item number and XML line number.

This is a bounded reading projection of [Atom 1.0 (RFC 4287)](https://www.rfc-editor.org/info/rfc4287/), not a full feed validator. Default and prefixed Atom namespaces are supported. XHTML text constructs are unsupported. Content and extension elements remain available in the exact original; the projection lists their element names. No links, enclosures or external content are fetched. No dates, authors or claims are authenticated.

Limits: one saved feed up to 32 KiB, up to 128 entries, structured capture up to 32 KiB, 16 XML nesting levels, 4,096 elements. Existing brief limits remain eight source slots and 128 KiB total. Unsupported or oversized input leaves the existing source set unchanged. DTDs and custom entities are not supported.

## Focused verification

From `ui/rabbita-moonfind`, run `moon test --target js --filter '*Atom*'` and the existing RSS tests. Atom tests exercise capture metadata, namespace prefixes, inert rendering, search/selection/CSV, draft restore, saved-brief reply reopening and cancelled/stale/unsupported import handling. The saved-brief test uses the existing host-shaped reply fixture, not a live native host or graphical browser.
