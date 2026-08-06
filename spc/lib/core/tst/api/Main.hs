{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

-- | External-client contracts for canonical and validated O2I values.
module Main
  ( main
  ) where

import ApiContractTH (assertAbstractTypes, assertOrdinaryFunctions)
import Control.Monad (unless)
import qualified Data.List.NonEmpty as NonEmpty
import O2I
import qualified O2I.Graph as Graph
import O2I.Language
import qualified O2I.Language as Language
import qualified O2I.Validation as Validation

$(assertAbstractTypes
    [ "Language.Claim"
    , "Language.NodeId"
    , "Language.ContextRef"
    , "Language.InterpretationSpec"
    , "Language.SomeInterpretation"
    , "Language.Relation"
    , "Language.SomeRelation"
    , "Language.RelationSpec"
    , "Language.MacroClaim"
    , "Language.MacroEvidenceRule"
    ])

$(assertOrdinaryFunctions
    [ 'Language.claimWithCommitment
    , 'Language.candidateClaim
    , 'Language.assertedClaim
    , 'Language.claimCommitment
    , 'Language.claimedProposition
    , 'Language.unNodeId
    , 'Language.contextRefId
    , 'Language.interpretationCode
    , 'Language.interpretationContext
    , 'Language.interpretationPrimitive
    , 'Language.interpretationWitness
    , 'Language.relationCode
    , 'Language.relationSemantics
    , 'Language.relationName
    , 'Language.relationLabel
    , 'Language.relationFrom
    , 'Language.relationTo
    , 'Language.relationCodeOf
    , 'Language.relationSemanticsOf
    , 'Language.relationNameOf
    , 'Language.relationNameFor
    , 'Language.anchorRelationFamilyName
    , 'Language.relationIdentity
    , 'Language.reifyRelation
    , 'Language.macroEvidenceRuleConclusion
    , 'Language.macroClaimConclusion
    ])

$(assertAbstractTypes
    [ "Graph.MacroFactIndex"
    , "Graph.MacroDependency"
    , "Graph.SomeNode"
    , "Graph.SomeEdge"
    , "Graph.WellFormedGraph"
    ])

$(assertOrdinaryFunctions
    [ 'Graph.buildMacroFactIndex
    , 'Graph.macroClaims
    , 'Graph.macroClaimsFor
    , 'Graph.macroDependencyEdge
    , 'Graph.macroScopeDependencies
    , 'Graph.graphNodes
    , 'Graph.graphEdges
    , 'Graph.someNodeId
    , 'Graph.someNodeKind
    , 'Graph.someNodeOwner
    , 'Graph.someEdgeFrom
    , 'Graph.someEdgeRelation
    , 'Graph.someEdgeTo
    , 'Graph.constitutingAnchorNodes
    ])

$(assertAbstractTypes
    [ "Validation.StructuralAssessment"
    , "Validation.ModelAssessment"
    , "Validation.StrategyFormulation"
    , "Validation.CollectiveStrategyRealization"
    , "Validation.CandidateCollectiveStrategyRealization"
    , "Validation.ValidatedCollectiveStrategyRealizations"
    , "Validation.ValidatedContributionGraph"
    , "Validation.CollectiveStrategyContribution"
    , "Validation.CandidateCollectiveStrategyContribution"
    , "Validation.ValidatedCollectiveStrategyContributions"
    , "Validation.NeedQualificationSourceReference"
    , "Validation.NeedQualificationCandidate"
    , "Validation.SemanticallyValidModel"
    , "Validation.EffectTrace"
    , "Validation.EffectTraceId"
    , "Validation.SomeSituationAnchorRef"
    , "Validation.TraceableEffectModel"
    , "Validation.MacroEvidenceWitness"
    , "Validation.KPIDefinition"
    , "Validation.EvidenceReadyModel"
    , "Validation.EffectAssessment"
    , "Validation.EvidenceAssessedModel"
    ])

$(assertOrdinaryFunctions
    [ 'Validation.assessModelSemantics
    , 'Validation.modelAssessmentStatus
    , 'Validation.structuralGraph
    , 'Validation.structuralCandidatePropositions
    , 'Validation.assessedSemanticModel
    , 'Validation.assessmentInvariantErrors
    , 'Validation.assessmentCollectiveErrors
    , 'Validation.assessmentCollectiveRegistryPreparationWork
    , 'Validation.assessmentCandidatePropositions
    , 'Validation.assessmentCandidateCollectiveStrategyRealizations
    , 'Validation.assessmentValidatedCollectiveStrategyRealizations
    , 'Validation.assessmentCandidateCollectiveStrategyContributions
    , 'Validation.assessmentValidatedCollectiveStrategyContributions
    , 'Validation.assessmentCollectiveContributionPreparationWork
    , 'Validation.assessmentCollectiveContributionWork
    , 'Validation.contextElaboration
    , 'Validation.modelMaturity
    , 'Validation.collectiveStrategyRealizations
    , 'Validation.lookupCollectiveStrategyRealization
    , 'Validation.collectiveRealizationsForTarget
    , 'Validation.collectiveRealizationId
    , 'Validation.collectiveContributors
    , 'Validation.collectiveTarget
    , 'Validation.collectiveFitEvidenceReference
    , 'Validation.collectiveContributionEvidence
    , 'Validation.candidateCollectiveClaim
    , 'Validation.candidateCollectiveIssues
    , 'Validation.collectiveStrategyContributions
    , 'Validation.collectiveContributionId
    , 'Validation.collectiveContributionParticipants
    , 'Validation.collectiveContributionTarget
    , 'Validation.collectiveContributionEvidenceReference
    , 'Validation.collectiveContributionRationales
    , 'Validation.collectiveContributionPrimitiveGraph
    , 'Validation.contributionGraphMode
    , 'Validation.contributionGraphNodes
    , 'Validation.contributionGraphOccurrences
    , 'Validation.contributionGraphRationaleReference
    , 'Validation.contributionGraphProvenance
    , 'Validation.candidateCollectiveContributionClaim
    , 'Validation.candidateCollectiveContributionIssues
    , 'Validation.validatedCollectiveStrategyRealizations
    , 'Validation.macroEvidenceWitnesses
    , 'Validation.witnessPremises
    , 'Validation.strategyFormulations
    , 'Validation.strategyFormulationData
    , 'Validation.needQualificationCandidateStrategy
    , 'Validation.needQualificationCandidateNeed
    , 'Validation.needQualificationCandidateKeyResult
    , 'Validation.needQualificationCandidateObjective
    , 'Validation.needQualificationCandidateRationale
    , 'Validation.needQualificationCandidateSourceReference
    , 'Validation.needQualificationSourceReferenceText
    , 'Validation.effectTraces
    , 'Validation.traceIdentifier
    , 'Validation.effectTraceIdText
    , 'Validation.traceVision
    , 'Validation.traceVisionObjective
    , 'Validation.traceStrategy
    , 'Validation.traceStrategyDriver
    , 'Validation.traceStrategyObjective
    , 'Validation.traceStrategyKeyResult
    , 'Validation.traceStrategyAction
    , 'Validation.traceNeed
    , 'Validation.traceNeedDriver
    , 'Validation.traceNeedObjective
    , 'Validation.traceIntervention
    , 'Validation.traceInterventionAction
    , 'Validation.traceInterventionKeyResult
    , 'Validation.traceMeasure
    , 'Validation.traceMeasurePerformanceDimension
    , 'Validation.traceKPI
    , 'Validation.traceSituation
    , 'Validation.traceSituationAnchor
    , 'Validation.situationAnchorRefId
    , 'Validation.situationAnchorRefKind
    , 'Validation.kpiDefinitionKPI
    , 'Validation.kpiDefinitionUnit
    , 'Validation.kpiDefinitionDomain
    , 'Validation.kpiDefinitionMeasurementMethod
    , 'Validation.kpiDefinitionInterpretation
    , 'Validation.kpiDefinitions
    , 'Validation.evidencePlans
    , 'Validation.readinessCheckedAt
    , 'Validation.plannedInterventionStarts
    , 'Validation.readyEffectTraces
    , 'Validation.readyInterventions
    , 'Validation.readyTracesForIntervention
    , 'Validation.assessedFollowUp
    , 'Validation.effectResult
    , 'Validation.targetResult
    , 'Validation.evidenceAssessedAt
    , 'Validation.actualInterventionStarts
    , 'Validation.effectAssessments
    ])

$(assertAbstractTypes
    [ "O2I.Claim"
    , "O2I.ModelAssessment"
    , "O2I.NodeId"
    , "O2I.ContextRef"
    , "O2I.SomeInterpretation"
    , "O2I.Relation"
    , "O2I.SomeRelation"
    , "O2I.MacroClaim"
    , "O2I.MacroEvidenceRule"
    , "O2I.MacroFactIndex"
    , "O2I.MacroDependency"
    , "O2I.SomeNode"
    , "O2I.SomeEdge"
    , "O2I.WellFormedGraph"
    , "O2I.StructuralAssessment"
    , "O2I.StrategyFormulation"
    , "O2I.CollectiveStrategyRealization"
    , "O2I.CandidateCollectiveStrategyRealization"
    , "O2I.ValidatedCollectiveStrategyRealizations"
    , "O2I.ValidatedContributionGraph"
    , "O2I.CollectiveStrategyContribution"
    , "O2I.CandidateCollectiveStrategyContribution"
    , "O2I.ValidatedCollectiveStrategyContributions"
    , "O2I.NeedQualificationSourceReference"
    , "O2I.NeedQualificationCandidate"
    , "O2I.SemanticallyValidModel"
    , "O2I.EffectTrace"
    , "O2I.EffectTraceId"
    , "O2I.SomeSituationAnchorRef"
    , "O2I.TraceableEffectModel"
    , "O2I.MacroEvidenceWitness"
    , "O2I.KPIDefinition"
    , "O2I.EvidenceReadyModel"
    , "O2I.EffectAssessment"
    , "O2I.EvidenceAssessedModel"
    ])

$(assertOrdinaryFunctions
    [ 'O2I.claimWithCommitment
    , 'O2I.candidateClaim
    , 'O2I.assertedClaim
    , 'O2I.claimCommitment
    , 'O2I.claimedProposition
    , 'O2I.assessedSemanticModel
    , 'O2I.modelAssessmentStatus
    , 'O2I.assessmentInvariantErrors
    , 'O2I.assessmentCollectiveErrors
    , 'O2I.assessmentCollectiveRegistryPreparationWork
    , 'O2I.assessmentCandidatePropositions
    , 'O2I.assessmentCandidateCollectiveStrategyRealizations
    , 'O2I.assessmentValidatedCollectiveStrategyRealizations
    , 'O2I.assessmentCandidateCollectiveStrategyContributions
    , 'O2I.assessmentValidatedCollectiveStrategyContributions
    , 'O2I.assessmentCollectiveContributionPreparationWork
    , 'O2I.assessmentCollectiveContributionWork
    , 'O2I.contextElaboration
    , 'O2I.modelMaturity
    , 'O2I.collectiveStrategyRealizations
    , 'O2I.validatedCollectiveStrategyRealizations
    , 'O2I.lookupCollectiveStrategyRealization
    , 'O2I.collectiveRealizationsForTarget
    , 'O2I.collectiveRealizationId
    , 'O2I.collectiveContributors
    , 'O2I.collectiveTarget
    , 'O2I.collectiveFitEvidenceReference
    , 'O2I.collectiveContributionEvidence
    , 'O2I.candidateCollectiveClaim
    , 'O2I.candidateCollectiveIssues
    , 'O2I.collectiveStrategyContributions
    , 'O2I.collectiveContributionId
    , 'O2I.collectiveContributionParticipants
    , 'O2I.collectiveContributionTarget
    , 'O2I.collectiveContributionEvidenceReference
    , 'O2I.collectiveContributionRationales
    , 'O2I.collectiveContributionPrimitiveGraph
    , 'O2I.contributionGraphMode
    , 'O2I.contributionGraphNodes
    , 'O2I.contributionGraphOccurrences
    , 'O2I.contributionGraphRationaleReference
    , 'O2I.contributionGraphProvenance
    , 'O2I.candidateCollectiveContributionClaim
    , 'O2I.candidateCollectiveContributionIssues
    , 'O2I.assessModelSemantics
    , 'O2I.structuralGraph
    , 'O2I.structuralCandidatePropositions
    , 'O2I.macroEvidenceRuleConclusion
    , 'O2I.macroClaimConclusion
    , 'O2I.buildMacroFactIndex
    , 'O2I.macroClaims
    , 'O2I.macroDependencyEdge
    , 'O2I.macroScopeDependencies
    , 'O2I.macroEvidenceWitnesses
    , 'O2I.witnessPremises
    , 'O2I.unNodeId
    , 'O2I.contextRefId
    , 'O2I.interpretationCodeOf
    , 'O2I.interpretationIdentity
    , 'O2I.relationNameFor
    , 'O2I.relationNameOf
    , 'O2I.anchorRelationFamilyName
    , 'O2I.relationCodeOf
    , 'O2I.relationIdentity
    , 'O2I.graphNodes
    , 'O2I.graphEdges
    , 'O2I.someNodeId
    , 'O2I.someNodeKind
    , 'O2I.someNodeOwner
    , 'O2I.someEdgeFrom
    , 'O2I.someEdgeRelation
    , 'O2I.someEdgeTo
    , 'O2I.constitutingAnchorNodes
    , 'O2I.strategyFormulations
    , 'O2I.strategyFormulationData
    , 'O2I.effectTraceIdText
    , 'O2I.needQualificationCandidateStrategy
    , 'O2I.needQualificationCandidateNeed
    , 'O2I.needQualificationCandidateKeyResult
    , 'O2I.needQualificationCandidateObjective
    , 'O2I.needQualificationCandidateRationale
    , 'O2I.needQualificationCandidateSourceReference
    , 'O2I.needQualificationSourceReferenceText
    , 'O2I.effectTraces
    , 'O2I.traceIdentifier
    , 'O2I.traceVision
    , 'O2I.traceVisionObjective
    , 'O2I.traceStrategy
    , 'O2I.traceStrategyDriver
    , 'O2I.traceStrategyObjective
    , 'O2I.traceStrategyKeyResult
    , 'O2I.traceStrategyAction
    , 'O2I.traceNeed
    , 'O2I.traceNeedDriver
    , 'O2I.traceNeedObjective
    , 'O2I.traceIntervention
    , 'O2I.traceInterventionAction
    , 'O2I.traceInterventionKeyResult
    , 'O2I.traceMeasure
    , 'O2I.traceMeasurePerformanceDimension
    , 'O2I.traceKPI
    , 'O2I.traceSituation
    , 'O2I.traceSituationAnchor
    , 'O2I.situationAnchorRefId
    , 'O2I.situationAnchorRefKind
    , 'O2I.kpiDefinitionKPI
    , 'O2I.kpiDefinitionUnit
    , 'O2I.kpiDefinitionDomain
    , 'O2I.kpiDefinitionMeasurementMethod
    , 'O2I.kpiDefinitionInterpretation
    , 'O2I.kpiDefinitions
    , 'O2I.evidencePlans
    , 'O2I.readinessCheckedAt
    , 'O2I.plannedInterventionStarts
    , 'O2I.readyEffectTraces
    , 'O2I.readyInterventions
    , 'O2I.readyTracesForIntervention
    , 'O2I.assessedFollowUp
    , 'O2I.effectResult
    , 'O2I.targetResult
    , 'O2I.evidenceAssessedAt
    , 'O2I.actualInterventionStarts
    , 'O2I.effectAssessments
    ])

-- | Run positive external-client API use.
main :: IO ()
main = do
  let compatibilityEvidence =
        RawContributorCompatibilityEvidence
          strategyId
          "compatible with the target Guiding Policy"
          "compatible with the target Trade-offs"
  assert
    "raw collective compatibility evidence is contributor-bound"
    (rawCompatibilityContributor compatibilityEvidence == strategyId
       && rawGuidingPolicyCompatibilityRationale compatibilityEvidence
            == "compatible with the target Guiding Policy"
       && rawTradeOffCompatibilityRationale compatibilityEvidence
            == "compatible with the target Trade-offs")
  let spec = interpretationSpec PrincipleInEthos
  assert
    "interpretation code projection"
    (interpretationCode spec == PrincipleInEthosCode)
  assert
    "interpretation Context projection"
    (contextValue (interpretationContext spec) == Ethos)
  assert
    "interpretation Primitive projection"
    (primitiveValue (interpretationPrimitive spec) == Principle)
  case interpretationWitness spec of
    PrincipleInEthos -> pure ()
  assert
    "complete interpretation registry"
    (map interpretationCodeOf allInterpretations == [minBound .. maxBound])
  case lookupInterpretation Ethos Principle of
    Just interpretation ->
      assert
        "interpretation lookup identity"
        (interpretationIdentity interpretation == (Ethos, Principle))
    Nothing -> fail "canonical interpretation was not found"
  let relationMetadata = Language.relationSpec Language.orientsStrategy
  assert
    "canonical relation metadata projection"
    (Language.relationCode relationMetadata == FixedRelation OrientsStrategyCode
       && Language.relationName relationMetadata
            == RelationName "vision-orients-strategy")
  assert
    "complete relation registry"
    (map Language.relationCodeOf Language.allRelations
       == Language.allRelationCodes)
  assert
    "closed SituationAnchor set"
    (([minBound .. maxBound] :: [SituationAnchor])
       == [BusinessCapability, BusinessProcess, BusinessObject, ValueStream])
  assert
    "closed anchor relation-family names"
    (map
       Language.anchorRelationFamilyName
       ([minBound .. maxBound] :: [AnchorRelationFamily])
       == [ RelationName "situation-is-constituted-by-anchor"
          , RelationName "situation-anchor-anchors-need-driver"
          , RelationName "intervention-action-changes-situation-anchor"
          , RelationName "measure-kpi-measures-situation-anchor"
          ])
  assert
    "relation reification roundtrip"
    (map
       (Language.relationCodeOf . Language.reifyRelation)
       Language.allRelationCodes
       == Language.allRelationCodes)
  case Language.lookupRelations (RelationName "vision-orients-strategy") of
    [relation] ->
      assert
        "relation lookup projections"
        (Language.relationCodeOf relation == FixedRelation OrientsStrategyCode
           && Language.relationNameOf relation
                == RelationName "vision-orients-strategy"
           && Language.relationIdentity relation
                == ( RelationName "vision-orients-strategy"
                   , ContextNodeKind Vision
                   , ContextNodeKind Strategy))
    _ -> fail "canonical relation was not uniquely found"
  case validatedValues of
    Left message -> fail message
    Right (ValidatedValues graph semantic traceable ready assessed trace definition assessment) -> do
      assert
        "Graph facade exposes validated nodes"
        (visionId `elem` map Graph.someNodeId (Graph.graphNodes graph))
      assert
        "Graph facade exposes validated edges"
        (not (null (Graph.graphEdges graph)))
      case Graph.lookupNode graph situationAnchorId of
        Just anchor ->
          assert
            "Situation anchors expose no Context owner"
            (Graph.someNodeOwner anchor == Nothing)
        Nothing -> fail "validated Situation anchor was not found"
      assert
        "Graph facade resolves Situation constitution relationally"
        (Graph.constitutingAnchorNodes graph situationId == [situationAnchorId])
      assert
        "aggregate facade resolves Situation constitution relationally"
        (O2I.constitutingAnchorNodes graph situationId == [situationAnchorId])
      case foldr (:) [] (Validation.strategyFormulations semantic) of
        [formulation] ->
          assert
            "validated StrategyFormulation projection"
            (rawFormulationStrategy
               (Validation.strategyFormulationData formulation)
               == strategyId)
        _ -> fail "expected one validated Strategy formulation"
      assert
        "validated traceable-model projection"
        (NonEmpty.head (Validation.effectTraces traceable) == trace)
      assert
        "validated readiness projections"
        (definition `elem` Validation.kpiDefinitions ready
           && NonEmpty.head (Validation.readyEffectTraces ready) == trace)
      assert
        "validated assessed-model projection"
        (assessment
           `elem` NonEmpty.toList (Validation.effectAssessments assessed))
      assert
        "Language NodeId projection"
        (Language.unNodeId (traceKPI trace) == measureKPIId)
      assert
        "aggregate NodeId projection"
        (O2I.unNodeId (traceKPI trace) == measureKPIId)
      assert
        "Language ContextRef projection"
        (Language.contextRefId (traceIntervention trace) == interventionId)
      assert
        "aggregate ContextRef projection"
        (O2I.contextRefId (traceIntervention trace) == interventionId)
      assert
        "validated KPI definition projections"
        (Validation.kpiDefinitionKPI definition == traceKPI trace
           && Validation.kpiDefinitionUnit definition == PercentagePoints
           && Validation.kpiDefinitionDomain definition
                == BoundedDomain (Level 0) (Level 100)
           && Validation.kpiDefinitionMeasurementMethod definition
                == "controlled measurement"
           && Validation.kpiDefinitionInterpretation definition
                == "higher is better")
      assert
        "validation and aggregate KPI projections agree"
        (O2I.kpiDefinitionKPI definition
           == Validation.kpiDefinitionKPI definition
           && O2I.kpiDefinitionUnit definition
                == Validation.kpiDefinitionUnit definition
           && O2I.kpiDefinitionDomain definition
                == Validation.kpiDefinitionDomain definition
           && O2I.kpiDefinitionMeasurementMethod definition
                == Validation.kpiDefinitionMeasurementMethod definition
           && O2I.kpiDefinitionInterpretation definition
                == Validation.kpiDefinitionInterpretation definition)
      assert
        "aggregate assessed follow-up projection"
        (observedLevel (followUpObservation (O2I.assessedFollowUp assessment))
           == Level 75)
      assert
        "aggregate effect-result projection"
        (O2I.effectResult assessment == Satisfied)
      assert
        "aggregate target-result projection"
        (O2I.targetResult assessment == TargetSatisfiedInObservationByDue)
      assert
        "validation and aggregate projections agree"
        (Validation.assessedFollowUp assessment
           == O2I.assessedFollowUp assessment
           && Validation.effectResult assessment == O2I.effectResult assessment
           && Validation.targetResult assessment == O2I.targetResult assessment)
  case needQualificationCandidateValue of
    Left message -> fail message
    Right candidate -> do
      assert
        "validated qualification candidate projections"
        (contextRefId (Validation.needQualificationCandidateStrategy candidate)
           == strategyId
           && contextRefId (Validation.needQualificationCandidateNeed candidate)
                == needId
           && unNodeId
                (Validation.needQualificationCandidateKeyResult candidate)
                == strategyKeyResultId
           && unNodeId
                (Validation.needQualificationCandidateObjective candidate)
                == needObjectiveId
           && Validation.needQualificationCandidateRationale candidate
                == "documented strategic translation"
           && Validation.needQualificationSourceReferenceText
                (Validation.needQualificationCandidateSourceReference candidate)
                == "strategy/kr-1")
      assert
        "aggregate qualification candidate projections agree"
        (O2I.needQualificationCandidateStrategy candidate
           == Validation.needQualificationCandidateStrategy candidate
           && O2I.needQualificationCandidateNeed candidate
                == Validation.needQualificationCandidateNeed candidate
           && O2I.needQualificationCandidateKeyResult candidate
                == Validation.needQualificationCandidateKeyResult candidate
           && O2I.needQualificationCandidateObjective candidate
                == Validation.needQualificationCandidateObjective candidate
           && O2I.needQualificationCandidateRationale candidate
                == Validation.needQualificationCandidateRationale candidate
           && O2I.needQualificationCandidateSourceReference candidate
                == Validation.needQualificationCandidateSourceReference
                     candidate
           && O2I.needQualificationSourceReferenceText
                (O2I.needQualificationCandidateSourceReference candidate)
                == Validation.needQualificationSourceReferenceText
                     (Validation.needQualificationCandidateSourceReference
                        candidate))

assert :: String -> Bool -> IO ()
assert message condition = unless condition (fail message)

data ValidatedValues =
  ValidatedValues
    WellFormedGraph
    SemanticallyValidModel
    TraceableEffectModel
    EvidenceReadyModel
    EvidenceAssessedModel
    EffectTrace
    KPIDefinition
    EffectAssessment

validatedValues :: Either String ValidatedValues
validatedValues = do
  structure <-
    checkedStructure "structural validation" (validateStructure assessmentGraph)
  let graph = structuralGraph structure
  model <-
    checkedSemantics
      "semantic validation"
      structure
      [assessmentStrategyFormulation]
  traceable <- checked "trace validation" (validateTraceability model)
  let trace = NonEmpty.head (effectTraces traceable)
      baselineObservation =
        Observation
          { observationKPI = unNodeId (traceKPI trace)
          , observationAnchor =
              situationAnchorRefId (traceSituationAnchor trace)
          , observedAt = read "2026-01-01 00:00:00 UTC"
          , observedLevel = Level 40
          , observationSource = EvidenceSource "validated baseline"
          }
      followUp =
        FollowUpObservation
          { followUpTrace = traceIdentifier trace
          , followUpObservation =
              baselineObservation
                { observedAt = read "2026-06-01 00:00:00 UTC"
                , observedLevel = Level 75
                , observationSource = EvidenceSource "validated follow-up"
                }
          }
      definition =
        RawKPIDefinition
          { rawDefinitionKPI = unNodeId (traceKPI trace)
          , rawDefinitionUnit = PercentagePoints
          , rawDefinitionDomain = BoundedDomain (Level 0) (Level 100)
          , rawDefinitionMeasurementMethod = "controlled measurement"
          , rawDefinitionInterpretation = "higher is better"
          }
      plan =
        EvidencePlan
          { plannedTrace = traceIdentifier trace
          , establishedAt = read "2025-12-01 00:00:00 UTC"
          , targetDueAt = read "2026-06-30 00:00:00 UTC"
          , planSource = EvidenceSource "approved plan"
          , baseline = baselineObservation
          , effectCriterion = AbsoluteIncreaseByAtLeast (Delta 10)
          , targetCriterion = AtLeast (Level 70)
          }
      intervention = contextRefId (traceIntervention trace)
      plannedStart =
        PlannedInterventionStart
          { plannedIntervention = intervention
          , plannedStartAt = read "2026-02-01 00:00:00 UTC"
          }
      actualStart =
        ActualInterventionStart
          { actualIntervention = intervention
          , actualStartAt = read "2026-02-01 00:00:00 UTC"
          }
  ready <-
    checked
      "readiness validation"
      (validateEvidenceReadinessAt
         (read "2026-01-15 00:00:00 UTC")
         traceable
         [definition]
         [plannedStart]
         [plan])
  validatedDefinition <-
    case lookupKPIDefinition ready (traceKPI trace) of
      Just value -> Right value
      Nothing -> Left "validated KPI definition was not found"
  assessed <-
    checked
      "evidence validation"
      (assessEffectEvidenceAt
         (read "2026-07-01 00:00:00 UTC")
         ready
         [actualStart]
         [followUp])
  pure
    (ValidatedValues
       graph
       model
       traceable
       ready
       assessed
       trace
       validatedDefinition
       (NonEmpty.head (effectAssessments assessed)))

checked :: Show error => String -> Validation error value -> Either String value
checked _ (Success value) = Right value
checked stage (Failure errors) = Left (stage ++ " failed: " ++ show errors)

checkedStructure ::
     String -> StructureResult -> Either String StructuralAssessment
checkedStructure _ (StructureAccepted assessment) = Right assessment
checkedStructure stage (StructureModelRejected errors) =
  Left (stage ++ " failed: " ++ show errors)
checkedStructure stage (StructureInternalFailure internal) =
  Left (stage ++ " failed internally: " ++ show internal)

needQualificationCandidateValue :: Either String NeedQualificationCandidate
needQualificationCandidateValue = do
  structure <-
    checkedStructure
      "qualification graph validation"
      (validateStructure
         assessmentGraph
           { rawEdges =
               filter
                 (`notElem` [ edge strategyId qualifiesNeed needId
                            , edge
                                strategyKeyResultId
                                translatesStrategyKeyResultToNeedObjective
                                needObjectiveId
                            ])
                 (rawEdges assessmentGraph)
           })
  model <-
    checkedSemantics
      "qualification semantic validation"
      structure
      [assessmentStrategyFormulation]
  checked
    "Need qualification proposal validation"
    (validateNeedQualificationProposal
       model
       RawNeedQualificationProposal
         { rawNeedQualificationCandidateStrategy = strategyId
         , rawNeedQualificationNeed = needId
         , rawNeedQualificationStrategyKeyResult = strategyKeyResultId
         , rawNeedQualificationNeedObjective = needObjectiveId
         , rawNeedQualificationRationale = "documented strategic translation"
         , rawNeedQualificationSourceReference = "  strategy/kr-1  "
         })

checkedSemantics ::
     String
  -> StructuralAssessment
  -> [RawStrategyFormulation]
  -> Either String SemanticallyValidModel
checkedSemantics stage structure formulations =
  let assessment =
        assessModelSemantics
          structure
          ModelSemanticsInput
            { modelStrategyClaims = map assertedClaim formulations
            , modelCollectiveClaims = []
            , modelCollectiveEvidence = []
            }
   in case modelAssessmentStatus assessment of
        SemanticsRejected errors -> Left (stage ++ " failed: " ++ show errors)
        SemanticsPending candidates ->
          Left (stage ++ " remained pending: " ++ show candidates)
        SemanticsAccepted model -> Right model

assessmentGraph :: RawGraph
assessmentGraph = RawGraph assessmentNodes assessmentEdges

assessmentNodes :: [RawNode]
assessmentNodes =
  [ RawContextNode ethosId Ethos
  , RawContextNode missionId Mission
  , RawContextNode visionId Vision
  , RawContextNode strategyId Strategy
  , RawContextNode needId Need
  , RawContextNode interventionId Intervention
  , RawContextNode measureId Measure
  , RawContextNode situationId Situation
  , RawPrimitiveNode ethosPrincipleId ethosId Principle
  , RawPrimitiveNode missionDriverId missionId Driver
  , RawPrimitiveNode visionObjectiveId visionId Objective
  , RawPrimitiveNode strategyDriverId strategyId Driver
  , RawPrimitiveNode strategyObjectiveId strategyId Objective
  , RawPrimitiveNode strategyPrincipleId strategyId Principle
  , RawPrimitiveNode strategyKeyResultId strategyId KeyResult
  , RawPrimitiveNode strategyActionId strategyId Action
  , RawPrimitiveNode needDriverId needId Driver
  , RawPrimitiveNode needObjectiveId needId Objective
  , RawPrimitiveNode interventionActionId interventionId Action
  , RawPrimitiveNode interventionKeyResultId interventionId KeyResult
  , RawPrimitiveNode measureKPIId measureId KPI
  , RawStructuringNode
      measurePerformanceDimensionId
      measureId
      PerformanceDimension
  , RawAnchorNode situationAnchorId BusinessCapability
  ]

assessmentEdges :: [RawEdge]
assessmentEdges =
  [ edge ethosPrincipleId guidesEthosPrincipleToMissionDriver missionDriverId
  , edge missionDriverId groundsMissionDriverToVisionObjective visionObjectiveId
  , edge
      ethosPrincipleId
      guidesEthosPrincipleToVisionObjective
      visionObjectiveId
  , edge visionId orientsStrategy strategyId
  , edge strategyId qualifiesNeed needId
  , edge situationId surfacesNeed needId
  , edge strategyId directsIntervention interventionId
  , edge interventionId addressesNeed needId
  , edge interventionId changesSituation situationId
  , edge strategyId framesMeasure measureId
  , edge interventionId setsTargetForMeasure measureId
  , edge measureId measuresSituation situationId
  , edge
      visionObjectiveId
      orientsVisionObjectiveToStrategyObjective
      strategyObjectiveId
  , edge strategyDriverId groundsStrategyDriverToObjective strategyObjectiveId
  , edge strategyPrincipleId guidesStrategyPrincipleToAction strategyActionId
  , edge
      strategyKeyResultId
      substantiatesStrategyKeyResultObjective
      strategyObjectiveId
  , edge
      strategyActionId
      contributesStrategyActionToKeyResult
      strategyKeyResultId
  , edge
      strategyKeyResultId
      translatesStrategyKeyResultToNeedObjective
      needObjectiveId
  , edge needDriverId groundsNeedDriverToObjective needObjectiveId
  , anchorEdge situationId ConstitutedByAnchorFamily situationAnchorId
  , anchorEdge situationAnchorId AnchorsNeedDriverFamily needDriverId
  , edge
      strategyActionId
      guidesStrategyActionToInterventionAction
      interventionActionId
  , edge
      interventionActionId
      contributesInterventionActionToKeyResult
      interventionKeyResultId
  , edge
      interventionKeyResultId
      substantiatesInterventionKeyResultNeedObjective
      needObjectiveId
  , edge
      interventionKeyResultId
      contributesInterventionKeyResultToStrategyKeyResult
      strategyKeyResultId
  , edge
      strategyDriverId
      indicatesMeasurePerformanceDimension
      measurePerformanceDimensionId
  , edge
      strategyKeyResultId
      determinesMeasurePerformanceDimension
      measurePerformanceDimensionId
  , edge
      measurePerformanceDimensionId
      (containsPerformanceDimension MeasureMeasurementDimension)
      measureKPIId
  , edge interventionKeyResultId setsTargetForMeasureKPI measureKPIId
  , anchorEdge interventionActionId ChangesAnchorFamily situationAnchorId
  , anchorEdge measureKPIId MeasuresAnchorFamily situationAnchorId
  ]

edge :: RawNodeId -> Relation from to -> RawNodeId -> RawEdge
edge from relation to = RawEdge from (relationNameFor relation) to

anchorEdge :: RawNodeId -> AnchorRelationFamily -> RawNodeId -> RawEdge
anchorEdge from family to = RawEdge from (anchorRelationFamilyName family) to

assessmentStrategyFormulation :: RawStrategyFormulation
assessmentStrategyFormulation =
  RawStrategyFormulation
    { rawFormulationStrategy = strategyId
    , rawFormulationScope = "enterprise" NonEmpty.:| []
    , rawFormulationAnchoring =
        StrategyAnchoring
          { anchoringPeriod = "2026"
          , anchoringResponsibilityScope = "enterprise"
          , anchoringDecisionLevel = "executive"
          , anchoringResponsibilities = "strategy owner" NonEmpty.:| []
          , anchoringDecisionPaths = "governance" NonEmpty.:| []
          , anchoringImplementationLogic = "coherent commitments"
          }
    , rawFormulationGuardrails = "evidence before assumption" NonEmpty.:| []
    , rawFormulationDiagnosis = strategyDriverId
    , rawFormulationIntent = strategyObjectiveId
    , rawFormulationGuidingPolicy = strategyPrincipleId
    , rawFormulationPositioning = "shared understanding" NonEmpty.:| []
    , rawFormulationTradeOffs = "traceability over speed" NonEmpty.:| []
    , rawFormulationActions = strategyActionId NonEmpty.:| []
    , rawFormulationKeyResults = strategyKeyResultId NonEmpty.:| []
    , rawFormulationFitRationale = "actions substantiate intent" NonEmpty.:| []
    }

ethosId, missionId, visionId, strategyId, needId, interventionId, measureId, situationId ::
     RawNodeId
ethosId = RawNodeId "ethos"

missionId = RawNodeId "mission"

visionId = RawNodeId "vision"

strategyId = RawNodeId "strategy"

needId = RawNodeId "need"

interventionId = RawNodeId "intervention"

measureId = RawNodeId "measure"

situationId = RawNodeId "situation"

ethosPrincipleId, missionDriverId, visionObjectiveId :: RawNodeId
ethosPrincipleId = RawNodeId "ethos-principle"

missionDriverId = RawNodeId "mission-driver"

visionObjectiveId = RawNodeId "vision-objective"

strategyDriverId, strategyObjectiveId :: RawNodeId
strategyDriverId = RawNodeId "strategy-driver"

strategyObjectiveId = RawNodeId "strategy-objective"

strategyPrincipleId, strategyKeyResultId, strategyActionId :: RawNodeId
strategyPrincipleId = RawNodeId "strategy-principle"

strategyKeyResultId = RawNodeId "strategy-key-result"

strategyActionId = RawNodeId "strategy-action"

needDriverId, needObjectiveId, interventionActionId :: RawNodeId
needDriverId = RawNodeId "need-driver"

needObjectiveId = RawNodeId "need-objective"

interventionActionId = RawNodeId "intervention-action"

interventionKeyResultId, measureKPIId, measurePerformanceDimensionId ::
     RawNodeId
interventionKeyResultId = RawNodeId "intervention-key-result"

measureKPIId = RawNodeId "measure-kpi"

measurePerformanceDimensionId = RawNodeId "measure-performance-dimension"

situationAnchorId :: RawNodeId
situationAnchorId = RawNodeId "situation-anchor"
