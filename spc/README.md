# O2I Haskell Specification

This directory contains the machine-checkable Haskell formalization of the O2I
metamodel and the tooling that inspects concrete O2I models. The normative
subject-matter definitions remain in the [O2I White Paper](../o2i.md); this file
documents only the technical codebase and its use.

## Packages

| Package | Responsibility |
| --- | --- |
| `o2i-core` | Typed O2I language, effect graphs, and staged validation |
| `o2i-inspection` | Format-neutral staged inspection, provenance, and reports |
| `o2i-archimate-profile` | Typed projection of the exact declarative ArchiMate profile contract |
| `o2i-amx` | Native Archi Model XML decoding and O2I profile projection |
| `o2i-cli` | Thin command-line composition and report rendering |

The dependency direction is:

```text
o2i-inspection        -> o2i-core
o2i-archimate-profile -> o2i-core + o2i-inspection
o2i-amx               -> o2i-archimate-profile + o2i-inspection + o2i-core
o2i-cli               -> o2i-inspection + o2i-amx
```

Inspection supplies the shared validated profile-version contract used by the
typed ArchiMate profile projection.

The curated public facades are `O2I`, `O2I.Language`, `O2I.Graph`,
`O2I.Validation`, `O2I.Inspection`, `O2I.ArchiMate.Profile`, and
`O2I.Adapter.AMX`.

The Core assesses `Candidate` and `Asserted` claims across one complete
semantic boundary, derives Context-level `Elaboration` and model-level
`Maturity` exactly once, validates the Primitive evidence of every asserted
Context macrorelation, and includes validated collective Strategy realizations
in `SemanticallyValidModel`. Binary Strategy contribution remains a separate
proposition.

## Build

The complete repository contract, including model and White Paper checks, is
verified from the repository root:

```sh
./utl/verify.sh
```

The Haskell stage can be run independently from the repository root:

```sh
./utl/verify.sh haskell
```

For focused Haskell development, run the following commands from this
directory:

```sh
cabal build all --ghc-options=-Werror
cabal test all --ghc-options=-Werror
cabal haddock all
```

The repository verification additionally checks external compile-pass and
compile-fail clients against the exact Cabal build under test.

Package metadata is checked separately:

```sh
(cd lib/core && cabal check)
(cd lib/inspection && cabal check)
(cd ctr/archimate && cabal check)
(cd lib/adapter/amx && cabal check)
(cd cli && cabal check)
```

## Install

The local CLI is installed under `~/.local/bin/o2i` by default:

```sh
make install
make uninstall
```

`PREFIX` changes the installation prefix. `DESTDIR` adds a packaging root
without changing the logical prefix.

## Inspect

The CLI uses exactly one View of a native Archi model as the inspection seed:

```sh
o2i inspect MODEL (--view NAME | --view-id ID) [--verbose | --debug] [--json]
```

It accepts a file or standard input. JSON output is deterministic and suited to
automation and agentic processing:

```sh
cat ../mdl/my.archimate | o2i inspect - --view "My view" --json
```

Inspection closes only the exact persisted O2I dependencies reached from that
seed and retains their provenance. It neither invents relations nor reports
independent defects outside the closed scope.

The CLI contains no validation semantics. It delegates inspection to the
libraries and renders their result.
