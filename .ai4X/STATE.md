# Handoff

- Observed: 2026-07-30 CEST
- Work status: `ACTIVE`
- Execution authorization: `APPROVED`
- Authorization scope: implement and verify Issue `#8` only. Add conservative
  path-sensitive CI selection without changing verification commands, O2I
  semantics, formalization, notation, APIs, or publication content. Do not
  push.
- Current Issue: `#8`
- Current gate: `path-sensitive-ci-2`
- Gate status: `PENDING`
- Current node: `path-sensitive-ci`

# Objective

Run expensive remote verification jobs only for relevant changes while every
uncertain classification deterministically triggers the complete suite.

# Current Gate

- Attempt: `path-sensitive-ci-2`
- Subject: the exact repository `HEAD` containing this record, limited to CI
  classification, workflow wiring, tests, documentation, and runtime handoff.
- Mandatory checks: representative path matrix, stable required-check names,
  conservative fallback, unchanged local full verification, full local and
  remote verification, repository autonomy, and diff hygiene.
- Finding status: `CLOSED`
- Result: `PENDING`

# Repository Facts

- GitHub Issues own change state, dependencies, plans, and review evidence.
  Project `O2I` is only the PO scheduling view.
- Issue `#11` is accepted and closed at revision
  `1400c4442b5f7b209cf67699ef4cd7e3c45f2437`; remote run `30576959153`
  succeeds and Project status is `Done`.
- The remote `blocked:external` label is deleted. Native Issue dependencies
  and explicit external-dependency records remain the dependency contract.
- Issue `#8` is open with Project status `In review` after explicit PO
  activation.
- Candidate revision `a785e42` was rejected with three bounded findings. The
  current candidate closes its handoff, documentation, and PR-range test gaps.
- Issue `#4` is open with Project status `Backlog` and remains inactive.
- The user controls ArchiMate edits and pushes.

# Dirty Scope

- `NONE`

# Risks

- A false negative could skip a required verification job.
- Required check names and branch-protection behavior must remain stable.

# Verification

- Baseline handoff revision `d1529e5` is available on `origin/trunk`.
- The path-classification suite passes all 12 representative tests, including
  a divergent Pull Request history.
- `git diff --check` and the workspace O2I boundary check pass.
- `./utl/verify.sh all` passes the complete Governance, model, Haskell,
  Haddock, formatting, and White Paper contract.
- Issue `#8` still requires independent Finalreview and remote full
  verification to remain green.

# Next Action

Obtain the risk-proportionate independent Finalreview of `HEAD`. After the
user pushes the accepted revision, verify the complete remote workflow.

# Local Return Point

After Issue `#8` is accepted and closed, return to a gate-free paused handoff
before Issue `#7` activation.
