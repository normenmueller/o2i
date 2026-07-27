# O2I Syntax

> Generated review snapshot of `O2I Syntax` from `mdl/o2i.archimate`.
> Review artifact only; exact syntax mapping authority is `spc/ctr/archimate/profile.json`.

## View Contract

Visualizes the carrier and relationship representations of the concrete ArchiMate mapping defined by spc/ctr/archimate/profile.json.

Notation-independent semantics remain defined by the O2I metamodel in o2i.md. Mapping exemplars and maps-to associations are unannotated specifications, not executable O2I graph propositions. Contextualization and collective Strategy realization use dedicated conformance Views.

## Nodes

- [Action] `Action` (Grouping)
- [ArchiMate Assessment] `ArchiMate Assessment` (Assessment)
- [ArchiMate Assessment] `ArchiMate Assessment` (Assessment)
- [ArchiMate Business Object] `ArchiMate Business Object` (BusinessObject)
- [ArchiMate Business Process] `ArchiMate Business Process` (BusinessProcess)
- [ArchiMate Capability] `ArchiMate Capability` (Capability)
- [ArchiMate Course of Action] `ArchiMate Course of Action` (CourseOfAction)
- [ArchiMate Course of Action] `ArchiMate Course of Action` (CourseOfAction)
- [ArchiMate Driver] `ArchiMate Driver` (Driver)
- [ArchiMate Driver] `ArchiMate Driver` (Driver)
- [ArchiMate Goal] `ArchiMate Goal` (Goal)
- [ArchiMate Goal] `ArchiMate Goal` (Goal)
- [ArchiMate Goal] `ArchiMate Goal` (Goal)
- [ArchiMate Grouping] `ArchiMate Grouping` (Grouping)
- [ArchiMate Grouping] `ArchiMate Grouping` (Grouping)
- [ArchiMate Grouping (source)] `ArchiMate Grouping (source)` (Grouping)
- [ArchiMate Grouping (target)] `ArchiMate Grouping (target)` (Grouping)
- [ArchiMate Outcome] `ArchiMate Outcome` (Outcome)
- [ArchiMate Outcome] `ArchiMate Outcome` (Outcome)
- [ArchiMate Principle] `ArchiMate Principle` (Principle)
- [ArchiMate Principle] `ArchiMate Principle` (Principle)
- [ArchiMate Value Stream] `ArchiMate Value Stream` (ValueStream)
- [Business Capability] `Business Capability` (Grouping)
- [Business Object] `Business Object` (Grouping)
- [Business Process] `Business Process` (Grouping)
- [Context] `Context` (Grouping)
- [Driver] `Driver` (Grouping)
- [KPI] `KPI` (Grouping)
- [Key Result] `Key Result` (Grouping)
- [Objective] `Objective` (Grouping)
- [Performance Dimension] `Performance Dimension` (Grouping)
- [Principle] `Principle` (Grouping)
- [Value Stream] `Value Stream` (Grouping)

## Relations

- `Action` --maps-to--> `ArchiMate Course of Action` (AssociationRelationship, directed)
- `ArchiMate Driver` --<O2I relation name>--> `ArchiMate Goal` (InfluenceRelationship)
- `ArchiMate Grouping` --<O2I relation name>--> `ArchiMate Assessment` (AggregationRelationship)
- `ArchiMate Grouping (source)` --<O2I relation name>--> `ArchiMate Grouping (target)` (AssociationRelationship, directed)
- `ArchiMate Outcome` --<O2I relation name>--> `ArchiMate Goal` (RealizationRelationship)
- `ArchiMate Principle` --<O2I relation name>--> `ArchiMate Course of Action` (AssociationRelationship, directed)
- `Business Capability` --maps-to--> `ArchiMate Capability` (AssociationRelationship, directed)
- `Business Object` --maps-to--> `ArchiMate Business Object` (AssociationRelationship, directed)
- `Business Process` --maps-to--> `ArchiMate Business Process` (AssociationRelationship, directed)
- `Context` --maps-to--> `ArchiMate Grouping` (AssociationRelationship, directed)
- `Driver` --maps-to--> `ArchiMate Driver` (AssociationRelationship, directed)
- `KPI` --maps-to--> `ArchiMate Assessment` (AssociationRelationship, directed)
- `Key Result` --maps-to--> `ArchiMate Outcome` (AssociationRelationship, directed)
- `Objective` --maps-to--> `ArchiMate Goal` (AssociationRelationship, directed)
- `Performance Dimension` --maps-to--> `ArchiMate Grouping` (AssociationRelationship, directed)
- `Principle` --maps-to--> `ArchiMate Principle` (AssociationRelationship, directed)
- `Value Stream` --maps-to--> `ArchiMate Value Stream` (AssociationRelationship, directed)
