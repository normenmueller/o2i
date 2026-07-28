# Handoff

- Observed: 2026-07-28 CEST
- Work status: `ACTIVE`
- Execution authorization: `APPROVED`
- Authorization scope: review and close `o2i-0004`; do not edit the ArchiMate
  model directly or push. This includes the approved removal of premature
  build-revision provenance before the final review candidate.
- Current gate: `o2i-0004-finalreview-8`
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
  `859c29de725e7150bc58f59ef15fe8ae8bcc485f` passes one uninterrupted
  `./utl/verify.sh all`.
- The current correction derives complete Situation-attached `TraceCore`
  values before Vision expansion and intersects convergent Intervention Key
  Results through contribution, substantiation, and Measure-target indices.
- Adversarial Vision and convergent-Key-Result contracts produce
  `1, 11, 21, 41` complete traces for fan-out `0, 10, 20, 40`, preserve exact
  identities and input-order determinism, and prove affine traversal work.
- Focused verification passes 297 public Core tests, 13 private trace-search
  tests, the public API contract, Werror, HIndent, and diff checks.
- One uninterrupted `./utl/verify.sh all` passes the complete correction
  worktree, including governance, model, all Haskell packages, API contracts,
  Haddock, HIndent, and the isolated White Paper build with `md2pdf 0.2.4`.

# Gate

- Attempt: `o2i-0004-finalreview-8`
- Subject: revision `859c29de725e7150bc58f59ef15fe8ae8bcc485f` and the
  implementation scope declared by
  `.ai4X/governance/changes/o2i-0004/plan.md`.
- Mandatory checks: strategy, formalization, Haskell, publication, profile,
  AMX, View, and repository verification.
- Finding status: `OPEN`
- Result: `REJECTED`

# Next Action

Run complete repository verification, commit one coherent candidate, and
verify its exact clean revision. Carry strategy and publication evidence
forward only across byte-identical scopes; obtain complete new formalization
and Haskell reviews.

# Local Return Point

After the accepted `o2i-0004` gate, stop and consult the user before
`workspace:issue-coordination`. After renewed approval, establish the GitHub
Issue/Fork-/Return coordination model, finalize the repository-governance entry
point, audit `o2i-0003` against the accepted revision, close already satisfied
scope, and stop before substantive profile-contract implementation.
