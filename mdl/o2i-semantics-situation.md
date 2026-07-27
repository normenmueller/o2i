# O2I Semantics - Situation

> Generated review snapshot of `O2I Semantics - Situation` from `mdl/o2i.archimate`.
> Review artifact only; semantic authority remains the O2I metamodel.

## View Contract

Visualizes the closed O2I SituationAnchor type, its four constructors, and the constitution of Situation.

This View is a checked semantic projection of the metamodel defined in o2i.md; it contains neither concrete SituationAnchor instances nor an ArchiMate syntax contract.

## Nodes

- [Business Capability] `Business Capability` (Grouping)
- [Business Object] `Business Object` (Grouping)
- [Business Process] `Business Process` (Grouping)
- [Situation] `Situation` (Grouping)
- [Situation Anchor] `Situation Anchor` (Grouping)
- [Value Stream] `Value Stream` (Grouping)

## Relations

- `Business Capability` --kind-of--> `Situation Anchor` (SpecializationRelationship)
- `Business Object` --kind-of--> `Situation Anchor` (SpecializationRelationship)
- `Business Process` --kind-of--> `Situation Anchor` (SpecializationRelationship)
- `Situation` --is-constituted-by--> `Situation Anchor` (AggregationRelationship)
- `Value Stream` --kind-of--> `Situation Anchor` (SpecializationRelationship)
