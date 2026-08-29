# Completed-Work Cleanup

This contract owns completion-and-cleanup preflight, destructive-action safeguards, deletion order, and postflight. `policy.json` owns the `completed-work.cleanup` action and its mutation gates. Ordinary execution authority ending at `In review` never authorizes merge, Issue closure, Project `Done`, or cleanup.

## Authority And Entry Conditions

Cleanup requires one current subject grant that explicitly includes completion and `completed-work.cleanup`. Its cleanup portion becomes executable only after the exact Issue is accepted, published when publication is required, green at the required remote verification boundary, closed, and in Project status `Done`. Missing or unknown evidence denies cleanup. Cleanup is then a required part of the authorized completion, not an optional chat convention.

The grant remains bounded by its subject, resources, scope, target, and exclusions. Host permission and verified execution identity are independent gates and never substitute for authority. Remote mutation stops when the required machine identity is unavailable or unverifiable.

## Read-Only Preflight

Before deleting anything, perform one read-only preflight that:

1. verifies the exact Issue, accepted and published result, required green remote checks, closed state, Project `Done`, and the active completion-and-cleanup grant;
2. enumerates every exact candidate by stable identity and expected ref where applicable: named local branch and full ref, named remote branch and ref, repository-relative linked-worktree path and registered identity, named stash and object ID, exact `.ai4x/local/ACTIVE.md` pointer, and exact Issue-owned scratch path;
3. proves each candidate's unique work durable on the owning published branch or intentionally obsolete under the same grant; and
4. records the permitted native deletion operation, conditions, expected identity, and required ordering for each candidate.

Stop before mutation when any fact is missing, ownership is ambiguous, unique work is not durable, the grant does not name the resource, or a candidate cannot be resolved without a broad target, variable, substitution, wildcard, or recursive filesystem operation.

## Mandatory Exclusions

Never delete:

- a default or protected branch;
- an active, review, unmerged, or recovery branch;
- an active worktree or applicable handoff;
- a stash or scratch artifact containing unique or user-owned data;
- anything outside the completed Issue's exact scope;
- a repository root, home directory, absolute foreign path, unresolved variable, glob, or recursive target; or
- any object whose current stable identity differs from preflight.

An exclusion or identity mismatch cannot be waived by technical permission, Project status, or apparent obsolescence.

## Per-Target Revalidation And Order

Immediately before each individual deletion, re-resolve the exact target and compare its stable identity and expected ref with preflight. Any mismatch stops cleanup before that mutation and leaves remaining targets untouched.

Use scoped native Git operations for worktrees and branches; never replace them with direct recursive filesystem deletion. Clear a stale active-checkout pointer before removing the exact worktree it names. Remove a linked worktree before its local branch. Delete a remote branch only through the verified machine identity and a lease or equivalent conditional operation bound to the preflight ref. Delete only the exact named stash object and exact Issue-owned scratch paths.

Failure after a completed individual deletion does not authorize rollback, substitution, or a broader target. Preserve the evidence, stop safely, and re-preflight remaining candidates against current facts.

## Postflight

After all authorized deletions, re-inventory local and remote branches, linked worktrees, stashes, the active-checkout pointer, and Issue-owned scratch paths. Prove every authorized target absent and every protected or unrelated target preserved. Correct stale Project or active-checkout state only when the same grant explicitly covers that mutation; otherwise report it without inference or change.

Record the preflight subject and grant, every stable target identity, each revalidation and result, conditional remote-deletion evidence, exclusions applied, failures, and the final inventory. Never store secrets, credentials, host-absolute paths, or session identifiers in repository memory.
