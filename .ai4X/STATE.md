# Handoff

- Observed: 2026-07-29 CEST
- Work status: `ACTIVE`
- Execution authorization: `APPROVED`
- Authorization scope: review and close `o2i-0004`; do not edit the ArchiMate
  model directly or push. This includes the approved removal of premature
  build-revision provenance before the final review candidate.
- Current gate: `o2i-0004-finalreview-11`
- Gate status: `REJECTED`
- Current node: `o2i:situation-anchor-gate`

# Objective

Establish one lean closed Situation-anchor set whose constructors all satisfy
the complete anchor relation family before finalizing the ArchiMate profile.

# Repository Facts

- `o2i-0003` is paused because its profile contract depends directly on
  `o2i-0004`.
- The closed anchor set is `BusinessCapability | BusinessProcess |
  BusinessObject | ValueStream`; every constructor supports
  `is-constituted-by`, `anchors`, `changes`, and `measures`.
- `BusinessRole` and `RegulatoryConstraint` remain ordinary Enterprise
  Architecture artifacts outside the Situation-anchor type.
- The exact ArchiMate profile authority is
  `spc/ctr/archimate/profile.json`; Haskell and the generated White Paper
  inventory project it.
- The versioned White Paper is bound to its exact publication sources and
  compared structurally and textually with an isolated fresh build.
- The user controls ArchiMate edits and pushes.

# Verification

- Exact clean revision
  `0f9bce63645adc9ca2628a17213b154d3e9bd0a0` passes one uninterrupted
  `./utl/verify.sh all`; its Haskell Finalreview rejects the former
  list-bind TraceSearch and macro-evidence architecture.
- Independent design reviews accept one private typed relational mechanism,
  constructive prefix-connected plans, total typed projections, and one
  immutable `PreparedMacroEvidence` prepared before Collective assessment.
- The generative executor boundary, closed fourteen-relation vocabulary, and
  typed domain cache are independently accepted at 10.0 throughout.
- Occurrence-aware witnesses, ordered collision-safe canonicalization, and
  operation-bound work pass 71 focused contracts, every Core suite, HIndent,
  and compile/import contracts. Their renewed independent Haskell review
  reports no finding and 10.0 in every dimension.
- `O2I.Validation.MacroEvidence.{Types,Prepare,Eval}` owns the shared
  preparation boundary. Semantics prepares one immutable value; Collective and
  Trace consume it through narrow interfaces. Its bounded independent Haskell
  review reports no finding and 10.0 in every dimension.
- The strategy and publication scopes are byte-identical to their accepted
  scopes at `859c29de725e7150bc58f59ef15fe8ae8bcc485f`; only formalization and
  Haskell require new Finalreviews.

# Gate

- Attempt: `o2i-0004-finalreview-11`
- Subject: revision `0f9bce63645adc9ca2628a17213b154d3e9bd0a0` and the
  implementation scope declared by
  `.ai4X/governance/changes/o2i-0004/plan.md`.
- Mandatory checks: strategy, formalization, Haskell, publication, profile,
  AMX, View, and repository verification.
- Finding status: `OPEN`
- Result: `REJECTED`

# Next Action

Replace the private list-bind `O2I.Validation.Trace.Search` architecture with
focused domain-owned effect-trace rules, typed projections, and execution over
the accepted private relational mechanism. Preserve the public trace API,
identity, canonical order, diagnostics, and O2I semantics; extend semantic
oracle and multi-axis performance contracts before bounded Haskell review.
Implement and verify the independently designed total endpoint-typed
occurrence projection first. Independent Co-Author and formalization reviews
accept a Context-Skeleton rule followed by one owner-specific complete
constituent rule per Skeleton and anchor kind. Every trace field is projected
from a typed required-premise occurrence; no binding projection is needed.
The corrected projection passes Relational 61/61, MacroEvidence 71/71, Core,
compile/import, and formatting checks; its renewed independent review reports
no finding and 10.0 in every dimension. Four total Cabal-private typed
accessors now expose only exact prepared domains for owned Primitives, Strategy
roles, Performance Dimensions, and Situation anchors; missing addresses yield
an empty typed domain while cache internals remain hidden. All seven Core
suites pass with `-Werror`, including MacroEvidence 73/73, Relational 61/61,
and the public suite 297/297. Their bounded independent review reports no
finding and 10.0 in every dimension. The Co-Author now implements the separate
Trace Types and declarative rule package. That package now compiles the
independent addressed-Need rule, connected nine-relation Context rule, and four
static-anchor alternatives of the connected eighteen-relation constituent
rule. Complete Core, compile/import, HIndent, and diff checks pass; its bounded
independent Haskell/formalization review reports no finding and 10.0 in every
dimension. The accepted integration design moves the public Trace
representation behind private typed construction, executes addressed-Need
diagnostics independently, skips empty anchor domains, canonicalizes exact
public trace identity, and preserves diagnostic order. Implement `Trace.Eval`
and replace `Trace.Search` next.

# Local Return Point

After the accepted `o2i-0004` gate, stop and consult the user before
`workspace:issue-coordination`. After renewed approval, establish the GitHub
Issue/Fork-/Return coordination model, finalize the repository-governance entry
point, audit `o2i-0003` against the accepted revision, close already satisfied
scope, and stop before substantive profile-contract implementation.
