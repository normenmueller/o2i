# O2I Syntax - Context

> Generated review snapshot of `O2I Syntax - Context` from `mdl/o2i.archimate`.
> Review artifact only; source of truth remains the O2I metamodel.

## Nodes

- [<Name> :: O2I Ethos] `<Name> :: O2I Ethos` (Grouping)
- [<Name> :: O2I Intervention] `<Name> :: O2I Intervention` (Grouping)
- [<Name> :: O2I Measure] `<Name> :: O2I Measure` (Grouping)
- [<Name> :: O2I Mission] `<Name> :: O2I Mission` (Grouping)
- [<Name> :: O2I Need] `<Name> :: O2I Need` (Grouping)
- [<Name> :: O2I Situation] `<Name> :: O2I Situation` (Grouping)
- [<Name> :: O2I Strategy] `<Name> :: O2I Strategy` (Grouping)
- [<Name> :: O2I Vision] `<Name> :: O2I Vision` (Grouping)

## Relations

- `<Name> :: O2I Ethos` --guides--> `<Name> :: O2I Mission` (AssociationRelationship, directed)
- `<Name> :: O2I Ethos` --guides--> `<Name> :: O2I Vision` (AssociationRelationship, directed)
- `<Name> :: O2I Intervention` --addresses--> `<Name> :: O2I Need` (AssociationRelationship, directed)
- `<Name> :: O2I Intervention` --changes--> `<Name> :: O2I Situation` (AssociationRelationship, directed)
- `<Name> :: O2I Intervention` --sets-target-for--> `<Name> :: O2I Measure` (AssociationRelationship, directed)
- `<Name> :: O2I Measure` --measures--> `<Name> :: O2I Situation` (AssociationRelationship, directed)
- `<Name> :: O2I Mission` --grounds--> `<Name> :: O2I Vision` (AssociationRelationship, directed)
- `<Name> :: O2I Situation` --surfaces--> `<Name> :: O2I Need` (AssociationRelationship, directed)
- `<Name> :: O2I Strategy` --contributes-to--> `<Name> :: O2I Strategy` (AssociationRelationship, directed)
- `<Name> :: O2I Strategy` --directs--> `<Name> :: O2I Intervention` (AssociationRelationship, directed)
- `<Name> :: O2I Strategy` --directs--> `<Name> :: O2I Strategy` (AssociationRelationship, directed)
- `<Name> :: O2I Strategy` --frames--> `<Name> :: O2I Measure` (AssociationRelationship, directed)
- `<Name> :: O2I Strategy` --qualifies--> `<Name> :: O2I Need` (AssociationRelationship, directed)
- `<Name> :: O2I Vision` --orients--> `<Name> :: O2I Strategy` (AssociationRelationship, directed)
