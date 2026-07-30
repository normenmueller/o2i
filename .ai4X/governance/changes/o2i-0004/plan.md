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

Revision `eebd36fb8cf2361cf2454af613b716f0075f6534` passes exact clean
repository verification. Its formalization Finalreview accepts every
dimension with 10.0; its Haskell Finalreview identifies one remaining
output-sensitivity defect:

1. `primitiveSpines` must start from each Intervention Key Result as the
   relational join node. Pairwise Strategy Actions, Need Objectives, Strategy
   Key Results, and Intervention Key Results must yield `1, 11, 21, 41`
   complete traces with affine work rather than quadratic intermediate paths.

The correction preserves semantics, trace identity, ordering, and public API.
It changes only the private join order and its adversarial proof.

Correction implementation status:

- every complete Primitive spine starts from one Measure-bound Intervention
  Key Result and reaches its Strategy Key Result, Intervention Action, Strategy
  Action, KPI, anchor, Need Driver, and Need Objective through indexed
  relation-selective joins;
- paired Strategy Actions, Need Objectives, Strategy Key Results, and
  Intervention Key Results produce `1, 11, 21, 41` exact traces with affine
  traversal and index-build work for fan-out `0, 10, 20, 40`;
- a separate graph contract proves exact short-circuit membership-probe
  accounting;
- the complete Haskell stage and one uninterrupted repository verification
  pass the correction worktree.

Revision `0f9bce63645adc9ca2628a17213b154d3e9bd0a0` passes exact clean
repository verification. Its independent Haskell Finalreview rejects the
complete TraceSearch architecture:

1. A shared Intervention Key Result with independently varying Strategy Key
   Results and Intervention Actions permits a quadratic intermediate trace
   spine despite linear facts and output.
2. Macro-evidence premise enumeration can materialize a cubic Cartesian
   product before shared bindings reject inconsistent tuples.
3. The current work metric and one-axis fan-out contracts do not measure or
   expose these paths.

Further local join patches are excluded. The target design is one Cabal-private
typed relational rule evaluator shared by macro-evidence and effect-trace
validation. It provides indexed variable-aware joins, distinct existence and
witness-enumeration modes, typed result rows, truthful executor work, canonical
ordering, and independent multi-axis reference contracts.

The evaluator supports only closed O2I proof obligations. Public APIs remain
fachlich named and expose no free query language. Database behavior, arbitrary
analytics, parsing, persistence, optimization, and graph export remain outside
this correction. The evaluator executes metamodel-owned rules and never becomes
a second source of O2I semantics.

The approved relational implementation contract is:

1. `O2I.Validation.Relational.Types`, `.Index`, and `.Eval` form one
   Cabal-private mechanism. Domain-specific rule plans remain in the
   macro-evidence and effect-trace modules.
2. `Plan scope row` is constructed only through `rootAtom`, `extendForward`,
   `extendBackward`, `constrainExisting`, and `finish`. Every extension connects
   a fresh typed variable to the already bound prefix; disconnected subplans
   and independent sibling products are unrepresentable.
3. Rank-2 scoping prevents variables, solutions, and projections from different
   plans being mixed. Scope machinery remains entirely private: domain-rule
   authors require no proxy, visible type application, existential unpacking,
   manual variable key, or general builder type class.
4. Relation endpoint types drive local inference. `Projection scope row` is
   built only from total typed field combinators over hidden matched
   occurrences; arbitrary partial projection functions are excluded.
5. The macro-evidence registry is endpoint-typed and constructs valid plans
   directly. Anchor families expand internally to their four typed relation
   variants. The registry remains the sole semantic authority and the evaluator
   contains no O2I relation names.
6. Evaluation uses variable-at-a-time indexed set intersection. Every new value
   comes from the smallest addressed candidate domain and is intersected with
   every currently evaluable constraint before a binding is extended.
7. The graph index stores sorted unique node domains separately from exact edge
   occurrence lists. Edge occurrences expand only after a complete node binding
   exists. Duplicate persisted evidence therefore remains distinguishable,
   while fachliche trace deduplication occurs only during typed projection.
8. `runExists` short-circuits without constructing rows or witnesses.
   `runEnumerate` returns all witnesses in canonical order. Both modes satisfy
   `runExists rule == not (null (runEnumerate rule))`.
