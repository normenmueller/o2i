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

Revision `bd949e4af16a1bff6fbe20c1e6cb6aca98bae2bb` is rejected. Its exact
clean repository verification passes, and all prior semantic, profile,
Situation-View, Agent-Memory, and profile-pagination findings remain closed.
The next correction closes three material findings:

1. Replace the remaining Strategy-by-Situation cross product under reachable
   dead-end fan-out with a Measure-led multiway join per addressed
   Intervention/Need pair. Add a linear-work adversarial regression while
   preserving trace identities, ordering, and the public API.
2. Replace the removed `matchesInterventionNeed` publication end marker with a
   stable explicit Haskell snippet boundary. The White Paper shows only the
   public traceability entry point and remains within one page.
3. Bind the versioned PDF to its exact publication sources and compare page
   and text structure against an isolated fresh build. The contract remains
   proportionate to a bleeding-edge PDF and requires no byte- or pixel-exact
   output from an unpinned renderer stack.

Correction implementation status:

- trace derivation starts from the target Measure and intersects compatible
  Situations and Strategies before extending a path;
- the adversarial `0, 10, 20, 40` reachable-fan-out regression proves linear
  traversal work with one unchanged trace identity;
- all five staged validation listings show only their documented public
  interfaces and occupy no more than one page each;
- `o2i.pdf.manifest.json` binds the exact PDF bytes to all publication inputs,
  including included Haskell sources, images, and TikZ sources; isolated
  verification separately compares page structure and normalized text;
- the source-bound contract detects stale visual and layout inputs without
  assuming byte-identical output from unpinned platform toolchains;
- the generated relation inventory uses separate, semantically bounded tables
  for Strategy formation and subsequent Need qualification and
  operationalization; conditional layout space keeps each heading with its
  table without a fixed page break;
- `./utl/verify.sh all` passes the complete correction worktree.

The repository handoff records the exact candidate revision and completed
clean verification before the next Finalreview.

Revision `546d43dac71b8c0b8f324fa7b8fa2fb1cc3f0136` is rejected by the
independent Haskell Finalreview. Strategy, formalization, and publication
reviews accept it without findings and with 10.0 in every dimension. The
remaining correction closes one finding:

1. Derive a complete Strategy/Need/Intervention/Measure primitive spine before
   joining its changed/measured Situation anchor to constituted Situations.
   Eliminate the pre-validation `compatibleSituations × strategyVisions`
   product and strengthen the `0, 10, 20, 40` regression with
   Measure-compatible, role-complete branches that fail only at later
   effect-path joins. Output identity and ordering remain unchanged while
   traversal work grows linearly.

Correction implementation status:

- trace derivation completes the Strategy/Need/Intervention/Measure primitive
  spine before joining its changed, measured, and Need-grounding anchor to
  constituted Situations;
- the strengthened `0, 10, 20, 40` regression preserves one identical trace
  while every traversal-work component grows linearly;
- focused public and private Core tests pass;
- the exact candidate revision, complete verification, and four independent
  Finalreviews remain pending.

Revision `18499622b393bcee11bc007bfecb97f5283e6d9b` is rejected. Its exact
clean repository verification passes, and the independent strategy
Finalreview accepts it without findings and with 10.0 in every dimension. The
next coherent correction closes two findings:

1. Compute macrocompatible Situations once per
   `(Intervention, Need, Measure)`, index them by their constituted Situation
   anchor, and look up each complete Primitive spine by anchor. Add adversarial
   `0, 10, 20, 40` regressions for complete mismatched spines,
   otherwise-complete unconstituted anchors, and multiple compatible
   Strategies with multiple Situations. Exact trace identity and ordering
   remain unchanged while every traversal-work component grows linearly with
   constant or linear output.
2. Define one repository-owned `md2pdf v0.2.4` toolchain identity. Local paper
   builds verify that identity, CI installs the same immutable revision, and
   the publication manifest binds the renderer identity together with exact
   sources and PDF bytes.

Correction implementation status:

- trace derivation builds one Situation-to-anchor index before compatible
  Strategy and Vision enumeration and performs one deterministic anchor lookup
  per complete Primitive spine;
- all three adversarial `0, 10, 20, 40` regressions prove affine-linear work
  with exact output identity and ordering;
- `acc/md2pdf.json` is the single release and CI-acquisition contract; local
  builds verify version `0.2.4`, CI installs its immutable revision, and
  manifest v2 binds the locally verifiable renderer identity;
