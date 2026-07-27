# O2I Semantics - Context

> Generated review snapshot of `O2I Semantics - Context` from `mdl/o2i.archimate`.
> Review artifact only; semantic authority remains the O2I metamodel.

## View Contract

Visualizes the closed O2I Context type and its admissible macrorelation families.

This View is a checked semantic projection of the metamodel defined in o2i.md; it contains neither concrete Context instances nor an ArchiMate syntax contract.

## Nodes

- [Ethos] `Ethos` (Grouping)
- [Intervention] `Intervention` (Grouping)
- [Measure] `Measure` (Grouping)
- [Mission] `Mission` (Grouping)
- [Need] `Need` (Grouping)
- [Situation] `Situation` (Grouping)
- [Strategy] `Strategy` (Grouping)
- [Vision] `Vision` (Grouping)

## Relations

- `Ethos` --guides--> `Mission` (InfluenceRelationship)
- `Ethos` --guides--> `Vision` (InfluenceRelationship)
- `Intervention` --addresses--> `Need` (InfluenceRelationship)
- `Intervention` --changes--> `Situation` (InfluenceRelationship)
- `Intervention` --sets-target-for--> `Measure` (InfluenceRelationship)
- `Measure` --measures--> `Situation` (InfluenceRelationship)
- `Mission` --grounds--> `Vision` (InfluenceRelationship)
- `Situation` --surfaces--> `Need` (InfluenceRelationship)
- `Strategy` --contributes-to--> `Strategy` (InfluenceRelationship)
- `Strategy` --directs--> `Intervention` (InfluenceRelationship)
- `Strategy` --directs--> `Strategy` (InfluenceRelationship)
- `Strategy` --frames--> `Measure` (InfluenceRelationship)
- `Strategy` --qualifies--> `Need` (InfluenceRelationship)
- `Vision` --orients--> `Strategy` (InfluenceRelationship)
