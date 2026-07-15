# Purpose

Durable project understanding for agentic AI agents working on O2I. Operating
rules belong in `BEHAVIOR.md`; volatile handoff state belongs in `STATE.md`.

# Project

O2I is a generic framework for effect architectures. It explains how
orientation, formation, situating, operationalization, and effect are grounded,
modeled, traced, and evidenced. The metamodel is the formal core of the
framework.

O2I remains independent of concrete organizational instances. Instances may
test and apply O2I but never define its generic semantics.

# Central Thesis

- O2I context macrorelations require justification through relations between
  contextualized O2I Primitives.
- Contexts provide meaning; Primitives carry modeled content.
- The effect graph emerges from contextualized Primitives and their relations.
- Example: `Key Result @ Strategy --translates-into--> Objective @ Need` can
  substantiate `Strategy --qualifies--> Need`.
- O2I therefore defines a checkable effect graph rather than only a terminology
  catalog.

# Qualification And Application Boundary

- Need qualification is an independent, pre-intervention capability. It asks
  which Strategy qualifies a situated Need and requires neither Intervention
  nor Measure.
- Evidence readiness is a generic O2I capability for validating an effect
  trace before an Intervention starts.
- O2I does not define Strategic Fit Evaluation, strategic topic complexes,
  instance-specific scores or statuses, or PerformanceDimension-bound fit
  semantics.
- External evaluations may query O2I effect traces to determine which
  Strategies connect to an Intervention. Domains are optional instance-level
  filters, never a prerequisite of generic O2I semantics.

# Semantic Baseline

- O2I separates Terminology, Semantics, and Syntax.
- Contexts: `Ethos`, `Mission`, `Vision`, `Strategy`, `Need`, `Situation`,
  `Intervention`, and `Measure`.
- Primitives: `Principle`, `Driver`, `Objective`, `Key Result`, `KPI`, and
  `Action`.
- `PerformanceDimension` is one closed structuring type with exactly two roles:
  a Strategy success dimension contains Strategy Key Results; a Measure
  measurement dimension contains Measure KPIs. CSF is a fachliche reading of
  the first role. Other groupings are not O2I PerformanceDimensions.
- `KPIDefinition`, `Unit`, `ValueDomain`, `Level`, `Delta`, `Observation`,
  `EvidencePlan`, `EffectCriterion`, `TargetCriterion`, and
  `FollowUpObservation` form the evidence layer; they are neither Contexts nor
  Primitives.
- Each KPI used by an effect trace has exactly one validated stable definition.
  Measurement levels and absolute changes are distinct types; the definition
  supplies their shared unit and the admissible domain of levels.
- Effect and target attainment are assessed independently.
- O2I validates evidence consistency and plausible attribution, not
  methodological causality.
- The validation pipeline is
  `RawGraph -> WellFormedGraph -> SemanticallyValidModel -> TraceableEffectModel -> EvidenceReadyModel -> EvidenceAssessedModel`.
- `RawGraph` represents unchecked node-edge data; `WellFormedGraph` establishes
  local graph admissibility; model stages add global fachliche invariants,
  effect traces, ex-ante evidence readiness, and ex-post evidence assessments.
- `O2I Context` and `O2I Primitives` are normative semantic visualizations of
  the O2I context and primitive models.
- `O2I Situation` is the normative semantic visualization of the Situation
  anchor category, its admissible forms, and Situation constitution.
- `O2I Situation Anchoring` is the normative semantic visualization of the
  parameterized Situation-anchor relation families.
- The concrete ArchiMate 4 syntax maps each Situation-anchor form to its native
  or explicitly specialized element and applies one parameterized relation
  mapping; no duplicate 24-edge syntax view is required.
- Their semantics is defined by O2I and does not derive from ArchiMate.
- `O2I Syntax` is the concrete ArchiMate realization of O2I contexts,
  contextualized Primitives, PerformanceDimensions, Situation anchors, and
  their mapped relations.

# Repository Map

- `o2i.md`: article and fachliche reference text.
- `README.md`: canonical shared Purpose and USP snippets included by the article.
- `wtf.md`: informal, non-normative entry guide linked to the article.
- `mdl/o2i.archimate`: ArchiMate model.
- `mdl/o2i-*.md`: generated read-only review snapshots.
- `img/`: article and model exports.
- `spc/src/lib/`: normative typed Haskell library.
- `spc/tst/`: executable validation tests.
- `toPDF.sh`: reproducible TikZ and PDF build entry point.
- `utl/extract-archimate-view.py`: deterministic ArchiMate snapshot extractor
  and model-contract validator.

# Haskell Architecture

- The Haskell specification is the normative machine-checkable formalization
  of the technology-independent O2I metamodel, not an independent fachliche
  layer.
- Terminology defines fachliche concepts and boundaries; the metamodel defines
  elements, relations, and invariants; the Haskell specification enforces those
  invariants mechanically.
- Formal precision must expose and resolve semantic ambiguity but must never
  invent fachliche semantics that cannot be justified by the article and
  metamodel.
- GADTs, modules, and opaque validation stages are Haskell design decisions;
  they do not introduce additional O2I fachliche semantics.
- `O2I.Language`: public semantic language facade.
- `O2I.Graph`: public facade for concrete effect graphs.
- `O2I.Validation`: public facade for staged validation.
- `O2I`: curated aggregate facade.
- The library distinguishes static relation typing from runtime validation of
  concrete graph-wide invariants.
- Public interpretation specifications and existential interpretations are
  opaque. Clients obtain canonical values through typed witnesses, registry
  enumeration, or lookup and may only project their metadata.
- Validated effect assessments are opaque. Clients obtain them only through
  evidence assessment and may project, but never rewrite, their follow-up,
  effect, and target results.
- Haskell excerpts in `o2i.md` are included directly from `spc/src/lib/` via
  `pandoc-include`.

# Document Architecture

- The article progresses through Einleitung, Fundament, Terminologie,
  Metamodell, Illustration, Fazit, and acknowledgements.
- The Semantik section is organized by Kontexte, Primitives,
  Wohlgeformtheitsregeln, and Interpretationen.
- Kontexte and Primitives each distinguish Elemente and Relationen.
- Syntax maps `Objective` to ArchiMate `Goal`, `Key Result` to `Outcome`, `KPI`
  to `Assessment`, and `Action` to `Course of Action`.
