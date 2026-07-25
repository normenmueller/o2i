# O2I Change Governance

O2I uses a lean, agentic-first rule for Framework changes: think before
writing. A proposed change is implemented only after its generic problem,
benefit, fit, and consequences are explicit and independently accepted.

The process governs O2I development. It does not define O2I fachliche
semantics.

## Applicability

A proposal is required when a change affects O2I terminology, metamodel
semantics, normative syntax, formalization, validation behavior, or a public
API contract.

Editorial work, generated artifacts, and demonstrably semantics-preserving
refactoring do not require a proposal. Their classification must be stated in
the commit or review context. If the classification is uncertain, use a
proposal.

## Authority

- `.ai4X/governance/changes.json` is the single change register and dependency
  authority.
- `.ai4X/governance/changes/o2i-NNNN/proposal.md` explains the generic problem
  and benefit.
- `.ai4X/governance/changes/o2i-NNNN/plan.md` defines admitted implementation
  scope and required Finalreview capabilities.
- `.ai4X/governance/changes/o2i-NNNN/reviews/` contains digest- or
  revision-bound independent reviews.
- `.ai4X/STATE.md` is runtime handoff only, never change-state or dependency
  authority.
- Backlog and Mermaid output are generated projections, never additional
  authorities.

Proposal and plan files remain immutable while their bound reviews are used.
Changing a reviewed proposal requires a new proposal. Changing an implementation
after Finalreview requires another Finalreview of the new revision.

## Lifecycle

```text
proposed     -> admitted | rejected | withdrawn
admitted     -> implementing | withdrawn
implementing -> reviewing | withdrawn
reviewing    -> implementing | done | withdrawn
```

`done`, `rejected`, and `withdrawn` are terminal. A failed Finalreview returns
the change to `implementing`; it does not create a workaround or an automatic
review loop.

The initial `o2i-0001` register bootstrap is the only change allowed to start
in `implementing`. Every later change starts in `proposed`.

## Admission

An Admission proposal stays short and answers:

1. What generic O2I problem exists?
2. Who benefits, and how?
3. Why do existing O2I concepts not solve it?
4. Why does the change belong in generic O2I?
5. What alternatives, non-goals, risks, and dependencies exist?

Admission requires two accepted reviews of the exact proposal SHA-256:
`strategy` and `formalization`. The author, co-authors, and both reviewers are
pairwise distinct.

The implementation plan is written after Admission. A co-author may implement
the admitted design but cannot provide its independent Admission or
Finalreview.

## Forks And Dependencies

An idea discovered during implementation becomes a separate proposal before
it changes O2I.

- `derived_from` records non-blocking lineage.
- `depends_on` records a direct, necessary implementation dependency.

Both relations form separate directed acyclic graphs. A change cannot become
`done` while a direct dependency remains open.

## Finalreview

The implementation plan declares the required Finalreview capabilities.
Each accepted Finalreview identifies one exact Git revision. A reviewer is
distinct from the change author and co-authors.

All required reviews for `done` refer to the same revision. The transition
from `reviewing` to `done` checks that committed history between this revision
and the attestation commit changes only the referenced Finalreview files and
`.ai4X/governance/changes.json`. Unrelated worktree changes are outside this
one-time closure check; later repository work does not reopen a completed
change.

## Tool

The validator uses only the Python 3.9 standard library and is deterministic:

```sh
python3 utl/change-governance.py validate
python3 utl/change-governance.py validate --base <git-revision>
python3 utl/change-governance.py backlog
python3 utl/change-governance.py graph
```

`--base` additionally checks state transitions and newly registered changes
against an earlier repository revision. The validator checks records and
evidence; expert judgment remains with the declared reviewers.
