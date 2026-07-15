{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module Main
  ( main
  ) where

import Control.Monad (unless)
import qualified Data.List.NonEmpty as NonEmpty
import Language.Haskell.TH
  ( Info(VarI)
  , lookupTypeName
  , lookupValueName
  , nameBase
  , reify
  )
import O2I
import O2I.Language
import qualified O2I.Validation as Validation

$(do
    specType <- lookupTypeName "InterpretationSpec"
    someType <- lookupTypeName "SomeInterpretation"
    specConstructor <- lookupValueName "InterpretationSpec"
    someConstructor <- lookupValueName "SomeInterpretation"
    case (specType, someType, specConstructor, someConstructor) of
      (Just _, Just _, Nothing, Nothing) -> pure []
      _ -> fail "interpretation metadata types must be public and abstract")

$(do
    let projections =
          [ 'interpretationCode
          , 'interpretationContext
          , 'interpretationPrimitive
          , 'interpretationWitness
          ]
        isNotOrdinaryFunction (_, VarI _ _ Nothing) = False
        isNotOrdinaryFunction _ = True
    projectionInfo <-
      traverse (\name -> fmap ((,) name) (reify name)) projections
    case filter isNotOrdinaryFunction projectionInfo of
      [] -> pure []
      invalid ->
        fail
          ("interpretation projections must not be record selectors: "
             ++ show (map (nameBase . fst) invalid)))

$(do
    o2iType <- lookupTypeName "O2I.EffectAssessment"
    validationType <- lookupTypeName "Validation.EffectAssessment"
    o2iConstructor <- lookupValueName "O2I.EffectAssessment"
    validationConstructor <- lookupValueName "Validation.EffectAssessment"
    case (o2iType, validationType, o2iConstructor, validationConstructor) of
      (Just _, Just _, Nothing, Nothing) -> pure []
      _ -> fail "EffectAssessment must be abstract through both facades")

$(do
    let projections =
          [ 'O2I.assessedFollowUp
          , 'O2I.effectResult
          , 'O2I.targetResult
          , 'Validation.assessedFollowUp
          , 'Validation.effectResult
          , 'Validation.targetResult
          ]
        isNotOrdinaryFunction (_, VarI _ _ Nothing) = False
        isNotOrdinaryFunction _ = True
    projectionInfo <-
      traverse (\name -> fmap ((,) name) (reify name)) projections
    case filter isNotOrdinaryFunction projectionInfo of
      [] -> pure []
      invalid ->
        fail
          ("assessment projections must not be record selectors: "
             ++ show (map (nameBase . fst) invalid)))

main :: IO ()
main = do
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
  case validatedAssessment of
    Left message -> fail message
    Right assessment -> do
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

assert :: String -> Bool -> IO ()
assert message condition = unless condition (fail message)

validatedAssessment :: Either String EffectAssessment
validatedAssessment = do
  graph <- checked "structural validation" (validateStructure assessmentGraph)
  model <-
    checked
      "semantic validation"
      (validateModelSemantics graph [assessmentStrategyFormulation])
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
         (NonEmpty.singleton plan))
  assessed <-
    checked
      "evidence validation"
      (assessEffectEvidenceAt
         (read "2026-07-01 00:00:00 UTC")
         ready
         [actualStart]
         (NonEmpty.singleton followUp))
  pure (NonEmpty.head (effectAssessments assessed))

checked :: Show error => String -> Validation error value -> Either String value
checked _ (Success value) = Right value
checked stage (Failure errors) = Left (stage ++ " failed: " ++ show errors)

assessmentGraph :: RawGraph
assessmentGraph = RawGraph assessmentNodes assessmentEdges

assessmentNodes :: [RawNode]
assessmentNodes =
  [ RawContextNode visionId Vision
  , RawContextNode strategyId Strategy
  , RawContextNode needId Need
  , RawContextNode interventionId Intervention
  , RawContextNode measureId Measure
  , RawContextNode situationId Situation
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
  , RawAnchorNode situationAnchorId situationId BusinessCapability
  ]

assessmentEdges :: [RawEdge]
assessmentEdges =
  [ edge visionId orientsStrategy strategyId
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
  , edge situationId (constitutedByAnchor SBusinessCapability) situationAnchorId
  , edge situationAnchorId (anchorsNeedDriver SBusinessCapability) needDriverId
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
  , edge
      interventionActionId
      (changesAnchor SBusinessCapability)
      situationAnchorId
  , edge measureKPIId (measuresAnchor SBusinessCapability) situationAnchorId
  ]

edge :: RawNodeId -> Relation from to -> RawNodeId -> RawEdge
edge from relation to = RawEdge from (relationNameFor relation) to

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

visionId, strategyId, needId, interventionId, measureId, situationId ::
     RawNodeId
visionId = RawNodeId "vision"

strategyId = RawNodeId "strategy"

needId = RawNodeId "need"

interventionId = RawNodeId "intervention"

measureId = RawNodeId "measure"

situationId = RawNodeId "situation"

visionObjectiveId, strategyDriverId, strategyObjectiveId :: RawNodeId
visionObjectiveId = RawNodeId "vision-objective"

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
