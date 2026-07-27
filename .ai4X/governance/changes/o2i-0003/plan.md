# O2I-0003 Implementation Plan

Author: `normenmueller`

Co-Author: `external-profile-contract-coauthor`

## Affected Surfaces

- declarative ArchiMate profile contract;
- White Paper concrete-syntax projection;
- ArchiMate reference and conformance View checks;
- Haskell AMX registry completeness tests;
- repository verification, Agent Memory, and changelog.

## Required Finalreview Capabilities

- strategy;
- formalization;
- Haskell;
- publication;
- agentic AI.

## Design Contract

`spc/contract/archimate-profile.json` is the finite, declarative authority for
exact concrete ArchiMate mappings. It contains only carrier mappings, metadata
placement, context-sensitive relationship representations, and structured
pattern representations.

The White Paper remains the normative fachliche publication and includes a
deterministically generated readable projection of the contract. The Haskell
core remains the notation-independent formalization. The AMX adapter executes
profile validation and projection. The ArchiMate model visualizes the contract
and provides reference and conformance Views without introducing independent
semantics.

## Steps

1. Classify every current ArchiMate View-documentation statement by authority
   and preserve all unique fachliche content.
2. Define the finite JSON contract and its closed mapping registries.
3. Implement a deterministic renderer for the White Paper profile fragment and
   include the generated fragment without exposing raw JSON structure.
4. Add repository checks comparing `O2I Syntax` and its focused excerpts with
   the contract.
5. Add Haskell tests comparing the complete AMX representation registry with
   the contract.
6. Move unique fachliche explanations into the White Paper, then reduce View
   documentation to purpose, boundary, profile version, and contract reference.
7. Update repository authority contracts, technical documentation, changelog,
   snapshots, and verification.
8. Run focused and repository-wide checks.
9. Obtain independent Finalreviews for one exact implementation revision and
   accept only without findings and with 10.0 in every required dimension.

## Required Checks

- deterministic contract validation and rendering tests;
- complete contract-to-View and contract-to-AMX-registry checks;
- all repository View extraction and snapshot checks;
- Haskell formatting, build, tests, and Haddock;
- publication expansion, references, figures, and PDF rendering;
- repository-wide staged verification;
- generic-content and diff checks.

## Non-goals

- changing terminology or notation-independent metamodel semantics;
- changing admitted ArchiMate mappings from `o2i-0002`;
- introducing code generation beyond the readable publication projection;
- introducing JSON Schema, a public CLI command, or instance-specific content;
- reducing model documentation before its content audit is complete.
