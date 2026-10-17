# Read a local Slack channel export as research evidence

The offline brief studio now accepts a single channel-export JSON array through
**Import Slack channel export (.json)** under **Capture local sources**.
This is a local corpus input for MOONFIND-UC02. It does not connect to Slack,
resolve users, download files, infer channel membership or verify statements.

1. Select an extracted JSON file from a Slack export you are allowed to use,
   or try [`fixtures/slack-channel-synthetic.json`](../fixtures/slack-channel-synthetic.json).
   ZIP archives, workspace manifests and user directories are not accepted.
2. Two source slots are added atomically: exact original JSON and a readable
   `.conversation.txt` capture. The original remains usable in the existing JSON
   explorer. Both retain filename, origin and capture time for save/reopen.
3. Read source-record locators (one-based positions in the original array),
   literal text, supplied user/bot IDs, supplied usernames, timestamps and edits.
   Search either capture through **Search loaded source dossier** and open hits.
4. Each reply identifies its parent timestamp and original record position when
   present. Orphan replies show an unresolved-context warning. Duplicate
   timestamps remain separate records and ambiguous parents are explicitly
   flagged; no message version is silently chosen. Roots show loaded reply record
   positions and any export-reported reply count, without claiming completeness.
5. Review source restrictions and both captures before saving or sharing the
   brief. Existing save/reopen retains both and existing generation/capacity
   guards prevent stale picker callbacks or partial two-source admission.

## Boundaries

One UTF-8 JSON file, at most 32 KiB and 200 records. Readable expansion must also
fit 32 KiB; smaller exports may be needed. Two free source slots are required;
existing eight-source and 128 KiB dossier limits continue to apply. An empty
array or malformed record fails without adding either source. Cancel changes
nothing. Original BOM, whitespace, ordering and private metadata stay unchanged.

Every record must have type `message` and a string timestamp containing one to
12 seconds digits, a decimal point and exactly six fractional digits. Optional
thread timestamps use the same shape; timestamps are never converted to floating
point or inferred as verified times. Metadata types are checked. Missing or
blank top-level text stays visible as a textless record. Subtypes are labeled;
blocks, reactions, nested event messages, files and attachments are not rendered.
Their original data remains in the original JSON. File/attachment counts appear
in the readable capture and URLs are never contacted. Edits indicate only the
supplied edit time; they do not reconstruct earlier text. All text is untrusted
literal evidence. Message-body lines are indented and metadata is quoted so
export text cannot masquerade as the capture's own record headings.

## Verification

`scripts/test_slack_source.mjs` executes the actual embedded JavaScript parser
and picker. Compiled `slack_source_wbtest.mbt` exercises real reducers, dossier
search, escaped rendering, browser draft retention, save/reopen protocol, stale
callbacks, pending state, malformed import and source-slot capacity. The
save/reopen reply is a fixture; this is not native-host persistence evidence.
All examples are synthetic. No live Slack, browser/file-picker, provider,
Mac or release qualification is claimed.
