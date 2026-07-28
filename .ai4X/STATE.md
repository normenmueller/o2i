# Handoff

- Observed: 2026-07-28 CEST
- Work status: `ACTIVE`
- Execution authorization: `APPROVED`
- Authorization scope: review and close `o2i-0004`; do not edit the ArchiMate
  model directly or push.
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

- Exact revision `287909f0ad6158c818bdadb4e21b05520f0fac83` passes one
  uninterrupted clean `./utl/verify.sh all`.
- The revision includes 297 public Core tests, six private trace-search work
  regressions, 146 AMX tests, 65 CLI tests, complete Haddock and HIndent, model
  hygiene and View checks, 17 publication-binding tests, and an isolated
  65-page White Paper build.
- The generated profile inventory uses two semantically bounded relation
  tables and keeps each heading with its table without a fixed page break.
- The correction completes each primitive spine before the Situation join.
  Its strengthened `0, 10, 20, 40` regression preserves one identical trace
  and proves linear traversal work.
- The correction builds one Situation-to-anchor index per
  `(Intervention, Need, Measure)` before Strategy enumeration. Three
  adversarial families prove affine-linear work.
- One renderer contract now governs local version verification, immutable CI
  acquisition, and manifest v2. The regenerated PDF remains 65 pages.
- Strategy, formalization, and publication Finalreviews accept exact revision
  `287909f0ad6158c818bdadb4e21b05520f0fac83` without findings and with 10.0
  in every dimension.
- The pure Haskell Finalreview rejects one target-Measure fan-out: each target
  Measure repeats pair-wide Situation and Strategy scans, producing quadratic
  work under linear Measure fan-out.
- The dirty correction replaces every broad repeated intersection with one
  relation-driven candidate set and constant membership guards. Eleven
  private regressions cover target Measure/Situation, addressed Need/Measure,
  Strategy Action, Need Objective, and Anchor fan-out.
- The private test contract is split into a small runner, contracts, shared
  fixtures, and scenario builders. Canonical `./utl/verify.sh haskell` passes.
- One uninterrupted `./utl/verify.sh all` passes the complete dirty
  correction worktree, including the isolated 65-page White Paper build with
  `md2pdf 0.2.4`.

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

Commit one coherent correction, verify that exact clean revision, and repeat
the four capability-distinct Finalreviews required by the current gate
contract.

# Local Return Point

After the accepted `o2i-0004` gate, establish the approved GitHub
Issue/Fork-/Return coordination model. Then finalize the repository-governance
entry point, audit `o2i-0003` against the accepted revision, close already
satisfied scope, and stop before substantive profile-contract implementation
for user review.
