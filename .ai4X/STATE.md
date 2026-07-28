# Handoff

- Observed: 2026-07-28 CEST
- Work status: `ACTIVE`
- Execution authorization: `APPROVED`
- Authorization scope: review and close `o2i-0004`; do not edit the ArchiMate
  model directly or push. This includes the approved removal of premature
  build-revision provenance before the final review candidate.
- Current gate: `o2i-0004-finalreview-7`
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

- Exact committed revision
  `58073d8500747ce31314f179e700ff14aed2cfd7` passes one uninterrupted clean
  `./utl/verify.sh all`; its pure Haskell review identified the remaining
  target-Measure fan-out.
- The correction replaces broad repeated intersections with relation-driven
  candidate sets and constant membership guards. Eleven private regressions
  cover every material fan-out axis, preserve deterministic traces, and prove
  affine-linear work.
- Private trace-search tests are split into contracts, shared fixtures, and
  scenario builders without changing the public API.
- Build-revision provenance has no current product consumer beyond the CLI
  option itself. O2I does not distribute binaries or bind inspection reports
  normatively to an executable revision, so the package and CLI surface are
  removed before Finalreview.
- One uninterrupted `./utl/verify.sh all` passes the simplified worktree,
  including governance, model, 297 Core tests, 11 private trace-search tests,
  146 AMX tests, 63 CLI tests, API contracts, Haddock, HIndent, publication,
  and the isolated 65-page White Paper build with `md2pdf 0.2.4`.

# Gate

- Attempt: `o2i-0004-finalreview-7`
- Subject: revision `287909f0ad6158c818bdadb4e21b05520f0fac83` and the
  implementation scope declared by
  `.ai4X/governance/changes/o2i-0004/plan.md`.
- Mandatory checks: strategy, formalization, Haskell, publication, profile,
  AMX, View, and repository verification.
- Finding status: `OPEN`
- Result: `REJECTED`

# Next Action

Run complete repository verification, commit and verify the exact clean
revision, and repeat the four capability-distinct Finalreviews required by the
current gate contract.

# Local Return Point

After the accepted `o2i-0004` gate, establish the approved GitHub
Issue/Fork-/Return coordination model. Then finalize the repository-governance
entry point, audit `o2i-0003` against the accepted revision, close already
satisfied scope, and stop before substantive profile-contract implementation
for user review.
