# MoonTown pack projection provider

MoonFind publishes `moontown.pack-projection.v1` as a read-only view of
research watches, runs, and reviewed synthesis candidates. MoonTown preserves
MoonFind's schema identifiers and domain payloads.

Bottom-up ideas enter through `research.candidate.intake`, which prepares a
reviewable research watch. It cannot acquire papers, accept claims, or start a
provider-backed run by itself.
