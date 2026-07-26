# O2I Syntax - Primitives

> Generated review snapshot of `O2I Syntax - Primitives` from `mdl/o2i.archimate`.
> Review artifact only; source of truth remains the O2I metamodel.

## View Contract

Defines the concrete ArchiMate element and relationship mappings for O2I Primitives and PerformanceDimensions.

The shown nodes are unannotated type-mapping exemplars, not fachliche O2I graph nodes or model instances. Their labels and ArchiMate element forms define these mappings:

- O2I Principle -> ArchiMate Principle
- O2I Driver -> ArchiMate Driver
- O2I Objective -> ArchiMate Goal
- O2I Key Result -> ArchiMate Outcome
- O2I KPI -> ArchiMate Assessment
- O2I Action -> ArchiMate Course of Action
- O2I Performance Dimension -> ArchiMate Grouping

An ArchiMate Grouping introduces no O2I semantics. The O2I relation name, direction, endpoint types, and ArchiMate relationship type jointly form each relationship syntax signature. Concrete admissibility remains context-sensitive and follows the Interpretation and role registries. Concrete instances receive their O2I metadata and explicit contextualization according to O2I Syntax - Contextualization.

Source: O2I syntax mapping based on The Open Group (2026).

## Nodes

- [ArchiMate Principle] `ArchiMate Principle` (Principle)
- [O2I Action] `O2I Action` (CourseOfAction)
- [O2I Driver] `O2I Driver` (Driver)
- [O2I KPI] `O2I KPI` (Assessment)
- [O2I Key Result] `O2I Key Result` (Outcome)
- [O2I Objective] `O2I Objective` (Goal)
- [O2I Performance Dimension] `O2I Performance Dimension` (Grouping)

## Relations

- `ArchiMate Principle` --guides--> `ArchiMate Principle` (InfluenceRelationship)
- `ArchiMate Principle` --guides--> `O2I Action` (AssociationRelationship, directed)
- `ArchiMate Principle` --guides--> `O2I Driver` (InfluenceRelationship)
- `ArchiMate Principle` --guides--> `O2I Objective` (InfluenceRelationship)
- `O2I Action` --contributes-to--> `O2I Action` (AssociationRelationship, directed)
- `O2I Action` --contributes-to--> `O2I Key Result` (RealizationRelationship)
- `O2I Action` --guides--> `O2I Action` (AssociationRelationship, directed)
- `O2I Driver` --grounds--> `O2I Objective` (InfluenceRelationship)
- `O2I Driver` --indicates--> `O2I Performance Dimension` (InfluenceRelationship)
- `O2I Key Result` --contributes-to--> `O2I Key Result` (InfluenceRelationship)
- `O2I Key Result` --determines--> `O2I Performance Dimension` (InfluenceRelationship)
- `O2I Key Result` --sets-target-for--> `O2I KPI` (AssociationRelationship, directed)
- `O2I Key Result` --substantiates--> `O2I Objective` (RealizationRelationship)
- `O2I Key Result` --translates-into--> `O2I Objective` (InfluenceRelationship)
- `O2I Objective` --orients--> `O2I Objective` (InfluenceRelationship)
- `O2I Performance Dimension` --contains--> `O2I KPI` (AggregationRelationship)
- `O2I Performance Dimension` --contains--> `O2I Key Result` (AggregationRelationship)
