# O2I Semantics - Primitives

> Generated review snapshot of `O2I Semantics - Primitives` from `mdl/o2i.archimate`.
> Review artifact only; semantic authority remains the O2I metamodel.

## View Contract

Visualizes the O2I Primitive, PerformanceDimension, and relation-family metatypes.

Concrete contextualization and context-sensitive admissibility remain defined by the metamodel in o2i.md. This View is a checked semantic projection, not a normative source.

## Nodes

- [Action] `Action` (Grouping)
- [Driver] `Driver` (Grouping)
- [KPI] `KPI` (Grouping)
- [Key Result] `Key Result` (Grouping)
- [Objective] `Objective` (Grouping)
- [Performance Dimension] `Performance Dimension` (Grouping)
- [Principle] `Principle` (Grouping)

## Relations

- `Action` --contributes-to--> `Action` (InfluenceRelationship)
- `Action` --contributes-to--> `Key Result` (InfluenceRelationship)
- `Action` --guides--> `Action` (InfluenceRelationship)
- `Driver` --grounds--> `Objective` (InfluenceRelationship)
- `Driver` --indicates--> `Performance Dimension` (InfluenceRelationship)
- `Key Result` --contributes-to--> `Key Result` (InfluenceRelationship)
- `Key Result` --determines--> `Performance Dimension` (InfluenceRelationship)
- `Key Result` --sets-target-for--> `KPI` (InfluenceRelationship)
- `Key Result` --substantiates--> `Objective` (InfluenceRelationship)
- `Key Result` --translates-into--> `Objective` (InfluenceRelationship)
- `Objective` --orients--> `Objective` (InfluenceRelationship)
- `Performance Dimension` --contains--> `KPI` (AggregationRelationship)
- `Performance Dimension` --contains--> `Key Result` (AggregationRelationship)
- `Principle` --guides--> `Action` (InfluenceRelationship)
- `Principle` --guides--> `Driver` (InfluenceRelationship)
- `Principle` --guides--> `Objective` (InfluenceRelationship)
- `Principle` --guides--> `Principle` (InfluenceRelationship)
