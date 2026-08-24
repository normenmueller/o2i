# Handoff

- Observed: 2026-08-24 CEST
- Work status: `ACTIVE`
- Current Issue: `#46`
- Current node: `pr-69-remediated-candidate-review`

# Objective

Complete one coherent PR #69 candidate that combines the accepted #46 Foundation CI correction, the #70 current-authority model verifier, the #71 White Paper synchronization, the Product Owner-authored #72/#74 focused model corrections, and the #76 exact Profile binding plus native Archi Junction decode correction without changing Core, Profile contract, or fachliche semantics.

# Authority

- Issue #46 owns the Foundation toolchain and pull-request workflow correction; Issue #70 owns the verifier correction; Issue #71 owns publication synchronization; Issues #72 and #74 own the separate model corrections exposed by the verifier; Issue #76 owns the exact model-root Profile binding and native AMX Junction-operator decode correction exposed by the integrated Haskell gate.
- The Product Owner authorized implementation, independent review, push, and PR publication through `In review`; the Product Owner performed every Archi edit under guided instructions.
- PR #69 is the existing publication line for this integrated predecessor correction. Merge remains a separate Product Owner decision.

# Material Risk

- Pull requests intentionally run the frozen Foundation Haskell closure. Manual dispatches and release tags intentionally run the complete Haskell closure and remain fail-closed until the later atomic package cutover.
- The complete package set cannot currently resolve under one compiler: Foundation packages require `base >=4.20 && <4.21`, while the legacy CLI still requires `base >=4.18 && <4.19`; no complete-project freeze exists yet. This is a known deferred package-graph boundary, not a reason to weaken or misreport the PR gate.
- The #70/#71 integration touched shared verification routing and `utl/verify.sh`; the resolved target retains #46's Foundation workflow, #70's current focused verifier and complete model-test discovery, and #71's removal of the obsolete generated Profile-renderer path.
- The first integrated review correctly required the PR-scope Foundation gate to execute the real repository model through AMX, Profile, and Core. Its implementation exposed the legacy model-root Profile shorthand and a false Junction rejection. The Product Owner bound the exact Profile in Archi and confirmed that the carrier was already an AND Junction; #76 therefore corrects the native AMX operator mapping rather than changing the model carrier, Core, or Profile semantics.
- Accepted issue-local revisions remain evidence for their exact subjects. The integrated resolution requires its own independent exact-revision review and green remote PR jobs.

# Verification

- #70/#72/#74 revision `4076297b3029c0db765c5c05c6d90e4b2b3cf559` is independently `accepted` with no blocking finding or advisory follow-up.
- #71 product/Authority revision `14c434e2082a7fad973111559799ab1d56e6a0de` is independently `accepted` with no blocking finding or advisory follow-up.
- Integrated product candidate through `0318b628f190353e980212b3b5ebff55b23aa184` carries all durable #46, #70, #71, #72, #74, and #76 changes plus every remediation of the first integrated review; branch-local historical Return Point commits were deliberately not copied.
- Passed locally on the integrated tree: licensing/REUSE 465/465, Governance 21 plus 18 tests, model hygiene and all 70 model tests, the complete Foundation Haskell gate including 49 Profile tests, 71 AMX tests, real-model AMX/Profile/Core execution, 100% Haddock, independently built source distributions and formatting, the complete Paper gate using canonical `md2pdf`, `git diff --check`, and the workspace O2I boundary.
- The complete Haskell gate was also reproduced: all 150 pre-build contract tests pass and Cabal then stops exactly at the known `o2i-cli` `base <4.19` versus installed `base-4.20.2.0` conflict. This gate is not represented as passed and is not the PR-scope Haskell command.
- Independent review of the integrated current clean `HEAD` and remote CI for all five PR jobs remain pending.

# Next Action

Commit this Authority Memory update, then obtain independent exact-revision reviews of the resulting clean `HEAD`. After intrinsic acceptance, push the branch to PR #69, update the PR body and Issue evidence without claiming the complete Haskell gate is green, and require all five remote pull-request jobs to pass: licensing, governance, model, Foundation-scoped Haskell, and White Paper.

# Local Return Point

- Branch: `fix/46-toolchain-workflow-correction`.
- Base: published `origin/trunk` revision `1551bf87b2de09b4b2797fac2e566d699fce3991`.
- Worktree: workspace-local `tmp/worktrees/o2i-46-toolchain-workflow-correction`.
- Exact integrated review subject: the current clean `HEAD`, including this Authority Memory update; acceptance remains pending until an independent reviewer reports it for that exact revision.
