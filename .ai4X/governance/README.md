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

A proposal may be corrected while it remains `proposed`; its Admission reviews
must then be renewed for the new digest. From `admitted` onward, proposal and
Admission reviews remain fixed. Changing an implementation after Finalreview
requires another Finalreview of the new revision.

A register entry omits `plan` before an implementation plan exists and contains
the repository-relative `plan.md` path from `implementing` onward. Empty
strings, `null`, and sentinel values are invalid.

## Lifecycle

```text
proposed     -> admitted | rejected | withdrawn
admitted     -> implementing | withdrawn
implementing -> reviewing | withdrawn
reviewing    -> implementing | done | withdrawn
```

`done`, `rejected`, and `withdrawn` are terminal. A failed Finalreview returns
the change to `implementing`; it does not create a workaround or an automatic
review loop. Every new change starts in `proposed`.

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

Implementation edits and finding corrections are accumulated into one coherent
review candidate. Independent Finalreviews assess that candidate, not each
individual edit. Required reviewer capabilities follow the admitted plan and
therefore remain proportionate to the change.

All required reviews for `done` refer to the same revision and declare their
reviewed scope. The scope excludes runtime handoff, the mutable register, and
Finalreview evidence. Accepted reviews remain durable evidence for their exact
revision; later changes require their own review without invalidating earlier
acceptance. Acceptance requires no finding and 10.0 in every reported
dimension. Git carries implementation history; the governance validator checks
the current register and its referenced evidence rather than reconstructing a
workflow from commits.

## Tool

The validator uses only the Python 3.9 standard library and is deterministic:

```sh
python3 utl/change-governance.py validate
python3 utl/change-governance.py backlog
python3 utl/change-governance.py graph
```

The validator checks current records, dependencies, and evidence. With Git
metadata it also checks referenced revisions; without Git it retains structural
validation. Historical process discipline remains visible in Git and is judged
by the declared reviewers.
