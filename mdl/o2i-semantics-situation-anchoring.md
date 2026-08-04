# O2I Semantics - Situation Anchoring

> Generated review snapshot of `O2I Semantics - Situation Anchoring` from `mdl/o2i.archimate`.
> Review artifact only; semantic authority remains the O2I metamodel.

## View Contract

Illustrates how one Situation Anchor binds Situation, Driver @ Need, Action @ Intervention, and KPI @ Measure to the same operational subject.

This View is an explanatory semantic projection of the metamodel defined in o2i.md, not an independent semantic contract.

## Nodes

- [Action] `Action @ Intervention` (Grouping)
- [Driver] `Driver @ Need` (Grouping)
- [KPI] `KPI @ Measure` (Grouping)
- [Situation] `Situation` (Grouping)
- [Situation Anchor] `Situation Anchor` (Grouping)

## Relations

- `Action @ Intervention` --changes--> `Situation Anchor` (AssociationRelationship, directed)
- `KPI @ Measure` --measures--> `Situation Anchor` (AssociationRelationship, directed)
- `Situation` --is-constituted-by--> `Situation Anchor` (AggregationRelationship)
- `Situation Anchor` --anchors--> `Driver @ Need` (AssociationRelationship, directed)
