# O2I Syntax - Contextualization

> Generated review snapshot of `O2I Syntax - Contextualization` from `mdl/o2i.archimate`.
> Review artifact only; exact syntax mapping authority is `spc/ctr/archimate/profile.json`.

## View Contract

Visualizes the executable ArchiMate conformance pattern for contextualizing O2I Primitives and PerformanceDimensions.

A typed Context owns an element through composition[contextualizes]; visual nesting has no contextualization semantics. Exact carrier, metadata, and cardinality contracts are defined by spc/ctr/archimate/profile.json. The displayed carriers are Candidate syntax exemplars, not fachliche model instances.

## Nodes

- [<Name> :: O2I Driver] `<Name> :: O2I Driver` (Driver)
- [<Name> :: O2I Mission] `<Name> :: O2I Mission` (Grouping)
- [<Name> :: O2I Performance Dimension] `<Name> :: O2I Performance Dimension` (Grouping)
- [<Name> :: O2I Strategy] `<Name> :: O2I Strategy` (Grouping)

## Relations

- `<Name> :: O2I Mission` --contextualizes--> `<Name> :: O2I Driver` (CompositionRelationship)
- `<Name> :: O2I Strategy` --contextualizes--> `<Name> :: O2I Performance Dimension` (CompositionRelationship)
