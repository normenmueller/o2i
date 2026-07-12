{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Data.List (nub)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Text as Text
import Data.Time (UTCTime(..), fromGregorian, secondsToDiffTime)
import O2I
import Test.Tasty
import Test.Tasty.HUnit
import qualified Test.Tasty.QuickCheck as QC

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup "O2I" [structureTests, traceTests, evidenceTests, registryTests]

structureTests :: TestTree
structureTests =
  testGroup
    "structural elaboration"
    [ testCase "empty model is structurally well-formed"
        $ assertSuccess (validateStructure emptyModel)
    , testCase "complete reference model is structurally well-formed"
        $ assertSuccess (validateStructure sampleModel)
    , testCase "structural errors accumulate"
        $ case validateStructure multiplyInvalidModel of
            Failure errors ->
              assertBool
                "at least three errors are reported"
                (length errors >= 3)
            Success _ -> assertFailure "invalid model was accepted"
    , testCase "duplicate edges are rejected"
        $ assertFailureResult
            (validateStructure
               sampleModel
                 {rawEdges = head (rawEdges sampleModel) : rawEdges sampleModel})
    , testCase "wrong relation domains are rejected"
        $ assertFailureResult (validateStructure invalidRelationDomainModel)
    , testCase "edge errors accumulate independently"
        $ case validateStructure independentlyInvalidEdgeModel of
            Failure errors -> length errors @?= 3
            Success _ -> assertFailure "invalid edge was accepted"
    , QC.testProperty "unknown endpoints accumulate"
        $ QC.forAll unknownEndpointModel
        $ \raw ->
            case validateStructure raw of
              Failure errors -> length errors == 3
              Success _ -> False
    ]

traceTests :: TestTree
traceTests =
  testGroup
    "relational effect trace"
    ([ testCase "empty model is not traceable"
         $ withWellFormed emptyModel
         $ \model -> assertFailureResult (validateTraceability model)
     , testCase "complete reference model is traceable"
         $ withTraceable sampleModel (const (pure ()))
     , testCase "every addressed need requires a complete trace"
         $ withWellFormed additionalUntracedNeedModel
         $ \model -> assertFailureResult (validateTraceability model)
     , testCase "parallel primitive paths produce distinct traces"
         $ withTraceable twoPathModel
         $ \model -> do
             let identifiers =
                   map traceIdentifier (NonEmpty.toList (effectTraces model))
             length identifiers @?= 2
             length (nub identifiers) @?= 2
     ]
       ++ map missingEdgeTest (rawEdges sampleModel)
       ++ [ QC.testProperty "removing any trace edge is rejected"
              $ QC.forAll (QC.elements (rawEdges sampleModel))
              $ \missingEdge ->
                  traceabilityFails
                    sampleModel
                      { rawEdges =
                          filter (/= missingEdge) (rawEdges sampleModel)
                      }
          , QC.testProperty "all situation anchor types are traceable"
              $ QC.forAll (QC.elements [minBound .. maxBound])
              $ \anchor -> traceabilitySucceeds (modelWithAnchor anchor)
          ])

missingEdgeTest :: RawEdge -> TestTree
missingEdgeTest missingEdge =
  testCase ("trace rejects missing edge " ++ show missingEdge)
    $ withWellFormed
        sampleModel {rawEdges = filter (/= missingEdge) (rawEdges sampleModel)}
    $ \model -> assertFailureResult (validateTraceability model)

evidenceTests :: TestTree
evidenceTests =
  testGroup
    "effect evidence"
    [ testCase "complete evidence is assessed"
        $ withAssessed successfulClaim
        $ \assessment -> do
            effectResult assessment @?= Satisfied
            targetResult assessment @?= ObservedSatisfiedOnTime
    , testCase "effect can be supported before target achievement"
        $ withAssessed belowTargetClaim
        $ \assessment -> do
            effectResult assessment @?= Satisfied
            targetResult assessment @?= NotSatisfiedAtFollowUp
    , testCase "target achievement does not imply positive effect"
        $ withAssessed targetWithoutEffectClaim
        $ \assessment -> do
            effectResult assessment @?= NotSatisfied
            targetResult assessment @?= ObservedSatisfiedOnTime
    , testCase "late target achievement is distinguished"
        $ withAssessed lateTargetClaim
        $ \assessment -> targetResult assessment @?= ObservedSatisfiedAfterDue
    , testCase "zero effect criteria are rejected"
        $ withTraceable sampleModel
        $ \model ->
            let identifier =
                  traceIdentifier (NonEmpty.head (effectTraces model))
             in assertFailureResult
                  (assessEffectEvidence
                     model
                     (NonEmpty.singleton (zeroEffectClaim identifier)))
    , testCase "duplicate claims for one trace are rejected"
        $ withTraceable sampleModel
        $ \model ->
            let identifier =
                  traceIdentifier (NonEmpty.head (effectTraces model))
                evidenceClaim = successfulClaim identifier
             in assertFailureResult
                  (assessEffectEvidence
                     model
                     (evidenceClaim NonEmpty.:| [evidenceClaim]))
    , testCase "evidence criteria must precede intervention"
        $ withTraceable sampleModel
        $ \model ->
            assertFailureResult
              (assessEffectEvidence
                 model
                 (NonEmpty.singleton (latePlanClaim (traceId model))))
    , testCase "observation units must match"
        $ withTraceable sampleModel
        $ \model ->
            assertFailureResult
              (assessEffectEvidence
                 model
                 (NonEmpty.singleton (mismatchedUnitClaim (traceId model))))
    , testCase "observation time order is validated"
        $ withTraceable sampleModel
        $ \model ->
            assertFailureResult
              (assessEffectEvidence
                 model
                 (NonEmpty.singleton (invalidTimeClaim (traceId model))))
    , testCase "claims must reference the traced KPI and anchor"
        $ withTraceable sampleModel
        $ \model ->
            assertFailureResult
              (assessEffectEvidence
                 model
                 (NonEmpty.singleton (mismatchedTraceClaim (traceId model))))
    , testCase "units and evidence sources must be named"
        $ withTraceable sampleModel
        $ \model -> do
            assertFailureResult
              (assessEffectEvidence
                 model
                 (NonEmpty.singleton (emptyUnitClaim (traceId model))))
            assertFailureResult
              (assessEffectEvidence
                 model
                 (NonEmpty.singleton (emptySourceClaim (traceId model))))
    , QC.testProperty "positive effect thresholds are accepted"
        $ QC.forAll (QC.chooseInteger (1, 100))
        $ \threshold ->
            evidenceSucceeds
              (\identifier ->
                 setEffectCriterion
                   (IncreaseByAtLeast (Quantity (fromInteger threshold) percent))
                   (claim identifier (fromInteger threshold + 40) targetDate))
    , QC.testProperty "both effect directions are assessed"
        $ QC.forAll ((,) <$> QC.arbitrary <*> QC.chooseInteger (1, 100))
        $ \(increases, threshold) ->
            evidenceSucceeds (directionalClaim increases threshold)
    ]

registryTests :: TestTree
registryTests =
  testGroup
    "typed registries"
    [ QC.testProperty "relation lookup round-trips"
        $ QC.forAll (QC.elements allRelations) relationRoundTrips
    , testCase "relation registry identities are unique"
        $ assertBool "duplicate relation identity" relationRegistryIsUnique
    , testCase "every relation code is represented"
        $ relationCodes @?= allRelationCodes
    , QC.testProperty "interpretation lookup round-trips"
        $ QC.forAll (QC.elements allInterpretations) interpretationRoundTrips
    , testCase "every interpretation code is represented"
        $ interpretationCodes @?= [minBound .. maxBound]
    ]

relationRoundTrips :: SomeRelation -> Bool
relationRoundTrips relation =
  relation `elem` lookupRelations (relationNameOf relation)

relationRegistryIsUnique :: Bool
relationRegistryIsUnique = identities == nub identities
  where
    identities = map relationIdentity allRelations

relationCodes :: [RelationCode]
relationCodes = nub (map relationCodeOf allRelations)

interpretationRoundTrips :: SomeInterpretation -> Bool
interpretationRoundTrips interpretation =
  case lookupInterpretation context primitive of
    Just _ -> True
    Nothing -> False
  where
    (context, primitive) = interpretationIdentity interpretation

interpretationCodes :: [InterpretationCode]
interpretationCodes = map interpretationCodeOf allInterpretations

withWellFormed :: RawModel -> (WellFormedModel -> Assertion) -> Assertion
withWellFormed raw action =
  case validateStructure raw of
    Failure errors -> assertFailure ("structural errors: " ++ show errors)
    Success model -> action model

withTraceable :: RawModel -> (TraceableEffectModel -> Assertion) -> Assertion
withTraceable raw action =
  withWellFormed raw $ \model ->
    case validateTraceability model of
      Failure errors -> assertFailure ("traceability errors: " ++ show errors)
      Success traceable -> action traceable

withAssessed ::
     (EffectTraceId -> EvidenceClaim)
  -> (EffectAssessment -> Assertion)
  -> Assertion
withAssessed makeClaim action =
  withTraceable sampleModel $ \model ->
    case assessEffectEvidence
           model
           (NonEmpty.singleton (makeClaim (traceId model))) of
      Failure errors -> assertFailure ("evidence errors: " ++ show errors)
      Success assessed -> action (NonEmpty.head (effectAssessments assessed))

traceId :: TraceableEffectModel -> EffectTraceId
traceId = traceIdentifier . NonEmpty.head . effectTraces

traceabilityFails :: RawModel -> Bool
traceabilityFails raw =
  case validateStructure raw of
    Failure _ -> False
    Success model ->
      case validateTraceability model of
        Failure _ -> True
        Success _ -> False

traceabilitySucceeds :: RawModel -> Bool
traceabilitySucceeds raw =
  case validateStructure raw of
    Failure _ -> False
    Success model ->
      case validateTraceability model of
        Failure _ -> False
        Success _ -> True

evidenceSucceeds :: (EffectTraceId -> EvidenceClaim) -> Bool
evidenceSucceeds makeClaim =
  case validateStructure sampleModel of
    Failure _ -> False
    Success model ->
      case validateTraceability model of
        Failure _ -> False
        Success traceable ->
          case assessEffectEvidence
                 traceable
                 (NonEmpty.singleton (makeClaim (traceId traceable))) of
            Failure _ -> False
            Success _ -> True

assertSuccess :: Validation errors result -> Assertion
assertSuccess (Success _) = pure ()
assertSuccess (Failure _) = assertFailure "expected validation success"

assertFailureResult :: Validation errors result -> Assertion
assertFailureResult (Failure _) = pure ()
assertFailureResult (Success _) = assertFailure "expected validation failure"

emptyModel :: RawModel
emptyModel = RawModel [] []

sampleModel :: RawModel
sampleModel = RawModel sampleNodes sampleEdges

twoPathModel :: RawModel
twoPathModel =
  RawModel
    (sampleNodes ++ map duplicateChild childNodes)
    (sampleEdges ++ map duplicateEdge evidenceEdges)
  where
    childNodes = filter (not . isContextNode) sampleNodes
    evidenceEdges =
      filter
        (\candidate ->
           not
             (isContextId (rawEdgeFrom candidate)
                && isContextId (rawEdgeTo candidate)))
        sampleEdges

duplicateChild :: RawNode -> RawNode
duplicateChild (RawPrimitiveNode identifier owner primitive) =
  RawPrimitiveNode (duplicateId identifier) owner primitive
duplicateChild (RawStructuringNode identifier owner structuring) =
  RawStructuringNode (duplicateId identifier) owner structuring
duplicateChild (RawAnchorNode identifier owner anchor) =
  RawAnchorNode (duplicateId identifier) owner anchor
duplicateChild node@(RawContextNode _ _) = node

duplicateEdge :: RawEdge -> RawEdge
duplicateEdge candidate =
  candidate
    { rawEdgeFrom = duplicateIfChild (rawEdgeFrom candidate)
    , rawEdgeTo = duplicateIfChild (rawEdgeTo candidate)
    }

duplicateIfChild :: RawNodeId -> RawNodeId
duplicateIfChild identifier
  | isContextId identifier = identifier
  | otherwise = duplicateId identifier

duplicateId :: RawNodeId -> RawNodeId
duplicateId (RawNodeId identifier) = RawNodeId ("second-" <> identifier)

isContextNode :: RawNode -> Bool
isContextNode (RawContextNode _ _) = True
isContextNode _ = False

isContextId :: RawNodeId -> Bool
isContextId identifier =
  identifier
    `elem` [ visionId
           , strategyId
           , needId
           , interventionId
           , measureId
           , situationId
           ]

modelWithAnchor :: SituationAnchor -> RawModel
modelWithAnchor anchor =
  sampleModel {rawNodes = map replaceAnchor (rawNodes sampleModel)}
  where
    replaceAnchor (RawAnchorNode identifier owner _) =
      RawAnchorNode identifier owner anchor
    replaceAnchor node = node

sampleNodes :: [RawNode]
sampleNodes =
  [ RawContextNode visionId Vision
  , RawContextNode strategyId Strategy
  , RawContextNode needId Need
  , RawContextNode interventionId Intervention
  , RawContextNode measureId Measure
  , RawContextNode situationId Situation
  , RawPrimitiveNode visionObjectiveId visionId Objective
  , RawPrimitiveNode strategyDriverId strategyId Driver
  , RawPrimitiveNode strategyObjectiveId strategyId Objective
  , RawPrimitiveNode strategyKeyResultId strategyId KeyResult
  , RawPrimitiveNode strategyActionId strategyId Action
  , RawPrimitiveNode needDriverId needId Driver
  , RawPrimitiveNode needObjectiveId needId Objective
  , RawPrimitiveNode interventionActionId interventionId Action
  , RawPrimitiveNode interventionKeyResultId interventionId KeyResult
  , RawPrimitiveNode measureKpiId measureId KPI
  , RawStructuringNode measureDomainId measureId Domain
  , RawAnchorNode situationAnchorId situationId BusinessCapability
  ]

sampleEdges :: [RawEdge]
sampleEdges =
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
  , anchorEdge situationId constitutedByAnchor situationAnchorId
  , anchorEdge situationAnchorId anchorsNeedDriver needDriverId
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
  , edge strategyDriverId indicatesMeasureDomain measureDomainId
  , edge strategyKeyResultId determinesMeasureDomain measureDomainId
  , edge measureDomainId containsMeasureKPI measureKpiId
  , edge interventionKeyResultId setsTargetForMeasureKPI measureKpiId
  , anchorEdge interventionActionId changesAnchor situationAnchorId
  , anchorEdge measureKpiId measuresAnchor situationAnchorId
  ]

