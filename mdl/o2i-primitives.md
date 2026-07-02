# O2I Primitives

> Generated review snapshot of `O2I Primitives` from `mdl/o2i.archimate`.
> Review artifact only; source of truth remains the O2I metamodel.

## Nodes

- [Action] `Action` (Grouping)
- [CSF] `CSF` (Grouping)
- [CSF] `Key Result` (Grouping)
- [CSF] `Objective` (Grouping)
- [Domain] `Domain` (Grouping)
- [Domain] `KPI` (Grouping)
- [Driver] `Driver` (Grouping)
- [Gap] `Gap` (Grouping)
- [Junction] `Junction` (Junction)
- [Principle] `Principle` (Grouping)

## Relations

- `Action` --addresses--> `Gap` (InfluenceRelationship)
- `Action` --contributes-to--> `Key Result` (InfluenceRelationship)
- `CSF` --Aggregation--> `Key Result` (AggregationRelationship)
- `CSF` --Aggregation--> `Objective` (AggregationRelationship)
- `Domain` --Aggregation--> `KPI` (AggregationRelationship)
- `Driver` --determines--> `Domain` (InfluenceRelationship)
- `Driver` --motivates?/ grounds?--> `Objective` (InfluenceRelationship)
- `Junction` --reveals--> `Gap` (InfluenceRelationship)
- `KPI` --provides actual value--> `Junction` (InfluenceRelationship)
- `KPI` --refines--> `KPI` (InfluenceRelationship)
- `Key Result` --provides target value--> `Junction` (InfluenceRelationship)
- `Key Result` --sets-target-for--> `KPI` (InfluenceRelationship)
- `Key Result` --substantiates--> `Objective` (InfluenceRelationship)
- `Key Result` --translates-into--> `Objective` (InfluenceRelationship)
- `Principle` --guides--> `Driver` (InfluenceRelationship)
- `Principle` --guides--> `Objective` (InfluenceRelationship)