9. Canonical macro order is alternative order followed by the edge-occurrence
   ordinal vector in declared premise order. Canonical trace order is the
   documented `EffectTraceKey` order and is independent of input order.
10. Work accounting records actual domain and bucket probes, candidate-domain
   comparisons, visited domain values, membership probes, binding extensions,
   occurrence reads, complete bindings, canonical insertions, and emitted
   results. Map and Set operations retain their documented logarithmic runtime
   cost.
11. Multi-axis `0, 10, 20, 40` contracts cover sparse, skewed, dense,
   dead-ending, unrelated, and output-heavy macro and trace graphs. A small
   test-only naive evaluator ranges over the complete registry and serves as
   semantic oracle. Compile-pass examples demonstrate representative readable
   rules; compile-fail contracts reject cross-scope variables, endpoint
   mismatches, disconnected plans, and ill-typed projections.
12. `Search.hs` is replaced by focused rule, execution, and projection modules;
    it is not cosmetically split. The existing conservative pre-semantic macro
    scope index remains separate because it operates on raw occurrence-bearing
    facts before a `WellFormedGraph` exists.

The accepted macro-integration lifecycle is:

```text
ContextAssessment
  -> ContextSemantics
  -> prepareMacroEvidence
  -> PreparedMacroEvidence
  -> assessCollectiveStrategyRealizations
  -> SemanticallyValidModel
```

`prepareMacroEvidence :: ContextSemantics -> PreparedMacroEvidence` is total and
runs exactly once per semantic assessment. Rejected Context assessment never
prepares evidence. Pending assessment may prepare evidence and assess
Collective claims but cannot produce a `SemanticallyValidModel`. Accepted
assessment produces that model only after Collective assessment succeeds.
`PreparedMacroEvidence` contains the exact Context semantics, fact and
relational indices, typed Strategy-role domains, compiled macro registry, and
truthful preparation work. The same immutable value is reused by Collective,
Trace, and every later semantic stage.

`TypedStrategyRole primitive` replaces optional untyped role recovery.
Constructive rule definitions make endpoint, scope, connectedness, and
projection defects compile-time failures; preparation remains total.
Collective validation remains independent of the evidence module at the domain
boundary: orchestration supplies the prepared context and Collective consumes
only its narrow typed evidence interface.

Richer public trace diagnostics remain outside this correction because they
change the fachliche API. No generic graph dependency is added: the existing
`containers` indices directly implement the typed lookup and intersection
contract required by O2I.

## Relational Redesign Finalreview

The relational redesign receives independent, capability-distinct
formalization and Haskell Finalreviews after its complete implementation. The
reviewers assess the design itself, not only regression results, and request
clarification whenever O2I purpose or a fachliche invariant is uncertain.

The review must determine whether:

- the mechanism is purpose-fit for O2I's closed, metamodel-owned proof
  obligations without becoming a database, public query language, analytics
  engine, or speculative general framework;
- typed variables, relations, projections, existential bindings, opacity, and
  runtime validation place every guarantee at the strongest proportionate
  boundary;
- semantic ownership remains in the domain registries and rule plans while the
  evaluator stays relation-generic and Cabal-private;
- module and package boundaries are coherent, minimal, idiomatic, documented,
  maintainable, and extensible for foreseeable O2I proof obligations;
- foreseeable new O2I proof obligations can be added through typed
  domain-owned rules and projections without modifying the relational
  evaluator; any later evaluator redesign requires a separately demonstrated
  new class of requirement;
- public APIs remain fachlich named, total, deterministic, and unchanged unless
  an independently justified semantic requirement demands otherwise;
- definition failures, validation failures, and public diagnostics are
  complete, precise, deterministic, provenance-preserving, and handled at the
  correct boundary;
- the executor avoids hidden Cartesian intermediates, reports truthful work,
  and demonstrates appropriate asymptotic behavior under sparse, skewed, dense,
  dead-ending, unrelated, and output-heavy multi-axis inputs;
- tests cover laws, semantic equivalence, invalid definitions, static
  rejections, every diagnostic branch, witness identity and ordering,
  short-circuiting, input permutations, and performance contracts;
- every advanced Haskell construct and every abstraction earns its complexity,
  with no workaround, compatibility layer, decorative type machinery, unsafe
  coercion, or premature type-class generalization.

Acceptance requires no unresolved finding and 10.0 in every required review
dimension. Findings receive one fresh target-state solution and are closed
before the exact revision is accepted.

