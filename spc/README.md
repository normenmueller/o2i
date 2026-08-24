# O2I Haskell Specification

This directory contains the machine-checkable Haskell formalization of the O2I metamodel and the current Foundation for processing O2I models. The normative subject-matter definitions remain in the [O2I White Paper](../o2i.md); this file documents only the technical codebase and its current use.

## Foundation Architecture

The Foundation build closure in `cabal.foundation.project` contains exactly four packages:

| Package | Responsibility |
| --- | --- |
| `o2i-core` | Notation-independent identities, selected-View scope, graph observations, structural and semantic assessment, opaque accepted artifacts, supplemental semantic input, and the compiled Core rule catalog |
| `o2i-archimate-profile` | Typed, immutable projection of `ctr/archimate/profile.json`, including Profile identity, Draft observations, ArchiMate notation, branch-separated closure, mapping, assessment, Core projection, and Profile-owned rule explanations |
| `o2i-operation` | Capability-sized acquisition, static Adapter composition, Profile bootstrap and resolution, exact View selection, request preparation, provenance, owner-bound diagnostics, discovery, and deterministic machine contracts |
| `o2i-amx` | Native Archi Model XML recognition and lossless decode into the profile-neutral Draft consumed through the Operation Adapter contract |

The Cabal dependencies point toward the packages that own the consumed contracts:

```text
o2i-archimate-profile -> o2i-core
o2i-operation         -> o2i-archimate-profile + o2i-core
o2i-amx               -> o2i-operation + o2i-archimate-profile
```

Core alone owns notation-independent O2I structure and semantics. The ArchiMate Profile alone owns its compiled mapping and projection. Operation coordinates acquisition and exact requests without redefining either contract. AMX contributes one native Adapter and does not own Profile or Core semantics.

## Public Foundation Surface

The production libraries expose exactly the following modules in their Cabal metadata.

`o2i-core`:

```text
O2I.Core.Contract
O2I.Core.Graph.Observation
O2I.Core.Identity
O2I.Core.Rule.Catalog
O2I.Semantics
O2I.Semantics.Input
O2I.Structure
```

`o2i-archimate-profile`:

```text
O2I.ArchiMate.Profile
O2I.ArchiMate.Profile.Closure
O2I.ArchiMate.Profile.Draft
O2I.ArchiMate.Profile.Mapping
O2I.ArchiMate.Profile.Notation
O2I.ArchiMate.Profile.Projection
O2I.ArchiMate.Profile.Resolution
O2I.ArchiMate.Profile.Rule.Catalog
O2I.ArchiMate.Profile.Rule.Explanation
```

`o2i-operation`:

```text
O2I.Operation.Acquisition
O2I.Operation.Adapter
O2I.Operation.Adapter.Authoring
O2I.Operation.Discovery.Adapter
O2I.Operation.Discovery.Adapter.Machine
O2I.Operation.Discovery.Profile
O2I.Operation.Discovery.Profile.Machine
O2I.Operation.Discovery.Rule
O2I.Operation.Discovery.Rule.Explanation.Machine
O2I.Operation.Discovery.Rule.Inventory.Machine
O2I.Operation.Discovery.View
O2I.Operation.Discovery.View.Machine
O2I.Operation.Diagnostic
O2I.Operation.Diagnostic.Machine
O2I.Operation.Diagnostic.Owner
O2I.Operation.Diagnostic.Owner.Source
O2I.Operation.Failure
O2I.Operation.Machine
O2I.Operation.Preparation
O2I.Operation.Profile
O2I.Operation.Provenance
O2I.Operation.Request
O2I.Operation.Rule.Catalog
O2I.Operation.Schema
O2I.Operation.Validate
O2I.Operation.Validate.Machine
O2I.Operation.Validate.Request
O2I.Operation.Validate.Result
O2I.Operation.View
```

`o2i-amx`:

```text
O2I.Adapter.AMX
```

The build-only public conformance libraries expose `O2I.Core.Conformance`, `O2I.ArchiMate.Profile.Conformance`, and `O2I.ArchiMate.Profile.Conformance.Source`. They verify the compiled owner contracts and are not production facades.

