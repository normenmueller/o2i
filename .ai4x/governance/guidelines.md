# Scope And Owners

Load for risk classification, Issues, Project administration, review, remote work or publication. Governance defines no fachliche semantics. `policy.json` owns executable governance; `policy.agent.md` is its generated projection. Apply `BEHAVIOR.md` precedence: current explicit PO/runtime authority outranks ceremonies and differs from durable grants. Do not request existing same-subject/scope authority again; technical permission, verified identity and material safeguards remain required.

| Fact | Owner |
| --- | --- |
| Problem, target, scope, acceptance, dependencies, decisions, review evidence, open/closed state | Owning GitHub Issue |
| Bounded Issue-free Routine work | Explicit Product Owner request; creates no durable product contract or Project item |
| Prerequisite relation | Native Issue Dependency; order alone creates none |
| Workflow status and Product Owner ordering | GitHub Project O2I |
| Implementation and verification evidence | Git commits and deterministic checks |
| Local return-point references | Applicable `.ai4x/HANDOFF.md`; never authority |
| Human contribution guidance | Generated `CONTRIBUTING.md` projection |

Record facts once at their owner. Prefer working software, executable evidence and ownership over ceremony. Exact-revision acceptance proves no permanent defect-freedom. Never weaken verification, types, autonomy, documentation, security or publication checks to save effort.

# Risk Path

Classify by actual impact, reversibility and blast radius, not labels or file count. If inspection leaves ambiguity, use the next safer path.

| Class | Trigger | Minimum path |
| --- | --- | --- |
| Routine | Reversible local, semantics-preserving fixes, refactoring, tests, docs, CI, tooling or administration | Understandable Issue or explicit bounded PO request; focused candidate; relevant checks; author self-review. Independent review when inspection and tests cannot close material risk |
| Significant | Public contract, cross-capability ownership, migration or material user/repository impact without protected meaning change | Issue with decision and material alternatives; exact execution authority; relevant checks; independent reviewer matched to primary risk |
| Protected | Fachliche terminology/metamodel, normative syntax, irreversible compatibility, release/publication authority, security-sensitive behavior or governance authority | Explicit PO decision; Issue with problem, benefit, target, scope, non-goals, risks and observable acceptance; independent risk-matched specialist review; complete applicable verification; exact authority for each protected mutation/publication |

Add reviewers only for distinct material risks. Require a digest/immutable manifest for external authority, release artifacts, security-sensitive evidence or another stated integrity need. Apply the global design standard; classification does not authorize a migration or workaround.

# Workflow And Authority

Policy owns transitions/authority; `Ready` grants none. Grants retain scope/target after approval consumption. Under `pullRequestCompletion`, current exact-head PO GitHub `APPROVED` authorizes normal merge, owning-Issue closure/Done, completion evidence and exact safe cleanup without reapproval. Other reviews grant none. Reviews/checks must cover the integration base; closure needs approved-head/integration-tree publication. Changed/withdrawn approval, change requests, failed/unknown checks or unsafe cleanup block dependent actions. Scope, exclusions, identity and permission remain binding.

Condition merge on the approved head (`sha`/`--match-head-commit`). Inspect merge-side closures: only the owning Issue may auto-close under merge authority. Distinguish this from explicit follow-up closure/Done/cleanup after post-merge proof.

Align Project status at workflow/PO handoffs using authorized transitions, PO ordering and remote readback. If blocked, report actual/UNVERIFIED state, intended correction and missing authority/access.

| Status | Observable meaning |
| --- | --- |
| Refinement | Material product/design decision is being prepared |
| In progress | Active design, implementation, investigation or correction |
| In review | Complete candidate undergoing required checks or awaiting bounded publication |
| Paused | Genuine wait with one reason and return condition |
| Done | Accepted, published when required, closed and green |