## Macro-evidence implementation evidence

- the constructive relational suite passes 59/59 contracts;
- the macro-evidence suite passes 38/38 contracts across the declared
  `0, 10, 20, 40` shape matrix;
- an independent list-based oracle agrees with the production evaluator for
  every registered macrorelation;
- representative private rules compile, while cross-scope variables,
  disconnected plans, endpoint mismatches, and ill-typed projections fail
  compilation;
- the complete Core suite and every internal Core suite pass with `-Werror`.

## Rejected macro-evidence implementation

Independent formalization and Haskell reviews reject this implementation
candidate despite its green regression suite. Its successor must:

- retain exact persisted occurrence identity inside opaque macro witnesses
  while keeping the public RawEdge projection;
- store immutable typed domains once and return them without raw-ID recasting
  or per-claim reconstruction;
- replace erased projected-premise lists with scope-local typed occurrence
  handles and total domain-row projections;
- derive relation identity, endpoints, conservative premises, executable rules,
  enumeration, and lookup from one exhaustive typed macrorelation vocabulary;
- measure actual preparation and canonicalization operations without nominal
  counters;
- place shared pre-trace macro evidence directly under `O2I.Validation`.

The constructive connected-plan evaluator, rank-2 scope, one-time semantic
lifecycle, public API, and fachliche semantics remain valid constraints. This
is a type-boundary redesign, not a compatibility patch.

## Proposed macro-evidence type boundary

1. Every relational premise receives a generative token in addition to its
   rank-2 plan scope and endpoint kinds. A type-level `Snoc` shape records the
   exact declaration order of those premise tokens.
2. `Plan`, the complete premise sequence, the evaluator-only matched sequence,
   and `Projection` carry the same shape. Projection consumes that sequence
   structurally. It performs no key lookup, has no `Maybe` or impossible branch,
   and cannot exchange two premises with equal endpoint kinds.
3. Only the evaluator constructs `MatchedPremise` values. Domain rule
   definitions receive typed matched occurrences through total projection
   combinators tied to the exact generative premise handles.
4. One closed `AlternativeShape` GADT stores each constructively connected
   macro-rule alternative exactly once. Total interpreters derive both its
   conservative raw premises and its executable typed plan. The current closed
   shapes are single relation, forward chain, target join, and joined
   chain-with-tail.
5. One exhaustive endpoint-indexed `MacroRelation` GADT contains the fourteen
   O2I macrorelations. Total functions derive conclusion relation, code,
   endpoint witnesses, alternatives, lookup, enumeration, public
   `MacroEvidenceRule` projection, and raw claim reification. The public facade
   remains unchanged.
6. A private `DMap DomainAddress Domain` stores cached owner, Strategy-role,
   Performance-Dimension, and anchor domains. Lawful private `GEq` and
   `GCompare` instances retain the kind index; lookup with
   `DomainAddress kind` can return only `Domain kind`, while absence yields
   `emptyDomain`. Kind mismatch is unrepresentable. Claim compilation never
   recasts raw identifiers or rebuilds shared domains.
7. `MacroEvidenceWitness` stores opaque `(occurrence ordinal, RawEdge)` premise
   occurrences. Public `witnessPremises` remains the total RawEdge projection;
   equality and internal identity retain occurrence ordinals.
8. Canonical rows are inserted into an ordered `Map` per registry alternative
   and emitted by ascending occurrence vector. Work records actual cache,
   registry, and canonical-map operations; no nominal counter remains.
9. Shared preparation and execution live in
   `O2I.Validation.MacroEvidence.{Types,Prepare,Eval}`. Collective, Semantics,
   and Trace consume narrow interfaces over the same opaque prepared value.
10. Compile-fail contracts reject cross-scope, cross-token, endpoint,
    disconnected-plan, and projection-order mismatches. Runtime contracts cover
    complete-registry oracle equivalence, duplicate occurrence identity,
    canonical order, cache reuse, preparation scaling, query scaling, and
    existence short-circuiting.

### Generative projection implementation review

The first implementation candidate preserves the accepted shared Snoc shape,
generative premise identity, and total structural projection. Its focused
relational, macro-evidence, private compile, and complete Core contracts pass.
The independent Haskell implementation review rejects the candidate until:

