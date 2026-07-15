# O2I Strategy Constituents

> Generated review snapshot of `O2I Strategy Constituents` from `mdl/o2i.archimate`.
> Review artifact only; source of truth remains the O2I metamodel.

## Nodes

- [Strategy#Anchoring] `Strategy#Anchoring` (Grouping)
- [Strategy#Coherent Action Commitments] `Strategy#Coherent Action Commitments` (Grouping)
- [Strategy#Derived Guardrails] `Strategy#Derived Guardrails` (Grouping)
- [Strategy#Diagnosis] `Strategy#Diagnosis` (Grouping)
- [Strategy#Fit] `Strategy#Fit` (Grouping)
- [Strategy#Guiding Policy] `Strategy#Guiding Policy` (Grouping)
- [Strategy#Intent] `Strategy#Intent` (Grouping)
- [Strategy#Positioning] `Strategy#Positioning` (Grouping)
- [Strategy#Scope] `Strategy#Scope` (Grouping)
- [Strategy#Success Reference] `Strategy#Success Reference` (Grouping)
- [Strategy#Trade-offs] `Strategy#Trade-offs` (Grouping)

## Relations

- `Strategy#Anchoring` --enables--> `Strategy#Coherent Action Commitments` (InfluenceRelationship)
- `Strategy#Coherent Action Commitments` --contributes-to--> `Strategy#Success Reference` (InfluenceRelationship)
- `Strategy#Derived Guardrails` --constrain--> `Strategy#Guiding Policy` (InfluenceRelationship)
- `Strategy#Diagnosis` --justifies--> `Strategy#Guiding Policy` (InfluenceRelationship)
- `Strategy#Diagnosis` --justifies--> `Strategy#Intent` (InfluenceRelationship)
- `Strategy#Fit` --validates--> `Strategy#Coherent Action Commitments` (InfluenceRelationship)
- `Strategy#Fit` --validates--> `Strategy#Positioning` (InfluenceRelationship)
- `Strategy#Fit` --validates--> `Strategy#Success Reference` (InfluenceRelationship)
- `Strategy#Fit` --validates--> `Strategy#Trade-offs` (InfluenceRelationship)
- `Strategy#Guiding Policy` --guides--> `Strategy#Coherent Action Commitments` (InfluenceRelationship)
- `Strategy#Guiding Policy` --guides--> `Strategy#Positioning` (InfluenceRelationship)
- `Strategy#Intent` --orients--> `Strategy#Guiding Policy` (InfluenceRelationship)
- `Strategy#Positioning` --orients--> `Strategy#Coherent Action Commitments` (InfluenceRelationship)
- `Strategy#Positioning` --requires--> `Strategy#Trade-offs` (InfluenceRelationship)
- `Strategy#Scope` --frames--> `Strategy#Diagnosis` (InfluenceRelationship)
- `Strategy#Success Reference` --substantiates--> `Strategy#Intent` (InfluenceRelationship)
- `Strategy#Trade-offs` --constrain--> `Strategy#Coherent Action Commitments` (InfluenceRelationship)
