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
- Added deterministic, View-scoped inspection of native Archi models through
  format-neutral libraries, the AMX adapter, and the thin `o2i` CLI with human
  and JSON reports.
- Added exactly one explicit Candidate or Asserted Commitment per persisted
  proposition, commitment-aware dependency validation and Candidate exclusion,
  derived Context elaboration, one complete Core-derived model maturity, and
  n-ary collective Strategy realization as a StructuredProposition with exact
  contributor evidence, target coverage, structured collective Fit,
  order-independent target Trade-offs, retained role- and
  participant-specific Candidate diagnostics, native AMX Junction projection,
  and provenance-preserving partial-View closure.

### Added

- Added an exhaustive human- and machine-readable mixed-license map with
  canonical CC-BY-4.0 and Apache-2.0 texts, REUSE 3.3 metadata, and a dedicated
  deterministic licensing verification stage that rejects unsupported licenses
  and missing, overlapping, or competing embedded assignments.
- Added lean, agentic-first admission, dependency, and independent-review
  governance for normative O2I Framework changes.
- Added a strictly technical `spc/README.md` for the Haskell package
  architecture, build, verification, installation, and CLI usage without
  introducing a competing source of O2I subject-matter semantics.
- Added the Git-LFS-tracked bleeding-edge `o2i.pdf` and linked it directly from
  the repository README.
- Added format-neutral staged model inspection, a native AMX adapter, and the
  thin `o2i inspect` CLI with exact View selection, file or standard-input
  acquisition, opaque source-relative adapter positions, request-bound source
  identities, mandatory closed-scope provenance, resource-bounded native XML
  decoding, stable diagnostics, and deterministic human or JSON reports.
- Added reproducible `make install` and `make uninstall` targets for the local
  `o2i` CLI and documented file- and standard-input inspection for human and
  agentic use.
- Added one staged, non-mutating repository verification contract with
  hermetic external-client API compile contracts, focused local execution,
  complete local-image validation, parallel cached GitHub Actions jobs, and a
  README status badge.
- Added one exact declarative ArchiMate profile contract with a typed Haskell
  projection, generated publication text, and checked reference visualization.
- Added `validateNeedQualificationProposal` as an opaque pre-persistence check
  for structurally and relationally admissible Need-qualification candidates
  with explicit rationale and source reference, distinct from subject-matter
  acceptance and the `qualifyingStrategies` query over accepted relations.
- Added repository-local agent facades backed by the canonical O2I behavior
  contract.
- Added a concise WTF and HTH guide with format-neutral minimum contents,
  validation criteria, process inputs, and results for central O2I concepts.
- Added a compact evidence-sequence visualization from situated Need to ex-post effect evidence.
- Added a framework-architecture visualization that distinguishes O2I's four
  architectural levels and locates the evidence layer within metamodel
  semantics.
- Added deterministic ArchiMate model-hygiene, View-contract,
  relationship-endpoint, documentation, and snapshot-drift verification.

### Changed

- Mapped `Strategy --directs--> Strategy` to ArchiMate `Influence`, retained
  directed `Association` for `Strategy --directs--> Intervention`, bound the
  endpoint-sensitive profile to explicit ArchiMate provenance, and split its
  checked reference visualization into carrier and relation-family Views.
- Structured deterministic repository utilities by responsibility under
  `utl/{verification,governance,model,haskell,paper}` while preserving
  `./utl/verify.sh` as the canonical staged entry point.
- Declared the O2I publication as the O2I Framework White Paper without
  changing its title.
- Shortened the paper title to "Von Orientierung zur Wirkung".
- Refined the introduction for clearer first-reader orientation and terminology.
- Reordered the literature-function section along the O2I domains.
- Clarified the O2I feedback loop, need qualification flow, generic refinement semantics, and the distinction between plausible attribution and causal proof.
- Clarified evidence logic as a derived justification structure rather than a separate O2I type or model element.
- Clarified formal validation of need qualification proposals, authorized
  subject-matter acceptance, and subsequent evidence readiness as distinct
  gates without requiring agentic AI.
- Defined every Context macrorelation as an explicitly persisted Claim whose
  validity requires its asserted Primitive evidence without being inferred
  from that evidence.
