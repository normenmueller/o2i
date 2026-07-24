# O2I Syntax - Contextualization

> Generated review snapshot of `O2I Syntax - Contextualization` from `mdl/o2i.archimate`.
> Review artifact only; source of truth remains the O2I metamodel.

## View Contract

Defines the concrete ArchiMate syntax for contextualizing O2I Primitives and PerformanceDimensions by typed O2I Context instances.

Every concrete Primitive and PerformanceDimension is contextualized by exactly one Context through composition[contextualizes]. Contexts and PerformanceDimensions are represented by ArchiMate Groupings; the Groupings introduce no O2I semantics. Visual nesting presents but never replaces explicit contextualization.

The Interpretation registry admits Primitive @ Context. The role registry admits PerformanceDimension @ Context and constrains its member Primitive type and membership relation without interpreting the members. Primitive @ Context and PerformanceDimension @ Context are derived textual readings, not persisted element names.

The shown combinations are typed syntax exemplars, not fachliche model instances.

Source: O2I syntax mapping based on The Open Group (2026).

## Nodes

- [<Name> :: O2I Driver] `<Name> :: O2I Driver` (Driver)
- [<Name> :: O2I Mission] `<Name> :: O2I Mission` (Grouping)
- [<Name> :: O2I Performance Dimension] `<Name> :: O2I Performance Dimension` (Grouping)
- [<Name> :: O2I Strategy] `<Name> :: O2I Strategy` (Grouping)

## Relations

- `<Name> :: O2I Mission` --contextualizes--> `<Name> :: O2I Driver` (CompositionRelationship)
- `<Name> :: O2I Strategy` --contextualizes--> `<Name> :: O2I Performance Dimension` (CompositionRelationship)
