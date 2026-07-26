# O2I-0002: Lean ArchiMate Syntax Mapping

Author: `normenmueller`

## Problem

Concrete syntax Views repeat complete O2I semantic graphs while replacing
metamodel elements with ArchiMate carriers. This conflates semantic
admissibility with notation mapping, duplicates normative information, and
creates avoidable drift between semantic and syntax Views.

## Minimal Generic Case

An O2I user needs to determine how one O2I Context and one O2I Context
relation are represented in ArchiMate. The concrete syntax must answer carrier,
relationship, direction, naming, metadata, and pattern questions without
restating the complete O2I Context graph.

## Users

- practitioners expressing O2I models in ArchiMate;
- tool authors validating or transforming concrete O2I syntax;
- authors and reviewers maintaining semantic and syntax Views;
- agentic AI agents synchronizing the model, specification, and publication.

## Benefit

Compact mapping Views make the semantic/syntactic boundary explicit, reduce
duplication, and provide direct contracts for ArchiMate carriers, relations,
metadata, and structured patterns. Readers can understand concrete syntax
without mistaking a notation mapping for a second semantic source.

## O2I Fit

O2I distinguishes notation-independent semantics from concrete syntax. The
change preserves existing semantics and makes their ArchiMate representation
more explicit and independently maintainable.

## Completeness Contract

The concrete syntax mapping is closed over the current O2I language:

- every O2I carrier family and type has exactly one ArchiMate representation;
- every registered O2I relation signature has exactly one ArchiMate
  relationship representation, direction, and naming contract;
- `o2i.profile`, `o2i.kind`, `o2i.type`, `o2i.commitment`, and
  pattern-specific metadata have explicit placement and value contracts;
- Contextualization and Collective Strategy Realization retain dedicated
  pattern mappings;
- unannotated mapping exemplars and executable Candidate or Asserted
  conformance carriers remain distinct persisted elements and Views.

Mapping completeness is checked against the notation-independent type and
relation registries. Adding a registered O2I type or relation without one
concrete mapping is invalid.

## Authority And Verification

Syntax Views and their View documentation define the concrete ArchiMate mapping
authority. O2I Context macrorelations map to directed ArchiMate Association
Relationships; their O2I names and endpoint signatures remain
notation-independent semantic contracts.

The AMX adapter implements exactly the declared concrete mapping. This changes
only concrete profile validation and projection, never notation-independent
O2I semantics. Repository extractor contracts check mapping Views and their
documentation. AMX tests check Candidate and Asserted conformance, negative
profile cases, and mapping completeness for every registered O2I carrier type
and relation signature.

## Alternatives

- Retaining complete mirrored graphs preserves visual familiarity but duplicates
  semantic topology and increases drift risk.
- Defining syntax only in prose is compact but weakens visual traceability and
  repository checks.
- One monolithic syntax View would combine simple mappings and complex patterns
  into an unnecessarily dense diagram.

## Non-goals

- changing O2I terminology, semantic relations, or admissibility;
- changing Haskell graph or validation semantics;
- introducing instance-specific content;
- encoding formal meaning through colors, borders, or layout;
- removing dedicated Views for contextualization, collective Strategy
  realization, or other non-trivial syntax patterns.

## Risks

- An overly generic mapping may omit required metadata or relation constraints.
- Mapping and executable conformance examples may be mixed again unless they
  remain separate persisted elements and Views.
- Too many mapping Views may recreate the duplication at a different level.

The target design therefore separates compact carrier and relation mappings
from dedicated non-trivial syntax patterns and executable conformance fixtures.

## Dependencies

None.
