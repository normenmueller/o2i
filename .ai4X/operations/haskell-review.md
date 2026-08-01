# Scope

Load for independent reviews of Haskell, formalization, metamodel fidelity,
tests, adapters, or the complete machine-checkable O2I chain.

# Independence

- The final reviewer is read-only, freshly inspects the observed worktree
  without inheriting the implementing agent's conclusions, and is not the
  implementing co-author.
- Review design and implementation themselves, not only test outcomes or the
  implementing agent's rationale.
- Review one bounded package at a time. Re-review every finding after closure.
- Do not accept a change when a required reviewer is unavailable.
- Inspect baseline diffs separately and invoke canonical verification entry
  points directly. Do not prefix verification commands with temporary
  environment assignments merely to select a diff base.

# Required Questions

- Is the design purpose-fit for O2I's current and foreseeable
  machine-checkable proof obligations without becoming a database, public
  query language, analytics engine, or speculative general framework?
- Does terminology map faithfully to metamodel, types, validation, and tests?
- Which invalid states are prevented statically, and which require runtime
  validation?
- Are type design, module boundaries, package architecture, and semantic
  ownership coherent, minimal, and explicitly justified?
- Does every advanced Haskell construct earn its complexity?
- Are signatures, modules, and Haddock locally understandable,
  inference-friendly, and fachlich explainable without reconstructing the
  entire implementation?
- Is the API total, idiomatic, elegant, documented, modular, robust,
  extensible, and maintainable?
- Does the formalization enforce fachlich material guarantees or merely encode
  decorative vocabulary?
- Are Decode, profile mapping, graph validation, semantic validation, traces,
  and evidence separated without competing authority?
- Are error handling, diagnostics, and reporting complete, precise,
  deterministic, provenance-preserving, and tested at the correct boundary?
- Do adversarial multi-axis contracts and truthful work metrics substantiate
  the claimed asymptotic performance without hidden Cartesian intermediates?
- Is the implementation robust and extensible without workaround,
  compatibility layer, unsafe mechanism, or premature abstraction?
- Can foreseeable proof obligations be added through domain-owned rules and
  projections without redesigning a stable shared evaluator?
- Is the design proportionate to O2I's actual formal value?

# Findings And Scores

- Report Blocker, High, Medium, and Low findings first.
- Every finding includes one clean target-state solution. No workaround,
  migration, compatibility layer, or retrospective rationale.
- Report separate 0.0-10.0 scores for Fachlichkeit, Metamodell,
  Typtheorie/Formalisierung, Haskell design, tests, diagnostics/provenance,
  extensibility, cross-package consistency, and formal value/proportionality.
- Use `10/10` only when every required dimension is independently 10.0.
- Acceptance requires no unresolved finding and 10.0 in every required
  dimension.
