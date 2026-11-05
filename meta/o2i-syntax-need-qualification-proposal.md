# O2I Syntax - Need Qualification Proposal

> Generated review snapshot of `O2I Syntax - Need Qualification Proposal` from `meta/o2i.archimate`.
> Review artifact only; exact syntax mapping authority is `spec/ctr/archimate/profile.json`.

## View Contract

Visualizes the executable ArchiMate conformance pattern for one O2I NeedQualificationProposal. The Assessment carrier preserves a nonempty rationale and source. Four directed Association references use o2i.role to bind Need, Strategy, Key Result, and Objective. Exact carrier, metadata, and cardinality contracts are defined by spec/ctr/archimate/profile.json. Together, the displayed carriers form a syntax exemplar, not a fachliche model instance.

## Nodes

- [<Name> :: O2I Key Result] `<Name> :: O2I Key Result` (Outcome)
- [<Name> :: O2I Need Qualification Proposal] `<Name> :: O2I Need Qualification Proposal` (Assessment)
- [<Name> :: O2I Objective] `<Name> :: O2I Objective` (Goal)
- [<Name> :: O2I Strategy] `<Name> :: O2I Strategy` (Grouping)
- [<Need> :: O2I Need] `<Need> :: O2I Need` (Grouping)

## Relations

- `<Name> :: O2I Need Qualification Proposal` --Association--> `<Name> :: O2I Key Result` (AssociationRelationship, directed)
- `<Name> :: O2I Need Qualification Proposal` --Association--> `<Name> :: O2I Objective` (AssociationRelationship, directed)
- `<Name> :: O2I Need Qualification Proposal` --Association--> `<Name> :: O2I Strategy` (AssociationRelationship, directed)
- `<Name> :: O2I Need Qualification Proposal` --Association--> `<Need> :: O2I Need` (AssociationRelationship, directed)
- `<Name> :: O2I Strategy` --contextualizes--> `<Name> :: O2I Key Result` (CompositionRelationship)
- `<Need> :: O2I Need` --contextualizes--> `<Name> :: O2I Objective` (CompositionRelationship)
