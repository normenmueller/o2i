# O2I Syntax

> Generated review snapshot of `O2I Syntax` from `mdl/o2i.archimate`.
> Review artifact only; source of truth remains the O2I metamodel.

## View Contract

Every O2I Context is represented by an ArchiMate Grouping. An O2I Primitive is contextualized by placement inside its owning Context Grouping; Primitive @ Context is the textual notation of this containment.

O2I Situation Anchor syntax:

O2I BusinessCapability -> ArchiMate Capability
O2I BusinessProcess -> ArchiMate Process
O2I BusinessObject -> ArchiMate Business Object
O2I BusinessRole -> ArchiMate Role
O2I ValueStream -> ArchiMate Value Stream
O2I RegulatoryConstraint -> ArchiMate Requirement

## Notes

- Note: Every O2I Context is represented by an ArchiMate Grouping.

## Nodes

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
