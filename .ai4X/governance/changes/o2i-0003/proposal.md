# O2I-0003: Declarative ArchiMate Profile Contract

Author: `normenmueller`

## Problem

The exact ArchiMate profile mapping is currently distributed across White Paper
prose, Haskell registries, ArchiMate View documentation, and repository checks.
Treating the ArchiMate model as the mapping authority hides a normative
contract inside tool-specific XML and makes drift difficult to prevent.

## Minimal Generic Case

An O2I user or tool author needs one exact answer for how an O2I carrier,
relation signature, metadata field, or structured pattern is represented in
ArchiMate. The answer must remain human-reviewable, machine-checkable, and
independent of one modeling tool.

## Users

- practitioners expressing O2I models in ArchiMate;
- tool authors implementing O2I profile validation or transformation;
- authors maintaining the White Paper, reference model, and formalization;
- agentic AI agents checking cross-artifact consistency.

## Benefit

A small declarative profile contract gives every exact ArchiMate mapping fact
one diffable source. The White Paper remains the normative fachliche
publication and includes a generated readable projection. The reference model
visualizes the contract, and the Haskell AMX adapter implements and verifies
it. Drift becomes a verification failure rather than a review convention.

## O2I Fit

O2I separates fachliche semantics, concrete notation, and machine-checkable
formalization. The contract contains only the closed concrete ArchiMate
mapping. It introduces no terminology, metamodel semantics, validation
algorithm, or instance-specific content.

## Target Authority

- `o2i.md` owns terminology, meaning, authors' derivations, metamodel types,
  relations, invariants, and the readable normative publication.
- `spc/contract/archimate-profile.json` owns exact ArchiMate carrier mappings,
  metadata placement, context-sensitive relationship representations, and
  structured pattern representations.
- `spc/lib/core/` formalizes the notation-independent metamodel.
- `spc/lib/adapter/amx/` executes ArchiMate profile validation and projection.
- `mdl/o2i.archimate` visualizes the contract and provides reference and
  conformance Views; it is not an independent normative source.

## Synchronization Contract

- A deterministic renderer produces the White Paper profile fragment from the
  declarative contract.
- The White Paper includes that fragment and remains self-contained.
- Repository checks compare the normative `O2I Syntax` View with the contract.
- Haskell tests compare the AMX registry completely with the contract.
- Verification fails on contract, publication, View, or registry drift.
- Existing ArchiMate View documentation is audited before reduction. Unique
  fachliche explanations move into the White Paper; the View retains only
  purpose, boundary, profile version, and contract reference.

## Alternatives

- White Paper alone is readable but a poor machine contract.
- Haskell alone is precise but implementation-oriented and unsuitable as the
  published explanation.
- ArchiMate View documentation is tool-specific, difficult to diff, and hidden
  in XML.
- Manual duplication across all artifacts preserves local readability but
  cannot prevent drift.

## Non-goals

- changing O2I terminology or notation-independent semantics;
- changing the admitted ArchiMate mappings of `o2i-0002`;
- introducing code generation, JSON Schema, or a public CLI command;
- moving prose, algorithms, or instance data into the contract;
- deleting model documentation before its content has been reconciled.

## Risks

- An overly expressive contract could become a second metamodel.
- A generated publication fragment could reduce readability if it mirrors raw
  JSON rather than publication structure.
- Contract checks could duplicate implementation logic unless they compare
  closed registries rather than reimplement validation.

The contract therefore remains finite, declarative, syntax-only, and covered by
one renderer plus two completeness checks.

## Dependencies

Derived from `o2i-0002`. The implementation of `o2i-0002` depends on this
authority correction before Finalreview.
