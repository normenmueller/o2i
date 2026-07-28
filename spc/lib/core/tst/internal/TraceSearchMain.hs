{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Private regression tests for output-sensitive effect-trace traversal.
module Main where

import Data.List (sort)
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
        "complete mismatched spines preserve one trace with linear work"
        mismatchedSpineFanOutTest
    , testCase
        "unconstituted anchors and live Situations grow linearly"
        unconstitutedAnchorFanOutTest
    , testCase
        "Strategy and Situation fan-out preserves one trace with linear work"
        strategySituationFanOutTest
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

mismatchedSpineFanOutTest :: Assertion
mismatchedSpineFanOutTest = do
  let zero = searchGraphWithMismatchedSpines 0
      ten = searchGraphWithMismatchedSpines 10
      twenty = searchGraphWithMismatchedSpines 20
      forty = searchGraphWithMismatchedSpines 40
      identity = traceIdentityConstituents zero
      workZero = traversalVector (traceTraversalWork (searchWork zero))
      workTen = traversalVector (traceTraversalWork (searchWork ten))
      workTwenty = traversalVector (traceTraversalWork (searchWork twenty))
      workForty = traversalVector (traceTraversalWork (searchWork forty))
  map traceIdentityConstituents [ten, twenty, forty] @?= replicate 3 identity
  map searchPaths [ten, twenty, forty] @?= replicate 3 (searchPaths zero)
  map (length . searchPaths) [zero, ten, twenty, forty] @?= replicate 4 1
  assertLinearTraversal workZero workTen workTwenty workForty

unconstitutedAnchorFanOutTest :: Assertion
unconstitutedAnchorFanOutTest = do
  let zero = searchGraphWithUnconstitutedAnchors 0
      ten = searchGraphWithUnconstitutedAnchors 10
      twenty = searchGraphWithUnconstitutedAnchors 20
      forty = searchGraphWithUnconstitutedAnchors 40
      workZero = traversalVector (traceTraversalWork (searchWork zero))
      workTen = traversalVector (traceTraversalWork (searchWork ten))
      workTwenty = traversalVector (traceTraversalWork (searchWork twenty))
      workForty = traversalVector (traceTraversalWork (searchWork forty))
  map (length . searchPaths) [zero, ten, twenty, forty] @?= [1, 11, 21, 41]
  map (map pathSituation . searchPaths) [zero, ten, twenty, forty]
    @?= map expectedLiveSituations [0, 10, 20, 40]
  assertBool
    "an unconstituted anchor produced an effect trace"
    (all
       ((== pathId 1 "situation-anchor") . pathSituationAnchor)
       (concatMap searchPaths [zero, ten, twenty, forty]))
  assertLinearTraversal workZero workTen workTwenty workForty

strategySituationFanOutTest :: Assertion
strategySituationFanOutTest = do
  let zero = searchGraphWithStrategySituationFanOut 0
      ten = searchGraphWithStrategySituationFanOut 10
      twenty = searchGraphWithStrategySituationFanOut 20
      forty = searchGraphWithStrategySituationFanOut 40
      identity = traceIdentityConstituents zero
      workZero = traversalVector (traceTraversalWork (searchWork zero))
      workTen = traversalVector (traceTraversalWork (searchWork ten))
      workTwenty = traversalVector (traceTraversalWork (searchWork twenty))
      workForty = traversalVector (traceTraversalWork (searchWork forty))
  map traceIdentityConstituents [ten, twenty, forty] @?= replicate 3 identity
  map searchPaths [ten, twenty, forty] @?= replicate 3 (searchPaths zero)
  map (length . searchPaths) [zero, ten, twenty, forty] @?= replicate 4 1
  assertLinearTraversal workZero workTen workTwenty workForty

assertLinearTraversal :: [Int] -> [Int] -> [Int] -> [Int] -> Assertion
assertLinearTraversal workZero workTen workTwenty workForty = do
  let tenFanOutWork = zipWith (-) workTen workZero
  zipWith (-) workTwenty workTen @?= tenFanOutWork
  zipWith (-) workForty workTwenty @?= map (* 2) tenFanOutWork
  assertBool
    "at least one traversal-work component decreased"
    (all (>= 0) tenFanOutWork)
  assertBool
    "adversarial facts did not register traversal work"
    (any (> 0) tenFanOutWork)

expectedLiveSituations :: Int -> [RawNodeId]
expectedLiveSituations count =
  sort (situationId : [liveSituationId ordinal | ordinal <- [1 .. count]])

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

searchGraphWithMismatchedSpines :: Int -> TraceSearchResult
searchGraphWithMismatchedSpines fanOut =
  searchGraphWithAdditions
    (concatMap mismatchedSpineNodes [1 .. fanOut])
    (concatMap mismatchedSpineEdges [1 .. fanOut])

searchGraphWithUnconstitutedAnchors :: Int -> TraceSearchResult
searchGraphWithUnconstitutedAnchors fanOut =
  searchGraphWithAdditions
    (concatMap unconstitutedAnchorNodes [1 .. fanOut])
    (concatMap unconstitutedAnchorEdges [1 .. fanOut])

searchGraphWithStrategySituationFanOut :: Int -> TraceSearchResult
searchGraphWithStrategySituationFanOut fanOut =
  deriveTracePaths
    (mkGraph
       (fixedNodes
          ++ pathNodes 1
          ++ concatMap strategySituationNodes [1 .. fanOut])
       (fixedEdges
          ++ pathEdges 1
          ++ concatMap strategySituationEdges [1 .. fanOut]))
    (strategyRolesWithFanOut fanOut)

searchGraphWithAdditions :: [SomeNode] -> [SomeEdge] -> TraceSearchResult
searchGraphWithAdditions nodes edges =
  deriveTracePaths
    (mkGraph
       (fixedNodes ++ pathNodes 1 ++ nodes)
       (fixedEdges ++ pathEdges 1 ++ edges))
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
pathNodes ordinal = spineNodes (pathId ordinal)

pathEdges :: Int -> [SomeEdge]
pathEdges ordinal =
  spineEdges identify
    ++ [ typedEdge
           situationId
           (constitutedByAnchor SBusinessCapability)
           (identify "situation-anchor")
       ]
  where
    identify = pathId ordinal

spineNodes :: (Text.Text -> RawNodeId) -> [SomeNode]
spineNodes identify =
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
    needDriver = identify "need-driver"
    needObjective = identify "need-objective"
    interventionAction = identify "intervention-action"
    interventionKeyResult = identify "intervention-key-result"
    dimension = identify "measure-dimension"
    measureKpi = identify "measure-kpi"
    situationAnchor = identify "situation-anchor"

spineEdges :: (Text.Text -> RawNodeId) -> [SomeEdge]
spineEdges = spineEdgesFor strategyDriverId strategyKeyResultId strategyActionId

spineEdgesFor ::
     RawNodeId
  -> RawNodeId
  -> RawNodeId
  -> (Text.Text -> RawNodeId)
  -> [SomeEdge]
spineEdgesFor strategyDriver strategyKeyResult strategyAction identify =
  [ typedEdge
      strategyKeyResult
      translatesStrategyKeyResultToNeedObjective
      needObjective
  , typedEdge needDriver groundsNeedDriverToObjective needObjective
  , typedEdge
      strategyAction
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
      strategyKeyResult
  , typedEdge strategyDriver indicatesMeasurePerformanceDimension dimension
  , typedEdge strategyKeyResult determinesMeasurePerformanceDimension dimension
  , typedEdge
      dimension
      (containsPerformanceDimension MeasureMeasurementDimension)
      measureKpi
  , typedEdge interventionKeyResult setsTargetForMeasureKPI measureKpi
  , typedEdge situationAnchor (anchorsNeedDriver SBusinessCapability) needDriver
  , typedEdge
      interventionAction
      (changesAnchor SBusinessCapability)
      situationAnchor
  , typedEdge measureKpi (measuresAnchor SBusinessCapability) situationAnchor
  ]
  where
    needDriver = identify "need-driver"
    needObjective = identify "need-objective"
    interventionAction = identify "intervention-action"
    interventionKeyResult = identify "intervention-key-result"
    dimension = identify "measure-dimension"
    measureKpi = identify "measure-kpi"
    situationAnchor = identify "situation-anchor"

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

mismatchedSpineNodes :: Int -> [SomeNode]
mismatchedSpineNodes ordinal =
  spineNodes identify
    ++ [contextNode situation SSituation, anchorNode constitutingAnchor]
  where
    identify = mismatchedId ordinal
    situation = identify "situation"
    constitutingAnchor = identify "constituting-anchor"

mismatchedSpineEdges :: Int -> [SomeEdge]
mismatchedSpineEdges ordinal =
  spineEdges identify
    ++ macroSituationEdges situation
    ++ [ typedEdge
           situation
           (constitutedByAnchor SBusinessCapability)
           constitutingAnchor
       ]
  where
    identify = mismatchedId ordinal
    situation = identify "situation"
    constitutingAnchor = identify "constituting-anchor"

unconstitutedAnchorNodes :: Int -> [SomeNode]
unconstitutedAnchorNodes ordinal =
  spineNodes (unconstitutedId ordinal)
    ++ [contextNode (liveSituationId ordinal) SSituation]

unconstitutedAnchorEdges :: Int -> [SomeEdge]
unconstitutedAnchorEdges ordinal =
  spineEdges (unconstitutedId ordinal)
    ++ macroSituationEdges situation
    ++ [ typedEdge
           situation
           (constitutedByAnchor SBusinessCapability)
           (pathId 1 "situation-anchor")
       ]
  where
    situation = liveSituationId ordinal

strategySituationNodes :: Int -> [SomeNode]
strategySituationNodes ordinal =
  [ contextNode vision SVision
  , contextNode strategy SStrategy
  , primitiveNode visionObjective vision SVision SObjective ObjectiveInVision
  , primitiveNode driver strategy SStrategy SDriver DriverInStrategy
  , primitiveNode
      strategyObjective
      strategy
      SStrategy
      SObjective
      ObjectiveInStrategy
  , primitiveNode
      strategyKeyResult
      strategy
      SStrategy
      SKeyResult
      KeyResultInStrategy
  , primitiveNode strategyAction strategy SStrategy SAction ActionInStrategy
  , contextNode situation SSituation
  , anchorNode constitutingAnchor
  ]
  where
    identify = strategySituationId ordinal
    vision = identify "vision"
    strategy = identify "strategy"
    visionObjective = identify "vision-objective"
    driver = identify "strategy-driver"
    strategyObjective = identify "strategy-objective"
    strategyKeyResult = identify "strategy-key-result"
    strategyAction = identify "strategy-action"
    situation = identify "situation"
    constitutingAnchor = identify "constituting-anchor"

strategySituationEdges :: Int -> [SomeEdge]
strategySituationEdges ordinal =
  [ typedEdge vision orientsStrategy strategy
  , typedEdge strategy qualifiesNeed needId
  , typedEdge strategy directsIntervention interventionId
  , typedEdge strategy framesMeasure measureId
  , typedEdge
      visionObjective
      orientsVisionObjectiveToStrategyObjective
      strategyObjective
  , typedEdge driver groundsStrategyDriverToObjective strategyObjective
  , typedEdge
      strategyKeyResult
      substantiatesStrategyKeyResultObjective
      strategyObjective
  , typedEdge
      strategyAction
      contributesStrategyActionToKeyResult
      strategyKeyResult
  , typedEdge
      strategyKeyResult
      translatesStrategyKeyResultToNeedObjective
      (pathId 1 "need-objective")
  , typedEdge
      strategyAction
      guidesStrategyActionToInterventionAction
      (pathId 1 "intervention-action")
  , typedEdge
      (pathId 1 "intervention-key-result")
      contributesInterventionKeyResultToStrategyKeyResult
      strategyKeyResult
  , typedEdge
      driver
      indicatesMeasurePerformanceDimension
      (pathId 1 "measure-dimension")
  ]
    ++ macroSituationEdges situation
    ++ [ typedEdge
           situation
           (constitutedByAnchor SBusinessCapability)
           constitutingAnchor
       ]
  where
    identify = strategySituationId ordinal
    vision = identify "vision"
    strategy = identify "strategy"
    visionObjective = identify "vision-objective"
    driver = identify "strategy-driver"
    strategyObjective = identify "strategy-objective"
    strategyKeyResult = identify "strategy-key-result"
    strategyAction = identify "strategy-action"
    situation = identify "situation"
    constitutingAnchor = identify "constituting-anchor"

macroSituationEdges :: RawNodeId -> [SomeEdge]
macroSituationEdges situation =
  [ typedEdge interventionId changesSituation situation
  , typedEdge situation surfacesNeed needId
  , typedEdge measureId measuresSituation situation
  ]

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

strategyRolesWithFanOut :: Int -> Map.Map RawNodeId TraceStrategyRoles
strategyRolesWithFanOut count =
  Map.union
    strategyRoles
    (Map.fromList
       [ ( strategySituationId ordinal "strategy"
         , TraceStrategyRoles
             { traceRoleDriver = strategySituationId ordinal "strategy-driver"
             , traceRoleObjective =
                 strategySituationId ordinal "strategy-objective"
             , traceRoleKeyResults =
                 [strategySituationId ordinal "strategy-key-result"]
             , traceRoleActions =
                 [strategySituationId ordinal "strategy-action"]
             })
       | ordinal <- [1 .. count]
       ])

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

mismatchedId :: Int -> Text.Text -> RawNodeId
mismatchedId ordinal suffix =
  RawNodeId ("mismatched-" <> Text.pack (show ordinal) <> "-" <> suffix)

unconstitutedId :: Int -> Text.Text -> RawNodeId
unconstitutedId ordinal suffix =
  RawNodeId ("unconstituted-" <> Text.pack (show ordinal) <> "-" <> suffix)

liveSituationId :: Int -> RawNodeId
liveSituationId ordinal =
  RawNodeId ("live-situation-" <> Text.pack (show ordinal))

strategySituationId :: Int -> Text.Text -> RawNodeId
strategySituationId ordinal suffix =
  RawNodeId ("strategy-situation-" <> Text.pack (show ordinal) <> "-" <> suffix)

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
