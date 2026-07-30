# O2I Change Governance

O2I uses a lean, agentic-first rule for change: think before writing. A
Framework change is implemented only after its generic problem, benefit, fit,
and consequences are explicit and independently accepted.

This contract governs O2I development. It defines no fachliche O2I semantics.

## Authority

- A GitHub Issue owns the change problem, target, scope, acceptance,
  dependencies, admission, implementation contract, state, and reviews.
- Native Issue Dependencies own blocking relations.
- The public GitHub Project
  [O2I](https://github.com/users/normenmueller/projects/4) is the PO scheduling
  view. It owns no admission, dependency, review, or closure fact.
- `.ai4X/STATE.md` holds only the activated local handoff. It is not a backlog
  or historical record.
- Git commits and CI own implementation and verification artifacts.
- `CONTRIBUTING.md` is the concise human-facing workflow.

Do not duplicate Issue state or Project history in `.ai4X`.

## Issue Paths

Use `framework-change` when work affects terminology, metamodel semantics,
normative syntax, formalization, validation behavior, or a public API.

Use `maintenance` for semantics-preserving tooling, presentation, tests, CI,
or repository administration. Review depth follows demonstrated risk. If the
classification is uncertain, use `framework-change`.

## Framework Admission

A Framework-change Issue states:

1. generic problem and affected users;
2. generic benefit and fit with O2I;
3. fresh target state;
4. scope, non-goals, alternatives, and risks;
5. observable acceptance criteria;
6. participants, lineage, and required review capabilities.

Strategy and formalization reviewers independently accept the exact Issue body
digest. The author, co-authors, and reviewers are distinct. From the first
Admission review, the body is contractually frozen; editing it invalidates
Admission.

The implementation contract is written after Admission as one separate,
digest-bound Issue comment. A changed contract is a new comment and requires a
new impact classification.

## Activation And Dependencies

An agent implements an Issue only when:

- the Issue is open;
- Project status is `Ready` or `In progress`;
- required Admission is accepted;
- `.ai4X/STATE.md` identifies the Issue and authorized scope;
- no unresolved dependency blocks the next action.

`Paused` requires an explicit PO decision, reason, and return condition. A
required blocker within the O2I Issue graph uses only a native Issue
Dependency. `blocked:external` applies only to a required dependency outside
that graph and records its source and next-check condition.

An idea discovered during implementation receives its own Issue before it
changes admitted scope. Native dependencies record necessary sequencing;
Issue references record non-blocking lineage.

When GitHub is unavailable, agents continue only an already activated local
handoff. They never infer, create, transition, or close remote work offline.

## Review Evidence

Every accepted review comment records:

- phase and reviewer capability;
- exact Issue-body digest for Admission;
- plan comment ID and digest for Finalreview;
- full candidate revision and reviewed scope for Finalreview;
- verdict, findings, checks, and every required dimension score.

One reviewer satisfies one capability per gate. Finalreviews bind the same
candidate revision. Acceptance requires no finding and 10.0 in every required
dimension.

Accepted comments are contractually append-only. Editing invalidates the
evidence; corrections use a new comment. A failed Finalreview returns the
Issue to implementation without creating a workaround or automatic review
loop.

## Scheduling And Closure

Project statuses are:

`Backlog | Ready | In progress | Paused | In review | Done`

`Backlog` records a sufficiently understandable idea, problem, and rough target.
It requires neither complete benefit evaluation nor design, Admission, or
implementation authorization.

`Ready` is the implementation-readiness gate. Benefit, scope, risks,
dependencies, and acceptance criteria must be viable. A Framework change also
requires complete Strategy and formalization Admission; Maintenance requires
only risk-proportionate readiness.

Issue open/closed state is authoritative. Project `Done` follows Issue closure.
Rejected work is closed as not planned.

Implementation and finding corrections accumulate into one coherent review
candidate. Reviewer capabilities follow actual impact; small
semantics-preserving changes do not automatically require every specialist.

After acceptance:

1. add one concise `CHANGELOG.md` entry when release-relevant;
2. commit the coherent implementation and its verification;
3. close the Issue and set Project status `Done`.

Git and the Issue retain history. No local change archive is created.

## Verification

Repository verification remains deterministic and network-independent:

```sh
./utl/verify.sh governance
```

It checks the local execution, intake, and migration contracts, never live
GitHub state. Remote reconciliation is an explicit migration or release
operation.

The retained `.ai4X/governance/changes.json`, change directories, legacy
validator, and legacy tests are immutable migration evidence. They are not
active work-state authorities and are not part of current governance
verification. Their deletion requires a separate, explicitly approved cleanup
after the cutover revision is available on `trunk`.
