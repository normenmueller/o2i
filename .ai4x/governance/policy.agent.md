# Generated Agent Governance Projection

> Generated from `.ai4x/governance/policy.json`; non-authoritative and never manually edited.

# Owners And Loads

- `bootstrap` → `.ai4x/BEHAVIOR.md`; load `always`; precedence, bounded startup, active-checkout pointer validation, handoff applicability, repository isolation, routing, and universal fail-closed safety.
- `applicability-envelope` → `.ai4x/STATE.md`; load `bootstrap`; one bounded closed header and no handoff body.
- `return-point` → `.ai4x/HANDOFF.md`; load `handoff-applicable`; branch-bound local return point.
- `repository-context` → `.ai4x/CONTEXT.md`; load `repository-context-required-after-checkout-selection`; stable identity, statement-class ownership, retrieval links, and durable product invariants.
- `capability-routing` → `.ai4x/TEAM.md`; load `collaboration-or-review-required`; capability routing and authorship-versus-review separation.
- `executable-governance` → `.ai4x/governance/policy.json`; load `deterministic-evaluation-before-authority-decision-or-mutation`; workflow transitions, actions, grants, mutation gates, events, provenance, rule registry, and budgets.
- `governance-practice` → `.ai4x/governance/guidelines.md`; load `risk-classification-issue-project-review-or-remote-work`; risk paths, Issue and Project ownership, reviews, and remote-work rules.
- `decision-rendering` → `.ai4x/governance/decision-handoff.md`; load `product-owner-decision-or-control-handoff`; event rendering and live approval binding.
- `session-continuity` → `.ai4x/governance/continuity.md`; load `applicable-handoff-reconstruction-or-cold-start-evaluation`; post-classification reconstruction and cold-start eligibility.
- `completed-work-cleanup` → `.ai4x/governance/cleanup.md`; load `explicit-completion-and-cleanup-grant`; cleanup preflight, destructive-action safeguards, deletion ordering, and postflight.
- `task-contracts` → `.ai4x/operations/*.md`; load `matching-task-class`; task-class-specific design, implementation, and quality rules.

Routes: `bootstrap` → `applicability-envelope`; `applicability-envelope` → `return-point`; `bootstrap` → `repository-context`; `bootstrap` → `capability-routing`; `bootstrap` → `governance-practice`; `governance-practice` → `executable-governance`; `governance-practice` → `decision-rendering`; `applicability-envelope` → `session-continuity`; `governance-practice` → `completed-work-cleanup`; `bootstrap` → `task-contracts`.

# Workflow And Authority

`Ready`: descriptive execution readiness only; the Issue contract is refined, prerequisites are clear, and no known blocker prevents the next action. Capacity: `unbounded`. Status creates authority: `false`.
- `workflow.backlog-to-refinement`: `Backlog` → `Refinement`.
- `workflow.refinement-to-ready`: `Refinement` → `Ready`.
- `workflow.ready-to-in-progress`: `Ready` → `In progress`.
- `workflow.in-progress-to-in-review`: `In progress` → `In review`.
- `workflow.in-progress-to-paused`: `In progress` → `Paused`.
- `workflow.paused-to-ready`: `Paused` → `Ready`.
- `workflow.in-review-to-done`: `In review` → `Done`.

Actions: `local.write`, `git.commit.create`, `project.transition`, `remote.issue-comment.create`, `remote.push`, `remote.pull-request.publish`, `remote.evidence.publish`, `issue.contract.mutate`, `issue.close`, `pull-request.merge`, `completed-work.cleanup`, `release.publish`, `tag.create`, `protected.publication`, `scope.expand`.

Every enumerated mutation requires all four gates: `current-matching-subject-grant`, `event-specific-guards`, `declared-and-verified-execution-identity`, `technical-host-or-tool-permission`. Missing or unknown evidence denies execution; permission never creates or revokes authority.
Grant schema `o2i.authority-grant/v1` remains active until `target-fulfilled`, `revoked`, `superseded`, `material-mismatch`. Consuming approval does not consume the grant. Its first authorized remote write is the immutable owning-Issue receipt; cross-session authority exists only when current remote state contains exactly one fully valid receipt.

# Decision Events

- `authority_request` creates a grant; required fields: `requestId`, `payloadFingerprint`, `subject`, `scope`, `targetState`, `requestedAuthority`, `exclusions`, `reason`, `alternatives`, `coldStart`.
- `product_owner_action` creates no grant; required fields: `eventId`, `subject`, `scope`, `targetState`, `requestedAgentAuthority`, `exclusions`, `reason`, `alternatives`, `coldStart`, `productOwnerAction`.
- `cold_start` creates no grant; required fields: `eventId`, `subject`, `scope`, `targetState`, `requestedAgentAuthority`, `exclusions`, `reason`, `alternatives`, `coldStart`.
Only `authority_request` accepts the exact adjacent reply `Freigegeben.`; it is single-use, current-fact-bound, observable, and non-replayable.

# Cold Start Continuity

`GitHub` alone. Boundaries: `completed-work-unit`, `active-product-owner-decision`. Load `session-continuity`; unknown denies; no local/session dependency; no checkpoint-derived acceptance or authority.

# Provenance And Forbidden Actions

Independent provenance facts: `product-owner-decision-authority`, `actual-content-authorship`, `git-commit-object-creator`, `verified-remote-publisher-identity`. Approval never implies authorship, committer, or publisher identity.
- `forbid-ready-as-authority`: when `Project-status-Ready-without-current-matching-grant`, forbid selector `all-actions`.
- `forbid-unlisted-transition`: when `workflow-transition-is-not-enumerated`, forbid `project.transition`.
- `forbid-grant-activation-issue-mutation`: when `activating-or-materializing-a-grant`, forbid `issue.contract.mutate`.
- `forbid-ordinary-execution-completion`: when `grant-target-ends-at-In-review`, forbid `pull-request.merge`, `issue.close`, `completed-work.cleanup`, `release.publish`, `tag.create`, `protected.publication`, `scope.expand`.
- `forbid-gate-substitution`: when `identity-or-permission-is-present-without-another-required-gate`, forbid selector `all-actions`.
- `forbid-scope-or-exclusion-mismatch`: when `action-expands-scope-target-or-crosses-an-exclusion`, forbid selector `current-action`.
- `forbid-unverified-remote-identity`: when `agent-remote-action-without-required-verified-machine-user`, forbid selector `remote-actions`.
