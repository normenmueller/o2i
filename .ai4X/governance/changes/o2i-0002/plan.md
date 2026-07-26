# O2I-0002 Implementation Plan

Author: `normenmueller`

Co-Author: `external-syntax-coauthor`

## Affected Surfaces

- ArchiMate semantic, mapping, and pattern Views;
- concrete syntax View documentation and snapshots;
- repository extractor contracts and tests;
- AMX representation registry and conformance tests;
- White Paper, WTF, README, specification README, and Haddock;
- Agent Memory, changelog, and verification.

## Required Finalreview Capabilities

- strategy;
- formalization;
- Haskell;
- agentic AI.

## Design Contract

O2I follows semantic-to-notation separation:

- semantic Views define notation-independent O2I types and admissible
  relations;
- mapping Views define ArchiMate carriers, relationship representations, and
  metadata contracts without repeating semantic graphs;
- pattern Views define executable syntax for non-trivial constructs;
- executable conformance carriers remain distinct from unannotated mapping
  exemplars;
- shape, color, border, and layout carry no O2I semantics.

The design follows the separation principle used by the ArchiMate 3.2
Specification where it benefits O2I; O2I defines its own complete mapping.

`O2I Type --association[maps-to]--> ArchiMate Construct` is the generic
carrier-mapping form. `maps-to` is a persisted, directed ArchiMate Association
used only between unannotated mapping-only elements in mapping Views. It is
neither an O2I relation nor executable instance syntax.

Semantic mapping sources use their canonical unprefixed names and reuse the
exact persisted metamodel elements. Abstract closed types use family-level
mappings only for uniform representations; heterogeneous representations map
their constructors individually.

## Target Views

- `O2I Syntax`: single normative mapping View for all carriers, registered
  relation representations, metadata contracts, and pattern references.
- `O2I Syntax - Context`, `O2I Syntax - Primitives`, and
  `O2I Syntax - Situation`: presentation-only excerpts that reuse the exact
  persisted mapping objects from `O2I Syntax` and introduce no independent
  contract.
- `O2I Syntax - Contextualization`: executable Candidate pattern View.
- `O2I Syntax - Collective Strategy Realization`: executable Candidate pattern
  View.

## Steps

1. Preserve the semantic View topology and apply the plain solid-box convention
   to metamodel elements as presentation only.
2. Establish `O2I Syntax` as the single normative mapping View and build its
   compact Context section:
   - `Context --association[maps-to]--> ArchiMate Grouping`;
   - document `Context` as the abstract closed type whose eight constructors
     share this representation;
   - one concrete directed Association exemplar for an O2I Context relation;
   - closed Context type, relation-signature, carrier, relation, metadata, and
     model-profile contracts in View documentation.
3. Add the Primitive section by reusing the existing semantic Primitive type
   elements as mapping sources, plus one concrete
   exemplar per used ArchiMate relationship representation. Keep the complete
   registered signature table in View documentation.
4. Add the Situation section by retaining `Situation Anchor` as the abstract
   closed type and mapping every heterogeneous SituationAnchor constructor
   individually, plus the registered anchor relation representations.
5. Create focused Context, Primitives, and Situation presentation excerpts from
   the exact persisted master mapping objects.
6. Keep Contextualization and Collective Strategy Realization as distinct,
   executable Candidate pattern Views and verify their metadata and topology.
7. Align the AMX registry with the mapping authority. Context macrorelations
   use directed ArchiMate Associations; notation-independent relation semantics
   remain unchanged.
8. Add closed completeness checks for every registered carrier type and
   relation signature, Candidate and Asserted conformance tests, and negative
   mapping/profile cases.
9. Synchronize extractor presets, View contracts, snapshots, PNG exports,
   model documentation, publication text, Haddock, and changelog.
10. Audit every semantic View in full after View roles are stable:
    - verify its purpose, elements, relations, directions, labels, completeness,
      and visual representation against the metamodel;
    - then audit semantic, mapping, excerpt, pattern, and illustration View
      names as one coherent naming system.
11. Run focused and repository-wide verification.
12. Obtain independent Finalreviews for one exact implementation revision and
    accept only without findings and with 10.0 in every required dimension.

## Required Checks

- all repository View extraction and snapshot checks;
- Python extractor and governance tests;
- Haskell formatting, build, tests, and Haddock;
- AMX mapping-completeness and conformance suites;
- focused Candidate and Asserted model inspection;
- publication expansion, references, figures, and PDF rendering;
- repository-wide staged verification;
- generic-content and diff checks.

## Non-goals

- changing O2I terminology or notation-independent semantics;
- introducing instance-specific content;
- inspecting mapping Views as executable O2I graphs;
- treating `maps-to` as an O2I relation;
- replacing dedicated non-trivial pattern Views with prose;
- reproducing ArchiMate presentation choices without an O2I benefit.
