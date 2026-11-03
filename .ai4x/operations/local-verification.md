# Scope

Load before local verification setup, repair or execution. Governance owns
required stages and acceptance; `utl/verify.sh` owns checks and stage selection.

# Execution And Recovery

Treat ignored `utl/verification/.local/` as reconstructible tool installations
and run intermediates. Its absence after a fresh clone is expected. Never infer
lost project state from missing installations or recover authority from them.

1. Before setup/dispatch, select stages with `utl/verification/verification_scope.py`
   for the checkpoint or exact base/head, as applicable. For post-merge, classify
   the accepted base to the published merge. `workflow_dispatch` selects all;
   post-merge alone does not justify it. Preserve required full/release and
   unknown-scope checks.
2. Read `utl/verification/README.md` for the tracked reconstruction procedure
   and prerequisite routes. Use its owning sources: CI and specification for
   toolchain versions; `doc/resources/md2pdf.json` for renderer acquisition.
3. Observe the installed tools. If the local environment is absent, incomplete
   or incompatible, reconstruct only the selected stages' prerequisites from
   that procedure within the selected checkout. The starter needs local Python;
   the canonical verifier enforces each selected stage's remaining tools. Setup
   may need network/cache permission; verification installs nothing implicitly.
   Preserve isolated-tool requirements, unrelated files and global installations.
4. Run `./utl/verification/local.sh checkpoint` for an authorized backup, or the
   explicitly required canonical stage through the same starter. Retain normal
   stage selection and checks; never change pins merely to obtain a green run.
5. Distinguish setup failure, tool-version mismatch and candidate failure.
   Repair the observed cause and rerun affected checks. Report exact passed and
   outstanding evidence; uncompleted required checks remain unmet.

Content evidence may be reused only with proved candidate/scope/integration
equivalence and valid freshness. Authority/identity guards remain binding;
exact-head approvals never transfer to a new head. Retain required new/post-merge
checks. Changed risk/failures require affected checks; unknown scope retains the
full fallback. Partial/cancelled runs prove only completed successful stages,
never a full run.

Never keep required source, results, evidence or continuation solely in `.local/`.
Move required results to their durable owner before relying on them. A rebuild
recipe belongs to `utl/verification/`; this contract owns agent actions and
retrieval only. Toolchain upgrades are separately verified candidates, not
implicit environment repairs.
