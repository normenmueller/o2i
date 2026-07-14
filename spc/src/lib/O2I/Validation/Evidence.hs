{-# LANGUAGE DataKinds #-}

-- | Ex-post assessment of empirical evidence for ready effect traces.
--
-- Evidence assessment checks follow-up observations against ex-ante plans and
-- baselines fixed by evidence readiness. It does not claim causal proof.
module O2I.Validation.Evidence
  ( FollowUpObservation(..)
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
import qualified Data.Text as Text
import Data.Time (UTCTime)
import Data.Validation (Validation(..))
import O2I.Language.Element
import O2I.Validation.Readiness
import O2I.Validation.Trace

-- * Follow-up evidence
-- | One ex-post observation submitted for a validated effect trace.
data FollowUpObservation = FollowUpObservation
  { followUpTrace :: EffectTraceId -- ^ Trace being assessed.
  , followUpObservation :: Observation -- ^ Ex-post KPI observation.
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

-- | Validated assessment of one follow-up against its fixed evidence plan.
data EffectAssessment = EffectAssessment
  { assessedFollowUp :: FollowUpObservation -- ^ Assessed ex-post evidence.
  , effectResult :: CriterionResult -- ^ Change criterion outcome.
  , targetResult :: TargetResult -- ^ Target and timeliness outcome.
  } deriving (Eq, Show)

-- * Evidence-assessed model
-- | Opaque evidence-ready model with valid follow-ups covering every trace.
--
-- Multiple follow-ups per trace remain distinct assessments. This stage
-- establishes evidence consistency, not methodological causal proof.
data EvidenceAssessedModel = EvidenceAssessedModel
  { assessedEvidenceReadyModel :: EvidenceReadyModel
  , validatedAssessments :: NonEmpty.NonEmpty EffectAssessment
  }

-- | Violations detected while validating ex-post effect evidence.
data EvidenceError
  = UnknownFollowUpTrace EffectTraceId
    -- ^ A follow-up refers to no ready effect trace.
  | DuplicateFollowUpObservation EffectTraceId UTCTime Int
    -- ^ A trace and observation timestamp occur more than once.
  | MissingFollowUpObservation EffectTraceId
    -- ^ A ready effect trace has no follow-up observation.
  | FollowUpKPIMismatch EffectTraceId RawNodeId RawNodeId
    -- ^ The follow-up KPI differs from the traced KPI.
  | FollowUpAnchorMismatch EffectTraceId RawNodeId RawNodeId
    -- ^ The follow-up anchor differs from the traced anchor.
  | FollowUpUnitMismatch EffectTraceId Unit Unit
    -- ^ The follow-up unit differs from the fixed baseline unit.
  | FollowUpObservedAtOrBeforeIntervention EffectTraceId
    -- ^ The follow-up was not observed after the Intervention started.
  | EmptyFollowUpUnit EffectTraceId
    -- ^ The follow-up observation has a blank unit.
  | EmptyFollowUpSource EffectTraceId
    -- ^ The follow-up observation has blank provenance.
  deriving (Eq, Show)

-- * Evidence validation
-- | Assess follow-ups against fixed plans and baselines for every ready trace.
--
-- Every trace requires at least one follow-up. Multiple follow-ups are allowed,
-- but each trace/timestamp pair must be unique. Effect and target attainment
-- are assessed separately without claiming proof of causality.
assessEffectEvidence ::
     EvidenceReadyModel
  -> NonEmpty.NonEmpty FollowUpObservation
  -> Validation (NonEmpty.NonEmpty EvidenceError) EvidenceAssessedModel
assessEffectEvidence ready followUps =
  case NonEmpty.nonEmpty errors of
    Just failures -> Failure failures
    Nothing ->
      case NonEmpty.nonEmpty assessments of
        Just nonEmptyAssessments ->
          Success (EvidenceAssessedModel ready nonEmptyAssessments)
        Nothing ->
          Failure
            (NonEmpty.singleton
               (MissingFollowUpObservation
                  (plannedTrace (NonEmpty.head (evidencePlans ready)))))
  where
    followUpList = NonEmpty.toList followUps
    traceable = readyTraceableModel ready
    followUpIndex = followUpsByTrace followUpList
    traces = NonEmpty.toList (effectTraces traceable)
    errors =
      duplicateFollowUpErrors followUpList
        ++ concatMap (followUpErrors ready) followUpList
        ++ [ MissingFollowUpObservation identifier
           | trace <- traces
           , let identifier = traceIdentifier trace
           , Map.notMember identifier followUpIndex
           ]
    assessments = mapMaybe (assessFollowUp ready) followUpList

followUpsByTrace ::
     [FollowUpObservation] -> Map EffectTraceId [FollowUpObservation]
followUpsByTrace =
  Map.fromListWith (++) . map (\item -> (followUpTrace item, [item]))

duplicateFollowUpErrors :: [FollowUpObservation] -> [EvidenceError]
duplicateFollowUpErrors followUps =
  [ DuplicateFollowUpObservation identifier timestamp count
  | ((identifier, timestamp), count) <- Map.toList counts
  , count > 1
  ]
  where
    counts =
      Map.fromListWith
        (+)
        [ ( (followUpTrace item, observedAt (followUpObservation item))
          , 1 :: Int)
        | item <- followUps
        ]

followUpErrors :: EvidenceReadyModel -> FollowUpObservation -> [EvidenceError]
followUpErrors ready followUp =
  case ( lookupEffectTrace traceable identifier
       , lookupEvidencePlan ready identifier) of
    (Just trace, Just plan) ->
      bindingErrors trace
        ++ unitErrors plan
        ++ timeErrors plan
        ++ provenanceErrors
    _ -> [UnknownFollowUpTrace identifier]
  where
    identifier = followUpTrace followUp
    observation = followUpObservation followUp
    traceable = readyTraceableModel ready
    bindingErrors trace =
      [ FollowUpKPIMismatch
        (traceIdentifier trace)
        (traceKPI trace)
        (observationKPI observation)
      | observationKPI observation /= traceKPI trace
      ]
        ++ [ FollowUpAnchorMismatch
             (traceIdentifier trace)
             (traceAnchor trace)
             (observationAnchor observation)
           | observationAnchor observation /= traceAnchor trace
           ]
    unitErrors plan =
      [ FollowUpUnitMismatch
        identifier
        (unit (observedValue (baseline plan)))
        (unit (observedValue observation))
      | unit (observedValue observation) /= unit (observedValue (baseline plan))
      ]
        ++ [ EmptyFollowUpUnit identifier
           | Text.null
               (Text.strip (unitName (unit (observedValue observation))))
           ]
    timeErrors plan =
      [ FollowUpObservedAtOrBeforeIntervention identifier
      | observedAt observation <= interventionStartedAt plan
      ]
    provenanceErrors =
      [ EmptyFollowUpSource identifier
      | Text.null
          (Text.strip (evidenceSourceName (observationSource observation)))
      ]

assessFollowUp ::
     EvidenceReadyModel -> FollowUpObservation -> Maybe EffectAssessment
assessFollowUp ready followUp = do
  plan <- lookupEvidencePlan ready (followUpTrace followUp)
  pure
    EffectAssessment
      { assessedFollowUp = followUp
      , effectResult = evaluateEffect plan (followUpObservation followUp)
      , targetResult = evaluateTarget plan (followUpObservation followUp)
      }

evaluateEffect :: EvidencePlan -> Observation -> CriterionResult
evaluateEffect plan observation =
  if satisfies
    then Satisfied
    else NotSatisfied
  where
    before = magnitude (observedValue (baseline plan))
    after = magnitude (observedValue observation)
    satisfies =
      case effectCriterion plan of
        IncreaseByAtLeast quantity -> after - before >= magnitude quantity
        DecreaseByAtLeast quantity -> before - after >= magnitude quantity

evaluateTarget :: EvidencePlan -> Observation -> TargetResult
evaluateTarget plan observation
  | not satisfied = NotSatisfiedAtFollowUp
  | observedAt observation <= targetDueAt plan = ObservedSatisfiedOnTime
  | otherwise = ObservedSatisfiedAfterDue
  where
    observed = magnitude (observedValue observation)
    satisfied =
      case targetCriterion plan of
        AtLeast quantity -> observed >= magnitude quantity
        AtMost quantity -> observed <= magnitude quantity
        Within lower upper ->
          observed >= magnitude lower && observed <= magnitude upper

-- | Enumerate all validated follow-up assessments.
effectAssessments :: EvidenceAssessedModel -> NonEmpty.NonEmpty EffectAssessment
effectAssessments = validatedAssessments

-- | Test whether any follow-up supports an effect for a Need.
--
-- Target attainment remains independent and is not required here.
isEffectiveNeed :: EvidenceAssessedModel -> ContextRef 'Need -> Bool
isEffectiveNeed model need =
  any supportsNeed (NonEmpty.toList (validatedAssessments model))
  where
    traceable = readyTraceableModel (assessedEvidenceReadyModel model)
    supportsNeed assessment =
      effectResult assessment == Satisfied
        && case lookupEffectTrace
                  traceable
                  (followUpTrace (assessedFollowUp assessment)) of
             Just trace -> traceNeed trace == need
             Nothing -> False
