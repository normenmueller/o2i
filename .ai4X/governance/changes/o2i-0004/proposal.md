# O2I-0004: Lean Situation Anchor Set

Author: `normenmueller`

## Problem

The closed `SituationAnchor` type admits `BusinessRole` and
`RegulatoryConstraint`, although neither denotes the operational effect
subject required by the complete anchor relation family. An O2I Situation
anchor must locate a Need Driver and denote the same business performance,
behavior, information, or value-flow subject whose state an Intervention
Action changes and a Measure KPI observes. Responsibility allocation and
externally imposed regulation contextualize such a subject; they are not that
subject.

## Minimal Generic Case

A regulation motivates a Need concerning an affected Business Process. The
Intervention changes that Process and the KPI observes the same Process. The
regulation remains related Enterprise Architecture evidence; it is not itself
the changed and measured anchor.

## Benefit

A smaller closed type makes every admitted anchor satisfy the same trace
relations without constructor-specific exceptions:

```text
BusinessCapability | BusinessProcess | BusinessObject | ValueStream
```

The result is easier to explain, model, validate, and extend only from
demonstrated generic need.

## O2I Fit

The four constructors form the minimal currently substantiated closed core:

- `BusinessCapability` denotes a business-performance subject;
- `BusinessProcess` denotes a behavioral subject;
- `BusinessObject` denotes an information subject;
- `ValueStream` denotes an end-to-end value-flow subject.

For each constructor, `is-constituted-by`, `anchors`, `changes`, and `measures`
refer directly to that same subject. `BusinessRole` allocates responsibility
or behavior to an actor; changing that allocation affects an anchored
Capability or Process but does not make the Role the operational effect
subject. `RegulatoryConstraint` states an external condition; an Intervention
changes the affected anchor rather than the condition. Both remain available
as normal Enterprise Architecture artifacts and may be related to the affected
anchor. Regulation may also motivate a `Driver`; no new O2I type is required.

The set is an O2I authors' decision, not a complete set prescribed by TOGAF or
ArchiMate. It is not asserted to exhaust every conceivable effect subject. A
genuine effect subject outside this set remains unmodelled as an O2I
SituationAnchor until a separate generic extension establishes its benefit and
complete relation semantics. Substituting an admitted constructor merely to
obtain formal conformance is invalid.

## Alternatives

- Keeping all six constructors requires relation exceptions and weakens the
  common anchor invariant.
- Making Situation anchors open-ended prevents exhaustive typing and permits
  semantically unsuitable artifacts.
- Adding `BusinessService` or retaining `BusinessRole` anticipates use cases
  that have not established a distinct generic benefit and complete
  constructor semantics.

## Non-goals

- removing roles or regulation from Enterprise Architecture models;
- defining new relations for arbitrary EA artifacts;
- claiming a complete TOGAF or ArchiMate Business Architecture taxonomy;
- preserving obsolete constructors through migration or compatibility code.

## Risks

Future evidence may show that another EA artifact satisfies the complete anchor
contract without distortion. Such an extension requires its own generic
benefit and relation analysis.

## Dependencies

Derived from the profile-contract implementation in `o2i-0003`.
`o2i-0003` depends on this semantic correction before its mapping contract can
be finalized.
