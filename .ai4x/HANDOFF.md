# Handoff

<!-- o2i-handoff-envelope-v1 -->
{"schema":"o2i.handoff/v1","workStatus":"PAUSED","currentIssue":"#128","currentNode":"await-md2pdf-collaborator-access"}
<!-- /o2i-handoff-envelope-v1 -->

# Objective

Finish the PO-authorized upstream bug-report linkage: md2pdf #8 is created and natively blocks O2I #128; assigning both requested accounts is pending Gertrud's repository access. After assignment, wait for a corrected stable renderer before O2I integration. No #128 product correction or #125 implementation has started.

# Authority

Re-fetch https://github.com/normenmueller/md2pdf/issues/8 and the owning O2I linkage record: https://github.com/normenmueller/o2i/issues/128#issuecomment-6419031753. The PO authorized only reporting/linking the upstream failure and waiting for its corrected stable release. This creates no renderer-implementation, O2I-implementation, merge or release authority. Keep #125's independent start boundary: https://github.com/normenmueller/o2i/issues/125#issuecomment-5894723274. Status, design acceptance and this handoff supply no authority. No cold-start eligibility is claimed.

Product Owner operating instruction: assign every newly created Issue to both `normenmueller` and `gertrud-ai4x`; verify the remote assignees.

# Current Facts

- Current branch remains `feat/125-strategy-cascading`; no #128 implementation checkout was selected. Fresh Project observations: #128 `Refinement`, #125 `Ready`.
- md2pdf #8 is open, authored by `gertrud-ai4x`, with exact reproduction and downstream references. Native dependency read back: O2I #128 is blocked by md2pdf #8.
- Gertrud currently has read-only md2pdf access and is not assignable there; no matching repository invitation was observed. Both upstream assignees remain unset. The PO has been asked to invite `gertrud-ai4x`; verify fresh facts before retrying.
- O2I's renderer contract is unchanged. Tested 0.2.5 does not fix the failure. Exact revision/tool identities and accepted-baseline guidance are owned by https://github.com/normenmueller/o2i/issues/128#issuecomment-6418420751; re-fetch before implementation.
- #125 design remains `spec/design/strategy-cascading.md`, SHA-256 `37bf3a3a1ef13ebcb5918589417d40e3f284bf6fd8b5b03cf971761d69a65bbb`, independently accepted as software design only. Paper wording remains preliminary.
- Illustration remains parked on `feat/116-illustration`; #115/#116 depend on #125. Preserve Ethos/Mission, exports and company-Vision return point.

# Material Risk

Generic renderer/Pandoc/Listings cause remains UNKNOWN; the O2I header is unnecessary for the failure. No Ubuntu CI or full-paper acceptance is established. Preserve umlauts and fachliche content. A version-only update is not PDF repair. Qualify project/CI tools together while global Homebrew stays current stable. Broader upgrades need confirmed scope. Never accept a PDF from preliminary #125 wording or edit `meta/o2i.archimate`.

# Verification

The owning #128 refinement records reproduction, versions, matrix and review: thirteen macOS/TeX Live 2026 renders, eight passing controls and five leading-umlaut failures (exit 43), including without O2I header. CI-version Pandoc/crossref is not actual Ubuntu CI. Upstream #8 and the O2I linkage were read back with author `gertrud-ai4x`; native dependency was separately read back. Assignees remain unverified.

Publication and verification Co-Authors shaped the recommendation; independent review accepted its published body without findings. Earlier operating-memory checkpoints and reviews passed. Gertrud's verified Git route is in governance guidelines. No #128 or #125 product acceptance is claimed.

# Next Action

When the PO sends the exact md2pdf collaborator invitation, accept it as `gertrud-ai4x`, verify repository rights, assign #8 to both requested accounts and read back the result. Then wait for md2pdf's corrected stable release; upstream closure alone is insufficient. No automatic monitoring is scheduled. Before later O2I integration, re-fetch the fixed release, confirm the regression and obtain its own implementation authority. Keep #125 unstarted.

# Local Return Point

After accepted PDF recovery, return to #125's own start decision on this branch. After accepted cascading correction and agreed integration, reconcile #115/#116 and return to company Vision on `feat/116-illustration`.

No scratch or local installation owns required continuity. Restore missing verification tools through `operations/local-verification.md` and `utl/verification/README.md`; fetch remote facts rather than reconstructing them from a previous session.
