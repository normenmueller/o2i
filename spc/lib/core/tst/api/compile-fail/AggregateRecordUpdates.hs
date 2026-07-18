{-# LANGUAGE DataKinds #-}

module AggregateRecordUpdates where

import qualified O2I

rewriteNodeId :: O2I.NodeId kind -> O2I.NodeId kind
rewriteNodeId identifier = identifier {O2I.unNodeId = O2I.unNodeId identifier}

rewriteContextRef :: O2I.ContextRef context -> O2I.ContextRef context
rewriteContextRef reference =
  reference {O2I.contextRefId = O2I.contextRefId reference}

rewriteSomeNode :: O2I.SomeNode -> O2I.SomeNode
rewriteSomeNode node = node {O2I.someNodeId = O2I.someNodeId node}

rewriteSomeEdge :: O2I.SomeEdge -> O2I.SomeEdge
rewriteSomeEdge edge = edge {O2I.someEdgeFrom = O2I.someEdgeFrom edge}

rewriteWellFormedGraph :: O2I.WellFormedGraph -> O2I.WellFormedGraph
rewriteWellFormedGraph graph = graph {O2I.graphNodes = O2I.graphNodes graph}

rewriteStrategyFormulation :: O2I.StrategyFormulation -> O2I.StrategyFormulation
rewriteStrategyFormulation formulation =
  formulation
    {O2I.strategyFormulationData = O2I.strategyFormulationData formulation}

rewriteNeedQualificationCandidate ::
     O2I.NeedQualificationCandidate -> O2I.NeedQualificationCandidate
rewriteNeedQualificationCandidate candidate =
  candidate
    { O2I.needQualificationCandidateStrategy =
        O2I.needQualificationCandidateStrategy candidate
    , O2I.needQualificationCandidateNeed =
        O2I.needQualificationCandidateNeed candidate
    , O2I.needQualificationCandidateKeyResult =
        O2I.needQualificationCandidateKeyResult candidate
    , O2I.needQualificationCandidateObjective =
        O2I.needQualificationCandidateObjective candidate
    , O2I.needQualificationCandidateRationale =
        O2I.needQualificationCandidateRationale candidate
    , O2I.needQualificationCandidateSourceReference =
        O2I.needQualificationCandidateSourceReference candidate
    }

rewriteNeedQualificationSourceReference ::
     O2I.NeedQualificationSourceReference
  -> O2I.NeedQualificationSourceReference
rewriteNeedQualificationSourceReference reference =
  reference
    { O2I.needQualificationSourceReferenceText =
        O2I.needQualificationSourceReferenceText reference
    }

rewriteSemanticallyValidModel ::
     O2I.SemanticallyValidModel -> O2I.SemanticallyValidModel
rewriteSemanticallyValidModel model =
  model {O2I.strategyFormulations = O2I.strategyFormulations model}

rewriteEffectTrace :: O2I.EffectTrace -> O2I.EffectTrace
rewriteEffectTrace trace =
  trace {O2I.traceIdentifier = O2I.traceIdentifier trace}

rewriteTraceableEffectModel ::
     O2I.TraceableEffectModel -> O2I.TraceableEffectModel
rewriteTraceableEffectModel model =
  model {O2I.effectTraces = O2I.effectTraces model}

rewriteSituationAnchorRef ::
     O2I.SomeSituationAnchorRef -> O2I.SomeSituationAnchorRef
rewriteSituationAnchorRef reference =
  reference {O2I.situationAnchorRefId = O2I.situationAnchorRefId reference}

rewriteKPI :: O2I.KPIDefinition -> O2I.KPIDefinition
rewriteKPI definition =
  definition {O2I.kpiDefinitionKPI = O2I.kpiDefinitionKPI definition}

rewriteUnit :: O2I.KPIDefinition -> O2I.KPIDefinition
rewriteUnit definition =
  definition {O2I.kpiDefinitionUnit = O2I.kpiDefinitionUnit definition}

rewriteDomain :: O2I.KPIDefinition -> O2I.KPIDefinition
rewriteDomain definition =
  definition {O2I.kpiDefinitionDomain = O2I.kpiDefinitionDomain definition}

rewriteMeasurementMethod :: O2I.KPIDefinition -> O2I.KPIDefinition
rewriteMeasurementMethod definition =
  definition
    { O2I.kpiDefinitionMeasurementMethod =
        O2I.kpiDefinitionMeasurementMethod definition
    }

rewriteInterpretation :: O2I.KPIDefinition -> O2I.KPIDefinition
rewriteInterpretation definition =
  definition
    { O2I.kpiDefinitionInterpretation =
        O2I.kpiDefinitionInterpretation definition
    }

rewriteEvidenceReadyModel :: O2I.EvidenceReadyModel -> O2I.EvidenceReadyModel
rewriteEvidenceReadyModel model =
  model {O2I.kpiDefinitions = O2I.kpiDefinitions model}

rewriteEffectAssessment :: O2I.EffectAssessment -> O2I.EffectAssessment
rewriteEffectAssessment assessment =
  assessment {O2I.assessedFollowUp = O2I.assessedFollowUp assessment}

rewriteEvidenceAssessedModel ::
     O2I.EvidenceAssessedModel -> O2I.EvidenceAssessedModel
rewriteEvidenceAssessedModel model =
  model {O2I.effectAssessments = O2I.effectAssessments model}
