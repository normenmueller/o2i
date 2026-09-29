# O2I AI Team

Load for collaboration or review. This contract owns capability routing, collaboration timing and records, and authorship/review separation. `governance/` owns authority, risk, remote work, and verdicts.

## Roles

- The Product Owner is the sole human decision and publication authority.
- Gertrud coordinates scope, capabilities, boundaries, evidence, and decisions; she is not a universal specialist.
- A specialist owns one assigned capability and bounded scope demonstrated by the work.
- An external Co-Author actively shapes design and implementation within the assigned specialist scope.
- An independent reviewer is read-only, did not author or implement the exact candidate, and covers capabilities matched to its material risks.

## Capability Routes

| Surface | Required capability | Skill | Contract |
| --- | --- | --- | --- |
| Core, Operation, adapters, CLI, Haskell, types, laws, performance | O2I metamodel, formal methods, type theory, Haskell, risk-specific API/performance | `o2i-formalization` | `operations/haskell-authoring.md` |
| Metamodel, ArchiMate, Profile, syntax, model contracts | O2I metamodeling and enterprise architecture; TOGAF/ArchiMate when triggered | `o2i-modeling` | `operations/modeling.md` |
| Strategy, terminology, qualification, measurement, effect | strategy, measurement, source criticism, O2I semantics | `o2i-strategy` | `operations/strategy-review.md` |
| White Paper, README, WTF, figures, rendering | technical publication, information design, affected O2I domain | `o2i-publication` | `operations/publication.md` |
| Material independent acceptance | independent critical review plus every risk-matched capability | `o2i-independent-review` | `governance/guidelines.md` plus affected operations |
| Governance, workflow, agent architecture, verification routing | repository governance, agentic safety, deterministic verification, human usability | none | `governance/guidelines.md` |

Load every materially affected row. Assign multiple capabilities to one agent only when credible and explicit; distinct risks still require distinct expertise. Missing required capability stops dependent work.

## Separation And Evidence

Routine reversible work may remain primary-only when no specialist judgment shapes it and deterministic checks close risk. Otherwise assign a Co-Author before embedding that judgment. A later reviewer cannot supply missing co-authorship; an author, Co-Author, or implementer never independently accepts their candidate.

Assign one bounded, independently verifiable result with explicit owned paths and mutation authority. Record capability, role, exact subject/scope, contributions and changed paths, checks, findings, unresolved risk, and authorship/review separation. Commit permission must be explicit; preserve concurrent work.

The team is repository/session-local. Cross-project input requires an explicit versioned artifact; infer no state from another session or shared runtime memory.
