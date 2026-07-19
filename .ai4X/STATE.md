# Purpose

Volatile O2I handoff state. Repository facts and the latest user instruction
override this snapshot.

# Snapshot

- Observed at: 2026-07-19 CEST.
- Mode: `READY`.
- Branch/upstream: `trunk` / `origin/trunk`; inspect Git for the current delta.
- Active objective: return to the DB Fv orientation instance.
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

# Architecture Baseline

- The package DAG is `o2i-inspection -> o2i-core`,
  `o2i-amx -> o2i-inspection + o2i-core`, and
  `o2i-cli -> o2i-inspection + o2i-amx`.
- The CLI is a thin `optparse-applicative` composition root; reusable model
  inspection stays in libraries.
- `pln.md` records the implemented architecture contract and its verification.
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
- Every public Provenance projection is non-updateable, occurrence identities
  use framed structured encoding, and source locations are bound to the exact
  inspected document. Every scope-resolved report contains canonical,
  auditable closed-scope provenance.
- Diagnostics are normalized once and every nested reference derives from the
  same canonical set. Human output centrally escapes untrusted terminal control
  characters; JSON remains unchanged.
- The last complete matrix passed all four package-local `cabal check` runs,
  the all-package `-Werror` build, all eight test suites, 100% Haddock coverage,
  package-license checks, HIndent, extractor snapshots and tests, Pandoc, PDF
  rendering, CLI smokes, and `git diff --check`.
- The source-capability batch is closed and externally approved: adapters emit
  only opaque source-relative positions, Inspection alone binds them to the
  exact request document, no public binding path remains, and compile-fail plus
  two-source tests cover failure and successful provenance paths. The full
  Haskell verification matrix is green for this batch.
- The AMX resource-budget batch is implemented and co-author checked: exact
  budgets constrain input bytes, XML depth, element nodes, attributes, and
  character data before DOM parsing; a monotonic scanner rejects unsafe XML
  with bounded memory. Boundary, adversarial entity, CDATA, diagnostic, and API
  tests pass (AMX 83 plus API contract).
- The independent final review approved commit `ce7726e` without findings or
  caveats. Fachlichkeit, Metamodell, Typtheorie, Haskell design, AMX adapter and
  robustness, CLI and UX, tests, formal value, and cross-artifact consistency
  each score 10.0/10.0. The complete matrix is green: four package-local Cabal
  checks, all-package `-Werror` build and eight suites, 100% public Haddock,
  HIndent, package licenses, extractor snapshots and 28 tests, Pandoc, PDF,
  file/stdin CLI smokes, and `git diff --check`.
- `spc/Makefile` installs the exact project-local `o2i` executable under
  `$(DESTDIR)$(PREFIX)/bin/o2i` and removes only that path. Temporary-prefix
  installation, version execution, and idempotent uninstallation pass.

# Next Work

1. Resume DB Fv at `Entbürokratisierte Freiräume :: O2I Principle`, complete
   Ethos/Mission/Vision, then continue the interrupted `wtf.md` review at Vision
   and the top-down `o2i.md` review.

# Release Note Draft

- `CHANGELOG.md` section `[0.2] - Unreleased` remains the canonical draft.
- Backlog: add the OMX adapter and convert Layered Cake to concrete syntax.
