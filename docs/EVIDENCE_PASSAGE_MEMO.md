# Collect passages into an evidence memo

Use the ordinary **Research briefs** studio at `/apps/moonfind/briefs` to explore
one question across local text captures. The dossier search could already find a
line, but its search artifact contained only a single query's clipped matches.
Bibliography reading notes only attach to reference records. The passage memo
connects that search to a researcher-curated set of exact quotations from arbitrary
loaded captures, with separate interpretations and a readable output file.

## Try the complete local workflow

1. Choose **New blank brief** or reopen the intended brief. Use **Choose local
   files** to load `fixtures/passage-interview-a.txt` and
   `fixtures/passage-interview-b.txt`. These are invented exercise inputs.
2. In **Search loaded source dossier**, search `Support:`. Choose **Select passage
   from this search hit**. Under **Collect passages into an evidence memo**, the
   first and last line both become 2. Set the last line to 3 to retain the
   qualifying statement about the absent purchase commitment.
3. Inspect **Read source with line numbers** and **Preview exact passage**. Enter
   the memo question, for example “Should the first prototype provide monthly or
   daily access?” Select the `support` label, add your interpretation, and choose
   **Collect this passage**. Nothing is inferred from the quotation.
4. Search `Contradiction:` and select its hit from the second capture. Extend the
   range to lines 2–3, choose `contradiction`, and write why the different access
   frequency matters. Collect it. Both passages remain separate in collection
   order. A question/context passage is equally valid; an empty interpretation is
   explicitly unassessed.
5. Edit either passage's label or interpretation if needed. These edits preserve
   the original quotation and source snapshot. **Remove passage from memo** is
   an explicit removal from this collection; it does not remove a brief source.
6. Open **Preview evidence memo Markdown**, then **Download evidence memo
   Markdown**. Open `moonfind-evidence-passage-memo.md` in a text/Markdown viewer.
   It contains the question, every quote, user label, interpretation, source name,
   origin, supplied capture time, original source slot and inclusive line range.
7. Reload/reopen the same brief on the same browser origin. Your collected
   passages reappear. Remove or replace an original source to see the quotation
   stay intact as a **Historical source snapshot**. It is never retargeted to
   whichever capture now occupies that slot.

The source dropdown also works without search. Choose any loaded capture and an
explicit line range. Changing the source or selecting a new search hit resets the
composer's role to `question` and clears its interpretation so a previous source's
assessment is not reused accidentally. Search itself retains its existing literal
matching and clipped-preview semantics; the collected quote uses the full source
range, never the clipped hit text.

## Persistence and output scope

- Only the memo question, collected passages and edits to those passages autosave.
  The passage composer is session-only until **Collect this passage**. The memo's
  question is independent of later changes to the research brief's question.
- Storage is scoped by browser origin and brief ID. It is not native workspace
  storage. Two workspaces on the same origin with the same brief ID share that
  local collection; use distinct IDs for independent work. Switching briefs in
  the same visit also retains unsaved collections in memory.
- **Native brief Save does not include this collection.** It does not become a
  MoonClaw run, accepted review, choice worksheet, MoonBook memory or MoonProj
  commitment. The earlier bibliography notebook remains separate.
- Markdown includes selected quotes and metadata, not full source bodies. Raw
  source Markdown, HTML and URL text is enclosed in fences longer than any
  embedded backtick run. No source links are fetched or executed.
- **Download complete passage collection JSON** includes every retained source's
  complete original bytes as hexadecimal, including unselected/private content.
  It is an inspectable portable source artifact, not a redacted export. JSON
  import is not implemented. Keep this file and the native brief dossier when
  retaining the original evidence outside browser storage.
- Browser storage failures keep accepted edits in memory and show **NOT VERIFIED
  SAVED**. Retry Save or download before leaving. A compare-before-write conflict
  preserves the other tab's stored bytes. Unreadable storage is not overwritten;
  the raw bytes and a retry-read action are shown.
- A successful download request is not proof of a browser disk save. Failed
  create/click attempts retain the complete collection for another try.

## Exactness and bounds

CRLF, LF and CR each delimit one logical line, matching dossier search. Ranges
are inclusive and preserve every original newline, including the selected last
line's terminator. A trailing newline exposes a final empty line. Blank-only,
out-of-range, reversed and unreadable UTF-8 selections fail without adding a
partial passage. Quoting does not authenticate the supplied author or capture
time, verify a native digest, or make denied/unavailable material available.
Only captures already loaded in the brief can be selected.

A collection holds up to 24 passages and 1 MiB of serialized UTF-8 JSON, including
full source copies. Each question/interpretation is at most 10,000 UTF-16 units;
each original source retains the existing 32 KiB bound. Repeated citations retain
separate snapshots, so the byte limit can be reached before 24 passages. Over-limit
edits preserve the previous collection. No automatic trimming or eviction occurs.
The Markdown file has its own 1 MiB bound because literal fences can expand text.
Use JSON when the readable rendering is too large. Stale/repeated actions and
pending host operations cannot add or change passages.

## PRD connection and qualification

The primary anchor is **MOONFIND-R02 / MOONFIND-F02**: make the evidence and
contradictions behind a decision inspectable without scoring missing evidence as
favorable. This is a bounded local evidence-assembly step; it does not fulfill the
entire side-by-side option/experiment workflow. **MOONFIND-UC02 / B02** and
**MOONFIND-UC04 / B04** supply the existing intake and openable-file context. This
change does not close native source-provenance, complete ZIP/manifest, independent
acceptance or configured provider gates.

From the UI module, with a configured private HOME/XDG and absolute external
build directory:

```sh
moon check --target js --target-dir "$BUILD_DIR"
moon test --target js --target-dir "$BUILD_DIR" --filter 'passage *'
moon test --target js --target-dir "$BUILD_DIR"
moon info --target js --target-dir "$BUILD_DIR"
```

The focused tests execute production MoonBit reducers, exact range extraction,
Rabbita rendering and root event dispatch. They cover contradictory captures,
source replacement/removal, browser reload, repeated/stale actions, bounds,
corrupt/quota/conflicting browser storage and literal escaping. Real Node Blob
bytes are written and reopened with only DOM download and browser storage
boundaries controlled. A dispatched collection sequence produces no native,
provider, MoonBook or MoonProj request. Native-host opt-in tests, graphical
browser interaction, actual browser disk saves, licensed-source access,
provider-backed research, production deployment and named human acceptance remain
unqualified by this slice. No Chromium launch was retried.
