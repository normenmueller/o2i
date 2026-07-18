# O2I Syntax

> Generated review snapshot of `O2I Syntax` from `mdl/o2i.archimate`.
> Review artifact only; source of truth remains the O2I metamodel.

## View Contract

Defines the concrete ArchiMate realization of O2I Contexts, contextualized Primitives, PerformanceDimensions, Situation anchors, and their relation mappings.

Every O2I Context and PerformanceDimension is represented by an ArchiMate Grouping. ArchiMate Groupings introduce no O2I semantics. Every concrete Primitive and PerformanceDimension instance has exactly one owning Context through composition[contains]. The Interpretation registry admits Primitive @ Context; the role registry admits PerformanceDimension @ Context and constrains its member Primitive type and membership relation without interpreting the members. Visual nesting presents but never replaces persisted ownership. Primitive @ Context and PerformanceDimension @ Context are the textual O2I notations. The bounded ownership examples are syntax exemplars, not fachliche instances.

Situation anchors are independent, ownerless nodes. Their assignment to a Situation is represented exclusively through aggregation[is-constituted-by].

O2I Situation Anchor syntax:

-  O2I BusinessCapability -> ArchiMate Capability
-  O2I BusinessProcess -> ArchiMate Process
-  O2I BusinessObject -> ArchiMate Business Object
-  O2I BusinessRole -> ArchiMate Role
-  O2I ValueStream -> ArchiMate Value Stream
-  O2I RegulatoryConstraint -> ArchiMate Requirement

## Nodes

- [] `Driver @ Mission` (Driver)
- [] `O2I Context (Mission)` (Grouping)
- [] `O2I Context (Strategy)` (Grouping)
- [] `Performance Dimension @ Strategy` (Grouping)
- [Assessment] `Assessment` (Assessment)
- [Course of Action] `Course of Action` (CourseOfAction)
- [Driver] `Driver` (Driver)
- [Goal] `Goal` (Goal)
- [Outcome] `Outcome` (Outcome)
- [Performance Dimension] `Performance Dimension` (Grouping)
- [Principle] `Principle` (Principle)

## Relations

- `Course of Action` --contributes-to--> `Course of Action` (AssociationRelationship, directed)
- `Course of Action` --contributes-to--> `Outcome` (RealizationRelationship)
- `Course of Action` --guides--> `Course of Action` (AssociationRelationship, directed)
- `Driver` --grounds--> `Goal` (InfluenceRelationship)
- `Driver` --indicates--> `Performance Dimension` (InfluenceRelationship)
- `Goal` --orients--> `Goal` (InfluenceRelationship)
- `O2I Context (Mission)` --contains--> `Driver @ Mission` (CompositionRelationship)
- `O2I Context (Strategy)` --contains--> `Performance Dimension @ Strategy` (CompositionRelationship)
- `Outcome` --contributes-to--> `Outcome` (InfluenceRelationship)
- `Outcome` --determines--> `Performance Dimension` (InfluenceRelationship)
- `Outcome` --sets-target-for--> `Assessment` (AssociationRelationship, directed)
- `Outcome` --substantiates--> `Goal` (RealizationRelationship)
- `Outcome` --translates-into--> `Goal` (InfluenceRelationship)
- `Performance Dimension` --contains--> `Assessment` (AggregationRelationship)
- `Performance Dimension` --contains--> `Outcome` (AggregationRelationship)
- `Principle` --guides--> `Course of Action` (AssociationRelationship, directed)
- `Principle` --guides--> `Driver` (InfluenceRelationship)
- `Principle` --guides--> `Goal` (InfluenceRelationship)
- `Principle` --guides--> `Principle` (InfluenceRelationship)
