# Scope

Load for independent reviews of Haskell, formalization, metamodel fidelity,
tests, adapters, or the complete machine-checkable O2I chain.

# Independence

- The final reviewer is read-only, freshly inspects the observed worktree
  without inheriting the implementing agent's conclusions, and is not the
  implementing co-author.
- Review one bounded package at a time. Re-review every finding after closure.
- Do not accept a change when a required reviewer is unavailable.

# Required Questions

- Does terminology map faithfully to metamodel, types, validation, and tests?
- Which invalid states are prevented statically, and which require runtime
  validation?
- Does every advanced Haskell construct earn its complexity?
- Is the API total, idiomatic, elegant, documented, modular, extensible, and
  maintainable?
- Does the formalization enforce fachlich material guarantees or merely encode
  decorative vocabulary?
- Are Decode, profile mapping, graph validation, semantic validation, traces,
  and evidence separated without competing authority?
- Are diagnostics complete, deterministic, provenance-preserving, and tested?
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
