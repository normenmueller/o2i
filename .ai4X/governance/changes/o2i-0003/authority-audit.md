# O2I-0003 Authority Audit

## Target Authority

| Statement class | Authority | Dependent representations |
| --- | --- | --- |
| Fachliche meaning and metamodel semantics | `o2i.md` | semantic Views, WTF, Haddock |
| Exact ArchiMate profile mapping | `spc/contract/archimate-profile.json` | White Paper projection, syntax Views, AMX registry |
| Notation-independent formalization | `spc/lib/core/` | Inspection, adapters, CLI |
| AMX profile execution | `spc/lib/adapter/amx/` | inspection reports |
| Reference visualization | `mdl/o2i.archimate` | snapshots and PNG exports |

## Closed Mapping Scope

- one model-root profile contract;
- 14 carrier mappings: Context family, six Primitives, one structuring type,
  and six SituationAnchor types;
- 60 context-sensitive relation mappings: 34 fixed relations, two
  PerformanceDimension memberships, and four anchor families for six anchor
  types;
- contextualization as one non-semantic ownership pattern;
- collective Strategy realization as one structured proposition pattern.

## Fachliche Content To Preserve

- O2I typing follows metadata and graph structure, never display labels.
- Mapping exemplars are not executable O2I propositions.
- Relation, contextualized endpoints, direction, and ArchiMate relationship
  type jointly determine a relation representation.
- Interpretation and role registries have distinct responsibilities.
- ArchiMate Grouping and Junction carriers introduce no O2I semantics.
- Outcome, Assessment, and PerformanceDimension retain their published O2I
  readings.
- A collective proposition is carried by its Junction; its segments carry no
  independent Commitment.
- Visual nesting presents but never replaces explicit contextualization.

## Observed Drift

- The White Paper uses `o2i.kind = Claim`; the profile and model use
  `o2i.kind = StructuredProposition`.
- Context macrorelations are admitted as directed ArchiMate Associations, while
  the AMX registry currently maps them to ArchiMate Influence relationships.
- Agent Memory and operation contracts still name `O2I Syntax` or the model as
  the concrete-mapping authority.
- The extractor still hard-codes mapping facts and former focused-View names.
- `O2I Syntax - Situation` remains incomplete.

## Reduction Gate

No ArchiMate View or element documentation is reduced until:

1. every exact mapping fact exists in the declarative contract;
2. every unique fachliche statement exists in the White Paper;
3. contract-to-publication, contract-to-View, and contract-to-AMX checks pass.
