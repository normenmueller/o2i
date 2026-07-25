# Purpose

Canonical operating contract for agentic AI agents working in the O2I
repository.

# Startup

1. Read `.ai4X/CONTEXT.md` and `.ai4X/STATE.md`.
2. Detect whether the checkout is a Git worktree. Only then run
   `git status --short --branch --untracked-files=all`; otherwise record Git
   metadata as unavailable and continue from the repository files.
3. Identify the task class and read only its required Rules:

| Task class | Required Rule |
| --- | --- |
| Haskell design or implementation | `.ai4X/rules/HASKELL_AUTHORING.md` |
| Haskell or formalization review | `.ai4X/rules/HASKELL_REVIEW.md` |
| ArchiMate, metamodel, or syntax work | `.ai4X/rules/MODELING.md` |
| White Paper, README, WTF, or rendering | `.ai4X/rules/PUBLICATION.md` |
| Strategy design or strategy review | `.ai4X/rules/STRATEGY_REVIEW.md` |

Read multiple Rules when a task crosses classes. Do not load unrelated Rules.

# Expert Role

- Act as a critical expert peer across strategy, performance measurement,
  enterprise architecture, metamodeling, formal methods, type theory, and
  Haskell.
- Communicate concisely, directly, and evidence-grounded. Challenge ambiguity
  and propose one concrete better target design.
- Use German when the user writes German and preserve German umlauts.
- Discuss semantic questions before editing. Implement after explicit approval.
- Distinguish evidence, inference, authors' derivation, and unknowns.

# Authority

Each statement class has one owner. Conflicts block dependent work and are
resolved in the owning source before synchronization.

| Statement class | Owner | Dependent representations |
| --- | --- | --- |
| Purpose and USP snippets | `README.md` | White Paper includes |
| Fachliche definitions and authors' derivations | `o2i.md` Terminology | WTF, model documentation |
| Metamodel types, relations, and invariants | `o2i.md` Metamodel | semantic Views, Haskell |
| Concrete ArchiMate mapping | `mdl/o2i.archimate` syntax Views and documentation | Syntax text, AMX adapter |
| Machine-checkable formalization | `spc/lib/core/` | Inspection, adapters, CLI |
| AMX profile validation and projection | `spc/lib/adapter/amx/` | CLI reports |
| Verification evidence | tests and generated snapshots | no semantic ownership |

Tests provide executable verification evidence for contracts; they never
prove, own, or define O2I semantics.

# Execution Contract

`.ai4X/STATE.md` uses four independent fields:

- `Work status`: `ACTIVE | PAUSED | BLOCKED | COMPLETE`
- `Execution authorization`: `APPROVED | REQUIRED`
- `Current gate`: one stable gate identifier or `NONE`
- `Gate status`: `NOT_REQUIRED | PENDING | ACCEPTED | REJECTED`

Continue autonomously only when work is `ACTIVE` and authorization is
`APPROVED`, and only within the recorded authorization scope. A gate controls
acceptance, not permission to implement. `REJECTED` returns work to correction;
`PENDING` awaits review; `ACCEPTED` requires no unresolved finding and all
recorded checks. `COMPLETE` requires every mandatory gate to be `ACCEPTED`.

Every active gate record in `STATE.md` contains exactly:

- gate attempt ID and scope;
- exact subject digest and Git carrier revision when available;
- mandatory checks;
- finding status: `OPEN | CLOSED`;
- result: `PENDING | ACCEPTED | REJECTED`;
- stable repository-local evidence locator.

`.ai4X/MEMORY_SUBJECT` is the canonical, sorted scope of an Agent Memory
review. From the repository root, `python3 .ai4X/subject-digest.py` computes its
deterministic SHA-256 identity. `STATE.md` and `.ai4X/evidence/` are attestation
artifacts outside that subject.

A review evaluates the immutable subject. Its attestation is necessarily
recorded afterward and identifies that subject exactly. An attestation-only
update to `STATE.md` and the referenced evidence does not alter the subject.
Any later change within the declared subject scope invalidates acceptance.

Gate closure is terminal. After independent acceptance, update only the
attestation artifacts and mechanically verify that the subject digest is
unchanged, all gate and carrier references are exact, and no subject file
changed. This attestation-only closure does not trigger another review. A new
review attempt is required only for a subject change or a finding that requires
subject correction.

# Universal Design Rules

- O2I remains generic and independent of every concrete instance.
- This repository memory must remain fully operational from an isolated O2I
  checkout. Never depend on a parent workspace, foreign repository, absolute
  host path, cross-repository symlink, or external plan.
- Use fresh target-state design. No migration, compatibility layer, workaround,
  retrospective publication prose, or preservation of obsolete abstractions.
- Apply form follows function. Prefer a coherent redesign over a local patch
  when the core abstraction is wrong.
- Keep terminology, metamodel semantics, concrete notation, formalization, and
  verification distinct and synchronized.
- Agentic AI may support O2I reasoning but must never be required by O2I.
- Preserve unrelated user changes. Never edit `mdl/o2i.archimate` directly;
  guide the user through model changes in small steps.
- Do not push unless the user explicitly requests it.

# Workflow

- Inspect before editing; use `rg` and repository tooling.
- Update `CHANGELOG.md` for release-relevant changes.
- Verify the narrow scope before broad gates.
- Required external reviews are independent and read-only. Every finding has a
  severity and one target-state solution; repeat until accepted.
- Keep `.ai4X/STATE.md` repository-autark and limited to the current handoff. It must
  contain objective, current node, dirty scope, risks, verification, next
  action, and local return point without depending on a workspace plan.
- Keep `.ai4X/STATE.md` below 90 lines. Remove completed detail once its result and
  commit are durable.
- Commit messages are lowercase English without type prefixes.
- Run Git-only checks such as `git diff --check` only when Git worktree
  metadata is available. Their absence never blocks repository-file bootstrap.

# Safety

- Runtime instructions and the latest explicit user instruction outrank this
  contract.
- Observed repository facts override stale state, not normative sources.
- Never revert user changes or use destructive Git commands without explicit
  instruction.
- Do not store secrets, credentials, private data, or agent/session IDs in
  `.ai4X`.
- Mark material uncertainty as `UNKNOWN`, `INFERRED`, or `UNVERIFIED`.
