# Retained Q&A sessions

MoonFind retains one Q&A session for a configured research run through its
existing same-origin MoonClaw Cowork relay. It does not introduce a provider,
ACP, Codex, or alternate runtime route.

## Creation and scope

Only an explicit Q&A create request carries `moonfind_purpose: "qa"` and the
exact `moonfind_run_id`. The relay validates these with the trusted Book cwd
and strips them before calling MoonClaw. Ordinary relay callers are unchanged.

The host owns two new files in the existing run directory:

- `qa-session-intent.json`: an immutable creation claim containing the run ID,
  research workspace, Book cwd, and exact configured gateway base
- `qa-session.json`: an immutable acknowledgement containing that scope and
  only the canonical session key returned by MoonClaw

The session key is a runtime identifier, not a bearer token. Host gateway
tokens are never copied. Gateway URLs with userinfo, queries, or fragments are
rejected for this persistence path. Research projections, run metadata,
review records, and current selected evidence are not rewritten.

The creation claim is written with exclusive creation and full sync before
dispatch. The acknowledgement is fully synced to a temporary file and then
published without replacement. A complete temporary acknowledgement can be
read after a failed rename. A later click with a known key reads that exact
session; it does not create a replacement.

## Workspace projection and reload

The existing `qa_cowork_session_key` and `qa_agent_status` fields now publish:

- `not-created`: no Q&A claim exists
- `retained`: a canonical key is retained for this exact host scope
- `creation-uncertain`: an attempt exists but no readable canonical key is
  available, including lost responses and incomplete local writes
- `reconnect-required`: the saved scope differs from the configured Book,
  workspace, run, or gateway, or the binding cannot be validated

Reload only reads workspace and session state. It does not create a session,
configure a model, or send a message. A retained configured session can answer
an explicit question; every question includes the current run projection.
An unconfigured session requires explicit preparation. Historical messages do
not become evidence for the current projection merely because they reloaded.

If the gateway or Book configuration changes, restore the original trusted
configuration and explicitly check the saved session before using it again.
The host never silently moves a key to another gateway. A gateway transport
outage does not erase its retained binding.

## Failure and compatibility

If MoonClaw accepted creation but its response was lost before the canonical
key could be saved, MoonFind cannot prove which session was created through
the current narrow relay contract. It keeps the attempt uncertain, offers
readback, and refuses implicit duplicate creation. It does not invent a key or
guess by session title. An operator must reconcile the original attempt if no
acknowledgement becomes readable; deleting the claim is not an automatic
recovery action.

An acknowledgement saved before generic relay registration or HTTP response
failure is still readable and authorizes only its exact scoped key. Corrupt
records do not prevent loading the research workspace or become an empty
state that would permit a new attempt.

Older generic `cowork-host-sessions` records remain valid for their existing
relay operations. They are not retrospectively classified as Q&A by title or
position. Runs without the new role files continue to load normally. Older
workspace response shapes are still understood by the client.

Retention does not claim that grounding was verified, accept a MoonBook
candidate, alter named review, or trigger learning. Tests use temporary local
workspaces and injected transports; they do not execute a provider.