- matched-row construction, projection application, plan decomposition, and
  occurrence construction are available only through the relational executor
  internals; the author facade excludes them and an import contract prevents
  `O2I.Language.Macro` from importing the executor surface;
- separate negative compile contracts isolate equal-endpoint token order,
  endpoint shape under one scope and token, and matched-row opacity; and
- projected premises are accumulated and materialized in declaration order in
  linear time per emitted row.

The corrected implementation closes all three findings through a safe author
facade, an executor-internal kernel guarded by a lexically complete import
contract, orthogonal negative compile contracts, and linear difference-list
materialization. Relational `59/59`, macro-evidence `38/38`, public semantic
`297/297`, all Core suites, eight import-checker tests, and all compile/import
contracts pass. The renewed independent Haskell implementation review reports
no finding and scores Typtheorie/Formalisierung, Haskell design, totality,
ergonomics/clarity, tests/contracts, robustness/extensibility, performance, and
proportionality at 10.0 each.

### Closed vocabulary implementation review

The first closed-vocabulary implementation makes `AlternativeShape` the one
rule representation and derives conservative and executable semantics through
total interpreters. Its complete Core, registry-oracle, import, and compile
contracts pass. The independent Haskell review rejects two remaining API-design
defects:

- `MacroRelationIndex` repeats the fourteen-relation inventory without making
  completeness constructive; direct `SomeMacroRelation` enumeration must
  replace it while the independent completeness test remains;
- the unused `lookupTypedMacroEvidenceRule` surface must be removed because
  executable compilation already receives the exact typed relation through its
  `MacroClaim`.

No semantic or public API change is required. The correction removes both
surfaces and repeats the focused review.

The correction removes both surfaces. The direct existential enumeration is
checked for exact equality and duplicate freedom against the general
macrorelation registry. The renewed independent Haskell review reports no
finding and scores Typtheorie/Formalisierung, Haskell design, totality,
ergonomics/clarity, tests/contracts, robustness/extensibility, performance, and
proportionality at 10.0 each.

### Typed domain-cache implementation review

The private `DMap DomainAddress Domain` cache retains complete `NodeKind`
indices for owned Primitives, Strategy roles, Performance Dimensions, and
Situation Anchors. Lawful total `GEq` and `GCompare` instances make kind
mismatch unrepresentable; a missing address yields `emptyDomain`. The cache is
built once and reused by every claim. Its focused contracts pass, and the
independent Haskell review reports no finding and 10.0 in all eight dimensions.

### Occurrence and work implementation review

The first occurrence-aware implementation retains exact edge occurrences and
uses stable ordered collision buckets per alternative. Its focused and complete
Core contracts pass. The independent Haskell review rejects two boundaries:

- public `Eq` and `Show` must remain projections of `NonEmpty RawEdge`, while a
  private operation compares exact occurrence identity;
- preparation work must be accumulated at actual DMap lookups and insertions,
  registry insertions, and plan instantiations. Nominal formulae and duplicate
  counters are excluded.

The correction preserves public witness equality and rendering over
`NonEmpty RawEdge` while a private comparator retains exact occurrence
identity. Canonical rows use ordered collision buckets and never drop distinct
rows with the same ordinal vector. One strict private operation accumulator
records actual DMap lookups and insertions, Claim reads, registry insertions,
and plan instantiations at their execution sites; selector-derived formulae and
duplicate nominal counters are absent. A fixed baseline and independent
domain-member and Claim deltas verify the contract without reconstructing the
rule vocabulary. The focused 70-contract macro-evidence suite, every Core
suite, HIndent, and compile/import contracts pass. Its bounded independent
Haskell review accepts the Witness and canonicalization contracts but rejects
two remaining lazy work boundaries:

- an updated Domain must be forced before its DMap lookup and insertion are
  counted; and
- a `CompiledPlan` must be forced before its plan instantiation is counted.

The correction uses private strict preparation-result boundaries and adds a
focused strictness contract. Scattered `seq` patches, deep evaluation, unsafe
instrumentation, and public test hooks remain excluded.

The focused suite passes 71/71 contracts. The renewed independent Haskell
review reports no finding and scores every required dimension at 10.0. It
accepts both strict preparation boundaries and confirms both original
occurrence-and-work findings as closed.

### Macro-evidence module-ownership review

