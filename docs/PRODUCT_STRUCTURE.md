# MoonFind product structure

MoonFind follows the MoonSuite product implementation standard v2 as an
**evidence-backed research domain pack**. Specializations and curated series
remain domain-owned; MoonClaw and MoonFlow are referenced through typed ports,
not reimplemented.

| Standard responsibility | MoonFind path | Boundary |
| --- | --- | --- |
| Research domain | `research/`, `humanoid/`, `series/`, `hardening/` | Evidence admission, synthesis records, specializations and desired series intent. |
| Application and review | `app/`, `closed_loop/`, `host/` | Durable projections and named-review preparation. |
| Provider/adapters | `arxiv/`, `providers/`, `pack_adapter/`, `adapters/moonflow/` | Permission-aware acquisition and generic executable seams. |
| Public catalog adapter | `public_search/`, `providers/public-listing-ranking.port.json` | Sanitized published-card admission and organic retrieval only; MoonTown retains publication and social policy. |
| Pack boundary | `pack.json`, `schemas/`, `workflows/` | Versioned tools, handoffs and domain workflow templates. |
| Visible application | `ui/rabbita-moonfind/` | Research journey and typed scenario catalog in Rabbita. |
| Composition roots | `cmd/` | Native UI/tool hosts without research policy duplication. |
| Qualification | `docs/qualification/`, package-local `*_test.mbt` files | Ordinary journey, hostile-input denial, recovery and receipt return. |

The Rabbita package separates the goal journey (`journey.mbt`), series catalog
(`series_views.mbt`) and semantic line icons (`ui_icons.mbt`) from the detailed
research workbenches. The selector consumes the host-published
`moonsuite.series-use-case.v1` catalog; choosing a template never executes its
desired graph. MoonDesk must create a run-bound handoff before MoonFlow may
consider it executable.

The L2 primary journey is: load permitted evidence → execute cited synthesis
through MoonClaw → challenge it in MoonTown → record a named portable review →
return it to MoonBook Bookkeeper for Three-Gap learning.
