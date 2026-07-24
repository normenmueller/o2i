# Purpose

Volatile O2I handoff state. Repository facts and the latest user instruction
override this snapshot.

# Snapshot

- Observed at: 2026-07-24 CEST.
- Mode: `ACTIVE`.
- Branch/upstream: `trunk` / `origin/trunk`; inspect Git for the current delta.
- Active objective: synchronize the accepted explicit Commitment and
  proposition-carrier contract with the normative ArchiMate syntax Views,
  extractor contracts, and snapshots.
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
  Situation` are normative semantic Views. Concrete syntax separates
  unannotated Context, Primitive, and Situation mapping Views from executable
  Candidate Contextualization and Collective Strategy Realization conformance
  Views.
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

- `o2i:commitment-closure` is accepted. The explicit Commitment,
  proposition-carrier, and `StructuredProposition` target contract is approved;
  its independently accepted Haskell package is commit `81e5c2c`.
- `O2I Syntax - Collective Strategy Realization` is a complete Candidate
  conformance exemplar: three Candidate Strategy Contexts, one Candidate
  `CollectiveStrategyRealization` carried by an AND Junction, three
  commitment-free `realizes` segments, and a Fit evidence reference. The
  Haskell inspector passes Decode, ViewScope, Profile, and Structure and emits
  only intended Candidate-exclusion warnings.
- The former Haskell-dispatch High finding is fully closed:
  only exactly one direct `o2i.type=CollectiveStrategyRealization` activates
  collective parsing; missing, duplicate, unknown, and future types remain in
  generic profile validation with provenance. The formatting closure passes
  HIndent and `git diff --check`; the bounded independent recheck reports no
  findings and scores all eight dispatcher dimensions 10.0/10.0. The separate
  open High finding remains the Python extractor's duplication of generic
  profile semantics that belong exclusively to Haskell.
- A separate metamodel review rejects the former view-wide Commitment plan.
  Mapping Views remain unannotated notation specifications. Executable
  conformance Views use distinct Candidate proposition carriers. Publication
  synchronization remains paused until this syntax gate closes.
- All eight `O2I Syntax - Context` mapping elements now have no direct O2I
  metadata. Their documentation still describes the removed properties, and
  Mission and Strategy remain shared with the Contextualization View; both
  points are explicit pending model steps in `pln.md`.
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

1. Reduce the Python extractor to deterministic repository and snapshot
   contracts; validate generic O2I profile semantics only through Haskell.
2. Guide the user through the mapping/conformance View split and verify every
   model change through snapshots and the appropriate Haskell inspector gates.
3. Synchronize article, WTF, repository README, `spc/README.md`, Haddock, model
   documentation, and changelog.
4. Correct the TikZ evidence sequence so that
   `validateNeedQualificationProposal` labels the formal proposal check and
   `qualifyingStrategies` remains a query over the accepted modeled
   qualification.
5. Run the complete cross-artifact gate and return to the exact
   `dbf:db-ia` re-entry point recorded in `pln.md`.
6. Afterwards continue the DB Fv instance, then review `wtf.md` at Vision and
   `o2i.md` collaboratively top-down.

# Release Note Draft

- `CHANGELOG.md` section `[0.2] - Unreleased` remains the canonical draft.
- Backlog: add the OMX adapter and convert Layered Cake to concrete syntax.
