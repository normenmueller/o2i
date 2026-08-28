# O2I Governance Guidelines

O2I governance protects product quality and clear authority with the least process justified by actual risk. It defines no fachliche O2I semantics.

## Operating Principles

- Prefer working software, executable evidence, and clear ownership over ceremonial proof.
- Apply more process only when impact, irreversibility, or blast radius justifies it.
- Treat integration feedback as normal engineering evidence, especially during the O2I general overhaul.
- Preserve accepted evidence for its exact revision and scope without claiming permanent defect-freedom.
- Keep decisions discoverable, but record each fact once in its owning system.
- Never weaken deterministic verification, type safety, repository autonomy, documentation quality, security, or publication checks to save process effort.

## Authority

- A GitHub Issue owns its problem, target, scope, acceptance criteria, dependencies, material decisions, review evidence, and open or closed state.
- For Issue-free Routine work, the explicit Product Owner request owns the bounded scope and the concise repository handoff records it for local continuity. This exception creates no Project item, dependency, or durable product contract.
- Native Issue Dependencies own genuine prerequisite relations.
- The public GitHub Project [O2I](https://github.com/users/normenmueller/projects/4) owns workflow status and Product Owner ordering. It owns no product contract or acceptance fact.
- `.ai4x/STATE.md` is a concise repository-local handoff, not a backlog, audit log, or second workflow authority.
- Git commits and deterministic checks own implementation and verification artifacts.
- `CONTRIBUTING.md` is the concise human-facing projection of this contract.

## Risk-Proportionate Change Paths

Classify the actual change by impact, reversibility, and blast radius. Labels aid discovery but never determine process by themselves.

### Routine

Routine work is reversible, local, and semantics-preserving. Examples include focused bug fixes, refactoring without public-contract change, tests, documentation corrections, CI, tooling, and repository administration.

Minimum path: one understandable Issue or explicit Product Owner request, one focused candidate, relevant deterministic checks, and author self-review. Add an independent reviewer only when a material risk cannot be credibly closed by tests and local inspection.

### Significant

Significant work affects a public contract, crosses package or capability ownership, performs a migration, or has material user or repository blast radius without changing protected fachliche meaning.

Minimum path: one Issue with the design decision and alternatives that matter, explicit execution authority, relevant deterministic verification, and at least one independent reviewer whose capability matches the primary risk. Add another reviewer only for a materially distinct risk.

### Protected

Protected work changes fachliche terminology or metamodel semantics, normative syntax, irreversible compatibility commitments, release or publication authority, security-sensitive behavior, or repository governance authority.

Minimum path: explicit Product Owner decision, an Issue that states problem, benefit, target, scope, non-goals, risks, and observable acceptance criteria, risk-selected independent specialist review, complete applicable verification, and explicit Product Owner authority for any protected publication. Authority already granted for the exact work unit is not requested again per covered action.

An exact digest or immutable manifest is required only for an externally supplied authority, a release artifact, security-sensitive evidence, or another stated integrity need. File count, implementation effort, or uncertainty alone never escalates a change to the maximum process. When classification remains genuinely ambiguous after inspection, select the next safer path, not automatically `Protected`.

## Workflow

The Project workflow is:

```text
Backlog -> Refinement -> Ready -> In progress -> In review -> Done
                                      |
                                      +-> Paused -> Ready
```

- `Backlog` is an understandable idea or problem.
- `Refinement` is used when a material product or design decision still needs preparation. It is not a mandatory stop for routine work or already explicit Product Owner instructions.
- `Ready` is authorized and free of a prerequisite that blocks its next action. Explicit Product Owner direction can establish this authority without ceremonial status hops.
- `In progress` covers active design, implementation, investigation, reproduction, and correction.
- `In review` means a complete candidate is undergoing its required checks or awaits Product Owner publication authority.
- `Paused` is only a genuine wait state. Its Issue records one reason and return condition; active investigation is never paused merely because a question exists.
- `Done` is accepted, remotely available when publication is required, closed, and successfully verified at the required boundary.

The Board reflects work; it does not manufacture authority. The Product Owner sets priorities and decides protected scope, publication, and release. Agents may administer statuses after explicit authority and may correct an inaccurate status to reflect observed work.

Project order never creates a dependency. Use native Issue Dependencies for genuine prerequisites. Record an external prerequisite once in the affected Issue with its source and next-check condition.

### Atomic Ready-Issue Release Authority

An explicit Product Owner release of one exact Issue in Project status `Ready` is one atomic work-unit authority and, within that Issue's accepted scope, authorizes Gertrud to activate the Issue and carry it through `In review` without another action-level Product Owner prompt. This authority includes Project `In progress`, capability-matched specialist and Co-Author coordination, implementation, deterministic verification, independent review and corrections, commit, push, Pull Request publication, green required remote verification, evidence receipts, and Project `In review`.

Project status `Ready` alone creates no authority. Fresh Product Owner authority is required only when the next action expands the stated scope or target, crosses an explicit exclusion, or introduces material irreversibility outside the bound authority. A Ready-Issue release never authorizes scope or target expansion, bypassing statement owners or required role separation, merge, Issue closure, Project `Done`, branch or worktree cleanup, release or tag, protected publication, or another materially irreversible action outside its explicit boundary. It is explicit Product Owner authority for only the listed Issue-scoped remote writes; every covered action retains its required review, deterministic and remote verification, protected-branch controls, and verified machine identity without becoming a new approval point.

Host, sandbox, and tool permissions are independent technical execution controls. A required permission may block an otherwise authorized command and must never be bypassed, but its grant or denial neither creates nor narrows Product Owner governance authority and never justifies a duplicate Product Owner approval prompt. Agent remote writes stop when the required machine identity is unavailable or unverified.

`10/10` is Product Owner shorthand for all required formal verdicts being `accepted`, zero blocking or advisory findings, all exact-candidate local and remote checks being green, and intact authorship-versus-review separation. It is never a formal review score, and `accepted with follow-ups` does not satisfy it.

### Completed-Issue Cleanup Authority

Explicit Product Owner authority for one exact Issue's completion actions remains effective according to its stated scope and conditions. When that authority also covers cleanup, only the cleanup portion becomes executable after the Issue is accepted, published when publication is required, green at its required remote verification boundary, closed, and in Project status `Done`. Gertrud must then remove all no-longer-needed Issue-scoped local and remote working branches, linked worktrees, Issue-owned stashes, any stale `.ai4x/local/ACTIVE.md` pointer, and Issue-owned scratch artifacts. Cleanup is part of the authorized completion, not an optional chat convention. The ordinary Ready-Issue release through `In review` never authorizes completion or cleanup.

Before deleting anything, Gertrud performs one read-only preflight that:

1. verifies the exact Issue, accepted and published result, required remote checks, closed state, Project `Done`, and explicit Product Owner completion-and-cleanup authority;
2. enumerates every exact candidate by stable identity and expected ref where applicable: named local branch and ref, named remote branch and ref, repository-relative linked-worktree path, named stash and object, exact active-checkout pointer, and exact Issue-owned scratch path;
3. proves that each candidate's unique work is durable on the owning published branch or intentionally obsolete under the same authority; and
4. excludes default or protected branches; active, review, unmerged, or recovery branches; active worktrees or handoffs; stashes or scratch artifacts containing unique or user-owned data; anything outside the completed Issue's scope; and every broad root, unresolved variable, glob, or recursive filesystem deletion target.

Immediately before each individual deletion, re-resolve the exact target and revalidate its stable identity plus any expected ref against the preflight; any mismatch stops cleanup before that mutation. Use scoped native Git operations for worktrees and branches; never substitute a broad direct filesystem deletion. Clear a stale active-checkout pointer before removing the exact worktree it names and remove a linked worktree before its local branch. Perform remote branch deletion only through the verified machine identity and with a lease or equivalent conditional operation bound to the expected ref. A missing fact, ambiguous owner, unique change, failed durability proof, or identity mismatch stops cleanup at the safe boundary without weakening the exclusions.

After cleanup, re-inventory local and remote branches, worktrees, stashes, the active-checkout pointer, and Issue-owned scratch paths. Confirm that every authorized target is absent and every protected or unrelated target remains. Correct stale Project or `.ai4x/local/ACTIVE.md` state only within the same explicit authority; otherwise report it without inference or mutation.

## Epics, Stories, And Batches

Use native Sub-Issues when they materially improve visibility of a multi-part deliverable. Do not create them merely because work has multiple files, owners, days, or handoffs.

The parent owns integrated scope, authority, acceptance, and publication. A Story or batch owns one bounded deliverable and its own open or closed state; it adds no product scope or authority and never substitutes for a dependency. Keep its body concise. Put active Stories on the Project when that improves Product Owner visibility.

Close a Story when its bounded deliverable and checks are complete. The parent remains open until integrated acceptance and publication conditions are met. A new concern outside the parent scope receives its own Issue.

## Later Integration Findings

A concern discovered while consuming accepted work is first an acceptance challenge, not a retroactive invalidation.

1. Reproduce the concern against the exact accepted revision and governing authority.
2. Classify it as a predecessor defect, current-work responsibility, contract ambiguity, or non-finding.
3. Keep the accepted historical evidence valid for its declared subject.
4. Create a new linked correction Issue for a confirmed predecessor defect by default. Reopen closed history only when the Product Owner explicitly chooses that representation.
5. Continue active reproduction and correction in `In progress`; use `Paused` only for an actual wait state.

A challenge blocks only the dependent action it makes unsafe. It never silently expands scope or authorizes a workaround, compatibility layer, weakened verification, or change to fachliche meaning.

## Specialist Collaboration

Gertrud is the repository-local coordinating referent, not a substitute for capability-matched expertise. Select specialists through `.ai4x/TEAM.md` from the actual domain and risk. When specialist judgment materially shapes design or implementation, an external Co-Author participates actively in both; later review of a primary-only result is not equivalent co-authoring.

Every material collaboration record states the assigned capability, role, owned scope, contribution, changed paths where applicable, checks, findings, and separation between authorship and independent review. Resource constraints may sequence participation but never waive a required capability or silently transfer it to Gertrud.

## Review

Every review records the reviewed revision or other exact subject, declared scope, reviewer capability, checks performed, findings, and one verdict:

- `accepted`: no blocking finding remains;
- `accepted with follow-ups`: no blocking finding remains and separately tracked advisory improvements do not prevent acceptance;
- `changes required`: at least one blocking finding remains.

Numerical scores are prohibited. Review depth follows the risk path above. Reviewers assess critically, neutrally, objectively, independently, and read-only against the exact candidate; review is never an acceptance default. An implementer or Co-Author never independently accepts their own result. A reviewer states one target-state remedy for each blocking finding and distinguishes required correction from optional improvement.

Later changes require review only for the changed risk surface. They do not invalidate historical evidence for unchanged revisions and laws. Correct a published review receipt with a new comment rather than editing its history.

## Remote Facts And Delegation

Delegated agents and independent reviewers never query or mutate remote Issue, Project, review, or CI state directly. They request material remote facts from the primary agent, which returns the unmodified result or reports it unavailable without inference.

Delegated agents never start commands that require host or sandbox approval. The primary agent executes any necessary approved command in the main thread. When GitHub is unavailable, continue only an already active local scope and do not infer remote state.

Use the connected GitHub application for connector-covered reads. Use `gh` only when the connector lacks the required capability. Stage temporary remote-write bodies under repository-local ignored `.ai4x/local/remote/`, never in tracked repository paths.

## Attribution And Publication

- `gertrud-ai4x` is the transparent O2I machine user for agentic work.
- Agent-produced implementation commits use `Gertrud ai4X <311782161+gertrud-ai4x@users.noreply.github.com>` as author and preserve the configured accountable human as committer.
- Commits that change `.ai4x/` are Product Owner authority commits and use the configured Product Owner identity as author and committer.
- Issue-scoped commits include `Refs #N`. Use `Closes #N` only when publication of that commit actually completes the Issue.
- Assign `gertrud-ai4x` when the primary agent takes material responsibility. Advisory participation alone creates no assignment.
- Agent-originated Issue comments and agent-administered Project transitions use the machine user. Never impersonate an unavailable identity.
- The primary agent may prepare and review local candidates within explicit scope. Push, release, protected publication, and accountable Product Owner decisions require explicit Product Owner authority; an exact work-unit authority may cover a push without a second action-level request.

Before a Product Owner push, report every outgoing commit, its scope, verification, review verdict, and any non-blocking follow-up. No reviewed file changes occur between accepted review and publication.

## Repository Handoff

Keep `.ai4x/STATE.md` below 90 lines and useful from an isolated checkout. It contains only:

- current Issue or `NONE`, and work status;
- current objective and explicit authority;
- material risk, blocker, or open acceptance challenge;
- verification and review state;
- next action and local return point.

Use `NONE` only for explicit Product Owner authority over Issue-free Routine work. Use `ACTIVE` for design, implementation, investigation, correction, review, and publication preparation; `PAUSED` only for a genuine wait; and `COMPLETE` only after the recorded work is actually complete. Do not create self-referential gates, duplicate Issue history, or require a follow-up commit merely to refresh a stale handoff after publication.

Product Owner-facing completion and status handoff reports follow the deterministic Product Owner Decision Handoff in `.ai4x/BEHAVIOR.md`. The decision block is a presentation and authority-request contract, not workflow state or authority, and is never copied into `.ai4x/STATE.md`.

## Verification

Repository verification remains deterministic and network-independent. Before every commit, run every stage selected for the changed paths by the canonical path matrix. If classification is unknown or spans a shared contract, run the complete suite. Before every release tag, run:

```sh
./utl/verify.sh
```

Direct branch pushes do not trigger GitHub Actions. Remote verification runs only for Pull Requests, manual dispatches, and release tags matching `o2i-v*`. A release is accepted only after required remote verification succeeds. Do not use `[skip ci]` as a routine workflow mechanism.
