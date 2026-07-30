# Handoff

- Observed: 2026-07-31 CEST
- Work status: `ACTIVE`
- Execution authorization: `APPROVED`
- Authorization scope: Issue `#14`; reduce the root README exactly through the
  accepted relocation proposal without semantic or informational loss.
- Current Issue: `#14`
- Current gate: `readme-reduction-1`
- Gate status: `PENDING`
- Current node: `readme-reduction`

# Objective

Keep the root README focused on positioning and central entry paths while
moving technical and contributor detail to its single owning document.

# Repository Facts

- GitHub Issues own change state, dependencies, plans, and review evidence.
  Project `O2I` is only the PO scheduling view.
- Issue `#11` is accepted and closed at revision
  `1400c4442b5f7b209cf67699ef4cd7e3c45f2437`; remote run `30576959153`
  succeeds and Project status is `Done`.
- The remote `blocked:external` label is deleted. Native Issue dependencies
  and explicit external-dependency records remain the dependency contract.
- Issue `#8` is accepted and closed at revision
  `5cd3852f08b0025ed80edf30ced7a37abb61cf12`; independent Finalreview reports
  no findings and 10.0 in all nine required dimensions, remote run
  `30584590860` succeeds, and Project status is `Done`.
- Issue `#14` is open with Project status `In progress`; the PO explicitly
  accepted its complete README proposal and authorized implementation.
- Issue `#7` remains `Ready` after Issue `#14`; Issue `#15` remains Backlog.
- Issue `#4` is open with Project status `Backlog` and remains inactive.
- The user controls ArchiMate edits and pushes.

# Dirty Scope

- `README.md`
- `CONTRIBUTING.md`
- `o2i.pdf`
- `o2i.pdf.manifest.json`
- `spc/README.md`
- `.ai4X/BEHAVIOR.md`
- `.ai4X/operations/publication.md`
- `.ai4X/STATE.md`

# Verification

- `README.md` matches the PO-accepted Issue proposal byte for byte.
- The independent relocation audit's four findings are closed.
- `./utl/verify.sh all`, `git diff --check`, and the workspace O2I boundary
  check pass for the current working tree.

# Next Action

Commit the exact candidate and submit that immutable revision to an
independent, risk-proportionate Finalreview.

# Local Return Point

After Issue `#14` closes, return to a gate-free handoff before Issue `#7`.

# Current Gate

- Attempt: `readme-reduction-1`
- Subject: the exact repository `HEAD` containing this record.
- Mandatory checks: complete repository verification and independent
  documentation-ownership and lossless-relocation Finalreview.
- Finding status: `OPEN`
- Result: `PENDING`
