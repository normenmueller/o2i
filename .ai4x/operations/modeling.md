# Scope

Load for `mdl/o2i.archimate`, semantic Views, concrete syntax, snapshots, or
instance-conformance work.

# Semantic And Syntax Discipline

- Treat ArchiMate as notation, never as the source of O2I semantics.
- Semantic Views visualize the metamodel. Syntax Views visualize the concrete
  mapping defined by `spc/ctr/archimate/profile.json` and introduce no
  independent fachliche semantics.
- Prefer plain boxes with solid outlines for O2I metamodel elements in
  reference Semantic Views. Consistent reference presentation is an editorial
  recommendation assessed through visual review, not a mandatory model
  conformance condition.
- Colors, fonts, and Grouping outline styles in O2I instances do not affect
  O2I conformance unless the authoritative notation/Profile contract explicitly
  assigns meaning to them. Preserve every existing meaning-bearing carrier,
  relationship, direction, and metadata requirement.
- Do not add a product presentation validator, CLI command or option,
  validation level, API, or styling engine for reference-diagram cosmetics.
  A future meaning-bearing graphical distinction requires an explicit,
  justified definition in its owning notation/Profile contract; its product
  checks belong in O2I libraries and the O2I CLI, without parallel shell/Python
  rule logic. This conditional boundary creates no speculative capability.
- Audit every Semantic View as a purpose-bounded metamodel visualization:
  verify its purpose, elements, relations, directions, labels, consistency
  within scope, and visual representation. No single View must project the
  complete metamodel; a naming audit alone is insufficient.
- Semantic metatype and type labels use their canonical unprefixed names, such
  as `Context`, `Principle`, and `Situation Anchor`. The View already supplies
  the O2I namespace.
- The same editorial recommendation applies to abstract closed types. State
  their abstraction explicitly in View documentation; do not introduce
  `dashed = abstract` or another border-, color-, or layout-based encoding.
- Syntax Views map semantic types, relation families, metadata, and structured
  patterns to ArchiMate notation. They never repeat a complete semantic graph
  merely to illustrate the mapping.
- `O2I Syntax - Carriers` and `O2I Syntax - Relations` jointly form the complete reference visualization of carrier mappings and applicable relation-mapping families. The former owns carrier projection; the latter owns relation-family projection. Focused syntax Views own metadata-bearing or non-binary patterns that cannot be represented by those two mapping Views, including contextualization, structured propositions, and qualification proposals. Every such current Profile mapping requires one checked focused visualization; each View reuses the exact persisted mapping elements and relationships and introduces no independent contract.
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
- Illustrative Views explain a conceptual reading without claiming executable
  profile or conformance status. `O2I Layered Cake` is such a non-executable
  overview; its repository contract is checked without executable Haskell
  conformance evaluation.
- `spc/ctr/archimate/profile.json` is the exact mapping authority. `O2I Syntax - Carriers`, `O2I Syntax - Relations`, and the focused syntax Views must jointly visualize every current mapping class without creating a parallel registry.
- Executable conformance and instance Views require the current Haskell
  AMX/Profile/Core integration check in addition to the repository View
  contract.

# ArchiMate Applicability Review

- Decide element and relationship applicability from the ArchiMate 3.2 relationship matrix, not from diagram appearance or a relationship definition in isolation. An exact Archi implementation matrix may provide reproducible supporting evidence when its version and symbol mapping are identified.
- Require an independent TOGAF/ArchiMate reviewer when a material decision disputes or changes an ArchiMate carrier, endpoint applicability, relationship type, derived relationship, or concrete profile mapping. Routine model maintenance does not activate this reviewer.
- Review ArchiMate validity, O2I semantic fidelity, profile consistency, and validator consequences as separate conclusions.

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
- The Python extractor checks named repository Views and snapshots together
  with their exact repository visualization contracts projected from the
  current Profile and bound Core companion: carrier and relation families,
  focused metadata, references, and topology. It validates no fachliche
  instance semantics and owns no parallel mapping registry.
- AMX decodes native model evidence losslessly; the compiled Profile applies
  the concrete mapping and projects selected Views.
- Core validates notation-independent O2I structure and semantics. Operation
  composes acquisition, adapter/Profile resolution, View selection, and the
  current preparation boundary.

# Commands

```text
python3 -B utl/model/audit-archimate-model.py
python3 -B utl/model/extract-archimate-view.py --preset all
python3 -B utl/model/extract-archimate-view.py --preset all --check
python3 -B -m unittest discover -s utl/model -p 'test_*.py'
./utl/verify.sh model
./utl/verify.sh foundation
```
