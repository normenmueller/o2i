# O2I Syntax - Collective Strategy Realization

> Generated review snapshot of `O2I Syntax - Collective Strategy Realization` from `mdl/o2i.archimate`.
> Review artifact only; source of truth remains the O2I metamodel.

## View Contract

Defines the concrete ArchiMate syntax for one O2I CollectiveStrategyRealization.

At least two distinct contributor Strategy Contexts connect through incoming realizes segments to one typed ArchiMate AND Junction. Exactly one outgoing realizes segment connects the Junction to one distinct target Strategy Context. Segment direction and topology determine contributor and target roles.

The Junction carries the complete structured proposition, its Commitment, and the collective Fit evidence reference. The realizes segments are mandatory syntax components and carry no independent Commitment. The shown elements are Candidate syntax exemplars, not fachliche model instances.

Source: O2I syntax mapping based on The Open Group (2026).

## Nodes

- [<Contributor Strategy 1> :: O2I Strategy] `<Contributor Strategy 1> :: O2I Strategy` (Grouping)
- [<Contributor Strategy 2> :: O2I Strategy] `<Contributor Strategy 2> :: O2I Strategy` (Grouping)
- [<Name> :: O2I Collective Strategy Realization] `<Name> :: O2I Collective Strategy Realization` (Junction)
- [<Target Strategy> :: O2I Strategy] `<Target Strategy> :: O2I Strategy` (Grouping)

## Relations

- `<Contributor Strategy 1> :: O2I Strategy` --realizes--> `<Name> :: O2I Collective Strategy Realization` (RealizationRelationship)
- `<Contributor Strategy 2> :: O2I Strategy` --realizes--> `<Name> :: O2I Collective Strategy Realization` (RealizationRelationship)
- `<Name> :: O2I Collective Strategy Realization` --realizes--> `<Target Strategy> :: O2I Strategy` (RealizationRelationship)
