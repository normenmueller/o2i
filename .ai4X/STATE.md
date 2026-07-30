# Handoff

- Observed: 2026-07-30 CEST
- Work status: `PAUSED`
- Execution authorization: `REQUIRED`
- Authorization scope: no further execution until the user pushes the local
  Issue `#6` candidate. Retain legacy evidence unchanged. Do not change
  fachliche artifacts, delete governance evidence, touch another repository,
  or push.
- Current Issue: `#6`
- Current gate: `actions-node24-1`
- Gate status: `PENDING`
- Current node: `actions-node24`

# Objective

Remove the GitHub Actions Node.js 20 deprecation annotation by pinning
`actions/cache` v5.0.5 without changing cache or verification behavior.

# Current Gate

- Attempt: `actions-node24-1`
- Subject: the exact repository `HEAD` containing this record, limited to the
  `actions/cache` pin in `.github/workflows/verify.yml` and this volatile
  handoff.
- Mandatory checks: local repository verification and remote GitHub
  verification without the Node.js 20 deprecation annotation.
- Finding status: `CLOSED`
- Result: `PENDING`

# Repository Facts

- GitHub Issues own change state, dependencies, plans, and review evidence.
  Project `O2I` is only the PO scheduling view.
- Issue `#2` is closed with Project status `Done`; its accepted cutover
  revision is reachable from `trunk` and remote verification is green.
- Issue `#6` is open with Project status `In progress`.
- Issue `#7` retains legacy-governance cleanup in `Backlog`; no deletion is
  authorized.
- Legacy register files and validator code remain immutable migration evidence
  until a separately approved cleanup.
- The user controls ArchiMate edits and pushes.

# Dirty Scope

- No tracked changes are expected after the local Issue `#6` commit.

# Risks

- The remote acceptance condition cannot be established locally.
- Live GitHub state is never required for deterministic local repository
  verification.

# Verification

- Cutover revision `2713f986557eea257293a93becac90e108ce547c` is active.
- Remote run `30544015335` for handoff revision `de93eed` succeeds.
- `actions/cache` v5.0.5 resolves to immutable commit
  `27d5ce7f107fe9357f9df03efb73ab90386fccae`.
- `./utl/verify.sh all` passes for the local Issue `#6` candidate.

# Next Action

The user pushes the local Issue `#6` candidate. Then verify the remote run and
the absence of the Node.js 20 deprecation annotation.

# Local Return Point

After the user pushes Issue `#6` and remote verification is green without the
Node.js 20 annotation, close Issue `#6` and resume Issue `#4` with a
residual-scope audit against accepted revision
`7623d1c2726a977f255f00ef65b6980159d02f83`.