`10/10` means all required verdicts `accepted`, zero blocking/advisory findings, all exact-candidate local/remote checks green, and intact author/reviewer separation. Never report a numerical review score. Completed-work cleanup has its own contract and authority.

Include exact local/remote topic-branch cleanup in completed-work closure. Follow matching authority and `cleanup.md`; if excluded or blocked, present the remaining step explicitly. Preserve unrelated branches, worktrees and unique data.

# Sub-Issues And Later Findings

Use native Sub-Issues when they clarify a multi-part deliverable. The parent owns integrated scope, authority, acceptance and publication; a child owns only its bounded deliverable and adds no authority.

Reproduce later concerns against the accepted revision and authority. Classify as predecessor defect, current-work responsibility, contract ambiguity or non-finding; preserve unchanged historical evidence. A confirmed predecessor defect normally gets a linked correction Issue. Block only the dependent unsafe action; the finding authorizes no workaround, weakened check or semantic expansion.

# Review

Load `TEAM.md` for capability assignment, collaboration timing and independence. Each review names exact subject/scope, reviewer capability, checks, findings and verdict: `accepted`, `accepted with follow-ups` or `changes required`. Acceptance requires no blocker. Each blocker states a target-state remedy; separate advisory work. Later edits require review of their changed risk surface.

# Remote Work

Open PRs with a brief PO-facing summary of achieved results and practical benefits; technical evidence follows. Handle Routine communication edits directly and proportionately.

Assign new Issues to both `normenmueller` and `gertrud-ai4x`; verify remotely.

Delegates and reviewers never query/mutate remote work state or start approval-requiring commands. The primary supplies exact material remote facts or reports them unavailable. When GitHub is unavailable, continue only an already active local scope and infer no remote fact.

Prefer connected GitHub for supported reads; use `gh` for missing capabilities. Stage unpublished remote drafts under ignored `.ai4x/work/local/drafts/`; the published artifact belongs remotely. Every agent write requires verified `gertrud-ai4x`; never substitute another identity. Before publication report outgoing commits, scope, checks, verdict and follow-ups. Preserve the accepted files unchanged.

For `gh`, select the dedicated `GH_CONFIG_DIR="$HOME/.config/gh-gertrud"` and verify `gh api user` returns `gertrud-ai4x`. Diagnose token scopes and Project collaborator access separately; never expand or substitute the personal account's permissions.

For Git writes, verify the actual transport credentials and one effective push destination separately from the API identity. A verified `gh` account does not verify SSH. Use an explicit repository URL with command-scoped verified credentials; check URL rewrites first. Do not treat `git -c remote.<name>.url=...` as replacement: remote URLs are multivalued. Read back publication evidence and record the actual Git publisher separately from authorship; never rewrite historical provenance to match intent.

# Verification And Backup

Load `operations/local-verification.md` for local execution and recovery. Use `./utl/verification/local.sh checkpoint` for regular scoped backup commits; verify remote HEAD and report unbacked changes before claiming recoverability. Pure illustration checkpoints select licensing/model checks; required per-save CLI checks and unfinished-model findings remain. A backup is no merge acceptance.

Make small, coherent, internally consistent, independently understandable commits after applicable local checks, before starting another independent unit. Separate unrelated work; keep coupled changes together. Time pushes by unpublished value and recovery risk: back up meaningful progress promptly and before risky operations, handoff or session end, within authority. Report unpublished commits or blocked checks. Local commits are not remote backups; commits and pushes establish no acceptance. Preserve required reviews and PR/manual/release checks; dispatch remote checks for backup commits only when verification requires them.

`utl/verify.sh` owns deterministic, network-independent checks and the regular path matrix. Unknown/shared integration scope selects the complete suite. Before a release tag run `./utl/verification/local.sh all` explicitly; the starter defaults to checkpoint. Checkpoint selection never changes PR/manual/release verification. Backup branch pushes without an open PR do not trigger the Verify workflow; updates to an open PR do. Do not routinely use `[skip ci]`.
