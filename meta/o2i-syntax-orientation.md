# O2I Syntax - Orientation

> Generated review snapshot of `O2I Syntax - Orientation` from `meta/o2i.archimate`.
> Review artifact only; exact syntax mapping authority is `spec/ctr/archimate/profile.json`.

## View Contract

Visualizes the ArchiMate syntax for Ethos, Mission and Vision. The displayed elements are Candidate syntax exemplars. Exact syntax is defined by spec/ctr/archimate/profile.json; meaning and minimum obligations by doc/paper/o2i.md.

For this View's reading, see the paper's Metamodell / Syntax / Semantische Begründung. Minimum contents and required witnesses are defined under Metamodell / Wohlgeformtheit und Validierung / Semantische Gültigkeit.

The six displayed guides/grounds endpoint pairs admit directed Association or Influence with absent or empty Strength. Source, target, relation name and commitment remain unchanged.

See O2I Orientierung for the conceptual overview. O2I Syntax - Carriers, O2I Syntax - Contextualization and O2I Syntax - Relations provide the general carrier, ownership and relation-family mappings.

## Nodes

- [<Name> :: O2I Driver] `<Name> :: O2I Driver` (Driver)
- [<Name> :: O2I Ethos] `<Name> :: O2I Ethos` (Grouping)
- [<Name> :: O2I Mission] `<Name> :: O2I Mission` (Grouping)
- [<Name> :: O2I Objective] `<Name> :: O2I Objective` (Goal)
- [<Name> :: O2I Principle] `<Name> :: O2I Principle` (Principle)
- [<Name> :: O2I Vision] `<Name> :: O2I Vision` (Grouping)

## Relations

- `<Name> :: O2I Driver` --grounds--> `<Name> :: O2I Objective` (AssociationRelationship, directed)
- `<Name> :: O2I Ethos` --contextualizes--> `<Name> :: O2I Principle` (CompositionRelationship)
- `<Name> :: O2I Ethos` --guides--> `<Name> :: O2I Mission` (AssociationRelationship, directed)
- `<Name> :: O2I Ethos` --guides--> `<Name> :: O2I Vision` (AssociationRelationship, directed)
- `<Name> :: O2I Mission` --contextualizes--> `<Name> :: O2I Driver` (CompositionRelationship)
- `<Name> :: O2I Mission` --grounds--> `<Name> :: O2I Vision` (AssociationRelationship, directed)
- `<Name> :: O2I Principle` --guides--> `<Name> :: O2I Driver` (AssociationRelationship, directed)
- `<Name> :: O2I Principle` --guides--> `<Name> :: O2I Objective` (AssociationRelationship, directed)
- `<Name> :: O2I Vision` --contextualizes--> `<Name> :: O2I Objective` (CompositionRelationship)
