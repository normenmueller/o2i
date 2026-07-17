# Purpose

Volatile handoff state for O2I. Observed repository facts and the latest user
instruction override this snapshot.

# Snapshot

- Observed at: 2026-07-17 CEST.
- Mode: `FINAL_REVIEW_PENDING`.
- Branch/upstream: `trunk` / `origin/trunk`.
- Active objective: close the independent review gate for the new formal
  Need-qualification proposal validation.
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

- The current dirty scope adds `validateNeedQualificationProposal` as a formal
  pre-persistence check over an existing Strategy and fully situated Need.
- Validation returns either accumulated formal errors or an opaque
  `NeedQualificationCandidate`; authorized subject-matter acceptance remains
  separate and precedes persistence, model revalidation, and
  `qualifyingStrategies` confirmation.
- Agentic AI may support proposal analysis but remains optional.
- A metamodel/type-theory/Haskell co-author participated in design,
  implementation, modularization, Haddock, and tests. Independent final review
  of the resulting commit remains pending.

- The independent final review of substantive commit `a87f333` on 2026-07-15
  reported no Blocker, High, Medium, or Low finding and explicit approval.
- Fachlichkeit, Metamodell, Typtheorie, Haskell, tests, formal value, and
  publication quality each received 10.0.
- A positive external API contract enforces complete `reifyRelation`
  round-tripping.
- The external API suite now binds relation registry, lookup, reification,
  opacity, construction failure, and pattern-matching failure.
- The WIP status remains intentional for O2I v0.2.
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
  through validated lookup or model queries. Ordinary projection functions do
  not permit record updates.
- Each traced KPI has exactly one validated stable definition. Units and value
  domains are centralized; measurement levels and absolute deltas are distinct
  types.
- Deterministic review snapshots include view contracts, visible notes, and
  directed Association semantics. `--check` validates exact normative relation
  contracts, DiagramConnection-to-Relationship endpoint identity, sole root
  version `0.2`, model invariants, and snapshot drift.
- Canonical interpretation and relation metadata and every validated stage,
  trace, KPI definition, and assessment are opaque and expose only ordinary
  projection functions.
- External API contracts combine Template Haskell surface checks, positive
  full-pipeline use, and compile-fail constructor and record-update tests across
  all public facades.

# Current Verification

- ArchiMate model check and nine extractor contract tests: passed.
- `cabal check` and `cabal build all --ghc-options=-Werror`: passed.
- Both Cabal test suites passed: 186 fachliche tests plus positive, Template
  Haskell, and compile-fail public-API contracts.
- HIndent 80 validation: passed.
- Haddock including internal and API-test modules: 100% coverage.
- Pandoc include expansion and `./toPDF.sh`: passed.
- `git diff --check`: passed.

# Release Note Draft

- `CHANGELOG.md` section `[0.2] - Unreleased` is the canonical v0.2 release-note
  draft.

# Next Work

- The user controls pushing the reviewed local commits.
- Then review `o2i.md` top-down and paragraph by paragraph, explaining every
  substantive difference, extension, refinement, and formal consequence.
- Backlog: convert the Layered Cake to concrete ArchiMate syntax.
