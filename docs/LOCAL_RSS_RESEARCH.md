# Explore a saved research feed

Use a locally saved RSS 2.0 feed as an evidence table, without retyping article
titles, dates, descriptions and links. This is local source preparation. It does
not fetch articles, refresh a feed, subscribe to updates or contact a publisher.

## Runnable example

1. Open the brief studio at `/apps/moonfind/briefs` in your existing local
   MoonFind installation. In **Capture local sources**, choose **Import saved RSS
   feed (.rss / .xml)** and select
   [`fixtures/local-research-feed.rss`](../fixtures/local-research-feed.rss).
2. The original `local-research-feed.rss.txt` and derived
   `local-research-feed.rss.items.json` appear as two ordinary sources. The exact
   original XML bytes remain unchanged; the `.txt` suffix makes their handling
   explicit. The structured source opens automatically at `/items` in **Explore
   loaded JSON evidence** above the import controls.
3. Search `clinic`, then **Select matching JSON records**. Both the positive
   pilot description and the conflicting comparison remain selected. Their
   duplicate supplied GUID does not merge them. Search `school`: the prior
   selection remains, using the existing explorer's selection behavior.
4. In the projected CSV section, keep the prefilled `/title`, `/link`, `/pubDate`
   and `/author` pointers, preview and download selected fields. Both clinic
   records appear with their original item locators. The missing date/author are
   explicit null values, rather than dates or people inferred by MoonFind.
   For original XML line numbers, add `/source_line` to the selected field list.
5. **Download selected JSON extract** keeps complete selected records and their
   structured-capture pointers. **Add selected JSON records to brief** appends
   that extract. The unchanged XML and complete structured feed remain in the
   brief, including unselected items. Selection is not redaction.
6. The existing browser-local brief draft retains these ordinary captures. Use
   the existing **Save** action for a native host revision. After reopening,
   choose the `.items.json` capture, set `/items`, and **Explore JSON array**.
   Temporary searches/selections are not a saved feed subscription.

Existing JSON cohorts, nested-field inspection, source comparisons, dossier
search and passage collection can also inspect these ordinary captures. For
example, inspect `/categories/0/value`, or compare two separately imported feed
snapshots. Choose a stable key yourself; duplicate GUIDs remain distinct and may
make a comparison key ambiguous. Feed imports do not assert identity or recency.

## Precisely supported subset

The format basis is the [RSS Advisory Board RSS 2.0 specification](https://www.rssboard.org/rss-specification).
This importer is a bounded reading projection, not a universal XML parser or an
RSS conformance validator.

- One UTF-8 `.rss` or `.xml` file, at most 32 KiB. One leading BOM is allowed.
  The derived JSON must also fit 32 KiB. Import needs two of eight source slots,
  within the existing 128 KiB total dossier limit. A large derived capture is
  refused without partially adding sources; no items are silently truncated.
- Unnamespaced `rss` with `version="2.0"`, containing one `channel`, with
  `title`, `link` and `description` present. An empty channel is supported.
  At most 128 items, 4,096 XML elements and 16 nested element levels.
- An optional XML 1.0 UTF-8 declaration; ASCII XML element/attribute names;
  quoted attributes; correctly nested tags; comments; CDATA; the five predefined
  XML entities and valid numeric character references. XML line endings are
  normalized only in parsed values. Original bytes are unchanged.
- Per-item `title`, `link`, `description`, `pubDate`, `author`, `guid`, repeated
  `category` with optional domain, `comments`, `source` with URL, and `enclosure`
  URL/length/type. Channel title/link/description and supplied publication/build
  date are retained in the JSON envelope. Item title or description is required.
- Each item has its one-based `source_item` and original `source_line`. Order and
  duplicates are preserved. Absent optional values are JSON null; present empty
  values remain empty strings. Categories are ordered objects, not merged tags.
- Dates, author strings, enclosure lengths and links keep supplied lexical text.
  Dates are not validated, sorted or timezone-converted. URLs are not resolved,
  opened or downloaded. A present GUID has a string `guid_is_permalink` value of
  `true` or `false`; missing `isPermaLink` takes RSS's `true` default. With no GUID
  both fields are null. This default is not a claim that a GUID is a safe URL.
- Entity-escaped or CDATA description markup is literal text. It is not inserted
  as HTML, stripped into an article or treated as verified full text. Even if a
  publisher supplies a full article in a description, availability/rights and
  factual quality remain unverified. Supplied source instructions are evidence.
- Prefixed extension elements may use declared prefixes. Their tag names appear
  in `unprojected_elements` (or `unprojected_channel_elements`), and their contents
  remain only in the original XML. `content:encoded` and `dc:creator` are not
  promoted to full text or to the standard RSS author field. Unknown unprefixed
  fields likewise remain unprojected. Inspect the original before drawing a
  conclusion from an absent normalized value.

Atom, RDF/RSS 1.0, nonempty default namespaces, non-UTF-8 encodings, DTD/entity
declarations, processing instructions, unbound namespace prefixes, duplicate
attributes or singleton fields, malformed XML, nested elements inside projected
text fields and invalid XML character references fail with a repairable error.
Namespaced attribute declarations are parsed for safe structure; unprojected
metadata is not normalized or fetched. There is no sanitizing/redaction claim:
original feeds, author email strings and descriptions may contain private data.

## Recovery and verification boundary

Cancel leaves the draft unchanged. A newer RSS chooser, brief edit, New or host
operation invalidates an earlier picker callback. Pending host operations block
new imports. Parse/size/capacity errors leave both existing sources and current
exploration intact. Repeated successful imports are separate sources.

`rss_source_wbtest.mbt` and `rss_source_boundaries_wbtest.mbt` exercise actual
compiled MoonBit reducers, the production decoder and picker, Rabbita rendering,
browser-local draft retention, host-shaped save/reopen protocol and existing
JSON/CSV output. Real Node Blob bytes are written/reopened at a controlled DOM
download boundary. Fixtures are synthetic. Headless picker mocks and simulated
save replies are not graphical browser, native host, ZIP/manifest, installed
pack, licensed-source, provider or real researcher acceptance qualification.

Run from this module with your pinned MoonBit toolchain and an absolute external
target directory: `moon --target-dir /absolute/private/build test --target js
--filter 'RSS*'`. The R646 delivery guide records the exact isolated environment
used for this change. Focused acceptance does not establish a full release.
