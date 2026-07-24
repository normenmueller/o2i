# Purpose

Durable understanding required for work in the O2I repository. Operating rules
belong in `.ai4X/BEHAVIOR.md`; volatile handoff belongs in
`.ai4X/STATE.md`.

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
- Validation stages:
  `RawGraph -> WellFormedGraph -> SemanticallyValidModel -> TraceableEffectModel -> EvidenceReadyModel -> EvidenceAssessedModel`.

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
- `o2i.kind` identifies `Context`, `Primitive`, `Structuring`,
  `SituationAnchor`, or `StructuredProposition`; `o2i.type` identifies the
  corresponding O2I constructor.
- Mapping Views are unannotated notation specifications and are not O2I graph
  propositions:
  `O2I Syntax - Context`, `O2I Syntax - Primitives`, and
  `O2I Syntax - Situation`.
- Conformance Views use distinct Candidate carriers:
  `O2I Syntax - Contextualization` and
  `O2I Syntax - Collective Strategy Realization`.
- A `CollectiveStrategyRealization` uses at least two contributor Strategies,
  one distinct target Strategy, homogeneous `realizes` segments through one
  AND Junction, and collective Fit evidence. The Junction is the sole
  Commitment carrier.
- ArchiMate Groupings and Junctions are notation carriers and introduce no O2I
  semantics.

# Tool Architecture

```text
AMX
 -> Haskell AMX adapter: Decode, View scope, profile, projection
 -> notation-independent O2I graph
 -> Core/Inspection: structure, semantics, trace, readiness, evidence
 -> CLI: report rendering
```

The Python extractor is separate: it supports development and review of O2I
repository Views and snapshots. It never validates O2I instances.

# Repository Map

- `o2i.md`: White Paper and normative fachliche/metamodel text.
- `README.md`: canonical Purpose and USP snippets.
- `wtf.md`: informal non-normative entry guide.
- `mdl/o2i.archimate`: semantic and concrete-syntax Views.
- `mdl/o2i-*.md`: generated review snapshots.
- `img/`, `acc/`, `toPDF.sh`: publication figures and rendering.
- `spc/lib/core/`: normative Haskell formalization.
- `spc/lib/inspection/`: format-neutral inspection pipeline.
- `spc/lib/adapter/amx/`: native AMX profile and projection.
- `spc/cli/`: thin `o2i` CLI.
- `utl/extract-archimate-view.py`: repository View/snapshot checker.
- `utl/verify.sh`: canonical staged verification.

# Stable Boundaries

- The Haskell formalization enforces the metamodel; it introduces no
  independent fachliche semantics.
- Static types prevent type-level invalidity. Runtime validation checks
  identity- and graph-wide invariants. Tests provide executable evidence that
  both classes of contract are enforced.
- Semantic Views visualize the metamodel. Syntax Views define the concrete
  ArchiMate mapping. Neither ArchiMate nor Python defines O2I semantics.
- Agentic AI may propose fachliche links; authorized humans decide their
  acceptance; deterministic validation checks formal admissibility.
