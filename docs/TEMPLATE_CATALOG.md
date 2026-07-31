# MoonFind template catalog

MoonFind publishes the Lunar Habitat Decision Series through the shared
`moonsuite.template-catalog.v1` envelope at `templates/catalog.v1.json`. Its
source digest binds
`workflows/lunar-habitat-decision-series-source.v1.json`, and the owner payload
contains only MoonFind's local series selector.

The template is `local-qualified`: its typed 38-stage desired graph and bounded
UI inspection passed the retained local qualification. It is independently
`recovery.blocked` because
`mooncast/needs-intake.approve-and-seed@0.3.0` is not published and MoonFlow
cannot yet materialize all late-bound inputs plus auxiliary authority/QC
evidence. MoonDesk therefore offers inspection, not execution.

The envelope binds that retained qualification report by digest, declares an
owner-reviewed migration policy, and names the research app as its preview.
The composite catalog/template identity and source digest are separate pins.

MoonDesk does not interpret the series payload or its research/robotics
semantics. Opening the preview does not create a template instance or start the
38-stage graph; the currently blocked template remains inspection-only.