Shared preparation and execution reside under
`O2I.Validation.MacroEvidence.{Types,Prepare,Eval}`. Semantics prepares one
immutable value; Collective consumes its narrow typed evidence interface and
Trace reuses the accepted model's prepared value. The former Trace-owned
evidence hierarchy and all references to it are absent. Focused and complete
Core verification, compile/import contracts, HIndent, and Cabal check pass.
The bounded independent Haskell review reports no finding and scores every
required dimension at 10.0.

### Typed effect-trace rule package

The current package replaces the private list-bind
`O2I.Validation.Trace.Search` architecture with focused domain-owned rule,
projection, and execution modules over the accepted private relational
mechanism. It preserves the public trace API, `EffectTraceKey` identity,
canonical order, diagnostics, and O2I semantics. The existing fourteen
adversarial trace contracts remain required and gain a small complete semantic
oracle plus independent multi-axis performance contracts. `Search.hs` is
removed without a compatibility module. Design receives bounded external
review before implementation; the completed package receives a distinct
bounded independent Haskell review.

The accepted design uses three closed responsibilities:

1. `AddressedNeedRule` derives diagnostic obligations independently of trace
   completeness.
2. `EffectTraceContextRule` derives one connected Vision, Strategy, Need,
   Intervention, Measure, and Situation Skeleton from the nine required
   Context relations.
3. `EffectTraceConstituentRule anchor` derives one complete owner-specific
   Primitive, Strategy-role, Performance-Dimension, and anchor proof for one
   Skeleton. The four anchor constructors remain static GADT alternatives.

Every one of the eighteen trace constituents is an endpoint of a required
premise. The relational facade therefore gains one opaque endpoint-indexed
`ProjectedOccurrence from to` and a total shape-, token-, order-, and
endpoint-preserving projection fold. It exposes typed endpoints, ordinal, and
edge but never bindings, matched rows, constructors, or positional lists. A
separate binding projection is excluded unless a future admitted closed O2I
obligation genuinely projects a value that is not a premise endpoint.

Independent Co-Author and formalization reviews accept this decomposition as
formally correct, purpose-fit, and performance-safe. They reject monolithic
model-wide rules, independently joined constituent fragments, Raw-ID casts,
positional decoding, generic dependent-query combinators, and untyped anchor
families.

The endpoint-typed occurrence projection implementation passes Relational
60/60, MacroEvidence 71/71, Core `-Werror` build, every compile/import
contract, HIndent, and `git diff --check`. Its bounded independent Haskell
review determines whether this new private authoring boundary is accepted
before any Trace module consumes it.

The first bounded review rejects two defects:

- erased-premise and endpoint-typed projections share one unindexed sum, which
  leaves cross-mode composition and one dead representation branch possible;
- runtime coverage does not compare complete typed occurrence signatures or
  prove that duplicate edge ordinals survive the typed projection.

The correction indexes `Projection` by one closed mode consumed existentially
by `finish` and execution. Each authoring family inhabits only its own mode,
mixed branches disappear constructively, and a compile-fail contract rejects
cross-mode composition. Runtime contracts compare complete source, relation,
target, and ordinal signatures and retain distinct duplicate occurrences.

The correction passes Relational 61/61, MacroEvidence 71/71, Core `-Werror`,
all compile/import contracts, HIndent, and `git diff --check`. The renewed
bounded independent Haskell review reports no finding and scores every
required dimension at 10.0. The endpoint-typed occurrence projection is
accepted for use by the Effect-Trace rules.

Four total Cabal-private accessors expose only exact typed domains from the
shared `PreparedMacroEvidence`: owner/Context/Primitive, Strategy formulation
role, Performance-Dimension role, and Situation/anchor kind. Missing exact
addresses yield `emptyDomain`; `MacroDomainIndex`, `DomainAddress`, DMap, raw
casts, and preparation-work internals remain hidden. Focused contracts cover
all role and anchor alternatives, missing addresses, and distinct owner
identities. MacroEvidence 73/73, Relational 61/61, every Core suite with
`-Werror`, compile/import contracts, HIndent, and `git diff --check` pass. The
bounded independent Haskell review reports no finding and scores every
required dimension at 10.0.

The following bounded package defines internal typed Trace result records and
the three accepted declarative rules without switching the public evaluator:
`AddressedNeedRule`, `EffectTraceContextRule`, and the four static
`EffectTraceConstituentRule` anchor alternatives. Execution integration,
diagnostics, oracle replacement, performance matrices, and deletion of
`Trace.Search` remain separate subsequent packages.

