# Scope

Load for Haskell architecture, type design, implementation, tests, Cabal, CLI,
adapters, or Haddock.

# Design Standard

- Treat Haskell as the normative machine-checkable formalization of the O2I
  metamodel, never as an independent fachliche source.
- Optimize simultaneously for semantic force, totality, idiomatic elegance,
  local clarity, a small public API, and proportionate complexity. A formally
  strong design that is unnecessarily difficult to explain or use is not
  acceptable.
- Keep type design, module boundaries, package architecture, and semantic
  ownership coherent and explicit. Signatures and Haddock must make the
  intended use and guarantee boundary understandable without reading the whole
  implementation.
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
- Make expected domain failures explicit, total, deterministic, and
  provenance-preserving. Internal definition defects must never be reported as
  missing fachliche evidence or ordinary validation failure.
- Design nontrivial graph and rule evaluation around addressed indices and
  truthful work contracts. Exclude hidden Cartesian intermediates and support
  asymptotic claims with adversarial multi-axis tests.
- Extend stable mechanisms through fachlich owned rules and projections.
  Redesign a shared evaluator only for a separately demonstrated new class of
  requirement; never add a workaround, compatibility layer, unsafe mechanism,
  or speculative abstraction.
- Keep the CLI thin. Reusable logic belongs in libraries.

# Package Boundaries

- `o2i-core`: notation-independent contract, identities, canonical graph
  observations, structure, semantics, and capability-owned domain contracts.
- `o2i-archimate-profile`: compiled immutable projection of the exact
  declarative ArchiMate Profile and its bound Core companion.
- `o2i-operation`: acquisition, Adapter composition, Profile and View
  resolution, preparation, provenance, diagnostics, discovery, and machine
  contracts without redefining Core or Profile semantics.
- `o2i-amx`: native AMX recognition and lossless decode into the Draft consumed
  by the current Operation/Profile pipeline.
- `o2i-inspection` and the current `o2i-cli` are legacy packages awaiting their
  atomic target cutover. Never extend them, route new Foundation behavior
  through them, or treat their package graph as current architecture.

# Co-Authoring

- Use external co-authoring when a Significant or Protected change has design
  or implementation complexity that materially benefits from a second active
  author. Haskell, type design, or a public API alone never makes co-authoring
  mandatory.
- The co-author role combines metamodel, formal-methods, type-theory, and
  idiomatic Haskell expertise during design and implementation.
- Assign small semantically coherent packages with explicit write scope and one
  independently verifiable result.
- Each handoff records target contract, owned paths, changed paths, checks,
  unresolved findings, and whether commit permission exists. Record its current
  package and next action in `.ai4x/STATE.md`.
- Preserve concurrent work. Do not permit commits or model edits unless the
  assignment explicitly authorizes them.

# Verification

Canonical repository-root verification entry for the current Foundation and
pull-request scope:

```text
./utl/verify.sh foundation
```

`./utl/verify.sh haskell` verifies the complete package set used by manual and
release gates. It remains intentionally fail-closed while legacy package bounds
and the complete freeze await their atomic cutover; never represent that gate
as passed from Foundation evidence.

Focused commands use the stated working directory:

```text
spc/: cabal --project-file=cabal.foundation.project build all --ghc-options=-Werror
spc/: cabal --project-file=cabal.foundation.project test all --ghc-options=-Werror
spc/: cabal --project-file=cabal.foundation.project haddock all
each package directory: cabal check
repository root:
  rg --files spc -g '*.hs' | xargs hindent --line-length 80 --validate
./utl/haskell/check-package-licenses.sh
```

In a Git worktree, additionally run `git diff --check`. In an archive or source
tree without Git metadata, omit only that check and record it as unavailable.

Tests must cover laws, positive paths, every diagnostic branch, provenance,
determinism, and public API boundaries. Tests provide verification evidence for
defined contracts; they neither prove, own, nor define semantics.