## Preparation And Validation Boundaries

The current Foundation composes the implemented boundaries in this direction:

```text
native AMX bytes
-> Operation acquisition and static Adapter selection
-> AMX recognition and lossless profile-neutral Draft decode
-> Profile-neutral ArchiMate canonicalization
-> Operation Profile-marker resolution, Adapter compatibility, and exact View selection
-> Profile branch closure, notation assessment, and notation-independent projection
-> Core selected-View scope, Structure assessment, and Semantics assessment
-> Operation owner-bound diagnostics and deterministic machine material
```

Profile produces a `StructureProjection`; Core alone assesses it and can admit an opaque `WellFormedGraph`. Core semantics then assesses that graph with its bound supplemental inputs and can admit an opaque `SemanticallyValidModel`. These are owner-specific guarantees, not stages of one universal inspection pipeline.

Operation exposes the complete public library-level Validate composition for explicit Notation, Profile, Structure, and Semantics levels: closed requests, cumulative orchestration, typed terminal results, and generated schema-bound machine documents. Validate has no supported CLI or executable integration yet. The request identities for trace, qualification, readiness, and assessment remain shared request vocabulary whose executable capability compositions are still pending; the Foundation therefore does not claim a current public path from an unchecked graph through trace, readiness, and evidence assessment.

## Profile And Candidate Views

`ctr/archimate/profile.json` owns the exact declarative ArchiMate mapping. Its compiled descriptor has identity `o2i.archimate-profile`, token `0.3`, and version `0.3.0`; a bound model uses the exact direct marker `o2i.profile=o2i.archimate-profile@0.3`.

Foundation verification selects and checks exactly these three focused Candidate Views from the real repository model:

- `O2I Syntax - Contextualization`
- `O2I Syntax - Collective Strategy Realization`
- `O2I Syntax - Need Qualification Proposal`

The repository checker acquires `mdl/o2i.archimate` through AMX, resolves its compiled Profile, selects every required View exactly once, and executes the current Profile and Core structure/semantic boundary. These checked Views are repository conformance subjects, not an installed user command.

## Layout

```text
spc/
|- cabal.foundation.project
|- cabal.foundation.project.freeze
|- ctr/archimate/
|- lib/
|  |- core/
|  |- operation/
|  `- adapter/amx/
`- README.md
```

Each Foundation package owns its source and test trees. `ctr/archimate/` contains the exact declarative Profile contract and its typed projection, `lib/core/` contains the normative machine-checkable formalization, `lib/operation/` contains capability-sized execution contracts, and `lib/adapter/amx/` contains the native Adapter. Focused Core excerpts are included in the White Paper; the complete Core source remains authoritative for the machine-checkable formalization.

## Build And Verification Status

The canonical repository-root verification command for the current Foundation and pull-request scope is:

```sh
./utl/verify.sh foundation
```

This fail-closed stage uses the frozen `cabal.foundation.project`, requires GHC `9.10.3`, Cabal `3.16.1.0`, and `base-4.20.2.0`, and checks licensing, generated contracts, package metadata, warning-free build and tests, the three real-model Candidate Views, external API contracts, Haddock, source distributions, and formatting.

The separate complete-project command remains fail-closed and is not currently green:

```sh
./utl/verify.sh haskell
```

The complete project still contains legacy inspection and CLI packages whose `base >=4.18 && <4.19` bounds cannot resolve with the Foundation toolchain's `base >=4.20 && <4.21`. Foundation success must therefore never be reported as complete-project success.

## Command Status

The current Foundation exposes the library-level Validate composition and verification executables only. It provides no supported `o2i` installation path and no available `o2i validate` or `o2i inspect` command. User-facing capability execution, rendering, installation, and the CLI package-graph cutover remain pending and are not documented here as usable behavior.

## License

The Haskell specification and tooling are licensed under Apache-2.0. The repository-wide path assignment and canonical legal text are defined by the root [licensing map](../LICENSING.md); every separately distributable Cabal package includes an identical local copy of that text.
