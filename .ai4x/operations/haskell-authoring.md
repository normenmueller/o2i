# Scope

Load for Haskell architecture, type design, implementation, tests, Cabal, CLI,
adapters, or Haddock.

# Design Standard

- Treat Haskell as the normative machine-checkable formalization of the O2I
  metamodel, never as an independent fachliche source.
- Optimize simultaneously for semantic force, totality, idiomatic elegance,
  modularity, performance, logical coherence, robustness, extensibility,
  practical applicability, local clarity, a small public API, and proportionate
  complexity. A formally strong design that is unnecessarily difficult to
  explain or use is not acceptable.
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
- Derive architecture from fachlich owned obligations. Reuse and extend stable
  mechanisms through owned rules and projections only while their design fits
  those obligations. Demonstrate any mismatch and redesign the affected boundary
  from its required target state; never preserve an ill-fitting design through
  migration scaffolding, compatibility layers, attached special-case logic,
  workarounds, unsafe mechanisms, or speculative abstractions.
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
- `spec/cabal.project` owns the complete five-package build. `o2i-inspection`
  is retired; never reintroduce its package, command, or runtime registrations.

# Co-Authoring

- Follow `TEAM.md` for collaboration timing, bounded assignments, records and
  independence. Haskell, type design or a public API alone does not trigger
  co-authoring; material specialist judgment does. Combine the metamodel,
  formal-methods, type-theory, idiomatic Haskell, API and performance capabilities
  needed by the assigned scope during design and implementation.
- Material Core semantic or architectural changes require scoped independent
  design review before implementation. Use `haskell-review.md` and governance
  for review evidence and acceptance; design review never replaces final
  candidate review.
- Record the current package and next action in the applicable Handoff under
  `governance/continuity.md`; preserve semantically coherent package boundaries.

# Verification

Use `local-verification.md` for local tools and recovery. Repository-root entries:

```text
./utl/verification/local.sh haskell
./utl/verification/local.sh foundation
```

`haskell` verifies all five packages, including the CLI, against
`spec/cabal.project` and its freeze, and checks the atomic package cutover.
`foundation` verifies the four-library subset against
`spec/cabal.foundation.project` and its freeze; it does not establish CLI
verification. The current workflow selects Foundation for Pull Requests and
the complete Haskell stage for manual and release runs. CLI changes require
complete Haskell evidence; never report that gate as passed from Foundation
results alone.

Focused commands use the stated working directory:

```text
spec/: cabal --project-file=cabal.project build all --ghc-options=-Werror
spec/: cabal --project-file=cabal.project test all --ghc-options=-Werror
spec/: cabal --project-file=cabal.project haddock all
each package directory: cabal check
repository root:
  rg --files spec -g '*.hs' | xargs hindent --line-length 80 --validate
./utl/haskell/check-package-licenses.sh
```

In a Git worktree, additionally run `git diff --check`. In an archive or source
tree without Git metadata, omit only that check and record it as unavailable.

Tests must cover laws, positive paths, every diagnostic branch, provenance,
determinism, and public API boundaries. Tests provide verification evidence for
defined contracts; they neither prove, own, nor define semantics.
