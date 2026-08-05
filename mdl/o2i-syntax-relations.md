# O2I Syntax - Relations

> Generated review snapshot of `O2I Syntax - Relations` from `mdl/o2i.archimate`.
> Review artifact only; exact syntax mapping authority is `spc/ctr/archimate/profile.json`.

## View Contract

Visualizes the relation-representation families of the concrete ArchiMate profile defined by spc/ctr/archimate/profile.json.

Each <O2I relation name> placeholder represents one or more endpoint-compatible O2I relations that share the displayed ArchiMate relationship type and direction. The displayed relations are unannotated mapping specifications, not concrete model relations or executable O2I graph propositions. Exact endpoint-sensitive assignments remain defined by the profile contract.

## Nodes

- [ArchiMate Assessment] `ArchiMate Assessment` (Assessment)
- [ArchiMate Assessment] `ArchiMate Assessment` (Assessment)
- [ArchiMate Capability] `ArchiMate Capability` (Capability)
- [ArchiMate Capability] `ArchiMate Capability` (Capability)
- [ArchiMate Capability] `ArchiMate Capability` (Capability)
- [ArchiMate Capability] `ArchiMate Capability` (Capability)
- [ArchiMate Course of Action] `ArchiMate Course of Action` (CourseOfAction)
- [ArchiMate Course of Action] `ArchiMate Course of Action` (CourseOfAction)
- [ArchiMate Driver] `ArchiMate Driver` (Driver)
- [ArchiMate Driver] `ArchiMate Driver` (Driver)
- [ArchiMate Goal] `ArchiMate Goal` (Goal)
- [ArchiMate Goal] `ArchiMate Goal` (Goal)
- [ArchiMate Grouping] `ArchiMate Grouping` (Grouping)
- [ArchiMate Grouping] `ArchiMate Grouping` (Grouping)
- [ArchiMate Grouping (source)] `ArchiMate Grouping (source)` (Grouping)
- [ArchiMate Grouping (source)] `ArchiMate Grouping (source)` (Grouping)
- [ArchiMate Grouping (target)] `ArchiMate Grouping (target)` (Grouping)
- [ArchiMate Grouping (target)] `ArchiMate Grouping (target)` (Grouping)
- [ArchiMate Outcome] `ArchiMate Outcome` (Outcome)
- [ArchiMate Principle] `ArchiMate Principle` (Principle)

## Relations

- `ArchiMate Assessment` --<O2I relation name>--> `ArchiMate Capability` (AssociationRelationship, directed)
- `ArchiMate Capability` --<O2I relation name>--> `ArchiMate Driver` (AssociationRelationship, directed)
- `ArchiMate Course of Action` --<O2I relation name>--> `ArchiMate Capability` (AssociationRelationship, directed)
- `ArchiMate Driver` --<O2I relation name>--> `ArchiMate Goal` (InfluenceRelationship)
- `ArchiMate Grouping` --<O2I relation name>--> `ArchiMate Assessment` (AggregationRelationship)
- `ArchiMate Grouping` --<O2I relation name>--> `ArchiMate Capability` (AggregationRelationship)
- `ArchiMate Grouping (source)` --<O2I relation name>--> `ArchiMate Grouping (target)` (AssociationRelationship, directed)
- `ArchiMate Grouping (source)` --<O2I relation name>--> `ArchiMate Grouping (target)` (InfluenceRelationship)
- `ArchiMate Outcome` --<O2I relation name>--> `ArchiMate Goal` (RealizationRelationship)
- `ArchiMate Principle` --<O2I relation name>--> `ArchiMate Course of Action` (AssociationRelationship, directed)
