# Handoff

- Observed: 2026-07-27 CEST
- Work status: `ACTIVE`
- Execution authorization: `APPROVED`
- Authorization scope: implement the admitted `o2i-0003` authority correction;
  do not edit the ArchiMate model directly or push.
- Current gate: `o2i-0003-implementation`
- Gate status: `PENDING`
- Current node: `o2i:profile-contract-implementation`

# Objective

Establish one declarative, machine-checkable authority for exact ArchiMate
profile mappings while retaining the White Paper as the normative fachliche
publication.

# Repository Facts

- Change `o2i-0002` is admitted and its manual syntax synchronization is paused
  at the documented Primitive mapping return point.
- `O2I Syntax` contains verified Context, Primitive, Performance Dimension,
  and generic Primitive relationship mappings.
- The complete 22-entry Primitive and structuring signature table is present
  in View documentation and verified against the current Haskell and AMX
  registries.
- Existing View documentation remains intact until every statement is
  classified and unique fachliche content has moved into the White Paper.
- The authority audit is recorded in
  `.ai4X/governance/changes/o2i-0003/authority-audit.md`.
- The strict declarative contract contains 14 carrier mappings, 60 relation
  mappings, and two structured patterns. Its deterministic readable projection
  is current.
- Change `o2i-0003` proposes `spc/contract/archimate-profile.json` as the exact
  concrete-mapping authority. The White Paper includes a generated readable
  projection; the reference model visualizes it; Haskell and repository checks
  verify it.
- Proposal SHA-256:
  `bddcab3a49da2f2c435cf095a4f175b2c38903e5dddf402b6c560f126e18b919`.
- Both independent Admission reviews accepted the exact proposal without
  findings and with 10.0 in every reported dimension.
- The extractor preset still expects the former View name
  `O2I Syntax - Context`; broad snapshot verification remains intentionally red
  until syntax synchronization resumes.
- The user controls pushes.

# Verification

- `python3 utl/change-governance.py validate`: passed after Admission and
  implementation-plan registration.

# Gate

- Attempt: `o2i-0003-implementation`
- Subject: implementation scope declared by
  `.ai4X/governance/changes/o2i-0003/plan.md`.
- Mandatory checks: contract, renderer, View, Haskell registry, publication,
  and repository verification.
- Finding status: `CLOSED`
- Result: `PENDING`

# Next Action

Add a complete Haskell AMX-registry equality test and contract-based repository
View checks with the external formalization/Haskell co-author. Correct context
macrorelations to their admitted directed Association representation.

# Local Return Point

After the accepted `o2i-0003` Finalreview, resume `o2i-0002`: reconcile and
reduce View documentation, move the focused-View boundary paragraph behind the
signature contract, rebuild `O2I Syntax - Primitives` as an
identity-preserving excerpt, and continue the Situation mapping. Preserve all
current user model edits.
