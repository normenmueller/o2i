# O2I Governance Guidelines

O2I uses a lean, agentic-first rule for change: think before writing. This contract governs O2I development and defines no fachliche O2I semantics.

## Authority

- A GitHub Issue owns its problem, target, scope, acceptance criteria, dependencies, admission, implementation contract, state, and review evidence.
- Native Issue Dependencies own genuine prerequisite relations.
- The public GitHub Project [O2I](https://github.com/users/normenmueller/projects/4) is the Product Owner scheduling view. It owns no admission, dependency, review, or closure fact.
- `.ai4X/STATE.md` holds only the activated repository-local handoff. It is neither backlog nor history.
- Git commits and CI own implementation and verification artifacts.
- `CONTRIBUTING.md` is the concise human-facing projection of this contract.

Do not duplicate Issue state or Project history in `.ai4X`.

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
- `Ready` is explicitly authorized by the Product Owner and queued for execution.
- `In progress` is authorized work actively implemented by an agent.
- `In review` binds an exact candidate revision to its mandatory verification and independent review gate.
- `Done` is accepted, remotely available when required, and closed.
- `Paused` is a side state for an actual interruption with one explicit reason and return condition.

Agents may mature `Backlog -> Refined`. They first read the complete Issue body and every existing comment, resolve compatible material into the body, and obtain an explicit Product Owner decision for conflicts or superseded instructions. This refinement is not implementation.

Only the Product Owner moves `Refined -> Ready`. That transition is the execution authorization. Agents neither perform nor infer it.

Agents control later transitions within the authorized contract:

- `Ready -> In progress` follows Ready order unless the Product Owner explicitly authorizes parallel execution or another order.
- `In progress -> In review` requires completed implementation and an exact verification candidate.
- `In review -> In progress` follows a rejected review or open finding and requires no renewed Product Owner authorization.
- `In review -> Done` requires accepted review evidence, required remote verification, Issue closure, and then Project status `Done`.
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

## Remote Facts And Delegation

Delegated agents and independent reviewers never query or mutate remote Issue, Project, review, or CI state directly. They request every material remote fact from the primary agent and state why it is needed.

The primary agent performs the authoritative query and returns the unmodified result, including absence or failure. Unavailable facts remain unavailable and are never inferred. Delegated work remains read-only with respect to remote work state.

When GitHub is unavailable, agents continue only an already activated local handoff. They never infer, create, transition, or close remote work offline.

## Review And Closure

Every accepted review comment records:

- phase and reviewer capability;
- exact Issue-body digest for Admission;
- plan comment ID and digest for Finalreview;
- full candidate revision and reviewed scope for Finalreview;
- verdict, findings, checks, and every required dimension score.

One reviewer satisfies one capability per gate. Finalreviews bind the same candidate revision. Acceptance requires no finding and 10.0 in every required dimension.

Accepted comments are append-only. Editing invalidates the evidence; corrections use a new comment. Review capabilities follow actual impact, and semantics-preserving Maintenance does not activate every specialist by default.

After acceptance:

1. add one concise `CHANGELOG.md` entry when release-relevant;
2. commit the coherent implementation and verification;
3. make the accepted revision available from the configured remote and complete required remote verification;
4. close the Issue and set Project status `Done`.

Git and the Issue retain history. No local change archive is created. Rejected work is closed as not planned.

## Verification

Repository verification remains deterministic and network-independent:

```sh
./utl/verify.sh governance
```

It checks the local execution and intake contracts, never live GitHub state.
