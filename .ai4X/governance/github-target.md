# GitHub-native Governance Target

Status: `ACCEPTED`

This document records the accepted migration target. It is not a second
runtime authority. The active agent contract is
`.ai4X/governance/README.md` from the explicitly named cutover commit onward.
Before that commit reaches `trunk`, the legacy register remains authoritative.

The cutover candidate is admissible only after:

- all migrated Issues, comments, identities, participants, lineage,
  dependencies, states, and review records reconcile with their sources;
- repository, Issue, dependency, Project, and API-export capabilities pass;
- every non-transfer decision has explicit PO approval;
- all prospective contracts pass deterministic local verification;
- every legacy authority statement is replaced in the same commit.

Issue `#2` records that commit by its full SHA. No partial or mixed authority
is valid.

## Authority

- A GitHub Issue owns problem, generic benefit, target, scope/non-goals,
  acceptance, lineage, dependencies, admission, and exact-revision reviews.
- The user-level GitHub Project `O2I` is the PO scheduling view over O2I Issues.
  It never owns admission, dependencies, review evidence, or closure.
- Project `Done` follows Issue closure.
- `.ai4X/STATE.md` holds only the active Issue ID, authorized scope, current
  candidate/gate, dirty scope, checks, next action, and local return point.
- Git commits and CI own implementation and verification artifacts.
- `CONTRIBUTING.md` owns the concise human-facing workflow shared with agents.

No backlog, Project state, or chronological history is copied into `.ai4X`.

## Issue Contract

A Framework-change Issue body contains:

- path and legacy ID when migrated;
- author and coauthors;
- non-blocking lineage;
- required Admission and Finalreview capabilities;
- the complete proposal: problem, generic benefit, fit, target, scope,
  non-goals, acceptance criteria, alternatives, and risks.

Native Issue Dependencies own blocking relations and are not duplicated in the
body. They are established before Admission and remain fixed for the admitted
scope. From the first Admission review onward, the body is contractually
frozen. Admission binds the SHA-256 of its exact UTF-8, LF-normalized bytes.
Editing the body invalidates Admission and returns the Issue to `Backlog`.

The admitted implementation contract is a separate, contractually frozen Issue
comment created after Admission. Finalreview binds its stable comment ID,
SHA-256, the exact candidate revision, and reviewed scope. A changed plan is a
new comment and requires renewed impact classification.

## Activation

An agent may implement an Issue only when:

- the Issue is open;
- Project status is `Ready` or `In progress`;
- Admission required by the Issue path is accepted;
- `.ai4X/STATE.md` identifies the Issue and authorized scope;
- no unresolved dependency prevents the next action.

`Paused` requires an explicit PO suspension decision, reason, and return
condition. External blocking is orthogonal and uses `blocked:external`.

When GitHub is unavailable, agents may continue only an already activated local
handoff. They do not infer, create, transition, or close remote work.

## Review Evidence

One accepted review comment records:

```text
change:
phase:
capability:
reviewer:
proposal_body_sha256:   # Admission
plan_comment_id:        # Finalreview
plan_sha256:            # Finalreview
reviewed_revision:      # Finalreview
reviewed_scope:
verdict:
findings:
checks:
scores:
source_path:            # Migrated evidence only
source_sha256:          # Migrated evidence only
```

Admission binds the exact Issue body digest or migrated proposal digest.
Finalreview binds one full Git commit SHA, plan comment, and declared scope.
Required capabilities are impact-based. One reviewer satisfies one capability
per gate. Acceptance requires no finding and 10.0 in every required dimension.

Accepted comments are contractually append-only. Editing invalidates the
evidence; correction uses a new comment. Reconciliation records stable comment
IDs and verifies current API-exported comment digests.

## Issue Paths

- `framework-change`: normative semantics, syntax, formalization, validation,
  or public API.
- `maintenance`: semantics-preserving tooling, presentation, tests, CI, or
  repository administration.

Framework-change Issues require strategy and formalization Admission. Their
Finalreview capabilities follow demonstrated impact. Maintenance uses only the
capabilities needed by its risk.

## Verification

Repository verification remains deterministic and network-independent. It
checks local contracts and implementation artifacts, never live GitHub state.
Remote issue and Project reconciliation is an explicit migration or release
operation, not part of `./utl/verify.sh`.
