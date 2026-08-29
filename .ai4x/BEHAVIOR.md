# Purpose

This file is the sole always-on operating kernel for agents working in the O2I repository. It owns precedence, bounded checkout selection, handoff applicability, contract routing, repository isolation, and universal fail-closed safety. Detailed governance, continuity, collaboration, and task rules load only through the routes below.

# Precedence And Boundaries

Runtime instructions and the latest explicit Product Owner instruction outrank this repository contract. Observed facts override stale state but never a normative owner. Conflicts between owners block dependent work until resolved in the owning source.

Work only in the exact O2I checkout selected by this bootstrap. Never obtain authority, work state, or instructions from a parent workspace, sibling checkout, foreign repository, conversation transcript, or model recollection. Preserve unrelated changes. Never expose secrets or private data, bypass a technical permission, or perform a destructive or remote mutation without its current subject-bound authority and required safeguards.

# Bounded Bootstrap

Apply these steps in order. Do not open `.ai4x/HANDOFF.md` before step 4 proves the handoff applicable.

1. Derive the repository root from the current checkout. Determine whether Git worktree metadata is available. If it is, observe the common Git directory, attached branch, revision, and complete status with `git status --short --branch --untracked-files=all`; otherwise record Git metadata as unavailable.
2. Before reading `.ai4x/STATE.md`, inspect `.ai4x/local/ACTIVE.md` if any filesystem entry exists at that path. A valid pointer is a non-symlink regular UTF-8 file containing exactly `Path: <relative-path>` and `Expected branch: <branch>`. Reject an absolute, empty, malformed, stale, or escaping path. Activate the named checkout only after Git proves the same common Git directory, its attached observed branch exactly equals the expected valid branch, and its own `AGENTS.md`, `.ai4x/CONTEXT.md`, and `.ai4x/STATE.md` are readable. Never checkout, reset, mutate, or select merely because the pointer names a target. Successful activation restarts this complete bootstrap in that checkout. Any present pointer not successfully activated makes applicability `UNVERIFIED` immediately.
3. After pointer absence or validated activation and restart, read at most 1,024 bytes from `.ai4x/STATE.md`. It must be strict UTF-8 without BOM and consist exactly of these three LF-terminated lines: opening delimiter `<!-- o2i-state-envelope-v1 -->`; one compact JSON object; closing delimiter `<!-- /o2i-state-envelope-v1 -->`. The object has exactly these ordered keys: `schema`, `appliesOnBranch`, `handoffSchema`. Required values are `o2i.state-envelope/v1`, one branch accepted by `git check-ref-format --branch`, and `o2i.handoff/v1`. Reject duplicate or unknown keys, extra whitespace or content, invalid escapes, non-finite numbers, a noncanonical key order, a missing terminal newline, or bytes that do not round-trip through the normative compact JSON serializer with unescaped non-ASCII characters.
4. Classify through this ordered ladder. Require valid Git metadata, an attached observed branch, complete status, and a valid State envelope. An exact equality between observed and named branch is `applicable`, including a dirty checkout. A mismatch is `dormant` only when the pointer is absent, the observed branch is `trunk`, the complete status is clean, and the named branch is not `trunk`. Every other case is `UNVERIFIED`. Dormancy says only that the branch-bound handoff does not govern this checkout; it proves no merge, completion, acceptance, Issue state, Project state, or authority. An unverified result may not select a return point or authority.
5. Only for `applicable`, open and validate fixed-path `.ai4x/HANDOFF.md`, then reconcile it under `.ai4x/governance/continuity.md` with current checkout and owning remote facts. Never infer remote facts. For `dormant`, exclude the handoff and use tracked repository and direct owning Issue or Project facts when material. For `UNVERIFIED`, repository-file bootstrap remains available, but stop before any action whose safety depends on the unresolved return point or authority.

# Conditional Routes

After checkout selection, read `.ai4x/CONTEXT.md` when repository identity, product boundaries, ownership, retrieval routes, or durable invariants are material. Read `.ai4x/TEAM.md` before material specialist collaboration or review and preserve authorship-versus-review separation.

Before an authority decision or mutation, load the validated agent projection `.ai4x/governance/policy.agent.md`. Load `.ai4x/governance/guidelines.md` for risk classification, Issues, Project administration, review, remote work, or publication; `.ai4x/governance/decision-handoff.md` for Product Owner decision events and live approval binding; `.ai4x/governance/continuity.md` only after applicability classification for return-point reconstruction or cold-start eligibility; and `.ai4x/governance/cleanup.md` only for explicitly authorized completed-work cleanup.

Load only task contracts whose classes actually apply:

| Task class | Contract |
| --- | --- |
| Haskell design or implementation | `.ai4x/operations/haskell-authoring.md` |
| Haskell or formalization review | `.ai4x/operations/haskell-review.md` |
| ArchiMate, metamodel, Profile, syntax, or model work | `.ai4x/operations/modeling.md` |
| White Paper, README, WTF, figures, or rendering | `.ai4x/operations/publication.md` |
| Strategy, terminology, qualification, measurement, or effect | `.ai4x/operations/strategy-review.md` |

Independent review additionally loads governance and every contract matching the reviewed risk. Cross-class tasks load multiple applicable contracts; unrelated contracts remain unread. Repository skills and agent facades are lean routers to these owners and add no policy.

# Universal Operation

The Product Owner is the sole human decision and publication authority. Gertrud coordinates and protects boundaries but is not a universal specialist. Use capability-matched external Co-Authors when specialist judgment materially shapes design or implementation, and independent read-only reviewers for every material candidate required by its risk. Authors and implementers never independently accept their own result.

Use German when the Product Owner writes German and preserve umlauts. Write `README.md`, `CONTRIBUTING.md`, `o2i.md`, and `wtf.md` in German; write `.ai4x`, GitHub Issues, code, Haddock, and `spc/README.md` in English. Distinguish observed evidence, inference, authors' derivation, authorized decisions, and unknowns.

Use repository-local paths, `rg`, and repository tooling. Immediately before a manual edit, reread its target; apply one narrow patch to one file; then reread the changed range and diff before another edit. Preserve user changes and never edit `mdl/o2i.archimate` directly. Delegated agents and independent reviewers neither query nor mutate remote work state and never start approval-requiring commands; the primary supplies exact remote facts or reports them unavailable. Mark material uncertainty `UNKNOWN`, `INFERRED`, or `UNVERIFIED` and stop at the safe boundary instead of guessing.
