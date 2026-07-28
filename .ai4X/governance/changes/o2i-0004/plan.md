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

## Finalreview Correction

Revision `d7d550e38b2fef1ac1720192c353a6f6e416b590` is rejected. One coherent
correction candidate closes these five findings:

1. Use `StructuredProposition` consistently as the persisted
   `o2i.kind`; retain `Claim` only as the notation-independent formal wrapper.
2. Establish the generated profile projection as the sole exact syntax
   inventory in the White Paper. Keep concise explanatory prose separate and
   distinguish persisted Context Associations from the Primitive relations
   that justify their semantics.
3. Add profile parser tests, renderer tests, and generated-fragment freshness
   checking to canonical model verification.
4. Document the actual `o2i-archimate-profile` dependency on both `o2i-core`
   and `o2i-inspection`.
5. Define the exact, non-redundant projection represented by the `O2I Syntax`
   master View, enforce equality between expected and actual mappings, and add
   a negative test for a missing required mapping.

Before implementation, the formalization co-author reviews the View projection
design. The design must preserve the exact declarative profile as authority
without turning the White Paper or reference View into duplicated,
hand-maintained inventories. Any resulting model change is performed manually
by the user under small-step guidance. Haskell Core changes are outside this
correction unless the design review proves a formal semantic change necessary.

Publication correction keeps target-state prose compact. Terminology remains
stable unless a missing term is demonstrated; Metamodel and syntax text are
synchronized precisely, long inventories are generated, and explanatory
detail is placed in a short box only when required for comprehension.

Revision `a149d9b793e91353be085f956ecae306e8243ef1` is rejected. Its coherent
correction candidate closes these six findings:

1. Define every Context macrorelation as an explicitly persisted Claim whose
   existence is never inferred from Primitive or syntax relations. Supporting
   asserted Primitive relations establish its fachliche evidence and
   validity.
2. Define a valid `Strategy --qualifies--> Need` Claim as content-grounded,
   formally admissible, and fachlich legitimized, but neither prioritized nor
   approved for implementation. O2I defines the meaning and formal
   preconditions of `Asserted`; instance governance determines who may
   authorize the transition and remains outside the O2I graph and validator.
3. Regenerate the versioned PDF and make canonical paper verification reject
   a stale PDF through metadata-independent semantic comparison.
4. Give generated profile tables stable wrapping dimensions and render formal
   alternatives without visible Markdown escaping.
5. Add table-driven missing- and duplicate-family regressions for every
   semantic relation-mapping family in `O2I Syntax`.
6. Guide the user through legible, crossing-free layouts for the semantic
   Situation and Situation Anchoring Views; then regenerate their snapshots
   and publication figures.

Correction status:

- all six findings are closed by revision
  `65b6c8549fcf84a7fb139adb0dfe0cd7301a3f85`;
- canonical complete verification passes that exact revision;
- the strategy Finalreview accepts it with 10.0 in every dimension;
- the formalization and publication Finalreviews reject it with four new
  correction subjects: output-sensitive effect-trace derivation, deterministic
  visual PDF freshness, current syntax-View routing in Agent Memory, and
  balanced generated-profile pagination.

The next correction preserves every accepted semantic result. It changes no
public O2I meaning or public Haskell API:

1. Replace Cartesian effect-trace enumeration and repeated linear edge lookup
   with deterministic internal graph indices and traversal of reachable facts.
   Add work-metric regressions proving invariance under unrelated Contexts.
2. Compare fixed-resolution deterministic page rasters in addition to page
   count and word-boundary-preserving normalized text. Add a visual-only drift
   regression.
3. Route Agent Memory to `O2I Syntax` as the complete mapping View and to the
   two separate executable conformance Views.
4. Balance the generated profile inventory without manual one-off page breaks
   or duplicated publication content.

Correction implementation status:

- the private trace search builds one graph index and traverses only reachable
  trace evidence; public trace identity and ordering remain unchanged;
- deterministic work regressions cover unrelated Contexts, relevant path
  growth, and input-order invariance;
- publication freshness compares page count, word-boundary-preserving text,
  and fixed-resolution page rasters, including a visual-only regression;
- Agent Memory names the complete mapping View and both executable conformance
  Views precisely;
- the generated profile inventory is locally compact, remains generated from
  the single contract, and contains no manual page split;
- `./utl/verify.sh all` passes the complete correction worktree.

The gate remains rejected until the coherent correction is committed, its exact
clean revision passes every required check, and independent Finalreview accepts
every required dimension with 10.0 and no findings.

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
