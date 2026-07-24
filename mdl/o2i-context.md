# O2I Semantics - Context

> Generated review snapshot of `O2I Semantics - Context` from `mdl/o2i.archimate`.
> Review artifact only; source of truth remains the O2I metamodel.

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