- focused Haskell, publication-contract, Python 3.9, shell-syntax, HIndent,
  Werror, and diff checks pass;
- the regenerated White Paper remains 65 pages with the profile inventory on
  pages 56 and 57.

Revision `287909f0ad6158c818bdadb4e21b05520f0fac83` is rejected by the
independent pure Haskell Finalreview. Strategy, formalization, and publication
reviews accept it without findings and with 10.0 in every dimension. The
remaining correction closes one finding:

1. Drive Situation and Strategy candidate enumeration from each current target
   Measure instead of repeating pair-wide scans for every Measure. Intersect
   Measure-specific adjacency with `changesSituation`, `surfacesNeed`,
   `qualifiesNeed`, and `directsIntervention`; preserve ascending-set order,
   trace identity, and the public API. Add an adversarial `0, 10, 20, 40`
   target-Measure/live-Situation regression proving affine-linear growth for
   every traversal-work component.

Correction implementation status:

- qualifying Strategies drive target Measures for each addressed
  Intervention/Need pair; Strategies are grouped by Measure before
  Measure-specific Situation indexing;
- every remaining Strategy Action, Need Objective, KPI, and Anchor join uses
  one relation-driven candidate bucket and constant ownership or edge guards;
- eleven private regressions prove affine-linear traversal work across all
  demonstrated fan-out dimensions while preserving trace identity and
  deterministic order;
- the expanded private test contract is separated into runner, contracts,
  shared typed fixtures, and adversarial scenario builders;
- public Core tests, API contracts, HIndent, Werror, Haddock, and the complete
  canonical Haskell verification stage pass;
- one uninterrupted complete repository verification passes the dirty
  correction worktree, including isolated publication rendering;
- one coherent candidate commit, exact clean-revision verification, and four
  independent Finalreviews remain pending.

Revision `859c29de725e7150bc58f59ef15fe8ae8bcc485f` is rejected by the
independent formalization and pure Haskell Finalreviews. Its strategy and
publication scopes are accepted without findings and with 10.0 in every
dimension. The correction closes two performance findings without changing
public semantics or API:

1. Derive complete Situation-attached `TraceCore` values before expanding
   compatible Vision links. Preserve Vision-then-Objective ordering and add a
   `0, 10, 20, 40` regression with complete traces and later-dead-ending
   Primitive spines.
2. Select convergent Intervention Key Results through one smallest-set
   three-way intersection over contribution, Need substantiation, and Measure
   targeting. Add a `0, 10, 20, 40` regression with `1, 11, 21, 41` complete
   traces.

Correction implementation status:

- both joins are output-sensitive and preserve public trace identities,
  deterministic ordering, and the public API;
- both adversarial contracts prove affine traversal work and input-order
  invariance;
- focused public Core, private trace-search, API, Werror, HIndent, and diff
  checks pass;
- complete verification, one exact candidate revision, and independent
  formalization and Haskell Finalreviews remain pending;
- accepted strategy and publication evidence is carried forward only when its
  declared scope is byte-identical at the new revision.

Revision `b5baa3cf45a54d2f295539dfa30cb8b7c870d80c` passes exact clean
repository verification and preserves the accepted strategy and publication
scopes byte-identically. Its Haskell Finalreview rejects two verification
defects:

1. The convergent-Key-Result regression must vary both Strategy and
   Intervention Key Results, share Need and Measure endpoints, pair the two
   families through contribution, and retain `1, 11, 21, 41` traces with
   affine work. Varying only Intervention Key Results does not reproduce the
   former two-dimensional join.
2. Selective-intersection work metrics must count the membership probes
   actually evaluated. The implementation either evaluates both guards
   strictly and counts two probes or records short-circuit evaluation exactly.

The correction changes neither O2I semantics nor public API. It strengthens
the adversarial proof and makes its measurement contract truthful.

Correction implementation status:

- the regression varies `n+1` Strategy and Intervention Key Results with one
  pairwise contribution per valid trace and proves `1, 11, 21, 41` outputs;
- the selective join records exactly one or two membership probes according
  to actual short-circuit evaluation and keeps its `Int` accumulator strict;
- all traversal and index-build vectors grow affinely and preserve exact
  identities and input-order determinism;
- focused Haskell verification and one uninterrupted complete repository
  verification pass the correction worktree.

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
