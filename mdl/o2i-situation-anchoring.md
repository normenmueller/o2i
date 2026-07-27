# O2I Situation Anchoring

> Generated review snapshot of `O2I Situation Anchoring` from `mdl/o2i.archimate`.
> Review artifact only; semantic authority remains the O2I metamodel.

## View Contract

Illustrates how one SituationAnchor preserves the same operational effect subject across Situation constitution, Need anchoring, Intervention change, and Measure observation.

This View is an explanatory semantic projection of the metamodel defined in o2i.md, not an independent semantic contract.

## Nodes

- [Intervention] `Action` (Grouping)
- [Intervention] `Intervention` (Grouping)
- [Measure] `KPI` (Grouping)
- [Measure] `Measure` (Grouping)
- [Need] `Driver` (Grouping)
- [Need] `Need` (Grouping)
- [Situation] `Situation` (Grouping)
- [Situation Anchor] `Situation Anchor` (Grouping)

## Relations

- `Action` --changes--> `Situation Anchor` (AssociationRelationship, directed)
- `Intervention` --addresses--> `Need` (InfluenceRelationship)
- `Intervention` --changes--> `Situation` (InfluenceRelationship)
- `Intervention` --sets-target-for--> `Measure` (InfluenceRelationship)
- `KPI` --measures--> `Situation Anchor` (AssociationRelationship, directed)
- `Measure` --measures--> `Situation` (InfluenceRelationship)
- `Situation` --is-constituted-by--> `Situation Anchor` (AggregationRelationship)
- `Situation` --surfaces--> `Need` (InfluenceRelationship)
- `Situation Anchor` --anchors--> `Driver` (AssociationRelationship, directed)
