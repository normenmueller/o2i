{-# LANGUAGE OverloadedStrings #-}

-- | Private contracts for output-sensitive effect-trace traversal.
module O2I.Validation.Trace.Search.Test.Contracts
  ( tests
  ) where

import Data.List (sort)
import O2I.Language.Element (RawNodeId)
import O2I.Validation.Trace.Search
import O2I.Validation.Trace.Search.Test.Fixture
import O2I.Validation.Trace.Search.Test.Scenarios
import Test.Tasty
import Test.Tasty.HUnit

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
        "target Measure and live Situation fan-out grows linearly"
        targetMeasureSituationFanOutTest
    , testCase
        "addressed Need and target Measure fan-out grows linearly"
        addressedNeedMeasureFanOutTest
    , testCase
        "Strategy Action relation fan-out grows linearly"
        strategyActionRelationFanOutTest
    , testCase
        "Need Objective relation fan-out grows linearly"
        needObjectiveRelationFanOutTest
    , testCase
        "spine-specific Anchor relation fan-out grows linearly"
        anchorRelationFanOutTest
    , testCase
        "Vision fan-out expands only complete trace cores"
        visionFanOutTest
    , testCase
        "Intervention Key Results drive complete convergent primitive spines"
        convergentKeyResultFanOutTest
    , testCase
        "three-way work counts only evaluated short-circuit probes"
        threeWayShortCircuitWorkTest
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

targetMeasureSituationFanOutTest :: Assertion
targetMeasureSituationFanOutTest = do
  let zero = searchGraphWithTargetMeasureSituationFanOut 0
      ten = searchGraphWithTargetMeasureSituationFanOut 10
      twenty = searchGraphWithTargetMeasureSituationFanOut 20
      forty = searchGraphWithTargetMeasureSituationFanOut 40
      results = [zero, ten, twenty, forty]
      workVectors =
        map (traversalVector . traceTraversalWork . searchWork) results
  map (length . searchPaths) results @?= [1, 11, 21, 41]
  map (map measureSituationIdentity . searchPaths) results
    @?= map expectedMeasureSituations [0, 10, 20, 40]
  case workVectors of
    [workZero, workTen, workTwenty, workForty] ->
      assertLinearTraversal workZero workTen workTwenty workForty
    _ -> assertFailure "target Measure work-vector arity changed"

addressedNeedMeasureFanOutTest :: Assertion
addressedNeedMeasureFanOutTest = do
  let zero = searchGraphWithAddressedNeedMeasureFanOut 0
      ten = searchGraphWithAddressedNeedMeasureFanOut 10
      twenty = searchGraphWithAddressedNeedMeasureFanOut 20
      forty = searchGraphWithAddressedNeedMeasureFanOut 40
      results = [zero, ten, twenty, forty]
      workVectors =
        map (traversalVector . traceTraversalWork . searchWork) results
  map (length . searchPaths) results @?= [0, 10, 20, 40]
  map (map needMeasureIdentity . searchPaths) results
    @?= map expectedNeedMeasures [0, 10, 20, 40]
  case workVectors of
    [workZero, workTen, workTwenty, workForty] ->
      assertLinearTraversal workZero workTen workTwenty workForty
    _ -> assertFailure "addressed Need work-vector arity changed"

strategyActionRelationFanOutTest :: Assertion
strategyActionRelationFanOutTest = do
  let zero = searchGraphWithStrategyActionFanOut 0
      ten = searchGraphWithStrategyActionFanOut 10
      twenty = searchGraphWithStrategyActionFanOut 20
      forty = searchGraphWithStrategyActionFanOut 40
      results = [zero, ten, twenty, forty]
      workVectors =
        map (traversalVector . traceTraversalWork . searchWork) results
  map (length . searchPaths) results @?= [1, 11, 21, 41]
  map (map strategyActionIdentity . searchPaths) results
    @?= map expectedStrategyActions [0, 10, 20, 40]
  case workVectors of
    [workZero, workTen, workTwenty, workForty] ->
      assertLinearTraversal workZero workTen workTwenty workForty
    _ -> assertFailure "Strategy Action work-vector arity changed"

needObjectiveRelationFanOutTest :: Assertion
needObjectiveRelationFanOutTest = do
  let zero = searchGraphWithNeedObjectiveFanOut 0
      ten = searchGraphWithNeedObjectiveFanOut 10
      twenty = searchGraphWithNeedObjectiveFanOut 20
      forty = searchGraphWithNeedObjectiveFanOut 40
      results = [zero, ten, twenty, forty]
      workVectors =
        map (traversalVector . traceTraversalWork . searchWork) results
  map (length . searchPaths) results @?= [1, 11, 21, 41]
  map (map needObjectiveIdentity . searchPaths) results
    @?= map expectedNeedObjectives [0, 10, 20, 40]
  case workVectors of
    [workZero, workTen, workTwenty, workForty] ->
      assertLinearTraversal workZero workTen workTwenty workForty
    _ -> assertFailure "Need Objective work-vector arity changed"

anchorRelationFanOutTest :: Assertion
anchorRelationFanOutTest = do
  let zero = searchGraphWithAnchorRelationFanOut 0
      ten = searchGraphWithAnchorRelationFanOut 10
      twenty = searchGraphWithAnchorRelationFanOut 20
      forty = searchGraphWithAnchorRelationFanOut 40
      results = [zero, ten, twenty, forty]
      workVectors =
        map (traversalVector . traceTraversalWork . searchWork) results
  map (length . searchPaths) results @?= [1, 11, 21, 41]
  map (map anchorRelationIdentity . searchPaths) results
    @?= map expectedAnchorRelations [0, 10, 20, 40]
  case workVectors of
    [workZero, workTen, workTwenty, workForty] ->
      assertLinearTraversal workZero workTen workTwenty workForty
    _ -> assertFailure "Anchor relation work-vector arity changed"

visionFanOutTest :: Assertion
visionFanOutTest = do
  let counts = [0, 10, 20, 40]
      normal = map (`searchGraphWithVisionFanOut` id) counts
      reversed = map (`searchGraphWithVisionFanOut` reverse) counts
      workVectors =
        map (traversalVector . traceTraversalWork . searchWork) normal
  map searchPaths reversed @?= map searchPaths normal
  map searchWork reversed @?= map searchWork normal
  map (length . searchPaths) normal @?= [1, 11, 21, 41]
  map traceIdentityConstituents normal
    @?= map expectedVisionFanOutIdentities counts
  case workVectors of
    [workZero, workTen, workTwenty, workForty] ->
      assertLinearTraversal workZero workTen workTwenty workForty
    _ -> assertFailure "Vision fan-out work-vector arity changed"

convergentKeyResultFanOutTest :: Assertion
convergentKeyResultFanOutTest = do
  let counts = [0, 10, 20, 40]
      normal = map (`searchGraphWithConvergentKeyResults` id) counts
      reversed = map (`searchGraphWithConvergentKeyResults` reverse) counts
      workVectors =
        map (traversalVector . traceTraversalWork . searchWork) normal
      buildVectors =
        map (indexBuildVector . traceIndexBuildWork . searchWork) normal
  map searchPaths reversed @?= map searchPaths normal
  map searchWork reversed @?= map searchWork normal
  map traceIdentityConstituents normal
    @?= map expectedConvergentKeyResultIdentities counts
  map (length . searchPaths) normal @?= [1, 11, 21, 41]
  case workVectors of
    [workZero, workTen, workTwenty, workForty] ->
      assertLinearTraversal workZero workTen workTwenty workForty
    _ -> assertFailure "convergent Key Result work-vector arity changed"
  case buildVectors of
    [workZero, workTen, workTwenty, workForty] ->
      assertLinearTraversal workZero workTen workTwenty workForty
    _ -> assertFailure "convergent Key Result build-vector arity changed"

threeWayShortCircuitWorkTest :: Assertion
threeWayShortCircuitWorkTest = do
  let firstGuardRejected = searchGraphWithFirstThreeWayGuardRejection
      secondGuardRejected = searchGraphWithSecondThreeWayGuardRejection
      firstWork = traceTraversalWork (searchWork firstGuardRejected)
      secondWork = traceTraversalWork (searchWork secondGuardRejected)
  searchPaths firstGuardRejected @?= searchPaths secondGuardRejected
  traceIndexBuildWork (searchWork firstGuardRejected)
    @?= traceIndexBuildWork (searchWork secondGuardRejected)
  secondWork
    @?= firstWork
          {traceEdgeMembershipProbes = traceEdgeMembershipProbes firstWork + 1}

assertLinearTraversal :: [Int] -> [Int] -> [Int] -> [Int] -> Assertion
assertLinearTraversal workZero workTen workTwenty workForty = do
  assertAffineTraversal workZero workTen workTwenty workForty
  let tenFanOutWork = zipWith (-) workTen workZero
  assertBool "adversarial facts did not register work" (any (> 0) tenFanOutWork)

assertAffineTraversal :: [Int] -> [Int] -> [Int] -> [Int] -> Assertion
assertAffineTraversal workZero workTen workTwenty workForty = do
  let tenFanOutWork = zipWith (-) workTen workZero
  zipWith (-) workTwenty workTen @?= tenFanOutWork
  zipWith (-) workForty workTwenty @?= map (* 2) tenFanOutWork
  assertBool
    "at least one traversal-work component decreased"
    (all (>= 0) tenFanOutWork)

expectedVisionFanOutIdentities :: Int -> [[RawNodeId]]
expectedVisionFanOutIdentities count =
  map
    (\(vision, objective) ->
       vision : objective : drop 2 expectedBasePathIdentity)
    (sort
       ((visionId, visionObjectiveId)
          : [ ( visionFanOutId ordinal "vision"
              , visionFanOutId ordinal "vision-objective")
            | ordinal <- [1 .. count]
            ]))

expectedConvergentKeyResultIdentities :: Int -> [[RawNodeId]]
expectedConvergentKeyResultIdentities count =
  map
    (\(strategyKeyResult, strategyAction, needObjective, interventionKeyResult) ->
       [ visionId
       , visionObjectiveId
       , strategyId
       , strategyDriverId
       , strategyObjectiveId
       , strategyKeyResult
       , strategyAction
       , needId
       , pathId 1 "need-driver"
       , needObjective
       , interventionId
       , pathId 1 "intervention-action"
       , interventionKeyResult
       , measureId
       , pathId 1 "measure-dimension"
       , pathId 1 "measure-kpi"
       , situationId
       , pathId 1 "situation-anchor"
       ])
    (sort
       (( strategyKeyResultId
        , strategyActionId
        , pathId 1 "need-objective"
        , pathId 1 "intervention-key-result")
          : [ ( convergentStrategyKeyResultId ordinal
              , convergentStrategyActionId ordinal
              , convergentNeedObjectiveId ordinal
              , convergentInterventionKeyResultId ordinal)
            | ordinal <- [1 .. count]
            ]))

expectedBasePathIdentity :: [RawNodeId]
expectedBasePathIdentity =
  [ visionId
  , visionObjectiveId
  , strategyId
  , strategyDriverId
  , strategyObjectiveId
  , strategyKeyResultId
  , strategyActionId
  , needId
  , pathId 1 "need-driver"
  , pathId 1 "need-objective"
  , interventionId
  , pathId 1 "intervention-action"
  , pathId 1 "intervention-key-result"
  , measureId
  , pathId 1 "measure-dimension"
  , pathId 1 "measure-kpi"
  , situationId
  , pathId 1 "situation-anchor"
  ]

expectedLiveSituations :: Int -> [RawNodeId]
expectedLiveSituations count =
  sort (situationId : [liveSituationId ordinal | ordinal <- [1 .. count]])

expectedMeasureSituations :: Int -> [(RawNodeId, RawNodeId)]
expectedMeasureSituations count =
  sort
    ((measureId, situationId)
       : [ ( targetMeasureSituationId ordinal "measure"
           , targetMeasureSituationId ordinal "situation")
         | ordinal <- [1 .. count]
         ])

measureSituationIdentity :: TracePath -> (RawNodeId, RawNodeId)
measureSituationIdentity path = (pathMeasure path, pathSituation path)

expectedNeedMeasures :: Int -> [(RawNodeId, RawNodeId, RawNodeId)]
expectedNeedMeasures count =
  sort
    [ ( needMeasureId ordinal "strategy"
      , needMeasureId ordinal "need"
      , needMeasureId ordinal "measure")
    | ordinal <- [1 .. count]
    ]

needMeasureIdentity :: TracePath -> (RawNodeId, RawNodeId, RawNodeId)
needMeasureIdentity path = (pathStrategy path, pathNeed path, pathMeasure path)

expectedStrategyActions :: Int -> [(RawNodeId, RawNodeId)]
expectedStrategyActions count =
  sort
    ((strategyKeyResultId, strategyActionId)
       : [ ( strategyActionFanOutId ordinal "strategy-key-result"
           , strategyActionFanOutId ordinal "strategy-action")
         | ordinal <- [1 .. count]
         ])

strategyActionIdentity :: TracePath -> (RawNodeId, RawNodeId)
strategyActionIdentity path =
  (pathStrategyKeyResult path, pathStrategyAction path)

expectedNeedObjectives :: Int -> [(RawNodeId, RawNodeId)]
expectedNeedObjectives count =
  sort
    ((strategyKeyResultId, pathId 1 "need-objective")
       : [ ( needObjectiveFanOutId ordinal "strategy-key-result"
           , needObjectiveFanOutId ordinal "need-objective")
         | ordinal <- [1 .. count]
         ])

needObjectiveIdentity :: TracePath -> (RawNodeId, RawNodeId)
needObjectiveIdentity path =
  (pathStrategyKeyResult path, pathNeedObjective path)

expectedAnchorRelations :: Int -> [(RawNodeId, RawNodeId)]
expectedAnchorRelations count =
  sort
    ((pathId 1 "measure-kpi", pathId 1 "situation-anchor")
       : [ ( anchorRelationFanOutId ordinal "measure-kpi"
           , anchorRelationFanOutId ordinal "situation-anchor")
         | ordinal <- [1 .. count]
         ])

anchorRelationIdentity :: TracePath -> (RawNodeId, RawNodeId)
anchorRelationIdentity path = (pathMeasureKPI path, pathSituationAnchor path)

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

indexBuildVector :: TraceIndexBuildWork -> [Int]
indexBuildVector work =
  [traceIndexedNodeOccurrences work, traceIndexedEdgeOccurrences work]
