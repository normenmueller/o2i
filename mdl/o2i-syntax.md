# O2I Syntax

> Generated review snapshot of `O2I Syntax` from `mdl/o2i.archimate`.
> Review artifact only; source of truth remains the O2I metamodel.

## Nodes

- [Course of Action] `Course of Action` (CourseOfAction)
- [Driver] `Driver` (Driver)
- [Goal] `Goal` (Goal)
- [KPI-Domain] `Assessment` (Assessment)
- [KPI-Domain] `KPI-Domain` (Grouping)
- [Outcome] `Outcome` (Outcome)
- [Principle] `Principle` (Principle)

## Relations

- `Course of Action` --contributes-to--> `Outcome` (RealizationRelationship)
- `Driver` --grounds--> `Goal` (InfluenceRelationship)
- `Driver` --indicates--> `KPI-Domain` (InfluenceRelationship)
- `KPI-Domain` --contains--> `Assessment` (AggregationRelationship)
- `Outcome` --determines--> `KPI-Domain` (InfluenceRelationship)
- `Outcome` --sets-target-for--> `Assessment` (AssociationRelationship)
- `Outcome` --substantiates--> `Goal` (RealizationRelationship)
- `Outcome` --translates-into--> `Goal` (InfluenceRelationship)
- `Principle` --guides--> `Course of Action` (AssociationRelationship)
- `Principle` --guides--> `Driver` (InfluenceRelationship)
- `Principle` --guides--> `Goal` (InfluenceRelationship)
