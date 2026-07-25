# O2I-0001: Lean Change Governance

Author: `normenmueller`

## Problem

Changes to the O2I Framework can originate from publication work,
formalization, implementation, or observations in concrete instances. Without
an explicit admission step, a locally useful idea can enter O2I before its
generic value, scope, and consequences are understood.

## Minimal Generic Case

An O2I user identifies a possible new Framework concept while applying O2I.
The concept may close a generic semantic gap, or it may only solve the local
case. The distinction must be made before implementation planning changes the
Framework.

## Users

- authors and maintainers evolving O2I;
- reviewers assessing strategy, metamodel, and formalization changes;
- agentic AI agents proposing or implementing O2I changes;
- practitioners relying on a lean and coherent Framework.

## Benefit

A short admission decision establishes why a change is needed, whom it serves,
and whether it belongs in generic O2I. It protects scope while allowing useful
ideas to proceed with clear dependencies, independent review, and an explicit
return point.

## O2I Fit

The process applies O2I's own standard of relational justification to Framework
development: a change is not accepted merely because it can be implemented.
Its problem, generic benefit, and fit must first be made explicit and reviewed.
The governance remains outside O2I fachliche semantics.

## Alternatives

- Informal discussion alone is too easy to lose and cannot be checked by a
  later agent.
- A comprehensive governance engine would exceed the problem and slow normal
  Framework work.
- GitHub Issues alone would make an external service the process authority.

## Non-goals

- governing editorial, generated, or demonstrably semantics-preserving work;
- encoding O2I fachliche semantics in governance tooling;
- introducing organization- or notation-specific requirements;
- replacing expert judgment with deterministic validation.

## Risks

- Excessive process would discourage small but valuable Framework changes.
- Weak role separation could turn review into self-confirmation.
- Unclear fork handling could expand an admitted scope during implementation.

The target design therefore uses short proposals, two independent Admission
reviews, a small register, a separate post-Admission plan, basic dependency
checks, and one revision-bound Finalreview.

## Dependencies

None.
