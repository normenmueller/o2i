{-# LANGUAGE DataKinds #-}

-- | Ex-ante readiness validation for empirical effect evidence.
--
-- Readiness fixes one complete evidence plan for every validated effect trace
-- and one canonical planned start for every traced Intervention. It does not
-- assess execution timing or follow-up observations.
module O2I.Validation.Readiness
  ( Unit(..)
  , Quantity(..)
  , RelativeChange(..)
  , EvidenceSource(..)
  , Observation(..)
  , EffectCriterion(..)
  , TargetCriterion(..)
  , PlannedInterventionStart(..)
  , EvidencePlan(..)
  , EvidenceReadyModel
  , EvidenceReadinessError(..)
  , validateEvidenceReadinessAt
  , evidencePlans
  , readinessCheckedAt
  , plannedInterventionStarts
  , readyEffectTraces
  , readyInterventions
  , readyTracesForIntervention
  , readyTraceableModel
  , lookupEvidencePlan
  ) where

import Data.List (nub, sort)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime)
import Data.Validation (Validation(..))
import O2I.Language.Element
import O2I.Validation.Trace

-- * Evidence design
-- | Unit of an observed or criterion quantity.
--
-- Percentage levels use 'PercentagePoints': a magnitude of @40@ denotes a
-- level of 40 percent, while an absolute delta of @10@ denotes ten percentage
-- points. Relative percentage changes are represented by 'RelativeChange'.
data Unit
  = PercentagePoints -- ^ Percentage levels and absolute percentage-point deltas.
  | NamedUnit Text -- ^ Extensible non-percentage unit with a nonblank name.
  deriving (Eq, Ord, Show)

-- | Exact measured or criterion value with its unit.
data Quantity = Quantity
  { magnitude :: Rational -- ^ Exact numeric magnitude.
  , unit :: Unit -- ^ Semantic unit of the magnitude.
  } deriving (Eq, Show)

-- | Exact unitless ratio for a relative change criterion.
--
-- For example, @RelativeChange (1 / 10)@ denotes a ten-percent relative
-- change. Validation requires a strictly positive ratio and a nonzero
-- baseline.
newtype RelativeChange = RelativeChange
  { relativeChangeRatio :: Rational -- ^ Ratio relative to baseline magnitude.
  } deriving (Eq, Show)

