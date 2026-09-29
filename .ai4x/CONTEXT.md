# Purpose

Stable identity, product ownership, retrieval, and durable invariants. Load after checkout selection when repository context is material; `BEHAVIOR.md` owns operational routing.

# Project Identity

O2I is a generic framework for effect architectures: terminology, metamodel, notation, and machine-checkable formalization make oriented effect understandable and evidencable. Organizational instances test and apply O2I without defining its semantics. Agentic AI may assist but is never required. O2I supports evidence consistency and plausible attribution, not causal proof.

# Statement-Class Boundaries

Each statement class has exactly one owner. Resolve conflicts in that owner before changing a dependent representation.

| Statement class | Owner | Dependent representation |
| --- | --- | --- |
| Purpose and USP snippets | `README.md` | White Paper includes |
| Fachliche definitions and authors' derivations | `doc/paper/o2i.md` Terminology | WTF and model documentation |
| Metamodel types, relations, and invariants | `doc/paper/o2i.md` Metamodel | semantic Views and Haskell |
| Exact ArchiMate mapping | `spec/ctr/archimate/profile.json` | White Paper projection, syntax Views, adapters |
| Notation-independent structure, semantics, qualification, trace, readiness, assessment | `spec/lib/core/` | Operation, adapters, CLI |
| Bounded AMX acquisition and native observations | `spec/lib/adapter/amx/` | Operation and CLI results |
| Change contract, decisions, dependencies, review evidence, open state | owning GitHub Issue | Project and local handoff references |
| Workflow status and Product Owner ordering | GitHub Project `O2I` | no product or authority fact |
| Verification evidence | tests and generated snapshots | no semantic ownership |

# Retrieval Routes

- Human entry: `README.md`, `doc/README.md`; informal orientation: `doc/misc/wtf.md`; guided modeling: `doc/guide/` with `doc/model/illustration.archimate`.
- Profile projection and generated contracts: `spec/ctr/archimate/`.
- Capability execution, diagnostics, machine results, thin CLI rendering: `spec/lib/operation/`, `spec/cli/`.
- Reference model and generated snapshots: `meta/o2i.archimate`, `meta/o2i-*.md`.
- Operating contracts: `governance/`, `operations/`; lean routers: `.agents/skills/`, `.github/agents/`.
- Artifact placement and local execution: `operations/artifact-placement.md`, `operations/local-verification.md`; tool procedure: `utl/verification/README.md`.

# Durable Invariants

- Keep terminology, metamodel semantics, concrete notation, formalization, and verification distinct and synchronized.
- Contexts provide meaning; Primitives carry modeled content. Contextualized Primitive relations substantiate Context macrorelations; visual nesting has no contextualization semantics.
- Persisted propositions carry explicit `Candidate` or `Asserted` commitment. Candidates remain diagnostic, and Asserted propositions depend only on Asserted propositions.
- A complete effect trace precedes evidence readiness. Effect and target attainment remain independent assessments.
- The Profile projects notation structure; Core owns notation-independent well-formedness and semantic validity. Qualification, trace, readiness, and assessment remain separate capabilities rather than one validation pipeline.
- Semantic Views visualize the metamodel; syntax Views visualize the Profile. ArchiMate, Python, and tests never define O2I semantics.
- Reference styling is editorial, not conformance. Apply `operations/modeling.md` and the White Paper Syntax boundary: no cosmetic product checker or implicit graphical semantics; justified meaning-bearing checks remain library/CLI-owned.
