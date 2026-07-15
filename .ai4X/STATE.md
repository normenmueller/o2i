# Purpose

Volatile handoff state for O2I. Observed repository facts and the latest user
instruction override this snapshot.

# Snapshot

- Observed at: 2026-07-15 CEST.
- Mode: `READY`.
- Branch/upstream: `trunk` / `origin/trunk`.
- Active objective: commit the remediated review state, repeat the independent
  final review, and close the gate at 10/10.
- Agent memory: active in the current repository revision.

# Approved Baseline

- Article: O2I v0.2 WIP, title `Von Orientierung zur Wirkung`.
- Core thesis: context macrorelations require evidence through relations
  between contextualized Primitives.
- Validation pipeline:
  `RawGraph -> WellFormedGraph -> SemanticallyValidModel -> TraceableEffectModel -> EvidenceReadyModel -> EvidenceAssessedModel`.
- Every Need is globally situated; every Strategy has exactly one complete,
  coherent formulation.
- Only assigned Strategy Primitives may substantiate Strategy traces or macro
  evidence.
- Effect and target attainment are independent; O2I supports plausible
  attribution, not causal proof.
- Need qualification remains an independent pre-intervention query; it does not
  require Intervention or Measure.
- SFE, strategic topic complexes, scoring, statuses, and
  PerformanceDimension-bound fit are external applications, not O2I core
  semantics.
- The Layered Cake remains semantic and is not yet converted to concrete
  ArchiMate syntax.

# Active Quality Gate

- The independent final review rejected the preceding state because of an
  ArchiMate 4 mismatch, incomplete concrete syntax, forgeable public typed
  references, stale ArchiMate documentation, missing automated model checks,
  and one undirected syntax association.
- Every accepted finding is closed in the working tree. The WIP status remains
  intentional for O2I v0.2.
- ArchiMate 4 mappings use `Capability`, `Process`, `Business Object`, `Role`,
  `Value Stream`, and `Requirement` with explicit O2I specializations.
- `O2I Syntax` defines Context containment, `Primitive @ Context`,
  PerformanceDimension syntax, and Situation Anchor mappings without redundant
  example instances or expanded 24-edge anchor syntax.
- The independent reviewer explicitly approved this lean syntax split after
  reassessment; the current PNG is synchronized.
- ArchiMate element, relation, and view documentation is synchronized with the
  article and Haskell specification.
- Public typed Haskell references are opaque, nominally typed, and obtained
  through validated lookup or model queries.
- Deterministic review snapshots include view contracts, visible notes, and
  directed Association semantics. `--check` validates model contracts and
  snapshot drift.

# Current Verification

- `python3 -B utl/extract-archimate-view.py --preset all --check`: passed.
- `cabal check`: passed.
- `cabal build all --ghc-options=-Werror`: passed.
- `cabal test all --test-show-details=direct`: 158 tests passed.
- HIndent 80 validation: passed.
- Haddock including internal modules: passed.
- Pandoc include expansion: passed.
- `./toPDF.sh`: passed.
- `git diff --check`: passed.

# Next Work

- Commit and push the coherent remediation checkpoint.
- Run a fresh independent final review across terminology, metamodel,
  ArchiMate, Haskell design, tests, formal value, and publication quality.
- Close any verified findings and repeat the gate until explicit 10/10 approval.
- Then review `o2i.md` top-down and paragraph by paragraph, explaining every
  substantive difference, extension, refinement, and formal consequence.
- Backlog: convert the Layered Cake to concrete ArchiMate syntax.
