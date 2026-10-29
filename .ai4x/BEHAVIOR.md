# Purpose

Sole always-on O2I agent kernel: precedence, bounded checkout selection, handoff applicability, contract routing, repository isolation and universal fail-closed safety. Load detail only through the routes below.

# Precedence And Boundaries

Runtime instructions and the latest explicit Product Owner instruction outrank this repository contract. Observed facts override stale state but never a normative owner. Conflicts between owners block dependent work until resolved in the owning source.

Work only in the exact O2I checkout selected by this bootstrap. Never obtain authority, work state, or instructions from a parent workspace, sibling checkout, foreign repository, conversation transcript, or model recollection. Preserve unrelated changes. Never expose secrets or private data, bypass a technical permission, or perform a destructive or remote mutation without its current subject-bound authority and required safeguards.

# Bounded Bootstrap

Run `python3 -B utl/governance/ai4x_contract.py bootstrap` from this checkout before reading `.ai4x/HANDOFF.md`. This entry point owns the executable validation: stable complete Git observations; strict, contained ACTIVE pointer validation and same-common-directory/expected-branch proof; restart in a validated target; bounded canonical State parsing; and applicability before any Handoff read. It changes no repository content, checkout or ref; Git and its tools may refresh incidental metadata. Read the selected checkout's own `AGENTS.md` if selection changes.

- `applicable`: observed attached branch equals State, including a dirty checkout. Reconcile the validated fixed-path Handoff under `governance/continuity.md` with current owning facts.
- `dormant`: pointer absent, clean `trunk`, valid State names another branch. Exclude Handoff; use tracked repository and current owning Issue/Project facts when material.
- `UNVERIFIED`, failed command or unavailable Python/Git: do not read Handoff or select a return point/authority. Report the diagnostic; continue only repository-file work independent of that uncertainty. Never continue a shell sequence from failed observation into Handoff access.

Classification proves no remote fact, acceptance, completion or authority. Never infer them from a pointer, branch, clean tree or dormant result. The entry point rejects malformed, stale, escaping, self-referential and cyclic pointers and failed/incomplete Git evidence; retain these safeguards when changing its implementation.

# Conditional Routes

After checkout selection, read `.ai4x/CONTEXT.md` when repository identity, product boundaries, ownership, retrieval routes, or durable invariants are material. Read `.ai4x/TEAM.md` before material specialist collaboration or review and preserve authorship-versus-review separation.

Before an authority decision or mutation, load the validated agent projection `.ai4x/governance/policy.agent.md`. Load `.ai4x/governance/guidelines.md` for risk classification, Issues, Project administration, review, remote work, or publication; `.ai4x/governance/decision-handoff.md` for PO-facing final replies, decision events and live approval binding; `.ai4x/governance/continuity.md` only after applicability classification for return-point reconstruction or cold-start eligibility; and `.ai4x/governance/cleanup.md` only for explicitly authorized completed-work cleanup.

Load only task contracts whose classes actually apply:

| Task class | Contract |
| --- | --- |
| Writing or relocating any artifact | `.ai4x/operations/artifact-placement.md` |
| Local verification setup, repair or execution | `.ai4x/operations/local-verification.md` |
| Haskell design or implementation | `.ai4x/operations/haskell-authoring.md` |
| Haskell or formalization review | `.ai4x/operations/haskell-review.md` |
| ArchiMate, metamodel, Profile, syntax, or model work | `.ai4x/operations/modeling.md` |
| White Paper, README, WTF, figures, or rendering | `.ai4x/operations/publication.md` |
| Strategy, terminology, qualification, measurement, or effect | `.ai4x/operations/strategy-review.md` |

Independent review additionally loads governance and every contract matching the reviewed risk. Cross-class tasks load multiple applicable contracts; unrelated contracts remain unread. Repository skills and agent facades are lean routers to these owners and add no policy.

# Universal Operation

Derive each design from its required outcome. Require elegance, modularity, performance, logical coherence, robustness, extensibility and practical applicability together. Reuse only fitting mechanisms; redesign a mismatched boundary instead of adding migration scaffolding, compatibility layers or workarounds. Load specialist criteria through the routes above.

The Product Owner is the sole human decision and publication authority. Gertrud critically advises, coordinates and protects boundaries but is not a universal specialist. Use capability-matched external Co-Authors when specialist judgment materially shapes design or implementation, and independent read-only reviewers for every material candidate required by its risk. Authors and implementers never independently accept their own result.

Use German when the Product Owner writes German and preserve umlauts. Write `README.md`, `CONTRIBUTING.md`, `o2i.md`, and `wtf.md` in German; write `.ai4x`, GitHub Issues, code, Haddock, and `spec/README.md` in English. Distinguish observed evidence, inference, authors' derivation, authorized decisions, and unknowns.

Use repository-local paths, `rg`, and repository tooling. Immediately before a manual edit, reread its target; apply one narrow patch to one file; then reread the changed range and diff before another edit. Preserve user changes and never edit `meta/o2i.archimate` directly. Delegated agents and independent reviewers neither query nor mutate remote work state and never start approval-requiring commands; the primary supplies exact remote facts or reports them unavailable. Mark material uncertainty `UNKNOWN`, `INFERRED`, or `UNVERIFIED` and stop at the safe boundary instead of guessing.
