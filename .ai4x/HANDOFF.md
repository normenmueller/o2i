# Handoff

<!-- o2i-handoff-envelope-v1 -->
{"schema":"o2i.handoff/v1","workStatus":"ACTIVE","currentIssue":"#128","currentNode":"pull-request-review"}
<!-- /o2i-handoff-envelope-v1 -->

# Objective

Implement the authorized md2pdf 0.2.6 integration through a ready-for-review PR with green required checks and independent exact-candidate acceptance. Work autonomously through implementation, verification and corrections. Do not merge or start #125.

# Authority

Current explicit PO authority is recorded at https://github.com/normenmueller/o2i/issues/128#issuecomment-6428633968; re-fetch the owning Issue and that bounded start decision. Approved scope and preflight: https://github.com/normenmueller/o2i/issues/128#issuecomment-6428371621. Target ends at `In review`: reviewed PR and green checks, no unresolved required findings. Exclude merge, Issue closure, releases/tags, cleanup, unrelated upgrades, native-model edits, #125 implementation and acceptance of its preliminary paper. This handoff creates no authority or cold-start eligibility.

New Issues must be assigned to both `normenmueller` and `gertrud-ai4x`, then verified remotely.

# Current Facts

- Selected checkout/branch: `fix/128-md2pdf-026`, from accepted trunk `36968ccb1f2c4c9cbd7c1d6bd09092596dc242b5`. The native Issue Development branch link is remotely verified.
- #128 is remotely verified `In review` with linked PR https://github.com/normenmueller/o2i/pull/129. Re-fetch its head, draft state, checks and review evidence; this handoff proves no final acceptance. #125 remains `Ready` and unstarted. Preserve `feat/125-strategy-cascading` and `feat/116-illustration` independently.
- O2I's renderer contract now binds stable md2pdf 0.2.6 to `2ded5ac8fa39e40a665fd6acf13e94fa58a9c2ee`; upstream #8 is closed. Isolated tools are reconstructed, including hindent 6.2.1.
- Universal operating-memory updates are preserved as separate commits through remotely verified backup `488d8e0b5a3c33e5759c5c4a6ce92472b87d4572`, excluding unfinished #125 product content.
- The regenerated accepted paper and unchanged-schema manifest accompany a five-case actual-PDF regression in `utl/paper/check-inline-code.py`, called by the canonical paper stage. Accepted prose, models and image assets remain unchanged.

# Material Risk

The renderer fix uses an internal Listings scanner. Require actual Ubuntu CI and independent acceptance on the current candidate. The first Ubuntu candidate passed inline-code and full-paper rendering but exposed lossy URL extraction in freshness comparison; correct only exact-character-preserving layout normalization and compare actual URI targets. Never reconstruct missing glyphs or weaken content checks. Keep the existing manifest schema; no general toolchain upgrade or text workaround. Preserve fachliche meaning and parked models. Agents never edit `meta/o2i.archimate`.

# Verification

The first candidate's exact evidence and required corrections are recorded at https://github.com/normenmueller/o2i/issues/128#issuecomment-6430206614; use subsequent owning-Issue/PR evidence for the current result. The five-case regression passes on macOS and Ubuntu with 0.2.6 and fails with 0.2.4 at the original Listings error. Accepted prose, model and image assets remain unchanged. The 56-page PDF SHA-256 is `addb772bf3f92aa746f1092678cc218e718f64202fbcf0917ee59e44754a540a`; all-page and detailed specialist visual QA found no defect. Existing CI Pandoc/crossref versions also produced identical raster pages locally. Historical checks never accept a later head; keep exact-candidate local/remote evidence and independent verdicts at their remote owners.

# Next Action

Re-fetch PR #129 and the owning Issue. Complete any missing checks, independent review or necessary corrections under the bounded scope; keep coherent commits, verified backups and current Project state. Once the exact candidate is green, independently accepted and free of required/advisory findings, make the PR ready and hand control to the PO for review. Surface only material new PO decisions or blockers requiring PO action.

# Local Return Point

At a green reviewed #128 PR, hand control to the PO for its PR decision. Trunk integration and synchronization of parked branches remain separate decisions. After accepted PDF recovery, #125 keeps its own start boundary; after accepted cascading correction and agreed integration, return to company Vision on `feat/116-illustration`.

Restore tools through `operations/local-verification.md` and `utl/verification/README.md`. No required continuity or authority belongs only to scratch or local installations.
