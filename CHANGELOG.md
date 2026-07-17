# Changelog

## [0.2] - Unreleased

### Summary

- Added the mandatory strategic success reference, Situating and Situation
  anchors, stable KPI definitions, observations, effect and target criteria,
  evidence readiness, and plausible attribution.
- Removed Direction, open Domain/CSF structuring types, redundant reverse
  relations, and refinement as an O2I core relation.
- Replaced Contextualization with Situating, defined Situation through anchors,
  introduced closed PerformanceDimension roles, and separated effect from
  target attainment.
- Achieved one machine-checkable semantic chain from Strategy through Need and
  Intervention to evidence, synchronized across terminology, metamodel,
  ArchiMate, Haskell, and tests.

### Added

- Added repository-local agent facades backed by the canonical O2I behavior
  contract.
- Added a concise WTF and HTH guide for direct access to central O2I concepts.
- Added a compact evidence-sequence visualization from situated Need to ex-post effect evidence.
- Added deterministic ArchiMate model-contract, relationship-endpoint, and snapshot-drift verification.

### Changed

- Shortened the paper title to "Von Orientierung zur Wirkung".
- Refined the introduction for clearer first-reader orientation and terminology.
- Reordered the literature-function section along the O2I domains.
- Clarified the O2I feedback loop, need qualification flow, generic refinement semantics, and the distinction between plausible attribution and causal proof.
- Clarified evidence logic as a derived justification structure rather than a separate O2I type or model element.
- Clarified the semantic boundary between structural graph stages and fachlich enriched model stages.
- Separated `O2I Situation` as the anchor type model from `O2I Situation Anchoring` as the relation model connecting situated Need, Intervention, and Measure semantics, with a parameterized ArchiMate 4 syntax mapping for every anchor form.
- Clarified the Haskell specification as the normative machine-checkable formalization of the technology-independent O2I metamodel.
- Introduced the mandatory strategic success reference as the terminology counterpart of `Key Result @ Strategy`.
- Reworked the Haskell specification under `spc/` into a Library-first Cabal project with typed graphs, an explicit graph/model validation boundary, total relation registries, opaque validated identities, canonical metadata and staged results, closed PerformanceDimension roles, stable KPI definitions with validated units and value domains, distinct measurement levels and deltas, five-stage validation of structure, semantics, traceability, ex-ante evidence readiness, and ex-post evidence assessment, canonical planned and actual Intervention timing, absolute and relative effect criteria, fully typed effect traces, focused qualification and trace queries, separate effect and target assessment, and executable API contracts.

## [0.1] - 2026-07-02

### Added

- Initial O2I framework release candidate for internal review.
- Terminology, metamodel, Haskell validation specification, ArchiMate views, and PDF release assets.