- Made canonical publication verification bind the versioned PDF to its exact
  sources and renderer release, install one immutable renderer revision in CI,
  and compare page and text structure against an isolated fresh build.
- Made effect-trace derivation output-sensitive through one private graph
  index and deterministic relation-driven joins from addressed
  Intervention/Need pairs through qualifying Strategy/Measure contexts,
  complete Primitive spines, Measure-specific Situations, and their shared
  Situation anchor; adversarial regressions cover every material fan-out
  dimension.
- Split the generated ArchiMate relation inventory at the semantic transition
  from Strategy formation to Need qualification and operationalization.
- Reduced validation listings to their documented public interfaces and kept
  implementation details in the referenced Haskell sources.
- Aligned Situation semantics by requiring every Situation to have at least one
  constituting Situation anchor.
- Reduced Situation anchors to the minimal closed set of Business Capability,
  Business Process, Business Object, and Value Stream, with one uniform
  constitution, anchoring, change, and measurement contract.
- Defined the exact minimum content and relational evidence contract for all
  eight Context types, including existential and universal obligations.
- Made the public adapter and diagnostic boundary schema-safe by construction
  through validated opaque machine values, Inspection-owned stages and
  identities, a deliberately reachable Inspection facade, and external-client
  API contracts.
- Made AMX model-root resolution execute the complete typed ArchiMate profile
  policy for key, cardinality, version, and additional O2I properties, while
  keeping selected-View semantic closure exclusively in Inspection and proving
  mixed-model and independently inspectable multi-View scopes.
- Closed external record-update forging for abstract typed-profile contracts
  through private internal fields, ordinary public accessors, and
  external-client compile contracts for hidden data constructors, record
  updates, and the hidden implementation module.
- Made all human CLI reports and process diagnostics terminal-safe by centrally
  encoding source-derived control characters without changing JSON reports.
- Clarified the semantic boundary between structural graph stages and
  subject-matter-enriched model stages, including the distinction between
  context-level relation evidence and empirical evidence stages.
- Distinguished binary Strategy contribution from collective Strategy
  realization and excluded direct binary `realizes` claims from O2I semantics.
- Distinguished normative `O2I Semantics - *` Views from their concrete
  `O2I Syntax - *` ArchiMate realizations through explicit View names and
  synchronized extractor contracts.
- Made contextualization by Context instances explicit and machine-readable in the ArchiMate
  syntax through one `composition[contextualizes]` per Primitive and
  Structuring element, mapped to the technical Haskell owner field rather than
  a fachliche graph edge; made
  Situation anchors ownerless and derived their Situation assignment
  exclusively from typed constitution relations; kept Primitive interpretation
  and PerformanceDimension role semantics independent of their ArchiMate
  `Grouping` representation; introduced explicit `o2i.kind` and `o2i.type`
  classification while deriving contextualization exclusively from
  `composition[contextualizes]`, validated technical Ownership model-wide, and
  required every PerformanceDimension member to share its concrete owner
  Context instance.
- Separated `O2I Semantics - Situation` as the anchor type model from `O2I Semantics - Situation Anchoring` as the relation model connecting situated Need, Intervention, and Measure semantics, with a parameterized ArchiMate syntax mapping for every admitted anchor form.
- Clarified the Haskell specification as the normative machine-checkable formalization of the technology-independent O2I metamodel.
- Introduced the mandatory strategic success reference as the terminology counterpart of `Key Result @ Strategy`.
- Mapped every identifier in the `O2I Semantics - Strategy Constituents` View explicitly to its
  corresponding terminology term.
- Reworked the Haskell specification under `spc/` into a Library-first Cabal project with typed graphs, an explicit graph/model validation boundary, total relation registries, opaque validated identities, canonical metadata and staged results, closed PerformanceDimension roles, stable KPI definitions with validated units and value domains, distinct measurement levels and deltas, five-stage validation of structure, semantics, traceability, ex-ante evidence readiness, and ex-post evidence assessment, canonical planned and actual Intervention timing, absolute and relative effect criteria, fully typed effect traces, focused qualification and trace queries, separate effect and target assessment, and executable API contracts.

## [0.1] - 2026-07-02

### Added

- Initial O2I framework release candidate for internal review.
- Terminology, metamodel, Haskell validation specification, ArchiMate views, and PDF release assets.
