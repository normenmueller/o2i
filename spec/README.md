# O2I Haskell Specification

This directory contains the machine-checkable Haskell formalization of the O2I metamodel and the current Foundation for processing O2I models. The normative subject-matter definitions remain in the [O2I White Paper](../doc/paper/o2i.md); this file documents only the technical codebase and its current use.

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

## Presentation Scope

The [White Paper](../doc/paper/o2i.md#syntax) owns the distinction between meaning-bearing notation and editorial presentation. Consistent reference-diagram styling, including solid outlines for semantic metamodel elements, is an editorial recommendation assessed by visual review, not an additional instance-conformance condition. Colors, fonts, layout, and ArchiMate Grouping border styles do not affect O2I conformance unless the governing notation or Profile contract assigns them meaning. Metamodel abstraction is documented explicitly; O2I introduces no dashed-border encoding of abstraction.

Editorial consistency does not justify a new product presentation checker, API, CLI option or command, validation level, or engine. Any justified meaning-bearing graphical rule must be defined by its owning contract, implemented in the responsible O2I library, and exposed through the thin O2I CLI. Shell or Python tooling must not maintain parallel product-rule logic for these checks.

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

Operation exposes Validate for explicit Notation, Profile, Structure, and Semantics levels: closed requests, cumulative orchestration, typed terminal results, and generated schema-bound machine documents. The CLI exposes this composition through `o2i validate`. Trace, qualification, readiness, and assessment are separate executable capabilities; an accepted validation result does not establish their guarantees.

## Profile And Candidate Views

`ctr/archimate/profile.json` owns the exact declarative ArchiMate mapping. Its compiled descriptor has identity `o2i.archimate-profile`, token `0.3`, and version `0.3.0`; a bound model uses the exact direct marker `o2i.profile=o2i.archimate-profile@0.3`.

Foundation verification selects and checks exactly these three focused Candidate Views from the real repository model:

- `O2I Syntax - Contextualization`
- `O2I Syntax - Collective Strategy Realization`
- `O2I Syntax - Need Qualification Proposal`

The repository checker acquires `meta/o2i.archimate` through AMX, resolves its compiled Profile, selects every required View exactly once, and executes the current Profile and Core structure/semantic boundary. These checked Views are repository conformance subjects, not an installed user command.

## Layout

```text
spec/
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

For a fresh clone or fork, first follow the [local verification setup](../utl/verification/README.md). It documents the pinned toolchain and prebuilt formatter installation for macOS and Linux. Locally, use `./utl/verification/local.sh foundation` or `./utl/verification/local.sh haskell` to put those checkout-local tools on the verification path. CI invokes the same canonical verifier directly.

The canonical repository-root verification command for the current Foundation and pull-request scope is:

```sh
./utl/verify.sh foundation
```

This fail-closed stage uses the frozen `cabal.foundation.project`, requires GHC `9.10.3`, Cabal `3.16.1.0`, and `base-4.20.2.0`, and checks licensing, generated contracts, package metadata, warning-free build and tests, the three real-model Candidate Views, external API contracts, Haddock, source distributions, and formatting.

The complete-project verification includes the CLI package:

```sh
./utl/verify.sh haskell
```

It uses `cabal.project` and its frozen package plan with the same required toolchain. Foundation verification covers its narrower four-package closure.

Core's internal tests run in one `o2i-core-internal-test` component. The existing domain groups sit under the `Core internal` Tasty root; fully qualified and positional test paths gain that first segment. From `spec/`, `cabal test o2i-core` runs the internal tests and the separate public conformance suite. To select one internal domain:

```sh
cabal test o2i-core:o2i-core-internal-test \
  --test-option=--pattern --test-option='/Core Qualification/'
```

External compile-pass/fail checks continue to consume the built public package and verify opaque constructors, hidden modules and scope boundaries separately. Both verification scopes enforce the same Haddock documentation/link-warning gate and package warning configuration; intentional API-fixture compiler arguments and diagnostic assertions remain distinct.

The verifier reports separate command timings for builds, test calls, Haddock, source-archive preparation and independent archive build/test calls. Archive checks still use freshly unpacked sources and a separate fresh build tree. A Cabal test call can include planning or rebuilding, so its duration is not pure test execution time.

Times use a labeled monotonic clock; invalid observations remain `UNKNOWN`. Suspend behavior is platform-dependent, and comparisons require matching host, clock, tool and cache conditions. The verifier reports requested compiler and scheduling options; unobserved effective settings remain `UNKNOWN`.

Cabal's native `--semaphore` coordinates module and component compilation for build, test and Haddock within the existing configured jobs budget. The verifier sets no jobs override. Quiet planning and API-fixture commands retain the same `-Werror` configuration. The single Core internal test binary can require more peak runtime memory; compiler scheduling does not reduce that runtime cost.

`O2I_HASKELL_CABAL_VERBOSITY` accepts `1` (default) or `2` (diagnostic). It affects build, test and Haddock output while machine-readable probes stay quiet. Capture diagnostic output when investigating actual compiler invocations or the effective native jobs pool. The verbosity setting changes neither check selection/frequency nor optimization, scheduling, dependencies or archive isolation.

## CLI Setup

Install the GHC/Cabal toolchain described in the [setup instructions](../utl/verification/README.md), then build the CLI from the repository root and add its executable directory to the current shell's PATH:

```sh
cd spec
cabal build exe:o2i
export PATH="$(dirname "$(cabal list-bin exe:o2i)"):$PATH"
cd ..
o2i --help
```

Run Cabal from `spec/` so local build artifacts remain in `spec/dist-newstyle/`. The CLI provides `views`, `validate`, `trace`, `qualify`, `readiness`, and `assess`; command-specific help describes their inputs. Add `--json` for deterministic machine output. Start modeling with the [Ethos guide](../doc/guide/ethos.md).

Hindent is a development verification tool; it is not a runtime dependency of the installed `o2i` command. Publication tools are needed only for the corresponding paper verification stage.

## License

The Haskell specification and tooling are licensed under Apache-2.0. The repository-wide path assignment and canonical legal text are defined by the root [licensing map](../LICENSING.md); every separately distributable Cabal package includes an identical local copy of that text.
