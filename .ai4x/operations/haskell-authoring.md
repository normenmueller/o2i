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
- Apply the presentation boundary in `modeling.md`: no new product capability
  for editorial reference styling. Product checks for explicitly justified,
  meaning-bearing notation belong in O2I libraries and the CLI, never in
  parallel shell/Python rule implementations.

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
- `o2i-cli`: the public executable, composing Operation APIs and the AMX
  adapter through a thin argument, acquisition, rendering, and exit boundary.
  Reusable evaluators and machine-result contracts remain library-owned.
- `spc/cabal.project` owns the complete five-package build. `o2i-inspection`
  is retired; never reintroduce its package, command, or runtime registrations.

# Co-Authoring

- Use an external Co-Author whenever specialist judgment materially shapes design or implementation. Haskell, type design, or a public API alone never makes co-authoring mandatory; material reliance on specialist judgment does.
- The Co-Author contributes actively during both design and implementation and combines the exact metamodel, formal-methods, type-theory, idiomatic Haskell, API, or performance capabilities required by the assigned scope.
- Assign small semantically coherent packages with explicit write scope and one
  independently verifiable result.
- Each handoff records capability, role, target contract, owned paths, contribution, changed paths, checks, unresolved findings, authorship-versus-review separation, and whether commit permission exists. Record its current package and next action in `.ai4x/HANDOFF.md` only after applicability is proven.
- A Co-Author or implementer never independently accepts their own candidate.
- Preserve concurrent work. Do not permit commits or model edits unless the
  assignment explicitly authorizes them.

# Verification

Canonical repository-root verification entries:

```text
./utl/verify.sh haskell
./utl/verify.sh foundation
```

`haskell` verifies all five packages, including the CLI, against
`spc/cabal.project` and its freeze, and checks the atomic package cutover.
`foundation` verifies the four-library subset against
`spc/cabal.foundation.project` and its freeze; it does not establish CLI
verification. The current workflow selects Foundation for Pull Requests and
the complete Haskell stage for manual and release runs. CLI changes require
complete Haskell evidence; never report that gate as passed from Foundation
results alone.

Focused commands use the stated working directory:

```text
spc/: cabal --project-file=cabal.project build all --ghc-options=-Werror
spc/: cabal --project-file=cabal.project test all --ghc-options=-Werror
spc/: cabal --project-file=cabal.project haddock all
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
