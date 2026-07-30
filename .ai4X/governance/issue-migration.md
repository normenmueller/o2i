# GitHub Issue Migration

Status: `CUTOVER CANDIDATE`

The PO approved the atomic authority cutover after complete reconciliation.
The commit containing this record is the cutover candidate; Issue `#2` binds
its full SHA. GitHub becomes authoritative when that revision reaches `trunk`.
Until then, the legacy register remains authoritative.

## Baseline

- Git revision:
  `8c62bd66d32227462cbdf9780796d82c164371f5`
- Source checksums: `.ai4X/governance/issue-migration.sha256`
- Existing GitHub issues: one open issue, `#1 Clarify jsonschema license
  metadata`; no closed issues.
- Existing O2I GitHub Project: none among open or closed user Projects.
- Repository and Project administration capabilities: `VERIFIED`.
- Native Issue Dependencies: available and readable through GraphQL.
- Complete Issue and Project API export: available.

## Change Mapping

| Source | State | Target | Project status | Dependencies |
| --- | --- | --- | --- | --- |
| `o2i-0002` | implementing | GitHub `#3` | `Paused` | blocked by `#4` |
| `o2i-0003` | implementing | GitHub `#4` | `Paused` | blocked by closed `#5` |
| `o2i-0004` | done | closed GitHub `#5` | `Done` | derived from `#4` |
| GitHub `#1` | open | retained unchanged | `Backlog` | none |
| issue-coordination migration | active locally | GitHub `#2` | `In progress` | none |

The PO approved one closed migrated Issue for completed `o2i-0004`. Its
work-record identity, participants, lineage, proposal, plan, and reviews remain
directly addressable.

## Stable Target Records

| Change | Plan comment | Review comments | Additional records |
| --- | --- | --- | --- |
| `o2i-0002` | `5130424733` | `5130429934`, `5130430039` | handoff `5130443303` |
| `o2i-0003` | `5130424840` | `5130430143`, `5130430266` | audit `5130433974`; handoff `5130444257` |
| `o2i-0004` | `5130424996` | `5130430406`, `5130430511`, `5130430617`, `5130430738`, `5130430886`, `5130430995` | none |

The public user-level Project is
`https://github.com/users/normenmueller/projects/4`; its scheduling View is
`Main`. Pilot evidence is Issue `#2`, comment `5130398632`.

The PO-approved pause contracts are:

- `o2i-0002`: paused while its required profile-contract change `o2i-0003`
  remains open; resume after `o2i-0003` is accepted.
- `o2i-0003`: paused for this Issue-governance cutover; resume with the
  residual-scope audit against accepted `o2i-0004`.

## Artifact Mapping

| Source artifact | Target |
| --- | --- |
| `changes.json` identity, title, author, coauthors, state, lineage, and dependencies | issue metadata, native dependency, and Project status |
| `o2i-0002/proposal.md` | complete `o2i-0002` issue problem and target sections |
| `o2i-0002/plan.md` | separate digest-bound implementation-contract comment on `o2i-0002` |
| `o2i-0002` admission reviews | two structured append-only issue comments |
| `o2i-0003/proposal.md` | complete `o2i-0003` issue problem and target sections |
| `o2i-0003/plan.md` | separate digest-bound implementation-contract comment on `o2i-0003` |
| `o2i-0003/authority-audit.md` | structured current-scope issue comment |
| `o2i-0003` admission reviews | two structured append-only issue comments |
| `o2i-0004/proposal.md` | complete proposal in the closed `o2i-0004` issue |
| `o2i-0004/plan.md` | separate digest-bound implementation-contract comment on the closed `o2i-0004` issue |
| `o2i-0004` admission and final reviews | six structured append-only comments on the closed `o2i-0004` issue |
| `.ai4X/governance/README.md` | active agent execution contract from cutover |
| `utl/change-governance.py` and tests | retained immutable migration evidence; removed from active verification |
| `utl/verify.sh` and Governance CI job | network-independent active-contract checks |

## Review Evidence Contract

Every migrated review record contains:

- phase and capability;
- reviewer identifier;
- exact proposal digest or reviewed Git revision;
- reviewed scope when applicable;
- verdict and complete findings;
- complete dimension scores;
- source path and source SHA-256.

Review comments are contractually append-only. Editing an accepted comment
invalidates it; corrections use a new comment.

## Reconciliation

No source may be removed until all checks pass:

- every source path in the checksum manifest matches its blob at the immutable
  baseline revision;
- every open change has exactly one target issue;
- all lineage and dependency directions match;
- every admission and final review has exactly one target record;
- every target record preserves its exact digest or Git revision;
- GitHub API export and this matrix have equal cardinality.

Authority cutover additionally requires successful reconciliation, verified
capabilities, explicit PO approval of every non-transfer decision, passing
local target-contract checks, and simultaneous replacement of every legacy
authority statement.

Result: `ACCEPTED`. A complete read-only API reconciliation confirms exact
proposal and plan content, source hashes, review cardinality and content,
scope-audit content, Issue state, native dependency direction, and Project
status for every mapped record. The repository label set is exactly
`framework-change`, `maintenance`, and `blocked:external`.

## Pilot Admission Gate

Status: `ACCEPTED`

No pilot Issue is created until:

- repository labels `framework-change`, `maintenance`, and
  `blocked:external` exist with their declared meaning;
- the user-level Project `O2I` exists and exposes exactly the scheduling
  statuses `Backlog`, `Ready`, `In progress`, `Paused`, `In review`, and
  `Done`;
- issue creation, comments, closure, native dependencies, Project item
  transitions, and complete API export are verified;
- the immutable baseline checksum check passes through repository
  verification.

## Explicit Non-transfer Decisions

None. Every legacy change, proposal, plan, participant, lineage relation,
dependency, Admission review, Finalreview, and current state has an explicit
Issue or Project target.

## Deletion Authorization

None. Legacy evidence remains retained and unchanged. Cleanup requires a
separate PO-approved package after the cutover revision is available on
`trunk`.
