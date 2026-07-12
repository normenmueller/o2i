{-# LANGUAGE DataKinds #-}

-- | Time-based observations and empirical effect assessment.
module O2I.Evidence
  ( Unit(..)
  , Quantity(..)
  , EvidenceSource(..)
  , Observation(..)
  , EffectCriterion(..)
  , TargetCriterion(..)
  , EvidencePlan(..)
  , EvidenceClaim(..)
  , CriterionResult(..)
  , TargetResult(..)
  , EffectAssessment(..)
  , EvidenceAssessedModel
  , EvidenceError(..)
  , assessEffectEvidence
  , effectAssessments
  , isEffectiveNeed
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime)
import Data.Validation (Validation(..))
import O2I.Trace
import O2I.Types

-- * Evidence types
newtype Unit = Unit
  { unitName :: Text
  } deriving (Eq, Ord, Show)

data Quantity = Quantity
  { magnitude :: Rational
  , unit :: Unit
  } deriving (Eq, Show)

newtype EvidenceSource = EvidenceSource
  { evidenceSourceName :: Text
  } deriving (Eq, Ord, Show)

data Observation = Observation
  { observationKPI :: RawNodeId
  , observationAnchor :: RawNodeId
  , observedAt :: UTCTime
  , observedValue :: Quantity
  , observationSource :: EvidenceSource
  } deriving (Eq, Show)

data EffectCriterion
  = IncreaseByAtLeast Quantity
  | DecreaseByAtLeast Quantity
  deriving (Eq, Show)

data TargetCriterion
  = AtLeast Quantity
  | AtMost Quantity
  | Within Quantity Quantity
  deriving (Eq, Show)

data EvidencePlan = EvidencePlan
  { establishedAt :: UTCTime
  , interventionStartedAt :: UTCTime
  , targetDueAt :: UTCTime
  , effectCriterion :: EffectCriterion
  , targetCriterion :: TargetCriterion
  } deriving (Eq, Show)

data EvidenceClaim = EvidenceClaim
  { evidenceTrace :: EffectTraceId
  , evidenceInterventionKeyResult :: RawNodeId
  , evidencePlan :: EvidencePlan
  , baseline :: Observation
  , followUp :: Observation
  } deriving (Eq, Show)

data CriterionResult
  = Satisfied
  | NotSatisfied
  deriving (Eq, Show)

data TargetResult
  = ObservedSatisfiedOnTime
  | ObservedSatisfiedAfterDue
  | NotSatisfiedAtFollowUp
  deriving (Eq, Show)

data EffectAssessment = EffectAssessment
  { assessedClaim :: EvidenceClaim
  , effectResult :: CriterionResult
  , targetResult :: TargetResult
  } deriving (Eq, Show)

-- * Evidence-assessed model
data EvidenceAssessedModel = EvidenceAssessedModel
  { assessedTraceableModel :: TraceableEffectModel
  , validatedAssessments :: NonEmpty.NonEmpty EffectAssessment
  }

data EvidenceError
  = UnknownEffectTrace EffectTraceId
  | DuplicateEvidenceClaim EffectTraceId Int
  | InterventionKeyResultMismatch EffectTraceId RawNodeId RawNodeId
  | ObservationKPIMismatch EffectTraceId RawNodeId RawNodeId
  | ObservationAnchorMismatch EffectTraceId RawNodeId RawNodeId
  | ObservationUnitMismatch EffectTraceId Unit Unit
  | CriterionUnitMismatch EffectTraceId Unit Unit
  | InvalidObservationOrder EffectTraceId
  | InvalidEvidencePlanOrder EffectTraceId
  | InvalidTargetDueDate EffectTraceId
  | InvalidEffectCriterion EffectTraceId
  | InvalidTargetCriterion EffectTraceId
  | EmptyUnit EffectTraceId
  | EmptyEvidenceSource EffectTraceId
  | MissingEvidenceClaim EffectTraceId
  deriving (Eq, Show)

-- * Evidence validation
assessEffectEvidence ::
     TraceableEffectModel
  -> NonEmpty.NonEmpty EvidenceClaim
  -> Validation (NonEmpty.NonEmpty EvidenceError) EvidenceAssessedModel
assessEffectEvidence model claims =
  case NonEmpty.nonEmpty errors of
    Just failures -> Failure failures
    Nothing ->
      case NonEmpty.nonEmpty assessments of
        Just nonEmptyAssessments ->
          Success (EvidenceAssessedModel model nonEmptyAssessments)
        Nothing ->
          Failure
            (NonEmpty.singleton
               (MissingEvidenceClaim
                  (traceIdentifier (NonEmpty.head (effectTraces model)))))
  where
    claimList = NonEmpty.toList claims
    claimIndex = claimsByTrace claimList
    traces = NonEmpty.toList (effectTraces model)
    errors =
      duplicateClaimErrors claimIndex
        ++ concatMap (claimErrors model) claimList
        ++ [ MissingEvidenceClaim identifier
           | trace <- traces
           , let identifier = traceIdentifier trace
           , Map.notMember identifier claimIndex
           ]
    assessments = mapMaybe (assessClaim model) claimList

claimsByTrace :: [EvidenceClaim] -> Map EffectTraceId [EvidenceClaim]
claimsByTrace =
  Map.fromListWith (++) . map (\claim -> (evidenceTrace claim, [claim]))

duplicateClaimErrors :: Map EffectTraceId [EvidenceClaim] -> [EvidenceError]
duplicateClaimErrors claimIndex =
  [ DuplicateEvidenceClaim identifier (length claims)
  | (identifier, claims) <- Map.toList claimIndex
  , length claims > 1
  ]

effectAssessments :: EvidenceAssessedModel -> NonEmpty.NonEmpty EffectAssessment
effectAssessments = validatedAssessments

isEffectiveNeed :: EvidenceAssessedModel -> ContextRef 'Need -> Bool
isEffectiveNeed model need =
  any supportsNeed (NonEmpty.toList (validatedAssessments model))
  where
    traceable = assessedTraceableModel model
    supportsNeed assessment =
      effectResult assessment == Satisfied
        && case lookupEffectTrace
                  traceable
                  (evidenceTrace (assessedClaim assessment)) of
             Just trace -> traceNeed trace == need
             Nothing -> False

claimErrors :: TraceableEffectModel -> EvidenceClaim -> [EvidenceError]
claimErrors model claim =
  case lookupEffectTrace model (evidenceTrace claim) of
    Nothing -> [UnknownEffectTrace (evidenceTrace claim)]
    Just trace ->
      keyResultErrors trace
        ++ observationErrors trace
        ++ unitErrors trace
        ++ timeErrors trace
        ++ criterionErrors trace
        ++ textualEvidenceErrors trace
  where
    keyResultErrors trace =
      [ InterventionKeyResultMismatch
        (traceIdentifier trace)
        (traceInterventionKeyResult trace)
        (evidenceInterventionKeyResult claim)
      | traceInterventionKeyResult trace /= evidenceInterventionKeyResult claim
      ]
    observationErrors trace =
      [ ObservationKPIMismatch (traceIdentifier trace) (traceKPI trace) actual
      | actual <-
          [observationKPI (baseline claim), observationKPI (followUp claim)]
      , actual /= traceKPI trace
      ]
        ++ [ ObservationAnchorMismatch
             (traceIdentifier trace)
             (traceAnchor trace)
             actual
           | actual <-
               [ observationAnchor (baseline claim)
               , observationAnchor (followUp claim)
               ]
           , actual /= traceAnchor trace
           ]
    unitErrors trace =
      let baselineUnit = unit (observedValue (baseline claim))
          followUpUnit = unit (observedValue (followUp claim))
       in [ ObservationUnitMismatch
            (traceIdentifier trace)
            baselineUnit
            followUpUnit
          | baselineUnit /= followUpUnit
          ]
            ++ [ CriterionUnitMismatch
                 (traceIdentifier trace)
                 baselineUnit
                 criterionUnit
               | criterionUnit <- claimCriterionUnits claim
               , criterionUnit /= baselineUnit
               ]
    timeErrors trace =
      [ InvalidObservationOrder (traceIdentifier trace)
      | not
          (observedAt (baseline claim) < interventionStartedAt plan
             && interventionStartedAt plan < observedAt (followUp claim))
      ]
        ++ [ InvalidEvidencePlanOrder (traceIdentifier trace)
           | establishedAt plan >= interventionStartedAt plan
           ]
        ++ [ InvalidTargetDueDate (traceIdentifier trace)
           | targetDueAt plan <= interventionStartedAt plan
           ]
    criterionErrors trace =
      [ InvalidEffectCriterion (traceIdentifier trace)
      | not (validEffectCriterion (effectCriterion plan))
      ]
        ++ [ InvalidTargetCriterion (traceIdentifier trace)
           | not (validTargetCriterion (targetCriterion plan))
           ]
    textualEvidenceErrors trace =
      [ EmptyUnit (traceIdentifier trace)
      | any (Text.null . Text.strip . unitName) (claimUnits claim)
      ]
        ++ [ EmptyEvidenceSource (traceIdentifier trace)
           | any
               (Text.null . Text.strip . evidenceSourceName . observationSource)
               [baseline claim, followUp claim]
           ]
    plan = evidencePlan claim

assessClaim :: TraceableEffectModel -> EvidenceClaim -> Maybe EffectAssessment
assessClaim model claim = do
  _ <- lookupEffectTrace model (evidenceTrace claim)
  pure
    EffectAssessment
      { assessedClaim = claim
      , effectResult = evaluateEffect claim
      , targetResult = evaluateTarget claim
      }

claimCriterionUnits :: EvidenceClaim -> [Unit]
claimCriterionUnits claim =
  effectUnits (effectCriterion plan) ++ targetUnits (targetCriterion plan)
  where
    plan = evidencePlan claim
    effectUnits (IncreaseByAtLeast quantity) = [unit quantity]
    effectUnits (DecreaseByAtLeast quantity) = [unit quantity]
    targetUnits (AtLeast quantity) = [unit quantity]
    targetUnits (AtMost quantity) = [unit quantity]
    targetUnits (Within lower upper) = [unit lower, unit upper]

claimUnits :: EvidenceClaim -> [Unit]
claimUnits claim =
  unit (observedValue (baseline claim))
    : unit (observedValue (followUp claim))
    : claimCriterionUnits claim

validEffectCriterion :: EffectCriterion -> Bool
validEffectCriterion (IncreaseByAtLeast quantity) = magnitude quantity > 0
validEffectCriterion (DecreaseByAtLeast quantity) = magnitude quantity > 0

validTargetCriterion :: TargetCriterion -> Bool
validTargetCriterion (AtLeast _) = True
validTargetCriterion (AtMost _) = True
validTargetCriterion (Within lower upper) =
  unit lower == unit upper && magnitude lower <= magnitude upper

evaluateEffect :: EvidenceClaim -> CriterionResult
evaluateEffect claim =
  if satisfies
    then Satisfied
    else NotSatisfied
  where
    before = magnitude (observedValue (baseline claim))
    after = magnitude (observedValue (followUp claim))
    satisfies =
      case effectCriterion (evidencePlan claim) of
        IncreaseByAtLeast quantity -> after - before >= magnitude quantity
        DecreaseByAtLeast quantity -> before - after >= magnitude quantity

evaluateTarget :: EvidenceClaim -> TargetResult
evaluateTarget claim
  | not satisfied = NotSatisfiedAtFollowUp
  | observedAt (followUp claim) <= targetDueAt (evidencePlan claim) =
    ObservedSatisfiedOnTime
  | otherwise = ObservedSatisfiedAfterDue
  where
    observed = magnitude (observedValue (followUp claim))
    satisfied =
      case targetCriterion (evidencePlan claim) of
        AtLeast quantity -> observed >= magnitude quantity
        AtMost quantity -> observed <= magnitude quantity
        Within lower upper ->
          observed >= magnitude lower && observed <= magnitude upper
