# Export selected evidence to line-oriented tools

The existing JSON/JSONL explorer can now produce a plain NDJSON file from
selected evidence records. Use it when a downstream tool expects one original
JSON object per line rather than MoonFind's provenance-wrapped extract format.
This is a new output from the existing source/selection workflow; it does not
fetch anything, execute research, or add an alternative evidence parser.

## Use the synthetic example

1. At `/apps/moonfind/briefs`, use **Choose local files** to add
   [`fixtures/ndjson-selection.json`](../fixtures/ndjson-selection.json).
2. In **Explore loaded JSON evidence**, choose that source, enter `/observations`
   as the JSON Pointer, and choose **Explore JSON array**.
3. Search `clinic`, then **Select matching JSON records**. Records 1 and 3 are
   selected. Search `school` afterward: the selected clinic records remain
   selected even though the table now shows the school record.
4. Open **Preview selected raw NDJSON records**. Check both complete objects,
   including nested/private fields. Choose **Download selected raw NDJSON records**.
   The filename is `moonfind-selected-records.ndjson`.
5. Import that file with the existing **Import JSONL / NDJSON file** action when
   you need to inspect the result again. The two output objects become records
   1 and 2 at physical lines 1 and 2; the old locators are not reconstructed.
6. Retain the original brief dossier or separately download **selected JSON
   extract** if source names, origins, original locators and host-recorded
   revision/digest provenance are needed.

The same output works after **Explore loaded JSONL lines**. Source selections
remain session-only and are not saved by downloading. Downloading does not
append a source, change a saved revision, or clear the selection. A failed
download leaves it available for retry.

## File contract

- UTF-8, one object per LF-delimited line, a final LF, and no BOM.
- Every field of each selected original object is included. Hidden selections
  are included; unselected records are excluded. There is no field redaction.
- Original record order is retained even if clicked out of order. Repeated
  selection IDs do not duplicate a row; identical objects at distinct source
  positions remain distinct rows.
- Only space, tab, CR and LF outside JSON strings are removed. Whitespace and
  escape spelling inside strings, huge integers, `-0`, exponent tokens and
  decimal trailing zeroes remain exact. Nested objects/arrays remain nested.
- The conversion uses JSON parsing for validity checks only, never to rewrite
  record values. Other applications may still round/overflow numeric values;
  use a lossless reader where this distinction matters.
- No wrapper, provenance fields, source body or digest is added. A field that
  already exists inside the chosen record is retained verbatim, regardless of
  its name. This output cannot replace the canonical original dossier.
- Select at least one current record. Empty, out-of-range or stale selections
  produce a repairable error and no file. The existing source/record limits
  remain 32 KiB and 512 records; nothing is silently truncated.

For example, an original selected record spanning several physical lines:

```json
{
  "count": 9007199254740993,
  "ratio": 1.2300,
  "note": "keep  spaces\ninside"
}
```

becomes one line, with no numeric conversion:

```json
{"count":9007199254740993,"ratio":1.2300,"note":"keep  spaces\ninside"}
```

No source instructions or links are executed. Review all selected contents
before sharing. Neither export nor a matching digest proves scientific truth,
source rights, full-text review, a completed research job or customer demand.
A browser click is not proof that a file reached disk.

## Focused qualification

From the repository root:

```sh
node --test scripts/test_json_evidence_ndjson.mjs
```

Thirty focused Node checks execute the JavaScript bodies extracted directly
from production MoonBit externs: existing lossless intake, the new selection
and compaction helper, real Blob bytes, and the download handler with a
controlled DOM boundary. They cover JSON and JSONL selection, exact tokens,
reimport, bounds, errors, nonmutation and object-URL cleanup. One explicitly
named source-wiring check inspects the MoonBit reducer/preview connections.

The MoonBit wrappers/reducers were not compiled or executed in R453. No
graphical browser, real file picker/disk-save, native host, provider or full
product suite was run. Product dependencies are unavailable; no dependency
install or substitution was attempted. This focused source-JavaScript evidence
does not advance cumulative R50 qualification or the separate R51–55 tracks.
