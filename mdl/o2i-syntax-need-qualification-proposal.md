# O2I Syntax - Need Qualification Proposal

> Generated review snapshot of `O2I Syntax - Need Qualification Proposal` from `mdl/o2i.archimate`.
> Review artifact only; exact syntax mapping authority is `spc/ctr/archimate/profile.json`.

## View Contract

Visualizes the executable ArchiMate conformance pattern for one O2I NeedQualificationProposal. The Assessment carrier preserves a nonempty rationale and source. Four directed Association references use o2i.role to bind Need, Strategy, Key Result, and Objective. Exact carrier, metadata, and cardinality contracts are defined by spc/ctr/archimate/profile.json. Together, the displayed carriers form a syntax exemplar, not a fachliche model instance.

## Nodes

- [<Key Result> :: O2I Key Result] `<Key Result> :: O2I Key Result` (Outcome)
- [<Name> :: O2I Need Qualification Proposal] `<Name> :: O2I Need Qualification Proposal` (Assessment)
- [<Need> :: O2I Need] `<Need> :: O2I Need` (Grouping)
- [<Objective> :: O2I Objective] `<Objective> :: O2I Objective` (Goal)
- [<Strategy> :: O2I Strategy] `<Strategy> :: O2I Strategy` (Grouping)

## Relations

- `<Name> :: O2I Need Qualification Proposal` --Association--> `<Key Result> :: O2I Key Result` (AssociationRelationship, directed)
- `<Name> :: O2I Need Qualification Proposal` --Association--> `<Need> :: O2I Need` (AssociationRelationship, directed)
- `<Name> :: O2I Need Qualification Proposal` --Association--> `<Objective> :: O2I Objective` (AssociationRelationship, directed)
- `<Name> :: O2I Need Qualification Proposal` --Association--> `<Strategy> :: O2I Strategy` (AssociationRelationship, directed)
- `<Need> :: O2I Need` --contextualizes--> `<Objective> :: O2I Objective` (CompositionRelationship)
- `<Strategy> :: O2I Strategy` --contextualizes--> `<Key Result> :: O2I Key Result` (CompositionRelationship)