edge :: RawNodeId -> Relation from to -> RawNodeId -> RawEdge
edge from relation to = RawEdge from (relationNameFor relation) to

anchorEdge ::
     RawNodeId
  -> (SSituationAnchor 'BusinessCapability -> Relation from to)
  -> RawNodeId
  -> RawEdge
anchorEdge from relation to = edge from (relation SBusinessCapability) to

multiplyInvalidModel :: RawModel
multiplyInvalidModel =
  RawModel
    [ RawContextNode strategyId Strategy
    , RawContextNode strategyId Need
    , RawPrimitiveNode needObjectiveId missingId KPI
    ]
    [RawEdge missingId (RelationName "unknown") strategyId]

invalidRelationDomainModel :: RawModel
invalidRelationDomainModel =
  RawModel
    [RawContextNode strategyId Strategy, RawContextNode needId Need]
    [edge needId qualifiesNeed strategyId]

independentlyInvalidEdgeModel :: RawModel
independentlyInvalidEdgeModel =
  RawModel
    []
    [ RawEdge
        (RawNodeId "unknown-from")
        (RelationName "unknown")
        (RawNodeId "unknown-to")
    ]

unknownEndpointModel :: QC.Gen RawModel
unknownEndpointModel = do
  suffix <- QC.listOf1 (QC.elements ['a' .. 'z'])
  let from = RawNodeId ("unknown-from-" <> Text.pack suffix)
      to = RawNodeId ("unknown-to-" <> Text.pack suffix)
  pure (RawModel [] [RawEdge from (RelationName "unknown") to])

additionalUntracedNeedModel :: RawModel
additionalUntracedNeedModel =
  sampleModel
    { rawNodes =
        RawContextNode additionalNeedId Need
          : RawPrimitiveNode
              additionalNeedObjectiveId
              additionalNeedId
              Objective
          : rawNodes sampleModel
    , rawEdges =
        edge interventionId addressesNeed additionalNeedId
          : rawEdges sampleModel
    }

successfulClaim :: EffectTraceId -> EvidenceClaim
successfulClaim identifier = claim identifier 75 targetDate

belowTargetClaim :: EffectTraceId -> EvidenceClaim
belowTargetClaim identifier = claim identifier 60 targetDate

targetWithoutEffectClaim :: EffectTraceId -> EvidenceClaim
targetWithoutEffectClaim identifier =
  setEffectCriterion
    (IncreaseByAtLeast (Quantity 10 percent))
    ((claim identifier 75 targetDate)
       {baseline = observation 72 baselineDate percent})

lateTargetClaim :: EffectTraceId -> EvidenceClaim
lateTargetClaim identifier = claim identifier 75 earlyTargetDate

mismatchedUnitClaim :: EffectTraceId -> EvidenceClaim
mismatchedUnitClaim identifier =
  (successfulClaim identifier) {followUp = observation 75 followUpDate count}

invalidTimeClaim :: EffectTraceId -> EvidenceClaim
invalidTimeClaim identifier =
  (successfulClaim identifier) {baseline = observation 40 followUpDate percent}

mismatchedTraceClaim :: EffectTraceId -> EvidenceClaim
mismatchedTraceClaim identifier =
  (successfulClaim identifier)
    { followUp =
        (followUp (successfulClaim identifier)) {observationKPI = missingId}
    }

zeroEffectClaim :: EffectTraceId -> EvidenceClaim
zeroEffectClaim identifier =
  setEffectCriterion
    (IncreaseByAtLeast (Quantity 0 percent))
    (successfulClaim identifier)

emptyUnitClaim :: EffectTraceId -> EvidenceClaim
emptyUnitClaim identifier =
  setEffectCriterion
    (IncreaseByAtLeast (Quantity 10 (Unit " ")))
    (successfulClaim identifier)

emptySourceClaim :: EffectTraceId -> EvidenceClaim
emptySourceClaim identifier =
  (successfulClaim identifier)
    { followUp =
        (followUp (successfulClaim identifier))
          {observationSource = EvidenceSource " "}
    }

latePlanClaim :: EffectTraceId -> EvidenceClaim
latePlanClaim identifier =
  let evidenceClaim = successfulClaim identifier
   in evidenceClaim
        { evidencePlan =
            (evidencePlan evidenceClaim) {establishedAt = interventionDate}
        }

directionalClaim :: Bool -> Integer -> EffectTraceId -> EvidenceClaim
directionalClaim increases threshold identifier =
  if increases
    then setEffectCriterion
           (IncreaseByAtLeast quantity)
           (claim identifier (40 + amount) targetDate)
    else setTargetCriterion
           (AtMost (Quantity 40 percent))
           (setEffectCriterion
              (DecreaseByAtLeast quantity)
              (claim identifier (40 - amount) targetDate))
  where
    amount = fromInteger threshold
    quantity = Quantity amount percent

claim :: EffectTraceId -> Rational -> UTCTime -> EvidenceClaim
claim identifier followValue due =
  EvidenceClaim
    { evidenceTrace = identifier
    , evidenceInterventionKeyResult = interventionKeyResultId
    , evidencePlan =
        EvidencePlan
          { establishedAt = criteriaDate
          , interventionStartedAt = interventionDate
          , targetDueAt = due
          , effectCriterion = IncreaseByAtLeast (Quantity 10 percent)
          , targetCriterion = AtLeast (Quantity 70 percent)
          }
    , baseline = observation 40 baselineDate percent
    , followUp = observation followValue followUpDate percent
    }

setEffectCriterion :: EffectCriterion -> EvidenceClaim -> EvidenceClaim
setEffectCriterion criterion evidenceClaim =
  evidenceClaim
    {evidencePlan = (evidencePlan evidenceClaim) {effectCriterion = criterion}}

setTargetCriterion :: TargetCriterion -> EvidenceClaim -> EvidenceClaim
setTargetCriterion criterion evidenceClaim =
  evidenceClaim
    {evidencePlan = (evidencePlan evidenceClaim) {targetCriterion = criterion}}

observation :: Rational -> UTCTime -> Unit -> Observation
observation value observedTimestamp valueUnit =
  Observation
    { observationKPI = measureKpiId
    , observationAnchor = situationAnchorId
    , observedAt = observedTimestamp
    , observedValue = Quantity value valueUnit
    , observationSource = EvidenceSource "decision registry"
    }

criteriaDate, baselineDate, interventionDate, earlyTargetDate, targetDate, followUpDate ::
     UTCTime
criteriaDate = timestamp 2025 12 1

baselineDate = timestamp 2026 1 1

interventionDate = timestamp 2026 2 1

earlyTargetDate = timestamp 2026 2 15

targetDate = timestamp 2026 6 30

followUpDate = timestamp 2026 6 1

timestamp :: Integer -> Int -> Int -> UTCTime
timestamp year month day =
  UTCTime (fromGregorian year month day) (secondsToDiffTime 0)

percent, count :: Unit
percent = Unit "percent"

count = Unit "count"

visionId, strategyId, needId, additionalNeedId, interventionId :: RawNodeId
visionId = RawNodeId "vision"

strategyId = RawNodeId "strategy"

needId = RawNodeId "need"

additionalNeedId = RawNodeId "additional-need"

interventionId = RawNodeId "intervention"

measureId, situationId, missingId :: RawNodeId
measureId = RawNodeId "measure"

situationId = RawNodeId "situation"

missingId = RawNodeId "missing"

visionObjectiveId, strategyDriverId, strategyObjectiveId :: RawNodeId
visionObjectiveId = RawNodeId "vision-objective"

strategyDriverId = RawNodeId "strategy-driver"

strategyObjectiveId = RawNodeId "strategy-objective"

strategyKeyResultId, strategyActionId, needDriverId :: RawNodeId
strategyKeyResultId = RawNodeId "strategy-key-result"

strategyActionId = RawNodeId "strategy-action"

needDriverId = RawNodeId "need-driver"

needObjectiveId, additionalNeedObjectiveId, interventionActionId :: RawNodeId
needObjectiveId = RawNodeId "need-objective"

additionalNeedObjectiveId = RawNodeId "additional-need-objective"

interventionActionId = RawNodeId "intervention-action"

interventionKeyResultId, measureKpiId, measureDomainId :: RawNodeId
interventionKeyResultId = RawNodeId "intervention-key-result"

measureKpiId = RawNodeId "measure-kpi"

measureDomainId = RawNodeId "measure-domain"

situationAnchorId :: RawNodeId
situationAnchorId = RawNodeId "situation-anchor"
