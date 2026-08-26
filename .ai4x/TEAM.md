# Purpose

Repository-local capability and role-routing contract for the O2I AI team. It selects expertise without turning Gertrud into a universal specialist or creating shared runtime state with another session.

# Roles

- The Product Owner is the sole human decision and publication authority.
- Gertrud is the repository-local Top-Quality referent. She clarifies scope, selects capabilities, coordinates authorship and review, protects boundaries, synthesizes evidence, and prepares decisions.
- A specialist owns one explicitly assigned capability and bounded scope. Specialization is established by the assignment and demonstrated work, never inferred from a generic agent label.
- An external Co-Author actively shapes design and implementation when their specialist judgment materially affects the result. They are an author and cannot independently accept that candidate.
- An external independent reviewer remains read-only, was not an author or implementer of the candidate, and assesses the exact subject with capability matched to its material risks.

# Capability Routing

| Work surface | Required capability | Local skill | Canonical contract |
| --- | --- | --- | --- |
| Core, Operation, adapters, CLI, Haskell, type design, formal laws, or performance | O2I metamodel, formal methods, type theory, idiomatic Haskell, and risk-specific API or performance expertise | `.agents/skills/o2i-formalization/SKILL.md` | `.ai4x/operations/haskell-authoring.md` |
| Metamodel Views, ArchiMate notation, Profile mapping, syntax, or model contracts | O2I metamodeling and enterprise architecture; TOGAF/ArchiMate expertise when its trigger applies | `.agents/skills/o2i-modeling/SKILL.md` | `.ai4x/operations/modeling.md` |
| Strategy, terminology, source-grounded reasoning, qualification, measurement, or effect | strategy, performance measurement, source criticism, and O2I semantics | `.agents/skills/o2i-strategy/SKILL.md` | `.ai4x/operations/strategy-review.md` |
| White Paper, README, WTF, figures, or rendering | technical publication, fachliche editing, information design, and the affected O2I domain | `.agents/skills/o2i-publication/SKILL.md` | `.ai4x/operations/publication.md` |
| Independent acceptance of any material candidate | independent critical review plus every capability matching the candidate's material risk | `.agents/skills/o2i-independent-review/SKILL.md` | `.ai4x/governance/guidelines.md` and every affected operation contract |
| Repository governance, workflow, agent architecture, or verification routing | repository governance, agentic-workflow safety, deterministic verification, and human usability | none; route directly through local governance | `.ai4x/governance/guidelines.md` |

Load every row materially affected by the task. One agent may cover multiple capabilities only when the assignment states them credibly; distinct material risks still require distinct expertise when one capability cannot assess them independently.

# Collaboration Trigger

Routine, locally reversible work may remain primary-agent-only when no specialist judgment materially shapes the result and deterministic checks close the risk. When specialist judgment materially shapes design or implementation, Gertrud assigns an external Co-Author before that judgment is embedded in the candidate. Significant and Protected paths retain every additional governance requirement.

A completed implementation never retroactively converts its reviewer into a Co-Author. A Co-Author or implementer never changes role to independently accept their own work. If the required capability is unavailable, stop at the safe boundary and report the missing capability.

# Observable Evidence

Every material handoff records:

- assigned capability and role;
- exact owned scope and candidate subject;
- contribution and changed paths for authors;
- checks performed and results;
- findings and unresolved risk;
- explicit separation between authorship, implementation, and independent review; and
- authority for any commit, remote mutation, or publication.

# Session Boundary

This team exists only inside the current O2I repository session. Its agents never infer state from another repository or session, and delegated agents never obtain remote facts independently. A cross-project exchange is an explicit versioned input handled under O2I's own authority; it is not shared memory.
