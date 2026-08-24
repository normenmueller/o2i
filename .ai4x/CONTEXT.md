# Purpose

Durable understanding required for work in the O2I repository. Operating rules
belong in `.ai4x/BEHAVIOR.md`; volatile handoff belongs in
`.ai4x/STATE.md`.

# Project

O2I is a generic framework for effect architectures. It makes oriented effect
understandable and evidencable through terminology, a metamodel, concrete
notation, and a machine-checkable Haskell formalization.

O2I remains independent of organizational instances. Instances test and apply
the Framework but never define its generic semantics.

# Central Thesis

- Contexts provide meaning; Primitives carry modeled content.
- Relations between contextualized Primitives justify Context
  macrorelations.
- Example:
  `Key Result @ Strategy --translates-into--> Objective @ Need` can substantiate
  `Strategy --qualifies--> Need`.
- O2I therefore defines a checkable effect graph, not only a terminology
  catalog.

# Semantic Baseline

- Fachliche domains: Orientierung, Formierung, Situierung,
  Operationalisierung, and Wirkung.
- Contexts: `Ethos`, `Mission`, `Vision`, `Strategy`, `Situation`, `Need`,
  `Intervention`, and `Measure`.
- Primitives: `Principle`, `Driver`, `Objective`, `Key Result`, `KPI`, and
  `Action`.
- `PerformanceDimension` is the closed structuring type for Strategy success
  dimensions and Measure measurement dimensions.
- Situation anchors are independent nodes. Typed `is-constituted-by`
  relations assign them to Situations.
- Every Situation has a constituting anchor, every Need is globally situated,
  and every Strategy has one complete coherent formulation.
- Need qualification is pre-intervention. Formal proposal validation,
  authorized fachliche acceptance, persistence, and renewed model validation
  remain distinct.
- A complete effect trace precedes evidence readiness. Effect and target
  attainment are assessed independently.
- O2I supports evidence consistency and plausible attribution, not causal
  proof.
- The current Foundation separates a Profile-projected `StructureProjection`, Core-owned `WellFormedGraph`, and Core-owned `SemanticallyValidModel`. Qualification, trace, readiness, and assessment remain separate capabilities with their own inputs, opaque results, rules, and diagnostics; they are not constructors of one monolithic validation pipeline.

# Proposition And Syntax Baseline

- Every persisted O2I proposition carries exactly one explicit
  `Commitment`: `Candidate` or `Asserted`.
- Candidates remain diagnostic and never satisfy semantic obligations.
  Asserted propositions may depend only on Asserted propositions.
- `Elaboration` is derived per Context; `Maturity` is derived for the complete
  model boundary.
- Primitives and PerformanceDimensions are contextualized exclusively through
  `Context --composition[contextualizes]--> element`. Visual nesting has no
  contextualization semantics.
- The Profile derives a carrier category from its ArchiMate type and exact `o2i.type`; it does not persist a parallel `o2i.kind` classification.
- `O2I Syntax - Carriers` and `O2I Syntax - Relations` are the unannotated carrier- and relation-mapping reference visualizations. Focused syntax Views are required to make non-binary patterns and metadata-bearing proposal syntax explicit. These Views specify notation and are not mapping authorities or fachliche O2I graphs.
- A focused syntax View is an executable Candidate conformance View only when its persisted metadata, references, and dependencies match the current Profile contract. It is then inspected through the AMX adapter and Core, never treated as a mapping authority. A stale or missing focused View is a model-correction target, not evidence that the Profile contract is absent or different.
- A `CollectiveStrategyRealization` uses at least two contributor Strategies, one distinct target Strategy, homogeneous `realizes` segments through one AND Junction, explicit participant completeness, and one Commitment on the Junction. Collective Fit is supplied separately as `CollectiveFitInput`; it is never persisted as ArchiMate metadata or a model reference.
- ArchiMate Groupings and Junctions are notation carriers and introduce no O2I
  semantics.

# Tool Architecture

```text
AMX source
 -> AMX Adapter: bounded acquisition and canonical native observations
 -> Operation: exact View selection and capability request
 -> ArchiMate Profile: root resolution, branch-separated closure, validation, projection
 -> Core: notation-independent structure and semantics; separate qualification, trace, readiness, and assessment contracts
 -> Operation: owner-bound diagnostics and deterministic machine results
 -> CLI: thin composition and rendering
```

The Python extractor is separate: it supports development and review of O2I
repository Views and snapshots. It never validates O2I instances.

# Repository Map

- `o2i.md`: White Paper and normative fachliche/metamodel text.
- `README.md`: canonical Purpose and USP snippets.
- `wtf.md`: informal non-normative entry guide.
- `spc/ctr/archimate/profile.json`: exact declarative ArchiMate profile
  mapping.
- `mdl/o2i.archimate`: semantic and concrete-syntax reference Views.
- `mdl/o2i-*.md`: generated review snapshots.
- `img/`, `acc/`, `toPDF.sh`: publication figures and rendering.
- `spc/lib/core/`: normative Haskell formalization.
- `spc/ctr/archimate/`: typed ArchiMate Profile projection and generated contract artifacts.
- `spc/lib/operation/`: capability-sized execution, provenance, diagnostics, and machine contracts.
- `spc/lib/adapter/amx/`: native AMX acquisition and Adapter implementation.
- `spc/lib/inspection/`: legacy package awaiting atomic removal; never extend it or use it as target architecture.
- `spc/cli/`: thin `o2i` CLI.
- `.ai4x/operations/`: task-specific execution and quality contracts.
- GitHub Issues: authority for change contracts, material decisions, acceptance criteria, dependencies, independent reviews, and open or closed state; an explicit Product Owner request may directly authorize Routine work.
- GitHub Project `O2I`: workflow-status and PO-ordering authority; no contract, acceptance, dependency, review, or closure authority.
- `.ai4x/governance/guidelines.md`: normative agent-facing GitHub workflow and evidence contract; no backlog, project history, or fachliche semantics.
- `utl/model/extract-archimate-view.py`: repository View/snapshot checker.
- `utl/verify.sh`: canonical staged verification.

# Stable Boundaries

- The Haskell formalization enforces the metamodel; it introduces no
  independent fachliche semantics.
- Static types prevent type-level invalidity. Runtime validation checks
  identity- and graph-wide invariants. Tests provide executable evidence that
  both classes of contract are enforced.
- Semantic Views visualize the metamodel. Syntax Views visualize the
  declarative ArchiMate profile contract. Neither ArchiMate nor Python defines
  O2I semantics.
- Agentic AI may propose fachliche links; authorized humans decide their
  acceptance; deterministic validation checks formal admissibility.
