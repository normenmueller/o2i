{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

-- | External-client contracts for canonical and validated O2I values.
module Main
  ( main
  ) where

import ApiContractTH (assertAbstractTypes, assertOrdinaryFunctions)
import Control.Monad (forM_, unless)
import Data.List (isInfixOf)
import qualified Data.List.NonEmpty as NonEmpty
import O2I
import qualified O2I.Graph as Graph
import O2I.Language
import qualified O2I.Language as Language
import qualified O2I.Validation as Validation
import System.Exit (ExitCode(..))
import System.Process (readProcessWithExitCode)

$(assertAbstractTypes
    [ "Language.NodeId"
    , "Language.ContextRef"
    , "Language.InterpretationSpec"
    , "Language.SomeInterpretation"
    , "Language.Relation"
    , "Language.RelationSpec"
    ])

$(assertOrdinaryFunctions
    [ 'Language.unNodeId
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
    ])

$(assertAbstractTypes
    ["Graph.SomeNode", "Graph.SomeEdge", "Graph.WellFormedGraph"])

$(assertOrdinaryFunctions
    [ 'Graph.graphNodes
    , 'Graph.graphEdges
    , 'Graph.someNodeId
    , 'Graph.someNodeKind
    , 'Graph.someNodeOwner
    , 'Graph.someEdgeFrom
    , 'Graph.someEdgeRelation
    , 'Graph.someEdgeTo
    ])

$(assertAbstractTypes
    [ "Validation.StrategyFormulation"
    , "Validation.SemanticallyValidModel"
    , "Validation.EffectTrace"
    , "Validation.EffectTraceId"
    , "Validation.SomeSituationAnchorRef"
    , "Validation.TraceableEffectModel"
    , "Validation.KPIDefinition"
    , "Validation.EvidenceReadyModel"
    , "Validation.EffectAssessment"
    , "Validation.EvidenceAssessedModel"
    ])

$(assertOrdinaryFunctions
    [ 'Validation.strategyFormulations
    , 'Validation.strategyFormulationData
    , 'Validation.effectTraces
    , 'Validation.traceIdentifier
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
    [ "O2I.NodeId"
    , "O2I.ContextRef"
    , "O2I.SomeInterpretation"
    , "O2I.Relation"
    , "O2I.SomeRelation"
    , "O2I.SomeNode"
    , "O2I.SomeEdge"
    , "O2I.WellFormedGraph"
    , "O2I.StrategyFormulation"
    , "O2I.SemanticallyValidModel"
    , "O2I.EffectTrace"
    , "O2I.EffectTraceId"
    , "O2I.SomeSituationAnchorRef"
    , "O2I.TraceableEffectModel"
    , "O2I.KPIDefinition"
    , "O2I.EvidenceReadyModel"
    , "O2I.EffectAssessment"
    , "O2I.EvidenceAssessedModel"
    ])

$(assertOrdinaryFunctions
    [ 'O2I.unNodeId
    , 'O2I.contextRefId
    , 'O2I.interpretationCodeOf
    , 'O2I.interpretationIdentity
    , 'O2I.relationNameFor
    , 'O2I.relationNameOf
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
    , 'O2I.strategyFormulations
    , 'O2I.strategyFormulationData
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

-- | Run positive API use and every compile-fail contract.
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
  let relationMetadata = Language.relationSpec Language.orientsStrategy
  assert
    "canonical relation metadata projection"
    (Language.relationCode relationMetadata == FixedRelation OrientsStrategyCode
       && Language.relationName relationMetadata
            == RelationName "vision-orients-strategy")
  case validatedValues of
    Left message -> fail message
    Right (ValidatedValues graph semantic traceable ready assessed trace definition assessment) -> do
      assert
        "Graph facade exposes validated nodes"
        (visionId `elem` map Graph.someNodeId (Graph.graphNodes graph))
      assert
        "Graph facade exposes validated edges"
        (not (null (Graph.graphEdges graph)))
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
  runCompileFailContracts

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
         (NonEmpty.singleton followUp))
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

data CompileFailKind
  = HiddenConstructors
  | NonRecordSelectors

data CompileFailContract =
  CompileFailContract String FilePath CompileFailKind [String]

runCompileFailContracts :: IO ()
runCompileFailContracts = forM_ compileFailContracts runCompileFailContract

runCompileFailContract :: CompileFailContract -> IO ()
runCompileFailContract (CompileFailContract label source kind names) = do
  (exitCode, standardOutput, standardError) <-
    readProcessWithExitCode
      "cabal"
      [ "exec"
      , "--"
      , "ghc"
      , "-v0"
      , "-fno-code"
      , "-fforce-recomp"
      , "-fmax-errors=100"
      , "-package"
      , "o2i"
      , source
      ]
      ""
  let output = standardOutput ++ standardError
      expectedReason =
        case kind of
          HiddenConstructors -> "illegal term-level use"
          NonRecordSelectors -> "not a record selector"
  case exitCode of
    ExitSuccess -> fail (label ++ " unexpectedly compiled")
    ExitFailure _ -> do
      assert
        (label ++ " failed for the wrong reason")
        (expectedReason `isInfixOf` map asciiLower output)
      forM_
        names
        (\name ->
           assert
             (label ++ " did not reject " ++ name)
             (mentionsExact name output))

mentionsExact :: String -> String -> Bool
mentionsExact = isInfixOf

asciiLower :: Char -> Char
asciiLower character
  | character >= 'A' && character <= 'Z' =
    toEnum (fromEnum character + fromEnum 'a' - fromEnum 'A')
  | otherwise = character

compileFailContracts :: [CompileFailContract]
compileFailContracts =
  [ CompileFailContract
      "O2I.Language opaque constructors"
      "tst/api/compile-fail/LanguageOpaqueConstructors.hs"
      HiddenConstructors
      [ "Language.NodeId"
      , "Language.ContextRef"
      , "Language.InterpretationSpec"
      , "Language.SomeInterpretation"
      , "Language.Relation"
      , "Language.RelationSpec"
      ]
  , CompileFailContract
      "O2I.Language record updates"
      "tst/api/compile-fail/LanguageRecordUpdates.hs"
      NonRecordSelectors
      [ "Language.unNodeId"
      , "Language.contextRefId"
      , "Language.interpretationCode"
      , "Language.interpretationContext"
      , "Language.interpretationPrimitive"
      , "Language.interpretationWitness"
      , "Language.relationCode"
      , "Language.relationSemantics"
      , "Language.relationName"
      , "Language.relationLabel"
      , "Language.relationFrom"
      , "Language.relationTo"
      ]
  , CompileFailContract
      "O2I.Graph opaque constructors"
      "tst/api/compile-fail/GraphOpaqueConstructors.hs"
      HiddenConstructors
      ["Graph.SomeNode", "Graph.SomeEdge", "Graph.WellFormedGraph"]
  , CompileFailContract
      "O2I.Graph record updates"
      "tst/api/compile-fail/GraphRecordUpdates.hs"
      NonRecordSelectors
      ["Graph.someNodeId", "Graph.someEdgeFrom", "Graph.graphNodes"]
  , CompileFailContract
      "O2I.Validation opaque constructors"
      "tst/api/compile-fail/ValidationOpaqueConstructors.hs"
      HiddenConstructors
      [ "Validation.StrategyFormulation"
      , "Validation.SemanticallyValidModel"
      , "Validation.EffectTrace"
      , "Validation.EffectTraceId"
      , "Validation.SomeSituationAnchorRef"
      , "Validation.TraceableEffectModel"
      , "Validation.KPIDefinition"
      , "Validation.EvidenceReadyModel"
      , "Validation.EffectAssessment"
      , "Validation.EvidenceAssessedModel"
      ]
  , CompileFailContract
      "O2I.Validation record updates"
      "tst/api/compile-fail/ValidationRecordUpdates.hs"
      NonRecordSelectors
      [ "Validation.strategyFormulationData"
      , "Validation.strategyFormulations"
      , "Validation.traceIdentifier"
      , "Validation.effectTraces"
      , "Validation.situationAnchorRefId"
      , "Validation.kpiDefinitionKPI"
      , "Validation.kpiDefinitionUnit"
      , "Validation.kpiDefinitionDomain"
      , "Validation.kpiDefinitionMeasurementMethod"
      , "Validation.kpiDefinitionInterpretation"
      , "Validation.kpiDefinitions"
      , "Validation.assessedFollowUp"
      , "Validation.effectAssessments"
      ]
  , CompileFailContract
      "O2I aggregate opaque constructors"
      "tst/api/compile-fail/AggregateOpaqueConstructors.hs"
      HiddenConstructors
      [ "O2I.NodeId"
      , "O2I.ContextRef"
      , "O2I.SomeInterpretation"
      , "O2I.Relation"
      , "O2I.SomeRelation"
      , "O2I.SomeNode"
      , "O2I.SomeEdge"
      , "O2I.WellFormedGraph"
      , "O2I.StrategyFormulation"
      , "O2I.SemanticallyValidModel"
      , "O2I.EffectTrace"
      , "O2I.EffectTraceId"
      , "O2I.SomeSituationAnchorRef"
      , "O2I.TraceableEffectModel"
      , "O2I.KPIDefinition"
      , "O2I.EvidenceReadyModel"
      , "O2I.EffectAssessment"
      , "O2I.EvidenceAssessedModel"
      ]
  , CompileFailContract
      "O2I aggregate record updates"
      "tst/api/compile-fail/AggregateRecordUpdates.hs"
      NonRecordSelectors
      [ "O2I.unNodeId"
      , "O2I.contextRefId"
      , "O2I.someNodeId"
      , "O2I.someEdgeFrom"
      , "O2I.graphNodes"
      , "O2I.strategyFormulationData"
      , "O2I.strategyFormulations"
      , "O2I.traceIdentifier"
      , "O2I.effectTraces"
      , "O2I.situationAnchorRefId"
      , "O2I.kpiDefinitionKPI"
      , "O2I.kpiDefinitionUnit"
      , "O2I.kpiDefinitionDomain"
      , "O2I.kpiDefinitionMeasurementMethod"
      , "O2I.kpiDefinitionInterpretation"
      , "O2I.kpiDefinitions"
      , "O2I.assessedFollowUp"
      , "O2I.effectAssessments"
      ]
  ]

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
