# Handoff

<!-- o2i-handoff-envelope-v1 -->
{"schema":"o2i.handoff/v1","workStatus":"ACTIVE","currentIssue":"#56","currentNode":"remote-ci-handoff-remediation"}
<!-- /o2i-handoff-envelope-v1 -->

# Objective

Complete #56 Batch 11 as one atomic CLI/package cutover over the accepted public Operation/Core design. No workaround, planted API, migration, compatibility, reparsing, or broader Core redesign.

# Authority

- Active grant `o2i-56-expanded-workunit-v5` supersedes v3. Its immutable receipt is Issue #105 comment `5540001623`; decision SHA-256 `ec15a607ffe5e50874f4325d15b951541e2a85eea0cde789c5178ff37723e9b1`; receipt SHA-256 `3d7393a41abbdd84c48763023483c0a3af25c1fcca8ad35653d632e6d4dbf46e`.
- The Product Owner approved `o2i-105-core-semantics-consumer-boundary-20260904-v5`; the durable grant remains active through its target.
- Authorized: bounded local implementation, verification, commit, branch push, Pull Request and CI publication, Issue #56/#105 evidence comments, and Project transitions through `In review`.
- Excluded: merge, Issue closure, Project `Done`, cleanup, release/tag, Issue-body mutation, batches 12/13, and broader Core redesign.

# Current Facts

- Branch `feat/56-cli-cutover` is attached. Product commit `0901e8d9182ef978fd20ad990aa4193c6fc0cf93` is published on the same remote branch.
- PR #107 is open, non-draft, mergeable, based on `trunk`, and points to that commit: `https://github.com/normenmueller/o2i/pull/107`.
- Issues #56 and #105 are open, assigned to `gertrud-ai4x`, and directly verified in Project `In review`.
- The accepted product subject is base `bc4969726e988151393a00d3f2dcf0f8497eab69` plus exactly 30 paths at canonical manifest SHA-256 `2784fcef73dec4e3999aefc91dd6797f8c06fa0f727e1e7a447c0136aefd634c`. `.ai4x/HANDOFF.md` is excluded from that manifest.
- Independent Haskell and Machine/CLI reviews returned `ACCEPTED`, each with zero blockers and advisories, on the unchanged manifest.
- Complete `spc/cabal.project.freeze` SHA-256 is `17a508f1c3e970ec63f493510a72e3bf4bf8ac3d1fff0d80ce698a832b52c165`.
- Run `33938213962`: Model, White Paper, and licensing are green; Haskell was last observed running. Governance failed only because Handoff exceeded 5,000 bytes, not because of the product candidate.

# Material Risk

- The accepted 30-path product subject is frozen. Handoff compaction must not alter it or invalidate either independent acceptance.
- Preserve the atomic public boundary: direct canonical Operation bytes; no CLI Core/Profile/Internal import, JSON reconstruction, universal bag, test hook, or representation opening.
- The Core read surface is natural, typed, total, opaque, and reusable. It changes no semantics, rules, identities, graph, schema, wire/order, capabilities, or package direction.
- Authors do not accept their own candidate. Automated green gates never override independent review findings.

# Verification

- Final local Haskell gate exited 0: contract groups 68/68, 50/50, and 55/55; Operation 198/198; CLI 61/61; external API 31/31; Candidate Views; all packages under `-Werror`; public Haddock 100%; isolated source distributions; target plan; atomic cutover; metadata; formatting; and diff.
- Final local licensing gate exited 0: licensing contract 10/10, REUSE 634/634, zero findings.
- Reviews confirmed four-role complement semantics, genuine wrong-role Trace runtime, the two-token payload domain, closed scalars, complete Human/Machine behavior, streams/exits, and Trace JSON.
- Remote branch and Pull Request head were directly verified at `0901e8d9182ef978fd20ad990aa4193c6fc0cf93`. The only observed remote failure is the Handoff size rule in run `33938213962`.

# Next Action

Keep the Handoff below 5,000 bytes, pass the local governance gate, commit only this primary-owned continuity correction, push it, and require the resulting Pull Request CI run to finish green. Then publish immutable completion evidence to Issues #56 and #105 and directly verify both remain `In review`. Do not merge, close, mark `Done`, clean up, release, or tag.

# Local Return Point

- Product return point: commit `0901e8d9182ef978fd20ad990aa4193c6fc0cf93`; accepted manifest `2784fcef73dec4e3999aefc91dd6797f8c06fa0f727e1e7a447c0136aefd634c`.
- The Handoff is primary-owned continuity state and excluded from the accepted candidate. A Handoff-only successor commit preserves both independent acceptances.
- Required sources are tracked repository state and owning GitHub facts; transcript and local snapshots are dispensable.
