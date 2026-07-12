{-# LANGUAGE DataKinds #-}

-- | Empirical evidence validation for relationally traceable effects.
--
-- Evidence validation checks observations and criteria against established
-- effect traces without claiming methodological proof of causality.
module O2I.Validation.Evidence
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
import O2I.Language.Element
import O2I.Validation.Trace

-- * Evidence types
-- | Named measurement unit shared by observations and criteria.
newtype Unit = Unit
  { unitName :: Text -- ^ Nonblank unit name required by evidence validation.
  } deriving (Eq, Ord, Show)

-- | Exact measured or criterion value with its unit.
data Quantity = Quantity
  { magnitude :: Rational -- ^ Exact numeric magnitude.
  , unit :: Unit -- ^ Semantic unit of the magnitude.
  } deriving (Eq, Show)

-- | Human-auditable provenance of an observation.
newtype EvidenceSource = EvidenceSource
  { evidenceSourceName :: Text -- ^ Nonblank source description.
  } deriving (Eq, Ord, Show)

-- | One timestamped observation of a KPI at a Situation anchor.
data Observation = Observation
  { observationKPI :: RawNodeId -- ^ Observed KPI; must match the trace.
  , observationAnchor :: RawNodeId -- ^ Anchor; must match the trace.
  , observedAt :: UTCTime -- ^ Observation timestamp.
  , observedValue :: Quantity -- ^ Observed quantity.
  , observationSource :: EvidenceSource -- ^ Auditable provenance.
  } deriving (Eq, Show)

-- | Required direction and minimum magnitude of observed change.
data EffectCriterion
  = IncreaseByAtLeast Quantity -- ^ Require at least this positive increase.
  | DecreaseByAtLeast Quantity -- ^ Require at least this positive decrease.
  deriving (Eq, Show)

-- | Required absolute target range at follow-up.
data TargetCriterion
  = AtLeast Quantity -- ^ Require a value at or above the threshold.
  | AtMost Quantity -- ^ Require a value at or below the threshold.
  | Within Quantity Quantity -- ^ Require an inclusive lower/upper range.
  deriving (Eq, Show)

-- | Ex-ante evidence design for one effect trace.
data EvidencePlan = EvidencePlan
  { establishedAt :: UTCTime -- ^ Time at which the plan was fixed.
  , interventionStartedAt :: UTCTime -- ^ Intervention start time.
  , targetDueAt :: UTCTime -- ^ Due date for target attainment.
  , effectCriterion :: EffectCriterion -- ^ Criterion for observed change.
  , targetCriterion :: TargetCriterion -- ^ Criterion for target attainment.
  } deriving (Eq, Show)

-- | Submitted evidence for one validated effect trace.
data EvidenceClaim = EvidenceClaim
  { evidenceTrace :: EffectTraceId -- ^ Trace being assessed.
  , evidenceInterventionKeyResult :: RawNodeId -- ^ Claimed operational result.
  , evidencePlan :: EvidencePlan -- ^ Ex-ante criteria and timing.
  , baseline :: Observation -- ^ Observation before intervention start.
  , followUp :: Observation -- ^ Observation after intervention start.
  } deriving (Eq, Show)

-- | Result of evaluating observed change against its effect criterion.
data CriterionResult
  = Satisfied -- ^ Observed change meets the effect criterion.
  | NotSatisfied -- ^ Observed change does not meet the effect criterion.
  deriving (Eq, Show)

-- | Result of evaluating follow-up against target value and due date.
data TargetResult
  = ObservedSatisfiedOnTime -- ^ Target met no later than its due date.
  | ObservedSatisfiedAfterDue -- ^ Target met, but only after its due date.
  | NotSatisfiedAtFollowUp -- ^ Follow-up does not meet the target.
  deriving (Eq, Show)

-- | Validated effect and target assessment for one evidence claim.
data EffectAssessment = EffectAssessment
  { assessedClaim :: EvidenceClaim -- ^ Evidence underlying the assessment.
  , effectResult :: CriterionResult -- ^ Change criterion outcome.
  , targetResult :: TargetResult -- ^ Target criterion and timeliness outcome.
  } deriving (Eq, Show)

-- * Evidence-assessed model
-- | Opaque traceable model with exactly one valid evidence claim per trace.
--
-- This stage establishes evidence consistency and criteria evaluation. It does
-- not constitute methodological proof that an Intervention caused the change.
data EvidenceAssessedModel = EvidenceAssessedModel
  { assessedTraceableModel :: TraceableEffectModel
  , validatedAssessments :: NonEmpty.NonEmpty EffectAssessment
  }

-- | Violations detected while validating empirical effect evidence.
data EvidenceError
  = UnknownEffectTrace EffectTraceId
    -- ^ A claim refers to no trace in the supplied traceable model.
  | DuplicateEvidenceClaim EffectTraceId Int
    -- ^ More than one claim targets the same effect trace.
  | InterventionKeyResultMismatch EffectTraceId RawNodeId RawNodeId
    -- ^ Claimed Intervention Key Result differs from the trace.
  | ObservationKPIMismatch EffectTraceId RawNodeId RawNodeId
    -- ^ An observation uses a KPI other than the traced KPI.
  | ObservationAnchorMismatch EffectTraceId RawNodeId RawNodeId
    -- ^ An observation uses an anchor other than the traced anchor.
  | ObservationUnitMismatch EffectTraceId Unit Unit
    -- ^ Baseline and follow-up use different units.
  | CriterionUnitMismatch EffectTraceId Unit Unit
    -- ^ A criterion unit differs from the observation unit.
  | InvalidObservationOrder EffectTraceId
    -- ^ Baseline, intervention start, and follow-up are not ordered.
  | InvalidEvidencePlanOrder EffectTraceId
    -- ^ The evidence plan was not established before intervention start.
  | InvalidTargetDueDate EffectTraceId
    -- ^ The target due date is not after intervention start.
  | InvalidEffectCriterion EffectTraceId
    -- ^ The minimum effect magnitude is not strictly positive.
  | InvalidTargetCriterion EffectTraceId
    -- ^ Target bounds use different units or an inverted range.
  | EmptyUnit EffectTraceId
    -- ^ At least one observation or criterion has a blank unit.
  | EmptyEvidenceSource EffectTraceId
    -- ^ At least one observation has blank provenance.
  | MissingEvidenceClaim EffectTraceId
    -- ^ A validated effect trace has no evidence claim.
  deriving (Eq, Show)

-- * Evidence validation
-- | Validate and assess exactly one evidence claim for every effect trace.
--
-- The input must already be relationally traceable. Independent evidence
-- errors accumulate. Success guarantees trace alignment, compatible units,
-- valid temporal ordering, nonblank provenance, and evaluated criteria.
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

-- | Enumerate all validated effect assessments.
effectAssessments :: EvidenceAssessedModel -> NonEmpty.NonEmpty EffectAssessment
effectAssessments = validatedAssessments

-- | Test whether any trace for a Need has satisfied its effect criterion.
--
-- Target attainment is deliberately independent and is not required here.
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
