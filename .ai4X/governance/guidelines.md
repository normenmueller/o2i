# O2I Governance Guidelines

O2I uses a lean, agentic-first rule for change: think before writing. This contract governs O2I development and defines no fachliche O2I semantics.

## Authority

- A GitHub Issue owns its problem, target, scope, acceptance criteria, dependencies, admission, implementation contract, review evidence, and open or closed state.
- Native Issue Dependencies own genuine prerequisite relations.
- The public GitHub Project [O2I](https://github.com/users/normenmueller/projects/4) owns workflow status and Product Owner ordering. It owns no contract, admission, dependency, review, or closure fact.
- `.ai4X/STATE.md` holds only the activated repository-local handoff. It is neither backlog nor history.
- Git commits and CI own implementation and verification artifacts.
- `CONTRIBUTING.md` is the concise human-facing projection of this contract.

Do not duplicate Project workflow state or Project history in `.ai4X`.

## Change Classification

Use `framework-change` when work affects terminology, metamodel semantics, normative syntax, formalization, validation behavior, or a public API.

Use `maintenance` for semantics-preserving tooling, presentation, tests, CI, agent memory, workflow, or repository administration. Review depth follows demonstrated risk. If classification is uncertain, use `framework-change`.

## Maintenance Review

Maintenance has no Framework Admission requirement or Admission digest. Advisory review is optional and never grants implementation authority or produces gate evidence.

Before acceptance, every exact Maintenance candidate revision receives at least one independent Finalreview by an external reviewer whose capability matches the actual impact and risk of the change. Record the selected capability and one concise risk rationale. Add another reviewer only when a materially distinct risk cannot be credibly assessed by the selected reviewer. Do not impose a fixed capability table, reviewer bundle, reviewer count, or reviewer-selection mechanism.

Each Finalreview binds the exact revision and scope and records findings, checks, and scores for its selected quality dimensions. Any finding rejects that exact candidate and requires review of a corrected revision. Acceptance requires no finding and 10.0 in every selected dimension.

Suspected terminology, metamodel-semantic, normative-syntax, formalization, validation-behavior, or public-API impact triggers reclassification assessment as `framework-change`; Maintenance review never substitutes for Framework Admission.

## Refinement And Authorization

The linear workflow is:

```text
Backlog -> Refined -> Ready -> In progress -> In review -> Done
```

- `Backlog` captures an understandable idea, problem, and rough target without design, admission, or implementation authority.
- `Refined` contains one viable, internally consistent contract whose complete Issue body and existing comments have been assessed and consolidated.
- `Ready` is an open Issue explicitly authorized by the Product Owner, complete for its applicable Admission and implementation contract, within the recorded local authorization scope, free of any prerequisite blocking its next action, and queued for execution.
- `In progress` is authorized work actively implemented by an agent.
- `In review` binds an exact candidate revision to mandatory verification and risk-selected independent review.
- `Done` is accepted, remotely available, successfully verified when remote verification is required, and closed.
- `Paused` is a side state for an actual interruption with one explicit reason and return condition.

Backlog intake is deliberately lightweight. When the Product Owner presents an idea for Backlog intake, the primary agent briefly evaluates O2I fit, expected benefit, possible duplicates, change classification, and suitable labels; asks only questions that materially affect capture; and records a suitable idea directly in `Backlog` without design, Admission, or implementation authority.

Agents may mature `Backlog -> Refined`. They first read the complete Issue body and every existing comment, resolve compatible material into the body, and obtain an explicit Product Owner decision for conflicts or superseded instructions. This refinement is not implementation.

Only the Product Owner moves `Refined -> Ready`. That transition is the execution authorization. Agents neither perform nor infer it.

Agents control later transitions within the authorized contract:

- `Ready -> In progress` requires the complete Ready contract to remain true and follows Ready order unless the Product Owner explicitly authorizes parallel execution or another order.
- `In progress -> In review` requires release notes when release-relevant, completed implementation and verification, and one committed exact candidate revision.
- `In review -> In progress` follows a rejected review or open finding and requires no renewed Product Owner authorization.
- `In review -> Done` requires accepted review evidence for that exact revision, remote availability, required remote verification, Issue closure, and then Project status `Done`.
- `In progress -> Paused` records the actual interruption and one return condition.
- `Paused -> Ready` requires that condition and every genuine blocker to be resolved. Existing authorization remains valid only for unchanged scope; a material scope change returns through refinement and Product Owner authorization.

Vertical order means refinement priority in `Backlog`, Product Owner decision priority in `Refined`, and authorized execution order in `Ready`. Order in every other Project column has no workflow meaning. After completing authorized work, agents continue with the next Ready Issue or pause when none exists.

Later comments never silently mutate a Refined, Ready, or active contract. Amend the explicit contract and return it to the required state, or record a new Issue. Findings within admitted scope remain correction work.

## Implementation Batches

When the authorized implementation contract names implementation batches, activation of the parent as `In progress` creates exactly one direct GitHub Sub-Issue for every named batch before that batch begins. An authorized contract amendment that adds a batch creates its Sub-Issue before the new batch begins. Work without an explicit batch-based implementation contract creates no Sub-Issues; ownership, blockers, handoffs, size, and duration introduce no additional trigger.

Each batch Sub-Issue body contains only the parent and implementation-contract link, batch identifier and title, concise deliverable, inherited batch completion conditions, and current assignee when known. It states that it makes one authorized implementation batch visible, adds no scope or authorization, and leaves the parent authoritative. Lifecycle comments may record only a blocker or pause reason, its return condition, and implementation or verification evidence.

Batch Sub-Issues remain outside the O2I Project and have no independent authorization, Admission, dependency, Project workflow, review, or acceptance authority over the parent. Each child owns its own open or closed state; closing it records only completion of that batch and neither accepts nor closes the parent. They never copy parent-wide contracts or evidence, never nest, and never substitute for native Issue Dependencies.

Close a batch Sub-Issue when its contracted deliverable and completion conditions are satisfied. A blocked or paused batch records its reason and return condition without automatically changing the parent. The parent enters `In review` only after every required batch Sub-Issue is closed; a review correction reopens the affected batch when the correction belongs to it.

Work discovered outside the authorized parent contract stops and follows ordinary refinement and Product Owner authorization or receives a separate Backlog Issue. A batch Sub-Issue never absorbs new scope.

## Dependencies

Model every genuine O2I prerequisite with a native Issue Dependency. Project order never creates a dependency. Duplicated prose, labels, and non-blocking lineage links never substitute for one.

A required dependency outside the O2I Issue graph is recorded in the affected Issue with its source and next-check condition. No dedicated label is reserved for it, and a blocker alone does not imply `Paused`.

An idea discovered during implementation receives its own Issue before it changes admitted scope.

## Framework Admission

A Framework-change Issue states:

1. generic problem and affected users;
2. generic benefit and fit with O2I;
3. fresh target state;
4. scope, non-goals, alternatives, and risks;
5. observable acceptance criteria;
6. participants, lineage, and required review capabilities.

Strategy and formalization reviewers independently accept the exact Issue-body digest. The author, co-authors, and reviewers are distinct. From the first Admission review, the body is contractually frozen; editing it invalidates Admission.

The implementation contract is written after Admission as one separate digest-bound Issue comment. A changed contract is a new comment and requires a new impact classification.

A digest is lowercase SHA-256 over the exact UTF-8 bytes returned by the GitHub API for the Issue body or implementation-contract comment body, without normalization or an added newline. Comment evidence additionally records the immutable comment database ID.

## Remote Facts And Delegation

Delegated agents and independent reviewers never query or mutate remote Issue, Project, review, or CI state directly. They request every material remote fact from the primary agent and state why it is needed.

The primary agent performs the authoritative query and returns the unmodified result, including absence or failure. Unavailable facts remain unavailable and are never inferred. Delegated work remains read-only with respect to remote work state.

Read GitHub Issue and comment bodies through the connected GitHub application and compute required SHA-256 digests directly over its exact UTF-8 result in the orchestration process. Do not introduce a repository utility, temporary file, `gh api` pipeline, or Python subprocess for a connector-covered read. Use `gh` only when the connector lacks the required capability.

When GitHub is unavailable, agents continue only an already activated local handoff. They never infer, create, transition, or close remote work offline.

## Attribution And Accountability

- `gertrud-ai4x` is the transparent O2I machine user for agentic work.
- Agent-produced commits use `Gertrud ai4X <311782161+gertrud-ai4x@users.noreply.github.com>` as author and preserve the configured accountable human as committer. Never rewrite existing commits merely to add this attribution.
- Issue-scoped commits include `Refs #N` in the commit body. Use `Closes #N` only when the commit actually completes the Issue; never rewrite existing history merely to add a reference.
- Add `gertrud-ai4x` as an assignee when the primary agent takes material responsibility for refining, coordinating, or implementing an Issue. Advisory-only participation creates no assignment.
- A commit that changes `.ai4X/` is an authority commit: keep it separate from implementation changes and use the configured Product Owner identity as both author and committer. The machine user never authors its own operating authority.
- The primary agent may create an authority commit locally but never pushes it. Before a Product Owner push, report every outgoing commit and its scope. The Product Owner's own push accepts and publishes those authority commits; no separate pre-commit confirmation is required.
- Agent-originated Issue comments and agent-controlled Project transitions from `Ready` onward use the machine user. If its separate authentication is unavailable, do not impersonate it through the Product Owner account.
- Product Owner authorization, `Refined -> Ready`, release authorization, and other accountable decisions remain actions of the Product Owner.
- The machine user may publish evidence produced by an independent reviewer but never becomes or impersonates that reviewer; the evidence identifies the actual independent capability and exact subject.
- Store machine-user credentials only in host credential storage, never in the repository or Agent Memory.

## Review And Closure

Every accepted review comment records:

- phase and reviewer capability;
- full candidate revision and reviewed scope for Finalreview;
- verdict, findings, checks, and every required dimension score.

Framework-change evidence additionally records the exact Issue-body digest for Admission and the implementation-contract comment ID and digest for Finalreview. Maintenance Finalreview evidence instead records the selected capability and concise risk rationale; it requires neither an Admission digest nor an implementation-contract comment.

Reviewers assess critically, neutrally, objectively, and independently. Review is never an acceptance default: reject the candidate when a substantiated objection, improvement, or materially better alternative exists under the applicable criteria of leanness, clarity, elegance, robustness, modularity, and usefulness.

For Framework Changes, one reviewer satisfies one capability per gate. Maintenance follows the minimum independent-review contract above. Finalreviews bind the same candidate revision. Acceptance requires no finding and 10.0 in every required dimension.

Accepted comments are append-only. Editing invalidates the evidence; corrections use a new comment. Review capabilities follow actual impact, and semantics-preserving Maintenance does not activate every specialist by default.

After acceptance, make the accepted exact revision available from the configured remote, complete required remote verification, close the Issue, and set Project status `Done`. No reviewed file changes between Finalreview and publication.

Git and the Issue retain history. No local change archive is created. A rejected Finalreview returns to `In progress`. Work discarded by the Product Owner is closed as not planned and its Project item is archived.

## Verification

Repository verification remains deterministic and network-independent. Before every commit, run every verification stage selected for the changed paths by the canonical path matrix; if classification is unknown or spans a shared contract, run the complete suite. Before every release tag, run the complete suite locally:

```sh
./utl/verify.sh
```

Direct branch pushes do not trigger GitHub Actions. Remote verification runs only for Pull Requests, manual dispatches, and release tags matching `o2i-v*`. Pull Requests use conservative path-sensitive selection; manual dispatches and release tags always run the complete suite. A release is not accepted until its remote verification succeeds.

Do not use `[skip ci]` as a routine workflow mechanism. The repository trigger policy, not commit-message decoration, owns whether remote verification runs.
