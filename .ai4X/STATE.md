# Handoff

- Observed: 2026-07-28 CEST
- Work status: `ACTIVE`
- Execution authorization: `APPROVED`
- Authorization scope: review and close `o2i-0004`; do not edit the ArchiMate
  model directly or push.
- Current gate: `o2i-0004-finalreview-5`
- Gate status: `REJECTED`
- Current node: `o2i:situation-anchor-review-correction`

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

- Exact revision `546d43dac71b8c0b8f324fa7b8fa2fb1cc3f0136` passes one
  uninterrupted clean `./utl/verify.sh all`.
- The revision includes 297 public Core tests, four private trace-search work
  regressions, 146 AMX tests, 65 CLI tests, complete Haddock and HIndent, model
  hygiene and View checks, 11 publication-binding tests, and an isolated
  65-page White Paper build.
- The generated profile inventory uses two semantically bounded relation
  tables and keeps each heading with its table without a fixed page break.
- Strategy, formalization, and publication Finalreviews accept the revision
  without findings and with 10.0 in every dimension.
- The independent Haskell Finalreview rejects the revision: fully
  Measure-compatible but later-incomplete Strategy/Situation branches still
  form a quadratic product under constant output.
- The correction completes each primitive spine before the Situation join.
  Its strengthened `0, 10, 20, 40` regression preserves one identical trace
  and proves linear traversal work; focused public and private Core tests pass.

# Gate

- Attempt: `o2i-0004-finalreview-5`
- Subject: revision `546d43dac71b8c0b8f324fa7b8fa2fb1cc3f0136` and the
  implementation scope declared by
  `.ai4X/governance/changes/o2i-0004/plan.md`.
- Mandatory checks: strategy, formalization, Haskell, publication, profile,
  AMX, View, and repository verification.
- Finding status: `OPEN`
- Result: `REJECTED`

# Next Action

Run canonical verification, commit one coherent candidate, and repeat four
capability-distinct exact-revision Finalreviews.

# Local Return Point

After the accepted `o2i-0004` gate, rename the repository-governance entry
point to `.ai4X/governance/CONTRACT.md`. Then audit `o2i-0003` against the
accepted revision, close already satisfied scope, and stop before substantive
profile-contract implementation for user review.
