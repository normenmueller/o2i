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
- O2I may support agentic AI in proposing qualification evidence, but never
  requires it. Cognitive assessment may be human or AI-assisted; authorized
  fachliche acceptance remains distinct from deterministic specification
  validation, and O2I remains fully valid without AI.
- A Need qualification proposal references an existing candidate Strategy and
  a situated Need, proposes one Strategy-Key-Result-to-Need-Objective relation,
  and provides rationale plus a source reference. Validate it after complete
  Need situating and before persisting `translates-into` and `qualifies`.
  Specification validation establishes only formal admissibility; authorized
  fachliche acceptance precedes persistence and renewed model validation.
- An evidence design may accompany an organizational submission but remains a
  separate later gate. It prepares actionability and evidence readiness and
  never determines the Need's strategic relevance.
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
- In the ArchiMate syntax, every Primitive and Structuring element has exactly
  one owning O2I Context through
  `Context --composition[contains]--> owned element`. A Context may own only
  Primitives and Structuring elements whose Interpretation or role is
  admissible for that Context. Visual nesting presents but never replaces this
  persisted ownership. Import maps it to the Haskell owner field, not to a
  fachliche `RawEdge`.
- ArchiMate model metadata uses `o2i.kind` for `Context`, `Primitive`,
  `Structuring`, or `SituationAnchor` and `o2i.type` for the corresponding O2I
  constructor. It never duplicates owner, Context, role, interpretation, or
  membership semantics; ownership derives exclusively from Composition.
- Situation anchors are independent nodes without a Context owner. Their
  assignment to one or more Situations is expressed exclusively by typed
  `is-constituted-by` relations.
- Every Situation has at least one constituting Situation anchor; every Need is
  globally situated; every Strategy has exactly one complete, coherent
  formulation.
- `PerformanceDimension` is one closed structuring type with exactly two roles:
  a Strategy success dimension contains Strategy Key Results; a Measure
  measurement dimension contains Measure KPIs. CSF is a fachliche reading of
  the first role. A role constrains admissible member types and membership but
  never interprets its member Primitives; their meaning remains defined by
  their own `Primitive @ Context`. Other groupings are not O2I
  PerformanceDimensions.
- A PerformanceDimension and every contained member Primitive share the same
  concrete owner Context instance.
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
  their mapped relations. ArchiMate `Grouping` realizes Context and
  PerformanceDimension notation but introduces no O2I semantics.

# Repository Map

- `o2i.md`: White Paper and fachliche reference text.
- `README.md`: canonical shared Purpose and USP snippets included by the White
  Paper.
- `wtf.md`: informal, non-normative entry guide linked to the White Paper.
- `mdl/o2i.archimate`: ArchiMate model.
- `mdl/o2i-*.md`: generated read-only review snapshots.
- `img/`: White Paper and model exports.
- `acc/`: reproducible TikZ sources for White Paper figures.
- `spc/README.md`: non-normative technical codebase and usage documentation.
- `spc/lib/core/`: normative typed Haskell core library.
- `spc/lib/inspection/`: format-neutral model inspection and reporting.
- `spc/lib/adapter/amx/`: native Archi Model XML adapter.
- `spc/cli/`: thin `o2i` command-line client.
- `spc/Makefile`: reproducible local CLI installation and uninstallation.
- `spc/lib/core/tst/`: executable validation tests.
- `toPDF.sh`: reproducible TikZ and PDF build entry point.
- `utl/verify.sh`: canonical non-mutating repository verification used locally
  and by GitHub Actions.
- `utl/extract-archimate-view.py`: deterministic ArchiMate snapshot extractor
  and model-contract validator.

# Model Inspection

- Use `o2i inspect MODEL (--view NAME | --view-id ID)` to validate exactly one
  O2I View from a native Archi model.
- Use standard input and `--json` for deterministic agentic processing:
  `cat mdl/my.archimate | o2i inspect - --view "My view" --json`.
- The CLI is only a rendering and composition boundary. Inspection semantics,
  staged validation, provenance, and reports remain in the libraries.

# Haskell Architecture

- The Haskell specification is the normative machine-checkable formalization
  of the technology-independent O2I metamodel, not an independent fachliche
  layer.
- Terminology defines fachliche concepts and boundaries; the metamodel defines
  elements, relations, and invariants; the Haskell specification enforces those
  invariants mechanically.
- Formal precision must expose and resolve semantic ambiguity but must never
  invent fachliche semantics that cannot be justified by the White Paper and
  metamodel.
- GADTs, modules, and opaque validation stages are Haskell design decisions;
  they do not introduce additional O2I fachliche semantics.
- `O2I.Language`: public semantic language facade.
- `O2I.Graph`: public facade for concrete effect graphs.
- `O2I.Validation`: public facade for staged validation.
- `O2I`: curated aggregate facade.
- The library distinguishes static relation typing from runtime validation of
  concrete graph-wide invariants.
- Validated identifiers, canonical interpretation and relation metadata,
  graph-wide validation stages, traces, KPI definitions, and assessments are
  opaque. Clients obtain them only through canonical registries, lookup, or
  validation and may project, but never construct or rewrite, their contents.
- Haskell excerpts in `o2i.md` are included directly from
  `spc/lib/core/src/` via `pandoc-include`.

# Document Architecture

- The White Paper progresses through Einleitung, Fundament, Terminologie,
  Metamodell, Illustration, Fazit, and acknowledgements.
- The Semantik section is organized by Kontexte, Primitives,
  Wohlgeformtheitsregeln, and Interpretationen.
- Kontexte and Primitives each distinguish Elemente and Relationen.
- Syntax maps `Objective` to ArchiMate `Goal`, `Key Result` to `Outcome`, `KPI`
  to `Assessment`, and `Action` to `Course of Action`.