The package compiles each rule through the accepted constructive relational
facade. Every projected Context or constituent identifier comes from one
endpoint-typed required-premise occurrence. Four orthogonal negative compile
contracts reject cross-scope variables, endpoint mismatch, occurrence-order
mismatch, and anchor mismatch; one readable positive contract instantiates all
four static anchor alternatives. Complete Core tests with `-Werror`,
compile/import contracts, HIndent, and `git diff --check` pass. A bounded
independent Haskell/formalization review first rejects one local readability
finding. The correction replaces numbered projection stages with semantically
named cumulative proof stages and renders the typed occurrence callback
vertically without splitting the connected proof. The renewed review reports
no finding and scores every required dimension at 10.0.

The accepted execution-integration design adds private `Trace.Eval` and moves
the Trace representation behind total typed construction in `Trace.Types`;
`Trace.hs` continues to reexport the unchanged public API. Evaluation reuses
one prepared relational index, derives addressed Needs independently, derives
Context skeletons once, and executes only nonempty static anchor alternatives
per skeleton. Exact `EffectTraceId` canonicalization preserves public
deduplication and `Map.elems` order. Coverage derives only from canonical
traces; diagnostics remain `MissingMacroEvidence` first, followed by
Intervention diagnostics in ascending identifier order. Work records only
actual relational evaluation, canonicalization, anchor-domain inspection, and
executed constituent plans. `Trace.Search` is deleted only after semantic,
diagnostic, oracle, and multi-axis contracts pass.

Execution integration is split into two bounded packages. Package 4a changes
only private Trace representation, `Trace.Eval`, the unchanged public facade,
and Cabal registration. Package 4b then adds the private Eval runner, fixtures,
contracts, and compile/import checks. This keeps production architecture and
verification architecture independently reviewable before the old Search
module is removed.

The bounded Package 4a review accepts its typed execution architecture but
rejects two closure gaps. Package 4b completes the operation-bound work
contract by counting Intervention enumeration and incremental typed coverage
construction, tests every work component directly, and locks the unchanged
public `Show EffectTrace` representation. `Trace.Search` remains untouched
until this corrected Eval boundary passes renewed independent review.

The corrected Eval boundary passes 8/8 private evaluator contracts, 298/298
public Core contracts, complete Core and compile/import verification, Cabal
check, HIndent, and diff checks. Its renewed independent review reports no
finding and 10.0 in every required dimension. `Trace.Search` can now be
replaced by Eval-owned oracle and multi-axis contracts and then removed without
a compatibility module.

Package 5a establishes replacement evidence before deletion. It ports every
material semantic and multi-axis contract to the Eval-owned private suite and
adds an independent naive trace oracle that does not consume Trace rules,
plans, or evaluator code. Production modules and the existing Search component
remain unchanged. Package 5b removes Search only after Package 5a passes
focused verification and bounded independent review.

The first Package 5a review rejects three test-only gaps. Its correction uses a
semantically admitted family of unconstituted anchors, applies one canonical
permutation to a multi-result scenario, and compares typed coverage exactly
with an independent Oracle including false addressed pairs. Production and
Search remain byte-identical throughout this correction.

The corrected Package 5a passes 22/22 focused Eval contracts, every Core suite,
compile/import contracts, Cabal check, HIndent, and diff checks. Its renewed
independent Haskell review reports no finding and 10.0 in every required
dimension. The Eval-owned semantic oracle and multi-axis contracts are accepted
as the verification authority required before Package 5b removes
`Trace.Search` and its private test suite without a compatibility module.

Package 5b removes `Trace.Search`, its private runner and its three private test
modules, and only their Cabal registrations. No compatibility module remains.
Every Core suite, compile/import contract, Cabal check, Haddock, HIndent, and
diff check passes. The bounded independent Haskell review confirms that all
fourteen material Search axes remain owned by Package 5a, reports no finding,
and scores every required dimension at 10.0.

The exact formalization and pure Haskell Finalreviews independently accept
revision `d36ece6529ce43da890e762bf38470fb3e1932d1` without findings and with
10.0 in every required dimension. The complete repository gate remains open
until one exact candidate revision containing the synchronized 69-page PDF and
manifest passes isolated repository verification and all four required
Finalreviews bind that same revision.

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
