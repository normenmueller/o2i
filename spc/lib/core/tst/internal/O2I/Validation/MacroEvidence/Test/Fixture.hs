{-# LANGUAGE OverloadedStrings #-}

-- | Closed semantic fixtures for private macro-evidence contracts.
module O2I.Validation.MacroEvidence.Test.Fixture
  ( ScenarioShape(..)
  , scenarioGraph
  , scenarioFormulation
  , scenarioSemantic
  , validateScenario
  , additionalDomainMemberGraph
  , registryGraph
  , registryGraphWithoutCollectiveClaim
  , registryFormulations
  , validateRegistryGraph
  , validateRegistryScenario
  , frameClaim
  , ethosId
  , ethosPrincipleId
  , strategyId
  , strategyDriverId
  , strategyObjectiveId
  , strategyPrincipleId
  , strategyActionId
  , strategyKeyResultId
  , measureId
  , measureDimensionId
  , situationId
  , situationAnchorId
  , secondStrategyId
  , secondStrategyDriverId
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Validation (Validation(..))
import O2I.Graph.Raw
import O2I.Language.Element
import O2I.Language.Macro
import O2I.Language.Relation
import O2I.Validation.MacroEvidence
import O2I.Validation.Semantics.Context
import O2I.Validation.Structure

-- | Adversarial relation shapes exercised at each declared size.
data ScenarioShape
  = Sparse
  | Skewed
  | Dense
  | DeadEnd
  | Unrelated
  | OutputHeavy
  deriving (Bounded, Enum, Eq, Show)

scenarioGraph :: ScenarioShape -> Int -> RawGraph
scenarioGraph shape size =
  RawGraph
    { rawNodes = baseNodes ++ addedNodes shape size
    , rawEdges = baseEdges ++ addedEdges shape size
    }

scenarioFormulation :: ScenarioShape -> Int -> RawStrategyFormulation
scenarioFormulation shape size =
  baseFormulation
    { rawFormulationKeyResults =
        strategyKeyResultId
          NonEmpty.:| if usesAddedKeyResults shape
                        then map keyResultId [1 .. size]
                        else []
    }

scenarioSemantic :: ScenarioShape -> Int -> Either String ContextSemantics
scenarioSemantic shape size =
  validateScenario (scenarioGraph shape size) (scenarioFormulation shape size)

validateScenario ::
     RawGraph -> RawStrategyFormulation -> Either String ContextSemantics
validateScenario graph formulation = validateGraph graph [formulation]

-- | Small baseline graph with one additional indexed Measure KPI.
additionalDomainMemberGraph :: RawGraph
additionalDomainMemberGraph =
  baseline
    { rawNodes =
        rawNodes baseline
          ++ [ RawPrimitiveNode
                 (RawNodeId "measure-kpi-additional")
                 measureId
                 KPI
             ]
    }
  where
    baseline = scenarioGraph Sparse 0

validateGraph ::
     RawGraph -> [RawStrategyFormulation] -> Either String ContextSemantics
validateGraph graph formulations =
  case validateStructure graph of
    StructureModelRejected errors -> Left ("structural errors: " ++ show errors)
    StructureInternalFailure internal ->
      Left ("internal structural failure: " ++ show internal)
    StructureAccepted assessment ->
      case validateContextSemantics (structuralGraph assessment) formulations of
        Failure errors -> Left ("semantic errors: " ++ show errors)
        Success semantic -> Right semantic

-- | One semantically valid graph containing every registered macrorelation.
registryGraph :: RawGraph
registryGraph =
  RawGraph
    { rawNodes = baseNodes ++ registryNodes
    , rawEdges = baseEdges ++ registryEdges
    }

-- | Complete registry fixture without its two-alternative collective claim.
registryGraphWithoutCollectiveClaim :: RawGraph
registryGraphWithoutCollectiveClaim =
  registryGraph
    {rawEdges = filter (not . isCollectiveClaim) (rawEdges registryGraph)}
  where
    isCollectiveClaim candidate =
      rawEdgeFrom candidate == strategyId
        && rawEdgeRelation candidate == relationNameFor contributesToStrategy
        && rawEdgeTo candidate == secondStrategyId

-- | Exact Strategy formulations used by the complete-registry oracle.
registryFormulations :: [RawStrategyFormulation]
registryFormulations = [baseFormulation, secondStrategyFormulation]

-- | Validate a registry-shaped graph with both complete Strategy formulations.
validateRegistryGraph :: RawGraph -> Either String ContextSemantics
validateRegistryGraph graph = validateGraph graph registryFormulations

-- | Validate the complete-registry oracle fixture.
validateRegistryScenario :: Either String ContextSemantics
validateRegistryScenario = validateRegistryGraph registryGraph

frameClaim :: PreparedMacroEvidence -> Either String (MacroClaim RawNodeId)
frameClaim evidence =
  case [ claim
       | (conclusion, claim) <- macroEvidenceClaims evidence
       , rawEdgeFrom conclusion == strategyId
       , rawEdgeRelation conclusion == relationNameFor framesMeasure
       , rawEdgeTo conclusion == measureId
       ] of
    [claim] -> Right claim
    claims ->
      Left
        ("expected one Strategy-frames-Measure claim, got "
           ++ show (length claims))

baseNodes :: [RawNode]
baseNodes =
  [ RawContextNode ethosId Ethos
  , RawContextNode missionId Mission
  , RawContextNode visionId Vision
  , RawContextNode strategyId Strategy
  , RawContextNode measureId Measure
  , RawPrimitiveNode ethosPrincipleId ethosId Principle
  , RawPrimitiveNode missionDriverId missionId Driver
  , RawPrimitiveNode visionObjectiveId visionId Objective
  , RawPrimitiveNode strategyDriverId strategyId Driver
  , RawPrimitiveNode strategyObjectiveId strategyId Objective
  , RawPrimitiveNode strategyPrincipleId strategyId Principle
  , RawPrimitiveNode strategyActionId strategyId Action
  , RawPrimitiveNode strategyKeyResultId strategyId KeyResult
  , RawPrimitiveNode measureKPIId measureId KPI
  , RawStructuringNode measureDimensionId measureId PerformanceDimension
  ]

baseEdges :: [RawEdge]
baseEdges =
  [ edge strategyId framesMeasure measureId
  , edge ethosPrincipleId guidesEthosPrincipleToMissionDriver missionDriverId
  , edge missionDriverId groundsMissionDriverToVisionObjective visionObjectiveId
  , edge
      ethosPrincipleId
      guidesEthosPrincipleToVisionObjective
      visionObjectiveId
  , edge
      visionObjectiveId
      orientsVisionObjectiveToStrategyObjective
      strategyObjectiveId
  , edge strategyDriverId groundsStrategyDriverToObjective strategyObjectiveId
  , edge strategyPrincipleId guidesStrategyPrincipleToAction strategyActionId
  , edge
      strategyActionId
      contributesStrategyActionToKeyResult
      strategyKeyResultId
  , edge
      strategyKeyResultId
      substantiatesStrategyKeyResultObjective
      strategyObjectiveId
  , edge
      strategyDriverId
      indicatesMeasurePerformanceDimension
      measureDimensionId
  , edge
      strategyKeyResultId
      determinesMeasurePerformanceDimension
      measureDimensionId
  , edge
      measureDimensionId
      (containsPerformanceDimension MeasureMeasurementDimension)
      measureKPIId
  ]

baseFormulation :: RawStrategyFormulation
baseFormulation =
  RawStrategyFormulation
    { rawFormulationStrategy = strategyId
    , rawFormulationScope = "scope" NonEmpty.:| []
    , rawFormulationAnchoring =
        StrategyAnchoring
          { anchoringPeriod = "2026"
          , anchoringResponsibilityScope = "scope"
          , anchoringDecisionLevel = "decision"
          , anchoringResponsibilities = "owner" NonEmpty.:| []
          , anchoringDecisionPaths = "path" NonEmpty.:| []
          , anchoringImplementationLogic = "logic"
          }
    , rawFormulationGuardrails = "guardrail" NonEmpty.:| []
    , rawFormulationDiagnosis = strategyDriverId
    , rawFormulationIntent = strategyObjectiveId
    , rawFormulationGuidingPolicy = strategyPrincipleId
    , rawFormulationPositioning = "position" NonEmpty.:| []
    , rawFormulationTradeOffs = "trade-off" NonEmpty.:| []
    , rawFormulationActions = strategyActionId NonEmpty.:| []
    , rawFormulationKeyResults = strategyKeyResultId NonEmpty.:| []
    , rawFormulationFitRationale = "fit" NonEmpty.:| []
    }

registryNodes :: [RawNode]
registryNodes =
  [ RawContextNode needId Need
  , RawContextNode situationId Situation
  , RawContextNode interventionId Intervention
  , RawContextNode secondStrategyId Strategy
  , RawPrimitiveNode needDriverId needId Driver
  , RawPrimitiveNode needObjectiveId needId Objective
  , RawPrimitiveNode interventionActionId interventionId Action
  , RawPrimitiveNode interventionKeyResultId interventionId KeyResult
  , RawPrimitiveNode secondStrategyDriverId secondStrategyId Driver
  , RawPrimitiveNode secondStrategyObjectiveId secondStrategyId Objective
  , RawPrimitiveNode secondStrategyPrincipleId secondStrategyId Principle
  , RawPrimitiveNode secondStrategyActionId secondStrategyId Action
  , RawPrimitiveNode secondStrategyKeyResultId secondStrategyId KeyResult
  , RawAnchorNode situationAnchorId BusinessCapability
  ]

registryEdges :: [RawEdge]
registryEdges =
  [ edge ethosId guidesMission missionId
  , edge missionId groundsVision visionId
  , edge ethosId guidesVision visionId
  , edge visionId orientsStrategy strategyId
  , edge visionId orientsStrategy secondStrategyId
  , edge strategyId directsStrategy secondStrategyId
  , edge strategyId contributesToStrategy secondStrategyId
  , edge strategyId qualifiesNeed needId
  , edge situationId surfacesNeed needId
  , edge interventionId addressesNeed needId
  , edge strategyId directsIntervention interventionId
  , edge interventionId changesSituation situationId
  , edge interventionId setsTargetForMeasure measureId
  , edge measureId measuresSituation situationId
  , edge
      visionObjectiveId
      orientsVisionObjectiveToStrategyObjective
      secondStrategyObjectiveId
  , edge
      secondStrategyDriverId
      groundsStrategyDriverToObjective
      secondStrategyObjectiveId
  , edge
      secondStrategyPrincipleId
      guidesStrategyPrincipleToAction
      secondStrategyActionId
  , edge
      secondStrategyActionId
      contributesStrategyActionToKeyResult
      secondStrategyKeyResultId
  , edge
      secondStrategyKeyResultId
      substantiatesStrategyKeyResultObjective
      secondStrategyObjectiveId
  , edge
      strategyPrincipleId
      guidesStrategyPrincipleToPrinciple
      secondStrategyPrincipleId
  , edge
      strategyKeyResultId
      contributesStrategyKeyResultToKeyResult
      secondStrategyKeyResultId
  , edge
      strategyActionId
      contributesStrategyActionToAction
      secondStrategyActionId
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
  , edge interventionKeyResultId setsTargetForMeasureKPI measureKPIId
  , anchorEdge interventionActionId ChangesAnchorFamily situationAnchorId
  , anchorEdge measureKPIId MeasuresAnchorFamily situationAnchorId
  ]

secondStrategyFormulation :: RawStrategyFormulation
secondStrategyFormulation =
  baseFormulation
    { rawFormulationStrategy = secondStrategyId
    , rawFormulationDiagnosis = secondStrategyDriverId
    , rawFormulationIntent = secondStrategyObjectiveId
    , rawFormulationGuidingPolicy = secondStrategyPrincipleId
    , rawFormulationActions = secondStrategyActionId NonEmpty.:| []
    , rawFormulationKeyResults = secondStrategyKeyResultId NonEmpty.:| []
    }

addedNodes :: ScenarioShape -> Int -> [RawNode]
addedNodes shape size = keyResultNodes ++ dimensionNodes ++ kpiNodes
  where
    keyResultNodes
      | usesAnyAddedKeyResults shape =
        [ RawPrimitiveNode (keyResultId index) strategyId KeyResult
        | index <- [1 .. size]
        ]
      | otherwise = []
    dimensionNodes
      | usesAddedDimensions shape =
        [ RawStructuringNode (dimensionId index) measureId PerformanceDimension
        | index <- [1 .. size]
        ]
      | otherwise = []
    kpiNodes
      | shape == OutputHeavy =
        [RawPrimitiveNode (kpiId index) measureId KPI | index <- [1 .. size]]
      | otherwise = []

addedEdges :: ScenarioShape -> Int -> [RawEdge]
addedEdges shape size =
  keyResultSemantics
    ++ case shape of
         Sparse -> sparseEdges size
         Skewed -> skewedEdges size
         Dense -> denseEdges size
         DeadEnd -> deadEndEdges size
         Unrelated -> unrelatedEdges size
         OutputHeavy -> outputHeavyEdges size
  where
    keyResultSemantics
      | usesAddedKeyResults shape =
        [ edge
          (keyResultId index)
          substantiatesStrategyKeyResultObjective
          strategyObjectiveId
        | index <- [1 .. size]
        ]
      | otherwise = []

sparseEdges :: Int -> [RawEdge]
sparseEdges size =
  concat
    [ [ edge
          strategyDriverId
          indicatesMeasurePerformanceDimension
          (dimensionId index)
      , edge
          (keyResultId index)
          determinesMeasurePerformanceDimension
          (dimensionId index)
      , edge
          (dimensionId index)
          (containsPerformanceDimension MeasureMeasurementDimension)
          measureKPIId
      ]
    | index <- [1 .. size]
    ]

skewedEdges :: Int -> [RawEdge]
skewedEdges size =
  [ edge
    strategyDriverId
    indicatesMeasurePerformanceDimension
    (dimensionId index)
  | index <- [1 .. size]
  ]

denseEdges :: Int -> [RawEdge]
denseEdges size = driverEdges ++ keyResultEdges ++ membershipEdges
  where
    dimensions = measureDimensionId : map dimensionId [1 .. size]
    keyResults = strategyKeyResultId : map keyResultId [1 .. size]
    driverEdges =
      [ edge strategyDriverId indicatesMeasurePerformanceDimension dimension
      | dimension <- drop 1 dimensions
      ]
    keyResultEdges =
      [ edge keyResult determinesMeasurePerformanceDimension dimension
      | keyResult <- keyResults
      , dimension <- dimensions
      , (keyResult, dimension) /= (strategyKeyResultId, measureDimensionId)
      ]
    membershipEdges =
      [ edge
        dimension
        (containsPerformanceDimension MeasureMeasurementDimension)
        measureKPIId
      | dimension <- drop 1 dimensions
      ]

deadEndEdges :: Int -> [RawEdge]
deadEndEdges size =
  concat
    [ [ edge
          strategyDriverId
          indicatesMeasurePerformanceDimension
          (dimensionId index)
      , edge
          (keyResultId index)
          determinesMeasurePerformanceDimension
          (dimensionId index)
      ]
    | index <- [1 .. size]
    ]

unrelatedEdges :: Int -> [RawEdge]
unrelatedEdges size =
  concat
    [ [ edge
          strategyDriverId
          indicatesMeasurePerformanceDimension
          (dimensionId index)
      , edge
          (keyResultId index)
          determinesMeasurePerformanceDimension
          (dimensionId index)
      , edge
          (dimensionId index)
          (containsPerformanceDimension MeasureMeasurementDimension)
          measureKPIId
      ]
    | index <- [1 .. size]
    ]

outputHeavyEdges :: Int -> [RawEdge]
outputHeavyEdges size = keyResultEdges ++ membershipEdges
  where
    keyResultEdges =
      [ edge
        (keyResultId index)
        determinesMeasurePerformanceDimension
        measureDimensionId
      | index <- [1 .. size]
      ]
    membershipEdges =
      [ edge
        measureDimensionId
        (containsPerformanceDimension MeasureMeasurementDimension)
        (kpiId index)
      | index <- [1 .. size]
      ]

usesAddedKeyResults :: ScenarioShape -> Bool
usesAddedKeyResults shape = shape `elem` [Sparse, Dense, DeadEnd, OutputHeavy]

usesAnyAddedKeyResults :: ScenarioShape -> Bool
usesAnyAddedKeyResults shape = usesAddedKeyResults shape || shape == Unrelated

usesAddedDimensions :: ScenarioShape -> Bool
usesAddedDimensions shape =
  shape `elem` [Sparse, Skewed, Dense, DeadEnd, Unrelated]

edge :: RawNodeId -> Relation from to -> RawNodeId -> RawEdge
edge from relation to = RawEdge from (relationNameFor relation) to

anchorEdge :: RawNodeId -> AnchorRelationFamily -> RawNodeId -> RawEdge
anchorEdge from family to = RawEdge from (anchorRelationFamilyName family) to

identifier :: Text -> Int -> RawNodeId
identifier prefix index = RawNodeId (prefix <> "-" <> Text.pack (show index))

keyResultId :: Int -> RawNodeId
keyResultId = identifier "strategy-key-result"

dimensionId :: Int -> RawNodeId
dimensionId = identifier "measure-dimension"

kpiId :: Int -> RawNodeId
kpiId = identifier "measure-kpi"

ethosId, missionId, visionId, strategyId, measureId :: RawNodeId
ethosId = RawNodeId "ethos"

missionId = RawNodeId "mission"

visionId = RawNodeId "vision"

strategyId = RawNodeId "strategy"

measureId = RawNodeId "measure"

ethosPrincipleId, missionDriverId, visionObjectiveId :: RawNodeId
ethosPrincipleId = RawNodeId "ethos-principle"

missionDriverId = RawNodeId "mission-driver"

visionObjectiveId = RawNodeId "vision-objective"

strategyDriverId, strategyObjectiveId, strategyPrincipleId :: RawNodeId
strategyDriverId = RawNodeId "strategy-driver"

strategyObjectiveId = RawNodeId "strategy-objective"

strategyPrincipleId = RawNodeId "strategy-principle"

strategyActionId, strategyKeyResultId :: RawNodeId
strategyActionId = RawNodeId "strategy-action"

strategyKeyResultId = RawNodeId "strategy-key-result-0"

measureDimensionId, measureKPIId :: RawNodeId
measureDimensionId = RawNodeId "measure-dimension-0"

measureKPIId = RawNodeId "measure-kpi-0"

needId, situationId, interventionId, secondStrategyId :: RawNodeId
needId = RawNodeId "need"

situationId = RawNodeId "situation"

interventionId = RawNodeId "intervention"

secondStrategyId = RawNodeId "strategy-second"

needDriverId, needObjectiveId :: RawNodeId
needDriverId = RawNodeId "need-driver"

needObjectiveId = RawNodeId "need-objective"

interventionActionId, interventionKeyResultId :: RawNodeId
interventionActionId = RawNodeId "intervention-action"

interventionKeyResultId = RawNodeId "intervention-key-result"

secondStrategyDriverId, secondStrategyObjectiveId :: RawNodeId
secondStrategyDriverId = RawNodeId "strategy-second-driver"

secondStrategyObjectiveId = RawNodeId "strategy-second-objective"

secondStrategyPrincipleId, secondStrategyActionId :: RawNodeId
secondStrategyPrincipleId = RawNodeId "strategy-second-principle"

secondStrategyActionId = RawNodeId "strategy-second-action"

secondStrategyKeyResultId, situationAnchorId :: RawNodeId
secondStrategyKeyResultId = RawNodeId "strategy-second-key-result"

situationAnchorId = RawNodeId "situation-anchor"
