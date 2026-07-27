# Scope

Load for `mdl/o2i.archimate`, semantic Views, concrete syntax, snapshots, or
instance-conformance work.

# Semantic And Syntax Discipline

- Treat ArchiMate as notation, never as the source of O2I semantics.
- Semantic Views visualize the metamodel. Syntax Views visualize the concrete
  mapping defined by `spc/ctr/archimate/profile.json` and introduce no
  independent fachliche semantics.
- Semantic Views render O2I metamodel elements as plain boxes with solid
  outlines. This is a readability convention only and carries no formal
  semantics.
- Audit Semantic Views as complete metamodel projections: verify View purpose,
  elements, relations, directions, labels, completeness, and visual
  representation. A naming audit alone is insufficient.
- Semantic metatype and type labels use their canonical unprefixed names, such
  as `Context`, `Principle`, and `Situation Anchor`. The View already supplies
  the O2I namespace.
- Abstract closed types use the same solid-box convention as other metamodel
  elements. Their abstraction is stated explicitly in View documentation,
  never encoded through dotted borders, color, or layout.
- Syntax Views map semantic types, relation families, metadata, and structured
  patterns to ArchiMate notation. They never repeat a complete semantic graph
  merely to illustrate the mapping.
- `O2I Syntax` is the complete reference visualization of the declarative
  profile contract. Add a focused presentation excerpt only when a concrete
  publication need requires it; such an excerpt reuses the exact persisted
  mapping elements and relationships and introduces no independent contract.
- Keep carrier mappings, relation mappings, and non-trivial syntax patterns
  explicit:
  - carrier mappings define which ArchiMate element represents an O2I type;
  - relation mappings define ArchiMate relationship type, direction, and
    naming;
  - pattern Views define syntax that cannot be expressed by one binary mapping,
    such as contextualization or collective Strategy realization.
- Represent a semantic-to-ArchiMate carrier mapping only as
  `O2I Type --association[maps-to]--> ArchiMate Construct`. `maps-to` is a
  directed, mapping-only ArchiMate Association and never an O2I relation or
  executable instance syntax.
- Reuse the exact persisted semantic metamodel element as the source of a
  type-specific mapping. Never create a prefixed duplicate such as
  `O2I Principle`.
- A closed type may define one family-level carrier mapping only when every
  constructor shares the same ArchiMate representation. `Context` therefore
  maps once to `ArchiMate Grouping`; its constructors are documented by the
  closed Context registry.
- A closed type with heterogeneous representations maps each constructor
  separately. `Situation Anchor` therefore remains the abstract family while
  Business Capability, Business Process, Business Object, and Value Stream map
  individually.
- Keep unannotated mapping Views distinct from executable Candidate conformance
  Views. Never reuse one persisted element across those levels.
- Mapping Views represent types only. Their semantic sources use canonical
  unprefixed labels such as `Principle`; their notation targets identify the
  ArchiMate construct, such as `ArchiMate Principle`. Neither side contains
  fachliche names or `<Name>` placeholders.
- Executable conformance Views may use `<Name> :: O2I <Type>` for typed
  carriers. Fachliche instances retain their domain names; O2I typing follows
  exclusively from profile metadata and graph structure.
- Contextualization is only
  `Context --composition[contextualizes]--> element`; visual nesting is
  presentational.
- Mapping-only Views are checked reference visualizations, not O2I graphs.
- `spc/ctr/archimate/profile.json` is the exact mapping authority.
  `O2I Syntax` must completely visualize it.
- Executable conformance and instance Views require Haskell `o2i inspect`.

# Model Documentation

- Keep model documentation minimal and subordinate to its owning authority.
- Semantic metatypes carry one concise definition and a reference to the
  corresponding White Paper section; they never duplicate literature anchors
  or complete fachliche definitions.
- Mapping exemplars carry no independent fachliche documentation.
- Every View states only its purpose, authority boundary, and reading.
  Conformance Views may additionally identify their exact profile-contract
  reference.
- Illustrative elements and relations may carry one concise reading.
- Never copy complete registries, profile mappings, source apparatus, or
  publication prose into the model.

# Model Editing

- Never edit `mdl/o2i.archimate` directly.
- Guide the user through one small Archi change at a time.
- After every saved model change:
  1. read the model freshly;
  2. regenerate all snapshots;
  3. run repository View-contract and snapshot checks;
  4. run Python extractor tests;
  5. run Haskell inspection for every affected executable View;
  6. inspect affected PNG exports when available.

# Tool Responsibilities

- The Python model-hygiene audit checks only repository structure: identifiers,
  references, model usage, custom folders, and View documentation.
- The Python extractor checks only named repository Views, labels,
  documentation, displayed relation signatures, and snapshots.
- AMX validates concrete O2I profile metadata and projects selected Views.
- Core/Inspection validates notation-independent O2I structure and semantics.

# Commands

```text
python3 -B utl/audit-archimate-model.py
python3 -B utl/extract-archimate-view.py --preset all
python3 -B utl/extract-archimate-view.py --preset all --check
python3 -B -m unittest discover -s utl -p 'test_*.py'
cabal --project-dir=spc run o2i -- inspect MODEL --view "VIEW"
```
