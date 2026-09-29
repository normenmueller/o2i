# Scope

Load for independent reviews of Haskell, formalization, metamodel fidelity,
tests, adapters, or the complete machine-checkable O2I chain.

# Review Method

Apply `../TEAM.md` for independence and `../governance/guidelines.md` for review
evidence and verdicts. Freshly inspect the observed worktree, design, and
implementation without inheriting the author's conclusions; test results and
rationale alone are insufficient. Review one bounded package at a time and
re-review every closed finding.

Inspect baseline diffs separately. Use `local-verification.md` for local checks;
do not prefix verification commands with temporary environment assignments to
select a diff base.

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

# Findings And Verdict

- Report blocking findings before advisory follow-ups; use severity only to prioritize correction.
- Every blocking finding includes one clean target-state solution. No workaround, migration, compatibility layer, or retrospective rationale.
- Assess every materially affected dimension among Fachlichkeit, Metamodell, Typtheorie/Formalisierung, Haskell design, tests, diagnostics/provenance, extensibility, cross-package consistency, and formal value/proportionality.
