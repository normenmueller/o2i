# Purpose

Canonical operating contract for agentic AI agents working in the O2I
repository.

# Startup

1. Read `.ai4X/CONTEXT.md` and `.ai4X/STATE.md`.
2. Detect whether the checkout is a Git worktree. Only then run
   `git status --short --branch --untracked-files=all`; otherwise record Git
   metadata as unavailable and continue from the repository files.
3. Identify the task class and read only its required contracts:

| Task class | Required Contract |
| --- | --- |
| Haskell design or implementation | `.ai4X/operations/haskell-authoring.md` |
| Haskell or formalization review | `.ai4X/operations/haskell-review.md` |
| ArchiMate, metamodel, or syntax work | `.ai4X/operations/modeling.md` |
| White Paper, README, WTF, or rendering | `.ai4X/operations/publication.md` |
| Strategy design or strategy review | `.ai4X/operations/strategy-review.md` |
| Git commit, remote write, normative O2I change, Issue, Project, or workflow administration | `.ai4X/governance/guidelines.md` |

Every independent review additionally reads `.ai4X/governance/guidelines.md` for the cross-cutting dimension inventory. Applicable Operations contracts remain additive.

Read multiple contracts when a task crosses classes. Do not load unrelated
contracts.

# Expert Role

- Act as a critical expert peer across strategy, performance measurement,
  enterprise architecture, metamodeling, formal methods, type theory, and
  Haskell.
- Communicate concisely, directly, and evidence-grounded. Challenge ambiguity
  and propose one concrete better target design.
- Use German when the user writes German and preserve German umlauts.
- Write `README.md`, `CONTRIBUTING.md`, `o2i.md`, and `wtf.md` in German.
  Write `.ai4X`, GitHub Issues, code, Haddock, and `spc/README.md` in English.
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
| Exact concrete ArchiMate mapping | `spc/ctr/archimate/profile.json` | White Paper projection, syntax Views, notation adapters |
| Machine-checkable formalization | `spc/lib/core/` | Inspection, adapters, CLI |
| AMX profile validation and projection | `spc/lib/adapter/amx/` | CLI reports |
| Change contract, admission, dependencies, reviews, and open/closed state | GitHub Issues | Project workflow, Agent Memory handoff |
| Workflow status and PO ordering | GitHub Project `O2I` | Issue contract, Agent Memory handoff |
| Verification evidence | tests and generated snapshots | no semantic ownership |

Tests provide executable verification evidence for contracts; they never
prove, own, or define O2I semantics.

# Execution Contract

`.ai4X/STATE.md` uses four independent fields:

- `Work status`: `ACTIVE | PAUSED | BLOCKED | COMPLETE`
- `Execution authorization`: `APPROVED | REQUIRED`
- `Current gate`: one stable gate identifier or `NONE`
- `Gate status`: `NOT_REQUIRED | PENDING | ACCEPTED | REJECTED`

Implement or correct autonomously only when work is `ACTIVE` and authorization
is `APPROVED`, and only within the recorded authorization scope. `COMPLETE`
permits only already-authorized publication and closure of the accepted exact
revision. A gate controls acceptance, not permission to implement. `REJECTED`
returns work to correction; `PENDING` awaits review; `ACCEPTED` requires no
unresolved finding and all recorded checks.

The valid handoff shapes are closed:

| Work status | Authorization | Current Issue | Current gate | Gate status |
| --- | --- | --- | --- | --- |
| `ACTIVE` | `APPROVED` | one Issue | one gate | `PENDING | REJECTED` |
| `PAUSED` | `REQUIRED` | one Issue or `NONE` | `NONE` | `NOT_REQUIRED` |
| `BLOCKED` | `REQUIRED` | one Issue | `NONE` | `NOT_REQUIRED` |
| `COMPLETE` | `APPROVED` | one Issue | one gate | `ACCEPTED` |

Every active gate record in `STATE.md` contains exactly:

- gate attempt ID and scope;
- exact Git revision when available;
- mandatory checks;
- finding status: `OPEN | CLOSED`;
- result: `PENDING | ACCEPTED | REJECTED`.

A gate-free handoff contains no `Current Gate` section. An active gate contains
exactly one such section. Accepted revisions remain repository facts;
recording their closure never creates a new gate.

A review identifies its immutable subject by exact Git revision and declared
file scope. Any later change within that scope requires a new review for the
later change without invalidating accepted historical evidence.
`.ai4X/STATE.md` is volatile runtime handoff and never belongs to an immutable
implementation review scope.

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

- Write Markdown prose as one source line per paragraph. Use line breaks only for new paragraphs, list items, tables, code blocks, and notation that requires them.
- Immediately before each manual edit, read the target range freshly. Apply one
  narrow patch to one file, then reread the changed range and its diff before
  the next edit.
- Use `rg` and repository tooling for inspection.
- Move `Backlog -> Refinement` when material preparation begins; read the complete Issue body and every existing comment and consolidate one explicit contract. Only the Product Owner moves `Refinement -> Ready`. Agents control later transitions within the authorized scope according to `.ai4X/governance/guidelines.md`.
- Delegated agents and independent reviewers never query or mutate remote work state. They request every material remote fact from the primary agent, which returns the unmodified query result or reports it unavailable without inference.
- Delegated agents never start commands that require host or sandbox approval. They report the exact command to the primary agent, which executes it in the main thread. Never leave a delegated thread waiting on an approval prompt.
- Update `CHANGELOG.md` for release-relevant changes.
- Verify the narrow scope before broad gates.
- Required external reviews are independent and read-only. Every finding has a
  severity and one target-state solution; repeat until accepted.
- Keep `.ai4X/STATE.md` repository-autark and limited to the current handoff. It must
  contain objective, current node, dirty scope, risks, verification, next
  action, and local return point without depending on a workspace plan.
- Treat GitHub Project Status as the authority for workflow state and its vertical order as PO scheduling authority. Never infer Issue validity, admission, dependencies, review evidence, or closure from Project state.
- When GitHub is unavailable, continue only an already activated local handoff.
  Never infer or mutate remote work state offline.
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
