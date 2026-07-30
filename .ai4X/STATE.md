# Handoff

- Observed: 2026-07-30 CEST
- Work status: `ACTIVE`
- Execution authorization: `APPROVED`
- Authorization scope: review and close `o2i-0004`; do not edit the ArchiMate
  model directly or push. This includes the approved removal of premature
  build-revision provenance before the final review candidate.
- Current gate: `o2i-0004-finalreview-12`
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

- Candidate `1a300b389ff04956a527b57defce503c21332f94` passes uninterrupted
  complete verification in the main and an isolated detached worktree.
- Strategy, pure Haskell, and publication Finalreviews accept that revision
  without findings and with 10.0 in every required dimension.
- Formalization rejects it because asserted macrorelation evidence is checked
  at Traceability instead of Semantics and the independent macro Oracle
  truncates multi-member Strategy Action and Key Result domains.
- The corrected semantic-stage validation, complete multi-member Oracle,
  canonical diagnostics, module ownership, and documentation pass one
  uninterrupted `./utl/verify.sh all`.
- Bounded Haskell and formalization reviews accept the complete correction
  without findings and with 10.0 in every required dimension.

# Gate

- Attempt: `o2i-0004-finalreview-12`
- Subject: revision `1a300b389ff04956a527b57defce503c21332f94` and the
  implementation scope declared by
  `.ai4X/governance/changes/o2i-0004/plan.md`.
- Mandatory checks: strategy, formalization, Haskell, publication, profile,
  AMX, View, and repository verification.
- Finding status: `OPEN`
- Result: `REJECTED`

# Next Action

Commit one exact candidate, verify it in isolation, and renew the required
exact-revision Finalreviews.

# Local Return Point

After the accepted `o2i-0004` gate, stop and consult the user before
`workspace:issue-coordination`. After renewed approval, establish the GitHub
Issue/Fork-/Return coordination model, finalize the repository-governance entry
point, audit `o2i-0003` against the accepted revision, close already satisfied
scope, and stop before substantive profile-contract implementation.
