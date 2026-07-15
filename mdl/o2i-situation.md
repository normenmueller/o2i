# O2I Situation

> Generated review snapshot of `O2I Situation` from `mdl/o2i.archimate`.
> Review artifact only; source of truth remains the O2I metamodel.

## Nodes

- [Business Capability] `Business Capability` (Grouping)
- [Business Object] `Business Object` (Grouping)
- [Business Process] `Business Process` (Grouping)
- [Business Role] `Business Role` (Grouping)
- [Regulatory Constraint] `Regulatory Constraint` (Grouping)
- [Situation] `Situation` (Grouping)
- [Situation Anchor] `Situation Anchor` (Grouping)
- [Value Stream] `Value Stream` (Grouping)

## Relations

- `Business Capability` --kind-of--> `Situation Anchor` (SpecializationRelationship)
- `Business Object` --kind-of--> `Situation Anchor` (SpecializationRelationship)
- `Business Process` --kind-of--> `Situation Anchor` (SpecializationRelationship)
- `Business Role` --kind-of--> `Situation Anchor` (SpecializationRelationship)
- `Regulatory Constraint` --kind-of--> `Situation Anchor` (SpecializationRelationship)
- `Situation` --is-constituted-by--> `Situation Anchor` (AggregationRelationship)
- `Value Stream` --kind-of--> `Situation Anchor` (SpecializationRelationship)
