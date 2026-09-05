# O2I Governance Guidelines

O2I governance protects product quality and clear authority with the least process justified by actual risk. It defines no fachliche O2I semantics. Executable workflow, grant, gate, event, provenance, owner-route, and budget rules belong only to `policy.json`; agents use its generated `policy.agent.md` route.

## Operating Principles

- Prefer working software, executable evidence, and clear ownership over ceremony.
- Apply more process only when impact, irreversibility, or blast radius justifies it.
- Preserve accepted evidence for its exact revision and scope without claiming permanent defect-freedom.
- Record each fact once in its owning system.
- Never weaken deterministic verification, type safety, repository autonomy, documentation quality, security, or publication checks to save effort.

## Repository Authority

- A GitHub Issue owns its problem, target, scope, acceptance criteria, dependencies, material decisions, review evidence, and open or closed state.
- An explicit Product Owner request may own bounded Issue-free Routine work; it creates no Project item, dependency, or durable product contract and still requires the current structured grant before mutation.
- Native Issue Dependencies own genuine prerequisite relations. Project order never creates a dependency.
- GitHub Project `O2I` owns workflow status and Product Owner ordering only. It owns no product contract, acceptance fact, or authority grant.
- Git commits own implementation artifacts; deterministic checks own verification evidence.
- `.ai4x/HANDOFF.md` is a local return point, never an authority source. `CONTRIBUTING.md` is a generated human projection.

## Risk-Proportionate Paths

Classify the actual change by impact, reversibility, and blast radius. Labels aid discovery but never determine process.

### Routine

Routine work is reversible, local, and semantics-preserving: focused fixes, refactoring without public-contract change, tests, documentation corrections, CI, tooling, and repository administration.

Minimum path: one understandable Issue or explicit bounded Product Owner request, one focused candidate, relevant deterministic checks, and author self-review. Add independent review only when tests and inspection cannot credibly close a material risk.

### Significant

Significant work affects a public contract, crosses capability ownership, performs a migration, or has material user or repository blast radius without changing protected fachliche meaning.

Minimum path: one Issue containing the decision and material alternatives, an exact execution grant, relevant deterministic verification, and at least one independent reviewer matched to the primary risk. Add reviewers only for distinct material risks.

### Protected

Protected work changes fachliche terminology or metamodel semantics, normative syntax, irreversible compatibility, release or publication authority, security-sensitive behavior, or repository governance authority.

Minimum path: explicit Product Owner decision, an Issue stating problem, benefit, target, scope, non-goals, risks, and observable acceptance, risk-selected independent specialist review, complete applicable verification, and an exact grant for every protected mutation or publication. Existing authority is not requested again for actions already inside its active target.

Require a digest or immutable manifest only for externally supplied authority, a release artifact, security-sensitive evidence, or another stated integrity need. File count and uncertainty alone do not escalate process. If classification remains ambiguous after inspection, choose the next safer path.

## Workflow Practice

The canonical policy owns states and transitions. `Ready` describes a refined, unblocked Issue and never authorizes work. The Board reflects work; it does not manufacture authority. Any Project mutation therefore requires the same current subject grant, transition guard, identity, and technical permission as every other mutation.

An active grant is one atomic work-unit authority through its target, not a sequence of action-level approvals. It remains effective across covered design, collaboration, implementation, verification, review corrections, commit, and publication actions explicitly listed in it. New authority is required only for expanded scope or target, an exclusion, a material mismatch, or an action absent from the grant. Host or tool permission is an independent technical gate: denial blocks execution but neither creates nor revokes Product Owner authority.

Use `Refinement` only while a material product or design decision needs preparation. `In progress` covers active design, implementation, investigation, reproduction, and correction. `In review` means a complete candidate is undergoing required checks or awaiting bounded publication. `Paused` is only a genuine wait with one reason and return condition. `Done` requires accepted, published when required, closed, and green evidence. Cleanup is separately governed by `cleanup.md`.

`10/10` is Product Owner shorthand for every required verdict being `accepted`, zero blocking or advisory findings, all exact-candidate local and remote checks green, and intact authorship-versus-review separation. It is never a review score.

## Stories And Integration Findings

Use native Sub-Issues only when they improve visibility of a multi-part deliverable. The parent owns integrated scope, authority, acceptance, and publication; a Story owns only its bounded deliverable and adds no scope or authority.

A later concern is an acceptance challenge, not retroactive invalidation. Reproduce it against the accepted revision and authority, classify it as predecessor defect, current-work responsibility, contract ambiguity, or non-finding, and preserve unchanged historical evidence. A confirmed predecessor defect normally receives a linked correction Issue. A challenge blocks only the dependent unsafe action and never authorizes workaround, compatibility, weakened verification, or semantic expansion.

## Review And Collaboration

Load `TEAM.md` when collaboration or review is required. Every review identifies its exact subject and scope, reviewer capability, checks, findings, and one verdict: `accepted`, `accepted with follow-ups`, or `changes required`. Numerical scores are prohibited. Acceptance requires no blocking finding. Each blocking finding states one target-state remedy; advisory work is separately identified. An author, Co-Author, or implementer never independently accepts their own candidate. Later changes require review only for their changed risk surface.

## Remote Facts And Publication

Delegated agents and independent reviewers never query or mutate remote Issue, Project, review, or CI state. They request each material fact from the primary agent, which returns the unmodified result or reports it unavailable. They never start approval-requiring commands; the primary agent runs any authorized command in the main thread. When GitHub is unavailable, continue only an already active local scope and infer no remote fact.

Prefer the connected GitHub application for covered reads and use `gh` only when required capability is absent. Stage drafts for remote writes only under ignored `.ai4x/local/drafts/`. Agent remote writes require the verified `gertrud-ai4x` identity and stop when it is unavailable. Never impersonate an unavailable identity. Before publication, report outgoing commits, scope, verification, review verdict, and follow-ups; change no reviewed file after acceptance.

## Verification

Verification is deterministic and network-independent. Before commit, run every stage selected by the canonical path matrix; unknown or shared scope selects the complete suite. Before a release tag, run `./utl/verify.sh`. Direct branch pushes do not trigger GitHub Actions. Required remote verification applies to Pull Requests, manual dispatches, and matching release tags. Never use `[skip ci]` as routine workflow.
