# O2I Primitives

> Generated review snapshot of `O2I Primitives` from `mdl/o2i.archimate`.
> Review artifact only; source of truth remains the O2I metamodel.

## Nodes

- [Action] `Action` (Grouping)
- [Domain] `Domain` (Grouping)
- [Domain] `KPI` (Grouping)
- [Driver] `Driver` (Grouping)
- [Key Result] `Key Result` (Grouping)
- [Objective] `Objective` (Grouping)
- [Principle] `Principle` (Grouping)

## Relations

- `Action` --contributes-to--> `Key Result` (InfluenceRelationship)
- `Domain` --contains--> `KPI` (AggregationRelationship)
- `Driver` --grounds--> `Objective` (InfluenceRelationship)
- `Driver` --indicates--> `Domain` (InfluenceRelationship)
- `Key Result` --determines--> `Domain` (InfluenceRelationship)
- `Key Result` --sets-target-for--> `KPI` (InfluenceRelationship)
- `Key Result` --substantiates--> `Objective` (InfluenceRelationship)
- `Key Result` --translates-into--> `Objective` (InfluenceRelationship)
- `Principle` --guides--> `Action` (InfluenceRelationship)
- `Principle` --guides--> `Driver` (InfluenceRelationship)
- `Principle` --guides--> `Objective` (InfluenceRelationship)
