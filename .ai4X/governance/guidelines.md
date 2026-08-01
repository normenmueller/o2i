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

## Refinement And Authorization

The linear workflow is:

```text
Backlog -> Refined -> Ready -> In progress -> In review -> Done
```

- `Backlog` captures an understandable idea, problem, and rough target without design, admission, or implementation authority.
- `Refined` contains one viable, internally consistent contract whose complete Issue body and existing comments have been assessed and consolidated.
- `Ready` is an open Issue explicitly authorized by the Product Owner, complete for its applicable Admission and implementation contract, within the recorded local authorization scope, free of any prerequisite blocking its next action, and queued for execution.
- `In progress` is authorized work actively implemented by an agent.
- `In review` binds an exact candidate revision to its mandatory verification and independent review gate.
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

## Review And Closure

Every accepted review comment records:

- phase and reviewer capability;
- exact Issue-body digest for Admission;
- implementation-contract comment ID and digest for Finalreview;
- full candidate revision and reviewed scope for Finalreview;
- verdict, findings, checks, and every required dimension score.

One reviewer satisfies one capability per gate. Finalreviews bind the same candidate revision. Acceptance requires no finding and 10.0 in every required dimension.

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
