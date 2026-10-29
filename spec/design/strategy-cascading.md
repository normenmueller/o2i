# Strategy cascading: proposed executable design

This proposal explains the software change for [#125](https://github.com/normenmueller/o2i/issues/125). It is a design candidate for independent review, not an accepted implementation or another semantic authority. The [White Paper](../../doc/paper/o2i.md), particularly *Strategiebeitrag und kollektive Strategierealisierung*, *Relationen* and *Semantische Wohlgeformtheit*, owns the meaning. The [Core companion](../lib/core/semantics.json) will encode that meaning; the [ArchiMate Profile](../ctr/archimate/profile.json) owns its notation. This document describes how those contracts become checked, explainable evidence.

## Problem and preserved boundaries

At baseline `e3bcfe84cb1b15cf5e1fc3bbb7610fada2ccb1e2`, Core admits a direct Strategy Key Result `contributes-to` Strategy Key Result relation. Collective realization finds those direct edges and uses their target endpoints for coverage. It cannot express the intended contribution through a lower Strategy's Objective. The semantic pipeline also has no general assessment of individual Strategy `directs` or `contributes-to` claims: its macro check exists only within collective realization and checks the explicit contribution edge separately from participant primitive support.

The correction replaces that relation family with upper Strategy Key Result `translates-into` lower Strategy Objective. It also makes the two affected explicit Strategy macro claims independently assessable. A catalog edit alone would leave the executable meaning incomplete.

Strategy Key Result translation into a Need Objective, Intervention Key Result contribution to a Strategy Key Result, and Action contribution to Action retain their meanings. Complete Strategy formulation, Vision orientation, diagnosis, qualification, effect traces, collective Fit, readiness and empirical assessment retain their existing obligations. In particular, translation does not replace the requirement that every listed Strategy intent has Vision orientation. No toolchain upgrade, compatibility alias, migration reader, synthetic relation or general graph-query language belongs to this change.

## Proof obligations

Let `U` and `L` denote two different Strategy identities. An upper and lower role is determined by the modeled relation, not an organization chart or a numeric level. The following are the complete support alternatives for this change:

| Explicit claim | Required primitive support |
| --- | --- |
| `U directs L` | A listed Guiding Policy Principle of `U` guides a listed Guiding Policy Principle of `L`, **or** a listed Key Result of `U` translates into a listed Intent Objective of `L`. |
| `L contributes-to U` | A listed Action of `L` contributes to a listed Action of `U`, **or** a listed Key Result of `L` substantiates the very same listed Intent Objective of `L` into which a listed Key Result of `U` translates. |

An ordinary macro claim needs at least one complete alternative. It does not require every upper Key Result to cascade. Collective realization retains its stronger requirement: the union of contributor support must cover **every** Action and Key Result in the target's valid formulation. Action support covers only the exact target Action; the two-edge alternative covers only the exact upper Key Result. Neither an isolated translation nor Action support covers an upper Key Result.

Every contributing role member must belong to the named valid Strategy formulation, have the expected qualified type, and have an Asserted carrier and Asserted contextualization to that Strategy. All supporting relations are Asserted. The two-edge join is by exact Objective occurrence identity within the same validated graph; its model identity and owner are preserved. Equal labels, equal types, two Objectives in one Strategy, or an Objective and Key Result owned by different Strategies cannot satisfy it.

The two edges are `lowerKR -> lowerObjective` and `upperKR -> lowerObjective`; traversing the second edge in reverse for lookup does not reverse its semantic direction. Their existence supports a modeled contribution, not measured achievement, causal effect, arithmetic aggregation or unlimited transitivity. It produces no persisted or virtual KR-to-KR relation. A lower Strategy may contribute to several upper Strategies through separately justified links.

Macro statements remain explicit. Primitive evidence cannot invent a macro statement. Conversely, a macro statement cannot supply missing primitive evidence. A contribution does not additionally require the reverse `directs` macro; collective realization requires each contributor's explicit contribution, not an additional direction claim.

## Validation boundaries and result states

Structure resolves endpoint contextualization first. A Strategy-to-Strategy translation must have different Strategy owners, including when its commitment is Candidate and when no macro is present. The two affected macro families likewise reject a self-relation. These identity invariants do not depend on supplemental formulation inputs. Unresolved endpoint ownership retains its existing primary structural diagnostic; it does not produce a guessed distinctness result.

The new standalone translation receives the structural distinct-owner check without requiring a macro or complete supplemental formulation inputs. Role binding is required when the relation supplies macro or collective evidence: its source must then be a listed upper Key Result and its target a listed lower Intent Objective. Unlisted primitives may still occur in the graph, including in a structurally valid translation, but cannot produce a checked Strategy support witness. A separate declaration-level role defect would impose a stronger semantic requirement than the existing role-for-evidence rule; this design deliberately does not introduce it.

| Situation | Result |
| --- | --- |
| Candidate translation or macro with valid structure | Retained as Candidate diagnostic content; no asserted support proof. |
| Asserted declaration depends on Candidate ownership | Existing asserted-dependency defect remains; Candidate carriers or Strategies never supply successful support. |
| Needed formulation is missing or has unresolved identity sites | Assessment unavailable, with exact blocking Strategies and existing reasons; no support proof and no missing-support defect inferred from absence. |
| Needed formulation is invalid | Preserve its primary defects and suppress only dependent support obligations. |
| Valid formulations, but a translation endpoint is outside its declared role | Translation remains structurally admitted but is excluded from support; no standalone role defect. |
| Valid prerequisites, but an explicit macro has no complete support alternative | Macro-support defect at that macro occurrence. |
| Complete prerequisites and support | Scoped proof retaining the original supporting occurrences. |

Independent defects accumulate. Known structural distinctness failure is never hidden by missing formulations. An ineligible translation does not erase an unrelated valid Action alternative; an independently invalid relation nevertheless remains a model defect. Missing supplemental inputs alone must not turn an otherwise well-formed model into a rejection. Existing invalid-before-unavailable precedence remains in force. Invalid, unavailable and Candidate prerequisites remain distinguishable in internal assessment records and Operation output; none becomes a successful empty witness set. An Asserted macro whose Strategy endpoint is Candidate is a failed asserted dependency, not missing formulation input.

## Architecture and evidence types

The affected boundary is Strategy-to-Strategy evidence, not arbitrary path evaluation. It belongs in Core as one cohesive private domain module, provisionally `O2I.Semantics.StrategyRelations`. It replaces the collective family's ownership of primitive contribution discovery. It prepares eligible translation witnesses, assesses standalone macros and prepares the shared contribution evidence consumed by collective realization. `Semantics.Eval` coordinates it after Strategy formulation assessment and before collective assessment. The new module does not import collective realization, Operation or Profile.

The existing `SemanticIndex` provides exact carrier, ownership, forward and reverse relation lookups. Existing `QualificationEligibleStrategy` values establish validated formulation membership. A private preparation step builds each Strategy's role membership maps once from those proofs and retains membership and contextualization evidence. No consumer reconstructs role validity from type labels or public identity lists.

Three private opaque evidence records give the required construction boundaries:

- `PreparedStrategy scope` identifies the exact Strategy occurrence and graph and separates its validated Principle, Intent, Action and Key Result memberships.
- `StrategyTranslation scope` binds the distinct prepared upper/lower Strategies, the exact upper Key Result, the exact lower Intent Objective, and one original asserted translation occurrence plus its endpoint/contextualization evidence. Its constructor is private to checked preparation.
- `ObjectiveContributionSupport scope` binds one exact lower Strategy and Intent Objective, a nonempty set of its listed Key Result substantiation occurrences, and nonempty translation buckets grouped by upper Strategy and upper Key Result. Every bucket refers to checked `StrategyTranslation` evidence with that same Objective. It preserves the two original edge families without enumerating their Cartesian combinations.

These records use the existing nominal graph scope and retain graph/contract provenance. Runtime checks establish owner inequality, role membership and exact join identity; Haskell types preserve those checked construction boundaries afterwards. Introducing a separate phantom for every runtime Strategy identity would not prove those runtime facts and is unnecessary. Empty support is represented by an assessment result, never a partially constructed proof.

Direct Action evidence and mediated Objective evidence form a closed sum of contribution alternatives. Guiding Policy and translation evidence form a separate closed sum for direction. Primitive support is distinct from an explicit macro proof. A macro proof carries its original macro occurrence and nonempty admitted support; a collective consumer selects those proofs for the exact contributor/target pair. It also retains the existing separate macro-presence and participant-primitive-support findings, rather than collapsing them into one unexplained failure.

Successful contribution evidence exposes the exact covered target members and canonically ordered original occurrence evidence. The internal Objective grouping preserves which edges share an Objective. Existing public flat witness projections may remain convenient summaries, but they cannot be used to reconstruct or fabricate a proof. Operation resolves original occurrence provenance through its existing source maps; no new synthetic model identity enters those maps.

## Shared preparation and bounded work

Preparation indexes only observed edges and validated role membership. Action and Principle edges are bucketed by their actual owner pair. Valid translations are bucketed by exact lower Objective and upper Strategy/Key Result. Valid lower substantiations are bucketed by that same lower Objective. Joining those two buckets establishes mediated support only where both nonempty sides exist. Substantiation evidence is shared for the Objective; it is not copied once for every upper Key Result or possible lower/upper Key Result pair.

Macro assessment performs a lookup for its exact owner pair. Collective coverage selects the same pair evidence for each actual contributor incidence and unions its covered target members. It does not rescan all target members for every contributor or enumerate missing participant/target combinations. Missing required target members are one final set difference. Missing explicit macros remain separately diagnosable even where prepared primitive support exists.

Let `N` be carrier, relation and contextualization occurrences; `M` listed formulation memberships; `Q` macro requests plus collective participant incidences; and `W` the evidence memberships actually visited when materializing selected results. With balanced maps/sets, the intended work is `O((N + M + Q + W) log(N + M + Q + 1))` and storage is linear in prepared memberships and requested output. This bound includes rejected-edge visits, bucket traversal, deduplication and result ordering. A large requested output may legitimately make `W` large; an unobserved pair product may not.

The work counters must expose source occurrence visits, role-membership lookups, relation bucket/occurrence visits, join Objective visits, owner-pair lookups and emitted evidence memberships. Existing collective counters must be revised where their direct-edge interpretation no longer describes the actual work. Their old numbers are not a constraint on the new implementation.

## Contracts, diagnostics and integration

The Core companion removes `strategy-key-result-contributes-to-strategy-key-result` and declares `strategy-key-result-translates-into-strategy-objective`. It describes the bounded support alternatives and collective coverage without making a generic path grammar. `semantic-diagnostic-evidence.json`, generated catalogs and rule explanations gain exact diagnostics for relation-owner distinctness, asserted macro endpoint dependencies, and direction/contribution support. Distinctness belongs to Structure; evidence-use obligations belong to Semantics. Diagnostic keys bind the original relation and exact endpoints/owners, with no reuse of an unrelated rule's evidence schema. There is no standalone translation-role diagnostic.

Core's public Structure and Semantics evidence eliminators must remain exhaustive after those additions. Operation's human diagnostics and machine fragments, generated owner inventories and schema projections must preserve all named evidence fields. Scoped compile-pass/compile-fail API checks and the conformance corpus cover the new cases. The CLI remains a consumer of the existing validation levels; no command, level or switch is added. Existing diagnostic envelopes can remain where their closed generated inventories permit the new rules; any required schema change must be explicit and checked, never disguised as a missing field.

The principal affected files are Core's `semantics.json`, `semantic-diagnostic-evidence.json`, contract compiler/tests, `Structure` and its private evidence/index modules, `Semantics` public/internal modules, `Semantics.Eval`, `Semantics.Index`, the new Strategy relation module, `Family.CollectiveStrategyRealization`, rule definitions, Cabal module lists, tests and conformance corpus. Operation propagation reaches `Human/Diagnostic.hs`, `Machine/Fragment/Internal.hs`, validation result rendering and their tests. Profile mapping, generated artifacts and repository model projections follow the exact stabilized Core digest.

Profile removes all concrete mappings of the retired KR-to-KR family and adds the new endpoint-specific translation mapping. The existing translation token remains shared with Need translation; their semantic families remain separate. ArchiMate endpoint applicability, relationship type and direction require independent notation review. No old relation is silently reinterpreted on input.

## Verification and delivery sequence

The focused test matrix must establish:

1. Structural rejection of the retired direct Strategy KR-to-KR edge; admission of the new endpoint family; rejection of same-owner translation and self macros for both commitments, without requiring supplemental inputs.
2. Both direction alternatives and both contribution alternatives, independently; no contribution requirement for a reverse direction macro; no macro synthesized from primitives.
3. Exact shared-Objective joining: two different Objectives with the same label cannot combine; reversed edges, a different lower owner, unlisted role members and Candidate carriers/ownership/edges cannot supply proof.
4. Either missing edge, complete alternative support, independent defects, invalid prerequisites and missing/unresolved formulations. Fixtures preserve unrelated formulation obligations when isolating macro failure; a formulation failure must not be mislabeled as absent macro support.
5. Collective coverage of every target Action and KR using the same evidence; a valid ordinary contribution with incomplete collective coverage; no coverage from translation alone; participant and target roles preserved.
6. Both original edges and ownership provenance survive success and diagnostic projection; duplicate occurrences remain observable; canonical results and coverage are invariant under input permutation; distinct graph scopes cannot exchange evidence.
7. Adversarial scaling varied independently across Strategies, irrelevant relations, listed members, upper KRs per Objective, lower KRs per Objective, macro occurrences and collective incidences. A single Objective with many edges on both sides must avoid a pair product. Counters account for all rejected and successful observations, not only selected evidence.

First reconcile these proof obligations with the White Paper and independently review this concrete design. Then implement Core and its focused tests, propagate the checked contract through Profile and Operation, and regenerate dependent artifacts with exact digest binding. Run the complete five-package Haskell verification, licensing, model and publication checks plus independent final review. Design acceptance never substitutes for implementation acceptance.

The Product Owner updates `meta/o2i.archimate` in small guided saves after the executable contract is ready: replace affected native relations, synchronize the semantic/syntax/illustrative views, then regenerate snapshots, validate affected executable views and inspect exports. Agents do not edit that native source. Until this synchronization and verification finish, the correction is incomplete and the illustration remains parked. The separate pre-existing governance-memory budget failure must also be resolved before an all-green checkpoint can be claimed; it is not a reason to weaken these product checks.
