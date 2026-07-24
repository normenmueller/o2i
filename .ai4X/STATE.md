# Purpose

Volatile O2I handoff state. Repository facts and the latest user instruction
override this snapshot.

# Snapshot

- Observed at: 2026-07-24 CEST.
- Mode: `ACTIVE`.
- Branch/upstream: `trunk` / `origin/trunk`; inspect Git for the current delta.
- Active objective: close the explicit Commitment and proposition-carrier
  contract in Core, Inspection, and the AMX adapter before synchronizing the
  normative ArchiMate syntax Views and publication artifacts.
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
- O2I ArchiMate contextualization is expressed exclusively through
  `composition[contextualizes]`; visual nesting carries no contextualization
  semantics. The Haskell graph represents this assignment through its
  technical owner field.
- Native AMX `version="5.0.0"` and O2I profile `o2i.profile="0.2"` are distinct.
- `O2I Semantics - Context`, `O2I Semantics - Primitives`, and `O2I Semantics -
  Situation` are normative semantic Views. Concrete syntax is separated into
  responsibility-aligned Context, Contextualization, Collective Strategy
  Realization, Primitives, and Situation Views; their Commitment metadata and
  extractor contracts remain to be synchronized.
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

- Current plan node: `o2i:commitment-closure`. The explicit Commitment,
  proposition-carrier, and `StructuredProposition` target contract is approved.
  The external Haskell co-author has completed its implementation package.
  Cabal checks, `-Werror` build, HIndent, Haddock, and all package-local tests
  pass. The independent read-only Haskell/formalization review rejected the
  package with one High finding: collective participant resolution loses
  Candidate commitment information at the `WellFormedGraph` boundary. Package
  2 must preserve a commitment-aware structural node index, retain Candidate
  collectives with resolved Candidate participants, reject Asserted collectives
  through a precise Candidate-dependency defect, and cover the complete
  contributor/target matrix. Exact design, scores, and sequence are in
  `pln.md`. Model and publication synchronization remain deliberately paused
  until this gate closes.
- The model and extractor enforce the direct root property `o2i.profile=0.2`;
  the extractor has 28 passing contract tests.
- The format-neutral Inspection library, native AMX adapter, and thin CLI are
  implemented with opaque staged artifacts, exact View selection, source
  provenance, stable diagnostics, and deterministic human or JSON reports.
- The independent Haskell/inspection review approved commit `ce7726e` without
  findings: Fachlichkeit, Metamodell, Typtheorie, Haskell design, AMX adapter,
  CLI/UX, tests, formal value, and cross-artifact consistency each score
  10.0/10.0.
- `spc/Makefile` installs the exact project-local `o2i` executable under
  `$(DESTDIR)$(PREFIX)/bin/o2i` and removes only that path. Temporary-prefix
  installation, version execution, and idempotent uninstallation pass.
- The rendered WIP White Paper is tracked as the Git-LFS artifact `o2i.pdf` and
  linked from the repository README at deliberate reviewed checkpoints.
- The independent article/WTF/specification synchronization review is complete
  without findings. Fachlichkeit, Metamodell, terminology/WTF consistency,
  specification fidelity, Haskell/API consistency, and cross-artifact
  synchronization each score 10.0/10.0.
- The 2026-07-22 contextualization-syntax gate is complete: the external
  co-author updated the AMX adapter and tests, and an independent closure review
  found no findings. Fachlichkeit, Metamodell, Typtheorie, Haskell design,
  tests, formal value, and cross-artifact consistency each score 10.0/10.0.
- Collective Strategy realization formalizes explicit Claims, derived
  Elaboration and Maturity, opaque n-ary realization, exact contribution
  evidence, target coverage, contributor-bound Fit, native AMX projection,
  partial-View closure, and occurrence-preserving indexes.
- The independent point-5 closure review reports no findings and scores
  Fachlichkeit, Metamodell, Typtheorie, Haskell design, tests, formal value,
  terminology/documentation, cross-artifact consistency, and agentic-AI
  fitness each 10.0/10.0. The Haskell and paper verification stages pass.
- The Framework architecture visualization distinguishes the fachliche,
  metamodel, executable-formalization, and instance levels; locates the
  evidence layer inside metamodel semantics; and separates foundation,
  illustration, trace structure, and evidence result. TikZ sources reside in
  `acc/` and render reproducibly through `toPDF.sh`.
- The repeated independent architecture review reports no findings:
  Fachlichkeit, Metamodell, formal consistency, evidence logic, publication
  clarity, and reproducibility each score 10.0/10.0.
- `utl/verify.sh` is the canonical staged local and CI verification contract.
  Its `model`, `haskell`, and `paper` stages check model contracts and extractor
  tests; package metadata, licenses, all-package `-Werror` builds and tests,
  hermetic external-client API contracts, 100% public Haddock, and HIndent; and
  Pandoc, isolated TikZ rendering, and an isolated PDF build. Local execution
  defaults to all stages; GitHub Actions runs the same stages in parallel and
  caches Haskell dependencies and verification tooling while keeping each
  specification build hermetic.
- External API contracts use exhaustive Template Haskell assertions plus
  compile-pass controls and structured, fixture-local GHC compile-fail
  diagnostics against the exact Cabal build under test; ambient
  `spc/dist-newstyle` state cannot affect their result.
- Release-ready changes require a green full local Verify run and green GitHub
  Actions confirmation on `ubuntu-24.04`; focused stages support development
  but never replace that combined gate. The independent final review reports no
  findings and scores Fachlichkeit, Metamodell, Typtheorie, Haskell design,
  tests, and formal value each 10.0/10.0.

# Next Work

1. Implement package 2 for commitment-aware collective participant resolution
   with the external Haskell co-author, run complete Haskell and AMX
   verification, and repeat independent review until every required dimension
   scores 10.0/10.0.
2. Synchronize syntax Views, extractor presets, tests, snapshots, article, WTF,
   README, Haddock, model documentation, and changelog.
3. Run the complete cross-artifact gate and return to the exact
   `dbf:db-ia` re-entry point recorded in `pln.md`.
4. Afterwards continue the DB Fv instance, then review `wtf.md` at Vision and
   `o2i.md` collaboratively top-down.

# Release Note Draft

- `CHANGELOG.md` section `[0.2] - Unreleased` remains the canonical draft.
- Backlog: add the OMX adapter and convert Layered Cake to concrete syntax.
