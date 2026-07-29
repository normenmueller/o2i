# Handoff

- Observed: 2026-07-29 CEST
- Work status: `ACTIVE`
- Execution authorization: `APPROVED`
- Authorization scope: review and close `o2i-0004`; do not edit the ArchiMate
  model directly or push. This includes the approved removal of premature
  build-revision provenance before the final review candidate.
- Current gate: `o2i-0004-finalreview-11`
- Gate status: `REJECTED`
- Current node: `o2i:situation-anchor-gate`

# Objective

Establish one lean closed Situation-anchor set whose constructors all satisfy
the complete anchor relation family before finalizing the ArchiMate profile.

# Repository Facts

- `o2i-0003` is paused because its profile contract depends directly on
  `o2i-0004`.
- The closed anchor set is `BusinessCapability | BusinessProcess |
  BusinessObject | ValueStream`; every constructor supports
  `is-constituted-by`, `anchors`, `changes`, and `measures`.
- `BusinessRole` and `RegulatoryConstraint` remain ordinary Enterprise
  Architecture artifacts outside the Situation-anchor type.
- The exact ArchiMate profile authority is
  `spc/ctr/archimate/profile.json`; Haskell and the generated White Paper
  inventory project it.
- The versioned White Paper is bound to its exact publication sources and
  compared structurally and textually with an isolated fresh build.
- The user controls ArchiMate edits and pushes.

# Verification

- Exact clean revision
  `0f9bce63645adc9ca2628a17213b154d3e9bd0a0` passes one uninterrupted
  `./utl/verify.sh all`; its Haskell Finalreview rejects the former
  list-bind TraceSearch and macro-evidence architecture.
- Independent design reviews accept one private typed relational mechanism,
  constructive prefix-connected plans, total typed projections, and one
  immutable `PreparedMacroEvidence` prepared before Collective assessment.
- The generative executor boundary, closed fourteen-relation vocabulary, and
  typed domain cache are independently accepted at 10.0 throughout.
- Occurrence-aware witnesses, ordered collision-safe canonicalization, and
  operation-bound work pass 71 focused contracts, every Core suite, HIndent,
  and compile/import contracts. Their renewed independent Haskell review
  reports no finding and 10.0 in every dimension.
- The strategy and publication scopes are byte-identical to their accepted
  scopes at `859c29de725e7150bc58f59ef15fe8ae8bcc485f`; only formalization and
  Haskell require new Finalreviews.

# Gate

- Attempt: `o2i-0004-finalreview-11`
- Subject: revision `0f9bce63645adc9ca2628a17213b154d3e9bd0a0` and the
  implementation scope declared by
  `.ai4X/governance/changes/o2i-0004/plan.md`.
- Mandatory checks: strategy, formalization, Haskell, publication, profile,
  AMX, View, and repository verification.
- Finding status: `OPEN`
- Result: `REJECTED`

# Next Action

Complete the bounded independent Haskell review of
`O2I.Validation.MacroEvidence.{Types,Prepare,Eval}`. The old Trace-owned path is
absent, and Semantics prepares one immutable value for Collective assessment
and accepted-model Trace reuse. Focused and complete Core verification,
compile/import contracts, HIndent, and Cabal check pass. After acceptance,
implement the typed effect-trace rules over the same private relational
mechanism.

# Local Return Point

After the accepted `o2i-0004` gate, stop and consult the user before
`workspace:issue-coordination`. After renewed approval, establish the GitHub
Issue/Fork-/Return coordination model, finalize the repository-governance entry
point, audit `o2i-0003` against the accepted revision, close already satisfied
scope, and stop before substantive profile-contract implementation.
