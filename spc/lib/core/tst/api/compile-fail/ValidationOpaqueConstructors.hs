module ValidationOpaqueConstructors where

import qualified O2I.Validation as Validation

forgedStructuralAssessment :: Validation.StructuralAssessment
forgedStructuralAssessment = Validation.StructuralAssessment undefined undefined

forgedModelAssessment :: Validation.ModelAssessment
forgedModelAssessment =
  Validation.ModelAssessment undefined undefined undefined undefined undefined

forgedNeedQualificationCandidate :: Validation.NeedQualificationCandidate
forgedNeedQualificationCandidate =
  Validation.NeedQualificationCandidate
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined

forgedSemanticallyValidModel :: Validation.SemanticallyValidModel
forgedSemanticallyValidModel =
  Validation.SemanticallyValidModel undefined undefined

forgedEffectTrace :: Validation.EffectTrace
forgedEffectTrace =
  Validation.EffectTrace
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined

forgedEffectTraceId :: Validation.EffectTraceId
forgedEffectTraceId = Validation.EffectTraceId undefined

forgedSituationAnchorRef :: Validation.SomeSituationAnchorRef
forgedSituationAnchorRef = Validation.SomeSituationAnchorRef undefined undefined

forgedTraceableEffectModel :: Validation.TraceableEffectModel
forgedTraceableEffectModel =
  Validation.TraceableEffectModel undefined undefined undefined

forgedMacroEvidenceWitness :: Validation.MacroEvidenceWitness
forgedMacroEvidenceWitness = Validation.MacroEvidenceWitness undefined

forgedKPIDefinition :: Validation.KPIDefinition
forgedKPIDefinition =
  Validation.KPIDefinition undefined undefined undefined undefined undefined

forgedEvidenceReadyModel :: Validation.EvidenceReadyModel
forgedEvidenceReadyModel =
  Validation.EvidenceReadyModel
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined

forgedEffectAssessment :: Validation.EffectAssessment
forgedEffectAssessment =
  Validation.EffectAssessment undefined undefined undefined

forgedEvidenceAssessedModel :: Validation.EvidenceAssessedModel
forgedEvidenceAssessedModel =
  Validation.EvidenceAssessedModel undefined undefined undefined undefined
