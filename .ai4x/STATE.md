# Handoff

- Observed: 2026-08-27 CEST
- Work status: `ACTIVE`
- Current Issue: `#89`
- Current node: `publication-and-closure`

# Objective

Make cleanup of no-longer-needed Issue-owned branches, worktrees, stashes, active-checkout pointers, and scratch artifacts a durable post-completion duty with strict destructive-action safeguards.

# Authority

- The Product Owner explicitly requested that the cleanup rule be recorded stringently in `.ai4x`, not merely stated in conversation.
- Authorized scope is the canonical operating/governance contracts, deterministic governance tests, and only required concise human-facing synchronization.
- Completion and protected publication of this governance change are explicitly requested; all work remains isolated from #53.
- The normal explicit release of a `Ready` Issue remains bounded through `In review` and alone authorizes no cleanup.

# Material Risk

- Cleanup must require completed, published and remotely verified work, closed Issue, Project `Done`, explicit completion-and-cleanup authority, and proof that no unique work remains only on a target.
- Default/protected, active, review, unmerged, recovery, foreign, user-owned, or otherwise unique data must never be deleted.
- Every destructive target must be resolved explicitly before action; remote deletion requires verified machine identity; local and remote inventories must be verified afterward.
- Protected repository governance requires active external Co-Authoring, deterministic evidence, and independent read-only acceptance.

# Participants

- Primary Gertrud: authority framing, Issue/Project administration, integration, remote identity, verification, publication, and exact cleanup.
- External Repository Governance, Agentic Workflow, Destructive-Action Safety, and Human Usability Co-Author: target design and implementation; no independent acceptance.
- Independent Repository Governance, Agentic Workflow, Destructive-Action Safety, and Human Usability reviewer: read-only acceptance of the exact Co-Authored candidate; no authorship or mutation.

# Verification

- Basis: clean published `trunk` at `258d47dc6593c250dc160e06e97227aa1109bc93`.
- Issue #89 is Project `In progress` in isolated branch `chore/89-clean-completed-work`.
- Corrected exact scoped candidate digest: `594e440582d0351b9b80bb0245880977a20d4c0151ed2be264e676ae695acb60`.
- Governance 33/33, verification routing 18/18, licensing 10/10, REUSE 518/518, package-license, focused cleanup, and diff checks pass.
- The first independent review returned three blockers and zero advisory findings; all three are corrected in the new digest.
- Independent re-review reproduced the digest and checks, found zero blocking and zero advisory findings, preserved role separation, and returned `accepted`.

# Next Action

Publish the accepted candidate through green remote verification, merge, close, set `Done`, and apply the rule to #89 itself.

# Local Return Point

- Branch: `chore/89-clean-completed-work`.
- Worktree: repository-relative `.ai4x/local/worktrees/89-clean-completed-work` from the stable checkout.
- Dirty scope: `.ai4x/STATE.md` plus Co-Author-owned governance candidate paths.
