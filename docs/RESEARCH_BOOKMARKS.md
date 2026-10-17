# Turn a bookmark collection into a research reading queue

Researchers often already have useful links grouped in browser folders. The
brief studio now reads a saved Netscape-format HTML bookmark export and connects
that collection to its existing JSON exploration and selected output tools.
This prepares a reading queue. A bookmark title or description is supplied
metadata, not evidence that its destination was read or that a claim is true.

## Complete local journey

1. Open `/apps/moonfind/briefs` and choose the intended brief. Under **Capture
   local sources**, choose **Import research bookmarks (.html)**. Select the
   synthetic `fixtures/research-bookmarks.html` to try this without real history.
2. Two ordinary sources appear: unchanged original HTML in `.html.txt`, and
   `.html.bookmarks.json`. The existing **Explore loaded JSON evidence** panel
   opens at `/bookmarks`. Four entries include two duplicate links with differing
   supplied descriptions, a school link, and an inert bookmarklet.
3. Search `clinic`, then **Select matching records**. Alternatively, open
   **Select a JSON evidence cohort**, set the first field to `/folder_path/1`,
   the exact scalar value to `"Clinic / pilots"`, preview, then replace selection
   with matching records. The slash is part of a folder title; path arrays retain
   it without inventing another folder level.
4. Preview or download selected CSV. Its default columns contain title, URL,
   full folder-path array, supplied add date and description, together with field
   kinds and record locators. The formula-like title is reversibly escaped by
   the existing CSV exporter. Change field pointers if you need tags or dates.
5. Download the complete selected JSON records, or **Add selected JSON records
   to brief**. Both retain exact individual bookmark and folder identities. The
   latter adds a third ordinary source; it does not remove unselected originals.
6. Reopen the browser-local draft normally. With the existing native save/open
   workflow, select the retained `.bookmarks.json` source and `/bookmarks` again.
   The focused tests simulate native protocol replies; they do not newly qualify
   native persistence or provider execution.

You can explore `/folders` separately to inspect folder descriptions and exact
original folder lines. `/folder_ids/0`, for example, distinguishes equal-named
top-level folders by their source ordinal. Folder title arrays, ordinal arrays
and line arrays are ordered from the root. A root-level bookmark has empty arrays.
Duplicate URLs and equal-named folders are never deduplicated or merged.

## What is read and preserved

- One UTF-8 `.html` or `.htm` file with the Netscape bookmark-export doctype.
  BOM, CRLF and CR are supported. Original bytes are preserved unchanged.
- Case-insensitive `DL`, `DT`, `H3`, `A`, `DD`, `P` and `HR`, with optional
  `META`, `TITLE`, `H1` header fields and comments. Attributes are quoted or
  valueless. Titles/descriptions contain plain text and escaped markup.
- Bookmark title, HREF as `url`, `ADD_DATE`, `LAST_MODIFIED`, `LAST_VISIT`,
  `TAGS`, description, source ordinal and HTML line. Folder titles, descriptions,
  add/modified dates and locators are retained separately.
- Dates remain strings, including unknown, nonnumeric or very large values.
  Missing values are `null`; empty supplied strings remain empty. No date or
  time-zone inference, URL normalization, destination validation or identity
  attestation occurs. Source lines count CRLF, CR and LF as one delimiter.
- Entity decoding supports amp, lt, gt, quot, apos, nbsp and valid numeric
  references. Only the structured projection normalizes source line endings and
  removes a final description newline plus trailing indentation from the export.
  The original retains all markup, comments, whitespace and other attributes.
- Unprojected attribute names are listed. Icon data, toolbar flags, custom
  attributes and other values remain only in the original; no icon is rendered.

This is deliberately not a general HTML parser. Arbitrary pages, scripts,
styles, embedded elements inside titles/descriptions, arbitrary declarations,
duplicate attributes, unbalanced folder lists, non-UTF-8 declarations and unknown
named entities are refused. No partial sources are appended after a parse error.
Firefox JSON/JSONLZ4 backups, browser databases, live browser access and URL
fetching are not part of this importer. Rejected files remain on the user's disk.

Mozilla documents its [HTML bookmark export](https://support.mozilla.org/en-US/kb/export-firefox-bookmarks-to-backup-or-transfer).
That describes obtaining a file; it is not a claim that every browser version or
every variant of bookmark HTML has been qualified here. Use a small permitted
export; larger files or unsupported variants need preparation outside this tool.

## Boundaries, recovery and privacy

The original and structured capture must each fit 32 KiB, with at most 128
bookmarks, 128 folders, 16 nested folder levels and 4,096 lexical tokens. Expanded
JSON may reach its byte bound before record bounds. The pair consumes two of the
existing eight source slots and must fit the existing 128 KiB dossier bound.
Oversized or malformed input leaves both prior sources and explorer unchanged.
Cancel does not import anything. A callback after a brief edit, another intake,
successful import or pending host operation cannot append stale records.

All URLs are inert strings, including `javascript:`, `data:`, `file:` and private
addresses. Nothing is opened, fetched, subscribed to or executed. Selection and
CSV projection do not remove private fields from the original: titles, URLs,
query strings, bookmark descriptions and full original metadata may be sensitive.
Review files before sharing. A successful download request does not prove the
browser saved it to disk; failed downloads leave the source and choices intact.

This is a local intake/exploration slice of **MOONFIND-UC02/B02** and openable
selected-file preparation under **UC04/B04**. It does not qualify licensed access,
source truth, a completed research answer, native manifest delivery, domain
review, production deployment or configured provider research.

## Checks

Twelve focused `bookmarks*` tests execute production parser, picker, root dispatch,
JSON cohort/search, CSV projection, source persistence protocol and downloads.
They cover hierarchy, duplicate URLs, missing data, exact original bytes,
escaped rendering, inert URLs, bounds, malformed input, stale callbacks, picker
cancellation/read failure, mixed valueless/valued attributes with whitespace
separators, duplicate/malformed-attribute rejection, and real Node Blob output
reopened from disk. Browser
storage and DOM boundaries are controlled. Real graphical browser, native host,
installed lifecycle, provider and named human acceptance remain separate gates.
