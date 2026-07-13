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

# Semantic Baseline

- O2I separates Terminology, Semantics, and Syntax.
- Contexts: `Ethos`, `Mission`, `Vision`, `Strategy`, `Need`, `Situation`,
  `Intervention`, and `Measure`.
- Primitives: `Principle`, `Driver`, `Objective`, `Key Result`, `KPI`, and
  `Action`.
- `Domain` is the generic structuring type; names such as CSF or KPI domain are
  domain instances or readings, not metamodel types.
- `Observation`, `EvidencePlan`, `EffectCriterion`, `TargetCriterion`, and
  `EvidenceClaim` form the evidence layer; they are neither Contexts nor
  Primitives.
- Effect and target attainment are assessed independently.
- O2I validates evidence consistency and plausible attribution, not
  methodological causality.
- The validation pipeline is
  `RawGraph -> WellFormedGraph -> SemanticallyValidModel -> TraceableEffectModel -> EvidenceAssessedModel`.
- ArchiMate is the concrete notation, never the semantic source.

# Repository Map

- `o2i.md`: article and fachliche reference text.
- `README.md`: canonical shared Purpose and USP snippets included by the article.
- `mdl/o2i.archimate`: ArchiMate model.
- `mdl/o2i-*.md`: generated read-only review snapshots.
- `img/`: article and model exports.
- `spc/src/lib/`: normative typed Haskell library.
- `spc/tst/`: executable validation tests.
- `utl/extract-archimate-view.py`: deterministic ArchiMate snapshot extractor.

# Haskell Architecture

- `O2I.Language`: public semantic language facade.
- `O2I.Graph`: public facade for concrete effect graphs.
- `O2I.Validation`: public facade for staged validation.
- `O2I`: curated aggregate facade.
- The library distinguishes static relation typing from runtime validation of
  concrete graph-wide invariants.
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
