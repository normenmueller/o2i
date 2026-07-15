module ValidationRecordUpdates where

import qualified O2I.Validation as Validation

rewriteStrategyFormulation ::
     Validation.StrategyFormulation -> Validation.StrategyFormulation
rewriteStrategyFormulation formulation =
  formulation
    { Validation.strategyFormulationData =
        Validation.strategyFormulationData formulation
    }

rewriteSemanticallyValidModel ::
     Validation.SemanticallyValidModel -> Validation.SemanticallyValidModel
rewriteSemanticallyValidModel model =
  model
    {Validation.strategyFormulations = Validation.strategyFormulations model}

rewriteEffectTrace :: Validation.EffectTrace -> Validation.EffectTrace
rewriteEffectTrace trace =
  trace {Validation.traceIdentifier = Validation.traceIdentifier trace}

rewriteTraceableEffectModel ::
     Validation.TraceableEffectModel -> Validation.TraceableEffectModel
rewriteTraceableEffectModel model =
  model {Validation.effectTraces = Validation.effectTraces model}

rewriteSituationAnchorRef ::
     Validation.SomeSituationAnchorRef -> Validation.SomeSituationAnchorRef
rewriteSituationAnchorRef reference =
  reference
    { Validation.situationAnchorRefId =
        Validation.situationAnchorRefId reference
    }

rewriteKPI :: Validation.KPIDefinition -> Validation.KPIDefinition
rewriteKPI definition =
  definition
    {Validation.kpiDefinitionKPI = Validation.kpiDefinitionKPI definition}

rewriteUnit :: Validation.KPIDefinition -> Validation.KPIDefinition
rewriteUnit definition =
  definition
    {Validation.kpiDefinitionUnit = Validation.kpiDefinitionUnit definition}

rewriteDomain :: Validation.KPIDefinition -> Validation.KPIDefinition
rewriteDomain definition =
  definition
    {Validation.kpiDefinitionDomain = Validation.kpiDefinitionDomain definition}

rewriteMeasurementMethod :: Validation.KPIDefinition -> Validation.KPIDefinition
rewriteMeasurementMethod definition =
  definition
    { Validation.kpiDefinitionMeasurementMethod =
        Validation.kpiDefinitionMeasurementMethod definition
    }

rewriteInterpretation :: Validation.KPIDefinition -> Validation.KPIDefinition
rewriteInterpretation definition =
  definition
    { Validation.kpiDefinitionInterpretation =
        Validation.kpiDefinitionInterpretation definition
    }

rewriteEvidenceReadyModel ::
     Validation.EvidenceReadyModel -> Validation.EvidenceReadyModel
rewriteEvidenceReadyModel model =
  model {Validation.kpiDefinitions = Validation.kpiDefinitions model}

rewriteEffectAssessment ::
     Validation.EffectAssessment -> Validation.EffectAssessment
rewriteEffectAssessment assessment =
  assessment
    {Validation.assessedFollowUp = Validation.assessedFollowUp assessment}

rewriteEvidenceAssessedModel ::
     Validation.EvidenceAssessedModel -> Validation.EvidenceAssessedModel
rewriteEvidenceAssessedModel model =
  model {Validation.effectAssessments = Validation.effectAssessments model}
