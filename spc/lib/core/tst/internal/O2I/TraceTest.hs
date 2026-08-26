{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module Main
  ( main
  ) where

import Data.List (sort)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Core.Contract
import O2I.Core.Graph.Observation (Commitment(..))
import O2I.Core.Identity
import O2I.Input.Internal.Text (canonicalizeFachlicheText)
import O2I.Input.Internal.Types
  ( FachlicheText(..)
  , StrategyAnchoring(..)
  , StrategyFormulationInput(..)
  )
import O2I.Semantics.Internal
  ( QualificationEligibleStrategy(..)
  , SemanticallyValidModel(..)
  , StrategyFormulationAssessment(..)
  , StrategyFormulationUnavailableReason(..)
  )
import O2I.Structure
import qualified O2I.Trace as Public
import O2I.Trace.Eval
  ( assessTraceabilityInternal
  , promoteTraceInternal
  , validateSuppliedTraceWithWorkInternal
  )
import O2I.Trace.Grammar
import O2I.Trace.Index
import O2I.Trace.Internal
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit (Assertion, (@?=), assertBool, assertFailure, testCase)

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "Core Trace"
    [ testCase "closes the exact 18/27/11 grammar" exactGrammar
    , testCase "uses the exact fixed 38-stage slot schedule" fixedSlotSchedule
    , testCase "produces one canonical complete witness" completeTrace
    , testCase "reports missing support as a partial gap" missingTrace
    , testCase "distinguishes Candidate-only support" candidateOnlyTrace
    , testCase
        "reports global inconsistency without a witness"
        inconsistentTrace
    , testCase "validates a directly supplied exact Trace" suppliedTrace
    , testCase
        "accumulates all 38 directly supplied missing slots"
        suppliedAllMissing
    , testCase
        "accumulates all 38 directly supplied Candidate slots"
        suppliedAllCandidate
    , testCase
        "emits every array across structurally admissible missing gaps"
        allNonRootMissing
    , testCase
        "emits every support array with 37 Candidate-root gaps"
        allNonRootCandidate
    , testCase
        "rejects a supplied Trace from another graph"
        suppliedGraphMismatch
    , testCase
        "deduplicates roots while retaining occurrence support"
        duplicateRoot
    , testCase
        "retains complete support arrays across simultaneous gaps"
        simultaneousGaps
    , testCase
        "reports an ambiguous endpoint projection without guessing"
        ambiguousProjection
    , testCase
        "reports an empty endpoint projection without a domain product"
        emptyProjection
    , testCase
        "accepts every closed situation-anchor endpoint kind"
        allAnchorKinds
    , testCase
        "selects the lexicographically least complete identity"
        lexicographicWitness
    , testCase
        "orders every addressed support bucket canonically"
        canonicalBuckets
    , testCase "excludes root-inconsistent disjoint support" disjointSupport
    , testCase
        "scales independently with unrelated carrier domains"
        independentDomainScaling
    , testCase
        "keeps preparation and dense projection emission subquadratic"
        preparationAndEmissionScaling
    , testCase
        "scales independently with support multiplicity"
        independentSupportScaling
    , testCase
        "assesses mixed complete and partial roots in root order"
        mixedRootScaling
    , testCase
        "measures dense witness alternatives by fixed frontiers"
        denseFrontierScaling
    , testCase
        "applies the complete Trace promotion precedence"
        promotionPrecedence
    , testCase "has deterministic projection order" permutationDeterminism
    , testCase "counts one addressed input pass" addressedWork
    ]

exactGrammar :: Assertion
exactGrammar = do
  length traceVariables @?= 18
  length traceRelationSlots @?= 27
  length traceOwnershipSlots @?= 11
  length traceSlots @?= 38
  traceRelationSlotId rootSlot @?= "intervention-addresses-need"
  map (coreRuleIdText . traceSlotRuleId) traceSlots
    @?= map expectedRule traceSlots
  where
    expectedRule slot =
      case slot of
        RelationTraceSlot _ -> "core.trace.slot." <> traceSlotId slot
        OwnershipTraceSlot _ -> "core.trace.ownership." <> traceSlotId slot

fixedSlotSchedule :: Assertion
fixedSlotSchedule =
  map traceSlotId traceSlots
    @?= [ "intervention-addresses-need"
        , "strategy-qualifies-need"
        , "strategy-directs-intervention"
        , "vision-orients-strategy"
        , "strategy-frames-measure"
        , "intervention-sets-target-for-measure"
        , "intervention-changes-situation"
        , "measure-measures-situation"
        , "situation-surfaces-need"
        , "need-driver-grounds-need-objective"
        , "strategy-key-result-translates-into-need-objective"
        , "strategy-driver-grounds-strategy-objective"
        , "vision-objective-orients-strategy-objective"
        , "strategy-key-result-substantiates-strategy-objective"
        , "strategy-action-contributes-to-strategy-key-result"
        , "strategy-action-guides-intervention-action"
        , "intervention-action-contributes-to-intervention-key-result"
        , "intervention-key-result-contributes-to-strategy-key-result"
        , "intervention-key-result-substantiates-need-objective"
        , "strategy-driver-indicates-measure-performance-dimension"
        , "strategy-key-result-determines-measure-performance-dimension"
        , "measure-performance-dimension-contains-measure-kpi"
        , "intervention-key-result-sets-target-for-measure-kpi"
        , "measure-kpi-measures-situation-anchor"
        , "intervention-action-changes-same-situation-anchor"
        , "situation-anchor-anchors-need-driver"
        , "situation-is-constituted-by-same-situation-anchor"
        , "vision-objective-at-vision"
        , "strategy-driver-at-strategy"
        , "strategy-objective-at-strategy"
        , "strategy-action-at-strategy"
        , "strategy-key-result-at-strategy"
        , "need-driver-at-need"
        , "need-objective-at-need"
        , "intervention-action-at-intervention"
        , "intervention-key-result-at-intervention"
        , "measure-performance-dimension-at-measure"
        , "measure-kpi-at-measure"
        ]

completeTrace :: Assertion
completeTrace =
  withTraceModel CompleteFixture $ \model ->
    case assessTraceabilityInternal model of
      (AssessedRootTraces graph (root NonEmpty.:| []), _) -> do
        graph @?= selectedViewIdentity
        storedRootIntervention (storedRootBinding root)
          @?= variableIdentity InterventionVariable
        storedRootNeed (storedRootBinding root)
          @?= variableIdentity NeedVariable
        case storedRootResult root of
          CompleteTraceResult witness -> do
            storedCompleteTraceIdentity witness @?= expectedIdentity
            length (storedCompleteRelationSupport witness) @?= 27
            length (storedCompleteOwnershipSupport witness) @?= 11
            assertBool
              "every exact slot retains asserted occurrence support"
              (all
                 (not . null . storedSupportOccurrences)
                 (storedCompleteRelationSupport witness
                    ++ storedCompleteOwnershipSupport witness))
          PartialTraceResult _ -> assertFailure "complete fixture was partial"
      outcome -> assertFailure ("unexpected complete result: " ++ show outcome)

missingTrace :: Assertion
missingTrace =
  withTraceModel (MissingFixture VisionOrientsStrategy) $ \model ->
    inspectSinglePartial model $ \partial -> do
      map storedSupportSlot (storedPartialRelationSupport partial)
        @?= map RelationTraceSlot traceRelationSlots
      case [ storedSupportOccurrences support
           | support <- storedPartialRelationSupport partial
           , storedSupportSlot support
               == RelationTraceSlot VisionOrientsStrategy
           ] of
        [[]] -> pure ()
        support ->
          assertFailure ("missing slot retained support: " ++ show support)
      case NonEmpty.toList (storedPartialGaps partial) of
        [gap] -> do
          gapSlot gap @?= Just (RelationTraceSlot VisionOrientsStrategy)
          gapDisposition gap @?= MissingSupport
        gaps -> assertFailure ("unexpected missing gaps: " ++ show gaps)

candidateOnlyTrace :: Assertion
candidateOnlyTrace =
  withTraceModel (CandidateFixture VisionOrientsStrategy) $ \model ->
    inspectSinglePartial model $ \partial ->
      case NonEmpty.toList (storedPartialGaps partial) of
        [gap] -> do
          gapSlot gap @?= Just (RelationTraceSlot VisionOrientsStrategy)
          gapDisposition gap @?= CandidateOnlySupport
        gaps -> assertFailure ("unexpected Candidate gaps: " ++ show gaps)

inconsistentTrace :: Assertion
inconsistentTrace =
  withTraceModel InconsistentFixture $ \model ->
    inspectSinglePartial model $ \partial ->
      case NonEmpty.toList (storedPartialGaps partial) of
        [GlobalConsistencyObstruction slots GloballyInconsistentSupport] ->
          NonEmpty.length slots @?= 38
        gaps -> assertFailure ("unexpected inconsistency gaps: " ++ show gaps)

suppliedTrace :: Assertion
suppliedTrace =
  withTraceModel CompleteFixture $ \model ->
    withBoundIdentity model expectedIdentity $ \bound ->
      case Public.validateSuppliedTrace model bound of
        SuppliedTraceComplete proof -> do
          storedSuppliedTraceIdentity proof @?= expectedIdentity
          length (storedSuppliedRelationSupport proof) @?= 27
          length (storedSuppliedOwnershipSupport proof) @?= 11
        unavailable ->
          assertFailure
            ("exact supplied Trace was rejected: " ++ show unavailable)

suppliedAllMissing :: Assertion
suppliedAllMissing = suppliedAllSlots AllMissingFixture MissingSupport

suppliedAllCandidate :: Assertion
suppliedAllCandidate = do
  withTraceModel AllCandidateFixture $ \model ->
    fst (assessTraceabilityInternal model)
      @?= NoAssertedRoot selectedViewIdentity
  suppliedAllSlots AllCandidateFixture CandidateOnlySupport

allNonRootMissing :: Assertion
allNonRootMissing =
  allNonRootPartial
    AllNonRootMissingFixture
    MissingSupport
    missingStructuralSlots
    structuralSupportSlots

allNonRootCandidate :: Assertion
allNonRootCandidate =
  allNonRootPartial
    AllNonRootCandidateFixture
    CandidateOnlySupport
    (drop 1 traceSlots)
    [RelationTraceSlot rootSlot]

allNonRootPartial ::
     Fixture -> TraceGapDisposition -> [TraceSlot] -> [TraceSlot] -> Assertion
allNonRootPartial fixture disposition expectedGaps supportedSlots =
  withTraceModel fixture $ \model ->
    inspectSinglePartial model $ \partial -> do
      let supports =
            storedPartialRelationSupport partial
              ++ storedPartialOwnershipSupport partial
          gaps = NonEmpty.toList (storedPartialGaps partial)
      map storedSupportSlot supports @?= traceSlots
      map gapSlot gaps @?= map Just expectedGaps
      map gapDisposition gaps @?= replicate (length expectedGaps) disposition
      map (not . null . storedSupportOccurrences) supports
        @?= map (`elem` supportedSlots) traceSlots

missingStructuralSlots :: [TraceSlot]
missingStructuralSlots =
  map RelationTraceSlot (drop 1 traceRelationSlots)
    ++ [ OwnershipTraceSlot slot
       | slot <- traceOwnershipSlots
       , fst (traceOwnershipSlotVariables slot)
           `elem` [NeedVariable, InterventionVariable]
       ]

structuralSupportSlots :: [TraceSlot]
structuralSupportSlots =
  RelationTraceSlot rootSlot
    : [ OwnershipTraceSlot slot
      | slot <- traceOwnershipSlots
      , fst (traceOwnershipSlotVariables slot)
          `notElem` [NeedVariable, InterventionVariable]
      ]

suppliedAllSlots :: Fixture -> TraceGapDisposition -> Assertion
suppliedAllSlots fixture expectedDisposition =
  withTraceModel fixture $ \model ->
    withBoundIdentity model expectedIdentity $ \bound ->
      case validateSuppliedTraceWithWorkInternal model bound of
        (SuppliedTraceUnavailable _ reasons, work) -> do
          let failures = NonEmpty.toList reasons
          map suppliedFailureSlot failures @?= traceSlots
          map suppliedFailureDisposition failures
            @?= replicate 38 expectedDisposition
          traceDirectSupportLookups work @?= 76
        outcome ->
          assertFailure ("unexpected supplied result: " ++ show outcome)

suppliedFailureSlot :: SuppliedTraceUnavailableReason -> TraceSlot
suppliedFailureSlot reason =
  case reason of
    ExactSlotUnsupported slot _ _ -> slot
    TraceGraphIdentityMismatch _ _ ->
      error "graph mismatch has no supplied slot"

suppliedFailureDisposition ::
     SuppliedTraceUnavailableReason -> TraceGapDisposition
suppliedFailureDisposition reason =
  case reason of
    ExactSlotUnsupported _ _ disposition -> disposition
    TraceGraphIdentityMismatch _ _ ->
      error "graph mismatch has no supplied disposition"

suppliedGraphMismatch :: Assertion
suppliedGraphMismatch =
  withTraceModel CompleteFixture $ \model ->
    withBoundIdentity model foreignIdentity $ \bound ->
      case validateSuppliedTraceWithWorkInternal model bound of
        (SuppliedTraceUnavailable _ (TraceGraphIdentityMismatch expected actual NonEmpty.:| []), work) -> do
          expected @?= selectedViewIdentity
          actual @?= foreignGraphIdentity
          traceDirectSupportLookups work @?= 0
        outcome -> assertFailure ("unexpected graph mismatch: " ++ show outcome)
  where
    foreignIdentity = traceIdentityValue foreignGraphIdentity variableBindings

promotionPrecedence :: Assertion
promotionPrecedence =
  withTraceModel CompleteFixture $ \model ->
    withBoundIdentity model expectedIdentity $ \bound ->
      case Public.validateSuppliedTrace model bound of
        SuppliedTraceComplete supplied -> do
          assertPromotionReasons
            model
            supplied
            unavailable
            [StrategyAssessmentUnavailable]
          assertPromotionReasons
            model
            supplied
            candidate
            [StrategyAssessmentUnavailable]
          assertPromotionReasons
            model
            supplied
            invalid
            [StrategyAssessmentInvalid]
          assertPromotionReasons
            model
            supplied
            proofGraphMismatch
            [StrategyProofModelMismatch]
          assertPromotionReasons
            model
            supplied
            proofIdentityMismatch
            [StrategyIdentityMismatch]
          assertPromotionReasons
            model
            supplied
            proofFormulationMismatch
            [ StrategyDiagnosisMismatch
            , StrategyIntentMismatch
            , StrategyActionNotInFormulation
            , StrategyKeyResultNotInFormulation
            ]
          case promoteTraceInternal model proofValid supplied of
            TracePromotionSucceeded promoted -> do
              storedPromotedGraphIdentity promoted @?= selectedViewIdentity
              storedPromotedTraceIdentity promoted @?= expectedIdentity
              storedPromotedStrategyProofIdentity promoted
                @?= variableIdentity StrategyVariable
            outcome ->
              assertFailure ("promotion did not succeed: " ++ show outcome)
        outcome ->
          assertFailure ("promotion fixture was unavailable: " ++ show outcome)
  where
    strategy = variableIdentity StrategyVariable
    unavailable =
      StrategyFormulationUnavailable strategy StrategyFormulationInputMissing
    candidate =
      StrategyFormulationCandidate strategy (occurrenceId "candidate-strategy")
    invalid =
      StrategyFormulationInvalid
        strategy
        (error "promotion must not inspect invalid defects" NonEmpty.:| [])
    proofGraphMismatch =
      validStrategyAssessment foreignGraphIdentity strategy mismatchFormulation
    proofIdentityMismatch =
      validStrategyAssessment
        selectedViewIdentity
        (modelId "wrong-strategy")
        mismatchFormulation
    proofFormulationMismatch =
      validStrategyAssessment selectedViewIdentity strategy mismatchFormulation
    proofValid =
      validStrategyAssessment selectedViewIdentity strategy validFormulation

assertPromotionReasons ::
     SemanticallyValidModel scope
  -> SuppliedCompleteTrace scope
  -> StrategyFormulationAssessment scope
  -> [TracePromotionUnavailableReason]
  -> Assertion
assertPromotionReasons model supplied assessment expected =
  case promoteTraceInternal model assessment supplied of
    TracePromotionUnavailable _ _ reasons ->
      NonEmpty.toList reasons @?= expected
    outcome -> assertFailure ("unexpected promotion result: " ++ show outcome)

validStrategyAssessment ::
     ModelIdentity
  -> ModelIdentity
  -> StrategyFormulationInput
  -> StrategyFormulationAssessment scope
validStrategyAssessment graph strategy input =
  StrategyFormulationValid
    QualificationEligibleStrategy
      { eligibleStrategyGraphIdentity = graph
      , eligibleStrategyIdentity = strategy
      , eligibleStrategyOccurrence = occurrenceId "strategy-proof"
      , eligibleStrategyInput = input
      , eligibleStrategyWitnesses = []
      }

validFormulation :: StrategyFormulationInput
validFormulation =
  formulation
    (variableIdentity StrategyDriverVariable)
    (variableIdentity StrategyObjectiveVariable)
    (variableIdentity StrategyActionVariable)
    (variableIdentity StrategyKeyResultVariable)

mismatchFormulation :: StrategyFormulationInput
mismatchFormulation =
  formulation
    (modelId "wrong-diagnosis")
    (modelId "wrong-intent")
    (modelId "wrong-action")
    (modelId "wrong-key-result")

formulation ::
     ModelIdentity
  -> ModelIdentity
  -> ModelIdentity
  -> ModelIdentity
  -> StrategyFormulationInput
formulation diagnosis intent action keyResult =
  StrategyFormulationInput
    { formulationStrategy = variableIdentity StrategyVariable
    , formulationScope = fachlicheText NonEmpty.:| []
    , formulationAnchoring =
        StrategyAnchoring
          { strategyAnchoringPeriod = fachlicheText
          , strategyAnchoringResponsibilityScope = fachlicheText
          , strategyAnchoringDecisionLevel = fachlicheText
          , strategyAnchoringResponsibilities = fachlicheText NonEmpty.:| []
          , strategyAnchoringDecisionPaths = fachlicheText NonEmpty.:| []
          , strategyAnchoringImplementationLogic = fachlicheText
          }
    , formulationDerivedGuardrails = fachlicheText NonEmpty.:| []
    , formulationDiagnosis = diagnosis
    , formulationIntent = intent
    , formulationGuidingPolicy = modelId "guiding-policy"
    , formulationPositioning = fachlicheText NonEmpty.:| []
    , formulationTradeOffs = fachlicheText NonEmpty.:| []
    , formulationActions = action NonEmpty.:| []
    , formulationKeyResults = keyResult NonEmpty.:| []
    , formulationFitRationale = fachlicheText NonEmpty.:| []
    }

fachlicheText :: FachlicheText
fachlicheText =
  case canonicalizeFachlicheText "trace-test" of
    Left failure -> error ("fachliche text fixture: " ++ show failure)
    Right canonical -> FachlicheText canonical

duplicateRoot :: Assertion
duplicateRoot =
  withTraceModel DuplicateRootFixture $ \model ->
    case fst (assessTraceabilityInternal model) of
      AssessedRootTraces _ (root NonEmpty.:| []) -> do
        NonEmpty.length (storedRootSupport (storedRootBinding root)) @?= 2
        case storedRootResult root of
          CompleteTraceResult _ -> pure ()
          PartialTraceResult _ -> assertFailure "duplicate root became partial"
      outcome ->
        assertFailure ("unexpected duplicate-root result: " ++ show outcome)

simultaneousGaps :: Assertion
simultaneousGaps =
  withTraceModel (MissingSlotsFixture missing) $ \model ->
    inspectSinglePartial model $ \partial -> do
      length (storedPartialRelationSupport partial) @?= 27
      length (storedPartialOwnershipSupport partial) @?= 11
      map gapSlot (NonEmpty.toList (storedPartialGaps partial))
        @?= map Just missing
      assertBool
        "missing slots did not retain canonical empty support"
        (all
           null
           [ storedSupportOccurrences support
           | support <-
               storedPartialRelationSupport partial
                 ++ storedPartialOwnershipSupport partial
           , storedSupportSlot support `elem` missing
           ])
  where
    missing =
      [ RelationTraceSlot VisionOrientsStrategy
      , OwnershipTraceSlot MeasureKpiAtMeasure
      ]

ambiguousProjection :: Assertion
ambiguousProjection =
  withTraceModel (AmbiguousProjectionFixture 8) $ \model ->
    inspectSinglePartial model $ \partial -> do
      projectionValues partial VisionVariable
        @?= sort
              (variableIdentity VisionVariable
                 : [ modelId
                     ("model-" ++ alternativeCarrierName number VisionVariable)
                   | number <- [1 .. 8]
                   ])
      case findGap (RelationTraceSlot VisionOrientsStrategy) partial of
        Just (UnboundSlotGap _ established unresolved MissingSupport) -> do
          established
            @?= [(StrategyVariable, variableIdentity StrategyVariable)]
          NonEmpty.toList unresolved @?= [VisionVariable]
        gap -> assertFailure ("unexpected ambiguous gap: " ++ show gap)

emptyProjection :: Assertion
emptyProjection =
  withTraceModel EmptyProjectionFixture $ \model ->
    inspectSinglePartial model $ \partial -> do
      projectionValues partial VisionVariable @?= []
      projectionValues partial VisionObjectiveVariable @?= []
      case findGap (RelationTraceSlot VisionOrientsStrategy) partial of
        Just (UnboundSlotGap _ established unresolved MissingSupport) -> do
          established
            @?= [(StrategyVariable, variableIdentity StrategyVariable)]
          NonEmpty.toList unresolved @?= [VisionVariable]
        gap -> assertFailure ("unexpected empty gap: " ++ show gap)

projectionValues :: PartialTrace scope -> TraceVariable -> [ModelIdentity]
projectionValues partial variable =
  case [ storedProjectionValues projection
       | projection <- storedPartialVariableProjections partial
       , storedProjectionVariable projection == variable
       ] of
    [values] -> values
    values -> error ("non-canonical projection fixture: " ++ show values)

findGap :: TraceSlot -> PartialTrace scope -> Maybe TraceGap
findGap slot partial =
  case [ gap
       | gap <- NonEmpty.toList (storedPartialGaps partial)
       , gapSlot gap == Just slot
       ] of
    [gap] -> Just gap
    _ -> Nothing

allAnchorKinds :: Assertion
allAnchorKinds =
  mapM_
    completeAnchor
    ["BusinessCapability", "BusinessObject", "BusinessProcess", "ValueStream"]
  where
    completeAnchor anchorType =
      withTraceModel (AnchorFixture anchorType) $ \model ->
        case fst (assessTraceabilityInternal model) of
          AssessedRootTraces _ (root NonEmpty.:| []) ->
            case storedRootResult root of
              CompleteTraceResult _ -> pure ()
              PartialTraceResult partial ->
                assertFailure ("anchor fixture was partial: " ++ show partial)
          outcome -> assertFailure ("anchor fixture failed: " ++ show outcome)

lexicographicWitness :: Assertion
lexicographicWitness =
  withTraceModel (LexAlternativeFixture 1) $ \model ->
    case fst (assessTraceabilityInternal model) of
      AssessedRootTraces _ (root NonEmpty.:| []) ->
        case storedRootResult root of
          CompleteTraceResult witness -> do
            traceIdentityBinding
              (storedCompleteTraceIdentity witness)
              VisionVariable
              @?= modelId "model-carrier-a-1-vision"
            traceIdentityBinding
              (storedCompleteTraceIdentity witness)
              VisionObjectiveVariable
              @?= modelId "model-carrier-a-1-visionObjective"
          PartialTraceResult partial ->
            assertFailure ("alternative fixture was partial: " ++ show partial)
      outcome -> assertFailure ("alternative fixture failed: " ++ show outcome)

canonicalBuckets :: Assertion
canonicalBuckets =
  withTraceModel (LexAlternativeFixture 1) $ \model -> do
    let index = buildTraceIndex (semanticModelGraph model)
        strategy =
          case traceIndexInternIdentity
                 index
                 (variableIdentity StrategyVariable) of
            Just identity -> identity
            Nothing -> error "fixture strategy was not interned"
        bucket =
          traceIndexAssertedBucket
            index
            (RelationTraceSlot VisionOrientsStrategy)
            Nothing
            (Just strategy)
        endpoints = map fst bucket
    endpoints @?= sort endpoints
    assertBool
      "canonical source bucket lost an alternative"
      (length bucket == 2)

disjointSupport :: Assertion
disjointSupport =
  withTraceModel DisjointSupportFixture $ \model ->
    inspectSinglePartial model $ \partial -> do
      let support =
            [ storedSupportOccurrences slotSupport
            | slotSupport <- storedPartialRelationSupport partial
            , storedSupportSlot slotSupport
                == RelationTraceSlot VisionOrientsStrategy
            ]
      support
        @?= [[occurrenceId (relationOccurrenceName VisionOrientsStrategy)]]
      assertBool
        "disjoint occurrence leaked into root-bound partial support"
        (disjointRelationOccurrence `notElem` concat support)

independentDomainScaling :: Assertion
independentDomainScaling =
  withTraceModel (DomainScalingFixture 0) $ \smallModel ->
    withTraceModel (DomainScalingFixture 64) $ \largeModel -> do
      let (_, small) = assessTraceabilityInternal smallModel
          (_, large) = assessTraceabilityInternal largeModel
      traceCarrierVisits large - traceCarrierVisits small @?= 64
      traceFrontierBindingsVisited large @?= traceFrontierBindingsVisited small
      traceFrontierBindingsEmitted large @?= traceFrontierBindingsEmitted small
      traceFrontierPeakPair large @?= traceFrontierPeakPair small

preparationAndEmissionScaling :: Assertion
preparationAndEmissionScaling =
  withTraceModel (ProjectionScalingFixture 0) $ \baseModel ->
    withTraceModel (ProjectionScalingFixture 64) $ \mediumModel ->
      withTraceModel (ProjectionScalingFixture 128) $ \largeModel -> do
        let (baseAssessment, base) = assessTraceabilityInternal baseModel
            (mediumAssessment, medium) = assessTraceabilityInternal mediumModel
            (largeAssessment, large) = assessTraceabilityInternal largeModel
            scalarMedium =
              tracePreparationIdentityScalarSteps medium
                - tracePreparationIdentityScalarSteps base
            scalarLarge =
              tracePreparationIdentityScalarSteps large
                - tracePreparationIdentityScalarSteps base
            fixedMedium =
              tracePreparationFixedWordSteps medium
                - tracePreparationFixedWordSteps base
            fixedLarge =
              tracePreparationFixedWordSteps large
                - tracePreparationFixedWordSteps base
            emissionMedium =
              traceAddressTrieSteps medium - traceAddressTrieSteps base
            emissionLarge =
              traceAddressTrieSteps large - traceAddressTrieSteps base
        projectionCardinality baseAssessment @?= 1
        projectionCardinality mediumAssessment @?= 65
        projectionCardinality largeAssessment @?= 129
        assertBool
          "measured identity ordering became quadratic"
          (scalarLarge < 3 * scalarMedium)
        fixedLarge @?= 2 * fixedMedium
        emissionLarge @?= 2 * emissionMedium
  where
    projectionCardinality assessment =
      case assessment of
        AssessedRootTraces _ (root NonEmpty.:| []) ->
          case storedRootResult root of
            PartialTraceResult partial ->
              length (projectionValues partial VisionVariable)
            CompleteTraceResult _ -> error "projection fixture was complete"
        _ -> error "projection fixture did not have exactly one root"

independentSupportScaling :: Assertion
independentSupportScaling =
  withTraceModel (DuplicateSupportFixture 0) $ \singleModel ->
    withTraceModel (DuplicateSupportFixture 7) $ \multipleModel -> do
      let (_, single) = assessTraceabilityInternal singleModel
          (_, multiple) = assessTraceabilityInternal multipleModel
      traceRelationVisits multiple - traceRelationVisits single @?= 7 * 27
      traceOwnershipVisits multiple @?= traceOwnershipVisits single
      traceSupportBucketOccurrences multiple @?= 38 + 7 * 27
      traceFrontierBindingsEmitted multiple
        @?= traceFrontierBindingsEmitted single
      traceFrontierPeakPair multiple @?= traceFrontierPeakPair single

mixedRootScaling :: Assertion
mixedRootScaling =
  withTraceModel (MixedRootsFixture 8) $ \model ->
    case assessTraceabilityInternal model of
      (AssessedRootTraces _ roots, work) -> do
        NonEmpty.length roots @?= 9
        map rootResultDisposition (NonEmpty.toList roots) @?= CompleteResult
          : replicate 8 PartialResult
        traceRootCount work @?= 9
        assertBool
          "root-scaled work did not visit every fixed stage"
          (traceFrontierStageVisits work >= 9 * 38)
      outcome ->
        assertFailure ("unexpected mixed-root result: " ++ show outcome)

data StoredResultDisposition
  = CompleteResult
  | PartialResult
  deriving (Eq, Show)

rootResultDisposition :: RootTrace scope -> StoredResultDisposition
rootResultDisposition root =
  case storedRootResult root of
    CompleteTraceResult _ -> CompleteResult
    PartialTraceResult _ -> PartialResult

denseFrontierScaling :: Assertion
denseFrontierScaling =
  withTraceModel (DenseAlternativesFixture 2) $ \smallModel ->
    withTraceModel (DenseAlternativesFixture 8) $ \largeModel -> do
      let (smallAssessment, small) = assessTraceabilityInternal smallModel
          (largeAssessment, large) = assessTraceabilityInternal largeModel
          largeWitnessSpace = (8 + 1) * (8 + 1)
          largePartialBindingSpace = (8 + 1) ^ (4 :: Int)
      rootDispositions smallAssessment @?= [CompleteResult]
      rootDispositions largeAssessment @?= [CompleteResult]
      assertBool
        "dense alternatives did not widen a fixed frontier"
        (traceFrontierPeakPair large > traceFrontierPeakPair small)
      assertBool
        "counter was substituted by complete-witness cardinality"
        (traceFrontierPeakPair large > largeWitnessSpace)
      assertBool
        "retention counter exceeded the two adjacent fixed frontiers"
        (traceFrontierPeakPair large <= 2 * largePartialBindingSpace)
      assertBool
        "dense support was not charged through H(k,b)"
        (traceSupportBucketOccurrences large
           > traceSupportBucketOccurrences small)
      assertBool
        "dense addressing work was not charged"
        (traceAddressTrieSteps large > traceAddressTrieSteps small)
      assertBool
        "frontier trie work was not charged"
        (traceFrontierKeyTrieSteps large > traceFrontierKeyTrieSteps small)
      assertBool
        "frontier compaction comparisons were not charged"
        (traceFrontierHistoryCellComparisons large
           > traceFrontierHistoryCellComparisons small)

rootDispositions :: TraceAssessment scope -> [StoredResultDisposition]
rootDispositions assessment =
  case assessment of
    NoAssertedRoot _ -> []
    AssessedRootTraces _ roots ->
      map rootResultDisposition (NonEmpty.toList roots)

permutationDeterminism :: Assertion
permutationDeterminism =
  withTraceModel CompleteFixture $ \forward ->
    withTraceModel ReversedFixture $ \reversed ->
      show (fst (assessTraceabilityInternal forward))
        @?= show (fst (assessTraceabilityInternal reversed))

addressedWork :: Assertion
addressedWork =
  withTraceModel CompleteFixture $ \model -> do
    let (_, work) = assessTraceabilityInternal model
    traceCarrierVisits work @?= 18
    traceRelationVisits work @?= 27
    traceOwnershipVisits work @?= 11
    traceRootCount work @?= 1
    traceConsistencyRuns work @?= 1
    traceFrontierStageVisits work @?= 38
    assertBool
      "ordered preparation was not charged to W_p"
      (tracePreparationIdentityScalarSteps work > 0)
    assertBool
      "fixed-word preparation was not charged to W_p"
      (tracePreparationFixedWordSteps work > 0)
    assertBool
      "address trie traversal was not charged"
      (traceAddressTrieSteps work > 0)
    assertBool
      "frontier trie traversal was not charged"
      (traceFrontierKeyTrieSteps work > 0)
    assertBool
      "frontier evaluation did no work"
      (traceFrontierBindingsVisited work > 0)
    assertBool
      "support buckets were not measured"
      (traceSupportBucketOccurrences work >= 38)

withBoundIdentity ::
     SemanticallyValidModel scope
  -> TraceIdentity
  -> (BoundTraceIdentity scope -> Assertion)
  -> Assertion
withBoundIdentity model identity inspect =
  case Public.bindTraceIdentity model identity of
    Left defects ->
      assertFailure ("Trace identity did not bind: " ++ show defects)
    Right bound -> inspect bound

inspectSinglePartial ::
     SemanticallyValidModel scope
  -> (PartialTrace scope -> Assertion)
  -> Assertion
inspectSinglePartial model inspect =
  case fst (assessTraceabilityInternal model) of
    AssessedRootTraces _ (root NonEmpty.:| []) ->
      case storedRootResult root of
        CompleteTraceResult _ -> assertFailure "partial fixture was complete"
        PartialTraceResult partial -> inspect partial
    outcome -> assertFailure ("unexpected partial result: " ++ show outcome)

gapSlot :: TraceGap -> Maybe TraceSlot
gapSlot gap =
  case gap of
    BoundSlotGap slot _ _ -> Just slot
    UnboundSlotGap slot _ _ _ -> Just slot
    GlobalConsistencyObstruction _ _ -> Nothing

gapDisposition :: TraceGap -> TraceGapDisposition
gapDisposition gap =
  case gap of
    BoundSlotGap _ _ disposition -> disposition
    UnboundSlotGap _ _ _ disposition -> disposition
    GlobalConsistencyObstruction _ disposition -> disposition

data Fixture
  = CompleteFixture
  | MissingFixture TraceRelationSlot
  | CandidateFixture TraceRelationSlot
  | MissingSlotsFixture [TraceSlot]
  | AllMissingFixture
  | AllCandidateFixture
  | AllNonRootMissingFixture
  | AllNonRootCandidateFixture
  | DuplicateRootFixture
  | LexAlternativeFixture Int
  | AmbiguousProjectionFixture Int
  | DenseAlternativesFixture Int
  | DuplicateSupportFixture Int
  | DomainScalingFixture Int
  | ProjectionScalingFixture Int
  | MixedRootsFixture Int
  | EmptyProjectionFixture
  | AnchorFixture Text
  | InconsistentFixture
  | DisjointSupportFixture
  | ReversedFixture
  deriving (Eq)

withTraceModel ::
     Fixture
  -> (forall scope. SemanticallyValidModel scope -> Assertion)
  -> Assertion
withTraceModel fixture inspect =
  case buildModelIdentityIndex (selectedViewOccurrence : occurrences) of
    Left defects ->
      assertFailure ("identity fixture rejected: " ++ show defects)
    Right index ->
      case withSelectedViewScope
             index
             selectedViewOccurrence
             (map modelOccurrenceIdentity occurrences)
             assessSelected of
        Left defects ->
          assertFailure ("selected View rejected: " ++ show defects)
        Right (Left problem) -> assertFailure problem
        Right (Right assertion) -> assertion
  where
    (projection, occurrences) = traceFixture fixture
    assessSelected scope =
      case assessStructure scope projection of
        Left defects -> Left (show defects)
        Right assessment ->
          foldStructureAssessment
            (const (Left "Structure rejected Trace fixture"))
            (\graph -> Right (inspect (SemanticallyValidModel graph [])))
            assessment

traceFixture :: Fixture -> (StructureProjection, [ModelOccurrence])
traceFixture fixture =
  ( structureProjection orderedCarriers orderedOwnership orderedRelations [] []
  , map occurrenceModel allOccurrenceNames)
  where
    carriers =
      [ carrier fixture variable
      | variable <- traceVariables
      , fixtureCarriesVariable fixture variable
      ]
        ++ [ carrierNamed StrategyVariable "strategy-alternate"
           | fixture == InconsistentFixture
           ]
        ++ [ carrierNamed variable name
           | fixture == DisjointSupportFixture
           , (variable, name) <-
               [ (VisionVariable, disjointVisionCarrier)
               , (StrategyVariable, disjointStrategyCarrier)
               ]
           ]
        ++ [ carrierNamed variable (alternativeCarrierName number variable)
           | number <- [1 .. lexAlternativeCount fixture]
           , variable <- [VisionVariable, VisionObjectiveVariable]
           ]
        ++ [ carrierNamed variable (denseCarrierName number variable)
           | number <- [1 .. denseAlternativeCount fixture]
           , variable <- [NeedDriverVariable, NeedObjectiveVariable]
           ]
        ++ [ carrierNamed owner (structuralOwnerName owner)
           | usesStructuralOwners fixture
           , owner <- structuralOwners
           ]
        ++ [ carrierNamed VisionVariable (domainCarrierName number)
           | number <- [1 .. domainScalingCount fixture]
           ]
        ++ concat
             [ [ carrierNamed
                   InterventionVariable
                   (extraRootCarrierName number InterventionVariable)
               , carrierNamed
                   NeedVariable
                   (extraRootCarrierName number NeedVariable)
               ]
             | number <- [1 .. mixedRootCount fixture]
             ]
    ownerships
      | usesStructuralOwners fixture =
        map structuralOwnership traceOwnershipSlots
      | otherwise =
        [ ownership fixture slot
        | slot <- traceOwnershipSlots
        , not (isOmittedOwnership fixture slot)
        ]
          ++ alternativeOwnership
          ++ denseOwnerships
    relations =
      [ relation fixture slot
      | slot <- traceRelationSlots
      , not (isMissingSlot fixture (RelationTraceSlot slot))
      ]
        ++ duplicateRoots
        ++ alternativeRelations
        ++ duplicateRelations
        ++ denseRelations
        ++ extraRootRelations
        ++ [ relationNamed
             Asserted
             VisionOrientsStrategy
             disjointRelationName
             disjointVisionCarrier
             disjointStrategyCarrier
           | fixture == DisjointSupportFixture
           ]
    order values
      | fixture == ReversedFixture = reverse values
      | otherwise = values
    orderedCarriers = order carriers
    orderedOwnership = order ownerships
    orderedRelations = order relations
    allOccurrenceNames =
      [ variableOccurrenceName variable
      | variable <- traceVariables
      , fixtureCarriesVariable fixture variable
      ]
        ++ ["strategy-alternate" | fixture == InconsistentFixture]
        ++ [ name
           | fixture == DisjointSupportFixture
           , name <-
               [ disjointVisionCarrier
               , disjointStrategyCarrier
               , disjointRelationName
               ]
           ]
        ++ [ alternativeCarrierName number variable
           | number <- [1 .. lexAlternativeCount fixture]
           , variable <- [VisionVariable, VisionObjectiveVariable]
           ]
        ++ [ denseCarrierName number variable
           | number <- [1 .. denseAlternativeCount fixture]
           , variable <- [NeedDriverVariable, NeedObjectiveVariable]
           ]
        ++ [ structuralOwnerName owner
           | usesStructuralOwners fixture
           , owner <- structuralOwners
           ]
        ++ [ domainCarrierName number
           | number <- [1 .. domainScalingCount fixture]
           ]
        ++ [ extraRootCarrierName number variable
           | number <- [1 .. mixedRootCount fixture]
           , variable <- [InterventionVariable, NeedVariable]
           ]
        ++ [ ownershipOccurrenceName slot
           | slot <- traceOwnershipSlots
           , not (isOmittedOwnership fixture slot)
           ]
        ++ [ relationOccurrenceName slot
           | slot <- traceRelationSlots
           , not (isMissingSlot fixture (RelationTraceSlot slot))
           ]
        ++ [duplicateRootName | fixture == DuplicateRootFixture]
        ++ [ name
           | number <- [1 .. lexAlternativeCount fixture]
           , name <-
               alternativeObjectiveRelationName number
                 : [ alternativeVisionRelationName number
                   | not
                       (isMissingSlot
                          fixture
                          (RelationTraceSlot VisionOrientsStrategy))
                   ]
           ]
        ++ [ alternativeOwnershipName owner member
           | (owner, member) <- alternativeOwnershipSpecs fixture
           ]
        ++ [ duplicateRelationName number slot
           | number <- [1 .. duplicateSupportCount fixture]
           , slot <- traceRelationSlots
           ]
        ++ [ name
           | number <- [1 .. denseAlternativeCount fixture]
           , name <- denseOccurrenceNames number
           ]
        ++ [ extraRootRelationName number
           | number <- [1 .. mixedRootCount fixture]
           ]
    duplicateRoots =
      [ relationNamed
        Asserted
        InterventionAddressesNeed
        duplicateRootName
        (variableOccurrenceName InterventionVariable)
        (variableOccurrenceName NeedVariable)
      | fixture == DuplicateRootFixture
      ]
    alternativeOwnership =
      [ ownershipNamed
        Asserted
        VisionObjectiveAtVision
        (alternativeOwnershipName owner member)
        (selectedAlternativeCarrier owner VisionVariable)
        (selectedAlternativeCarrier member VisionObjectiveVariable)
      | (owner, member) <- alternativeOwnershipSpecs fixture
      ]
    denseOwnerships =
      concatMap denseOwnership [1 .. denseAlternativeCount fixture]
    duplicateRelations =
      [ relationNamed
        Asserted
        slot
        (duplicateRelationName number slot)
        (variableOccurrenceName source)
        (variableOccurrenceName target)
      | number <- [1 .. duplicateSupportCount fixture]
      , slot <- traceRelationSlots
      , let (source, target) = traceRelationSlotVariables slot
      ]
    denseRelations =
      concatMap denseRelation [1 .. denseAlternativeCount fixture]
    extraRootRelations =
      [ relationNamed
        Asserted
        InterventionAddressesNeed
        (extraRootRelationName number)
        (extraRootCarrierName number InterventionVariable)
        (extraRootCarrierName number NeedVariable)
      | number <- [1 .. mixedRootCount fixture]
      ]
    structuralOwnership slot =
      ownershipNamed
        Asserted
        slot
        (ownershipOccurrenceName slot)
        (structuralOwnerName owner)
        (variableOccurrenceName member)
      where
        (owner, member) = traceOwnershipSlotVariables slot
    alternativeRelations =
      concat
        [ [ relationNamed
              Asserted
              VisionObjectiveOrientsStrategyObjective
              (alternativeObjectiveRelationName number)
              (alternativeCarrierName number VisionObjectiveVariable)
              (variableOccurrenceName StrategyObjectiveVariable)
          ]
          ++ [ relationNamed
               Asserted
               VisionOrientsStrategy
               (alternativeVisionRelationName number)
               (alternativeCarrierName number VisionVariable)
               (variableOccurrenceName StrategyVariable)
             | not
                 (isMissingSlot
                    fixture
                    (RelationTraceSlot VisionOrientsStrategy))
             ]
        | number <- [1 .. lexAlternativeCount fixture]
        ]

isMissingSlot :: Fixture -> TraceSlot -> Bool
isMissingSlot fixture slot =
  case fixture of
    MissingFixture missing -> slot == RelationTraceSlot missing
    MissingSlotsFixture missing -> slot `elem` missing
    AmbiguousProjectionFixture _ ->
      slot == RelationTraceSlot VisionOrientsStrategy
    EmptyProjectionFixture ->
      slot
        `elem` [ RelationTraceSlot VisionOrientsStrategy
               , RelationTraceSlot VisionObjectiveOrientsStrategyObjective
               , OwnershipTraceSlot VisionObjectiveAtVision
               ]
    ProjectionScalingFixture _ ->
      slot
        `elem` [ RelationTraceSlot VisionOrientsStrategy
               , RelationTraceSlot VisionObjectiveOrientsStrategyObjective
               , OwnershipTraceSlot VisionObjectiveAtVision
               ]
    DisjointSupportFixture ->
      slot == RelationTraceSlot InterventionChangesSituation
    AllMissingFixture -> True
    AllNonRootMissingFixture -> slot /= RelationTraceSlot rootSlot
    _ -> False

usesStructuralOwners :: Fixture -> Bool
usesStructuralOwners fixture =
  fixture `elem` [AllMissingFixture, AllNonRootMissingFixture]

fixtureCarriesVariable :: Fixture -> TraceVariable -> Bool
fixtureCarriesVariable fixture variable =
  case fixture of
    EmptyProjectionFixture ->
      variable `notElem` [VisionVariable, VisionObjectiveVariable]
    _ -> True

isOmittedOwnership :: Fixture -> TraceOwnershipSlot -> Bool
isOmittedOwnership fixture slot =
  fixture == EmptyProjectionFixture && slot == VisionObjectiveAtVision

carrier :: Fixture -> TraceVariable -> CarrierProjection
carrier fixture variable =
  carrierNamedWithType
    variable
    (fixtureVariableType fixture variable)
    (variableOccurrenceName variable)

carrierNamed :: TraceVariable -> String -> CarrierProjection
carrierNamed variable = carrierNamedWithType variable (variableType variable)

carrierNamedWithType ::
     TraceVariable -> CoreO2IType -> String -> CarrierProjection
carrierNamedWithType variable selectedType name =
  carrierProjection
    (occurrenceId name)
    (variableCategory variable)
    selectedType
    Asserted

ownership :: Fixture -> TraceOwnershipSlot -> ContextualizationProjection
ownership fixture slot =
  ownershipNamed
    (slotCommitment fixture (OwnershipTraceSlot slot))
    slot
    (ownershipOccurrenceName slot)
    (variableOccurrenceName owner)
    (variableOccurrenceName member)
  where
    (owner, member) = traceOwnershipSlotVariables slot

ownershipNamed ::
     Commitment
  -> TraceOwnershipSlot
  -> String
  -> String
  -> String
  -> ContextualizationProjection
ownershipNamed commitment _ name owner member =
  contextualizationProjection
    (occurrenceId name)
    (occurrenceId owner)
    (occurrenceId member)
    commitment

relation :: Fixture -> TraceRelationSlot -> RelationProjection
relation fixture slot =
  relationNamed
    commitment
    slot
    (relationOccurrenceName slot)
    sourceName
    (variableOccurrenceName target)
  where
    (source, target) = traceRelationSlotVariables slot
    sourceName
      | fixture == InconsistentFixture && slot == StrategyDirectsIntervention =
        "strategy-alternate"
      | otherwise = variableOccurrenceName source
    commitment = slotCommitment fixture (RelationTraceSlot slot)

relationNamed ::
     Commitment
  -> TraceRelationSlot
  -> String
  -> String
  -> String
  -> RelationProjection
relationNamed commitment slot name source target =
  relationProjection
    (occurrenceId name)
    (occurrenceId source)
    (traceRelationSlotToken slot)
    (occurrenceId target)
    commitment

denseOwnership :: Int -> [ContextualizationProjection]
denseOwnership number =
  [ ownershipNamed
      Asserted
      NeedDriverAtNeed
      (denseOwnershipName number "driver")
      (variableOccurrenceName NeedVariable)
      (denseCarrierName number NeedDriverVariable)
  , ownershipNamed
      Asserted
      NeedObjectiveAtNeed
      (denseOwnershipName number "objective")
      (variableOccurrenceName NeedVariable)
      (denseCarrierName number NeedObjectiveVariable)
  ]

denseRelation :: Int -> [RelationProjection]
denseRelation number =
  [ relationNamed
      Asserted
      NeedDriverGroundsNeedObjective
      (denseRelationName number "grounds")
      (denseCarrierName number NeedDriverVariable)
      (denseCarrierName number NeedObjectiveVariable)
  , relationNamed
      Asserted
      StrategyKeyResultTranslatesIntoNeedObjective
      (denseRelationName number "translates")
      (variableOccurrenceName StrategyKeyResultVariable)
      (denseCarrierName number NeedObjectiveVariable)
  , relationNamed
      Asserted
      InterventionKeyResultSubstantiatesNeedObjective
      (denseRelationName number "substantiates")
      (variableOccurrenceName InterventionKeyResultVariable)
      (denseCarrierName number NeedObjectiveVariable)
  , relationNamed
      Asserted
      SituationAnchorAnchorsNeedDriver
      (denseRelationName number "anchors")
      (variableOccurrenceName SituationAnchorVariable)
      (denseCarrierName number NeedDriverVariable)
  ]

slotCommitment :: Fixture -> TraceSlot -> Commitment
slotCommitment fixture slot =
  case fixture of
    CandidateFixture candidate
      | slot == RelationTraceSlot candidate -> Candidate
    MissingSlotsFixture missing
      | slot `elem` missing -> Candidate
    AllCandidateFixture -> Candidate
    AllNonRootCandidateFixture
      | slot /= RelationTraceSlot rootSlot -> Candidate
    ProjectionScalingFixture _
      | slot == OwnershipTraceSlot VisionObjectiveAtVision -> Candidate
    _ -> Asserted

structuralOwners :: [TraceVariable]
structuralOwners =
  [ VisionVariable
  , StrategyVariable
  , NeedVariable
  , InterventionVariable
  , MeasureVariable
  ]

structuralOwnerName :: TraceVariable -> String
structuralOwnerName variable =
  "carrier-structural-owner-" ++ Text.unpack (traceVariableId variable)

duplicateSupportCount :: Fixture -> Int
duplicateSupportCount fixture =
  case fixture of
    DuplicateSupportFixture count -> count
    _ -> 0

lexAlternativeCount :: Fixture -> Int
lexAlternativeCount fixture =
  case fixture of
    LexAlternativeFixture count -> count
    AmbiguousProjectionFixture count -> count
    DenseAlternativesFixture count -> count
    _ -> 0

alternativeOwnershipSpecs :: Fixture -> [(Int, Int)]
alternativeOwnershipSpecs fixture =
  case fixture of
    LexAlternativeFixture count -> [(number, number) | number <- [1 .. count]]
    AmbiguousProjectionFixture count ->
      [(number, number) | number <- [1 .. count]]
    DenseAlternativesFixture count ->
      [(number, number) | number <- [1 .. count]]
    _ -> []

denseAlternativeCount :: Fixture -> Int
denseAlternativeCount fixture =
  case fixture of
    DenseAlternativesFixture count -> count
    _ -> 0

domainScalingCount :: Fixture -> Int
domainScalingCount fixture =
  case fixture of
    DomainScalingFixture count -> count
    ProjectionScalingFixture count -> count
    _ -> 0

mixedRootCount :: Fixture -> Int
mixedRootCount fixture =
  case fixture of
    MixedRootsFixture count -> count
    _ -> 0

disjointVisionCarrier :: String
disjointVisionCarrier = "carrier-disjoint-vision"

disjointStrategyCarrier :: String
disjointStrategyCarrier = "carrier-disjoint-strategy"

disjointRelationName :: String
disjointRelationName = "relation-disjoint-vision-orients-strategy"

disjointRelationOccurrence :: OccurrenceIdentity
disjointRelationOccurrence = occurrenceId disjointRelationName

domainCarrierName :: Int -> String
domainCarrierName number = "carrier-domain-vision-" ++ show number

extraRootCarrierName :: Int -> TraceVariable -> String
extraRootCarrierName number variable =
  "carrier-root-"
    ++ show number
    ++ "-"
    ++ Text.unpack (traceVariableId variable)

extraRootRelationName :: Int -> String
extraRootRelationName number =
  "relation-root-" ++ show number ++ "-intervention-addresses-need"

duplicateRelationName :: Int -> TraceRelationSlot -> String
duplicateRelationName number slot =
  "relation-duplicate-"
    ++ show number
    ++ "-"
    ++ Text.unpack (traceRelationSlotId slot)

duplicateRootName :: String
duplicateRootName = "relation-intervention-addresses-need-duplicate"

denseCarrierName :: Int -> TraceVariable -> String
denseCarrierName number variable =
  "carrier-dense-"
    ++ show number
    ++ "-"
    ++ Text.unpack (traceVariableId variable)

denseOwnershipName :: Int -> String -> String
denseOwnershipName number suffix =
  "ownership-dense-" ++ show number ++ "-" ++ suffix

denseRelationName :: Int -> String -> String
denseRelationName number suffix =
  "relation-dense-" ++ show number ++ "-" ++ suffix

denseOccurrenceNames :: Int -> [String]
denseOccurrenceNames number =
  [ denseOwnershipName number "driver"
  , denseOwnershipName number "objective"
  , denseRelationName number "grounds"
  , denseRelationName number "translates"
  , denseRelationName number "substantiates"
  , denseRelationName number "anchors"
  ]

alternativeCarrierName :: Int -> TraceVariable -> String
alternativeCarrierName number variable =
  "carrier-a-" ++ show number ++ "-" ++ Text.unpack (traceVariableId variable)

selectedAlternativeCarrier :: Int -> TraceVariable -> String
selectedAlternativeCarrier number variable
  | number == 0 = variableOccurrenceName variable
  | otherwise = alternativeCarrierName number variable

alternativeOwnershipName :: Int -> Int -> String
alternativeOwnershipName owner member =
  "ownership-a-"
    ++ show owner
    ++ "-"
    ++ show member
    ++ "-vision-objective-at-vision"

alternativeVisionRelationName :: Int -> String
alternativeVisionRelationName number =
  "relation-a-" ++ show number ++ "-vision-orients-strategy"

alternativeObjectiveRelationName :: Int -> String
alternativeObjectiveRelationName number =
  "relation-a-" ++ show number ++ "-vision-objective-orients-strategy-objective"

variableOccurrenceName :: TraceVariable -> String
variableOccurrenceName = Text.unpack . ("carrier-" <>) . traceVariableId

ownershipOccurrenceName :: TraceOwnershipSlot -> String
ownershipOccurrenceName = Text.unpack . ("ownership-" <>) . traceOwnershipSlotId

relationOccurrenceName :: TraceRelationSlot -> String
relationOccurrenceName = Text.unpack . ("relation-" <>) . traceRelationSlotId

occurrenceModel :: String -> ModelOccurrence
occurrenceModel name =
  modelOccurrence (occurrenceId name) (modelId ("model-" ++ name))

variableIdentity :: TraceVariable -> ModelIdentity
variableIdentity = modelId . ("model-" ++) . variableOccurrenceName

variableBindings :: [(TraceVariable, ModelIdentity)]
variableBindings =
  [(variable, variableIdentity variable) | variable <- traceVariables]

expectedIdentity :: TraceIdentity
expectedIdentity = traceIdentityValue selectedViewIdentity variableBindings

variableCategory :: TraceVariable -> CoreCarrierCategory
variableCategory variable =
  exactCategory
    $ case variable of
        VisionVariable -> "Context"
        StrategyVariable -> "Context"
        NeedVariable -> "Context"
        InterventionVariable -> "Context"
        MeasureVariable -> "Context"
        SituationVariable -> "Context"
        MeasurePerformanceDimensionVariable -> "Structuring"
        SituationAnchorVariable -> "SituationAnchor"
        _ -> "Primitive"

variableType :: TraceVariable -> CoreO2IType
variableType variable =
  exactType
    $ case variable of
        VisionVariable -> "Vision"
        StrategyVariable -> "Strategy"
        NeedVariable -> "Need"
        InterventionVariable -> "Intervention"
        MeasureVariable -> "Measure"
        SituationVariable -> "Situation"
        VisionObjectiveVariable -> "Objective"
        StrategyDriverVariable -> "Driver"
        StrategyObjectiveVariable -> "Objective"
        StrategyActionVariable -> "Action"
        StrategyKeyResultVariable -> "KeyResult"
        NeedDriverVariable -> "Driver"
        NeedObjectiveVariable -> "Objective"
        InterventionActionVariable -> "Action"
        InterventionKeyResultVariable -> "KeyResult"
        MeasurePerformanceDimensionVariable -> "PerformanceDimension"
        MeasureKpiVariable -> "KPI"
        SituationAnchorVariable -> "BusinessCapability"

fixtureVariableType :: Fixture -> TraceVariable -> CoreO2IType
fixtureVariableType fixture variable =
  case (fixture, variable) of
    (AnchorFixture anchorType, SituationAnchorVariable) -> exactType anchorType
    _ -> variableType variable

selectedViewOccurrence :: ModelOccurrence
selectedViewOccurrence =
  modelOccurrence (occurrenceId "selected-view") selectedViewIdentity

selectedViewIdentity :: ModelIdentity
selectedViewIdentity = modelId "selected-view-identity"

foreignGraphIdentity :: ModelIdentity
foreignGraphIdentity = modelId "foreign-graph-identity"

modelId :: String -> ModelIdentity
modelId value =
  case modelIdentity (Text.pack value) of
    Left problem -> error ("model identity fixture: " ++ show problem)
    Right accepted -> accepted

occurrenceId :: String -> OccurrenceIdentity
occurrenceId value =
  case occurrenceIdentity (Text.pack value) of
    Left problem -> error ("occurrence identity fixture: " ++ show problem)
    Right accepted -> accepted

exactCategory :: Text -> CoreCarrierCategory
exactCategory value =
  exactValue "carrier category" value (lookupCoreCarrierCategory value)

exactType :: Text -> CoreO2IType
exactType value = exactValue "O2I type" value (lookupCoreO2IType value)

exactValue :: String -> Text -> Maybe result -> result
exactValue label value result =
  case result of
    Nothing -> error (label ++ " fixture missing " ++ Text.unpack value)
    Just accepted -> accepted
