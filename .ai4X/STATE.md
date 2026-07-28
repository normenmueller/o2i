# Handoff

- Observed: 2026-07-28 CEST
- Work status: `ACTIVE`
- Execution authorization: `APPROVED`
- Authorization scope: correct and review `o2i-0004`; do not edit the
  ArchiMate model directly or push.
- Current gate: `o2i-0004-finalreview-3`
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
- The reference model contains the complete four-constructor contract and ten
  registered Views. Whole-model hygiene and generated snapshots are current.
- The exact ArchiMate profile authority is
  `spc/ctr/archimate/profile.json`; Haskell and the generated White Paper
  inventory project it.
- The user controls ArchiMate edits and pushes.

# Verification

- Exact revision `65b6c8549fcf84a7fb139adb0dfe0cd7301a3f85` passes
  `./utl/verify.sh all`.
- The independent strategy Finalreview accepts that revision with 10.0 in
  every dimension and no finding.
- The formalization and publication Finalreviews reject it with four open
  correction subjects: output-sensitive effect-trace derivation, deterministic
  visual PDF freshness, current syntax-View routing in Agent Memory, and
  balanced generated-profile pagination.
- Every earlier semantic, profile, View, and relation-family finding remains
  closed.
- One coherent correction candidate replaces Cartesian trace enumeration with
  an indexed reachable traversal, compares deterministic page rasters, routes
  Agent Memory to the current syntax Views, and balances the generated profile
  inventory.
- `./utl/verify.sh all` passes the complete correction worktree, including 297
  public Core tests, three private trace-search work regressions, complete
  Haddock and HIndent checks, and the isolated White Paper build.

# Gate

- Attempt: `o2i-0004-finalreview-3`
- Subject: revision `65b6c8549fcf84a7fb139adb0dfe0cd7301a3f85` and the
  implementation scope declared by
  `.ai4X/governance/changes/o2i-0004/plan.md`.
- Mandatory checks: strategy, formalization, Haskell, publication, profile,
  AMX, View, and repository verification.
- Finding status: `OPEN`
- Result: `REJECTED`

# Next Action

Commit the coherent correction candidate, verify the exact clean revision, and
repeat independent Finalreview until every required dimension is 10.0 without
findings.

# Local Return Point

After the accepted `o2i-0004` gate, rename the repository-governance entry
point to `.ai4X/governance/CONTRACT.md`. Then audit `o2i-0003` against the
accepted revision, close already satisfied scope, and execute only demonstrated
residual work.
