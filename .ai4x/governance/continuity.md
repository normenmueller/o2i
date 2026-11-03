# Scope

Load after bootstrap classifies applicability under `BEHAVIOR.md`. Owns return-point/authority reconstruction and Cold Start eligibility; bootstrap owns checkout/pointer/State validation, policy owns grants/guards, `decision-handoff.md` owns rendering.

# Sources And Reconstruction

Reconstruct from the selected checkout's tracked artifacts, observed Git, applicable Handoff and material current owning GitHub Issue/Project/PR/CI facts. GitHub alone owns operational continuity. Transcripts, `resume`, prior-session context, model recollection, cached remote facts, ignored files, local pointers and host snapshots supply neither authority nor continuity.

Apply `CONTEXT.md` ownership; current owners supersede stale references. Owner conflicts block dependent work. Status/commits/clean trees/branches/PRs/tests prove no completion, acceptance or authority.

| Applicability | Action |
| --- | --- |
| `applicable` | Validate fixed-path closed `o2i.handoff/v1`. Reconcile all Handoff fields against branch/revision/complete status and needed current remote facts. Identify/preserve dirty scope |
| `dormant` | Exclude Handoff; use tracked trunk/current owners. Proves only non-applicability, no acceptance/merge/completion/closure/Project/authority facts. Expected dormancy needs no refresh, mutation or history investigation |
| `UNVERIFIED` | Only independent repository-file work. Mark exact uncertainty; obtain owning evidence before dependent action. Infer no next action from Handoff |

# Durable Authority

Reconstruct surviving grants from canonical policy and the freshly fetched owning Issue. Require exactly one immutable receipt per grant ID; verify author identity, canonical bytes, approved payload/digest, unchanged Issue precondition, subject/actions/scope/target/exclusions and current lifecycle.

Missing/ambiguous/malformed/mismatched/stale/unverifiable receipts leave authority `UNVERIFIED`. Revoked/superseded/fulfilled/materially invalid grants authorize nothing. Handoff/transcripts/historical readbacks cannot replace current evidence. Current explicit runtime/PO instructions retain precedence; continuity references create no authority.

Standing completion requires accepted versioned `pullRequestCompletion` and fresh PR/review/Issue/check facts: exact head/source branch, effective PO approval, independent acceptance, integration-base coverage, then approved-head/integration-tree publication and post-merge checks. Cleanup requires full preflight. Changed/dismissed/withdrawn approval, change requests or failed/unknown gates deny. Review IDs only locate evidence; no transcript/receipt reconstruction or implementation-grant extension.

# Handoff Maintenance

Maintain Handoff on the applicable branch through completion, pending PO decision or explicit pause. Record one current Issue (`NONE` only for explicit Issue-free Routine work), objective, authority reference, risk, checks, next action and local return point. A completed grant authorizes no further work; record the pending decision.

- `ACTIVE`: design, implementation, investigation, correction, review or publication preparation.
- `PAUSED`: genuine wait with one reason and return condition.
- `COMPLETE`: recorded objective completed.

Respect policy budgets; reference durable owners. Exclude backlog history, copied policy, secrets/private data, session identifiers and authority payloads. Handoff creates no authority, workflow state, acceptance or evidence. Placement/lifetime: `operations/artifact-placement.md`.

# Cold-Start Eligibility

Require every shared gate:

- Selected branch HEAD published exactly; a fresh single-branch clone reproduces it with a clean tree.
- Tracked State/Handoff classify `applicable`; return point and surviving authority are durably materialized and freshly verified.
- No delegated/background work, required local-only/session state or missing restore proof.

Unknown/missing evidence denies. Dormancy needs no ordinary refresh but cannot establish Cold Start eligibility: State/Handoff must be applicable.

| Boundary | Additional gates |
| --- | --- |
| `completed-work-unit` | Handoff `COMPLETE`; authorized work, deterministic/remote checks, corrections and independent reviews complete; no unresolved material fact or PO decision |
| `active-product-owner-decision` | Handoff `ACTIVE`; one exact pending PO decision is next; immutable current owning-Issue record explicitly grants no authority; all required local edits committed/pushed; incomplete/unaccepted state explicit; no other unresolved material fact |
| `explicit-work-pause` | Handoff `PAUSED`; explicit PO pause, reason/return condition; durable next subject/Issue/unfinished state; required changes committed/pushed; explicit decisions/findings; successful preservation without inferred acceptance/completion; explicit authority/resume conditions |

For a pause, the owning Issue records pause/return point and authority disposition, including surviving grants or their absence. Verified absence of resume authority satisfies authority evidence; missing/unverifiable evidence denies. Resume requires current explicit PO instruction and fresh owning facts; surviving grants retain all validity guards. Pause/Cold Start create no implementation/publication authority.

Unfinished/rejected WIP, including product-check failures, may be preserved only with exact state, rejection/unaccepted status, decisions and findings reconstructible from the published branch/current Issue. Successful preservation proves recoverability only, never validity, acceptance or completion. All shared guards still apply.

Checkpoints create no acceptance/authority. Only after all gates pass and Cold Start is the sole recommendation, follow `decision-handoff.md`'s three fixed actions and policy records. Derive checkout root. Recovery permits, never requires deletion; session deletion removes descendants. Never recommend it early.

A greeting carries no state. Startup payloads only recover failed durable materialization before interruption; they never override owners or become routine continuity.
