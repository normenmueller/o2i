# Handoff

<!-- o2i-handoff-envelope-v1 -->
{"schema":"o2i.handoff/v1","workStatus":"ACTIVE","currentIssue":"#128","currentNode":"await-product-owner-renderer-repair-scope"}
<!-- /o2i-handoff-envelope-v1 -->

# Objective

Continue from the completed #128 refinement and prepare the next bounded renderer-repair decision. Restore PDF functionality before starting #125. Updating only md2pdf to 0.2.5 does not repair the reproduced leading-umlaut failure. No #128 product correction or #125 cascading implementation has started.

# Authority

Re-fetch https://github.com/normenmueller/o2i/issues/128 and its refinement evidence: https://github.com/normenmueller/o2i/issues/128#issuecomment-6418420751. The PO authorized operating-memory backup and refinement through a concrete recommendation; those results create no implementation-start or foreign-repository authority. A generic renderer correction needs its own subject-bound work unit before a corrected stable release is integrated through #128. Keep #125's independent start boundary: https://github.com/normenmueller/o2i/issues/125#issuecomment-5894723274. Status, design acceptance and this handoff supply no authority. No cold-start eligibility is claimed.

Product Owner operating instruction: assign every newly created Issue to both `normenmueller` and `gertrud-ai4x`; verify the remote assignees.

# Current Facts

- Current branch remains `feat/125-strategy-cascading`; no #128 implementation checkout was selected. Fresh Project observations: #128 `Refinement`, #125 `Ready`.
- Accepted trunk observed at `36968ccb1f2c4c9cbd7c1d6bd09092596dc242b5`; re-fetch before choosing a dedicated #128 candidate baseline. #126 completion: https://github.com/normenmueller/o2i/issues/126#issuecomment-5894635312.
- O2I still binds md2pdf 0.2.4 at `8ab76cd31129b778165f9f090391e91139be9ddc`. Latest stable observed: 0.2.5 at `c8cb54cf5bddc68353c6cc9c7707a7524188915f`; recheck at implementation time. All 23 renderer library files are unchanged between these revisions.
- #125 design remains `spec/design/strategy-cascading.md`, SHA-256 `37bf3a3a1ef13ebcb5918589417d40e3f284bf6fd8b5b03cf971761d69a65bbb`, independently accepted as software design only. Paper wording remains preliminary.
- Illustration remains parked on `feat/116-illustration`; #115/#116 depend on #125. Preserve Ethos/Mission, exports and company-Vision return point.

# Material Risk

The failure is reproduced without O2I's header, but the precise cause within renderer/Pandoc/Listings remains UNKNOWN. No actual Ubuntu CI run or full-paper acceptance is established. Preserve umlauts and fachliche content. A version-only update cannot be reported as PDF repair. Global Homebrew may stay current stable; qualify the relevant project/CI combination together rather than silently accepting a moving baseline. Broader toolchain changes need confirmed scope. Never regenerate an accepted PDF from preliminary #125 wording. Agents never edit `meta/o2i.archimate`.

# Verification

The owning #128 comment records the complete reproduction recipe, exact releases, tool/archive identities, comparison matrix, limits and expert recommendation. Thirteen local renders: two renderer revisions and two Pandoc/crossref pairs, each with ASCII/internal-umlaut/leading-umlaut cases, plus the generic case without O2I header. Eight controls pass with text preserved; all five leading-umlaut cases fail with exit 43. This includes CI-version Pandoc 3.9/crossref 0.3.24 on macOS/TeX Live 2026, not Ubuntu CI.

Publication and verification Co-Authors shaped the recommendation; independent read-only review accepted its exact published body with no blocking or advisory findings. The operating-memory changes passed scoped licensing/governance checkpoints and independent reviews. Actual HTTPS Git publisher and commit author/committer: `gertrud-ai4x`; the dedicated configuration route is in governance guidelines. No #128 or #125 product acceptance is claimed.

# Next Action

Present the bounded recommendation: investigate and correct the generic failure in the renderer's owning work unit, then integrate a corrected stable release through #128 on accepted trunk with local/CI qualification, actual paper rendering and independent acceptance. Obtain exact authority before foreign-repository work or product implementation. A broad Homebrew/Pandoc/library upgrade is not a demonstrated repair. #125 remains unstarted.

# Local Return Point

After accepted PDF recovery, return to #125's own start decision on this branch. After accepted cascading correction and agreed integration, reconcile #115/#116 and return to company Vision on `feat/116-illustration`.

No scratch or local installation owns required continuity. Restore missing verification tools through `operations/local-verification.md` and `utl/verification/README.md`; fetch remote facts rather than reconstructing them from a previous session.
