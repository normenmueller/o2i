# Purpose

Stable identity, product boundaries, statement-class ownership, retrieval routes, and durable invariants for work in the O2I repository. Bootstrap belongs to `.ai4x/BEHAVIOR.md`; collaboration to `.ai4x/TEAM.md`; governance to `.ai4x/governance/`; task rules to `.ai4x/operations/`; and the applicable local return point to `.ai4x/HANDOFF.md`.

# Project Identity

O2I is a generic framework for effect architectures. It makes oriented effect understandable and evidencable through terminology, a metamodel, concrete notation, and machine-checkable formalization. O2I remains independent of every organizational instance: instances test and apply the Framework but never define its generic semantics. Agentic AI may support O2I reasoning but must never be required by O2I.

Contexts provide meaning and Primitives carry modeled content. Relations between contextualized Primitives justify Context macrorelations, so O2I defines a checkable effect graph rather than only a terminology catalog. O2I supports evidence consistency and plausible attribution, not causal proof.

# Statement-Class Boundaries

Each statement class has exactly one owner. Resolve conflicts in that owner before changing a dependent representation.

| Statement class | Owner | Dependent representation |
| --- | --- | --- |
| Purpose and USP snippets | `README.md` | White Paper includes |
| Fachliche definitions and authors' derivations | `o2i.md` Terminology | WTF and model documentation |
| Metamodel types, relations, and invariants | `o2i.md` Metamodel | semantic Views and Haskell |
| Exact ArchiMate mapping | `spc/ctr/archimate/profile.json` | White Paper projection, syntax Views, adapters |
| Machine-checkable formalization | `spc/lib/core/` | Operation, adapters, CLI |
| AMX acquisition, validation, and projection | `spc/lib/adapter/amx/` and `spc/ctr/archimate/` | Operation and CLI results |
| Change contract, decisions, dependencies, review evidence, open state | owning GitHub Issue | Project and local handoff references |
| Workflow status and Product Owner ordering | GitHub Project `O2I` | no product or authority fact |
| Verification evidence | tests and generated snapshots | no semantic ownership |

Tests verify contracts; they never define fachliche meaning.

# Retrieval Routes

- `README.md`, `o2i.md`, and `wtf.md`: purpose, normative fachliche/metamodel content, and informal orientation.
- `spc/lib/core/`: notation-independent structure, semantics, qualification, trace, readiness, and assessment contracts.
- `spc/ctr/archimate/`: declarative Profile, typed projection, and generated contract artifacts.
- `spc/lib/adapter/amx/`: bounded AMX acquisition and canonical native observations.
- `spc/lib/operation/` and `spc/cli/`: capability-sized execution, diagnostics, machine results, and thin rendering.
- `mdl/o2i.archimate` and `mdl/o2i-*.md`: reference model and generated review snapshots; agents never edit the model directly.
- `.ai4x/governance/`, `.ai4x/operations/`, `.agents/skills/`, and `.github/agents/`: canonical operating contracts and their lean routers.
- `utl/verify.sh`: canonical staged deterministic verification.

# Durable Invariants

- Keep terminology, metamodel semantics, concrete notation, formalization, and verification distinct and synchronized.
- Contextualized Primitive relations substantiate Context macrorelations; visual nesting alone has no contextualization semantics.
- Persisted propositions carry explicit `Candidate` or `Asserted` commitment. Candidates remain diagnostic, and Asserted propositions depend only on Asserted propositions.
- A complete effect trace precedes evidence readiness. Effect and target attainment remain independent assessments.
- The Profile projects notation structure; Core owns notation-independent well-formedness and semantic validity. Qualification, trace, readiness, and assessment remain separate capabilities rather than one validation pipeline.
- Semantic Views visualize the metamodel; syntax Views visualize the declarative Profile. Neither ArchiMate nor Python owns O2I semantics.
- Reference styling is editorial guidance, not instance conformance. Preserve the lean presentation boundary in `o2i.md` (Syntax) and `operations/modeling.md`: no cosmetic product checker or implicit graphical semantics; justified meaning-bearing checks belong in O2I libraries and the CLI.
