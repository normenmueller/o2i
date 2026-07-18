{-# LANGUAGE DataKinds #-}

-- | Ex-post assessment of empirical evidence for ready effect traces.
--
-- Evidence assessment checks actual Intervention timing and follow-up levels
-- against KPI definitions, ex-ante plans, and baselines fixed by readiness. It
-- supports plausible attribution and does not claim causal proof.
module O2I.Validation.Evidence
  ( ActualInterventionStart(..)
  , FollowUpObservation(..)
  , CriterionResult(..)
  , TargetResult(..)
  , EffectAssessment
  , assessedFollowUp
  , effectResult
  , targetResult
  , EvidenceAssessedModel
  , EvidenceError(..)
  , assessEffectEvidenceAt
  , evidenceAssessedAt
  , actualInterventionStarts
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
-- | Actual temporal boundary shared by every trace of one Intervention.
data ActualInterventionStart = ActualInterventionStart
  { actualIntervention :: RawNodeId
    -- ^ Raw Intervention identifier submitted for validation.
  , actualStartAt :: UTCTime -- ^ Observed execution start.
  } deriving (Eq, Show)

-- | One ex-post observation submitted for a validated effect trace.
--
-- Its KPI selects the stable definition and value domain fixed at readiness.
data FollowUpObservation = FollowUpObservation
  { followUpTrace :: EffectTraceId -- ^ Trace being assessed.
  , followUpObservation :: Observation -- ^ Ex-post KPI observation.
  } deriving (Eq, Show)

-- | Result of evaluating observed change against its effect criterion.
data CriterionResult
  = Satisfied -- ^ Observed change meets the effect criterion.
  | NotSatisfied -- ^ Observed change does not meet the effect criterion.
  deriving (Eq, Show)

-- | Result of evaluating one follow-up observation against its target.
--
-- These outcomes locate and classify only the submitted observation. They do
-- not establish when target attainment first occurred.
data TargetResult
  = TargetSatisfiedInObservationByDue
    -- ^ The observation satisfies the target and is no later than its due time.
  | TargetSatisfiedInObservationAfterDue
    -- ^ The observation satisfies the target and occurs after its due time.
  | TargetNotSatisfiedInObservation
    -- ^ The observation does not satisfy the target.
  deriving (Eq, Show)

-- | Validated assessment of one follow-up against its fixed evidence plan.
--
-- Values are produced only by 'assessEffectEvidenceAt'.
data EffectAssessment =
  EffectAssessment FollowUpObservation CriterionResult TargetResult
  deriving (Eq, Show)

-- | Project the assessed ex-post evidence.
assessedFollowUp :: EffectAssessment -> FollowUpObservation
assessedFollowUp (EffectAssessment followUp _ _) = followUp

-- | Project the change-criterion outcome.
effectResult :: EffectAssessment -> CriterionResult
effectResult (EffectAssessment _ result _) = result

-- | Project the independent target outcome.
targetResult :: EffectAssessment -> TargetResult
targetResult (EffectAssessment _ _ result) = result

-- * Evidence-assessed model
-- | Opaque evidence-ready model with canonical actual timing and valid
-- follow-ups covering every trace.
--
-- Multiple follow-ups per trace remain distinct assessments. Success
-- establishes
-- @readinessCheckedAt < actualStartAt < observedAt <= assessedAt@ for each
-- assessment, definition-domain conformance, and evidence consistency, not
-- methodological causal proof.
data EvidenceAssessedModel = EvidenceAssessedModel
  { assessedEvidenceReadyModel :: EvidenceReadyModel
  , validatedAssessedAt :: UTCTime
  , validatedActualStarts :: Map
      (ContextRef 'Intervention)
      ActualInterventionStart
  , validatedAssessments :: NonEmpty.NonEmpty EffectAssessment
  }

-- | Violations detected while validating ex-post effect evidence.
data EvidenceError
  = UnknownActualInterventionStart RawNodeId
    -- ^ A timing record refers to no evidence-ready Intervention.
  | DuplicateActualInterventionStart RawNodeId Int
    -- ^ More than one actual start was supplied for one Intervention.
  | MissingActualInterventionStart (ContextRef 'Intervention)
    -- ^ An evidence-ready Intervention has no canonical actual start.
  | ActualInterventionStartAtOrBeforeReadiness (ContextRef 'Intervention)
    -- ^ The actual start does not strictly follow validated readiness.
  | ActualInterventionStartAtOrAfterAssessment (ContextRef 'Intervention)
    -- ^ The actual start does not strictly precede the assessment time.
  | UnknownFollowUpTrace EffectTraceId
    -- ^ A follow-up refers to no ready effect trace.
  | DuplicateFollowUpObservation EffectTraceId UTCTime Int
    -- ^ A trace and observation timestamp occur more than once.
  | MissingFollowUpObservation EffectTraceId
    -- ^ A ready effect trace has no follow-up observation.
  | FollowUpKPIMismatch EffectTraceId RawNodeId RawNodeId
    -- ^ The follow-up KPI differs from the traced KPI.
  | FollowUpAnchorMismatch EffectTraceId RawNodeId RawNodeId
    -- ^ The follow-up anchor differs from the traced anchor.
  | FollowUpLevelOutsideDomain EffectTraceId Level ValueDomain
    -- ^ The follow-up level lies outside the KPI's declared domain.
  | FollowUpObservedAtOrBeforeActualStart EffectTraceId
    -- ^ The follow-up was not observed after actual execution started.
  | FollowUpObservedAfterAssessment EffectTraceId
    -- ^ The follow-up observation is future-dated at assessment time.
  | EmptyFollowUpSource EffectTraceId
    -- ^ The follow-up observation has blank provenance.
  deriving (Eq, Show)

-- * Evidence validation
-- | Assess canonical actual timing and follow-ups at an explicit time.
--
-- Every evidence-ready Intervention requires one actual start and every trace
-- requires at least one follow-up. Multiple follow-ups are allowed, but each
-- actual start must strictly follow the validated readiness check and strictly
-- precede the assessment time. Each trace/timestamp pair must be unique.
-- Effect and target attainment are assessed separately without claiming proof
-- of causality.
assessEffectEvidenceAt ::
     UTCTime
  -> EvidenceReadyModel
  -> [ActualInterventionStart]
  -> NonEmpty.NonEmpty FollowUpObservation
  -> Validation (NonEmpty.NonEmpty EvidenceError) EvidenceAssessedModel
assessEffectEvidenceAt assessedAt ready starts followUps =
  case NonEmpty.nonEmpty errors of
    Just failures -> Failure failures
    Nothing ->
      case NonEmpty.nonEmpty assessments of
        Just nonEmptyAssessments ->
          Success
            EvidenceAssessedModel
              { assessedEvidenceReadyModel = ready
              , validatedAssessedAt = assessedAt
              , validatedActualStarts = validatedStarts
              , validatedAssessments = nonEmptyAssessments
              }
        Nothing ->
          Failure
            (NonEmpty.singleton
               (MissingFollowUpObservation
                  (plannedTrace (NonEmpty.head (evidencePlans ready)))))
  where
    followUpList = NonEmpty.toList followUps
    traceable = readyTraceableModel ready
    followUpIndex = followUpsByTrace followUpList
    startIndex = startsByIntervention starts
    traces = NonEmpty.toList (effectTraces traceable)
    interventions = readyInterventions ready
    validatedStarts =
      Map.fromList
        [ (intervention, record)
        | intervention <- interventions
        , Just record <- [uniqueRecord (contextRefId intervention) startIndex]
        ]
    errors =
      actualStartErrors
        (readinessCheckedAt ready)
        assessedAt
        interventions
        startIndex
        ++ duplicateFollowUpErrors followUpList
        ++ concatMap (followUpErrors assessedAt ready startIndex) followUpList
        ++ [ MissingFollowUpObservation identifier
           | trace <- traces
           , let identifier = traceIdentifier trace
           , Map.notMember identifier followUpIndex
           ]
    assessments = mapMaybe (assessFollowUp ready) followUpList

startsByIntervention ::
     [ActualInterventionStart]
  -> Map RawNodeId (NonEmpty.NonEmpty ActualInterventionStart)
startsByIntervention =
  Map.fromListWith (<>) . map (\start -> (actualIntervention start, pure start))

actualStartErrors ::
     UTCTime
  -> UTCTime
  -> [ContextRef 'Intervention]
  -> Map RawNodeId (NonEmpty.NonEmpty ActualInterventionStart)
  -> [EvidenceError]
actualStartErrors checkedAt assessedAt interventions startIndex =
  [ UnknownActualInterventionStart intervention
  | intervention <- Map.keys startIndex
  , intervention `notElem` map contextRefId interventions
  ]
    ++ [ DuplicateActualInterventionStart intervention (NonEmpty.length records)
       | (intervention, records) <- Map.toList startIndex
       , NonEmpty.length records > 1
       ]
    ++ [ MissingActualInterventionStart intervention
       | intervention <- interventions
       , Map.notMember (contextRefId intervention) startIndex
       ]
    ++ [ ActualInterventionStartAtOrBeforeReadiness intervention
       | intervention <- interventions
       , Just record <- [uniqueRecord (contextRefId intervention) startIndex]
       , actualStartAt record <= checkedAt
       ]
    ++ [ ActualInterventionStartAtOrAfterAssessment intervention
       | intervention <- interventions
       , Just record <- [uniqueRecord (contextRefId intervention) startIndex]
       , actualStartAt record >= assessedAt
       ]

uniqueRecord ::
     Ord key => key -> Map key (NonEmpty.NonEmpty value) -> Maybe value
uniqueRecord key index = do
  records <- Map.lookup key index
  case NonEmpty.toList records of
    [record] -> Just record
    _ -> Nothing

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

followUpErrors ::
     UTCTime
  -> EvidenceReadyModel
  -> Map RawNodeId (NonEmpty.NonEmpty ActualInterventionStart)
  -> FollowUpObservation
  -> [EvidenceError]
followUpErrors assessedAt ready startIndex followUp =
  case ( lookupEffectTrace traceable identifier
       , lookupEvidencePlan ready identifier) of
    (Just trace, Just _) ->
      bindingErrors trace
        ++ domainErrors trace
        ++ timeErrors trace
        ++ provenanceErrors
    _ -> [UnknownFollowUpTrace identifier]
  where
    identifier = followUpTrace followUp
    observation = followUpObservation followUp
    traceable = readyTraceableModel ready
    bindingErrors trace =
      [ FollowUpKPIMismatch
        (traceIdentifier trace)
        (unNodeId (traceKPI trace))
        (observationKPI observation)
      | observationKPI observation /= unNodeId (traceKPI trace)
      ]
        ++ [ FollowUpAnchorMismatch
             (traceIdentifier trace)
             (situationAnchorRefId (traceSituationAnchor trace))
             (observationAnchor observation)
           | observationAnchor observation
               /= situationAnchorRefId (traceSituationAnchor trace)
           ]
    domainErrors trace =
      case lookupKPIDefinition ready (traceKPI trace) of
        Nothing -> []
        Just definition ->
          [ FollowUpLevelOutsideDomain
            identifier
            (observedLevel observation)
            (kpiDefinitionDomain definition)
          | not
              (levelInDomain
                 (kpiDefinitionDomain definition)
                 (observedLevel observation))
          ]
    timeErrors trace =
      [ FollowUpObservedAtOrBeforeActualStart identifier
      | Just start <-
          [uniqueRecord (contextRefId (traceIntervention trace)) startIndex]
      , observedAt observation <= actualStartAt start
      ]
        ++ [ FollowUpObservedAfterAssessment identifier
           | observedAt observation > assessedAt
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
    (EffectAssessment
       followUp
       (evaluateEffect plan (followUpObservation followUp))
       (evaluateTarget plan (followUpObservation followUp)))

evaluateEffect :: EvidencePlan -> Observation -> CriterionResult
evaluateEffect plan observation =
  if satisfies
    then Satisfied
    else NotSatisfied
  where
    before = levelValue (observedLevel (baseline plan))
    after = levelValue (observedLevel observation)
    relative increase = increase / abs before
    satisfies =
      case effectCriterion plan of
        AbsoluteIncreaseByAtLeast delta -> after - before >= deltaValue delta
        AbsoluteDecreaseByAtLeast delta -> before - after >= deltaValue delta
        RelativeIncreaseByAtLeast change ->
          relative (after - before) >= relativeChangeRatio change
        RelativeDecreaseByAtLeast change ->
          relative (before - after) >= relativeChangeRatio change

evaluateTarget :: EvidencePlan -> Observation -> TargetResult
evaluateTarget plan observation
  | not satisfied = TargetNotSatisfiedInObservation
  | observedAt observation <= targetDueAt plan =
    TargetSatisfiedInObservationByDue
  | otherwise = TargetSatisfiedInObservationAfterDue
  where
    observed = levelValue (observedLevel observation)
    satisfied =
      case targetCriterion plan of
        AtLeast level -> observed >= levelValue level
        AtMost level -> observed <= levelValue level
        Within lower upper ->
          observed >= levelValue lower && observed <= levelValue upper

-- | Read the time at which the assessed stage was established.
evidenceAssessedAt :: EvidenceAssessedModel -> UTCTime
evidenceAssessedAt = validatedAssessedAt

-- | Enumerate canonical actual starts for all assessed Interventions.
actualInterventionStarts :: EvidenceAssessedModel -> [ActualInterventionStart]
actualInterventionStarts = Map.elems . validatedActualStarts

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
