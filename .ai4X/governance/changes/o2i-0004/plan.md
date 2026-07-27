# O2I-0004 Implementation Plan

Author: `normenmueller`

Co-Author: `external-anchor-coauthor`

## Affected Surfaces

- White Paper terminology, metamodel, and concrete-syntax text;
- notation-independent Haskell language and relation formalization;
- declarative ArchiMate profile contract and typed projection;
- AMX profile projection, fixtures, and tests;
- semantic and syntax reference Views and generated snapshots;
- WTF, technical documentation, Agent Memory, and changelog.

## Required Finalreview Capabilities

- strategy;
- formalization;
- Haskell;
- publication.

## Design Contract

`SituationAnchor` is the closed type:

```text
BusinessCapability | BusinessProcess | BusinessObject | ValueStream
```

Every constructor denotes the same operational effect subject across
`is-constituted-by`, `anchors`, `changes`, and `measures`. The formalization
defines this relation family once and derives every constructor-specific
admissibility rule from it. It contains no constructor exception, singleton
proxy, migration path, or compatibility layer.

`BusinessRole` and `RegulatoryConstraint` remain ordinary Enterprise
Architecture artifacts outside the closed O2I type. The White Paper states the
admissibility criterion, constructor readings, authors' derivation, minimal
scope, and prohibition of proxy anchoring.

`spc/ctr/archimate/profile.json` remains the exact concrete-mapping authority.
Its typed projection, AMX execution, reference Views, snapshots, and
publication projection express the same four-constructor contract.

## Steps

1. Remove obsolete Situation-anchor constructors, witnesses, registries, and
   tests from the Haskell Core.
2. Define one central anchor-relation-family observation and derive all typed
   anchor relation admissibility from it.
3. Update structural, semantic, trace, and evidence validation tests for the
   four-constructor closed type.
4. Reduce the declarative profile contract and typed projection to the four
   anchor carriers and their complete relation mappings.
5. Update AMX registries, projection, fixtures, and diagnostics without
   notation-specific semantic exceptions.
6. Synchronize White Paper, WTF, technical documentation, Agent Memory, and
   changelog in fresh target-state prose.
7. Verify the user-edited semantic and syntax Views, regenerate snapshots, and
   guide any further ArchiMate changes without editing the model directly.
8. Run focused and repository-wide verification.
9. Obtain independent Finalreviews for one exact implementation revision and
   accept only without findings and with 10.0 in every required dimension.

## Required Checks

- Core formatting, build, tests, API tests, and Haddock;
- profile contract validation, rendering, typed equality, and source archive;
- AMX formatting, build, tests, API tests, fixtures, and source archive;
- repository View-contract, snapshot, and extractor tests;
- publication expansion, references, figures, and PDF rendering;
- repository-wide staged verification;
- governance, generic-content, and diff checks.

## Non-goals

- defining arbitrary Enterprise Architecture artifacts as Situation anchors;
- adding relations for roles, regulation, or services;
- claiming a complete TOGAF or ArchiMate taxonomy;
- changing unrelated O2I terminology or validation stages;
- adding the SPC package-architecture documentation proposed separately;
- editing `mdl/o2i.archimate` automatically.
