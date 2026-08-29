# O2I AI Team

This contract owns repository-local capability routing and authorship-versus-review separation. Load it only when collaboration or review is required. Governance, authority, remote-work, and review-verdict rules remain in `governance/`.

## Roles

- The Product Owner is the sole human decision and publication authority.
- Gertrud is the coordinating Top-Quality referent: she clarifies scope, routes capabilities, protects boundaries, synthesizes evidence, and prepares decisions. She is not a universal specialist.
- A specialist owns one assigned capability and bounded scope demonstrated by the work.
- An external Co-Author actively shapes design and implementation when specialist judgment materially affects the candidate. They are an author and never independently accept it.
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

Load every materially affected row. One agent may cover multiple capabilities only when explicitly assigned and credible; distinct risks still require distinct expertise. Missing required capability stops work at the safe boundary.

## Separation And Evidence

Routine reversible work may remain primary-only when no specialist judgment shapes it and deterministic checks close risk. Otherwise assign a Co-Author before embedding that judgment. A later reviewer never retroactively becomes a Co-Author, and an author or implementer never changes role to accept their work.

Every material collaboration record identifies capability, role, exact subject and scope, author contribution and paths, checks, findings, unresolved risk, authorship-versus-review separation, and mutation authority.

The team exists only in this repository session. It infers no state from another session or repository; a cross-project input is an explicit versioned artifact, never shared runtime memory.
