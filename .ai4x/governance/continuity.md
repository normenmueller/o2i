# Scope

Load only after `BEHAVIOR.md` classifies handoff applicability. This contract owns return-point reconstruction, durable authority continuity and cold-start eligibility. Bootstrap owns checkout/pointer/State validation and applicability; policy owns grant schemas and guards; `decision-handoff.md` owns event rendering.

# Sources And Reconstruction

Use the selected checkout's tracked artifacts and observed Git facts, an applicable Handoff, and current owning GitHub Issue/Project/PR/CI facts when material. GitHub is the single operational continuity target. Transcripts, `resume`, prior-session context, model recollection, cached remote facts, ignored files, local pointers and host snapshots supply neither authority nor durable continuity.

Apply `CONTEXT.md` statement ownership. A stale dependent reference yields to its current owner; conflicts inside/between owners block dependent work. Status, commits, clean trees, branch names, PRs and tests alone prove no completion, acceptance or authority.

| Applicability | Action |
| --- | --- |
| `applicable` | Validate fixed-path Handoff against closed `o2i.handoff/v1`. Reconcile Issue, objective, work status, authority reference, risks, checks, next action and return point with branch, revision, complete status and needed current remote facts. Preserve and identify dirty scope |
| `dormant` | Exclude Handoff. Use tracked trunk/current owners. Dormancy proves only non-applicability; no acceptance, merge, completion, closure, Project or authority fact. Expected dormant content needs no refresh, mutation or history investigation |
| `UNVERIFIED` | Continue only repository-file work independent of the unresolved return point/authority. Mark the exact uncertainty; obtain owning evidence before dependent action. Never infer a next action from Handoff |

# Durable Authority

For authority surviving a session, load canonical policy and re-fetch the owning Issue. Require exactly one immutable receipt for the grant ID and verify required author identity, canonical bytes, approved payload/digest, unchanged Issue precondition, subject, actions, scope, target, exclusions and current lifecycle facts.

Zero/multiple, malformed, mismatched, stale or unverifiable receipts leave authority `UNVERIFIED`; revoked, superseded, fulfilled or materially invalid grants cannot authorize continuation. A handoff, transcript or historical readback cannot repair missing current evidence. Current explicit runtime/PO instructions retain bootstrap precedence; a continuity reference never manufactures authority.

# Handoff Maintenance

Maintain Handoff only for an active authorized work unit on its applicable branch. Record one current Issue (or `NONE` only for explicit Issue-free Routine work), objective, authority reference, material risk, checks, next action and local return point.

- `ACTIVE`: design, implementation, investigation, correction, review or publication preparation.
- `PAUSED`: genuine wait with one reason and return condition.
- `COMPLETE`: recorded objective completed.

Stay within policy budget. Reference durable owners; exclude backlog history, copied policy, secrets, private data, session identifiers and authority payloads. Handoff maintenance creates no authority, workflow state, acceptance or evidence. Audience and artifact lifetime belong to `operations/artifact-placement.md`.

# Cold-Start Eligibility

Require every shared gate:

- Selected branch HEAD published exactly; a fresh single-branch clone reproduces it with a clean tree.
- Tracked State/Handoff classify `applicable`; return point and surviving authority are durably materialized and freshly verified.
- No delegated/background work, required local-only/session state or missing restore proof.

Unknown or missing evidence denies eligibility. A dormant checkout needs no refresh for ordinary work, but cannot establish cold-start eligibility: policy requires applicable State/Handoff.

| Boundary | Additional gates |
| --- | --- |
| `completed-work-unit` | Handoff `COMPLETE`; authorized work, deterministic/remote checks, corrections and independent reviews complete; no unresolved material fact or PO decision |
| `active-product-owner-decision` | Handoff `ACTIVE`; one exact pending PO decision is next; immutable current owning-Issue record explicitly grants no authority; all required local edits committed/pushed; incomplete/unaccepted state explicit; no other unresolved material fact |

A checkpoint establishes neither acceptance nor authority. If all gates pass and cold start is the single recommendation, render only the canonical event in `decision-handoff.md` and its three fixed actions. Derive the checkout root; include no host path, payload, digest, snapshot locator or `resume`. The proof makes session and local copy dispensable without requiring deletion. Session deletion removes descendants too; never recommend it early.

A greeting carries no state. Payload-bearing startup is exceptional recovery only when durable materialization failed before interruption; it never overrides repository owners or becomes routine continuity.
