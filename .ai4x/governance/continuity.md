# Scope

This contract owns post-classification return-point reconstruction, durable authority continuity, and cold-start eligibility. Load it only after `.ai4x/BEHAVIOR.md` has classified handoff applicability. It owns no pointer validation, State parsing, branch comparison, applicability decision, decision-event rendering, workflow transition, or grant schema.

# Durable Sources

A fresh session reconstructs state only from the selected checkout's tracked repository artifacts, observed Git facts, an applicable `.ai4x/HANDOFF.md`, and current repository-native facts from the owning Issue and Project when material. Conversation transcripts, prior-session runtime context, model recollection, cached remote results, and a local active-checkout pointer are neither authority nor continuity sources.

GitHub Issues own change contracts, decisions, dependencies, review evidence, and open state. The Project owns workflow status and Product Owner ordering. The canonical governance policy owns grant structure and lifecycle. Git and deterministic checks own implementation and verification artifacts. The handoff is a concise local reference to these owners and never replaces them.

# Reconstruction

For an `applicable` result, validate `.ai4x/HANDOFF.md` against the `o2i.handoff/v1` closed schema before using any field. Reconcile its Issue, objective, work status, authority reference, risks, verification, next action, and local return point with the exact checkout branch, revision, complete status, and current owning remote facts needed for the next action. Preserve a dirty matching checkout and identify its scope; never discard or silently normalize it.

If active authority crosses the session boundary, load the canonical policy and reconstruct that grant only from its durable immutable Issue receipt and current lifecycle facts. Re-fetch the owning Issue, locate exactly one receipt for the grant ID, verify its required author identity, canonical bytes, approved payload and digest, unchanged Issue precondition, subject, actions, scope, target, exclusions, and current fulfillment, revocation, supersession, and material-match conditions. Zero, multiple, malformed, mismatched, stale, unverifiable, revoked, superseded, fulfilled, or materially invalid receipts leave authority `UNVERIFIED`. A handoff reference, transcript, or historical readback never repairs missing current evidence.

For a `dormant` result, do not open or use the handoff. Dormancy proves only non-applicability in the selected checkout; it proves no merge, completion, acceptance, Issue closure, Project state, or authority. Expected dormant tracked content is not a contradiction or repair target. Do not inspect branch or Pull Request history merely to explain it, mutate the State envelope or handoff, or require a refresh commit. Select the return point from tracked `trunk` and current owning remote facts when material.

For `UNVERIFIED`, repository-file work that does not depend on a return point may continue, but no authority or next action may be inferred from the handoff. Stop at the first action whose safety depends on the unresolved fact. Mark the exact uncertainty and obtain or ask the Product Owner for the missing owning evidence instead of synthesizing it.

When sources disagree, the current owning source prevails over stale dependent state. A conflict inside or between owners blocks dependent work until resolved in the relevant owner. Never infer completion, authority, or acceptance from workflow status, a commit, a clean tree, a branch name, a Pull Request, or tests alone.

# Handoff Maintenance

Maintain `.ai4x/HANDOFF.md` only on its applicable branch and only for an active authorized work unit. Use `ACTIVE` for design, implementation, investigation, correction, review, or publication preparation; `PAUSED` only for a genuine wait with one reason and return condition; and `COMPLETE` only when its recorded objective is complete. Record one current Issue or `NONE`, objective, authority reference, material risk, verification state, next action, and local return point. `NONE` is valid only for an explicit Issue-free Routine request.

Keep the handoff below its policy budget, repository-autark, and free of backlog history, duplicated normative policy, secrets, private data, session identifiers, or authority payloads. Reference durable owners rather than copying them. Updating a handoff records continuity but never creates authority, workflow state, acceptance, or evidence.

# Cold-Start Eligibility

A routine cold start is eligible only when the current return point and every surviving authority are durably materialized and freshly verified; the authorized work unit, required deterministic and remote verification, required corrections, and all independent reviews are complete; no delegated or background work remains; no unresolved material fact or Product Owner decision remains; and transcript retention is not required. A proven dormant handoff is neutral to these gates and needs no refresh.

When eligible and when cold start is the single recommendation, render only the canonical `cold_start` event from `.ai4x/governance/decision-handoff.md`. Its three fixed actions are the sole transition instructions. Derive the repository root from the selected checkout; do not include an absolute host path, payload, digest, snapshot locator, or `resume`. Session deletion permanently removes the current session and descendants, so never recommend it before every gate passes.

An ordinary greeting carries no state. A long transport snapshot or payload-bearing startup prompt is exceptional recovery only when the return point could not be durably materialized before interruption; it is never routine continuity and never overrides a repository-owned source.
