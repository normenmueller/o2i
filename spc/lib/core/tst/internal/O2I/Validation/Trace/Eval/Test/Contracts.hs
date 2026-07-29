{-# LANGUAGE DataKinds #-}

-- | Private semantic and operation-bound effect-trace evaluation contracts.
module O2I.Validation.Trace.Eval.Test.Contracts
  ( tests
  ) where

import Data.List (sort)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import O2I.Language.Element
import O2I.Validation.Relational.Eval
import O2I.Validation.Trace.Eval
import O2I.Validation.Trace.Eval.Test.Fixture
import O2I.Validation.Trace.Eval.Test.Oracle
import O2I.Validation.Trace.Eval.Test.Scenarios
import O2I.Validation.Trace.Types
import Test.Tasty
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "private typed effect-trace evaluator"
    [ testCase "empty trace space reports exact work" emptyWorkTest
    , testCase "complete baseline reports exact work" baselineWorkTest
    , testCase
        "one unconnected Intervention changes only domain enumeration"
        interventionEnumerationDeltaTest
    , testCase
        "one additional anchor records plan, trace, and coverage work"
        additionalAnchorDeltaTest
    , testCase "all four anchor kinds construct typed traces" allAnchorKindsTest
    , testCase
        "addressed lookup and typed coverage remain exact"
        addressedCoverageTest
    , testCase
        "one shared input permutation preserves every Eval observation"
        inputOrderTest
    , testCase "same-kind anchor fan-out remains affine" anchorFanOutWorkTest
    , testCase
        "independent oracle agrees across the semantic scenario matrix"
        semanticOracleMatrixTest
    , testCase
        "unreachable Contexts preserve traces with affine work"
        unreachableContextsTest
    , testCase
        "mismatched complete spines preserve traces with affine work"
        mismatchedSpinesTest
    , testCase
        "unconstituted evidence-bearing anchors never produce traces"
        unconstitutedAnchorFanOutTest
    , testCase
        "Strategy and Situation fan-out remains affine"
        strategySituationFanOutTest
    , testCase
        "Measure and Situation fan-out emits only complete traces"
        targetMeasureSituationFanOutTest
    , testCase
        "addressed Need and Measure paths remain ordered and covered"
        addressedNeedMeasureFanOutTest
    , testCase
        "Strategy Action alternatives grow traces affinely"
        strategyActionFanOutTest
    , testCase
        "Need Objective alternatives grow traces affinely"
        needObjectiveFanOutTest
    , testCase
        "anchor relation alternatives grow traces affinely"
        anchorRelationFanOutTest
    , testCase "Vision alternatives grow traces affinely" visionFanOutTest
    , testCase
        "convergent Key Results grow traces affinely"
        convergentKeyResultFanOutTest
    , testCase
        "constituent evaluation short-circuits failed paths"
        shortCircuitWorkTest
    , testCase
        "complete relevant paths have constant incremental work"
        relevantPathGrowthTest
    ]

emptyWorkTest :: Assertion
emptyWorkTest =
  withEvaluation emptyEvaluation $ \result ->
    traceEvaluationWork result @?= expectedEmptyWork

baselineWorkTest :: Assertion
baselineWorkTest =
  withEvaluation baselineEvaluation $ \result ->
    traceEvaluationWork result @?= expectedBaselineWork

interventionEnumerationDeltaTest :: Assertion
interventionEnumerationDeltaTest =
  withEvaluation baselineEvaluation $ \baseline ->
    withEvaluation extraInterventionEvaluation $ \expanded -> do
      traceEvaluationWork expanded
        @?= (traceEvaluationWork baseline)
              { traceInterventionDomainValuesRead =
                  traceInterventionDomainValuesRead
                    (traceEvaluationWork baseline)
                    + 1
              }
      map unNodeId (traceEvaluationInterventions expanded)
        @?= [interventionId, extraInterventionId]

additionalAnchorDeltaTest :: Assertion
additionalAnchorDeltaTest =
  withEvaluation additionalProcessAnchorEvaluation $ \result ->
    traceEvaluationWork result @?= expectedAdditionalAnchorWork

allAnchorKindsTest :: Assertion
allAnchorKindsTest =
  withEvaluation allAnchorKindsEvaluation $ \result -> do
    length (traceEvaluationTraces result) @?= 4
    sort
      (map
         (situationAnchorRefKind . traceSituationAnchor)
         (traceEvaluationTraces result))
      @?= [BusinessCapability, BusinessProcess, BusinessObject, ValueStream]
    traceAnchorDomainsInspected (traceEvaluationWork result) @?= 4
    traceEmptyAnchorDomainsSkipped (traceEvaluationWork result) @?= 0
    traceConstituentPlansExecuted (traceEvaluationWork result) @?= 4

addressedCoverageTest :: Assertion
addressedCoverageTest =
  withEvaluation extraInterventionEvaluation $ \result ->
    case traceEvaluationInterventions result of
      [connected, unconnected] ->
        case traceEvaluationAddressedNeedsFor result connected of
          [need] -> do
            assertBool
              "complete trace did not cover its typed pair"
              (traceEvaluationCovers result (AddressedNeed connected need))
            traceEvaluationAddressedNeedsFor result unconnected @?= []
          needs ->
            assertFailure
              ("expected one addressed Need, got " ++ show (length needs))
      interventions ->
        assertFailure
          ("expected two Interventions, got " ++ show (length interventions))

inputOrderTest :: Assertion
inputOrderTest = do
  let scenario = addressedNeedMeasureScenario 8
  baseline <- requireScenario scenario
  permuted <- requireScenario (permuteScenario scenario)
  traceEvaluationInterventions permuted
    @?= traceEvaluationInterventions baseline
  addressedPairs permuted @?= addressedPairs baseline
  traceEvaluationTraces permuted @?= traceEvaluationTraces baseline
  traceEvaluationTraceMap permuted @?= traceEvaluationTraceMap baseline
  coverageObservations permuted @?= coverageObservations baseline
  traceEvaluationWork permuted @?= traceEvaluationWork baseline

anchorFanOutWorkTest :: Assertion
anchorFanOutWorkTest =
  withEvaluations (map processAnchorFanOutEvaluation [10, 20, 30, 40]) $ \results -> do
    map (length . traceEvaluationTraces) results @?= [11, 21, 31, 41]
    case map (traceWorkVector . traceEvaluationWork) results of
      [ten, twenty, thirty, forty] -> do
        zipWith (-) twenty ten @?= zipWith (-) thirty twenty
        zipWith (-) thirty twenty @?= zipWith (-) forty thirty
      _ -> assertFailure "anchor fan-out fixture arity changed"

semanticOracleMatrixTest :: Assertion
semanticOracleMatrixTest =
  mapM_
    assertScenarioMatchesOracle
    [ baselineScenario
    , allAnchorKindsScenario
    , anchorFanOutScenario 2
    , unconstitutedAnchorFanOutScenario 2
    , unreachableContextsScenario 2
    , mismatchedSpinesScenario 2
    , strategySituationFanOutScenario 2
    , targetMeasureSituationScenario 2
    , addressedNeedMeasureScenario 2
    , strategyActionFanOutScenario 2
    , needObjectiveFanOutScenario 2
    , visionFanOutScenario 2
    , convergentKeyResultScenario 2
    ]

unreachableContextsTest :: Assertion
unreachableContextsTest = do
  results <- evaluateFamily unreachableContextsScenario
  assertOracleFamily unreachableContextsScenario results
  map (length . traceEvaluationTraces) results @?= replicate 4 1
  map (length . traceEvaluationInterventions) results @?= [1, 3, 5, 9]
  assertAffineWork results

mismatchedSpinesTest :: Assertion
mismatchedSpinesTest = do
  results <- evaluateFamily mismatchedSpinesScenario
  assertOracleFamily mismatchedSpinesScenario results
  map (length . traceEvaluationTraces) results @?= replicate 4 1
  map addressedPairCount results @?= [1, 3, 5, 9]
  map (length . filter (not . snd) . coverageObservations) results
    @?= [0, 2, 4, 8]
  assertAffineWork results

unconstitutedAnchorFanOutTest :: Assertion
unconstitutedAnchorFanOutTest = do
  results <- evaluateFamily unconstitutedAnchorFanOutScenario
  assertOracleFamily unconstitutedAnchorFanOutScenario results
  map (length . traceEvaluationTraces) results @?= replicate 4 1
  sequence_
    [ Set.intersection
      (Set.fromList (unconstitutedAnchorIds size))
      (Set.fromList
         (map
            (situationAnchorRefId . traceSituationAnchor)
            (traceEvaluationTraces result)))
      @?= Set.empty
    | (size, result) <- zip scenarioSizes results
    ]
  assertAffineWorkAllowZero results

strategySituationFanOutTest :: Assertion
strategySituationFanOutTest = do
  results <- evaluateFamily strategySituationFanOutScenario
  assertOracleFamily strategySituationFanOutScenario results
  map (length . traceEvaluationTraces) results @?= replicate 4 1
  case results of
    first:_ ->
      map traceEvaluationWork results
        @?= replicate 4 (traceEvaluationWork first)
    [] -> assertFailure "scenario family arity changed"

targetMeasureSituationFanOutTest :: Assertion
targetMeasureSituationFanOutTest = do
  results <- evaluateFamily targetMeasureSituationScenario
  assertOracleFamily targetMeasureSituationScenario results
  map (length . traceEvaluationTraces) results @?= [1, 3, 5, 9]
  assertAffineWork results

addressedNeedMeasureFanOutTest :: Assertion
addressedNeedMeasureFanOutTest = do
  results <- evaluateFamily addressedNeedMeasureScenario
  assertOracleFamily addressedNeedMeasureScenario results
  map (length . traceEvaluationTraces) results @?= [1, 3, 5, 9]
  map addressedPairCount results @?= [1, 3, 5, 9]
  mapM_ assertAddressedOrder results
  assertAffineWork results

strategyActionFanOutTest :: Assertion
strategyActionFanOutTest = assertTraceFanOut strategyActionFanOutScenario

needObjectiveFanOutTest :: Assertion
needObjectiveFanOutTest = assertTraceFanOut needObjectiveFanOutScenario

anchorRelationFanOutTest :: Assertion
anchorRelationFanOutTest = do
  results <- evaluateFamily anchorFanOutScenario
  assertOracleFamily anchorFanOutScenario results
  map (length . traceEvaluationTraces) results @?= [1, 3, 5, 9]
  assertAffinePositiveWork results

visionFanOutTest :: Assertion
visionFanOutTest = assertTraceFanOut visionFanOutScenario

convergentKeyResultFanOutTest :: Assertion
convergentKeyResultFanOutTest = assertTraceFanOut convergentKeyResultScenario

shortCircuitWorkTest :: Assertion
shortCircuitWorkTest = do
  early <- requireScenario shortCircuitEarlyScenario
  late <- requireScenario shortCircuitLateScenario
  traceEvaluationTraces early @?= []
  traceEvaluationTraces late @?= []
  evaluationWorkVector
    (traceConstituentEvaluationWork (traceEvaluationWork early))
    @?= [1, 18, 4, 4, 0, 0, 0, 0, 0, 0, 0]
  evaluationWorkVector
    (traceConstituentEvaluationWork (traceEvaluationWork late))
    @?= [11, 198, 31, 31, 10, 28, 10, 0, 0, 0, 0]

relevantPathGrowthTest :: Assertion
relevantPathGrowthTest = do
  results <- evaluateFamily addressedNeedMeasureScenario
  assertAffineWork results
  map (length . traceEvaluationTraces) results @?= [1, 3, 5, 9]

assertTraceFanOut :: (Int -> TraceScenario) -> Assertion
assertTraceFanOut scenarioFor = do
  results <- evaluateFamily scenarioFor
  assertOracleFamily scenarioFor results
  map (length . traceEvaluationTraces) results @?= [1, 3, 5, 9]
  assertAffineWork results

scenarioSizes :: [Int]
scenarioSizes = [0, 2, 4, 8]

evaluateFamily :: (Int -> TraceScenario) -> IO [TraceEvaluationResult]
evaluateFamily scenarioFor =
  traverse (requireScenario . scenarioFor) scenarioSizes

assertOracleFamily ::
     (Int -> TraceScenario) -> [TraceEvaluationResult] -> Assertion
assertOracleFamily scenarioFor results =
  sequence_
    [ assertResultMatchesOracle (scenarioFor size) result
    | (size, result) <- zip scenarioSizes results
    ]

assertScenarioMatchesOracle :: TraceScenario -> Assertion
assertScenarioMatchesOracle scenario = do
  result <- requireScenario scenario
  assertResultMatchesOracle scenario result

assertResultMatchesOracle :: TraceScenario -> TraceEvaluationResult -> Assertion
assertResultMatchesOracle scenario result = do
  map unNodeId (traceEvaluationInterventions result)
    @?= oracleInterventions graph
  addressedPairs result @?= oracleAddressedNeeds graph
  map traceSignature (traceEvaluationTraces result) @?= expectedTraces
  Map.size (traceEvaluationTraceMap result) @?= length expectedTraces
  assertCoverageMatchesOracle scenario result expectedTraces
  where
    graph = traceScenarioGraph scenario
    formulations = traceScenarioFormulations scenario
    expectedTraces = oracleTraces graph formulations

traceSignature :: EffectTrace -> OracleTrace
traceSignature trace =
  OracleTrace
    { oracleTraceVision = contextRefId (traceVision trace)
    , oracleTraceVisionObjective = unNodeId (traceVisionObjective trace)
    , oracleTraceStrategy = contextRefId (traceStrategy trace)
    , oracleTraceStrategyDriver = unNodeId (traceStrategyDriver trace)
    , oracleTraceStrategyObjective = unNodeId (traceStrategyObjective trace)
    , oracleTraceStrategyKeyResult = unNodeId (traceStrategyKeyResult trace)
    , oracleTraceStrategyAction = unNodeId (traceStrategyAction trace)
    , oracleTraceNeed = contextRefId (traceNeed trace)
    , oracleTraceNeedDriver = unNodeId (traceNeedDriver trace)
    , oracleTraceNeedObjective = unNodeId (traceNeedObjective trace)
    , oracleTraceIntervention = contextRefId (traceIntervention trace)
    , oracleTraceInterventionAction = unNodeId (traceInterventionAction trace)
    , oracleTraceInterventionKeyResult =
        unNodeId (traceInterventionKeyResult trace)
    , oracleTraceMeasure = contextRefId (traceMeasure trace)
    , oracleTraceMeasureDimension =
        unNodeId (traceMeasurePerformanceDimension trace)
    , oracleTraceMeasureKPI = unNodeId (traceKPI trace)
    , oracleTraceSituation = contextRefId (traceSituation trace)
    , oracleTraceAnchor = situationAnchorRefId (traceSituationAnchor trace)
    , oracleTraceAnchorKind =
        situationAnchorRefKind (traceSituationAnchor trace)
    }

addressedPairs :: TraceEvaluationResult -> [(RawNodeId, RawNodeId)]
addressedPairs = map snd . typedAddressedPairs

typedAddressedPairs ::
     TraceEvaluationResult -> [(AddressedNeed, (RawNodeId, RawNodeId))]
typedAddressedPairs result =
  [ (AddressedNeed intervention need, (unNodeId intervention, unNodeId need))
  | intervention <- traceEvaluationInterventions result
  , need <- traceEvaluationAddressedNeedsFor result intervention
  ]

coverageObservations ::
     TraceEvaluationResult -> [((RawNodeId, RawNodeId), Bool)]
coverageObservations result =
  [ (rawPair, traceEvaluationCovers result addressed)
  | (rawPair, addressed) <- Map.toAscList relevantPairs
  ]
  where
    relevantPairs =
      Map.fromList
        ([ (rawPair, addressed)
         | (addressed, rawPair) <- typedAddressedPairs result
         ]
           ++ [ (addressedNeedSignature addressed, addressed)
              | trace <- traceEvaluationTraces result
              , let addressed = effectTraceCoveredPair trace
              ])

addressedNeedSignature :: AddressedNeed -> (RawNodeId, RawNodeId)
addressedNeedSignature (AddressedNeed intervention need) =
  (unNodeId intervention, unNodeId need)

assertCoverageMatchesOracle ::
     TraceScenario -> TraceEvaluationResult -> [OracleTrace] -> Assertion
assertCoverageMatchesOracle scenario result expectedTraces = do
  Set.fromList (map fst actual) @?= relevantPairs
  actual @?= expected
  where
    addressed =
      Set.fromList (oracleAddressedNeeds (traceScenarioGraph scenario))
    covered = Set.fromList (oracleCoveredPairs expectedTraces)
    relevantPairs = Set.union addressed covered
    actual = coverageObservations result
    expected =
      [(pair, Set.member pair covered) | pair <- Set.toAscList relevantPairs]

addressedPairCount :: TraceEvaluationResult -> Int
addressedPairCount = length . addressedPairs

assertAddressedOrder :: TraceEvaluationResult -> Assertion
assertAddressedOrder result =
  addressedPairs result
    @?= sort (Set.toList (Set.fromList (addressedPairs result)))

assertAffineWork :: [TraceEvaluationResult] -> Assertion
assertAffineWork results =
  case map (traceWorkVector . traceEvaluationWork) results of
    [zero, two, four, eight] -> do
      let firstDelta = zipWith (-) two zero
      zipWith (-) four two @?= firstDelta
      zipWith (-) eight four @?= map (* 2) firstDelta
      assertBool "scenario axis registered no work" (any (> 0) firstDelta)
      assertBool "a work component decreased" (all (>= 0) firstDelta)
    _ -> assertFailure "scenario family arity changed"

assertAffineWorkAllowZero :: [TraceEvaluationResult] -> Assertion
assertAffineWorkAllowZero results =
  case map (traceWorkVector . traceEvaluationWork) results of
    [zero, two, four, eight] -> do
      let firstDelta = zipWith (-) two zero
      zipWith (-) four two @?= firstDelta
      zipWith (-) eight four @?= map (* 2) firstDelta
      assertBool "a work component decreased" (all (>= 0) firstDelta)
    _ -> assertFailure "scenario family arity changed"

assertAffinePositiveWork :: [TraceEvaluationResult] -> Assertion
assertAffinePositiveWork results =
  case map (traceWorkVector . traceEvaluationWork) results of
    [_, two, four, eight] -> do
      let firstDelta = zipWith (-) four two
      zipWith (-) eight four @?= map (* 2) firstDelta
      assertBool "scenario axis registered no work" (any (> 0) firstDelta)
      assertBool "a work component decreased" (all (>= 0) firstDelta)
    _ -> assertFailure "scenario family arity changed"

requireScenario :: TraceScenario -> IO TraceEvaluationResult
requireScenario = either (ioError . userError) pure . evaluateTraceScenario

withEvaluation ::
     Either String TraceEvaluationResult
  -> (TraceEvaluationResult -> Assertion)
  -> Assertion
withEvaluation candidate action =
  case candidate of
    Left message -> assertFailure message
    Right result -> action result

withEvaluations ::
     [Either String TraceEvaluationResult]
  -> ([TraceEvaluationResult] -> Assertion)
  -> Assertion
withEvaluations candidates action =
  case sequence candidates of
    Left message -> assertFailure message
    Right results -> action results

traceWorkVector :: TraceEvaluationWork -> [Int]
traceWorkVector work =
  [traceInterventionDomainValuesRead work]
    ++ evaluationWorkVector (traceAddressedEvaluationWork work)
    ++ canonicalizationVector (traceAddressedCanonicalizationWork work)
    ++ evaluationWorkVector (traceContextEvaluationWork work)
    ++ canonicalizationVector (traceContextCanonicalizationWork work)
    ++ [ traceAnchorDomainsInspected work
       , traceEmptyAnchorDomainsSkipped work
       , traceConstituentPlansExecuted work
       ]
    ++ evaluationWorkVector (traceConstituentEvaluationWork work)
    ++ canonicalizationVector (traceCanonicalizationWork work)
    ++ canonicalizationVector (traceCoverageCanonicalizationWork work)

evaluationWorkVector :: EvaluationWork -> [Int]
evaluationWorkVector work =
  [ workVariableFrames work
  , workConstraintScans work
  , workIndexDomainProbes work
  , workDomainSizeComparisons work
  , workDomainValuesVisited work
  , workIntersectionMembershipProbes work
  , workBindingAttempts work
  , workCompleteNodeBindings work
  , workEdgeBucketProbes work
  , workExactOccurrenceReads work
  , workResultsEmitted work
  ]

canonicalizationVector :: CanonicalizationWork -> [Int]
canonicalizationVector work =
  [ canonicalizationRowsRead work
  , canonicalizationUniqueRows work
  , canonicalizationDuplicateRows work
  ]

expectedEmptyWork :: TraceEvaluationWork
expectedEmptyWork =
  TraceEvaluationWork
    { traceInterventionDomainValuesRead = 0
    , traceAddressedEvaluationWork = EvaluationWork 1 1 1 1 0 0 0 0 0 0 0
    , traceAddressedCanonicalizationWork = mempty
    , traceContextEvaluationWork = EvaluationWork 1 9 4 4 0 0 0 0 0 0 0
    , traceContextCanonicalizationWork = mempty
    , traceAnchorDomainsInspected = 0
    , traceEmptyAnchorDomainsSkipped = 0
    , traceConstituentPlansExecuted = 0
    , traceConstituentEvaluationWork = mempty
    , traceCanonicalizationWork = mempty
    , traceCoverageCanonicalizationWork = mempty
    }

expectedBaselineWork :: TraceEvaluationWork
expectedBaselineWork =
  TraceEvaluationWork
    { traceInterventionDomainValuesRead = 1
    , traceAddressedEvaluationWork = EvaluationWork 2 3 2 2 2 2 2 1 1 1 1
    , traceAddressedCanonicalizationWork = CanonicalizationWork 1 1 0
    , traceContextEvaluationWork = EvaluationWork 6 63 18 18 6 18 6 1 9 9 1
    , traceContextCanonicalizationWork = CanonicalizationWork 1 1 0
    , traceAnchorDomainsInspected = 4
    , traceEmptyAnchorDomainsSkipped = 3
    , traceConstituentPlansExecuted = 1
    , traceConstituentEvaluationWork =
        EvaluationWork 13 252 36 36 13 36 13 1 18 18 1
    , traceCanonicalizationWork = CanonicalizationWork 1 1 0
    , traceCoverageCanonicalizationWork = CanonicalizationWork 1 1 0
    }

expectedAdditionalAnchorWork :: TraceEvaluationWork
expectedAdditionalAnchorWork =
  expectedBaselineWork
    { traceEmptyAnchorDomainsSkipped = 2
    , traceConstituentPlansExecuted = 2
    , traceConstituentEvaluationWork =
        EvaluationWork 26 504 72 72 26 72 26 2 36 36 2
    , traceCanonicalizationWork = CanonicalizationWork 2 2 0
    , traceCoverageCanonicalizationWork = CanonicalizationWork 2 1 1
    }
