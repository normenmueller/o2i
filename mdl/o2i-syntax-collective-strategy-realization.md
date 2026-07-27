# O2I Syntax - Collective Strategy Realization

> Generated review snapshot of `O2I Syntax - Collective Strategy Realization` from `mdl/o2i.archimate`.
> Review artifact only; exact syntax mapping authority is `spc/ctr/archimate/profile.json`.

## View Contract

Visualizes the executable ArchiMate conformance pattern for one O2I CollectiveStrategyRealization.

Candidate Strategy carriers connect through realizes segments and one AND Junction serving as the StructuredProposition carrier. Exact cardinality, topology, metadata, and collective Fit-evidence contracts are defined by spc/ctr/archimate/profile.json. The displayed carriers are syntax exemplars, not fachliche model instances.

## Nodes

- [<Contributor Strategy 1> :: O2I Strategy] `<Contributor Strategy 1> :: O2I Strategy` (Grouping)
- [<Contributor Strategy 2> :: O2I Strategy] `<Contributor Strategy 2> :: O2I Strategy` (Grouping)
- [<Name> :: O2I Collective Strategy Realization] `<Name> :: O2I Collective Strategy Realization` (Junction)
- [<Target Strategy> :: O2I Strategy] `<Target Strategy> :: O2I Strategy` (Grouping)

## Relations

- `<Contributor Strategy 1> :: O2I Strategy` --realizes--> `<Name> :: O2I Collective Strategy Realization` (RealizationRelationship)
- `<Contributor Strategy 2> :: O2I Strategy` --realizes--> `<Name> :: O2I Collective Strategy Realization` (RealizationRelationship)
- `<Name> :: O2I Collective Strategy Realization` --realizes--> `<Target Strategy> :: O2I Strategy` (RealizationRelationship)
