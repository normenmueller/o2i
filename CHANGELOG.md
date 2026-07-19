# Changelog

## [0.2] - Unreleased

### Summary

- Added the mandatory strategic success reference, formal validation of need
  qualification proposals, Situating and Situation anchors, stable KPI
  definitions, observations,
  effect and target criteria, evidence readiness, and plausible attribution.
- Removed Direction, open Domain/CSF structuring types, redundant reverse
  relations, and refinement as an O2I core relation.
- Replaced Contextualization with Situating, defined Situation through anchors,
  introduced closed PerformanceDimension roles, and separated effect from
  target attainment.
- Achieved one machine-checkable semantic chain from Strategy through Need and
  Intervention to evidence, synchronized across terminology, metamodel,
  ArchiMate, Haskell, and tests.

### Added

- Added format-neutral staged model inspection, a native AMX adapter, and the
  thin `o2i inspect` CLI with exact View selection, file or standard-input
  acquisition, opaque source-relative adapter positions, request-bound source
  identities, mandatory closed-scope provenance, resource-bounded native XML
  decoding, stable diagnostics, and deterministic human or JSON reports.
- Added `validateNeedQualificationProposal` as an opaque pre-persistence check
  for structurally and relationally admissible Need-qualification candidates
  with explicit rationale and source reference, distinct from subject-matter
  acceptance and the `qualifyingStrategies` query over accepted relations.
- Added repository-local agent facades backed by the canonical O2I behavior
  contract.
- Added a concise WTF and HTH guide with format-neutral minimum contents,
  validation criteria, process inputs, and results for central O2I concepts.
- Added a compact evidence-sequence visualization from situated Need to ex-post effect evidence.
- Added deterministic ArchiMate model-contract, relationship-endpoint, and snapshot-drift verification.

### Changed

- Shortened the paper title to "Von Orientierung zur Wirkung".
- Refined the introduction for clearer first-reader orientation and terminology.
- Reordered the literature-function section along the O2I domains.
- Clarified the O2I feedback loop, need qualification flow, generic refinement semantics, and the distinction between plausible attribution and causal proof.
- Clarified evidence logic as a derived justification structure rather than a separate O2I type or model element.
- Clarified formal validation of need qualification proposals, authorized
  subject-matter acceptance, and subsequent evidence readiness as distinct
  gates without requiring agentic AI.
- Aligned Situation semantics by requiring every Situation to have at least one
  constituting Situation anchor.
- Defined the exact minimum content and relational evidence contract for all
  eight Context types, including existential and universal obligations.
- Made the public adapter and diagnostic boundary schema-safe by construction
  through validated opaque machine values, Inspection-owned stages and
  identities, and external-client API contracts.
- Made all human CLI reports and process diagnostics terminal-safe by centrally
  encoding source-derived control characters without changing JSON reports.
- Clarified the semantic boundary between structural graph stages and
  subject-matter-enriched model stages.
- Made Context ownership explicit and machine-readable in the ArchiMate syntax
  through one `composition[contains]` per Primitive and Structuring element,
  mapped to the Haskell owner field rather than a fachliche graph edge; made
  Situation anchors ownerless and derived their Situation assignment
  exclusively from typed constitution relations; kept Primitive interpretation
  and PerformanceDimension role semantics independent of their ArchiMate
  `Grouping` representation; introduced explicit `o2i.kind` and `o2i.type`
  classification while deriving ownership exclusively from
  `composition[contains]`, validated Ownership model-wide, and required every
  PerformanceDimension member to share its concrete owner Context instance.
- Separated `O2I Situation` as the anchor type model from `O2I Situation Anchoring` as the relation model connecting situated Need, Intervention, and Measure semantics, with a parameterized ArchiMate 4 syntax mapping for every anchor form.
- Clarified the Haskell specification as the normative machine-checkable formalization of the technology-independent O2I metamodel.
- Introduced the mandatory strategic success reference as the terminology counterpart of `Key Result @ Strategy`.
- Reworked the Haskell specification under `spc/` into a Library-first Cabal project with typed graphs, an explicit graph/model validation boundary, total relation registries, opaque validated identities, canonical metadata and staged results, closed PerformanceDimension roles, stable KPI definitions with validated units and value domains, distinct measurement levels and deltas, five-stage validation of structure, semantics, traceability, ex-ante evidence readiness, and ex-post evidence assessment, canonical planned and actual Intervention timing, absolute and relative effect criteria, fully typed effect traces, focused qualification and trace queries, separate effect and target assessment, and executable API contracts.

## [0.1] - 2026-07-02

### Added

- Initial O2I framework release candidate for internal review.
- Terminology, metamodel, Haskell validation specification, ArchiMate views, and PDF release assets.
