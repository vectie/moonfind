# Moonfind responsibility and testability

Moonfind is the evidence-backed research domain pack. It owns research watches,
point-in-time paper records, evidence admission, cited analysis contracts,
cross-paper idea validation, and reviewed handoffs. It does not own an agent
runtime, Moontown's deliberation reducer, Bookkeeper acceptance, capability
activation, or experiment execution.

## Responsibility boundary

| Concern | Responsible owner | Moonfind behavior |
|---|---|---|
| Paper/provider rights | Reviewed provider policy | Fail closed on use, model-input, commercial, retention, redistribution, or expiry mismatch. |
| Hostile PDF extraction | Isolated extractor | Admit only digest-bound, network-disabled, bounded evidence receipts. |
| Model analysis | MoonClaw | Send a typed `gpt-5.6-sol` prompt packet; retain Moonfind ownership. |
| Cross-paper deliberation | Moontown | Send/ingest typed run-bound handoff and reducer receipt. |
| Research acceptance | Named human | Validate exact idea IDs and authority receipt. |
| Durable learning | MoonBook Bookkeeper | Submit a candidate; never accept or classify its own outcome. |
| Capability activation | MoonFlow after review | Observe assignments; never self-install a capability. |

## Refactored test seams

- `research_command_responsibility_issues` verifies that Moonfind delegates only
  a bounded prompt/model loop to MoonClaw. It rejects wrong models,
  self-approval, activation authority, and secret-shaped packet fields.
- `decide_provider_use` is covered independently from network acquisition and
  proves identity, permission, retention, and expiry failures.
- `recovery_snapshot` is covered as a pure state-to-next-action function, so a
  restart cannot invent completed analysis, Moontown, review, or Bookkeeper
  stages.

Research result validation remains separate from provider transport, human
review, Moontown execution, and downstream experiments. Fixture synthesis
cannot satisfy a live licensed-provider or prospective experiment gate.
