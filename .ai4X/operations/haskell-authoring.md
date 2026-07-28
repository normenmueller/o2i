# Scope

Load for Haskell architecture, type design, implementation, tests, Cabal, CLI,
adapters, or Haddock.

# Design Standard

- Treat Haskell as the normative machine-checkable formalization of the O2I
  metamodel, never as an independent fachliche source.
- Optimize for semantic force, totality, idiomatic clarity, a small public API,
  and proportionate complexity.
- Use GADTs, DataKinds, phantom types, existential packaging, or opaque
  validated artifacts only when they prevent invalid states, express a law, or
  protect a package boundary.
- Prefer closed sums and exhaustive functions for closed vocabularies.
- Accumulate independent findings applicatively. Use monadic sequencing only
  when later work genuinely depends on an earlier result.
- Keep `IO` at acquisition, rendering, and process boundaries. Do not add a
  global application monad or effect framework without a concrete requirement.
- Use type classes only for coherent reusable abstractions with meaningful
  laws. Avoid instance-driven control flow and type classes that merely rename
  functions.
- Separate static type guarantees from identity- and graph-dependent runtime
  validation.
- Keep the CLI thin. Reusable logic belongs in libraries.

# Package Boundaries

- `o2i-core`: language, graph, validation, trace, and evidence semantics.
- `o2i-inspection`: format-neutral staged inspection and reports.
- `o2i-archimate-profile`: typed projection of the declarative ArchiMate
  profile contract.
- `o2i-amx`: Decode, View scope, concrete AMX profile, provenance, projection.
- `o2i-cli`: arguments, composition, and rendering.

# Co-Authoring

- Trigger external co-authoring for changes to type design, validation
  semantics, public API, package architecture, adapter projection, or
  non-mechanical Haskell implementation.
- The co-author role combines metamodel, formal-methods, type-theory, and
  idiomatic Haskell expertise during design and implementation.
- Assign small semantically coherent packages with explicit write scope and one
  independently verifiable result.
- Each handoff records target contract, owned paths, changed paths, checks,
  unresolved findings, and whether commit permission exists. Record its current
  package and gate in `.ai4X/STATE.md`.
- Preserve concurrent work. Do not permit commits or model edits unless the
  assignment explicitly authorizes them.

# Verification

Canonical repository-root gate:

```text
./utl/verify.sh haskell
```

Focused commands use the stated working directory:

```text
spc/: cabal build all --ghc-options=-Werror
spc/: cabal test all --ghc-options=-Werror
spc/: cabal haddock all
each package directory: cabal check
repository root:
  rg --files spc -g '*.hs' | xargs hindent --line-length 80 --validate
./utl/check-package-licenses.sh
```

In a Git worktree, additionally run `git diff --check`. In an archive or source
tree without Git metadata, omit only that check and record it as unavailable.

Tests must cover laws, positive paths, every diagnostic branch, provenance,
determinism, and public API boundaries. Tests provide verification evidence for
defined contracts; they neither prove, own, nor define semantics.
