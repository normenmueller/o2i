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
- The typed contract projection belongs in the dedicated
  `o2i-archimate-profile` package so its JSON equality test remains valid in an
  independent Cabal source archive. `o2i-amx` consumes that package and owns
  only adapter execution.
- The self-contained profile package is implemented. Its opaque public facade
  exposes contract observations without constructors, and its packaged JSON
  equality test prevents drift from the declarative authority.
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
- Contract parser and renderer tests: 19 passed.
- Full Haskell tests with `-Werror`: Core 292, Inspection 48, profile contract
  1, AMX 146 plus API, and CLI 65 plus API passed.
- Profile package and AMX source archives are self-contained; Cabal check,
  HIndent, Haddock, license equality, governance validation, and diff integrity
  passed.

# Gate

- Attempt: `o2i-0003-implementation`
- Subject: implementation scope declared by
  `.ai4X/governance/changes/o2i-0003/plan.md`.
- Mandatory checks: contract, renderer, View, Haskell registry, publication,
  and repository verification.
- Finding status: `CLOSED`
- Result: `PENDING`

# Next Action

Replace duplicated Python mapping registries with contract-based repository
View checks. Python remains repository-development tooling; it does not
validate O2I instances.

# Local Return Point

After the accepted `o2i-0003` Finalreview, resume `o2i-0002`: reconcile and
reduce View documentation, move the focused-View boundary paragraph behind the
signature contract, rebuild `O2I Syntax - Primitives` as an
identity-preserving excerpt, and continue the Situation mapping. Preserve all
current user model edits.
