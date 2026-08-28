{-# LANGUAGE OverloadedStrings #-}

-- | Collection validation and non-aggregating observation evaluation.
module O2I.Assessment.Eval
  ( assessEvidenceInternal
  , assessEvidenceWithWorkInternal
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Ratio ((%))
import qualified Data.Set as Set
import qualified Data.Text as Text
import O2I.Assessment.Internal
import O2I.Core.Contract (coreRuleIdText)
import O2I.Core.Identity (modelIdentityText)
import O2I.Readiness.Internal
import O2I.Trace
  ( TraceVariable(..)
  , traceIdentityBinding
  , traceIdentityBindings
  , traceIdentityGraphIdentity
  )

data ValueDomainIndex
  = QuantitativeDomainIndex !Unit
  | OrdinalDomainIndex !CanonicalText !(Map CanonicalText Integer)
  | CategoricalDomainIndex !(Set.Set CanonicalText)

data CriterionIndex
  = NoCriterionIndex
  | CategoricalCriterionIndex !(Set.Set CanonicalText)

data AssessmentIndexes = AssessmentIndexes
  { indexedValueDomain :: !ValueDomainIndex
  , indexedEffectCriterion :: !CriterionIndex
  , indexedTargetCriterion :: !CriterionIndex
  }

assessEvidenceInternal :: AssessmentSubject scope -> AssessmentResult scope
assessEvidenceInternal = fst . assessEvidenceWithWorkInternal

assessEvidenceWithWorkInternal ::
     AssessmentSubject scope -> (AssessmentResult scope, AssessmentWork)
assessEvidenceWithWorkInternal subject =
  case collectionDefects of
    first:remaining ->
      ( AssessmentInputInvalid graph trace (first :| remaining)
      , work collectionDefects [] 0 (Set.size observationIdentityIndex))
    [] ->
      let indexes =
            buildAssessmentIndexes
              (storedKpiDomain (storedKpiDefinition readiness))
              (storedEffectCriterion plan)
              (storedTargetCriterion plan)
          itemResults = map (assessObservation indexes) observations
          allValid = all isAssessed itemResults
          proof =
            if allValid
              then Just
                     (EvidenceAssessedProof
                        graph
                        trace
                        (fromIntegral (length observations)))
              else Nothing
          collectedItemDefects = concatMap observationDefects itemResults
       in ( AssessmentObservationsCompleted graph trace itemResults proof
          , work
              []
              collectedItemDefects
              (length observations)
              (Set.size observationIdentityIndex + assessmentIndexSize indexes))
  where
    ready = storedAssessmentReadyProof subject
    graph = storedReadyGraphIdentity ready
    trace = storedReadyTraceIdentity ready
    readiness = storedReadyInput ready
    plan = storedEvidencePlan readiness
    bundle = storedBoundAssessmentBundle (storedAssessmentSubjectBundle subject)
    actual = storedActualStart bundle
    observations = storedObservations bundle
    expectedIntervention = traceIdentityBinding trace InterventionVariable
    actualKey = ActualStartKey expectedIntervention
    subjectKey = AssessmentSubjectKey graph trace
    setKey = ObservationSetKey graph trace
    observationKeys =
      [ (storedObservationTrace observation, storedObservedAt observation)
      | observation <- observations
      ]
    observationIdentityIndex = Set.fromList observationKeys
    collectionDefects =
      sortAssessmentDefects
        ([ defect AssessmentTraceObservationCoverage subjectKey
         | null observations
         ]
           <> [ defect AssessmentObservationUniqueness setKey
              | Set.size observationIdentityIndex /= length observationKeys
              ]
           <> [ defect AssessmentActualStartCardinality actualKey
              | storedActualIntervention actual /= expectedIntervention
              ]
           <> [ defect AssessmentActualStartChronology actualKey
              | not
                  (storedReadinessCheckedAt readiness
                     < storedActualStartAt actual
                     && storedActualStartAt actual <= storedAssessedAt bundle)
              ])
    assessObservation indexes observation =
      case itemDefects indexes observation of
        first:remaining -> InvalidObservation observation (first :| remaining)
        [] ->
          AssessedObservation
            observation
            (assessEffect
               indexes
               (storedKpiDomain (storedKpiDefinition readiness))
               (storedBaselineValue (storedBaseline plan))
               (storedEffectCriterion plan)
               (storedObservationValue observation))
            (assessTarget
               indexes
               (storedKpiDomain (storedKpiDefinition readiness))
               (storedTargetCriterion plan)
               (storedTargetDueAt plan)
               observation)
            (CausalityNotEstablished
               :| [FirstTargetAttainmentTimeNotEstablished])
    itemDefects indexes observation =
      sortAssessmentDefects
        ([defect AssessmentTraceIdentity key | observedTrace /= trace]
           <> [ defect AssessmentKpiIdentity key
              | traceIdentityBinding observedTrace MeasureKpiVariable
                  /= traceIdentityBinding trace MeasureKpiVariable
              ]
           <> [ defect AssessmentAnchorIdentity key
              | traceIdentityBinding observedTrace SituationAnchorVariable
                  /= traceIdentityBinding trace SituationAnchorVariable
              ]
           <> [ defect AssessmentObservationValueDomain key
              | not
                  (domainContains
                     (indexedValueDomain indexes)
                     (storedObservationValue observation))
              ]
           <> [ defect AssessmentSourceNonempty key
              | not (validSource (storedObservationSource observation))
              ]
           <> [ defect AssessmentObservationChronology key
              | not
                  (storedActualStartAt actual < storedObservedAt observation
                     && storedObservedAt observation <= storedAssessedAt bundle)
              ])
      where
        observedTrace = storedObservationTrace observation
        key = ObservationKey observedTrace (storedObservedAt observation)
    work collection item transitionCount indexEntries =
      let defects = collection <> item
          entries = length defects + transitionCount
       in emptyAssessmentWork
            { assessmentInputOccurrences = assessmentBundleSize bundle
            , assessmentTraceSupportOccurrences =
                storedAssessmentTraceSupport subject
            , assessmentReadinessCriteriaEvaluated =
                storedAssessmentReadinessCriteria subject
            , assessmentSubmittedObservations = length observations
            , assessmentAddressedObservationSupport =
                if null collection
                  then 3 * length observations
                  else 0
            , assessmentIndexEntries = indexEntries
            , assessmentOrderingEntries = entries
            , assessmentOrderingKeyScalars =
                sum (map defectKeyScalarLength defects)
                  + if null collection
                      then sum
                             [ evidenceKeyScalarLength
                               (ObservationKey
                                  (storedObservationTrace observation)
                                  (storedObservedAt observation))
                             | observation <- observations
                             ]
                      else 0
            , assessmentTransitions = transitionCount
            , assessmentRetainedEntries = entries
            }

defect :: AssessmentRule -> AssessmentEvidenceKey -> AssessmentDefect
defect ruleValue = AssessmentDefect (assessmentRuleId ruleValue)

isAssessed :: ObservationAssessment scope -> Bool
isAssessed result =
  case result of
    InvalidObservation {} -> False
    AssessedObservation {} -> True

observationDefects :: ObservationAssessment scope -> [AssessmentDefect]
observationDefects result =
  case result of
    InvalidObservation _ defects -> NonEmpty.toList defects
    AssessedObservation {} -> []

validSource :: CanonicalText -> Bool
validSource (CanonicalText value) = not (Text.null value)

buildAssessmentIndexes ::
     ValueDomain -> EffectCriterion -> TargetCriterion -> AssessmentIndexes
buildAssessmentIndexes domain effectCriterion targetCriterion =
  AssessmentIndexes
    { indexedValueDomain =
        case domain of
          QuantitativeDomain unit _ -> QuantitativeDomainIndex unit
          OrdinalDomain scale levels _ ->
            OrdinalDomainIndex scale (rankIndex levels)
          CategoricalDomain admitted ->
            CategoricalDomainIndex (Set.fromList (NonEmpty.toList admitted))
    , indexedEffectCriterion =
        case effectCriterion of
          CategoricalTransitionEffect accepted ->
            CategoricalCriterionIndex (Set.fromList (NonEmpty.toList accepted))
          _ -> NoCriterionIndex
    , indexedTargetCriterion =
        case targetCriterion of
          CategoricalMembership accepted ->
            CategoricalCriterionIndex (Set.fromList (NonEmpty.toList accepted))
          _ -> NoCriterionIndex
    }

assessmentIndexSize :: AssessmentIndexes -> Int
assessmentIndexSize indexes =
  domainIndexSize (indexedValueDomain indexes)
    + criterionIndexSize (indexedEffectCriterion indexes)
    + criterionIndexSize (indexedTargetCriterion indexes)
  where
    domainIndexSize domainIndex =
      case domainIndex of
        QuantitativeDomainIndex _ -> 0
        OrdinalDomainIndex _ ranks -> Map.size ranks
        CategoricalDomainIndex admitted -> Set.size admitted
    criterionIndexSize criterionIndex =
      case criterionIndex of
        NoCriterionIndex -> 0
        CategoricalCriterionIndex accepted -> Set.size accepted

domainContains :: ValueDomainIndex -> DomainValue -> Bool
domainContains domainIndex value =
  case (domainIndex, value) of
    (QuantitativeDomainIndex expected, QuantitativeValue _ actual) ->
      expected == actual
    (OrdinalDomainIndex scale ranks, OrdinalValue actualScale level) ->
      scale == actualScale && Map.member level ranks
    (CategoricalDomainIndex admitted, CategoricalValue actual) ->
      Set.member actual admitted
    _ -> False

assessEffect ::
     AssessmentIndexes
  -> ValueDomain
  -> DomainValue
  -> EffectCriterion
  -> DomainValue
  -> EffectResult
assessEffect indexes domain baseline criterionValue observed =
  case (indexedValueDomain indexes, domain, baseline, criterionValue, observed) of
    (QuantitativeDomainIndex _, QuantitativeDomain _ direction, QuantitativeValue baselineValue _, QuantitativeAbsoluteEffect (PositiveDecimal minimumDelta), QuantitativeValue observedValue _) ->
      satisfied
        (directionAdjusted direction baselineValue observedValue
           >= decimalRational minimumDelta)
    (QuantitativeDomainIndex _, QuantitativeDomain _ direction, QuantitativeValue baselineValue _, QuantitativeRelativeEffect (PositiveDecimal minimumRatio), QuantitativeValue observedValue _)
      | decimalRational baselineValue == 0 -> EffectNotAssessableZeroBaseline
      | otherwise ->
        satisfied
          (directionAdjusted direction baselineValue observedValue
             / abs (decimalRational baselineValue)
             >= decimalRational minimumRatio)
    (OrdinalDomainIndex _ ranks, OrdinalDomain _ _ direction, OrdinalValue _ baselineLevel, OrdinalStepsEffect minimumSteps, OrdinalValue _ observedLevel) ->
      satisfied
        (adjustedSteps direction ranks baselineLevel observedLevel
           >= toInteger minimumSteps)
    (CategoricalDomainIndex {}, CategoricalDomain _, CategoricalValue baselineValue, CategoricalTransitionEffect _, CategoricalValue observedValue) ->
      case indexedEffectCriterion indexes of
        CategoricalCriterionIndex accepted ->
          satisfied
            (observedValue /= baselineValue && Set.member observedValue accepted)
        NoCriterionIndex ->
          error "EvidenceReady proof lost categorical effect index"
    _ -> error "EvidenceReady proof admitted incompatible effect values"

assessTarget ::
     AssessmentIndexes
  -> ValueDomain
  -> TargetCriterion
  -> UtcTimestamp
  -> Observation
  -> TargetAttainment
assessTarget indexes domain criterionValue due observation =
  if targetSatisfied
    then if storedObservedAt observation <= due
           then TargetSatisfiedInObservationByDue
           else TargetSatisfiedInObservationAfterDue
    else TargetNotSatisfiedInObservation
  where
    observed = storedObservationValue observation
    targetSatisfied =
      case (indexedValueDomain indexes, domain, criterionValue, observed) of
        (QuantitativeDomainIndex _, QuantitativeDomain {}, QuantitativeThreshold comparison target _, QuantitativeValue value _) ->
          compareQuantitative comparison value target
        (OrdinalDomainIndex _ ranks, OrdinalDomain {}, OrdinalThreshold comparison _ targetLevel, OrdinalValue _ value) ->
          compareOrdinal comparison ranks value targetLevel
        (CategoricalDomainIndex {}, CategoricalDomain {}, CategoricalMembership _, CategoricalValue value) ->
          case indexedTargetCriterion indexes of
            CategoricalCriterionIndex accepted -> Set.member value accepted
            NoCriterionIndex ->
              error "EvidenceReady proof lost categorical target index"
        _ -> error "EvidenceReady proof admitted incompatible target values"

satisfied :: Bool -> EffectResult
satisfied condition =
  if condition
    then EffectSatisfied
    else EffectNotSatisfied

directionAdjusted ::
     EffectDirection -> CanonicalDecimal -> CanonicalDecimal -> Rational
directionAdjusted direction baseline observed =
  case direction of
    EffectIncrease -> decimalRational observed - decimalRational baseline
    EffectDecrease -> decimalRational baseline - decimalRational observed

decimalRational :: CanonicalDecimal -> Rational
decimalRational decimal =
  storedDecimalCoefficient decimal % (10 ^ storedDecimalScale decimal)

rankIndex :: NonEmpty CanonicalText -> Map CanonicalText Integer
rankIndex levels = Map.fromList (zip (NonEmpty.toList levels) [0 ..])

adjustedSteps ::
     EffectDirection
  -> Map CanonicalText Integer
  -> CanonicalText
  -> CanonicalText
  -> Integer
adjustedSteps direction ranks baseline observed =
  case direction of
    EffectIncrease -> rank observed - rank baseline
    EffectDecrease -> rank baseline - rank observed
  where
    rank value =
      Map.findWithDefault
        (error "EvidenceReady proof admitted an unknown ordinal level")
        value
        ranks

compareQuantitative ::
     QuantitativeComparison -> CanonicalDecimal -> CanonicalDecimal -> Bool
compareQuantitative comparison value target =
  case comparison of
    QuantitativeAtLeast -> value >= target
    QuantitativeAtMost -> value <= target
    QuantitativeEqual -> value == target

compareOrdinal ::
     OrdinalComparison
  -> Map CanonicalText Integer
  -> CanonicalText
  -> CanonicalText
  -> Bool
compareOrdinal comparison ranks value target =
  case comparison of
    OrdinalAtLeastRank -> rank value >= rank target
    OrdinalAtMostRank -> rank value <= rank target
    OrdinalEqualRank -> rank value == rank target
  where
    rank level =
      Map.findWithDefault
        (error "EvidenceReady proof admitted an unknown ordinal target")
        level
        ranks

assessmentBundleSize :: AssessmentBundleInput -> Int
assessmentBundleSize bundle =
  2
    + sum
        [ 3
          + length (traceIdentityBindings (storedObservationTrace observation))
        | observation <- storedObservations bundle
        ]

defectKeyScalarLength :: AssessmentDefect -> Int
defectKeyScalarLength assessmentDefect =
  Text.length (coreRuleIdText (storedAssessmentDefectRule assessmentDefect))
    + evidenceKeyScalarLength (storedAssessmentDefectKey assessmentDefect)

evidenceKeyScalarLength :: AssessmentEvidenceKey -> Int
evidenceKeyScalarLength key =
  case key of
    AssessmentSubjectKey graph trace -> identityLength graph + traceLength trace
    ActualStartKey intervention -> identityLength intervention
    ObservationSetKey graph trace -> identityLength graph + traceLength trace
    ObservationKey trace observedAt ->
      traceLength trace + Text.length (storedTimestampText observedAt)
  where
    identityLength = Text.length . modelIdentityText
    traceLength value =
      identityLength (traceIdentityGraphIdentity value)
        + sum
            [ identityLength identity
            | (_, identity) <- traceIdentityBindings value
            ]
