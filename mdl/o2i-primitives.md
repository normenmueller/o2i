# O2I Primitives

> Generated review snapshot of `O2I Primitives` from `mdl/o2i.archimate`.
> Review artifact only; source of truth remains the O2I metamodel.

## View Contract

Defines the normative type-level view of O2I Primitives, PerformanceDimension, and admissible relation families.

The view intentionally abstracts from concrete Primitive and Structuring instances and their owning Contexts. It does not assert that every displayed relation is admissible for every Context. Concrete ownership and context-sensitive admissibility are defined by Instantiation, the Interpretation registry, the PerformanceDimension role registry, and the typed Relation registry. Their concrete ArchiMate realization is defined in O2I Syntax.

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
