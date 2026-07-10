# Changelog

## [Unreleased]

### Changed

- Shortened the paper title to "Von Orientierung zur Wirkung".
- Refined the introduction for clearer first-reader orientation and terminology.
- Reordered the literature-function section along the O2I domains.
- Reworked the Haskell specification under `spc/` into a Library-first Cabal project.
- Split the typed O2I core into elements, relations, graph, and validation modules.
- Distinguished structural well-formedness (`wfModel`) from complete effect-model validation (`validEffectModel`).
- Derived runtime interpretation checks from typed `Interpretation` witnesses via `allowedInterpretation`.
- Added validation tests for effect relevance, macrorelation evidence, and complete effect traces.

## [0.1] - 2026-07-02

### Added

- Initial O2I framework release candidate for internal review.
- Terminology, metamodel, Haskell validation specification, ArchiMate views, and PDF release assets.