-- | Human-auditable provenance of a plan or observation.
newtype EvidenceSource = EvidenceSource
  { evidenceSourceName :: Text -- ^ Nonblank provenance description.
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
--
-- Absolute criteria compare quantities in the observation unit. Relative
-- criteria compare the directional delta with the absolute baseline magnitude.
data EffectCriterion
  = AbsoluteIncreaseByAtLeast Quantity
    -- ^ Require at least this positive absolute increase.
  | AbsoluteDecreaseByAtLeast Quantity
    -- ^ Require at least this positive absolute decrease.
  | RelativeIncreaseByAtLeast RelativeChange
    -- ^ Require at least this positive relative increase.
  | RelativeDecreaseByAtLeast RelativeChange
    -- ^ Require at least this positive relative decrease.
  deriving (Eq, Show)

-- | Required absolute target range at follow-up.
data TargetCriterion
  = AtLeast Quantity -- ^ Require a value at or above the threshold.
  | AtMost Quantity -- ^ Require a value at or below the threshold.
  | Within Quantity Quantity -- ^ Require an inclusive lower/upper range.
  deriving (Eq, Show)

-- | Planned temporal boundary shared by every trace of one Intervention.
data PlannedInterventionStart = PlannedInterventionStart
  { plannedIntervention :: RawNodeId
    -- ^ Raw Intervention identifier submitted for validation.
  , plannedStartAt :: UTCTime -- ^ Planned start fixed before execution.
  } deriving (Eq, Show)

-- | Ex-ante evidence design fixed for one effect trace.
data EvidencePlan = EvidencePlan
  { plannedTrace :: EffectTraceId -- ^ Trace governed by this plan.
  , establishedAt :: UTCTime -- ^ Time at which the plan was fixed.
  , targetDueAt :: UTCTime
    -- ^ Absolute due time, fixed ex ante and later applied to observations.
  , planSource :: EvidenceSource -- ^ Provenance of the evidence design.
  , baseline :: Observation -- ^ Observation fixed before intervention.
  , effectCriterion :: EffectCriterion -- ^ Required observed change.
  , targetCriterion :: TargetCriterion -- ^ Required absolute target.
  } deriving (Eq, Show)

-- * Evidence-ready model
-- | Opaque traceable model with canonical planned timing and one valid ex-ante
-- plan per effect trace.
--
-- Success establishes complete timing and plan coverage, trace alignment,
-- @establishedAt <= checkedAt < plannedStartAt@, baseline timing, compatible
-- units and criteria, and auditable provenance.
data EvidenceReadyModel = EvidenceReadyModel
  { validatedTraceableModel :: TraceableEffectModel
  , validatedReadinessCheckedAt :: UTCTime
  , validatedEvidencePlans :: NonEmpty.NonEmpty EvidencePlan
  , evidencePlanIndex :: Map EffectTraceId EvidencePlan
  , validatedPlannedStarts :: Map
      (ContextRef 'Intervention)
      PlannedInterventionStart
  }

-- | Violations detected while validating ex-ante evidence readiness.
data EvidenceReadinessError
  = UnknownPlannedInterventionStart RawNodeId
    -- ^ A timing record refers to no Intervention in a validated trace.
  | DuplicatePlannedInterventionStart RawNodeId Int
    -- ^ More than one planned start was supplied for one Intervention.
  | MissingPlannedInterventionStart (ContextRef 'Intervention)
    -- ^ A traced Intervention has no canonical planned start.
  | ReadinessCheckedAtOrAfterPlannedStart (ContextRef 'Intervention)
    -- ^ Readiness was not established before the planned start.
  | UnknownEvidencePlanTrace EffectTraceId
    -- ^ A plan refers to no trace in the supplied traceable model.
  | DuplicateEvidencePlan EffectTraceId Int
    -- ^ More than one plan targets the same effect trace.
  | MissingEvidencePlan EffectTraceId
    -- ^ A validated effect trace has no evidence plan.
  | PlanEstablishedAfterCheck EffectTraceId
    -- ^ The plan was established after the readiness check.
  | BaselineObservedAfterCheck EffectTraceId
    -- ^ The baseline was observed after the readiness check.
  | InvalidTargetDueDate EffectTraceId
    -- ^ The absolute target due time is not after the planned start.
  | BaselineKPIMismatch EffectTraceId RawNodeId RawNodeId
    -- ^ The baseline KPI differs from the traced KPI.
  | BaselineAnchorMismatch EffectTraceId RawNodeId RawNodeId
    -- ^ The baseline anchor differs from the traced anchor.
  | CriterionUnitMismatch EffectTraceId Unit Unit
    -- ^ An absolute criterion unit differs from the baseline unit.
  | InvalidEffectCriterion EffectTraceId
    -- ^ An absolute magnitude or relative ratio is not strictly positive.
  | RelativeEffectCriterionWithZeroBaseline EffectTraceId
    -- ^ Relative change is undefined for the plan's zero baseline.
  | InvalidTargetCriterion EffectTraceId
    -- ^ Target bounds use different units or an inverted range.
  | EmptyUnit EffectTraceId
    -- ^ The baseline or a criterion has a blank named unit.
  | EmptyPlanSource EffectTraceId
    -- ^ The evidence plan has blank provenance.
  | EmptyBaselineSource EffectTraceId
    -- ^ The baseline observation has blank provenance.
  deriving (Eq, Show)

-- * Readiness validation
-- | Validate canonical planned timing and one ex-ante plan per effect trace.
--
-- Plan establishment and baseline observation may equal the explicit check
-- time. The check must strictly precede each canonical planned start. A target
-- due time is an absolute deadline and must follow that planned start.
validateEvidenceReadinessAt ::
     UTCTime
  -> TraceableEffectModel
  -> [PlannedInterventionStart]
  -> NonEmpty.NonEmpty EvidencePlan
  -> Validation (NonEmpty.NonEmpty EvidenceReadinessError) EvidenceReadyModel
validateEvidenceReadinessAt checkedAt model starts plans =
  case NonEmpty.nonEmpty errors of
    Just failures -> Failure failures
    Nothing ->
      Success
        EvidenceReadyModel
          { validatedTraceableModel = model
          , validatedReadinessCheckedAt = checkedAt
          , validatedEvidencePlans = plans
          , evidencePlanIndex = Map.map NonEmpty.head planIndex
          , validatedPlannedStarts = validatedStarts
          }
  where
    planList = NonEmpty.toList plans
    planIndex = plansByTrace planList
    startIndex = startsByIntervention starts
    traces = NonEmpty.toList (effectTraces model)
    interventions = tracedInterventions traces
    validatedStarts =
      Map.fromList
        [ (intervention, record)
        | intervention <- interventions
        , Just record <- [uniqueRecord (contextRefId intervention) startIndex]
        ]
    errors =
      plannedStartErrors checkedAt interventions startIndex
        ++ duplicatePlanErrors planIndex
        ++ concatMap (planErrors checkedAt model startIndex) planList
        ++ [ MissingEvidencePlan identifier
           | trace <- traces
           , let identifier = traceIdentifier trace
           , Map.notMember identifier planIndex
           ]

tracedInterventions :: [EffectTrace] -> [ContextRef 'Intervention]
tracedInterventions = sort . nub . map traceIntervention

startsByIntervention ::
     [PlannedInterventionStart]
  -> Map RawNodeId (NonEmpty.NonEmpty PlannedInterventionStart)
startsByIntervention =
  Map.fromListWith (<>)
    . map (\start -> (plannedIntervention start, pure start))

plannedStartErrors ::
     UTCTime
  -> [ContextRef 'Intervention]
  -> Map RawNodeId (NonEmpty.NonEmpty PlannedInterventionStart)
  -> [EvidenceReadinessError]
plannedStartErrors checkedAt interventions startIndex =
  [ UnknownPlannedInterventionStart intervention
  | intervention <- Map.keys startIndex
  , intervention `notElem` map contextRefId interventions
  ]
    ++ [ DuplicatePlannedInterventionStart
         intervention
         (NonEmpty.length records)
       | (intervention, records) <- Map.toList startIndex
       , NonEmpty.length records > 1
       ]
    ++ [ MissingPlannedInterventionStart intervention
       | intervention <- interventions
       , Map.notMember (contextRefId intervention) startIndex
       ]
    ++ [ ReadinessCheckedAtOrAfterPlannedStart intervention
       | intervention <- interventions
       , Just record <- [uniqueRecord (contextRefId intervention) startIndex]
       , checkedAt >= plannedStartAt record
       ]

uniqueRecord ::
     Ord key => key -> Map key (NonEmpty.NonEmpty value) -> Maybe value
uniqueRecord key index = do
  records <- Map.lookup key index
  case NonEmpty.toList records of
    [record] -> Just record
    _ -> Nothing

plansByTrace ::
     [EvidencePlan] -> Map EffectTraceId (NonEmpty.NonEmpty EvidencePlan)
plansByTrace =
  Map.fromListWith (<>) . map (\plan -> (plannedTrace plan, pure plan))

duplicatePlanErrors ::
     Map EffectTraceId (NonEmpty.NonEmpty EvidencePlan)
  -> [EvidenceReadinessError]
duplicatePlanErrors planIndex =
  [ DuplicateEvidencePlan identifier (NonEmpty.length plans)
  | (identifier, plans) <- Map.toList planIndex
  , NonEmpty.length plans > 1
  ]

planErrors ::
     UTCTime
  -> TraceableEffectModel
  -> Map RawNodeId (NonEmpty.NonEmpty PlannedInterventionStart)
  -> EvidencePlan
  -> [EvidenceReadinessError]
planErrors checkedAt model startIndex plan =
  case lookupEffectTrace model (plannedTrace plan) of
    Nothing -> [UnknownEvidencePlanTrace (plannedTrace plan)]
    Just trace ->
      timeErrors trace
        ++ bindingErrors trace
        ++ unitErrors trace
        ++ criterionErrors trace
        ++ provenanceErrors trace
  where
    baselineObservation = baseline plan
    baselineUnit = unit (observedValue baselineObservation)
    timeErrors trace =
      [ PlanEstablishedAfterCheck (traceIdentifier trace)
      | establishedAt plan > checkedAt
      ]
        ++ [ BaselineObservedAfterCheck (traceIdentifier trace)
           | observedAt baselineObservation > checkedAt
           ]
        ++ [ InvalidTargetDueDate (traceIdentifier trace)
           | Just start <-
               [ uniqueRecord
                   (contextRefId (traceIntervention trace))
                   startIndex
               ]
           , targetDueAt plan <= plannedStartAt start
           ]
    bindingErrors trace =
      [ BaselineKPIMismatch
        (traceIdentifier trace)
        (unNodeId (traceKPI trace))
        (observationKPI baselineObservation)
      | observationKPI baselineObservation /= unNodeId (traceKPI trace)
      ]
        ++ [ BaselineAnchorMismatch
             (traceIdentifier trace)
             (situationAnchorRefId (traceSituationAnchor trace))
             (observationAnchor baselineObservation)
           | observationAnchor baselineObservation
               /= situationAnchorRefId (traceSituationAnchor trace)
           ]
    unitErrors trace =
      [ CriterionUnitMismatch (traceIdentifier trace) baselineUnit criterionUnit
      | criterionUnit <- criterionUnits plan
      , criterionUnit /= baselineUnit
      ]
    criterionErrors trace =
      [ InvalidEffectCriterion (traceIdentifier trace)
      | not (validEffectCriterion (effectCriterion plan))
      ]
        ++ [ RelativeEffectCriterionWithZeroBaseline (traceIdentifier trace)
           | isRelativeCriterion (effectCriterion plan)
           , magnitude (observedValue baselineObservation) == 0
           ]
        ++ [ InvalidTargetCriterion (traceIdentifier trace)
           | not (validTargetCriterion (targetCriterion plan))
           ]
        ++ [ EmptyUnit (traceIdentifier trace)
           | any blankUnit (baselineUnit : criterionUnits plan)
           ]
    provenanceErrors trace =
      [EmptyPlanSource (traceIdentifier trace) | blankSource (planSource plan)]
        ++ [ EmptyBaselineSource (traceIdentifier trace)
           | blankSource (observationSource baselineObservation)
           ]

criterionUnits :: EvidencePlan -> [Unit]
criterionUnits plan =
  effectUnits (effectCriterion plan) ++ targetUnits (targetCriterion plan)
  where
    effectUnits (AbsoluteIncreaseByAtLeast quantity) = [unit quantity]
    effectUnits (AbsoluteDecreaseByAtLeast quantity) = [unit quantity]
    effectUnits (RelativeIncreaseByAtLeast _) = []
    effectUnits (RelativeDecreaseByAtLeast _) = []
    targetUnits (AtLeast quantity) = [unit quantity]
    targetUnits (AtMost quantity) = [unit quantity]
    targetUnits (Within lower upper) = [unit lower, unit upper]

validEffectCriterion :: EffectCriterion -> Bool
validEffectCriterion (AbsoluteIncreaseByAtLeast quantity) =
  magnitude quantity > 0
validEffectCriterion (AbsoluteDecreaseByAtLeast quantity) =
  magnitude quantity > 0
validEffectCriterion (RelativeIncreaseByAtLeast change) =
  relativeChangeRatio change > 0
validEffectCriterion (RelativeDecreaseByAtLeast change) =
  relativeChangeRatio change > 0

isRelativeCriterion :: EffectCriterion -> Bool
isRelativeCriterion (RelativeIncreaseByAtLeast _) = True
isRelativeCriterion (RelativeDecreaseByAtLeast _) = True
isRelativeCriterion _ = False

validTargetCriterion :: TargetCriterion -> Bool
validTargetCriterion (AtLeast _) = True
validTargetCriterion (AtMost _) = True
validTargetCriterion (Within lower upper) =
  unit lower == unit upper && magnitude lower <= magnitude upper

blankUnit :: Unit -> Bool
blankUnit PercentagePoints = False
blankUnit (NamedUnit name) = Text.null (Text.strip name)

blankSource :: EvidenceSource -> Bool
blankSource = Text.null . Text.strip . evidenceSourceName

-- * Validated readiness access
-- | Enumerate all validated ex-ante evidence plans.
evidencePlans :: EvidenceReadyModel -> NonEmpty.NonEmpty EvidencePlan
evidencePlans = validatedEvidencePlans

-- | Read the time at which evidence readiness was validated.
readinessCheckedAt :: EvidenceReadyModel -> UTCTime
readinessCheckedAt = validatedReadinessCheckedAt

-- | Enumerate canonical planned starts for all traced Interventions.
plannedInterventionStarts :: EvidenceReadyModel -> [PlannedInterventionStart]
plannedInterventionStarts = Map.elems . validatedPlannedStarts

-- | Enumerate all complete effect traces covered by validated plans.
readyEffectTraces :: EvidenceReadyModel -> NonEmpty.NonEmpty EffectTrace
readyEffectTraces = effectTraces . validatedTraceableModel

-- | Enumerate all Interventions with validated canonical planned timing.
readyInterventions :: EvidenceReadyModel -> [ContextRef 'Intervention]
readyInterventions = Map.keys . validatedPlannedStarts

-- | Find all evidence-ready traces for one Intervention.
readyTracesForIntervention ::
     EvidenceReadyModel -> ContextRef 'Intervention -> [EffectTrace]
readyTracesForIntervention model intervention =
  filter
    ((== intervention) . traceIntervention)
    (NonEmpty.toList (readyEffectTraces model))

-- | Access the traceable model underlying evidence readiness.
readyTraceableModel :: EvidenceReadyModel -> TraceableEffectModel
readyTraceableModel = validatedTraceableModel

-- | Resolve the fixed evidence plan for a validated trace identifier.
lookupEvidencePlan :: EvidenceReadyModel -> EffectTraceId -> Maybe EvidencePlan
lookupEvidencePlan model identifier =
  Map.lookup identifier (evidencePlanIndex model)
