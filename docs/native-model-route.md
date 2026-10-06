# MoonFind native model routing

MoonFind starts with no model selected. The trusted host asks the configured
MoonClaw **Cowork** service for its native route using the host's
`book_workspace`. Cowork obtains both the configured default and live catalog
from that exact workspace, which is also the workspace used for execution.
The separate native daemon's route is not used.

Install the companion Cowork `POST /v1/cowork/model-route` endpoint with the
MoonFind host/UI change. An older Cowork service, missing native default,
unavailable catalog, or authorization failure leaves native execution blocked
with an explanation. A healthy `/health` response alone is not model readiness.

Configure the host's existing `--moonclaw-gateway` / `MOONCLAW_GATEWAY_BASE`
setting and `--book-workspace` / `MOONFIND_BOOK_WORKSPACE`. If Cowork requires a
bearer, supply `MOONCLAW_GATEWAY_TOKEN` to the trusted host process. The browser
never receives that token. No credential is configured by this change.

The host publishes a same-origin Cowork relay, restricted to session creation,
reads, config, and messages. It uses the one configured upstream service and
persists session keys under the current MoonFind run. Other sessions, roots,
endpoints, and empty model assignments are rejected. The host-bound workspace
is displayed with the native route. Editing the folder cannot borrow another
workspace's default; restore the bound folder or explicitly reconfigure the
trusted host for a different workspace.

Automatic selection uses only the exact configured native default verified in
the current live catalog. Explicit native selections may use an available
catalog member even when no default is configured. Saved session overrides and
typed selections take precedence over later discovery. An unavailable selection
stays visible and is not replaced. Deliberately selected legacy model selectors
remain supported; they are identified as explicit legacy routes.

New prepared command packets leave their model field unassigned. Submission
must first configure an exact session model and confirm the returned workspace
and model override. Research and Q&A messages also carry that exact selector,
so an empty config cannot silently clear to Cowork's generic default. Existing
prepared commands, attempts, and receipts are not rewritten.

The host dependency compatibility patch separately pins `moonbitlang/x` from
0.4.40 to 0.4.50. The native source checks and tests for this change were run with
async 0.19.4, x 0.4.50, and moonlib 0.1.19. The original x 0.4.40 configuration
was not executable in the supplied offline dependency set.
