# Scope

Load before local verification setup, repair or execution. Governance owns
required stages and acceptance; `utl/verify.sh` owns checks and stage selection.

# Environment Recovery

Treat ignored `utl/verification/.local/` as reconstructible tool installations
and run intermediates. Its absence after a fresh clone is expected. Never infer
lost project state from missing installations or recover authority from them.

1. Read `utl/verification/README.md` for the tracked reconstruction procedure
   and prerequisite routes. Use its owning sources: CI and specification for
   toolchain versions; `doc/resources/md2pdf.json` for renderer acquisition.
2. Observe the installed tools. If the local environment is absent, incomplete
   or incompatible, reconstruct it from that procedure within the selected
   checkout. Setup may need network/cache permission; verification installs
   nothing implicitly. Preserve unrelated files and global installations.
3. Run `./utl/verification/local.sh checkpoint` for an authorized backup, or the
   explicitly required canonical stage through the same starter. Retain normal
   stage selection and checks; never change pins merely to obtain a green run.
4. Distinguish setup failure, tool-version mismatch and candidate failure.
   Repair the observed cause and rerun affected checks. Report exact passed and
   outstanding evidence; a partial run never proves complete verification.

Never keep required source, results, evidence or continuation solely in `.local/`.
Move required results to their durable owner before relying on them. A rebuild
recipe belongs to `utl/verification/`; this contract owns agent actions and
retrieval only. Toolchain upgrades are separately verified candidates, not
implicit environment repairs.
