# Handoff

- Observed: 2026-08-28 CEST
- Work status: `PAUSED`
- Current Issue: `#100`
- Applies on branch: `feat/100-cold-start-dormancy`
- Current node: `protected-publication-authority`

# Objective

Make merged branch handoffs deterministically dormant on clean `trunk` so fresh sessions select the current repository return point without treating expected historical state as a contradiction or repair task.

# Authority

- The Product Owner explicitly requested immediate implementation of the agreed target design.
- Issue #100 owns this Protected repository-governance change.
- Authorized scope is Issue creation and activation, capability-matched Co-Authoring, `.ai4x/BEHAVIOR.md`, `.ai4x/governance/guidelines.md`, `.ai4x/STATE.md`, `CONTRIBUTING.md`, deterministic governance tests, local verification, independent read-only review and corrections, and a local commit.
- Exclusions are protected publication, merge, Issue closure, Project `Done`, cleanup, release, tag, fachliche O2I semantics, model, Haskell, CLI, approval binding, and `/delete` behavior.

# Material Risk

- False dormancy must not hide active or dirty work, and dormancy must never imply merge, completion, closure, Project state, or authority.
- Only a clean `trunk` checkout with no active-checkout pointer and one valid different non-`trunk` binding may classify the tracked handoff as dormant.
- Missing, multiple, malformed, detached, Git-unavailable, dirty-`trunk`, or non-`trunk` mismatch cases remain unresolved and retain the safe boundary.

# Participants

- Primary Gertrud: authority boundary, remote facts, Issue and Project administration, current handoff, verification, review routing, and publication preparation.
- External Repository Governance, Agentic Workflow Safety, and Human Usability Co-Author: completed target design and active implementation of canonical and human-facing contracts and deterministic tests; excluded from independent acceptance.
- Independent reviewer: returned `changes required` on the exact first candidate, then accepted the corrected exact five-path candidate with zero blocking and zero advisory findings; remained read-only and separate from authorship.

# Verification

- Official OpenAI documentation confirms that `/delete` permanently removes the current transcript and descendants while resuming a saved session reloads its selected transcript; repository continuity must therefore remain sufficient without session history.
- The Co-Author completed the target design, canonical and human-facing contracts, and deterministic positive and negative applicability matrix; the primary Gertrud owns this current handoff.
- Issue #100 is open, assigned to `gertrud-ai4x`, and in Project status `In progress`; the required Machine User identity and Project scope are verified.
- `./utl/verify.sh governance` passes governance 38/38 and routing 18/18; `./utl/verify.sh licensing` passes all licensing contracts including 576/576 path assignments; `git diff --check` passes.
- Independent review found pointer-precedence ambiguity and insufficient raw branch-field and cold-start evidence. The Co-Author corrected both through one pointer-first decision ladder, raw STATE fixtures, Git branch validation, and an explicit dormant-cold-start linkage.
- Independent re-review accepted the corrected exact five-path candidate with zero blocking and zero advisory findings; the candidate is committed locally on the bound branch.

# Next Action

Wait for explicit protected-publication authority; resume by publishing this exact reviewed candidate without merging or closing Issue #100.

# Local Return Point

- Branch: `feat/100-cold-start-dormancy`.
- Base: clean `trunk` revision `ceeec6d5632f78152d96d908d9ed1fdc682bcbbd`.
- The reviewed five-path scope is committed locally; no uncommitted work remains after the handoff amendment.
