{-# LANGUAGE DataKinds #-}

-- | Private semantic and operation-bound effect-trace evaluation contracts.
module O2I.Validation.Trace.Eval.Test.Contracts
  ( tests
  ) where

import Data.List (sort)
import O2I.Language.Element
import O2I.Validation.Relational.Eval
import O2I.Validation.Trace.Eval
import O2I.Validation.Trace.Eval.Test.Fixture
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
    , testCase "input order preserves result and work" inputOrderTest
    , testCase "same-kind anchor fan-out remains affine" anchorFanOutWorkTest
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
  withEvaluation baselineEvaluation $ \result -> do
    let intervention = mkNodeId interventionId
        need = mkNodeId needId
        addressed = AddressedNeed intervention need
    traceEvaluationAddressedNeedsFor result intervention @?= [need]
    assertBool
      "complete trace did not cover its typed pair"
      (traceEvaluationCovers result addressed)
    traceEvaluationAddressedNeedsFor result (mkNodeId extraInterventionId)
      @?= []

inputOrderTest :: Assertion
inputOrderTest =
  withEvaluation baselineEvaluation $ \baseline ->
    withEvaluation permutedBaselineEvaluation $ \permuted -> do
      traceEvaluationInterventions permuted
        @?= traceEvaluationInterventions baseline
      traceEvaluationTraces permuted @?= traceEvaluationTraces baseline
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
