# Scope

Load for `meta/o2i.archimate`, semantic Views, concrete syntax, snapshots, or
instance-conformance work.

# Semantic And Syntax Discipline

ArchiMate is notation, never semantic authority. Semantic Views visualize the
metamodel; syntax Views visualize `spec/ctr/archimate/profile.json`, the exact
mapping owner. Neither introduces independent fachliche semantics.

## Presentation And Semantic Views

- Prefer plain solid-outline boxes, including abstract closed types. This is
  visual-review guidance, not conformance. Document abstraction explicitly;
  never encode it through dashes, borders, colors, or layout.
- Colors, fonts, and Grouping outlines affect conformance only when the owning
  notation/Profile contract assigns explicit meaning. Preserve meaning-bearing
  carriers, relationships, directions, and metadata.
- Add no cosmetic product validator, CLI command/option, validation level, API,
  or styling engine. A meaning-bearing graphical distinction requires a
  justified definition in the notation/Profile owner; checks belong in O2I
  libraries and CLI, never parallel shell/Python logic. This permits no
  speculative capability.
- Audit each Semantic View's purpose, elements, relations, directions, labels,
  scoped consistency, and visual representation. Naming alone is insufficient;
  no View must project the complete metamodel.
- Use canonical unprefixed metatype/type labels: `Context`, `Principle`,
  `Situation Anchor`. The View supplies the O2I namespace.

## Mapping Coverage And Identity

`O2I Syntax - Carriers` owns carrier projection; `O2I Syntax - Relations` owns
applicable relation-family projection, including relationship type, direction,
and naming. Focused syntax Views cover metadata-bearing and non-binary patterns
not expressible there: contextualization, structured propositions, qualification
proposals, and collective Strategy realization. Each such current Profile
mapping requires one checked focused visualization. Together these Views cover
every current mapping class without a parallel registry or repeated complete
semantic graph.

- Reuse exact persisted mapping elements/relationships and semantic metamodel
  sources. Never create prefixed duplicates such as `O2I Principle`.
- Carrier mappings use only
  `O2I Type --association[maps-to]--> ArchiMate Construct`: a directed,
  mapping-only ArchiMate Association, never an O2I relation or instance syntax.
- Map a closed family once only when all constructors share its representation:
  `Context` maps to `ArchiMate Grouping`, with constructors in the Context
  registry. Otherwise map constructors individually: `Situation Anchor`
  remains abstract; Business Capability, Business Process, Business Object,
  and Value Stream each map separately.
- Mapping Views contain types only: canonical semantic names (`Principle`)
  and named notation constructs (`ArchiMate Principle`), without fachliche
  names or `<Name>` placeholders.
- Never reuse a persisted element between unannotated mapping and executable
  Candidate conformance Views. Executable typed carriers may use
  `<Name> :: O2I <Type>`; fachliche instances retain domain names. Only Profile
  metadata and graph structure determine O2I typing.
- Contextualization is
  `Context --composition[contextualizes]--> element`; nesting is presentational.

## View Verification Classes

| Class | Required verification |
| --- | --- |
| Mapping-only | Repository reference-visualization contract; not an O2I graph |
| Illustrative | Repository contract and conceptual reading; no executable Profile/conformance claim or Haskell conformance evaluation (`O2I Layered Cake`) |
| Executable conformance or instance | Repository View contract plus current Haskell AMX/Profile/Core integration |

# ArchiMate Applicability Review

- Decide applicability from the ArchiMate 3.2 relationship matrix. Diagram appearance or an isolated relationship definition is insufficient. An exact Archi implementation matrix is supporting evidence only with identified version and symbol mapping.
- Require independent TOGAF/ArchiMate review for material disputes or changes to carriers, endpoint applicability, relationship types, derived relationships, or concrete Profile mappings; routine maintenance does not trigger it.
- Review ArchiMate validity, O2I semantic fidelity, profile consistency, and validator consequences as separate conclusions.

# Model Documentation

Keep documentation minimal and subordinate to its owner:

| Subject | Allowed documentation |
| --- | --- |
| Semantic metatype | One concise definition and corresponding White Paper section |
| Mapping exemplar | No independent fachliche documentation |
| View | Purpose, authority boundary, reading; conformance Views may add exact Profile-contract reference |
| Illustrative element/relation | One concise reading |

Never copy literature anchors, complete fachliche definitions, registries,
Profile mappings, source apparatus, or publication prose into the model.

# Model Editing

- Never edit `meta/o2i.archimate` directly.
- Guide the user through one small Archi change at a time.
- After every saved model change:
  1. read the model freshly;
  2. regenerate all snapshots;
  3. run repository View-contract and snapshot checks;
  4. run Python extractor tests;
  5. run Haskell inspection for every affected executable View;
  6. inspect affected PNG exports when available.

# Tool Responsibilities

- Python hygiene: identifiers, references, usage, custom folders, View documentation.
- Python extractor: named Views/snapshots against visualization contracts from
  current Profile and bound Core companion; carrier/relation families, focused
  metadata, references, topology. No fachliche instance validation or parallel
  mapping registry.
- AMX: lossless native decode. Compiled Profile: mapping and selected-View projection.
- Core: notation-independent structure/semantics. Operation: acquisition,
  adapter/Profile resolution, View selection, and preparation.

# Commands

Apply `local-verification.md` before local execution.

```text
python3 -B utl/model/audit-archimate-model.py
python3 -B utl/model/extract-archimate-view.py --preset all
python3 -B utl/model/extract-archimate-view.py --preset all --check
python3 -B -m unittest discover -s utl/model -p 'test_*.py'
./utl/verification/local.sh model
./utl/verification/local.sh foundation
```
