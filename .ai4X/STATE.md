# Purpose

Volatile O2I handoff state. Repository facts and the latest user instruction
override this snapshot.

# Snapshot

- Observed at: 2026-07-19 CEST.
- Mode: `FINAL_REVIEW`.
- Branch/upstream: `trunk` / `origin/trunk`; inspect Git for the current delta.
- Active objective: independently review the implemented generic O2I model
  inspection, AMX adapter, and CLI before returning to the DB Fv orientation
  instance.
- The user controls every push.

# Approved Baseline

- O2I v0.2 WIP is a generic framework independent of concrete instances.
- Context macrorelations require evidence through relations between
  contextualized Primitives.
- Validation pipeline:
  `RawGraph -> WellFormedGraph -> SemanticallyValidModel -> TraceableEffectModel -> EvidenceReadyModel -> EvidenceAssessedModel`.
- Every Situation has a constituting anchor, every Need is globally situated,
  and every Strategy has exactly one complete coherent formulation.
- Need qualification is pre-intervention; evidence readiness is a later gate.
- Effect and target attainment are independent. O2I supports plausible
  attribution, not causal proof.
- O2I ArchiMate ownership is persisted exclusively through
  `composition[contains]`; visual nesting carries no ownership semantics.
- Native AMX `version="5.0.0"` and O2I profile `o2i.profile="0.2"` are distinct.
- `O2I Context`, `O2I Primitives`, and `O2I Situation` are normative semantic
  views; `O2I Syntax` is their concrete ArchiMate realization.
- The semantic Layered Cake remains outside concrete-syntax inspection until
  its explicit backlog conversion.

# Active Architecture Gate

- The package DAG is `o2i-inspection -> o2i-core`,
  `o2i-amx -> o2i-inspection + o2i-core`, and
  `o2i-cli -> o2i-inspection + o2i-amx`.
- The CLI is a thin `optparse-applicative` composition root; reusable model
  inspection stays in libraries.
- `pln.md` is the frozen architecture contract. Six independent read-only
  reviews culminated in three findings closed with the external co-author:
  adapter-owned profile types remain existential until normalization, Decode
  distinguishes unavailable from rejected native bindings, and internal
  structure elaboration failures are not model findings.
- No further pre-implementation architecture review is required. Implement
  against the frozen contract, run every deterministic check, then review the
  resulting code and artifacts independently.
- Supplemental inputs never influence View scope. Semantic witnesses bind one
  exact structurally closed graph and its unchanged supplied inputs.
- Decode, ViewScope, Profile, Structure, Semantics, Traceability, Readiness, and
  Evidence have disjoint responsibilities and explicit report states.

# Current Worktree

- The O2I model uses the direct root property `o2i.profile=0.2`.
- The extractor enforces that profile, rejects the legacy `version=0.2`
  property, and has 28 passing contract tests.
- The format-neutral Inspection library, native AMX adapter, and thin CLI are
  implemented with opaque staged artifacts, exact View selection, source
  provenance, stable diagnostics, and deterministic human or JSON reports.
- All four packages pass `cabal check`; all eight Cabal test suites pass under
  `-Werror`; all 85 Haskell files pass HIndent validation; Haddock, package
  licenses, extractor snapshots, 28 extractor tests, Pandoc expansion, PDF
  rendering, CLI help/version smoke tests, and `git diff --check` pass.
- Every implementation-review finding is closed in the worktree. The resulting
  implementation still requires one separate read-only final review.

# Next Work

1. Create a local technical checkpoint commit; never push without explicit
   request.
2. Run one independent read-only review with explicit per-dimension scores;
   close every finding in small coherent batches and repeat the review.
3. Present the final eight-Context minimum-contract matrix to the user and
   create the reviewed local O2I commit.
4. Resume DB Fv at `Entbürokratisierte Freiräume :: O2I Principle`, complete
   Ethos/Mission/Vision, then continue the interrupted `wtf.md` review at Vision
   and the top-down `o2i.md` review.

# Release Note Draft

- `CHANGELOG.md` section `[0.2] - Unreleased` remains the canonical draft.
- Backlog: add the OMX adapter and convert Layered Cake to concrete syntax.
