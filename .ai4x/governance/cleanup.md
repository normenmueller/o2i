# Cleanup

This contract owns completed-work and superseded-continuity-source cleanup, destructive-action safeguards, deletion order, and postflight. `policy.json` owns the `completed-work.cleanup` action and its mutation gates. Ordinary execution authority ending at `In review` never authorizes merge, Issue closure, Project `Done`, or cleanup.

## Authority And Entry Conditions

Cleanup requires one current subject grant that explicitly includes the exact target and `completed-work.cleanup`. Missing or unknown evidence denies cleanup.

`completed-work` cleanup becomes executable only after the exact Issue is accepted, published when publication is required, green at the required remote verification boundary, closed, and in Project status `Done`.

`superseded-continuity-source` cleanup becomes executable only after the replacement is independently accepted, published, and green; a fresh restore proves the replacement sufficient without the old source; every unique object is either durable in the replacement or explicitly obsolete under the same grant; the exact source identity is unchanged; and the operation is recoverable. Issue closure and Project `Done` are not entry conditions because retirement is itself the final acceptance action. This mode may only retire a source; it cannot delete an active checkout, authority owner, or required recovery object.

The grant remains bounded by its subject, resources, scope, target, and exclusions. Host permission and verified execution identity are independent gates and never substitute for authority. Remote mutation stops when the required machine identity is unavailable or unverifiable.

## Read-Only Preflight

Before deleting anything, perform one read-only preflight that:

1. verifies the selected cleanup mode, exact Issue, accepted and published result, required green remote checks, active cleanup grant, and either the completed-work closure gates or the superseded-source replacement, restore, unique-data, and recoverability gates;
2. enumerates every exact candidate by stable identity and expected ref where applicable: named local branch and full ref, named remote branch and ref, repository-relative linked-worktree path and registered identity, named stash and object ID, exact `.ai4x/local/ACTIVE.md` pointer, exact Issue-owned scratch path, or exact grant-bound superseded continuity source;
3. proves each candidate's unique work durable on the owning published branch or intentionally obsolete under the same grant; and
4. records the permitted native deletion operation, conditions, expected identity, and required ordering for each candidate.

Stop before mutation when any fact is missing, ownership is ambiguous, unique work is not durable, the grant does not name the resource, or a candidate cannot be resolved without a broad target, variable, substitution, wildcard, or recursive filesystem operation.

## Mandatory Exclusions

Never delete:

- a default or protected branch;
- an active, review, unmerged, or recovery branch;
- an active worktree or applicable handoff;
- a stash or scratch artifact containing unique or user-owned data;
- anything outside the cleanup grant's exact subject and scope;
- a repository root, home directory, unresolved variable, glob, recursive target, or absolute foreign path other than the one exact superseded continuity source named by its dedicated grant; or
- any object whose current stable identity differs from preflight.

An exclusion or identity mismatch cannot be waived by technical permission, Project status, or apparent obsolescence.

## Per-Target Revalidation And Order

Immediately before each individual deletion, re-resolve the exact target and compare its stable identity and expected ref with preflight. Any mismatch stops cleanup before that mutation and leaves remaining targets untouched.

Use scoped native Git operations for worktrees and branches; never replace them with direct recursive filesystem deletion. Clear a stale active-checkout pointer before removing the exact worktree it names. Remove a linked worktree before its local branch. Delete a remote branch only through the verified machine identity and a lease or equivalent conditional operation bound to the preflight ref. Delete only the exact named stash object and exact Issue-owned scratch paths. Retire an external continuity source only by moving that exact stable target to a previously absent explicit Trash destination; never empty Trash in the same work unit.

Failure after a completed individual deletion does not authorize rollback, substitution, or a broader target. Preserve the evidence, stop safely, and re-preflight remaining candidates against current facts.

## Postflight

After all authorized deletions, re-inventory local and remote branches, linked worktrees, stashes, the active-checkout pointer, Issue-owned scratch paths, and any superseded continuity source and Trash destination. Prove every authorized target absent or recoverably relocated and every protected or unrelated target preserved. Correct stale Project or active-checkout state only when the same grant explicitly covers that mutation; otherwise report it without inference or change.

Record the preflight subject and grant, every stable target identity, each revalidation and result, conditional remote-deletion evidence, exclusions applied, failures, and the final inventory. Never store secrets, credentials, host-absolute paths, or session identifiers in repository memory.
