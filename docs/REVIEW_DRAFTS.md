# Resume an exact-result review draft

Open the ordinary research studio at `/apps/moonfind/research` after the trusted native host has a correlated completed MoonTown result. Select exact synthesis IDs and enter a decision, rationale and Three-Gap statements in the existing named-human review form. Edits autosave to this browser; expand **Save, resume and back up this review draft** to check the actual save status.

Refresh or reopen the same trusted Book, research run and exact source digest. The local form fields return after the host supplies that correlated result. A different Book, run or digest gets a separate draft. Returning to the previous exact context retrieves its saved draft; unsaved edits are additionally retained during the current visit.

This is a pre-submit convenience, not review authority. Draft restoration does not restore reviewer identity, pending requests, preparation receipts, approval, a native review phase, a MoonFlow request or MoonBook acceptance. A saved draft outcome is only an editable form choice. The native workflow remains authoritative; preparing a review still requires the existing explicit button, named reviewer and validation.

If the host omits the trusted Book identity, the result remains readable but selection, draft storage and review preparation are unavailable. Reload after the host supplies the identity; blank context can never share a saved draft.

## Recovery and portability

- **Retry saving draft** retries a failed or quota-limited browser write. The status distinguishes verified saves from edits held only in memory.
- **Download draft JSON** requests an inert JSON file and also exposes its exact text for copying. Download success means the browser download was requested, not that an OS save dialog was exercised.
- **Retry reading storage; keep my edits** rechecks availability while preserving current form fields. Save explicitly after a read failure is resolved.
- Malformed, unsupported-version, wrong-context and invalid-field stored drafts pause saving. Original unreadable bytes are exposed in the recovery box and can be downloaded before any replacement.
- Paste an exact-context JSON backup and choose **Restore this exact-result form draft** to replace only that local form. Cross-Book, cross-run and cross-digest backups are rejected.
- **Clear this local form draft** explicitly replaces this context's browser record with an empty form. Back up first. Other draft keys and native evidence are untouched.

The versioned `moonfind.review-draft.v1` envelope contains only the exact context and form fields. Automatic storage and restore are limited to 131,072 UTF-16 characters. Oversize edits remain visible but unsaved; an oversize download is for salvage and cannot be re-imported until shortened. Browser storage is local to this origin and profile, not a native-host backup, encrypted vault or cross-device sync.

Compiled tests cover fresh-model reload, run/Book/digest changes, original-byte preservation, corrupt/read/quota failures, explicit restoration and clearing, stale context, pending preparation, malicious text escaping and native prepared-workflow precedence. The separate native crossing uses a deterministic fixture POST to establish correlated result data, then exercises a real localhost completed-result response with compiled UI controllers and checks that draft reload causes no mutation requests. These tests do not qualify graphical browser layout, keyboard/assistive technology, OS file dialogs, providers, customers or production deployment.
