# Handoff

- Observed: 2026-07-27 CEST
- Work status: `ACTIVE`
- Execution authorization: `APPROVED`
- Authorization scope: correct and review `o2i-0004`; do not edit the
  ArchiMate model directly or push.
- Current gate: `o2i-0004-finalreview-2`
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

- Exact revision `a149d9b793e91353be085f956ecae306e8243ef1` passed
  `./utl/verify.sh all`.
- Three independent Finalreviews rejected that revision.
- Macro-Claim and qualification boundaries, complete relation-family
  regressions, and both Situation View layouts are closed in the working tree.
- The Situation Anchoring View now isolates one shared operational subject
  across `Driver @ Need`, `Action @ Intervention`, and `KPI @ Measure`; its
  review snapshot preserves those view-specific labels.
- PDF freshness and generated profile-table corrections are implemented and
  await the canonical publication render and complete verification.
- A tooling co-author added table-driven missing- and duplicate-family
  regressions for all nine relation-mapping families; all 29 focused Extractor
  tests pass.
- No Haskell Core design finding is open.

# Gate

- Attempt: `o2i-0004-finalreview-2`
- Subject: revision `a149d9b793e91353be085f956ecae306e8243ef1` and the
  implementation scope declared by
  `.ai4X/governance/changes/o2i-0004/plan.md`.
- Mandatory checks: strategy, formalization, Haskell, publication, profile,
  AMX, View, and repository verification.
- Finding status: `OPEN`
- Result: `REJECTED`

# Next Action

Render every dependent publication artifact, run exact full verification, and
repeat independent Finalreview for one coherent revision until every required
dimension is 10.0 without findings.

# Local Return Point

After the accepted `o2i-0004` gate, rename the repository-governance entry
point to `.ai4X/governance/CONTRACT.md`. Then audit `o2i-0003` against the
accepted revision, close already satisfied scope, and execute only demonstrated
residual work.
