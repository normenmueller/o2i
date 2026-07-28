{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Private regression tests for output-sensitive effect-trace traversal.
module Main where

import qualified Data.Map.Strict as Map
import qualified Data.Text as Text
import O2I.Graph.Typed
import O2I.Language.Element
import O2I.Language.Interpretation
import O2I.Language.Relation
import O2I.Validation.Trace.Search
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "private effect-trace search"
    [ testCase
        "all unreachable context kinds preserve trace identities and traversal"
        unreachableContextsTest
    , testCase
        "relevant path growth has constant incremental work"
        linearRelevantPathGrowthTest
    , testCase
        "input order does not affect paths or work"
        inputOrderDeterminismTest
    ]

unreachableContextsTest :: Assertion
unreachableContextsTest = do
  let baseline = searchGraph 1 0 id
      hundred = searchGraph 1 100 id
      thousand = searchGraph 1 1000 id
      baselineWork = searchWork baseline
      hundredWork = searchWork hundred
      thousandWork = searchWork thousand
  traceIdentityConstituents hundred @?= traceIdentityConstituents baseline
  traceIdentityConstituents thousand @?= traceIdentityConstituents baseline
  searchPaths hundred @?= searchPaths baseline
  searchPaths thousand @?= searchPaths baseline
  traceTraversalWork hundredWork @?= traceTraversalWork baselineWork
  traceTraversalWork thousandWork @?= traceTraversalWork baselineWork
  length (searchInterventions hundred) @?= length (searchInterventions baseline)
    + 100
  length (searchInterventions thousand)
    @?= length (searchInterventions baseline)
    + 1000
  searchAddressedNeeds hundred (unreachableId 100 "intervention") @?= []
  searchAddressedNeeds thousand (unreachableId 1000 "intervention") @?= []
  traceIndexedNodeOccurrences (traceIndexBuildWork hundredWork)
    @?= traceIndexedNodeOccurrences (traceIndexBuildWork baselineWork)
    + 800
  traceIndexedNodeOccurrences (traceIndexBuildWork thousandWork)
    @?= traceIndexedNodeOccurrences (traceIndexBuildWork baselineWork)
    + 8000
  traceIndexedEdgeOccurrences (traceIndexBuildWork hundredWork)
    @?= traceIndexedEdgeOccurrences (traceIndexBuildWork baselineWork)
  traceIndexedEdgeOccurrences (traceIndexBuildWork thousandWork)
    @?= traceIndexedEdgeOccurrences (traceIndexBuildWork baselineWork)

traceIdentityConstituents :: TraceSearchResult -> [[RawNodeId]]
traceIdentityConstituents = map pathIdentity . searchPaths

pathIdentity :: TracePath -> [RawNodeId]
pathIdentity path =
  [ pathVision path
  , pathVisionObjective path
  , pathStrategy path
  , pathStrategyDriver path
  , pathStrategyObjective path
  , pathStrategyKeyResult path
  , pathStrategyAction path
  , pathNeed path
  , pathNeedDriver path
  , pathNeedObjective path
  , pathIntervention path
  , pathInterventionAction path
  , pathInterventionKeyResult path
  , pathMeasure path
  , pathMeasurePerformanceDimension path
  , pathMeasureKPI path
  , pathSituation path
  , pathSituationAnchor path
  ]

linearRelevantPathGrowthTest :: Assertion
linearRelevantPathGrowthTest = do
  let one = searchGraph 1 0 id
      two = searchGraph 2 0 id
      three = searchGraph 3 0 id
      ten = searchGraph 10 0 id
      workOne = traversalVector (traceTraversalWork (searchWork one))
      workTwo = traversalVector (traceTraversalWork (searchWork two))
      workThree = traversalVector (traceTraversalWork (searchWork three))
      workTen = traversalVector (traceTraversalWork (searchWork ten))
      increment = zipWith (-) workTwo workOne
  length (searchPaths one) @?= 1
  length (searchPaths two) @?= 2
  length (searchPaths three) @?= 3
  length (searchPaths ten) @?= 10
  zipWith (-) workThree workTwo @?= increment
  workTen @?= zipWith (+) workOne (map (* 9) increment)

inputOrderDeterminismTest :: Assertion
inputOrderDeterminismTest = do
  let normal = searchGraph 3 0 id
      reversed = searchGraph 3 0 reverse
  searchPaths reversed @?= searchPaths normal
  searchWork reversed @?= searchWork normal

traversalVector :: TraceTraversalWork -> [Int]
traversalVector work =
  [ traceNodeBucketProbes work
  , traceNodeOccurrences work
  , traceNodeMembershipProbes work
  , traceEdgeBucketProbes work
  , traceEdgeOccurrences work
  , traceEdgeMembershipProbes work
  , traceStrategyRoleProbes work
  , tracePathExtensions work
  , tracePathsEmitted work
  ]

searchGraph :: Int -> Int -> ([SomeEdge] -> [SomeEdge]) -> TraceSearchResult
searchGraph pathCount unreachableCount orderEdges =
  deriveTracePaths
    (mkGraph
       (fixedNodes
          ++ concatMap pathNodes [1 .. pathCount]
          ++ unreachableNodes unreachableCount)
       (orderEdges (fixedEdges ++ concatMap pathEdges [1 .. pathCount])))
    strategyRoles

mkGraph :: [SomeNode] -> [SomeEdge] -> WellFormedGraph
mkGraph nodes =
  mkWellFormedGraph (Map.fromList [(someNodeId node, node) | node <- nodes])

fixedNodes :: [SomeNode]
fixedNodes =
  [ contextNode visionId SVision
  , contextNode strategyId SStrategy
  , contextNode needId SNeed
  , contextNode interventionId SIntervention
  , contextNode measureId SMeasure
  , contextNode situationId SSituation
  , primitiveNode
      visionObjectiveId
      visionId
      SVision
      SObjective
      ObjectiveInVision
  , primitiveNode strategyDriverId strategyId SStrategy SDriver DriverInStrategy
  , primitiveNode
      strategyObjectiveId
      strategyId
      SStrategy
      SObjective
      ObjectiveInStrategy
  , primitiveNode
      strategyKeyResultId
      strategyId
      SStrategy
      SKeyResult
      KeyResultInStrategy
  , primitiveNode strategyActionId strategyId SStrategy SAction ActionInStrategy
  ]

fixedEdges :: [SomeEdge]
fixedEdges =
  [ typedEdge visionId orientsStrategy strategyId
  , typedEdge strategyId qualifiesNeed needId
  , typedEdge situationId surfacesNeed needId
  , typedEdge strategyId directsIntervention interventionId
  , typedEdge interventionId addressesNeed needId
  , typedEdge interventionId changesSituation situationId
  , typedEdge strategyId framesMeasure measureId
  , typedEdge interventionId setsTargetForMeasure measureId
  , typedEdge measureId measuresSituation situationId
  , typedEdge
      visionObjectiveId
      orientsVisionObjectiveToStrategyObjective
      strategyObjectiveId
  , typedEdge
      strategyDriverId
      groundsStrategyDriverToObjective
      strategyObjectiveId
  , typedEdge
      strategyKeyResultId
      substantiatesStrategyKeyResultObjective
      strategyObjectiveId
  , typedEdge
      strategyActionId
      contributesStrategyActionToKeyResult
      strategyKeyResultId
  ]

pathNodes :: Int -> [SomeNode]
pathNodes ordinal =
  [ primitiveNode needDriver needId SNeed SDriver DriverInNeed
  , primitiveNode needObjective needId SNeed SObjective ObjectiveInNeed
  , primitiveNode
      interventionAction
      interventionId
      SIntervention
      SAction
      ActionInIntervention
  , primitiveNode
      interventionKeyResult
      interventionId
      SIntervention
      SKeyResult
      KeyResultInIntervention
  , performanceDimensionNode dimension measureId
  , primitiveNode measureKpi measureId SMeasure SKPI KPIInMeasure
  , anchorNode situationAnchor
  ]
  where
    needDriver = pathId ordinal "need-driver"
    needObjective = pathId ordinal "need-objective"
    interventionAction = pathId ordinal "intervention-action"
    interventionKeyResult = pathId ordinal "intervention-key-result"
    dimension = pathId ordinal "measure-dimension"
    measureKpi = pathId ordinal "measure-kpi"
    situationAnchor = pathId ordinal "situation-anchor"

pathEdges :: Int -> [SomeEdge]
pathEdges ordinal =
  [ typedEdge
      strategyKeyResultId
      translatesStrategyKeyResultToNeedObjective
      needObjective
  , typedEdge needDriver groundsNeedDriverToObjective needObjective
  , typedEdge
      strategyActionId
      guidesStrategyActionToInterventionAction
      interventionAction
  , typedEdge
      interventionAction
      contributesInterventionActionToKeyResult
      interventionKeyResult
  , typedEdge
      interventionKeyResult
      substantiatesInterventionKeyResultNeedObjective
      needObjective
  , typedEdge
      interventionKeyResult
      contributesInterventionKeyResultToStrategyKeyResult
      strategyKeyResultId
  , typedEdge strategyDriverId indicatesMeasurePerformanceDimension dimension
  , typedEdge
      strategyKeyResultId
      determinesMeasurePerformanceDimension
      dimension
  , typedEdge
      dimension
      (containsPerformanceDimension MeasureMeasurementDimension)
      measureKpi
  , typedEdge interventionKeyResult setsTargetForMeasureKPI measureKpi
  , typedEdge
      situationId
      (constitutedByAnchor SBusinessCapability)
      situationAnchor
  , typedEdge situationAnchor (anchorsNeedDriver SBusinessCapability) needDriver
  , typedEdge
      interventionAction
      (changesAnchor SBusinessCapability)
      situationAnchor
  , typedEdge measureKpi (measuresAnchor SBusinessCapability) situationAnchor
  ]
  where
    needDriver = pathId ordinal "need-driver"
    needObjective = pathId ordinal "need-objective"
    interventionAction = pathId ordinal "intervention-action"
    interventionKeyResult = pathId ordinal "intervention-key-result"
    dimension = pathId ordinal "measure-dimension"
    measureKpi = pathId ordinal "measure-kpi"
    situationAnchor = pathId ordinal "situation-anchor"

unreachableNodes :: Int -> [SomeNode]
unreachableNodes count =
  concatMap
    (\ordinal ->
       [ contextNode (unreachableId ordinal "ethos") SEthos
       , contextNode (unreachableId ordinal "mission") SMission
       , contextNode (unreachableId ordinal "vision") SVision
       , contextNode (unreachableId ordinal "strategy") SStrategy
       , contextNode (unreachableId ordinal "situation") SSituation
       , contextNode (unreachableId ordinal "need") SNeed
       , contextNode (unreachableId ordinal "intervention") SIntervention
       , contextNode (unreachableId ordinal "measure") SMeasure
       ])
    [1 .. count]

strategyRoles :: Map.Map RawNodeId TraceStrategyRoles
strategyRoles =
  Map.singleton
    strategyId
    TraceStrategyRoles
      { traceRoleDriver = strategyDriverId
      , traceRoleObjective = strategyObjectiveId
      , traceRoleKeyResults = [strategyKeyResultId]
      , traceRoleActions = [strategyActionId]
      }

contextNode :: RawNodeId -> SContext context -> SomeNode
contextNode identifier context =
  SomeNode (ContextNode (mkNodeId identifier) context)

primitiveNode ::
     RawNodeId
  -> RawNodeId
  -> SContext context
  -> SPrimitive primitive
  -> Interpretation context primitive
  -> SomeNode
primitiveNode identifier owner context primitive interpretation =
  SomeNode
    (PrimitiveNode
       (mkNodeId identifier)
       (mkNodeId owner)
       context
       primitive
       interpretation)

performanceDimensionNode :: RawNodeId -> RawNodeId -> SomeNode
performanceDimensionNode identifier owner =
  SomeNode
    (PerformanceDimensionNode
       (mkNodeId identifier)
       (mkNodeId owner)
       MeasureMeasurementDimension)

anchorNode :: RawNodeId -> SomeNode
anchorNode identifier =
  SomeNode (AnchorNode (mkNodeId identifier) SBusinessCapability)

typedEdge :: RawNodeId -> Relation from to -> RawNodeId -> SomeEdge
typedEdge from relation to =
  SomeEdge (Edge (mkNodeId from) relation (mkNodeId to))

pathId :: Int -> Text.Text -> RawNodeId
pathId ordinal suffix =
  RawNodeId ("path-" <> Text.pack (show ordinal) <> "-" <> suffix)

unreachableId :: Int -> Text.Text -> RawNodeId
unreachableId ordinal suffix =
  RawNodeId ("unreachable-" <> Text.pack (show ordinal) <> "-" <> suffix)

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

strategyKeyResultId, strategyActionId :: RawNodeId
strategyKeyResultId = RawNodeId "strategy-key-result"

strategyActionId = RawNodeId "strategy-action"
